---
description: Review a GitHub PR by link. Usage /review-pr <pr-url|owner/repo#number|#number>
agent: pr-reviewer
---

Here is the PR data:

!`~/.config/opencode/scripts/review-pr.sh $ARGUMENTS`

Review this PR using the **code-review-and-quality** skill's five-axis framework — correctness, readability & simplicity, architecture, security, and performance.

Label every finding with one of these severity prefixes:

| Prefix | Meaning | Author Action |
|--------|---------|---------------|
| *(no prefix)* | Required change | Must address before merge |
| **Critical:** | Blocks merge | Security vulnerability, data loss, broken functionality |
| **Nit:** | Minor, optional | Author may ignore |
| **Optional:** / **Consider:** | Suggestion | Worth considering |
| **FYI** | Informational only | No action needed |

End with a **Verdict**: **Approve** (ready to merge with no blocking issues) or **Request changes** (blocking issues found). Include the checklist from the skill's review template.

Be direct, quantify problems where possible (e.g. "this N+1 query adds ~50ms per item"), and reference specific file paths and line numbers from the diff.
