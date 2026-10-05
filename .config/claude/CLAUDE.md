# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

## File deletion discipline

`rm` is restricted by tool permissions — treat that as intentional and never
work around it (no blank-shell writes, no `git rm`, no shell tricks).
Deletion is always the **last task in every execution**: finish all edits,
moves, and renames first, then batch removals at the end.

Removals are staged soft-deletes: move files with
`~/.config/opencode/scripts/ai-trash.sh <repo-relative-path>...` into
`$TMPDIR/opencode-trash/<repo>/`, which preserves repo-relative paths and is
restorable via `ai-trash.sh --restore` and `--list`. Only once the staged
batch is verified correct, empty it permanently with
`ai-trash.sh --empty` — the single sanctioned `rm`, scoped strictly inside
the trash dir. See the `file-ops` skill and the `/trash` command.

When a plan pivots mid-session, regenerate the removal list from
`git status` at cleanup time — never carry a hand-maintained list across
architecture changes. Verify the list against the current diff before
staging, and compile/test the affected modules afterwards.

## Gradle Build Cache

When a Gradle build fails and all tasks report `UP-TO-DATE`, **do not assume cache is the
problem** — the failure is almost certainly a real compilation error in your changes; check
the full build output. If you genuinely suspect a stale cache, **ask the user for confirmation**
before re-running with `--rerun-tasks` or any cache-busting flag.

## Dotfiles Script & MCP Conventions

- **`scripts/` vs `bin/`**: In `~/dotfiles`, `scripts/` is exclusively for shell function snippets sourced by `.zshrc` during shell startup (`for file in $DOT/scripts/*; do source $file`). NEVER place executable CLI tools, runners, or top-level scripts in `scripts/` — doing so executes them on every terminal open and crashes login shells (e.g. Ghostty). Executable scripts belong in `bin/` (and symlinked to `~/.local/bin/`).
- **Secrets & MCP Configs**: Never commit raw API tokens or local application paths into git-tracked MCP configuration files (`mcp_config.json`, `settings.json`, `opencode.jsonc`, etc.). Store tokens in `secrets` (git-ignored) and create a wrapper script in `bin/` that bootstraps PATH and loads the token dynamically.

