#!/usr/bin/env node
// Save reviewed org Secrets for their registry hosts, select them for named sandboxes, and copy
// ordinary config files separately. Credential values are held only in memory/stdin.
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileContent } from './content.mjs';
import {
  SECRET_MAX_ITEMS,
  SECRET_MAX_TOTAL,
  SECRET_MAX_VALUE,
  FILE_MAX_VALUE,
  FILE_MAX_TOTAL,
  configPathOK,
  FORMAT,
  TOKEN_HOSTS,
  human,
  isMain,
  run,
  sameSecret,
  secretIdentity,
  secretNameOK,
  validID,
} from './lib.mjs';
import { MANIFEST, readManifest } from './plan.mjs';
import { SHELL_RC } from './scan.mjs';

const shellFor = (file) => (/\/\.z[^/]*$/.test(file) && spawnSync('zsh', ['-c', 'true']).status === 0 ? 'zsh' : 'bash');

const NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

// The values of some variables a shell startup file exports, sourcing it once: {name: value}.
// Never logged. The file is sourced the way a shell does, its output discarded, and only the
// variables are printed (NUL-separated: a shell variable cannot hold a NUL). Names still unset
// after that get one more try in an interactive shell, for rc files that start with the usual
// `case $- in *i*)` / `[[ -o interactive ]] || return` guard; that shell reads no startup file
// of its own, so nothing it prints reaches the output.
export function readRc(file, names, env = process.env) {
  const got = {};
  const zsh = shellFor(file) === 'zsh';
  for (const interactive of [false, true]) {
    const want = names.filter((n) => NAME.test(n) && !got[n]);
    if (!want.length) break;
    const flags = interactive ? (zsh ? ['-f', '-i'] : ['--norc', '--noprofile', '-i']) : [];
    const script = `. "$1" >/dev/null 2>&1 </dev/null; printf '%s\\0' ${want.map((n) => `"\${${n}-}"`).join(' ')}`;
    const r = spawnSync(zsh ? 'zsh' : 'bash', [...flags, '-c', script, 'instabox-basic-setup', file], {
      env,
      encoding: 'utf8',
      timeout: 30_000,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const vals = (r.stdout || '').split('\0');
    want.forEach((n, i) => {
      if (vals[i]) got[n] = vals[i];
    });
  }
  return got;
}

// The value of one token, or {error}. Never logged. rc: {file: {name: value}} already read by
// readRc, so a file holding several tokens is sourced once.
export function readValue(src, env = process.env, rc = {}) {
  try {
    switch (src.type) {
      case 'env':
        return env[src.name] ? { value: env[src.name] } : { error: `${src.name} is not set in this environment` };
      case 'rc': {
        if (!NAME.test(src.name)) return { error: 'bad name' };
        const v = (rc[src.file] ?? readRc(src.file, [src.name], env))[src.name];
        if (v) return { value: v };
        // The shell this runs from may have it already (an rc that returned early, or set it some other way).
        if (env[src.name]) return { value: env[src.name] };
        return {
          error: `${src.name} is not set after sourcing ${src.file} (also tried as an interactive shell), nor in this environment`,
        };
      }
      case 'cmd': {
        const r = run(src.argv, { env });
        const v = r.stdout.replace(/\n$/, '');
        return r.ok && v ? { value: v } : { error: `\`${src.argv.join(' ')}\` failed (exit ${r.status})` };
      }
    }
  } catch (e) {
    return { error: e.code || 'unreadable' };
  }
  return { error: `unknown source ${src.type}` };
}

const INSTALL = readFileSync(new URL('./install-files.py', import.meta.url), 'utf8');
const quote = (s) => "'" + s.replaceAll("'", "'\"'\"'") + "'";
const unique = (values) => [...new Set(values)].sort();

function saveManifest(path, manifest) {
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  const temporary = `${path}.${randomBytes(8).toString('hex')}.tmp`;
  writeFileSync(temporary, JSON.stringify(manifest, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  renameSync(temporary, path);
}

function validSource(it, home) {
  const s = it.source;
  if (!s) return false;
  if (s.type === 'cmd')
    return JSON.stringify(s.argv) === JSON.stringify(['gh', 'auth', 'token', '--hostname', 'github.com']);
  if (s.name !== it.name) return false;
  return s.type === 'env' || (s.type === 'rc' && SHELL_RC.some((f) => join(home, f) === s.file));
}

function checkSelection(sel) {
  if (sel.version !== FORMAT || Object.hasOwn(sel, 'selector'))
    throw new Error('this selection was approved in an older format; scan and approve a new org Secret plan');
  if (
    !validID(sel.orgId) ||
    !Array.isArray(sel.sandboxes) ||
    sel.sandboxes.some((id) => !validID(id) || !id.startsWith('m_')) ||
    unique(sel.sandboxes).length !== sel.sandboxes.length
  )
    throw new Error('an explicit org ID and distinct sandbox IDs are required');
  if (!Array.isArray(sel.items) || typeof sel.home !== 'string') throw new Error('invalid selection');
  const ids = new Set(),
    names = new Set(),
    paths = new Set();
  for (const it of sel.items) {
    if (ids.has(it.id)) throw new Error('duplicate selection ID');
    ids.add(it.id);
    if (it.kind === 'env') {
      if (
        !TOKEN_HOSTS.has(it.name) ||
        !secretNameOK(it.name) ||
        names.has(it.name) ||
        !validSource(it, sel.home) ||
        !Object.hasOwn(it, 'expected')
      )
        throw new Error('invalid Secret selection or source');
      names.add(it.name);
    } else if (it.kind === 'file') {
      if (!sel.sandboxes.length || !Array.isArray(it.files))
        throw new Error('config copying needs explicit sandbox IDs');
      for (const f of it.files) {
        if (!configPathOK(f.path) || paths.has(f.path) || !['text', 'raw', 'gitconfig'].includes(f.transform))
          throw new Error('invalid or duplicate config target');
        paths.add(f.path);
      }
    } else throw new Error('unknown selection kind');
  }
}

export function push(
  sel,
  {
    instabox = 'instabox',
    env = process.env,
    dryRun = false,
    manifestPath = MANIFEST,
    log = (s) => console.log(s),
  } = {},
) {
  const results = [];
  const fail = (message, code = 1, totals) => {
    log(message);
    return { ok: false, code, results, totals };
  };
  const json = (args) => {
    const response = run([instabox, ...args, '--json'], { env });
    if (!response.ok)
      throw new Error(`${args.slice(0, 2).join(' ')} failed; check sign-in, permissions and the selected org/sandbox`);
    try {
      return JSON.parse(response.stdout);
    } catch {
      throw new Error('CLI returned invalid metadata; update the CLI and retry');
    }
  };
  let secrets, targets;
  try {
    checkSelection(sel);
    if (env.INSTABOX_API_KEY && sel.items.some((it) => it.kind === 'env'))
      throw new Error('saving Secret values requires a signed-in org owner/admin session, not an API key');
    const org = json(['org', 'get', sel.orgId]);
    if (org.id !== sel.orgId) throw new Error('use the stable org ID, not a name');
    if (sel.items.some((it) => it.kind === 'env') && !['owner', 'admin'].includes(org.role))
      throw new Error('saving Secrets requires an org owner/admin sign-in');
    secrets = json(['secrets', 'ls', '--org', sel.orgId]).items;
    if (!Array.isArray(secrets) || secrets.some((s) => s.orgId !== sel.orgId))
      throw new Error('Secret catalog belongs to another org');
    for (const it of sel.items.filter((it) => it.kind === 'env')) {
      const current = secrets.find((s) => s.name === it.name);
      if (it.expected ? !sameSecret(it.expected, current) : current)
        throw new Error(`${it.name} changed since the plan; regenerate and review before replacing it`);
    }
    targets = sel.sandboxes.map((id) => {
      const box = json(['get', id]);
      if (box.id !== id || box.orgId !== sel.orgId)
        throw new Error('target sandbox does not belong to the selected org');
      if (sel.items.some((it) => it.kind === 'file') && box.state !== 'running')
        throw new Error(`${id}: start the sandbox before copying config files`);
      const selection = json(['secrets', 'show', id]);
      if (selection.secrets !== 'all' && !Array.isArray(selection.secrets))
        throw new Error('sandbox returned invalid Secret selections');
      return box;
    });
  } catch (e) {
    return fail(e.message);
  }

  let maxItems = SECRET_MAX_ITEMS,
    maxBytes = SECRET_MAX_TOTAL;
  try {
    const limits = json(['usage']).limits?.vault;
    if (limits?.maxItems) maxItems = limits.maxItems;
    if (limits?.maxBytes) maxBytes = limits.maxBytes;
  } catch {
    return fail('could not read Secret limits; nothing written');
  }

  const tokens = [],
    files = [];
  const rcNames = new Map(),
    rcValues = new Map();
  for (const it of sel.items)
    if (it.kind === 'env' && it.source.type === 'rc') {
      rcNames.set(it.source.file, [...(rcNames.get(it.source.file) || []), it.name]);
    }
  for (const it of sel.items) {
    if (it.kind === 'env') {
      if (it.source.type === 'rc' && !rcValues.has(it.source.file))
        rcValues.set(it.source.file, readRc(it.source.file, rcNames.get(it.source.file), env));
      const got = readValue(it.source, env, Object.fromEntries(rcValues));
      const value = got.value;
      if (
        got.error ||
        typeof value !== 'string' ||
        value.includes('\0') ||
        Buffer.byteLength(value) > SECRET_MAX_VALUE ||
        /[\x00-\x08\x0a-\x1f\x7f]/.test(value)
      )
        return fail(`${it.name}: could not prepare a valid header value; nothing written`);
      tokens.push({ item: it, hosts: TOKEN_HOSTS.get(it.name), value });
    } else {
      for (const f of it.files) {
        const got = fileContent(f, { home: sel.home });
        if (got.error || Buffer.byteLength(got.text) > FILE_MAX_VALUE)
          return fail(`~/${f.path}: config could not be prepared; nothing written`);
        files.push({ path: f.path, text: got.text });
      }
    }
  }
  const replaced = new Set(tokens.map((t) => t.item.name));
  const staying = secrets.filter((s) => !replaced.has(s.name));
  const totals = {
    items: staying.length + tokens.length,
    maxItems,
    bytes:
      staying.reduce((sum, s) => sum + (s.size || 0), 0) +
      tokens.reduce((sum, t) => sum + Buffer.byteLength(t.value), 0),
    maxBytes,
  };
  if (totals.items > maxItems || totals.bytes > maxBytes)
    return fail(
      `over the org Secret limits, nothing written: ${totals.items} items of ${maxItems}, ${human(totals.bytes)} of ${human(maxBytes)}`,
      3,
      totals,
    );
  const fileInput = JSON.stringify({ files });
  if (
    files.reduce((sum, f) => sum + Buffer.byteLength(f.text), 0) > FILE_MAX_TOTAL ||
    Buffer.byteLength(fileInput) > 1024 * 1024
  )
    return fail('config copies exceed the transfer limit; nothing written', 3, totals);

  const manifest = readManifest(manifestPath);
  let ok = true;
  for (const { item, hosts, value } of tokens) {
    const r = {
      name: item.name,
      kind: 'secret',
      hosts,
      bytes: Buffer.byteLength(value),
      status: dryRun ? 'would save' : 'failed',
    };
    results.push(r);
    if (!dryRun) {
      const args = [
        instabox,
        'secrets',
        'set',
        item.name,
        '--org',
        sel.orgId,
        ...hosts.flatMap((h) => ['--host', h]),
        '--json',
      ];
      const response = run(args, { env, input: value + '\n' });
      try {
        const saved = response.ok && JSON.parse(response.stdout);
        if (
          !saved ||
          saved.name !== item.name ||
          saved.orgId !== sel.orgId ||
          !saved.id ||
          !Number.isSafeInteger(saved.version) ||
          JSON.stringify(unique(saved.hosts || [])) !== JSON.stringify(unique(hosts))
        )
          throw new Error();
        r.status = 'saved';
        manifest.secrets = manifest.secrets.filter((m) => m.orgId !== sel.orgId || m.name !== item.name);
        manifest.secrets.push(secretIdentity(saved));
      } catch {
        ok = false;
      }
    }
    log(
      `${r.status} ${item.name} (for ${hosts.join(',')}, ${r.bytes} bytes) in ${sel.orgId}`,
    );
  }
  if (!dryRun && tokens.length) saveManifest(manifestPath, manifest);
  if (!ok)
    return fail(
      'some Secrets could not be saved; sandbox selections and config files were not changed; saved Secrets remain in the org',
      1,
      totals,
    );

  for (const box of targets) {
    const result = { sandboxId: box.id, kind: 'sandbox', status: dryRun ? 'would configure' : 'failed' };
    results.push(result);
    if (dryRun) {
      log(
        `would update explicit Secret selections and copy ${files.length} config files to ${box.id}; existing selections are preserved`,
      );
      continue;
    }
    try {
      if (tokens.length) {
        const current = json(['secrets', 'show', box.id]);
        if (current.secrets !== 'all') {
          const names = unique([...current.secrets, ...tokens.map((t) => t.item.name)]);
          json(['secrets', 'select', box.id, '--secrets', JSON.stringify(names)]);
        }
        if (box.state === 'running') {
          const refreshed = json(['secrets', 'push', box.id]);
          if (refreshed.guest?.state !== 'applied')
            throw new Error('the box has not applied the Secret selection; inspect secrets show and retry');
        }
      }
      if (files.length) {
        const response = run([instabox, 'exec', box.id, '--stdin', '--', 'python3 -c ' + quote(INSTALL)], {
          env,
          input: fileInput,
        });
        const marker = 'INSTABOX-BASIC-SETUP ';
        const at = response.stdout.lastIndexOf(marker);
        let copied;
        try {
          copied = JSON.parse(response.stdout.slice(at + marker.length).split('\n')[0]).files;
        } catch {}
        if (
          at < 0 ||
          !Array.isArray(copied) ||
          copied.length !== files.length ||
          new Set(copied.map((f) => f.path)).size !== files.length ||
          copied.some((f) => !files.some((want) => want.path === f.path) || !['written', 'failed'].includes(f.status))
        )
          throw new Error('config copy returned no valid outcome');
        for (const f of copied) {
          const r = { sandboxId: box.id, kind: 'file', path: f.path, status: f.status };
          results.push(r);
          log(`${r.status} ${box.id}: ~/${f.path}`);
          if (f.status === 'written' && !manifest.files.some((m) => m.sandboxId === box.id && m.path === f.path))
            manifest.files.push({ sandboxId: box.id, path: f.path });
        }
        if (!response.ok || copied.some((f) => f.status !== 'written'))
          throw new Error('some config files could not be copied (check existing paths and symlinks)');
      }
      result.status = 'configured';
      log(
        `configured ${box.id}${box.state === 'running' ? '; existing application processes may need a restart' : '; the Secret selection applies at the next start'}`,
      );
    } catch (e) {
      ok = false;
      log(`failed ${box.id}: ${e.message}`);
    }
  }
  if (!dryRun && targets.length) saveManifest(manifestPath, manifest);
  return { ok, code: ok ? 0 : 1, results, totals };
}

function main() {
  const args = process.argv.slice(2),
    at = args.indexOf('--selection');
  if (at < 0 || !args[at + 1]) {
    process.stderr.write('usage: push.mjs --selection selection.json [--dry-run]\n');
    process.exit(2);
  }
  const file = args[at + 1];
  args.splice(at, 2);
  if (args.some((arg) => arg !== '--dry-run')) {
    process.stderr.write('unknown push arguments\n');
    process.exit(2);
  }
  const selection = JSON.parse(readFileSync(file, 'utf8'));
  const result = push(selection, {
    dryRun: args.includes('--dry-run'),
    instabox: process.env.INSTABOX_BIN || 'instabox',
  });
  if (result.totals)
    console.log(
      `Org Secrets after this: ${result.totals.items} of ${result.totals.maxItems}, ${human(result.totals.bytes)} of ${human(result.totals.maxBytes)}. Config files use no Secret quota.`,
    );
  if (selection.leftover?.length)
    console.log(
      `Previously saved and left unchanged: ${selection.leftover.join(' ')}. Remove only if intended: instabox secrets rm --yes NAME --org ORG.`,
    );
  process.exit(result.code);
}
if (isMain(import.meta)) main();
