---
name: html-report
description: "Builds a self-contained HTML report (side contents menu, light/dark theme switch, full-screen reader mode, syntax-highlighted change previews) from findings, measurements or a branch's commits. Use when the user asks for an HTML report, a shareable write-up of an investigation, or a report with a change preview of commits."
---

# HTML report

One self-contained HTML file: no external fonts, scripts or CDNs, so it opens offline and can be attached or
archived. The template in `assets/report-template.html` provides the chrome; you only write the body.

What the template gives every report:
- **Side contents menu** built from `<h2>` and `<h3>` (headings inside `<details>` are skipped), with the
  section being read highlighted. On narrow screens it becomes a drawer behind a menu button.
- **Theme switch** between Light and Dark, remembered in `localStorage`. Without a saved choice the first
  visit follows the OS setting.
- **Reader mode**: hides the menu, enlarges the type in one serif reading column and goes full screen.
  Leaving full screen (Esc) leaves reader mode. It is not remembered, since full screen needs a click.
- Code uses JetBrains Mono, then Fira Code, with ligatures on. Fonts are not embedded, so a viewer without either
  falls back to the system monospace (no ligatures).
- Muted greys, syntax colours and links are tuned to at least 4.5:1 contrast in both themes. Keep that when
  adding colours to the template.
- Wide tables scroll inside a frame, a back-to-top button, print styles, and links to a collapsed
  `<details id>` open it.

## Workflow

1. **Write the body** as plain HTML (what goes inside `<main>`), using the components below. Start with
   `<h1>`, a `.byline` and a `<h2>Summary</h2>`.
2. **Build** the page:
   ```
   python3 -I ~/.claude/skills/html-report/scripts/build_report.py --title "Title" --content body.html --out report.html
   ```
   To restyle an existing report onto the current template, re-wrap its `<main>`:
   `build_report.py --from old.html --out new.html`.
3. **Change preview** (optional, for work on a git branch): renders every commit in `<base>..HEAD` as an
   expandable, syntax-highlighted diff and links `<td><code>hash</code></td>` cells to it. Each commit's hash in
   the section links to the commit on GitHub in a new tab (taken from the `upstream` remote, else `origin`;
   override with `--commit-url`; it 404s until pushed), and code-like words in commit messages are wrapped in
   `<code>`. Rerun it after new commits; it replaces its own section. Use `--head <ref>` when the branch is not
   checked out.
   ```
   python3 -I ~/.claude/skills/html-report/scripts/diff_preview.py --repo <worktree> --base <ref> \
     --html report.html [--md report.md] [--trim path/to/Generated.kt=40]
   ```
   Use `--trim` for generated or very large files.
4. **Render-check** with headless Chrome and look at the images before handing over:
   ```
   C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
   "$C" --headless --disable-gpu --window-size=1440,1100 --screenshot=/tmp/r.png "file://$PWD/report.html"
   ```
   Check dark and reader mode by rendering a copy with `<html lang="en" data-theme="dark">` or
   `<html lang="en" class="reader">` (headless Chrome cannot go full screen, so this checks the layout only). Headless Chrome never lays out narrower than 500 px, so test the narrow
   layout at `--window-size=500,1000`; a 420 px screenshot just crops a 500 px page. To find overflow, append a
   script that writes `innerWidth`, `document.documentElement.scrollWidth` and any element whose right edge
   passes `innerWidth`, then read it with `--virtual-time-budget=2000 --dump-dom`.
5. **Place it** where the user asks. If the destination already holds reports, match their naming.
   Opening it for the user: `open -a "Google Chrome" report.html`.

## Components

```html
<h1>Ticket: Short title</h1>
<p class="byline">Ticket: <a href="…">KEY-1</a>, In Progress. Branch: <code>task/…</code>. 3 commits, not pushed.</p>

<h2>Summary</h2>
<p class="lead">Two or three sentences: what was asked, what was found, what changed.</p>

<div class="tiles">
  <div class="tile"><div class="label">Scroll cost</div>
    <div class="n"><span class="from">482 →</span> 17 ms</div><div class="sub good">−96% main-thread time</div></div>
</div>

<table>
  <tr><th>Fix</th><th>Scenario</th><th class="num">Before</th><th class="num">After</th></tr>
  <tr><td>…</td><td>…</td><td class="num">1934 ms</td><td class="num">664 ms</td></tr>
</table>

<span class="tag done">Shipped</span> <span class="tag skip">Not changed</span>
<span class="tag care">Not included</span> <span class="tag open">Follow-up</span> <span class="tag bad">Regressed</span>

<div class="callout warn">Something the reader must not miss.</div>
<div class="card">Grouped content on a raised surface.</div>
<p class="note">Secondary text, methodology, caveats.</p>
```

Also available: `.good`, `.warn`, `.critical` text colours, `<pre><code>` blocks, `<blockquote>`, and bar rows
(`.bars` > `.bar-row` with `.bar-track` > `.bar-before` / `.bar-after` sized by inline `width:%`).

## Writing the content

- Lead with outcomes. Headline tiles hold the 3 or 4 biggest before → after numbers; the summary table holds the
  rest, one row per fix, with the scenario spelled out and numbers right-aligned in `td.num`.
- Say where each number came from: device or environment, build, scenario, run count. If rows come from
  different environments, mark them in the row.
- Compare like with like. When a refactor splits one unit into nested ones, count the outer unit only, or the
  after number double-counts. When runs vary, show ranges over repeated runs, and alternate builds rather than
  running one build after the other.
- Keep a "What did not make it, and why" table with an outcome tag per row: measured and left alone, reverted,
  dropped, follow-up. It is as valuable as what shipped.
- End with open decisions for the reader, then how to reproduce (scripts, queries, data locations).
- When the numbers were rechecked, add a short recheck section: what was re-derived, what was corrected, what
  is still unverified.
- Keep `<h2>` for top-level sections and `<h3>` for subsections, since they feed the contents menu. Don't add
  ids by hand unless something links to them; the template generates them.
- Keep a Markdown twin (`report.md`) only if the user wants one; `diff_preview.py --md` updates it too.
