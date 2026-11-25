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
codex_bin="$HOME/.local/bin/codex"
agy_bin="$HOME/.local/bin/agy"
work_config="$HOME/.claude-work"

[[ -x "$opencode_bin" ]] || printf '  Warning: %s is missing. Run --only links first.\n' "$opencode_bin"

# Keep the Claude and Codex instances on PATH lookup when the local binary is absent.
[[ -x "$claude_bin" ]] || claude_bin=""
[[ -x "$codex_bin" ]] || codex_bin=""
# T3 only auto-detects agy_acp_server.par, so Antigravity needs the agy path. Leave it alone without one.
[[ -x "$agy_bin" ]] || agy_bin=""

updated="$(
  jq \
    --slurpfile shared "$(dirname -- "${BASH_SOURCE[0]}")/.config/t3/settings.json" \
    --arg opencodeBin "$opencode_bin" \
    --arg claudeBin "$claude_bin" \
    --arg codexBin "$codex_bin" \
    --arg agyBin "$agy_bin" \
    --arg workConfig "$work_config" \
    '
      def claudeBinary:
        if $claudeBin == "" then {} else {"binaryPath": $claudeBin} end;

      def codexConfig:
        {"setupMode": "existing"}
        + (if $codexBin == "" then {} else {"binaryPath": $codexBin} end);

      def configure($current; $driver; $name; $config):
        ($current // {"driver": $driver})
        | .driver = $driver
        | .enabled = true
        | .displayName = $name
        | .config = ((.config // {}) + $config);

      . * $shared[0]
      | .providerInstances = (.providerInstances // {})
      | .providerInstances.opencode =
          configure(.providerInstances.opencode; "opencode"; "OpenCode"; {"binaryPath": $opencodeBin})
      | .providerInstances.codex =
          configure(.providerInstances.codex; "codex"; "Codex"; codexConfig)
      | if $agyBin == "" then . else
          .providerInstances.antigravity =
            configure(.providerInstances.antigravity; "antigravity"; "Antigravity"; {"binaryPath": $agyBin})
        end
      | .providerInstances.claudeAgent =
          configure(.providerInstances.claudeAgent; "claudeAgent"; "Claude Work"; ({"homePath": $workConfig} + claudeBinary))
      | .providerInstances.claudeAgentPersonal =
          (configure(.providerInstances.claudeAgentPersonal; "claudeAgent"; "Claude Personal"; claudeBinary)
           | .config |= del(.homePath))
    ' "$settings"
)"

client_settings="$(dirname -- "$settings")/client-settings.json"
if [[ -f "$client_settings" ]]; then
  client_updated="$(jq --slurpfile shared "$(dirname -- "${BASH_SOURCE[0]}")/.config/t3/client-settings.json" '. * $shared[0]' "$client_settings")"
  if [[ "$client_updated" != "$(cat -- "$client_settings")" ]]; then
    setup_backup "$client_settings" copy
    printf '  Configure T3 Code client preferences in %s\n' "$client_settings"
    if [[ "$SETUP_DRY_RUN" != 1 ]]; then
      client_temp="$client_settings.$$.tmp"
      printf '%s\n' "$client_updated" > "$client_temp"
      chmod "$(stat -f %Lp "$client_settings" 2>/dev/null || stat -c %a "$client_settings" 2>/dev/null || echo 600)" "$client_temp"
      mv -- "$client_temp" "$client_settings"
    fi
  fi
fi

# Publish shared themes by copy, then make ours the environment theme once.
# Re-running `t3 theme set` would undo a theme picked in the app, so skip it when already set.
themes_dir="$(dirname -- "$settings")/themes"
for theme in "$(dirname -- "${BASH_SOURCE[0]}")"/.config/t3/themes/*.json; do
  [[ -f "$theme" ]] || continue
  target="$themes_dir/$(basename -- "$theme")"
  if [[ -f "$target" ]] && cmp -s -- "$theme" "$target"; then
    continue
  fi
  [[ ! -e "$target" ]] || setup_backup "$target" copy
  printf '  Publish T3 Code theme %s\n' "$target"
  if [[ "$SETUP_DRY_RUN" != 1 ]]; then
    mkdir -p -- "$themes_dir"
    # T3 reads published themes live, so rename into place to avoid a partial read.
    cp -- "$theme" "$target.$$.tmp"
    mv -- "$target.$$.tmp" "$target"
  fi
done

t3_theme="dotfiles"
t3_bin="$HOME/.local/bin/t3"
[[ -x "$t3_bin" ]] || t3_bin="$(command -v t3 || true)"
if [[ -z "$t3_bin" ]]; then
  printf '  Skip T3 Code theme selection: t3 CLI not found\n'
elif "$t3_bin" theme show 2>/dev/null | grep -Eq "^Environment theme: \"?${t3_theme}([^[:alnum:]_-]|$)"; then
  printf '  Already selected T3 Code theme: %s\n' "$t3_theme"
else
  setup_run "$t3_bin" theme set "$t3_theme" || printf '  Warning: could not set the T3 Code theme. Pick %s in Settings > Appearance.\n' "$t3_theme"
fi

if [[ "$updated" == "$(cat -- "$settings")" ]]; then
  printf '  Already configured: %s\n' "$settings"
  exit 0
fi

printf '  Configure T3 Code providers in %s\n' "$settings"
printf '    opencode -> %s\n' "$opencode_bin"
printf '    Codex -> %s\n' "${codex_bin:-codex from PATH}"
printf '    Antigravity -> %s\n' "${agy_bin:-unchanged (no ~/.local/bin/agy)}"
printf '    Claude Work -> %s\n' "$work_config"
printf '    Claude Personal -> host default (no CLAUDE_CONFIG_DIR)\n'

setup_backup "$settings" copy
printf '  Write %s\n' "$settings"
if [[ "$SETUP_DRY_RUN" != 1 ]]; then
  temp="$settings.$$.tmp"
  printf '%s\n' "$updated" > "$temp"
  chmod "$(stat -f %Lp "$settings" 2>/dev/null || stat -c %a "$settings" 2>/dev/null || echo 600)" "$temp"
  mv -- "$temp" "$settings"
fi
