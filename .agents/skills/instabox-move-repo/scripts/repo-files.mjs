#!/usr/bin/env node
// instabox-move-repo: what of the current git repo (and its worktrees) goes to the box, where it
// lands, and how big it is. Node >= 18, no dependencies. Run it from anywhere inside the repo or
// any of its linked worktrees: the plan is always the main checkout plus its worktrees.
//
//   node repo-files.mjs --dest /data/workspace/NAME            the plan with sizes, human readable
//   node repo-files.mjs --dest /data/workspace/NAME --json     the same plan as JSON
//   node repo-files.mjs --list0 PATH                           the files of the checkout at PATH (main
//                                                              or a worktree) for tar, NUL-separated,
//                                                              relative to PATH
//   --skip-worktree PATH   leave a linked worktree behind (repeatable; pass it to --list0 runs too)
//   --keep NAME            copy an excluded name anyway (repeatable): --keep build (not an untracked
//                          .env: those always stay behind)
//
// What goes: all of the main checkout's .git (branches, stashes, the index, unpushed commits, the
// worktrees' own HEAD and index under .git/worktrees/), every tracked file that exists, and every
// untracked file git does not ignore, in the main checkout and in each linked worktree. What
// stays, on top of what git ignores: build output and dependency directories (EXCLUDED_DIRS,
// EXCLUDED_FILES) that the repo forgot to ignore, and untracked .env files. Tracked files always
// go, even inside such a directory, so the box shows the same `git status` and HEAD; the only
// difference is `??` lines for what was left out. File contents are never read, only names and sizes.
import { spawnSync } from 'node:child_process';
import { lstatSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { basename, dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

// Directory names that hold build output, dependencies or caches: regenerated on the box.
export const EXCLUDED_DIRS = [
  // JavaScript / TypeScript
  'node_modules',
  'bower_components',
  'jspm_packages',
  '.pnpm-store',
  '.npm',
  '.yarn-cache',
  '.next',
  '.nuxt',
  '.output',
  '.svelte-kit',
  '.angular',
  '.expo',
  '.parcel-cache',
  '.turbo',
  '.vercel',
  '.netlify',
  '.docusaurus',
  '.vite',
  'storybook-static',
  // generic build output and caches
  'dist',
  'build',
  'out',
  'target',
  '.cache',
  'coverage',
  '.nyc_output',
  // Python
  '__pycache__',
  '.venv',
  'venv',
  '.tox',
  '.nox',
  '.pytest_cache',
  '.mypy_cache',
  '.ruff_cache',
  '.pytype',
  '.hypothesis',
  '.ipynb_checkpoints',
  '.eggs',
  // JVM, Android
  '.gradle',
  '.kotlin',
  // native and others
  'CMakeFiles',
  '.zig-cache',
  'zig-cache',
  'zig-out',
  '.build',
  'DerivedData',
  'Pods',
  '.dart_tool',
  '.stack-work',
  'dist-newstyle',
  '_build',
  '.terraform',
  '.direnv',
  '.devenv',
];

// Directory name patterns.
export const EXCLUDED_DIR_PATTERNS = ['bazel-*', 'cmake-build-*', '*.egg-info'];

// File name patterns: compiled objects and tool caches.
export const EXCLUDED_FILES = [
  '*.o',
  '*.obj',
  '*.so',
  '*.dylib',
  '*.dll',
  '*.a',
  '*.lib',
  '*.pyc',
  '*.pyo',
  '*.class',
  '*.tsbuildinfo',
  '.eslintcache',
  '.stylelintcache',
  '.DS_Store',
];

// Untracked .env files never go: the final report lists them as left behind. Templates do.
const ENV_FILE = /^\.env(?:\..+)?$/;
const ENV_TEMPLATE = /^\.env\.(?:example|sample|template|dist|defaults)$/;
const isEnvName = (f) => {
  const b = f.replace(/\/$/, '').split('/').pop();
  return ENV_FILE.test(b) && !ENV_TEMPLATE.test(b);
};

function globToRe(g) {
  return new RegExp('^' + g.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$');
}
const DIR_RES = EXCLUDED_DIR_PATTERNS.map(globToRe);
const FILE_RES = EXCLUDED_FILES.map((g) => [g, globToRe(g)]);

function git(args, cwd) {
  const r = spawnSync('git', args, { cwd, encoding: 'buffer', maxBuffer: 1 << 30 });
  if (r.status !== 0) {
    const msg = (r.stderr || '').toString().trim();
    throw new Error(`git ${args.join(' ')}: ${msg || 'failed'}`);
  }
  return r.stdout.toString('utf8');
}

const split0 = (s) => s.split('\0').filter((x) => x !== '');

function lstat(p) {
  try {
    return lstatSync(p);
  } catch {
    return null;
  }
}

// Bytes and files under a path; symlinks are counted as links, not followed. skip: absolute paths.
function treeBytes(p, skip = new Set()) {
  if (skip.has(p)) return { bytes: 0, files: 0 };
  const st = lstat(p);
  if (!st) return { bytes: 0, files: 0 };
  if (!st.isDirectory()) return { bytes: st.size, files: 1 };
  let bytes = 0;
  let files = 0;
  let names = [];
  try {
    names = readdirSync(p);
  } catch {}
  for (const n of names) {
    const t = treeBytes(join(p, n), skip);
    bytes += t.bytes;
    files += t.files;
  }
  return { bytes, files };
}

// Archive names are joined with '/' whatever the host separator.
function walk(dir, rel, skip, out = []) {
  if (skip.has(dir)) return out;
  out.push(rel);
  let names = [];
  try {
    names = readdirSync(dir).sort();
  } catch {}
  for (const n of names) {
    const p = join(dir, n);
    const st = lstat(p);
    if (!st || skip.has(p)) continue;
    if (st.isDirectory()) walk(p, `${rel}/${n}`, skip, out);
    else out.push(`${rel}/${n}`);
  }
  return out;
}

// Why an untracked path is left out, or null when it goes. keep: names the user opted back in.
// Returns { group, kind }: group is the directory prefix (`web/node_modules/`), the file, or the pattern.
export function excludedBy(path, isDirEntry, keep = new Set()) {
  const parts = path.replace(/\/$/, '').split('/');
  const last = parts.length - 1;
  for (let i = 0; i < parts.length; i++) {
    const n = parts[i];
    // The last component is a directory only for git's `dir/` entries (nested repos) or symlinks.
    if (i === last && !isDirEntry) break;
    if (keep.has(n)) continue;
    if (EXCLUDED_DIRS.includes(n) || DIR_RES.some((re) => re.test(n)))
      return { group: parts.slice(0, i + 1).join('/') + '/', kind: 'build' };
  }
  const base = parts[last];
  if (isEnvName(base)) return { group: path, kind: 'env' };
  if (!keep.has(base)) for (const [g, re] of FILE_RES) if (re.test(base)) return { group: g, kind: 'build' };
  return null;
}

export function human(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const u = ['KB', 'MB', 'GB', 'TB'];
  let v = bytes / 1024;
  let i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v >= 10 ? Math.round(v) : v.toFixed(1)} ${u[i]}`;
}

const real = (p) => {
  try {
    return realpathSync(p);
  } catch {
    return resolve(p);
  }
};
// s: sep for native paths, '/' for git's.
const inside = (p, dir, s = sep) => p === dir || p.startsWith(dir + s);

// `git worktree list --porcelain -z`, parsed. The first entry is the main checkout.
export function listWorktrees(cwd) {
  const out = [];
  let cur = null;
  for (const line of git(['worktree', 'list', '--porcelain', '-z'], cwd).split('\0')) {
    if (line === '') {
      if (cur) out.push(cur);
      cur = null;
      continue;
    }
    const sp = line.indexOf(' ');
    const key = sp < 0 ? line : line.slice(0, sp);
    const val = sp < 0 ? '' : line.slice(sp + 1);
    if (key === 'worktree') cur = { path: val };
    else if (!cur) continue;
    else if (key === 'HEAD') cur.head = val;
    else if (key === 'branch') cur.branch = val.replace(/^refs\/heads\//, '');
    else if (key === 'detached') cur.detached = true;
    else if (key === 'bare') cur.bare = true;
    else if (key === 'locked') cur.locked = val || true;
    else if (key === 'prunable') cur.prunable = val || true;
  }
  if (cur) out.push(cur);
  return out;
}

// The files of one checkout (main or linked worktree) to send, relative to it, with its sizes.
// nested: absolute paths of other worktrees inside it, which are moved on their own.
function checkoutFiles(top, { keep, nested = [] }) {
  const files = [];
  let trackedBytes = 0;
  for (const f of split0(git(['ls-files', '-z', '--cached'], top))) {
    const st = lstat(join(top, f));
    if (!st) continue; // deleted in the work tree: `git status` shows that from the index
    files.push(f);
    trackedBytes += st.isDirectory() ? 0 : st.size; // a directory here is a submodule
  }
  const trackedFiles = files.length;
  const tracked = new Set(files);
  const nestedRel = nested.map((p) => relative(top, p).split(sep).join('/'));

  let untrackedBytes = 0;
  let untrackedFiles = 0;
  const groups = new Map();
  for (const f of split0(git(['ls-files', '-z', '--others', '--exclude-standard'], top))) {
    const bare = f.replace(/\/$/, '');
    if (tracked.has(f) || nestedRel.some((n) => inside(bare, n, '/'))) continue;
    const st = lstat(join(top, bare));
    if (!st) continue;
    const isDir = st.isDirectory();
    const why = excludedBy(f, f.endsWith('/') || isDir || st.isSymbolicLink(), keep);
    if (why) {
      const size = isDir ? treeBytes(join(top, bare)) : { bytes: st.size, files: 1 };
      const g = groups.get(why.group) || { bytes: 0, files: 0, kind: why.kind };
      g.bytes += size.bytes;
      g.files += size.files;
      groups.set(why.group, g);
      continue;
    }
    files.push(bare);
    untrackedFiles++;
    untrackedBytes += isDir ? 0 : st.size; // a nested repo: only its directory entry goes
  }

  // .env files git ignores (names only): they stay behind too, and the user should know.
  const ignoredEnv = split0(git(['ls-files', '-z', '--others', '--ignored', '--exclude-standard', '--directory'], top))
    .filter((f) => !f.endsWith('/') && isEnvName(f))
    .filter((f) => !nestedRel.some((n) => inside(f, n, '/')));
  const left = [...groups.entries()]
    .map(([path, g]) => ({ path, ...g }))
    .sort((a, b) => b.bytes - a.bytes || a.path.localeCompare(b.path));
  const leftBuild = left.filter((g) => g.kind === 'build');
  const leftBytes = left.reduce((s, g) => s + g.bytes, 0);
  // Staged or unstaged changes to tracked files (untracked ones are counted above).
  const changed = split0(git(['status', '--porcelain', '-z', '--untracked-files=no'], top)).filter(
    (l) => /^[ MADRCUT?!]{2} /.test(l),
  ).length;
  return {
    files,
    report: {
      changed,
      tracked: { files: trackedFiles, bytes: trackedBytes },
      untracked: { files: untrackedFiles, bytes: untrackedBytes },
      leftOut: leftBuild,
      leftOutBytes: leftBuild.reduce((s, g) => s + g.bytes, 0),
      envLeftOut: [...left.filter((g) => g.kind === 'env').map((g) => g.path), ...ignoredEnv].sort(),
      envTracked: [...tracked].filter(isEnvName).sort(),
      filesBytes: trackedBytes + untrackedBytes,
      gitRuleFilesBytes: trackedBytes + untrackedBytes + leftBytes,
    },
  };
}

function safeName(s) {
  return s.replace(/[^A-Za-z0-9._-]/g, '-');
}

// The whole plan: the main checkout and each linked worktree, with where each lands on the box.
// dest: the main checkout's directory on the box. Worktrees inside the main checkout keep their
// relative path; the others go to <dest>.worktrees/<their directory name>.
// lite: only where things are, no file lists or sizes (for --list0).
export function planRepo(cwd = process.cwd(), { dest, keep = [], skip = [], lite = false } = {}) {
  const keepSet = new Set(keep);
  const common = real(resolve(cwd, git(['rev-parse', '--git-common-dir'], cwd).trim()));
  const wts = listWorktrees(cwd);
  const main = wts[0];
  if (!main || main.bare) throw new Error('a bare repository with worktrees: move each worktree by hand');
  if (basename(common) !== '.git')
    throw new Error(`the git directory ${common} is not <checkout>/.git (--separate-git-dir?): move this repo by hand`);
  const mainSrc = real(main.path);
  if (real(dirname(common)) !== mainSrc) throw new Error(`unexpected layout: ${common} is not ${mainSrc}/.git`);
  dest = (dest || `/data/workspace/${safeName(basename(mainSrc))}`).replace(/\/+$/, '');
  if (!/^\/[A-Za-z0-9._/-]+$/.test(dest)) throw new Error(`--dest ${dest}: use an absolute path of letters, digits and ._-/`);
  const skipSet = new Set(skip.map((p) => real(p)));
  const fromHere = real(git(['rev-parse', '--show-toplevel'], cwd).trim());

  // Each linked worktree's admin dir (.git/worktrees/<id>), by the checkout its gitdir file names.
  const admins = new Map();
  let ids = [];
  try {
    ids = readdirSync(join(common, 'worktrees'));
  } catch {}
  for (const id of ids) {
    let g;
    try {
      g = readFileSync(join(common, 'worktrees', id, 'gitdir'), 'utf8').trim();
    } catch {
      continue;
    }
    const wt = dirname(resolve(join(common, 'worktrees', id), g));
    admins.set(real(wt), join(common, 'worktrees', id));
    admins.set(wt, join(common, 'worktrees', id));
  }

  const linked = [];
  const used = new Set();
  for (const w of wts.slice(1)) {
    const src = real(w.path);
    const entry = {
      src,
      branch: w.branch || null,
      detached: !!w.detached,
      head: w.head || null,
      locked: w.locked || false,
      prunable: w.prunable || false,
    };
    const adminDir = admins.get(src) || admins.get(resolve(w.path)) || null;
    entry.adminDir = adminDir;
    entry.id = adminDir ? basename(adminDir) : null;
    const st = lstat(src);
    if (w.prunable || !st || !st.isDirectory()) {
      entry.move = false;
      entry.why = w.prunable ? `prunable: ${w.prunable === true ? 'missing' : w.prunable}` : 'its directory is missing';
      linked.push(entry);
      continue;
    }
    // Box paths are safe in a single-quoted shell word: [A-Za-z0-9._-/] only.
    let box = inside(src, mainSrc)
      ? `${dest}/${relative(mainSrc, src).split(sep).map(safeName).join('/')}`
      : `${dest}.worktrees/${safeName(basename(src))}`;
    for (let i = 2, b = box; used.has(box); i++) box = `${b}-${i}`;
    entry.box = box;
    used.add(entry.box);
    entry.move = !skipSet.has(src);
    if (!entry.move) entry.why = 'unchecked (--skip-worktree)';
    linked.push(entry);
  }

  const allLinked = linked.map((w) => w.src);
  const nestedOf = (top) => allLinked.filter((p) => p !== top && inside(p, top));
  if (lite) return { main: { src: mainSrc, box: dest, move: true }, worktrees: linked, nestedOf };
  const mainFiles = checkoutFiles(mainSrc, { keep: keepSet, nested: nestedOf(mainSrc) });
  const gitDir = join(mainSrc, '.git');
  // Admin dirs of worktrees that are not moved stay behind, so the box does not list them.
  const adminSkip = new Set(
    linked.filter((w) => !w.move && w.adminDir).map((w) => w.adminDir),
  );
  const gitBytes = treeBytes(real(gitDir), adminSkip).bytes;
  const nestedAbs = new Set(nestedOf(mainSrc));
  const mainDisk = treeBytes(mainSrc, nestedAbs).bytes;
  const plan = {
    from: fromHere,
    main: {
      src: mainSrc,
      box: dest,
      branch: main.branch || null,
      detached: !!main.detached,
      head: main.head || null,
      move: true,
      diskBytes: mainDisk,
      gitBytes,
      ...mainFiles.report,
      sendBytes: gitBytes + mainFiles.report.filesBytes,
    },
    worktrees: [],
  };
  for (const w of linked) {
    if (!w.adminDir && w.move !== false) {
      w.move = false;
      w.why = 'not a working git checkout';
    }
    if (w.move === false && !lstat(w.src)) {
      plan.worktrees.push(w);
      continue;
    }
    const f = checkoutFiles(w.src, { keep: keepSet, nested: nestedOf(w.src) });
    plan.worktrees.push({
      ...w,
      diskBytes: treeBytes(w.src, new Set(nestedOf(w.src))).bytes,
      ...f.report,
      sendBytes: f.report.filesBytes,
    });
  }
  delete plan.main.filesBytes;
  for (const w of plan.worktrees) delete w.adminDir;
  const moving = [plan.main, ...plan.worktrees.filter((w) => w.move)];
  plan.totals = {
    diskBytes: plan.main.diskBytes + plan.worktrees.reduce((s, w) => s + (w.diskBytes || 0), 0),
    gitRuleBytes: gitBytes + moving.reduce((s, w) => s + w.gitRuleFilesBytes, 0),
    leftOutBytes: moving.reduce((s, w) => s + w.leftOutBytes, 0),
    sendBytes: moving.reduce((s, w) => s + w.sendBytes, 0),
  };
  plan.keep = [...keepSet];
  return plan;
}

// The NUL list for one checkout: relative paths, directories included for tar --no-recursion.
export function listFor(path, { keep = [], skip = [] } = {}) {
  const plan = planRepo(path, { keep, skip, lite: true });
  const top = real(git(['rev-parse', '--show-toplevel'], path).trim());
  const isMain = top === plan.main.src;
  const w = isMain ? plan.main : plan.worktrees.find((x) => x.src === top);
  if (!w || !w.move) throw new Error(`${top} is not moved in this plan`);
  const { files } = checkoutFiles(top, { keep: new Set(keep), nested: plan.nestedOf(top) });
  if (!isMain) return ['.git', ...files];
  // The admin dirs of worktrees that stay behind (unchecked, prunable, missing) stay too.
  const skipAdmin = new Set(plan.worktrees.filter((x) => !x.move && x.adminDir).map((x) => x.adminDir));
  return [...walk(real(join(top, '.git')), '.git', skipAdmin), ...files];
}

function describe(w) {
  const at = w.detached ? `detached at ${(w.head || '').slice(0, 12)}` : w.branch ? `branch ${w.branch}` : '';
  const dirty = w.changed ? `${w.changed} uncommitted change${w.changed === 1 ? '' : 's'}` : 'no uncommitted changes';
  const flags = [at, dirty, w.locked ?`locked${w.locked === true ? '' : ': ' + w.locked}` : ''].filter(Boolean);
  return flags.join(', ');
}

export function formatPlan(p) {
  const pad = (s) => s.padStart(8);
  const L = [];
  const block = (w, title) => {
    L.push(`${title} ${w.src}`);
    L.push(`  -> ${w.box}${describe(w) ? `  (${describe(w)})` : ''}`);
    L.push(`  before: ${pad(human(w.diskBytes))} on disk, ${human(w.gitRuleFilesBytes + (w.gitBytes || 0))} by git's rule`);
    if (w.leftOut.length) {
      L.push(`  left out ${human(w.leftOutBytes)} of build output and dependencies git does not ignore:`);
      for (const g of w.leftOut.slice(0, 12))
        L.push(`      ${g.path}  ${human(g.bytes)} (${g.files} file${g.files === 1 ? '' : 's'})`);
      if (w.leftOut.length > 12) L.push(`      ... and ${w.leftOut.length - 12} more`);
    }
    if (w.envLeftOut.length) L.push(`  .env files left out (never copied): ${w.envLeftOut.join(', ')}`);
    if (w.envTracked.length) L.push(`  committed .env files (they go with .git): ${w.envTracked.join(', ')}`);
    const parts = [];
    if (w.gitBytes !== undefined) parts.push(`.git ${human(w.gitBytes)}`);
    parts.push(`${w.tracked.files} tracked ${human(w.tracked.bytes)}`);
    parts.push(`${w.untracked.files} untracked ${human(w.untracked.bytes)}`);
    L.push(`  after:  ${pad(human(w.sendBytes))} sent (${parts.join(', ')})`);
  };
  block(p.main, 'main checkout');
  for (const w of p.worktrees) {
    if (w.move) block(w, 'worktree');
    else L.push(`worktree ${w.src}  NOT moved: ${w.why}${w.sendBytes !== undefined ? ` (${human(w.sendBytes)})` : ''}`);
  }
  const n = p.worktrees.filter((w) => w.move).length;
  L.push(
    `total: ${human(p.totals.diskBytes)} on disk; git's rule ${human(p.totals.gitRuleBytes)}; left out ${human(
      p.totals.leftOutBytes,
    )}; sending ${human(p.totals.sendBytes)} (main checkout${n ? ` + ${n} worktree${n === 1 ? '' : 's'}` : ''})`,
  );
  if (p.keep.length) L.push(`copied anyway (--keep): ${p.keep.join(', ')}`);
  return L.join('\n') + '\n';
}

function main(argv) {
  const keep = [];
  const skip = [];
  let mode = 'report';
  let dest;
  let listPath;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const val = () => {
      if (argv[i + 1] === undefined) throw new Error(`${a} needs a value`);
      return argv[++i];
    };
    try {
      if (a === '--json') mode = 'json';
      else if (a === '--list0') (mode = 'list0'), (listPath = val());
      else if (a === '--dest') dest = val();
      else if (a === '--keep') keep.push(val());
      else if (a === '--skip-worktree') skip.push(val());
      else if (a === '-h' || a === '--help') {
        process.stdout.write(
          'usage: node repo-files.mjs [--dest DIR] [--json | --list0 PATH] [--skip-worktree PATH]... [--keep NAME]...\n',
        );
        return 0;
      } else throw new Error(`unknown argument ${a}`);
    } catch (e) {
      process.stderr.write(`repo-files: ${e.message}\n`);
      return 2;
    }
  }
  try {
    if (mode === 'list0') {
      process.stdout.write(listFor(listPath, { keep, skip }).map((f) => f + '\0').join(''));
      return 0;
    }
    const plan = planRepo(process.cwd(), { dest, keep, skip });
    process.stdout.write(mode === 'json' ? JSON.stringify(plan, null, 2) + '\n' : formatPlan(plan));
    return 0;
  } catch (e) {
    process.stderr.write(`repo-files: ${e.message}\n`);
    return 1;
  }
}

let isMain = false;
try {
  isMain = realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
} catch {}
if (isMain) process.exitCode = main(process.argv.slice(2));
