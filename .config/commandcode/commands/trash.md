Stage files for deletion in the per-repo $TMPDIR trash, restore them, or empty the trash.
Usage: /trash [paths... | --list | --restore <paths> | --empty]

Current worktree state:

!`git status --short`

User request: $ARGUMENTS

Follow the **file-ops** skill. Concretely:

- `--list` → run `~/.config/opencode/scripts/ai-trash.sh --list` and report. Done.
- `--restore <paths>` → restore, then compile/test the affected modules. Done.
- `--empty` → preview with `--dry-run`, confirm the list, then run `--empty`. Report permanent.
- otherwise (a deletion request) — runs LAST, after all other work:
  - Regenerate the removal list from the `git status` snapshot above; discard any earlier
    hand-maintained list. Verify each path: exists, no remaining references, not in the current diff.
  - `--dry-run` first, show the list, then stage for real.
  - Compile/test afterwards. On failure, `--restore` and report.
  - Do NOT `--empty` in the same turn.
