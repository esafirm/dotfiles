#!/usr/bin/env bash
set -euo pipefail

DB="$HOME/.local/share/opencode/opencode.db"

# Defaults
MODE="project"
RANGE="7d"

# Parse arguments in either order.
for arg in "$@"; do
  case "$arg" in
    --all)
      MODE="--all"
      ;;
    7d|30d|all)
      RANGE="$arg"
      ;;
    *)
      # Ignore unknown args.
      ;;
  esac
done

# Compute cutoff timestamp (ms since epoch).
case "$RANGE" in
  7d)
    CUTOFF_MS=$(($(date +%s) * 1000 - 7 * 24 * 60 * 60 * 1000))
    ;;
  30d)
    CUTOFF_MS=$(($(date +%s) * 1000 - 30 * 24 * 60 * 60 * 1000))
    ;;
  *)
    CUTOFF_MS=0
    ;;
esac

get_project_filter() {
  if [ "$MODE" = "--all" ]; then
    echo ""
  else
    local dir
    dir="$(pwd)"
    local pid
    pid=$(sqlite3 "$DB" "SELECT id FROM project WHERE worktree = '$dir' LIMIT 1;")
    if [ -n "$pid" ]; then
      echo "AND s.project_id = '$pid'"
    else
      echo ""
    fi
  fi
}

PF=$(get_project_filter)
SESSION_CONDITION=""
if [ -n "$PF" ]; then
  SESSION_CONDITION="AND s.project_id = '$(echo "$PF" | sed "s/.*'\(.*\)'.*/\1/")'"
fi

# Time filter clause for session/part tables (ms epoch).
TIME_FILTER_SESSION=""
TIME_FILTER_PART=""
if [ "$CUTOFF_MS" -gt 0 ]; then
  TIME_FILTER_SESSION="AND s.time_created >= $CUTOFF_MS"
  TIME_FILTER_PART="AND p.time_created >= $CUTOFF_MS"
fi

echo "========================================"
echo "  WORKFLOW AUDIT REPORT"
echo "========================================"
echo "Scope: ${MODE:---project}"
echo "Range: $RANGE"
echo ""

# ── 1. Tool Usage ──
echo "─── Tool Usage ───"
sqlite3 -header -column "$DB" "
SELECT
  json_extract(p.data, '$.tool') AS tool,
  COUNT(*) AS calls,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM part p
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '$.type') = 'tool'
  $PF
  $TIME_FILTER_PART
GROUP BY tool
ORDER BY calls DESC
LIMIT 25;
"
echo ""

# ── 1a. Bash Command Breakdown ──
echo "─── Bash Command Breakdown ───"
sqlite3 -header -column "$DB" "
WITH raw AS (
  SELECT
    CASE
      WHEN json_extract(p.data, '\$.state.input.command') LIKE 'rtk %'
        THEN 'rtk ' || substr(substr(json_extract(p.data, '\$.state.input.command'), 5), 1, instr(substr(json_extract(p.data, '\$.state.input.command'), 5) || ' ', ' ') - 1)
      ELSE substr(json_extract(p.data, '\$.state.input.command'), 1, instr(json_extract(p.data, '\$.state.input.command') || ' ', ' ') - 1)
    END AS command
  FROM part p
  JOIN session s ON s.id = p.session_id
  WHERE json_extract(p.data, '\$.tool') = 'bash'
    AND json_extract(p.data, '\$.type') = 'tool'
    $PF
    $TIME_FILTER_PART
)
SELECT
  command,
  COUNT(*) AS calls,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM raw
GROUP BY command
ORDER BY calls DESC
LIMIT 20;
"
echo ""

# ── 1b. Tool Status Breakdown ──
echo "─── Tool Status Breakdown ───"
sqlite3 -header -column "$DB" "
SELECT
  json_extract(p.data, '$.tool') AS tool,
  json_extract(p.data, '$.state.status') AS status,
  COUNT(*) AS calls,
  ROUND(AVG(
    json_extract(p.data, '$.state.time.end') - json_extract(p.data, '$.state.time.start')
  )) AS avg_duration_ms
FROM part p
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '$.type') = 'tool'
  $PF
  $TIME_FILTER_PART
GROUP BY tool, status
ORDER BY tool, calls DESC;
"
echo ""

# ── 2. Skill Usage ──
echo "─── Skill Usage (loaded via skill tool) ───"
sqlite3 -header -column "$DB" "
SELECT
  json_extract(p.data, '$.state.input.name') AS skill_name,
  COUNT(*) AS loaded
FROM part p
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '$.tool') = 'skill'
  $PF
  $TIME_FILTER_PART
GROUP BY skill_name
ORDER BY loaded DESC;
"
echo ""

# ── 3. Available Skills on Disk ──
echo "─── Available Skills on Disk ───"
{
  find -L "$HOME/.config/opencode/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null
  find -L "$HOME/.claude/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null
} | while read -r f; do
  basename "$(dirname "$f")"
done | sort -u | while read -r name; do
  echo "  $name"
done
echo ""

# ── 4. Agent Usage ──
echo "─── Agent Usage ───"
sqlite3 -header -column "$DB" "
SELECT
  s.agent,
  COUNT(*) AS sessions,
  ROUND(SUM(s.cost), 2) AS total_cost,
  SUM(s.tokens_input) AS total_input,
  SUM(s.tokens_output) AS total_output
FROM session s
WHERE 1=1
  $SESSION_CONDITION
  $TIME_FILTER_SESSION
GROUP BY s.agent
ORDER BY sessions DESC;
"
echo ""

# ── 5. Model Usage ──
echo "─── Model Usage ───"
sqlite3 -header -column "$DB" "
SELECT
  COALESCE(json_extract(s.model, '$.id'), s.model) AS model,
  COUNT(*) AS sessions,
  ROUND(SUM(s.cost), 2) AS total_cost,
  SUM(s.tokens_input) AS total_input,
  SUM(s.tokens_output) AS total_output
FROM session s
WHERE 1=1
  $SESSION_CONDITION
  $TIME_FILTER_SESSION
GROUP BY model
ORDER BY sessions DESC;
"
echo ""

# ── 6. Sessions Overview ──
echo "─── Sessions Overview ───"
sqlite3 -header -column "$DB" "
SELECT
  COUNT(*) AS total_sessions,
  ROUND(SUM(s.cost), 2) AS total_cost,
  SUM(s.tokens_input) AS total_input_tokens,
  SUM(s.tokens_output) AS total_output_tokens
FROM session s
WHERE 1=1
  $SESSION_CONDITION
  $TIME_FILTER_SESSION;
"
echo ""

# ── 7. Prompt Intent Distribution ──
echo "─── Prompt Intent Distribution ───"
sqlite3 "$DB" "
SELECT json_extract(p.data, '\$.text')
FROM part p
JOIN message m ON m.id = p.message_id
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '\$.type') = 'text'
  AND json_extract(m.data, '\$.role') = 'user'
  AND length(trim(json_extract(p.data, '\$.text'))) > 0
  $PF
  $TIME_FILTER_PART
" | awk '
BEGIN {
  split("config|git|debug|refactor|explain|audit|test|deploy", cats, "|")
  pats["config"] = "zshrc|gitconfig|opencode|dotfiles|setup|brew|symlink|tmux|vimrc"
  pats["git"] = "commit|branch|diff|push|rebase|merge|stash|pull request|pr"
  pats["debug"] = "error|fail|crash|fix|bug|broken|exception|stack trace"
  pats["refactor"] = "rename|move|extract|clean up|simplify|refactor|restructure|organize"
  pats["explain"] = "how|why|what does|explain|understand|describe|clarify"
  pats["audit"] = "report|workflow|usage|stats|analyze|audit|metrics"
  pats["test"] = "test|pytest|junit|unit test|integration test|coverage"
  pats["deploy"] = "deploy|release|publish|build|ci|cd|pipeline"
}
{
  prompt = tolower($0)
  c = "other"
  for (i in cats) {
    if (prompt ~ pats[cats[i]]) {
      c = cats[i]; break
    }
  }
  count[c]++
}
END {
  for (c in count) print count[c], c
}
' | sort -rn | head -10 | awk '{ printf "  %-12s %s\n", $1, $2 }'
echo ""

echo "─── Top Keywords ───"
sqlite3 "$DB" "
SELECT json_extract(p.data, '\$.text')
FROM part p
JOIN message m ON m.id = p.message_id
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '\$.type') = 'text'
  AND json_extract(m.data, '\$.role') = 'user'
  AND length(trim(json_extract(p.data, '\$.text'))) > 0
  $PF
  $TIME_FILTER_PART
" | awk '
BEGIN {
  split("config|git|debug|refactor|explain|audit|test|deploy", cats, "|")
  pats["config"] = "zshrc|gitconfig|opencode|dotfiles|setup|brew|symlink|tmux|vimrc"
  pats["git"] = "commit|branch|diff|push|rebase|merge|stash|pull request|pr"
  pats["debug"] = "error|fail|crash|fix|bug|broken|exception|stack trace"
  pats["refactor"] = "rename|move|extract|clean up|simplify|refactor|restructure|organize"
  pats["explain"] = "how|why|what does|explain|understand|describe|clarify"
  pats["audit"] = "report|workflow|usage|stats|analyze|audit|metrics"
  pats["test"] = "test|pytest|junit|unit test|integration test|coverage"
  pats["deploy"] = "deploy|release|publish|build|ci|cd|pipeline"
}
{
  prompt = tolower($0)
  for (i in cats) {
    n = split(pats[cats[i]], kws, "|")
    for (j = 1; j <= n; j++) {
      if (index(prompt, kws[j]) > 0) kwc[kws[j]]++
    }
  }
}
END {
  for (k in kwc) print kwc[k], k
}
' | sort -rn | head -20 | awk '{ printf "  %-12s %s\n", $1, $2 }'
echo ""

# ── 7c. Recent Prompts ──
echo "─── Recent Prompts (last 15) ───"
sqlite3 "$DB" "
SELECT p.time_created, replace(json_extract(p.data, '\$.text'), char(10), ' ')
FROM part p
JOIN message m ON m.id = p.message_id
JOIN session s ON s.id = p.session_id
WHERE json_extract(p.data, '\$.type') = 'text'
  AND json_extract(m.data, '\$.role') = 'user'
  AND length(trim(json_extract(p.data, '\$.text'))) > 0
  $PF
  $TIME_FILTER_PART
ORDER BY p.time_created DESC
LIMIT 15;
" | awk '
BEGIN {
  FS = "|"
  split("config|git|debug|refactor|explain|audit|test|deploy", cats, "|")
  pats["config"] = "zshrc|gitconfig|opencode|dotfiles|setup|brew|symlink|tmux|vimrc"
  pats["git"] = "commit|branch|diff|push|rebase|merge|stash|pull request|pr"
  pats["debug"] = "error|fail|crash|fix|bug|broken|exception|stack trace"
  pats["refactor"] = "rename|move|extract|clean up|simplify|refactor|restructure|organize"
  pats["explain"] = "how|why|what does|explain|understand|describe|clarify"
  pats["audit"] = "report|workflow|usage|stats|analyze|audit|metrics"
  pats["test"] = "test|pytest|junit|unit test|integration test|coverage"
  pats["deploy"] = "deploy|release|publish|build|ci|cd|pipeline"
}
{
  ts = $1
  text = $2
  prompt = tolower(text)

  c = "other"
  for (i in cats) {
    if (prompt ~ pats[cats[i]]) { c = cats[i]; break }
  }

  truncated = (length(text) > 80) ? substr(text, 1, 80) "..." : text
  gsub(/[[:space:]]+/, " ", truncated)
  printf "  [%-8s] %s\n", c, truncated
}
'
echo ""

# ── 8. Sessions per Project (only for --all) ──
if [ "$MODE" = "--all" ]; then
  echo "─── Sessions per Project ───"
  sqlite3 -header -column "$DB" "
  SELECT
    p.name AS project,
    p.worktree AS directory,
    COUNT(*) AS sessions,
    ROUND(SUM(s.cost), 2) AS total_cost
  FROM session s
  JOIN project p ON p.id = s.project_id
  WHERE 1=1
    $TIME_FILTER_SESSION
  GROUP BY s.project_id
  ORDER BY sessions DESC;
  "
  echo ""
fi
