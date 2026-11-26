---
name: prune
description: Whole-project sweep for everything that's broken, inconsistent, inefficient, or no longer needed, preferring deletion over simplification over optimization over automation. Produces a numbered report sorted by sureness and impact and changes nothing. Use for /prune, "prune this project", "sweep this repo", or "find everything that's broken". Pass "ui" to also run the app and review every screen.
---

# Prune

The prompt this skill runs:

> Read this entire project and find everything that's broken, inconsistent,
> inefficient, or no longer needed. Prefer deleting over simplifying,
> simplifying over optimizing, and optimizing over automating. Sort by
> sureness and impact.

## Rules

- **Report only.** Do not edit, delete, commit, or deploy anything during the
  sweep. Throwaway repro scripts go in the scratchpad, never the repo. Running
  the test suite, typecheck, and read-only commands is fine.
- **Read the whole project**, not just the diff or the obvious entry points:
  code, tests, scripts, CI, deploy config, docs, and assets.
- **The fix ladder.** For every finding, pick the earliest rung that works:
  delete > simplify > optimize > automate. Never propose new tooling when
  removal solves it.
- **Verify before you claim.** Re-read the code and its callers yourself for
  every Must fix finding. Mark anything you couldn't confirm as `likely` or
  `possible`, never `certain`.

## How to run it

1. **Get the baseline.** Work out what the project does, who calls it, and the
   load it really sees. Run the tests and typecheck once so the report can say
   what already passes.
2. **Fan out on big repos.** If the project is too large to read in one pass,
   split it by area and give each area to a read-only review subagent. Tell
   each one the same prompt and fix ladder. Merge their findings, drop
   duplicates, and re-check the serious ones yourself.
3. **Write the report** in the format below.
4. **Stop.** Wait for the user to choose items by number.

## Report format

Start with three short lines:

- **What this repo does:** one or two sentences.
- **Load I assumed:** who calls it and how often. This decides what counts as
  "inefficient".
- **Starting state:** test and typecheck results.

Then list the findings. Number them once across all groups so the user can
reply with "3. do it" or "4. ignore". Sort by sureness first, then impact.

Tag each finding **[sureness / impact]**:

- sureness: `certain` (read the code path, or reproduced it), `likely`
  (strong evidence, one link unchecked), `possible` (needs a fact you can't
  reach, such as production state or a person's intent).
- impact: `high`, `medium`, `low`.

Groups: `## Must fix`, `## Should fix`, `## Needs a decision`. Write each
finding like this:

```markdown
3. **[likely / high] One-line claim** ([file.ts:40-49](/abs/path/file.ts:40))
   - **What this is:** the thing, in plain words.
   - **Problem:** what's wrong, with the concrete evidence.
   - **Fix:** the change, from the fix ladder, with a rough line count ("delete, about 135 lines").
   - **If we skip it:** the real consequence.
```

Close with:

- How many smaller findings were left out, with two or three examples.
- **Verdict:** what to do first and why, in two or three sentences.
- **Lean:** about how many lines, dependencies, and assets could go.
- **Not checked:** everything you couldn't verify, such as live services,
  servers you can't reach, or a real browser or device.
- One line offering a cross-check of the Must fix findings by other models.

## Cross-check (only when asked)

When the user asks for a cross-check, often naming the models, hand each
reviewer the Must fix claims with their file locations. Ask them to try to
prove each one wrong by reading the code and its callers. They may run small
repro scripts but must not edit anything. Use the host's delegation tool for
other providers. When all reviewers are done, show a table with one row per
claim and one column each for your verdict and theirs. Downgrade or drop
claims they disprove.

## Acting on the user's picks

Once the user picks items, do exactly those. Deletions follow the `file-ops`
skill: stage them with `ai-trash.sh` as the last step. Commit only when asked,
with the user's signature commit format. Leave other people's uncommitted
changes alone.

## UI pass (`/prune ui`, only when asked)

Add this only when the user asks for it.

1. Build and run the app yourself. On Android, use the `android` CLI, `adb`,
   and `blnav` where available. For web, use the browser preview tools.
2. Open every page or screen, including empty, loading, and error states you
   can reach, and take a screenshot of each.
3. Put a `## UI` section before the code findings. Start with the **5 biggest
   hierarchy and density problems**, each with its screenshot and the same
   `[sureness / impact]` tag. Then list the other UI findings.
4. Name any screens you couldn't reach, and say why.
