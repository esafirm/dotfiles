---
description: "Stage files for deletion in the per-repo $TMPDIR trash, restore them, or permanently empty the trash. Usage: /trash [paths... | --list | --restore <paths> | --empty]"
---

Current worktree state:

!`git status --short`

User request: $ARGUMENTS

Follow the **file-ops** skill. Concretely:

- `--list` → run `~/.config/opencode/scripts/ai-trash.sh --list` and report. Done.
- `--restore <paths>` → `~/.config/opencode/scripts/ai-trash.sh --restore <paths...>`, then compile/test the affected modules. Done.
- `--empty` → preview with `~/.config/opencode/scripts/ai-trash.sh --empty --dry-run`, confirm the list matches what was verified, then `~/.config/opencode/scripts/ai-trash.sh --empty`. Report that it is permanent. Done.
- otherwise (a deletion request) — it runs LAST, after all other work in the execution is complete:
  - Regenerate the removal list from the `git status` snapshot above. Discard any hand-maintained list from earlier in the session — re-verify every path: it must exist, have no remaining references (grep imports/usages), and not be added/modified in the current diff.
  - Run `~/.config/opencode/scripts/ai-trash.sh --dry-run <paths...>` first, show the user what would be staged, then stage for real with the verified list.
  - Compile/test the affected modules afterwards. On failure, restore via `--restore` and report.
  - Do NOT run `--empty` in the same turn — leave the staged batch restorable and tell the user it's ready to empty once they've confirmed.
