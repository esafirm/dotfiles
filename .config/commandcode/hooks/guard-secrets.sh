#!/usr/bin/env bash
# PreToolUse guard: deny any tool call that touches the user's secret paths.
# Registered from ~/.commandcode/settings.json. Mirrors opencode's
# permission.external_directory deny for secrets/secret_dir/keepsecret.
set -euo pipefail

payload="$(cat)"
display="$(printf '%s' "$payload" | jq -r '.tool_display_name // ""' | tr '[:upper:]' '[:lower:]')"

case "$display" in
  shell) target="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')" ;;
  read)  target="$(printf '%s' "$payload" | jq -r '.tool_input.absolute_path // ""')" ;;
  write) target="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')" ;;
  edit)  target="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')" ;;
  *) exit 0 ;;
esac

[[ -n "$target" ]] || exit 0

# Require a path-like prefix so a bare word ("git log --grep secrets") never matches.
pattern='(~|\$HOME|'"$HOME"')/(secrets|secret_dir|keepsecret)(/|[^[:alnum:]_-]|$)'
pattern+='|(^|[^[:alnum:]_-])dotfiles/(secrets|secret_dir|keepsecret)(/|[^[:alnum:]_-]|$)'

if printf '%s' "$target" | grep -Eq "$pattern"; then
  jq -n --arg t "$target" '{
    systemMessage: "Blocked access to a secret path",
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Access to secret paths (secrets, secret_dir, keepsecret) is forbidden by policy. Blocked: " + ($t[0:200]))
    }
  }'
fi

exit 0
