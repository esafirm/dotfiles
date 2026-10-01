# llm-wiki skill

Lets an AI agent (Claude Code, Codex, etc.) query the user's locally-running **LLM Wiki** desktop app over its built-in HTTP API.

This skill is **documentation only**. The API is a standard HTTP+JSON contract — call it with `curl`, `fetch`, `requests`, or whatever HTTP tool your environment already has. There is no client library, no SDK, no compile step.

## Installation

### Recommended — one-liner via `skills` CLI

```bash
npx skills add https://github.com/nashsu/llm_wiki_skill.git --skill llm-wiki
```

This fetches the latest version of the skill from GitHub and registers it with your agent runtime. Re-run the same command to update to a newer revision later.

### Alternative — clone + symlink (Claude Code)

If you prefer to manage the source locally and link it into Claude Code (skills live at `~/.claude/skills/`):

```bash
git clone https://github.com/nashsu/llm_wiki_skill.git
ln -s "$(pwd)/llm_wiki_skill" ~/.claude/skills/llm-wiki
```

### Alternative — manual drop-in

The skill is three markdown files and nothing else. Drop the folder anywhere your agent runtime discovers skills (e.g. Codex `agents/`, custom MCP server skill dir). No dependencies, no build step.

## What this skill enables

- "What does my wiki say about X?" → hybrid search (keyword + vector) + read
- "Show me the neighborhood of node Y in my graph" → wikilinks traversal
- "Read me the page about Z" → file content fetch
- "I just added new docs, re-index" → backend rescan
- "Give me a structural overview of my wiki" → file tree + index.md

All read-only except `sources/rescan` (triggers an internal queue diff).

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | Agent-facing instructions. Loaded automatically by the AI runtime. |
| `api-reference.md` | Full endpoint contract (status codes, params, response shapes). |
| `examples.md` | Conversation → API recipe patterns. |
| `README.md` | This file — human setup / install / troubleshooting. |

No scripts, no wrappers. If you find yourself wanting one, just `curl`.

## Prerequisites

1. **LLM Wiki desktop app installed and running.** The API binds to `127.0.0.1:19828` only while the app is open. If the app isn't running, the agent will see `connection refused` and tell you.

2. **API server enabled.** Default: on. Verify in `Settings → API Server → "Enable local HTTP API"` is checked.

3. **Token configured.** Default: off (token field empty → every endpoint returns 401). Either:
   - In the app: `Settings → API Server → Generate new token`. Copy and stash it.
   - Via env: `export LLM_WIKI_API_TOKEN=...` (overrides UI; persists for the agent process).

   You can also flip `Settings → API Server → "Allow access without a token"`, which removes auth entirely. **Local-only — but any process on this machine can then read your wiki.** Use only with trusted setups.

## Quick smoke test

> **Windows users**: replace `export LLM_WIKI_API_TOKEN=...` with `$env:LLM_WIKI_API_TOKEN = "..."` (PowerShell) or `set LLM_WIKI_API_TOKEN=...` (cmd.exe). Use `curl.exe` instead of `curl` in PowerShell to bypass the `Invoke-WebRequest` alias. Backslash line-continuations (`\`) become backticks (`` ` ``) in PowerShell and `^` in cmd.

```bash
export LLM_WIKI_API_TOKEN=...

# 1. Probe — no auth needed
curl -s http://127.0.0.1:19828/api/v1/health

# Expected:
# {
#   "ok": true,
#   "status": "running",
#   "enabled": true,
#   "authConfigured": true,
#   "tokenSource": "env",
#   "allowUnauthenticated": false,
#   ...
# }

# 2. List projects
curl -s -H "Authorization: Bearer $LLM_WIKI_API_TOKEN" \
  http://127.0.0.1:19828/api/v1/projects

# 3. Search the active project
curl -s -H "Authorization: Bearer $LLM_WIKI_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"query":"rope","topK":3}' \
  http://127.0.0.1:19828/api/v1/projects/current/search

# 4. Read a page
curl -s -H "Authorization: Bearer $LLM_WIKI_API_TOKEN" \
  "http://127.0.0.1:19828/api/v1/projects/current/files/content?path=wiki/concepts/rope.md"
```

Add `| jq` at the end of any of these if you have `jq` installed and want pretty output. Not required.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `curl: (7) Failed to connect to 127.0.0.1 port 19828` | App not running | Launch LLM Wiki desktop, wait ~2s for the API server to bind. |
| `Status: port_conflict` in `/health` | Another process on 19828 | `lsof -i :19828` to find the squatter; quit and restart the app. |
| Every endpoint returns 401 | No token configured | Settings → API Server → Generate; OR `export LLM_WIKI_API_TOKEN=...` |
| Every endpoint returns 503 with "disabled" | Kill switch is on | Settings → API Server → check "Enable local HTTP API". |
| Every endpoint returns 503 with "busy" | In-flight cap reached (64 concurrent) | Back off, send fewer parallel requests. |
| 429 on rapid requests | Rate limit: 120 req/sec global | Back off ≥1s. |
| `files/content` returns 415 on `.pdf` | API is text-only | Read source PDFs via the desktop UI; only text-ish extensions are exposed. |
| `tokenSource: "env"` even though I cleared it from UI | `LLM_WIKI_API_TOKEN` env var is set somewhere | `unset LLM_WIKI_API_TOKEN`; or set its value to match what's in your UI. |

## Security model

- The API listens on `127.0.0.1` only. It is **not reachable from other hosts** on your network.
- Token-based auth is constant-time compared (no timing leak in the auth check).
- Path traversal blocked at the route handler (`safe_join` with canonical-path prefix check).
- File reads restricted to a whitelist (`purpose.md`, `schema.md`, `wiki/**`, `raw/sources/**`); text extensions only; 2 MB cap.
- Body limit 1 MB; in-flight cap 64; rate limit 120/sec.
- No write endpoints in v1. `/sources/rescan` is the only mutation, and it only reads disk + queues internal work.

What's **not** in the threat model:

- A malicious **local** process with the token can read everything in your active project's wiki + sources. Treat the token as a local secret.
- A malicious local process can probe `/health` (no auth) to discover the API exists. Information disclosure, no content leak.
- Cross-origin browser pages can hit the API only if they have the token. Default CORS is `*` — relies on token secrecy. Don't paste your token into untrusted web tools.

## Version

This skill matches **LLM Wiki API v1** as shipped in app version `0.4.10+`. Hybrid retrieval (keyword + vector) is live; the response carries `mode: "keyword" | "vector" | "hybrid"`, `tokenHits`, `vectorHits`, and per-result `vectorScore`. If the desktop app's `/health` reports a major version bump, check `api-reference.md` for drift before relying on the contract verbatim.

## Updating

If you installed via `npx skills add`, re-run the same command to pull the latest revision:

```bash
npx skills add https://github.com/nashsu/llm_wiki_skill.git --skill llm_wiki_skill
```

If you cloned the repo, `git pull` inside the cloned folder is enough — the symlink picks up changes automatically.

## Contributing

Source repo: <https://github.com/nashsu/llm_wiki_skill>

Issues and PRs welcome. The skill should stay **client-less** — no scripts, no SDK shim, no wrapper binaries. The whole point of the underlying API is that any HTTP tool can call it; this skill is the contract documentation, not a runtime.

## License

See the repository for license details.
