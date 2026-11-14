# Global Claude profile

`/claude-profile` opens a picker without calling a model. It also accepts
`work`, `personal`, or `status`. The command palette has **Switch global Claude profile**.

- `personal` uses `~/.claude` (the default).
- `work` uses `~/.claude-work`.

Both profiles keep their existing shared dotfiles symlinks. This changes the
Claude Agent login, not OpenCode's skills or configuration. It does not create
profiles, copy credentials, or sign in for you.

## Setup

`setup-symlink.sh` installs the plugin and `~/.local/bin/opencode-claude`.
Enable the wrapper once, when it is safe to restart the OpenCode service:

```sh
opencode service set env OPENCODE_CLAUDE_PATH "$HOME/.local/bin/opencode-claude"
```

Sign in to the work profile interactively if needed:

```sh
CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude auth login
```

After activation, switching does not restart OpenCode. Selection is stored in
`${XDG_STATE_HOME:-$HOME/.local/state}/opencode/claude-profile` and applies to all
new local Claude processes. Running processes retain their login. Start a new
OpenCode session when changing accounts. The picker controls the local machine,
not a remotely connected service. Explicit API-key/token environment overrides
can take precedence over a profile's saved login.

From a terminal, use `opencode-claude --profile work|personal|status`.
To stop using the wrapper, run
`opencode service unset env OPENCODE_CLAUDE_PATH` (also restarts the service).

## Clients that spawn their own server

T3 Code starts its own `opencode serve` process, so it does not inherit the
service environment and the setting above has no effect there. Set T3 Code's
OpenCode **Binary path** to `~/.local/bin/opencode-profile`. That launcher
exports `OPENCODE_CLAUDE_PATH` before starting OpenCode, which makes the Claude
Agent provider honor the selected profile. Start a new thread after switching.

T3 Code's native Claude provider is separate. Add one Claude provider instance
per profile instead of switching a single instance: Work sets
`CLAUDE_CONFIG_DIR` to `~/.claude-work`, and Personal leaves it unset so it
keeps the default `~/.claude.json` and Keychain entry. `setup-t3.sh` configures
both, so the profile picker does not change which Claude accounts T3 can use.

## Verify

```sh
python3 tests/test-opencode-claude.py
bun test tests/claude-profile.test.ts
bash -n bin/opencode-claude
```
