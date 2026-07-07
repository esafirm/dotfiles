# workflow-audit-audit

Validates the workflow audit, analyzes recent prompts, and **initializes/updates opencode configuration** based on real usage data.

## Goal (VERY IMPORTANT)
This skill exists to:
1. Catch bugs in the audit script itself (parsing errors, missing sections, count mismatches)
2. Analyze recent prompts to identify recurring intents, friction points, and optimization opportunities
3. **Initialize and maintain opencode configuration** — permissions, tools, MCP servers, agents, and commands — based on actual usage patterns
4. Generate actionable suggestions for skills, agents, commands, and config changes based on real usage data
5. Track audit health over time (error rates, slow tools, unused resources)

## When to use
- After running `workflow-audit.sh`, to validate results and get deeper insights
- When asked to analyze workflow patterns or suggest optimizations
- When debugging issues with the workflow audit itself
- **When setting up or updating opencode configuration for a project**

## Scripts

### workflow-audit-audit.sh
Full meta-audit that:
- Runs `workflow-audit.sh` and checks all 11 sections are present
- Reads `/tmp/opencode-recent-prompts.txt` and categorizes prompts
- Cross-references session counts, tool totals, and error rates
- Detects anomalies (slow tools, high error rates, unused skills)

Usage:
```bash
bash ~/.config/opencode/scripts/workflow-audit-audit.sh
```

## Data Sources

| Source | Path | Description |
|--------|------|-------------|
| OpenCode DB | `~/.local/share/opencode/opencode.db` | All session/part data |
| Audit script | `~/.config/opencode/scripts/workflow-audit.sh` | The subject under test |
| Recent prompts | `/tmp/opencode-recent-prompts.txt` | Inline prompt dump (7d default) |
| OpenCode config | `<project>/opencode.jsonc` | Project-level opencode configuration |

## Config Initialization (IMPORTANT)

**Based on audit findings, initialize or update opencode configuration.** Configuration lives in `<project>/opencode.jsonc` (or `opencode.json`). Reference: https://opencode.ai/config.json

### 1. Permissions
Audit which tools and commands are actually used, then ensure permission rules cover them:

- **Read-only tools** (`read`, `grep`, `glob`): set to `"allow"` by default
- **Edit/create tools** (`edit`, `write`): set to `"allow"` for trusted files
- **Bash commands**: audit the "Bash Command Breakdown" section. For every command appearing >5% of bash calls, consider adding an explicit `"allow"` rule. Common candidates:
  - `git *` — git operations
  - `rtk *` — custom CLI tool
  - `sqlite3 *` — DB queries
  - `ls *`, `cat *`, `which *` — file inspection
  - `rm *` — typically `"deny"`
  - `mkdir *`, `cp *` — file operations
- **External directory access**: ensure paths used by `read`/`bash` tools are covered
- **MCP tool permissions**: if an MCP server is configured, ensure its tools have appropriate allow/deny rules

### 2. MCP Servers
If the project uses external services, configure them in the `"mcp"` section:

- **Local MCP**: `"type": "local"` with a `"command"` array (e.g., `["npx", "-y", "firebase-tools@latest", "mcp"]`)
- **Remote MCP**: `"type": "remote"` with a `"url"` (e.g., Android Studio)
- Verify each MCP server is working by checking tool availability in session data

### 3. Agents
If audit reveals recurring complex multi-step tasks, create agent files under `~/.config/opencode/agents/`:

- Each agent gets a `.md` file with description, capabilities, and model recommendation
- Agent files follow this structure:
  ```markdown
  # agent-name
  
  Description of when this agent should be used.
  
  ## Instructions
  Specific guidance for this agent's behavior.
  ```
- Register agents by adding them to `opencode.jsonc` if needed

### 4. Commands
For frequently typed intents detected in prompt analysis, create command files under `~/.config/opencode/commands/`:

- Each command gets a `.md` file with a `description` frontmatter
- Example: `workflow-audit.md` — runs audit and triggers analysis
- Target patterns: "commit and push", "code review", "run workflow audit"

### 5. Skills
Configure skill paths in `opencode.jsonc`:

```json
"skills": {
  "paths": [".claude/skills"]
}
```

Skill files live in `~/.config/opencode/skills/<name>/SKILL.md`.

## Recent Prompts Analysis

**YOU MUST read and analyze `/tmp/opencode-recent-prompts.txt` inline.** Do NOT just echo the report — read the actual prompt text and extract insights.

The file contains only developer-typed prompts (system-generated tool call recordings and file content dumps are filtered out).

When analyzing recent prompts, always:
1. Read the prompts file and count prompts per session and per category
2. Identify the top 3-5 recurring intent categories from the actual text
3. Read the raw prompt text to understand WHAT the developer is actually working on (not just which category)
4. Note any "other" prompts that don't match existing categories and suggest new ones
5. Cross-reference with the audit report's Prompt Intent Distribution
6. Look for patterns: what tasks repeat, what frustrates, what could be automated
7. Generate actionable recommendations based on prompt content, not just stats

## Suggested Workflow

1. Run `workflow-audit.sh` to generate the report
2. **Read `/tmp/opencode-recent-prompts.txt`** — this is the most important step
3. Run `workflow-audit-audit.sh` to validate cross-references
4. Based on actual prompt content and tool usage, **initialize/update opencode config**:
   - Add permission rules for frequently used bash commands and tools
   - Create agents for recurring complex workflows
   - Create commands for frequently typed requests
   - Register MCP servers if needed
   - Archive unused skills
5. Apply changes to `<project>/opencode.jsonc`
6. Update this skill if new analysis patterns are discovered

## Data Integrity
- System-generated texts ("Called the..." tool call recordings, "<path>..." file dumps) are excluded by SQL in `workflow-audit.sh`
- Only developer-typed prompts appear in the recent prompts file
- If you see unexpected content, check the SQL filters in `workflow-audit.sh`
