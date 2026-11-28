// What a directly copied configuration file becomes: the local file with this
// machine's HOME rewritten to the box's, lines that look like credentials
// removed and macOS-only lines commented out. ~/.gitconfig also gets a few
// changes so git works on a box that has no signing or SSH key.
//
// Used by plan.mjs (for sizes) and push.mjs (for the upload). Nothing here
// prints a file's content.
import { readFileSync } from 'node:fs';
import { basename, extname } from 'node:path';
import { BOX_HOME, MACOS_ONLY, SECRET_KEY_LINE, SECRET_VALUE } from './lib.mjs';

const TAG = '[instabox-basic-setup]';

function commentStyle(path) {
  const b = basename(path);
  const e = extname(path);
  if (e === '.lua') return '--';
  if (e === '.vim' || b === '.vimrc' || b === '.gvimrc') return '"';
  return '#';
}

const isComment = (line) => /^\s*(?:#|;|--|")/.test(line);

// Filters one text file. Returns the new text and how many lines were changed.
export function scrubText(text, { path, home }) {
  const c = commentStyle(path);
  let secrets = 0;
  let macos = 0;
  const out = text.split('\n').map((line) => {
    if (SECRET_VALUE.test(line) || (SECRET_KEY_LINE.test(line) && !isComment(line))) {
      secrets++;
      return `${c} ${TAG} removed a line that looked like a credential`;
    }
    if (MACOS_ONLY.test(line) && !isComment(line)) {
      macos++;
      return `${c} ${TAG} macOS only: ${line.trim()}`;
    }
    return home ? line.split(home).join(BOX_HOME) : line;
  });
  return { text: out.join('\n'), secrets, macos };
}

// ~/.gitconfig for the box. Changes, besides scrubText's:
//  - commit/tag signing is turned off: the signing key (GPG, SSH, 1Password) is not on the box;
//  - url.<ssh>.insteadOf rewrites are commented out: the box has no SSH key, and they would
//    send HTTPS remotes over SSH.
export function gitconfigText(text, { home }) {
  const r = scrubText(text, { path: '.gitconfig', home });
  let section = '';
  let signing = 0;
  let insteadOf = 0;
  const lines = r.text.split('\n').map((line) => {
    const h = line.match(/^\s*\[([^\]]*)\]/);
    if (h) section = h[1].trim();
    if (isComment(line)) return line;
    if (/^\s*gpgsign\s*=\s*(?:true|yes|on|1)\s*$/i.test(line)) {
      signing++;
      return `# ${TAG} signing off (no signing key on the box): ${line.trim()}`;
    }
    if (/^\s*(?:push)?insteadof\s*=/i.test(line) && /^url\s+"(?:git@|ssh:\/\/)/i.test(section)) {
      insteadOf++;
      return `# ${TAG} no SSH key on the box: ${line.trim()}`;
    }
    return line;
  });
  return { text: lines.join('\n'), secrets: r.secrets, macos: r.macos, signing, insteadOf };
}

// The content of one file of a file item, or {error}. f: {path, src, transform}.
export function fileContent(f, { home } = {}) {
  let buf;
  try {
    buf = readFileSync(f.src);
  } catch (e) {
    return { error: `${f.src}: ${e.code || 'unreadable'}` };
  }
  if (buf.includes(0)) return { error: `${f.src}: a binary file (config copying supports UTF-8 text only)` };
  const text = buf.toString('utf8');
  if (!Buffer.from(text).equals(buf)) return { error: `${f.src}: invalid UTF-8 text` };
  if (f.transform === 'gitconfig') return gitconfigText(text, { home });
  if (f.transform === 'raw') {
    if (SECRET_VALUE.test(text) || text.split('\n').some((line) => SECRET_KEY_LINE.test(line)))
      return { error: `${f.src}: possible credential in structured config; review it separately` };
    return { text, secrets: 0, macos: 0 };
  }
  return scrubText(text, { path: f.path, home });
}
