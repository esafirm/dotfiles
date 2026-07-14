---
description: Gather current context and get structured advice from a specialized advisor. Usage: /advice [what you need advice on]
---

The user wants advice. First gather context from the codebase — check `git status`, `git log --oneline -10`, `pwd`, and note any recent changes or open questions. Then ask the user to fill in these three things if they haven't already:

- **Goal** — what are they trying to achieve?
- **In Progress** — what have they done so far?
- **Blockers** — what's stopping them?

Once you have all of it, call `@advice` and pass the gathered context along with the user's original request.

$ARGUMENTS
