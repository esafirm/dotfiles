---
description: VERY IMPORTANT. Goal: optimize developer workflow by analyzing usage patterns and suggesting concrete improvements — skills, agents, commands. Usage /workflow-audit [project|--all] [7d|30d|all]
---

Here is the workflow audit data for the current project:

!`~/.config/opencode/scripts/workflow-audit.sh $ARGUMENTS`

Analyze this data carefully. **The GOAL is to optimize the developer's workflow.** Every suggestion must be concrete and actionable.

Provide:

1. **Workflow summary** — key observations about tool usage patterns, agent usage, model preferences, and time range.

2. **Skills to create** — suggest new skills that would help streamline frequently used tool combinations and recurring intents. For each suggestion, include:
   - The proposed skill name and description
   - Which tools/patterns/intents it covers
   - A brief SKILL.md outline

3. **Agents to create** — suggest new agents for recurring task types. For each suggestion, include:
   - The proposed agent name and description
   - Recommended model
   - A brief agent .md outline

4. **Skills to remove** — list skills that are available on disk but rarely or never loaded. For each, note:
   - How many times it was loaded
   - Whether to keep, archive, or remove

5. **Prompt intent insights** — if "Prompt Intent Distribution" and "Top Keywords" are present, identify recurring user intents and suggest commands/skills/agents to address them. Pay special attention to the recent prompts file (printed above) — each prompt is a potential candidate for automation. Read the file to analyze the full recent prompts grouped by session.

6. **Optional improvements** — any other workflow optimizations worth considering (e.g. permission tweaks, MCP server additions, time range defaults, etc.)
