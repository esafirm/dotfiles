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
