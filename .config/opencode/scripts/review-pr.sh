#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"

if [[ -z "$INPUT" ]]; then
  echo "Usage: review-pr.sh <pr-url|owner/repo#number|#number>"
  exit 1
fi

OWNER=""
REPO=""
NUMBER=""

# Match patterns:
#   https://github.com/owner/repo/pull/123
#   owner/repo#123
#   owner/repo/123
pr_url_regex='github\.com/([^/]+)/([^/]+)/pull/([0-9]+)'
if [[ "$INPUT" =~ $pr_url_regex ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$INPUT" =~ ^([^/]+)/([^/#]+)#([0-9]+)$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$INPUT" =~ ^([^/]+)/([^/]+)/([0-9]+)$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$INPUT" =~ ^#([0-9]+)$ ]]; then
  NUMBER="${BASH_REMATCH[1]}"
  # Try to detect from git remote
  REMOTE=$(git remote get-url origin 2>/dev/null || true)
  if [[ "$REMOTE" =~ github\.com[:\/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  else
    echo "Error: Could not detect owner/repo from git remote. Use full URL or owner/repo#number."
    exit 1
  fi
else
  echo "Error: Unrecognized PR format. Use:"
  echo "  https://github.com/owner/repo/pull/123"
  echo "  owner/repo#123"
  echo "  #123 (uses git remote to detect owner/repo)"
  exit 1
fi

REPO_REF="$OWNER/$REPO"

echo "=== PR METADATA ==="
if ! PR_JSON=$(gh pr view "$NUMBER" -R "$REPO_REF" --json title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,state,createdAt,mergeable,closedAt,isDraft 2>&1); then
  echo "Error fetching PR: $PR_JSON"
  exit 1
fi
echo "$PR_JSON"

echo ""
echo "=== CHANGED FILES ==="
FILES_JSON=$(gh pr view "$NUMBER" -R "$REPO_REF" --json files --jq '.files[] | "\(.status) \(.additions) +\(.deletions) -\(.path)"' 2>/dev/null || echo "(failed to fetch file list)")
echo "$FILES_JSON"

echo ""
echo "=== DIFF ==="
DIFF=$(gh pr diff "$NUMBER" -R "$REPO_REF" 2>/dev/null || echo "(failed to fetch diff)")
MAX_DIFF_CHARS=80000
if [ "${#DIFF}" -gt "$MAX_DIFF_CHARS" ]; then
  echo "(Warning: diff is ${#DIFF} chars — truncating to $MAX_DIFF_CHARS)"
  echo "${DIFF:0:$MAX_DIFF_CHARS}"
  echo ""
  echo "... [truncated: diff was ${#DIFF} chars total]"
else
  echo "$DIFF"
fi

echo ""
echo "=== EXISTING REVIEWS AND COMMENTS ==="
REVIEWS_JSON=$(gh pr view "$NUMBER" -R "$REPO_REF" --json reviews,comments 2>/dev/null || echo "(failed to fetch reviews/comments)")
echo "$REVIEWS_JSON"
