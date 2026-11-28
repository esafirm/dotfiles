---
name: instabox-move-repo
description: Use when the user wants to move the repo they are working in onto instabox — "move this repo to instabox", "migrate this repo to a box", "continue this work in the cloud", "move my project to a box". Copies the current git repo and all its worktrees exactly (uncommitted, untracked, stashed and unpushed work; no build output or dependencies), moves its Claude Code / Codex conversations so they resume on the box, then installs the project's dependencies there.
metadata:
  installed-by: instabox
---

# Move a local repo to instabox

Moves the git repo of the current directory, with its worktrees, into one new box (see the `instabox` skill for the CLI). The box ends up with the same `git status`, HEAD, branches, stashes and worktrees, the agent conversations about the repo, and its dependencies installed.

Three scripts in `scripts/` next to this file do the parts that must be exact (Node 18+ and bash, nothing to install):

| Script | Does |
| --- | --- |
| `repo-files.mjs` | The plan: the main checkout and each linked worktree, where each lands on the box, sizes before and after, what is left out. `--list0 PATH`: the files of one checkout for `tar`. Names and sizes only, never contents. |
| `history.mjs` | Stages the Claude Code and Codex sessions of those paths with every path rewritten to the box path. Prints counts and session ids, never contents. |
| `deps.sh` | Runs on the box: detects the toolchain, installs missing runtimes and the dependencies, runs an obvious build. |

What goes over:

- All of the main checkout's `.git` (branches, tags, stashes, unpushed commits, the index so staged changes stay staged, each worktree's own HEAD and index), every tracked file, and every untracked file git does not ignore, in the main checkout and in each linked worktree.
- **Never build output or dependencies**, even when the repo forgot to ignore them: `node_modules`, `target`, `dist`, `build`, `out`, `.next`, `.nuxt`, `.svelte-kit`, `.turbo`, `.cache`, `coverage`, `__pycache__`, `.venv`, `venv`, `.tox`, `.mypy_cache`, `.pytest_cache`, `.gradle`, `bazel-*`, `*.egg-info`, `*.o`, `*.so`, `*.pyc`, `*.class`, ... (the full list is `EXCLUDED_DIRS` and `EXCLUDED_FILES` in `repo-files.mjs`). Files git ignores stay too. A **tracked** file always goes, even under such a name, so `git status` matches. `--keep NAME` copies an excluded name anyway, for a repo whose source really lives in, say, `build/` (pass it to every `repo-files.mjs` run, step 1 and step 3, through `KEEP`). It does not bring back an untracked `.env`: those stay behind (step 7 lists them).
- Claude Code and Codex conversations for the repo and its worktrees (on by default, the user can opt out).

Not moved: `.env` files that are not committed, credentials stored outside the repo (git credential helpers, gh, cloud, API keys in your environment), other local tools and config, other repos. A `.env` that is committed or staged is in `.git` and goes with it. Everything inside `.git` goes, including `.git/config` and any credentials embedded in its remote URLs. Only `.env`-named untracked files are held back, so an untracked `.npmrc` with a token, a `*.pem` or a `secrets.yaml` that git does not ignore goes too.

**Never read, print or paste a credential value yourself**: not a `.env`, not `gh auth token`, not `echo $SOME_KEY`.

Before starting, tell the user plainly:

- **git push/pull from the box will not work until they set up credentials there** (for example `instabox ssh <box>` then `gh auth login`; org Secrets cover HTTP API keys only, so git sign-in is set up separately).
- **The copied conversation history may contain secrets they pasted earlier** (tokens, keys, passwords). It goes by default; ask whether to skip it (or only Codex / only Claude Code).
- Their local copy stays as it is, and nothing keeps the two in sync afterwards.

## 1. The plan

Run with **bash**, anywhere inside the repo or one of its worktrees:

```bash
export MSYS2_ARG_CONV_EXCL=/data/                 # Git Bash on Windows: keep box paths as they are
instabox whoami                                   # signed in? otherwise: instabox login
S=~/.claude/skills/instabox-move-repo/scripts     # or ~/.agents/skills/instabox-move-repo/scripts: wherever this file is
W=$(mktemp -d)
node "$S/repo-files.mjs"                          # the plan, for you and the user
```

It always plans the **main checkout plus its linked worktrees** (from `git worktree list`), even when run from inside a worktree: a worktree alone is half a repo. For each it shows the branch (or detached HEAD), uncommitted changes, locked state, where it lands, and the sizes:

- `before`: everything in the directory on disk, and what "`.git` plus every file git does not ignore" would be.
- `left out`: build output and dependencies git does not ignore, biggest first, and `.env` files.
- `after`: what is actually sent.

Where things land: the main checkout in `/data/workspace/<repo-name>` (`/data` is the box's persistent disk; HOME is `/data/home`); a worktree inside it (such as `.claude/worktrees/<name>`) at the same relative path; any other worktree in `/data/workspace/<repo-name>.worktrees/<its directory name>`. Pass `--dest /data/workspace/<other>` if the user wants another name. Prunable worktrees (directory gone) are listed as not moved and stay behind.

Show the user the plan in short: the worktrees with their sizes and state, the total sent, the biggest things left out, the `.env` files. If there are worktrees, ask which to leave behind (in Claude Code, AskUserQuestion with multiSelect); each one left behind is a `--skip-worktree PATH`. Ask about the history (above). Then write the final plan:

```bash
SKIP=()            # one --skip-worktree per worktree the user unchecked: SKIP+=(--skip-worktree /path/to/it)
KEEP=()            # one --keep per excluded name the user wants copied anyway: KEEP+=(--keep build)
node "$S/repo-files.mjs" "${SKIP[@]}" "${KEEP[@]}" --json > "$W/plan.json"
DEST=$(jq -r .main.box "$W/plan.json" | tr -d '\r')   # tr: Windows jq.exe ends lines in CRLF
jq -r '.totals' "$W/plan.json"                    # sendBytes must fit well inside /data: instabox usage
```

Submodules: their history comes along inside `.git/modules`; run `git submodule update --init` on the box. Uncommitted changes inside a submodule, and an untracked nested repo's files, are not copied. A bare repo with worktrees is refused: move its worktrees one by one by hand.

## 2. Create the box

```bash
instabox ls                                       # pick a box name that is not taken
BOX=<box>
instabox create --name "$BOX" --meta repo="$(basename "$DEST")"
```

Box names are lowercase letters, digits and `-`. The box gets the default size, 4 vCPU / 8 GB (the instabox skill's Sizes lists the others a plan offers). The default template (`agent-browser`, shown as standard in the dashboard) has git, Node.js 22 (npm, pnpm, Yarn), Bun, Python (uv), Go, Rust, a C toolchain, Docker and a desktop with Chromium. This box is meant to stay; it pauses itself after 30 idle minutes. The `repo=` label can match a user's existing Vault selectors (the Vault is legacy and will be retired; never save credentials there); it does not select org Secrets. Without `--secrets` the box still gets such existing Vault items. Opt into org Secrets explicitly with `--secrets NAME,NAME`. Use `--no-vault --secrets none` when neither store should deliver credentials.

## 3. Copy the repo and its worktrees

The main checkout first (it carries `.git`), then each worktree, each as its own `tar` stream:

```bash
export COPYFILE_DISABLE=1                                   # macOS tar: no ._ AppleDouble files
X='tar -xzf - --warning=no-unknown-keyword'                 # the box runs GNU tar
jq -r '.main, (.worktrees[] | select(.move)) | [.src, .box] | @tsv' "$W/plan.json" | tr -d '\r' |
while IFS=$'\t' read -r src box; do
  echo "== $src -> $box"
  node "$S/repo-files.mjs" --list0 "$src" "${SKIP[@]}" "${KEEP[@]}" </dev/null |
    tar -C "$src" --null --no-recursion -T - -czf - |
    instabox ssh "$BOX" -- "mkdir -p '$box' && $X -C '$box'"
done
```

Then point the worktrees at their new places (each worktree's `.git` file and `.git/worktrees/<id>/gitdir` still name the local paths; `git worktree repair` with the new paths rewrites both sides):

```bash
WTS=$(jq -r '[.worktrees[] | select(.move) | .box] | join(" ")' "$W/plan.json" | tr -d '\r')
[ -z "$WTS" ] || instabox ssh "$BOX" -- "cd '$DEST' && git worktree repair $WTS"
```

Box paths contain only letters, digits and `._-/`, so they are safe unquoted there.

Check that every checkout has the same state, and the same worktrees:

```bash
jq -r '.main, (.worktrees[] | select(.move)) | [.src, .box] | @tsv' "$W/plan.json" | tr -d '\r' |
while IFS=$'\t' read -r src box; do
  echo "== $box"
  diff <(cd "$src" && { git status --porcelain | sort; git rev-parse HEAD; }) \
       <(instabox exec "$BOX" --cwd "$box" -- 'git status --porcelain | sort; git rev-parse HEAD' </dev/null)
done
git worktree list; instabox exec "$BOX" --cwd "$DEST" -- git worktree list
```

The only allowed differences are `<` lines starting with `??` for what the plan left out (a build directory, an untracked `.env`, or a whole `?? dir/` that held only those), and ` M <submodule>` for a submodule with uncommitted changes inside it (those are not copied: note it for step 7). A name passed with `--keep` must not show up as a `??` difference: it was meant to go. HEADs must match, and the box's `git worktree list` must show the same branches, detached HEADs and `locked` marks at the box paths, without the worktrees left behind. Anything else: stop and look before going on.

## 4. Conversation history (unless the user opted out)

```bash
H=$(mktemp -d)
node "$S/history.mjs" --plan "$W/plan.json" --out "$H" > "$W/history.json"   # --no-claude / --no-codex to skip one
jq '{claude: .claude | {sessions, bytes, recent}, codex: .codex | {sessions, bytes, recent}}' "$W/history.json"   # null: skipped
tar -C "$H" -czf - $(jq -r '.entries[]' "$W/history.json" | tr -d '\r') | instabox ssh "$BOX" -- "$X --no-overwrite-dir -C ~"
instabox ssh "$BOX" -- 'bash ~/.cache/instabox-move-repo/apply-history.sh'
rm -rf "$H"
```

What it moves, for the main checkout, each moved worktree, and any directory under them:

- Claude Code: `~/.claude/projects/<path with every non-alphanumeric character as ->/` (sessions, subagent transcripts, tool results). Which path a directory belongs to is read from the `cwd` its sessions recorded, so `/a/app-2` is never taken for `/a/app`. On the box it is stored under the box path's name, so `claude --continue` and `claude --resume` in that directory find it. The prompt history lines (`~/.claude/history.jsonl`) for those paths are appended.
- Codex: the `rollout-*.jsonl` files under `~/.codex/sessions` (and `archived_sessions`) whose `cwd` is one of those paths, and their lines of `~/.codex/history.jsonl`.
- In every copied file each local path is replaced by its box path (a longer name such as `/a/app-2` is not touched), so the sessions' `cwd` and the file paths in them point at the box. File times are kept, so the latest session stays the latest. The local files are not changed.

Do not write any notes about the move into `CLAUDE.md`, `AGENTS.md` or settings files on the box, global or in the repo.

## 5. Install dependencies

```bash
instabox ssh "$BOX" -- 'mkdir -p ~/.cache/instabox-move-repo && cat > ~/.cache/instabox-move-repo/deps.sh' < "$S/deps.sh"
instabox ssh "$BOX" -- "bash -l ~/.cache/instabox-move-repo/deps.sh '$DEST'"      # --dry-run first if you want to see the steps
```

Over `ssh`, which has no time limit (installs and builds take minutes; `instabox exec` stops at 600 seconds). It looks at the repo root and each first-level subdirectory with a lockfile of its own:

| Found | Runtime, installed only when missing or another version is pinned | Install | Smoke |
| --- | --- | --- | --- |
| `.tool-versions`, `mise.toml` | mise | `mise install` | |
| `package.json` + `pnpm-lock.yaml` / `yarn.lock` / `bun.lock(b)` / `package-lock.json` (or `packageManager`) | Node per `.nvmrc` / `.node-version` (nvm), pnpm/yarn via corepack, bun | `pnpm install --frozen-lockfile`, `yarn install --immutable` (berry) or `--frozen-lockfile`, `bun install --frozen-lockfile`, `npm ci`; no lockfile: `npm install --no-package-lock` | `<pm> run build` if there is a `build` script |
| `uv.lock`, `poetry.lock`, `Pipfile.lock`, `pdm.lock`, `requirements*.txt`, `pyproject.toml` / `setup.py` | uv (it fetches the Python in `.python-version`), poetry/pipenv/pdm via `uv tool` | `uv sync --frozen`, `poetry install`, `pipenv sync --dev`, `pdm sync`, `uv venv && uv pip install -r ...`, `uv pip install -e .` | |
| `Cargo.toml` | rustup (follows `rust-toolchain`) | `cargo fetch [--locked]` | `cargo build` |
| `go.mod` | Go (newer `go` lines are fetched by Go itself) | `go mod download` | `go build ./...` |
| `Gemfile` | ruby-full, bundler (apt, gem) | `bundle install` (gems in `~/.bundle/gems`) | |
| `pom.xml` / `build.gradle(.kts)` | JDK, Maven (apt) | `./mvnw` or `mvn dependency:go-offline` | `compile`, `./gradlew assemble` |
| `composer.json` | PHP, composer (apt) | `composer install` | |
| `mix.exs`, `deno.json`, `*.csproj`, `Package.swift`, `pubspec.yaml`, compose files | | noted, not installed | |

It never rewrites a lockfile (frozen installs only), carries on past a failed step, lists every step as ok or FAILED, adds notes (an expected `.env`, compose services not started, git status changed by an install), and exits 1 if anything failed. Failures are not the end: read each one, fix it on the box (a system library with `sudo apt-get install -y ...`, another toolchain version, a step from the README or CI config in `.github/workflows`), and run the step again, until it builds. Run tests if the project defines them and they do not need services or secrets. For a script you send over stdin instead, give anything that might prompt `-y` or `</dev/null`. Stop and ask the user when something needs a secret (private registry token, `.env` values) or a choice only they can make.

Worktrees: install only in the main checkout unless the user wants a worktree ready too (`deps.sh '<its box path>'`); each install takes disk space.

## 6. Check git did not change

```bash
instabox exec "$BOX" --cwd "$DEST" -- 'git status --porcelain | sort; git rev-parse HEAD'
```

Compare with step 3. New `??` lines from the installs (for example a lockfile the project does not commit) are worth a mention; a modified tracked file is not expected: find which step did it.

## 7. Tell the user

- The box name and where the repo is: `instabox ssh <box>`, then `cd /data/workspace/<name>`; each worktree with its box path and branch; worktrees left behind and why.
- Uncommitted work inside a submodule (a ` M <submodule>` line in step 3) did not come over: name each such submodule so the user can commit or copy that work themselves.
- Sizes: on disk before, sent after, and the biggest things left out (they were rebuilt or reinstalled on the box).
- What was installed, whether build and tests pass, and anything left to do (each FAILED step and note from `deps.sh` that is not fixed).
- Again: git push/pull needs credentials set up on the box. Ignored files and build output were not copied. Untracked `.env` files were left behind: list them by name from the plan (`jq -r '.main.envLeftOut, (.worktrees[] | select(.move) | .envLeftOut) | .[]' "$W/plan.json"`), never their contents. For an HTTP API key the project needs, the user can run `instabox secrets set NAME --host <api-host>` and select it on the box with `instabox secrets select`; database URLs and other credentials need their own setup on the box. Secrets in committed or staged files, anywhere in `.git` (such as a token in a remote URL in `.git/config`), in untracked files not named `.env*`, or in the copied history, did go over.
- How to pick up old conversations, kept short, with the session ids from step 4:
  - Claude Code, in the repo (or worktree) directory on the box: `claude --continue` (latest) or `claude --resume` (picker, or `claude --resume <id>`).
  - Codex, in that directory: `codex resume` (picker for this directory), `codex resume --last`, or `codex resume <id>`.
- The local copy is untouched; nothing keeps the two in sync after this.

Delete `$W` when done (plans and lists, no values).
