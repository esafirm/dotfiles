#!/usr/bin/env node
// instabox-move-repo: stage the Claude Code and Codex conversations of a repo (and its worktrees)
// for the box, with every local path rewritten to the box path, so `claude --continue` and
// `codex resume` find them there. Node >= 18, no dependencies.
//
//   node history.mjs --plan plan.json --out STAGE [--no-claude] [--no-codex]
//   node history.mjs --map /local/path=/box/path [--map ...] --out STAGE
//
// --plan is the JSON of `repo-files.mjs --json`: the main checkout and every moved worktree are
// mapped. STAGE is laid out like the box's HOME:
//   .claude/projects/<box path, Claude Code's way>/...   sessions, subagents, tool results
//   .codex/sessions/YYYY/MM/DD/rollout-*.jsonl           (and archived_sessions/)
//   .cache/instabox-move-repo/{claude,codex}-history.jsonl + apply-history.sh
//                                                        prompt history lines, appended on the box
// File times are kept, so the latest session stays the latest. The output is a JSON summary:
// counts, bytes and session ids. Conversation contents are rewritten, never printed.
import {
  chmodSync,
  closeSync,
  existsSync,
  openSync,
  readSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  realpathSync,
  statSync,
  utimesSync,
  writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

// Claude Code's directory name for a project path: every non-alphanumeric character becomes '-'.
export function claudeProjectName(path) {
  return path.replace(/[^A-Za-z0-9]/g, '-');
}

const reEscape = (s) => s.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');

// A rewriter for text: each local path (as written raw, and as escaped inside a JSON string) is
// replaced by its box path when it is followed by something that cannot continue a path name, so
// /a/app does not touch /a/app-2. Longest paths first: a worktree inside the main checkout wins.
export function makeRewriter(maps) {
  const pairs = [];
  for (const [from, to] of maps) {
    if (from === to) continue;
    pairs.push([from, to]);
    const jf = JSON.stringify(from).slice(1, -1);
    if (jf !== from) pairs.push([jf, JSON.stringify(to).slice(1, -1)]);
  }
  pairs.sort((a, b) => b[0].length - a[0].length);
  if (!pairs.length) return (s) => s;
  const table = new Map(pairs);
  const re = new RegExp(`(${pairs.map(([f]) => reEscape(f)).join('|')})(?![A-Za-z0-9._-])`, 'g');
  return (s) => s.replace(re, (m) => table.get(m));
}

// The box path for a local path under one of the maps, or null.
export function mapPath(maps, p) {
  let best = null;
  for (const [from, to] of maps)
    if ((p === from || p.startsWith(from + '/')) && (!best || from.length > best[0].length)) best = [from, to];
  return best ? best[1] + p.slice(best[0].length) : null;
}

function lstat(p) {
  try {
    return lstatSync(p);
  } catch {
    return null;
  }
}

function filesUnder(dir, rel = '') {
  const out = [];
  let names = [];
  try {
    names = readdirSync(join(dir, rel)).sort();
  } catch {
    return out;
  }
  for (const n of names) {
    const r = rel ? `${rel}/${n}` : n;
    const st = lstat(join(dir, r));
    if (!st) continue;
    if (st.isDirectory()) out.push(...filesUnder(dir, r));
    else if (st.isFile()) out.push(r);
  }
  return out;
}

// The first "cwd" recorded in a JSONL file, read from its start.
function firstCwd(path, limit = 4 << 20) {
  let text;
  let fd;
  try {
    fd = openSync(path, 'r');
    const buf = Buffer.alloc(Math.min(limit, statSync(path).size));
    const n = readSync(fd, buf, 0, buf.length, 0);
    text = buf.subarray(0, n).toString('utf8');
  } catch {
    return null;
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
  const m = /"cwd"\s*:\s*"((?:[^"\\]|\\.)*)"/.exec(text);
  if (!m) return null;
  try {
    return JSON.parse(`"${m[1]}"`);
  } catch {
    return null;
  }
}

const TEXT = /\.(?:jsonl|json|txt|md|log)$/i;

// Copy src to dst, rewritten when it is text, keeping its times and a private mode.
function copyRewritten(src, dst, rewrite) {
  const st = statSync(src);
  const buf = readFileSync(src);
  const out = TEXT.test(src) && !buf.includes(0) ? Buffer.from(rewrite(buf.toString('utf8')), 'utf8') : buf;
  mkdirSync(dirname(dst), { recursive: true, mode: 0o700 });
  writeFileSync(dst, out, { mode: 0o600 });
  chmodSync(dst, 0o600);
  utimesSync(dst, st.atime, st.mtime);
  return { bytes: out.length, mtime: st.mtimeMs };
}

function claude(maps, rewrite, out, home) {
  const root = join(process.env.CLAUDE_CONFIG_DIR || join(home, '.claude'));
  const projects = join(root, 'projects');
  const res = { projects: [], sessions: 0, bytes: 0, recent: [], historyLines: 0 };
  const prefixes = maps.map(([from]) => claudeProjectName(from));
  let names = [];
  try {
    names = readdirSync(projects);
  } catch {}
  const sessions = [];
  for (const name of names.sort()) {
    if (!prefixes.some((p) => name === p || name.startsWith(p + '-'))) continue;
    const dir = join(projects, name);
    if (!lstat(dir)?.isDirectory()) continue;
    const files = filesUnder(dir);
    // Which path the directory is for: the cwd its sessions recorded (the name alone is lossy:
    // /a/app-x and /a/app/x share it), or the exact name of a mapped path when nothing recorded one.
    let cwd = null;
    for (const f of files.filter((f) => f.endsWith('.jsonl'))) if ((cwd = firstCwd(join(dir, f)))) break;
    let to = cwd ? mapPath(maps, cwd) : null;
    if (!cwd) {
      const exact = maps.find(([from]) => claudeProjectName(from) === name);
      to = exact ? exact[1] : null;
    }
    if (!to) continue;
    const newName = claudeProjectName(to);
    let bytes = 0;
    for (const f of files) {
      const r = copyRewritten(join(dir, f), join(out, '.claude', 'projects', newName, f), rewrite);
      bytes += r.bytes;
      if (!f.includes('/') && f.endsWith('.jsonl')) sessions.push({ id: f.slice(0, -6), mtime: r.mtime, dir: to });
    }
    res.projects.push({ from: cwd || name, to, dir: newName, files: files.length, bytes });
    res.bytes += bytes;
  }
  res.sessions = sessions.length;
  res.recent = sessions
    .sort((a, b) => b.mtime - a.mtime)
    .slice(0, 5)
    .map(({ id, dir }) => ({ id, dir }));

  // Prompt history (up-arrow in claude): lines whose "project" is a mapped path.
  const hist = join(root, 'history.jsonl');
  if (existsSync(hist)) {
    const lines = [];
    for (const line of readFileSync(hist, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      let o;
      try {
        o = JSON.parse(line);
      } catch {
        continue;
      }
      const to = typeof o.project === 'string' ? mapPath(maps, o.project) : null;
      if (!to) continue;
      lines.push(rewrite(line));
    }
    if (lines.length) {
      const dst = join(out, '.cache', 'instabox-move-repo', 'claude-history.jsonl');
      mkdirSync(dirname(dst), { recursive: true, mode: 0o700 });
      writeFileSync(dst, lines.join('\n') + '\n', { mode: 0o600 });
      res.historyLines = lines.length;
    }
  }
  return res;
}

function codex(maps, rewrite, out, home) {
  const root = process.env.CODEX_HOME || join(home, '.codex');
  const res = { sessions: 0, bytes: 0, recent: [], historyLines: 0 };
  const ids = new Set();
  const found = [];
  for (const sub of ['sessions', 'archived_sessions']) {
    const dir = join(root, sub);
    for (const f of filesUnder(dir)) {
      const base = f.split('/').pop();
      if (!/^rollout-.*\.jsonl$/.test(base)) continue;
      const cwd = firstCwd(join(dir, f));
      if (!cwd || !mapPath(maps, cwd)) continue;
      const r = copyRewritten(join(dir, f), join(out, '.codex', sub, f), rewrite);
      res.bytes += r.bytes;
      const id = (/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$/.exec(base) || [])[1];
      if (id) ids.add(id);
      found.push({ id: id || base, name: base, archived: sub !== 'sessions', dir: mapPath(maps, cwd) });
    }
  }
  res.sessions = found.length;
  // Rollout file names start with the time they began.
  res.recent = found
    .filter((s) => !s.archived)
    .sort((a, b) => b.name.localeCompare(a.name))
    .slice(0, 5)
    .map(({ id, dir }) => ({ id, dir }));

  // Prompt history: lines of the moved sessions.
  const hist = join(root, 'history.jsonl');
  if (ids.size && existsSync(hist)) {
    const lines = [];
    for (const line of readFileSync(hist, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      try {
        if (ids.has(JSON.parse(line).session_id)) lines.push(rewrite(line));
      } catch {}
    }
    if (lines.length) {
      const dst = join(out, '.cache', 'instabox-move-repo', 'codex-history.jsonl');
      mkdirSync(dirname(dst), { recursive: true, mode: 0o700 });
      writeFileSync(dst, lines.join('\n') + '\n', { mode: 0o600 });
      res.historyLines = lines.length;
    }
  }
  return res;
}

// Run on the box after the stage is unpacked into HOME: appends the prompt history lines that
// are not there yet, then removes the staged copies. Safe to run again.
const APPLY = `#!/usr/bin/env bash
# Written by instabox-move-repo (history.mjs). Safe to run again.
set -eu
A="$HOME/.cache/instabox-move-repo"
for t in claude codex; do
  src="$A/$t-history.jsonl"
  [ -f "$src" ] || continue
  dst="$HOME/.$t/history.jsonl"
  mkdir -p "$HOME/.$t"
  touch "$dst"
  cat "$dst" "$src" | awk '!seen[$0]++' > "$dst.tmp"
  chmod 600 "$dst.tmp"
  mv "$dst.tmp" "$dst"
  rm -f "$src"
done
echo "instabox-move-repo: history in place"
`;

export function stageHistory({ maps, out, home = homedir(), claude: doClaude = true, codex: doCodex = true }) {
  const rewrite = makeRewriter(maps);
  mkdirSync(out, { recursive: true, mode: 0o700 });
  const res = {
    maps: maps.map(([from, to]) => ({ from, to })),
    claude: doClaude ? claude(maps, rewrite, out, home) : null,
    codex: doCodex ? codex(maps, rewrite, out, home) : null,
  };
  const apply = join(out, '.cache', 'instabox-move-repo', 'apply-history.sh');
  mkdirSync(dirname(apply), { recursive: true, mode: 0o700 });
  writeFileSync(apply, APPLY, { mode: 0o700 });
  res.entries = readdirSync(out).sort(); // the top-level names to tar
  return res;
}

export function mapsFromPlan(plan) {
  const maps = [[plan.main.src, plan.main.box]];
  for (const w of plan.worktrees || []) if (w.move) maps.push([w.src, w.box]);
  return maps;
}

function main(argv) {
  const maps = [];
  let out;
  let doClaude = true;
  let doCodex = true;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const val = () => {
      if (argv[i + 1] === undefined) throw new Error(`${a} needs a value`);
      return argv[++i];
    };
    try {
      if (a === '--plan') maps.push(...mapsFromPlan(JSON.parse(readFileSync(val(), 'utf8'))));
      else if (a === '--map') {
        const v = val();
        const eq = v.indexOf('=');
        if (eq <= 0) throw new Error(`--map wants LOCAL=BOX, got ${v}`);
        maps.push([v.slice(0, eq), v.slice(eq + 1)]);
      } else if (a === '--out') out = val();
      else if (a === '--no-claude') doClaude = false;
      else if (a === '--no-codex') doCodex = false;
      else if (a === '-h' || a === '--help') {
        process.stdout.write('usage: node history.mjs (--plan plan.json | --map LOCAL=BOX ...) --out DIR [--no-claude] [--no-codex]\n');
        return 0;
      } else throw new Error(`unknown argument ${a}`);
    } catch (e) {
      process.stderr.write(`history: ${e.message}\n`);
      return 2;
    }
  }
  if (!out || !maps.length) {
    process.stderr.write('history: --out and --plan (or --map) are required\n');
    return 2;
  }
  // Local paths as the agents recorded them: also the symlink-resolved spelling (macOS /tmp, /var).
  const all = [];
  for (const [from, to] of maps) {
    all.push([from, to]);
    try {
      const r = realpathSync(from);
      if (r !== from) all.push([r, to]);
    } catch {}
  }
  const res = stageHistory({ maps: all, out, claude: doClaude, codex: doCodex });
  res.out = relative(process.cwd(), out) || '.';
  process.stdout.write(JSON.stringify(res, null, 2) + '\n');
  return 0;
}

let isMain = false;
try {
  isMain = realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
} catch {}
if (isMain) process.exitCode = main(process.argv.slice(2));
