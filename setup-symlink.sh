#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/setup-common.sh"
[[ $# -eq 0 ]] || { printf 'Use ./setup.sh --only links for options such as --dry-run.\n' >&2; exit 2; }

# Each call is: setup_link "source in this repo" "destination".

## Shell and Git
setup_link "$SETUP_ROOT/.vimrc" "$HOME/.vimrc"
setup_link "$SETUP_ROOT/.zshrc" "$HOME/.zshrc"
setup_link "$SETUP_ROOT/.warprc" "$HOME/.warprc"
setup_link "$SETUP_ROOT/.gitconfig" "$HOME/.gitconfig"

## Neovim
setup_link "$SETUP_ROOT/.config/nvim" "$HOME/.config/nvim"

## Gemini
setup_link "$SETUP_ROOT/.gemini/settings.json" "$HOME/.gemini/settings.json"
setup_link "$SETUP_ROOT/.gemini/projects.json" "$HOME/.gemini/projects.json"
setup_link "$SETUP_ROOT/.agents/AGENTS.md" "$HOME/.gemini/GEMINI.md"
setup_link "$SETUP_ROOT/.gemini/antigravity-cli/settings.json" "$HOME/.gemini/antigravity-cli/settings.json"
setup_link "$SETUP_ROOT/.gemini/extensions/extension-enablement.json" "$HOME/.gemini/extensions/extension-enablement.json"
setup_link "$SETUP_ROOT/.gemini/config/mcp_config.json" "$HOME/.gemini/config/mcp_config.json"

## Claude Code
setup_link "$SETUP_ROOT/.config/claude/settings.json" "$HOME/.claude/settings.json"
if [[ ! -e "$HOME/.claude/keybindings.json" && ! -L "$HOME/.claude/keybindings.json" ]]; then
  setup_link "$SETUP_ROOT/.config/claude/keybindings.json" "$HOME/.claude/keybindings.json"
else
  printf '  Keeping existing ~/.claude/keybindings.json (not replacing it)\n'
fi
setup_link "$SETUP_ROOT/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
setup_link "$SETUP_ROOT/.config/claude/skills" "$HOME/.claude/skills"
setup_link "$SETUP_ROOT/.config/claude/hooks/herdr-agent-state.sh" "$HOME/.claude/hooks/herdr-agent-state.sh"
setup_link "$SETUP_ROOT/.config/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"

## OpenCode
setup_link "$SETUP_ROOT/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
setup_link "$SETUP_ROOT/.agents/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
setup_link "$SETUP_ROOT/.config/opencode/cli.json" "$HOME/.config/opencode/cli.json"
setup_link "$SETUP_ROOT/.config/opencode/plugins/auto-mode" "$HOME/.config/opencode/plugins/auto-mode"
setup_link "$SETUP_ROOT/.config/opencode/package.json" "$HOME/.config/opencode/package.json"
setup_link "$SETUP_ROOT/.config/opencode/package-lock.json" "$HOME/.config/opencode/package-lock.json"
setup_link "$SETUP_ROOT/.config/opencode/.gitignore" "$HOME/.config/opencode/.gitignore"
setup_link "$SETUP_ROOT/.config/opencode/agents/advice.md" "$HOME/.config/opencode/agents/advice.md"
setup_link "$SETUP_ROOT/.config/opencode/agents/pr-reviewer.md" "$HOME/.config/opencode/agents/pr-reviewer.md"
setup_link "$SETUP_ROOT/.config/opencode/agents/verify-finding.md" "$HOME/.config/opencode/agents/verify-finding.md"
setup_link "$SETUP_ROOT/.config/opencode/commands/workflow-audit.md" "$HOME/.config/opencode/commands/workflow-audit.md"
setup_link "$SETUP_ROOT/.config/opencode/commands/advice.md" "$HOME/.config/opencode/commands/advice.md"
setup_link "$SETUP_ROOT/.config/opencode/commands/review-pr.md" "$HOME/.config/opencode/commands/review-pr.md"
setup_link "$SETUP_ROOT/.config/opencode/commands/verify.md" "$HOME/.config/opencode/commands/verify.md"
setup_link "$SETUP_ROOT/.config/opencode/commands/trash.md" "$HOME/.config/opencode/commands/trash.md"
setup_link "$SETUP_ROOT/.config/opencode/scripts/workflow-audit.sh" "$HOME/.config/opencode/scripts/workflow-audit.sh"
setup_link "$SETUP_ROOT/.config/opencode/scripts/review-pr.sh" "$HOME/.config/opencode/scripts/review-pr.sh"
setup_link "$SETUP_ROOT/.config/opencode/scripts/ai-trash.sh" "$HOME/.config/opencode/scripts/ai-trash.sh"
setup_link "$SETUP_ROOT/.config/claude/skills" "$HOME/.config/opencode/skills"

## Shared agent skills
setup_link "$SETUP_ROOT/.agents/skills" "$HOME/.agents/skills"
setup_link "$SETUP_ROOT/.agents/.skill-lock.json" "$HOME/.agents/.skill-lock.json"

## CLI tools
setup_link "$SETUP_ROOT/kotlin/kscripts/jenkins-cli.main.kts" "$HOME/scripts/jenkins-cli.main.kts"
setup_link "$SETUP_ROOT/bin/llm-wiki-mcp" "$HOME/.local/bin/llm-wiki-mcp"
setup_link "$SETUP_ROOT/bin/play-store-mcp" "$HOME/.local/bin/play-store-mcp"
setup_link "$SETUP_ROOT/kotlin/kscripts/jenkins" "$SETUP_ROOT/bin/jenkins"

## herdr
setup_link "$SETUP_ROOT/.config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
setup_link "$SETUP_ROOT/.config/herdr/presentation.toml" "$HOME/.config/herdr/presentation.toml"
setup_link "$SETUP_ROOT/bin/herdr-presentation" "$HOME/.local/bin/herdr-presentation"
setup_link "$SETUP_ROOT/bin/herdr-presentation-status" "$HOME/.local/bin/herdr-presentation-status"

## Ghostty
setup_link "$SETUP_ROOT/.config/ghostty/config" "$HOME/.config/ghostty/config"
setup_link "$SETUP_ROOT/.config/ghostty/appearance" "$HOME/.config/ghostty/appearance"
setup_link "$SETUP_ROOT/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
setup_link "$SETUP_ROOT/.config/ghostty/appearance" "$HOME/Library/Application Support/com.mitchellh.ghostty/appearance"

# Claude's config mixes MCP servers with runtime state, so register them via CLI.
# Keep in sync with opencode.jsonc.
if command -v claude >/dev/null 2>&1; then
  claude_config="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
  mcp_backed_up=0
  claude_mcp() {
    local comparison='def defaults: .args //= [] | .env //= {}; (.mcpServers[$name] | defaults) == ($expected | defaults)'
    # jq is optional. Without it, safely refresh entries as before.
    if command -v jq >/dev/null 2>&1 && [[ -f "$claude_config" ]] &&
      jq -e --arg name "$1" --argjson expected "$2" "$comparison" "$claude_config" >/dev/null 2>&1; then
      printf '  MCP already configured: %s\n' "$1"
      return 0
    fi
    if [[ "$mcp_backed_up" == 0 ]]; then
      if [[ -f "$claude_config" ]]; then
        setup_backup "$claude_config" copy
      fi
      mcp_backed_up=1
    fi
    # remove returns nonzero for absent entries. The following add must succeed.
    setup_run claude mcp remove -s user "$1" >/dev/null 2>&1 || true
    setup_run claude mcp add-json -s user "$1" "$2"
  }
  claude_mcp android-studio '{"type":"http","url":"http://127.0.0.1:64342/stream"}'
  claude_mcp firebase '{"type":"stdio","command":"firebase","args":["mcp","--only","crashlytics","--dir","/tmp"]}'
  claude_mcp llm-wiki '{"type":"stdio","command":"llm-wiki-mcp"}'
  claude_mcp play-store '{"type":"stdio","command":"play-store-mcp"}'
  claude_mcp slack '{"type":"http","url":"https://mcp.slack.com/mcp"}'
fi

## Dotfiles git hooks (pre-push verifies MCP sync between opencode and Claude)
if [[ "$(git -C "$SETUP_ROOT" config --local --get core.hooksPath || true)" != .githooks ]]; then
  git_config="$(git -C "$SETUP_ROOT" rev-parse --path-format=absolute --git-path config)"
  setup_backup "$git_config" copy
  setup_run git -C "$SETUP_ROOT" config --local core.hooksPath .githooks
fi

## Ghostex keeps its own managed settings; include the shared appearance.
ghostex="$HOME/.config/ghostex/ghostty/config.ghostty"
if ! grep -Fqx 'config-file = ../../ghostty/appearance' "$ghostex" 2>/dev/null; then
  if [[ -e "$ghostex" ]]; then
    setup_backup "$ghostex" copy
  fi
  printf '  Append shared Ghostty appearance to %s\n' "$ghostex"
  if [[ "$SETUP_DRY_RUN" != 1 ]]; then
    mkdir -p -- "$(dirname -- "$ghostex")"
    printf '\n# Shared with Ghostty\nconfig-file = ../../ghostty/appearance\n' >> "$ghostex"
  fi
fi

# Legacy locations are preserved rather than deleting potentially user-owned skills.
for legacy in "$HOME/.gemini/skills" "$HOME/.config/opencode/skill"; do
  if [[ -e "$legacy" || -L "$legacy" ]]; then
    printf '  Legacy skills left untouched: %s\n' "$legacy"
  fi
done
