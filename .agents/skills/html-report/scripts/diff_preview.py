"""Renders commits as syntax-highlighted diffs into a report built from the html-report template.

Usage:
  python3 -I diff_preview.py --repo <path> --base <ref> --html report.html [--md report.md]
                             [--trim path/to/Generated.kt=40 ...]

Every commit in <base>..HEAD becomes an expandable section (oldest first) with its message and per-file diffs.
Each commit hash links to the commit on GitHub in a new tab (the link 404s until the commit is pushed). Identifiers
in commit messages (camelCase, PascalCase, calls, file names) are wrapped in <code>.
Content between the change-preview markers is replaced, so the script can be rerun after new commits. Without
markers the section is appended at the end of <main> (HTML) or the file (Markdown). Table cells holding a
commit hash as <code>hash</code> are turned into links to its section.
"""
import argparse
import html
import re
import subprocess

COMMIT_URL = ""  # "https://github.com/<owner>/<repo>/commit/", filled from --commit-url or the git remote
TRIM = {}  # path -> max diff lines shown, filled from --trim
START, END = "<!-- change-preview:start -->", "<!-- change-preview:end -->"

KEYWORDS = set("""
as break class continue do else false for fun if in interface is null object package return super this throw true
try typealias val var when while by catch constructor delegate dynamic field file finally get import init param
property receiver set setparam where actual abstract annotation companion const crossinline data enum expect
external final infix inline inner internal lateinit noinline open operator out override private protected public
reified sealed suspend tailrec vararg def
""".split())

TOKEN = re.compile(
    r'(?P<comment>//.*$)'
    r'|(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])\')'
    r'|(?P<annotation>@[A-Za-z_][\w.]*)'
    r'|(?P<number>\b\d[\d_]*(?:\.\d+)?[fFL]?\b)'
    r'|(?P<word>\b[A-Za-z_]\w*\b)'
)


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True, text=True).stdout


def highlight(code):
    stripped = code.lstrip()
    if stripped.startswith(("/*", "*", "*/")):
        return f'<span class="t-c">{html.escape(code)}</span>'
    out, pos = [], 0
    for m in TOKEN.finditer(code):
        out.append(html.escape(code[pos:m.start()]))
        kind, text = m.lastgroup, m.group()
        if kind == "word":
            if text in KEYWORDS:
                kind = "k"
            elif text[0].isupper():
                kind = "ty"
            else:
                out.append(html.escape(text))
                pos = m.end()
                continue
        cls = {"comment": "c", "string": "s", "annotation": "a", "number": "n"}.get(kind, kind)
        out.append(f'<span class="t-{cls}">{html.escape(text)}</span>')
        pos = m.end()
    out.append(html.escape(code[pos:]))
    return "".join(out)


def parse_files(diff):
    """Yields (path, hunks) where hunks is a list of (header, lines)."""
    files = []
    for block in re.split(r"^diff --git ", diff, flags=re.M)[1:]:
        lines = block.split("\n")
        path = None
        hunks = []
        for line in lines:
            if line.startswith("+++ "):
                path = line[6:] if line != "+++ /dev/null" else None
            elif line.startswith("--- ") and path is None:
                old = line[6:]
                path = old if old != "/dev/null" else path
            elif line.startswith("@@"):
                hunks.append((line, []))
            elif hunks and (line[:1] in ("+", "-", " ") or line == ""):
                hunks[-1][1].append(line)
        if path is None:
            path = lines[0].split(" b/")[-1]
        while hunks and hunks[-1][1] and hunks[-1][1][-1] == "":
            hunks[-1][1].pop()
        files.append((path, hunks))
    return files


CODE = re.compile(
    r"`([^`]+)`"
    r"|(?<![\w.])((?:[a-z][a-z0-9]*[A-Z]\w*|[A-Z][a-z0-9]+[A-Z]\w*|\w+\(\)|\w+\.(?:kt|kts|xml|gradle|java|json|md))(?:\.\w+)*)(?![\w])"
)


def with_code(text):
    """Escapes text and wraps code-like words (and anything already in backticks) in <code>."""
    out, pos = [], 0
    for m in CODE.finditer(text):
        out.append(html.escape(text[pos:m.start()]))
        out.append(f"<code>{html.escape(m.group(1) or m.group(2))}</code>")
        pos = m.end()
    out.append(html.escape(text[pos:]))
    return "".join(out)


def commit_url(repo):
    """GitHub commit URL prefix from the upstream remote, falling back to origin."""
    for remote in ("upstream", "origin"):
        try:
            url = git(repo, "remote", "get-url", remote).strip()
        except subprocess.CalledProcessError:
            continue
        m = re.search(r"github\.com[:/](.+?)(?:\.git)?$", url)
        if m:
            return f"https://github.com/{m.group(1)}/commit/"
    return ""


def render_html(commits):
    parts = []
    for c in commits:
        files = parse_files(c["diff"])
        body = "</p><p class=\"note\">".join(with_code(p).replace("\n", " ") for p in c["body"].split("\n\n"))
        href = f'{COMMIT_URL}{c["hash"]}'
        hash_html = (
            f'<a class="hash" href="{href}" target="_blank" rel="noopener" title="Open on GitHub">'
            f'<code>{c["hash"]}</code></a>'
            if COMMIT_URL else f'<code class="hash">{c["hash"]}</code>'
        )
        parts.append(f'<details class="commit" id="c-{c["hash"]}">')
        parts.append(
            f'<summary>{hash_html}{with_code(c["subject"])}'
            f'<span class="stat">{html.escape(c["stat"])}</span></summary>'
        )
        parts.append(f'<p class="note">{body}</p>')
        for path, hunks in files:
            parts.append(f'<div class="file"><div class="path">{html.escape(path)}</div><table class="diff">')
            budget = TRIM.get(path)
            shown = 0
            skipped = 0
            for header, lines in hunks:
                m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)", header)
                old, new = int(m.group(1)), int(m.group(2))
                if budget is not None and shown >= budget:
                    skipped += len(lines)
                    continue
                parts.append(f'<tr class="hunk"><td></td><td></td><td>{html.escape(header)}</td></tr>')
                for line in lines:
                    if budget is not None and shown >= budget:
                        skipped += 1
                        continue
                    shown += 1
                    sign, code = (line[:1] or " "), line[1:]
                    if sign == "+":
                        parts.append(f'<tr class="add"><td></td><td>{new}</td><td><span class="sign">+</span>{highlight(code)}</td></tr>')
                        new += 1
                    elif sign == "-":
                        parts.append(f'<tr class="del"><td>{old}</td><td></td><td><span class="sign">-</span>{highlight(code)}</td></tr>')
                        old += 1
                    else:
                        parts.append(f'<tr><td>{old}</td><td>{new}</td><td><span class="sign"> </span>{highlight(code)}</td></tr>')
                        old += 1
                        new += 1
            if skipped:
                parts.append(f'<tr class="hunk"><td></td><td></td><td>… {skipped} more lines, trimmed</td></tr>')
            parts.append("</table></div>")
        parts.append("</details>")
    return "\n".join(parts)


def render_md(commits):
    parts = []
    for c in commits:
        parts.append(f'### `{c["hash"]}` {c["subject"]}\n\n{c["body"]}\n')
        for path, hunks in parse_files(c["diff"]):
            lines = []
            for header, hunk in hunks:
                lines.append(header)
                lines.extend(hunk)
            limit = TRIM.get(path)
            if limit is not None and len(lines) > limit:
                extra = len(lines) - limit
                lines = lines[:limit] + [f"# … {extra} more lines, trimmed"]
            parts.append(f"`{path}`\n\n```diff\n" + "\n".join(lines) + "\n```\n")
    return "\n".join(parts)








def replace_between(text, new):
    if START in text:
        head, rest = text.split(START, 1)
        _, tail = rest.split(END, 1)
        return head + START + "\n" + new + "\n" + END + tail
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base", required=True, help="commits in <base>..HEAD are rendered")
    parser.add_argument("--html", required=True)
    parser.add_argument("--head", default="HEAD", help="commits in <base>..<head> are rendered")
    parser.add_argument("--commit-url", help="commit URL prefix, default from the upstream or origin remote")
    parser.add_argument("--md")
    parser.add_argument("--trim", action="append", default=[], help="path or path=N, limits the diff lines shown")
    args = parser.parse_args()
    global COMMIT_URL
    COMMIT_URL = args.commit_url or commit_url(args.repo)
    for item in args.trim:
        path, _, limit = item.partition("=")
        TRIM[path] = int(limit) if limit else 40

    commits = []
    for line in git(args.repo, "log", "--reverse", "--format=%h", f"{args.base}..{args.head}").split():
        commits.append({
            "hash": line,
            "subject": git(args.repo, "log", "-1", "--format=%s", line).strip(),
            "body": git(args.repo, "log", "-1", "--format=%b", line).strip(),
            "stat": git(args.repo, "show", "--shortstat", "--format=", line).strip(),
            "diff": git(args.repo, "show", "--format=", "-U3", "--no-color", line),
        })

    page = open(args.html).read()
    section = (
        '<h2 id="change-preview">Change preview</h2>\n'
        '<p class="note">Every commit, oldest first. Click a commit to expand it, or its hash to open it on GitHub. Hashes in the report tables jump here.</p>\n' + render_html(commits)
    )
    replaced = replace_between(page, section)
    if replaced is None:
        replaced = page.replace("</main>", START + "\n" + section + "\n" + END + "\n</main>", 1)
    for c in commits:
        replaced = replaced.replace(
            f"<td><code>{c['hash']}</code></td>", f'<td><a href="#c-{c["hash"]}"><code>{c["hash"]}</code></a></td>'
        )
    open(args.html, "w").write(replaced)

    if args.md:
        md = open(args.md).read()
        md_section = "## Change preview\n\nEvery commit, oldest first.\n\n" + render_md(commits)
        md_replaced = replace_between(md, md_section)
        if md_replaced is None:
            md_replaced = md.rstrip("\n") + "\n\n" + START + "\n" + md_section + "\n" + END + "\n"
        open(args.md, "w").write(md_replaced)


if __name__ == "__main__":
    main()
