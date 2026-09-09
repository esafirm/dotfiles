---
name: file-ops
description: Safe file deletion via trash-staging. Use when removing files, cleaning up after a refactor or plan pivot, or whenever you would reach for `rm` / `git rm`.
---

# File Ops — Trash, Then Empty

`rm` on repo files is denied by tool permissions. Never work around it: no
blank-shell writes, no `git rm`, no `rm -rf`, no shell tricks. Deletion is
soft and always the **last task in an execution** — batch all removals at the
end.

## The procedure

1. **Finish the real work first.** All edits, moves, and renames land before
   any removal is staged.
2. **Regenerate the removal list from `git status` at cleanup time.** Never
   carry a hand-maintained list across architecture changes — a plan pivot
   can legitimately restore a file you marked earlier, and a stale list
   over-deletes (this has happened: a restored decorator and its test were
   trashed by a stale list).
3. **Verify each candidate:** confirm nothing references it (grep for imports
   / usages), confirm it is not back in the current diff as added or
   modified.
4. **Stage via the trash script** (preserves repo-relative paths for restore):
   ```bash
   ~/.config/opencode/scripts/ai-trash.sh --dry-run <paths...>
   ~/.config/opencode/scripts/ai-trash.sh <paths...>
   ```
   Trash lives at `$TMPDIR/opencode-trash/<repo>/`.
5. **Compile / test the affected modules after staging.** If something was
   wrongly trashed, restore it:
   ```bash
   ~/.config/opencode/scripts/ai-trash.sh --restore <paths...>
   ~/.config/opencode/scripts/ai-trash.sh --list
   ```
6. **Only empty the trash once the batch is confirmed right.** The ONE place
   `rm` ever runs is scoped inside the trash dir:
   ```bash
   ~/.config/opencode/scripts/ai-trash.sh --empty --dry-run   # preview
   ~/.config/opencode/scripts/ai-trash.sh --empty             # permanent
   ```
   Until `--empty`, everything staged is restorable. The OS also clears the
   trash on reboot.

## Rules

- One explicit path per argument. No globs, no absolute paths, no `..`.
- Never touch `.git`, the worktree root, or anything outside the worktree —
  the script refuses these; do not bypass it with manual `mv`.
- Restores overwrite-nothing: if a file reappeared at the destination,
  stop and reconcile before `--restore`.
- `--empty` is irreversible and trash-scoped only. Never point it anywhere
  else, and never empty until the staged batch is verified.
