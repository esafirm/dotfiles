#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/setup-common.sh"
[[ $# -eq 0 ]] || { printf 'Use ./setup.sh --only t3 for options such as --dry-run.\n' >&2; exit 2; }

settings="${T3CODE_HOME:-$HOME/.t3}/userdata/settings.json"

if [[ ! -f "$settings" ]]; then
  printf '  Skip T3 Code providers: no settings at %s\n' "$settings"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '  Skip T3 Code providers: jq is not installed\n'
  exit 0
fi

opencode_bin="$HOME/.local/bin/opencode-profile"
claude_bin="$HOME/.local/bin/claude"
work_config="$HOME/.claude-work"
personal_config="$HOME/.claude"

[[ -x "$opencode_bin" ]] || printf '  Warning: %s is missing. Run --only links first.\n' "$opencode_bin"

# Keep the Claude instances on PATH lookup when the local binary is absent.
[[ -x "$claude_bin" ]] || claude_bin=""

updated="$(
  jq \
    --arg opencodeBin "$opencode_bin" \
    --arg claudeBin "$claude_bin" \
    --arg workConfig "$work_config" \
    --arg personalConfig "$personal_config" \
    '
      def claudeConfig($home):
        {"homePath": $home}
        + (if $claudeBin == "" then {} else {"binaryPath": $claudeBin} end);

      def configure($current; $driver; $name; $config):
        ($current // {"driver": $driver})
        | .driver = $driver
        | .enabled = true
        | .displayName = $name
        | .config = ((.config // {}) + $config);

      .providerInstances = (.providerInstances // {})
      | .providerInstances.opencode =
          configure(.providerInstances.opencode; "opencode"; "OpenCode"; {"binaryPath": $opencodeBin})
      | .providerInstances.claudeAgent =
          configure(.providerInstances.claudeAgent; "claudeAgent"; "Claude Work"; claudeConfig($workConfig))
      | .providerInstances.claudeAgentPersonal =
          configure(.providerInstances.claudeAgentPersonal; "claudeAgent"; "Claude Personal"; claudeConfig($personalConfig))
    ' "$settings"
)"

if [[ "$updated" == "$(cat -- "$settings")" ]]; then
  printf '  Already configured: %s\n' "$settings"
  exit 0
fi

printf '  Configure T3 Code providers in %s\n' "$settings"
printf '    opencode -> %s\n' "$opencode_bin"
printf '    Claude Work -> %s\n' "$work_config"
printf '    Claude Personal -> %s\n' "$personal_config"

setup_backup "$settings" copy
printf '  Write %s\n' "$settings"
if [[ "$SETUP_DRY_RUN" != 1 ]]; then
  temp="$settings.$$.tmp"
  printf '%s\n' "$updated" > "$temp"
  chmod "$(stat -f %Lp "$settings" 2>/dev/null || stat -c %a "$settings" 2>/dev/null || echo 600)" "$temp"
  mv -- "$temp" "$settings"
fi
