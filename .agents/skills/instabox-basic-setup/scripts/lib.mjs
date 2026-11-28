// Shared by the instabox-basic-setup scripts. Node >= 18, no dependencies.
//
// The one rule every function here keeps: a credential's value is never
// returned to the agent, stored in a file or printed. Code that looks at a
// secret returns names, places and sizes only.
import { spawnSync } from 'node:child_process';
import { lstatSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

// Environment variable names that hold a credential, also with a rotation or environment
// qualifier after it (OPENAI_API_KEY_2, GITHUB_TOKEN_OLD). The qualifier needs its own `_`,
// so PATH is not PAT plus H.
export const SECRET_NAME =
  /(?:^|_)(?:API_?KEY|APIKEY|KEY_?SECRET|TOKEN|ACCESS_?TOKEN|AUTH_?TOKEN|REFRESH_?TOKEN|SECRET|SECRET_?KEY|CLIENT_?SECRET|ACCESS_?KEY|ACCESS_?KEY_?ID|PASSWORD|PASSWD|PASS|PAT|PRIVATE_?KEY|CREDENTIALS?)(?:_(?:\d+|V\d+|OLD|NEW|PREV|PREVIOUS|BAK|BACKUP|ALT|PROD|PRODUCTION|DEV|STAGING|STAGE|TEST|LOCAL|CI))?$/i;

// Values that are credentials whatever they are called: token prefixes of the common
// services, private keys, and URLs with a password in them.
export const SECRET_VALUE = new RegExp(
  [
    String.raw`\bgh[pousr]_[A-Za-z0-9]{20,}`,
    String.raw`\bgithub_pat_[A-Za-z0-9_]{20,}`,
    String.raw`\bsk-[A-Za-z0-9_-]{20,}`,
    String.raw`\bAKIA[0-9A-Z]{16}\b`,
    String.raw`\bASIA[0-9A-Z]{16}\b`,
    String.raw`\bxox[abposr]-[A-Za-z0-9-]{10,}`,
    String.raw`\bglpat-[A-Za-z0-9_-]{20,}`,
    String.raw`\bnpm_[A-Za-z0-9]{30,}`,
    String.raw`\bAIza[0-9A-Za-z_-]{35}`,
    String.raw`-----BEGIN [A-Z ]*PRIVATE KEY-----`,
    String.raw`[a-z][a-z0-9+.-]*://[^/\s:@'"]+:[^@\s'"/]+@`,
  ].join('|'),
);

// key = value / key: value pairs whose key says it is a secret (config files); numbers and
// booleans are not secrets (max_tokens = 100).
export const SECRET_KEY_LINE =
  /(?:^|[\s{,;:])["']?[\w.-]*(?:token|password|passwd|secret|api[_-]?key|apikey|_auth|authorization|extraheader|private[_-]?key)[\w.-]*["']?\s*[=:]\s*["']?(?![0-9.]+\b|true\b|false\b)[^\s"',}]/i;

// The tokens this skill saves, each with the HTTPS API hosts its usual client sends it to in a
// request header. The box gets a placeholder and the outbound proxy fills in the token only for
// these hosts. A token whose client signs with it, sends it in a body or URL, or talks to hosts
// that cannot be named exactly is left out: the scan lists it as a manual step.
// FORMAT is the scan and approved-selection format. 5: proxy-only Secrets, hosts from
// TOKEN_HOSTS, GitHub tokens also for github.com (git over HTTPS). Older files approved env
// delivery or fewer hosts; they are refused, never reinterpreted, so an approval cannot widen a
// credential's reach.
export const FORMAT = 5;

export const TOKEN_HOSTS = new Map(
  Object.entries({
    GH_TOKEN: ['api.github.com', 'github.com'],
    GITHUB_TOKEN: ['api.github.com', 'github.com'],
    ANTHROPIC_API_KEY: ['api.anthropic.com'],
    OPENAI_API_KEY: ['api.openai.com'],
    GEMINI_API_KEY: ['generativelanguage.googleapis.com'],
    GOOGLE_API_KEY: ['generativelanguage.googleapis.com'],
    GOOGLE_GENERATIVE_AI_API_KEY: ['generativelanguage.googleapis.com'],
    OPENROUTER_API_KEY: ['openrouter.ai'],
    GROQ_API_KEY: ['api.groq.com'],
    MISTRAL_API_KEY: ['api.mistral.ai'],
    DEEPSEEK_API_KEY: ['api.deepseek.com'],
    XAI_API_KEY: ['api.x.ai'],
    TOGETHER_API_KEY: ['api.together.ai', 'api.together.xyz'],
    FIREWORKS_API_KEY: ['api.fireworks.ai'],
    PERPLEXITY_API_KEY: ['api.perplexity.ai'],
    COHERE_API_KEY: ['api.cohere.ai', 'api.cohere.com'],
    VOYAGE_API_KEY: ['api.voyageai.com'],
    REPLICATE_API_TOKEN: ['api.replicate.com'],
    ELEVENLABS_API_KEY: ['api.elevenlabs.io'],
    TAVILY_API_KEY: ['api.tavily.com'],
    EXA_API_KEY: ['api.exa.ai'],
    FIRECRAWL_API_KEY: ['api.firecrawl.dev'],
    BRAVE_API_KEY: ['api.search.brave.com'],
    HF_TOKEN: ['huggingface.co', 'router.huggingface.co'],
    HUGGING_FACE_HUB_TOKEN: ['huggingface.co', 'router.huggingface.co'],
    NPM_TOKEN: ['registry.npmjs.org'],
    VERCEL_TOKEN: ['api.vercel.com'],
    NETLIFY_AUTH_TOKEN: ['api.netlify.com'],
    CLOUDFLARE_API_TOKEN: ['api.cloudflare.com'],
    SUPABASE_ACCESS_TOKEN: ['api.supabase.com'],
    RENDER_API_KEY: ['api.render.com'],
    NEON_API_KEY: ['console.neon.tech'],
    SENTRY_AUTH_TOKEN: ['sentry.io'],
    LINEAR_API_KEY: ['api.linear.app'],
    GITLAB_TOKEN: ['gitlab.com'],
    DIGITALOCEAN_ACCESS_TOKEN: ['api.digitalocean.com'],
  }),
);

// Reserved Secret variable names (internal/secrets/validate.go).
const RESERVED = new Set([
  'HOME',
  'PATH',
  'USER',
  'LOGNAME',
  'SHELL',
  'TERM',
  'XDG_RUNTIME_DIR',
  'DBUS_SESSION_BUS_ADDRESS',
  'SSL_CERT_FILE',
  'SSL_CERT_DIR',
  'REQUESTS_CA_BUNDLE',
  'CURL_CA_BUNDLE',
  'NODE_EXTRA_CA_CERTS',
]);
export function secretNameOK(name) {
  return (
    /^[A-Za-z_][A-Za-z0-9_]*$/.test(name) &&
    name.length <= 128 &&
    !RESERVED.has(name) &&
    !name.startsWith('INSTABOX_') &&
    !name.startsWith('SSH_')
  );
}

export const isSecretName = (name) => SECRET_NAME.test(name);

// Lines in macOS configs that mean nothing on the Linux box.
export const MACOS_ONLY =
  /\/opt\/homebrew|\/usr\/local\/Cellar|\/usr\/local\/Homebrew|\/Applications\/|\/Library\/|\bosxkeychain\b|\bUseKeychain\b|\bpbcopy\b|\bpbpaste\b|\bosascript\b|\breattach-to-user-namespace\b|\bterminal-notifier\b|\bafplay\b|\/System\/|\.orbstack\/|1password.*agent\.sock|\bsecurity (?:find|add)-[a-z-]*password\b/i;

// Org Secret limits; the server may override these in .limits.vault (legacy wire name).
export const SECRET_MAX_VALUE = 64 * 1024;
export const SECRET_MAX_TOTAL = 256 * 1024;
export const SECRET_MAX_ITEMS = 100;

export const FILE_MAX_VALUE = 64 * 1024;
export const FILE_MAX_TOTAL = 512 * 1024;
export const BOX_HOME = '/data/home';

// Runs a command without a shell; never throws. stdout is returned to the caller only:
// callers that run credential tools (gh auth token) must not keep or print it.
export function run(argv, { cwd, env, input, timeout = 30_000 } = {}) {
  const r = spawnSync(argv[0], argv.slice(1), {
    cwd,
    env,
    input,
    timeout,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    stdio: [input === undefined ? 'ignore' : 'pipe', 'pipe', 'pipe'],
  });
  return { ok: r.status === 0 && !r.error, status: r.status, stdout: r.stdout || '', stderr: r.stderr || '' };
}

export function hasCommand(name, env) {
  for (const dir of (env?.PATH || '').split(':')) {
    if (!dir) continue;
    try {
      const st = lstatSync(join(dir, name));
      if (st.isFile() || st.isSymbolicLink()) return true;
    } catch {}
  }
  return false;
}

// stat, following symlinks (dotfiles are often links into a dotfiles repo), or null.
export function statOrNull(p) {
  try {
    return statSync(p);
  } catch {
    return null;
  }
}

// Every regular file under dir (symlinks followed), as paths relative to it, sorted.
export function listFiles(dir, skip = () => false, rel = '', depth = 0) {
  const out = [];
  if (depth > 8) return out;
  let names = [];
  try {
    names = readdirSync(join(dir, rel)).sort();
  } catch {
    return out;
  }
  for (const n of names) {
    if (skip(n)) continue;
    const r = rel ? `${rel}/${n}` : n;
    const st = statOrNull(join(dir, r));
    if (!st) continue;
    if (st.isDirectory()) out.push(...listFiles(dir, skip, r, depth + 1));
    else if (st.isFile()) out.push(r);
  }
  return out;
}

export function readText(p) {
  try {
    return readFileSync(p, 'utf8');
  } catch {
    return null;
  }
}

export function human(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const u = ['KB', 'MB', 'GB'];
  let v = bytes / 1024;
  let i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v >= 10 ? Math.round(v) : v.toFixed(1)} ${u[i]}`;
}

// Paths are relative to the guest home. Config copying never follows symlinks.
export function configPathOK(p) {
  if (typeof p !== 'string' || !p || p.startsWith('/') || p.length > 255 || /[\x00-\x1f\x7f\\]/.test(p)) return false;
  return p.split('/').every((c) => c !== '' && c !== '.' && !c.startsWith('..'));
}

export function validID(s) {
  return typeof s === 'string' && /^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(s);
}
export function secretIdentity(s) {
  return {
    id: s.id,
    name: s.name,
    orgId: s.orgId,
    version: s.version,
    hosts: [...(s.hosts || [])].sort(),
  };
}
export function sameSecret(a, b) {
  return !!a && !!b && JSON.stringify(secretIdentity(a)) === JSON.stringify(secretIdentity(b));
}

// True when the module is the script node was started with (not imported by a test).
export function isMain(meta) {
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(meta.url));
  } catch {
    return false;
  }
}
