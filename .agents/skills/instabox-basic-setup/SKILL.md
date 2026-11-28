---
name: instabox-basic-setup
description: Use when the user wants their instabox setup to use local tokens, git config or editor config — "put my tokens / dotfiles / git config into instabox", "set up my box like my laptop", "move my setup to instabox". Produces a names-only scan and a reviewable plan, saves known API tokens as org Secrets for their service's HTTPS API hosts, selects them on named sandboxes, and copies approved ordinary config files directly to named running sandboxes. It does not put files in the Secret store. Moves no code; for a repo, use instabox-move-repo.
metadata:
  installed-by: instabox
---

# Basic setup with org Secrets and sandbox config copies

Use the user's chosen org and sandbox IDs. Secrets are shared within an org. A sandbox that selects a Secret gets a placeholder in its environment; the outbound proxy puts the token into HTTPS request headers sent to the Secret's allowed hosts, and nowhere else. Other org sandboxes whose selection is `all`, including future sandboxes, can also use a newly saved Secret. Updating an existing Secret affects every sandbox already selecting it.

Only tokens in the built-in registry (`TOKEN_HOSTS` in `scripts/lib.mjs`) are saved, each for its service's API hosts: for example `ANTHROPIC_API_KEY` for `api.anthropic.com`, `OPENAI_API_KEY` for `api.openai.com`, `GH_TOKEN` and `GITHUB_TOKEN` for `api.github.com` and `github.com`. Every other credential-looking export becomes a manual step. Secrets work only for clients that send the token in an HTTPS header (Basic auth included); database URLs and signing keys need their own setup on the box. git over HTTPS (`github.com`) also needs git to get the placeholder from a credential helper such as `gh auth setup-git` on the box.

Git and editor configuration is copied separately, once, to the named running sandboxes. It is not stored as Secrets, does not consume Secret quota, and is not reapplied on start or resume. This skill moves no repository or agent history. Use `instabox-move-repo` for code and conversation history.

| Group | Destination | Sources |
| --- | --- | --- |
| Tokens | Encrypted org Secrets, each limited to its registry hosts | GitHub token through `gh auth token`; registry tokens in the environment or shell startup files; other credential-like exports listed as manual steps |
| Git | Files under the selected sandbox's home | `.gitconfig`, `.config/git/config`, global gitignore |
| Editor and terminal | Files under the selected sandbox's home | `.vimrc`, nvim config without plugin checkouts, `.tmux.conf` |

The scripts beside this file require Node 18+ locally and Python 3 in sandboxes receiving config files:

| Script | Responsibility |
| --- | --- |
| `scan.mjs` | Read-only inventory of names, source locations, sizes and manual setup requirements; no credential values in output |
| `plan.mjs` | Write and strictly parse the editable plan, binding it to an org and Secret metadata |
| `push.mjs` | Read approved values into memory, validate all inputs and quotas, save Secrets with their registry hosts through CLI stdin, merge sandbox selections, and copy config |
| `content.mjs` | Rewrite HOME paths, remove recognized credential lines, and adapt git/editor configuration for Linux |
| `install-files.py` | Install ordinary config files privately, refusing symlinks and unsafe paths; no Secret-store or legacy Vault access |

Never print credential values, shell startup files, credential-bearing config, or `gh auth token` output. Do not run these scripts against the user's machine unless their request authorizes this setup. Scripts may read credentials internally; their output is limited to names, sizes and outcomes. If a value cannot be obtained, let the user supply it through the hidden prompt of `instabox secrets set NAME --org ORG --host HOST`.

## 1. Scan and choose the org

```bash
instabox whoami
instabox org ls --json
S=~/.claude/skills/instabox-basic-setup/scripts # or the installed ~/.agents/skills path
W=$(mktemp -d)
node "$S/scan.mjs" > "$W/scan.json"
ORG_ID=<stable-org-id>
instabox secrets ls --org "$ORG_ID" --json > "$W/secrets.json"
instabox usage --json | jq '.limits.vault // {}' > "$W/limits.json"
```

Saving Secret values requires the org owner/admin: a sign-in, or the workspace's own `workspace:admin` API key in `INSTABOX_API_KEY`. A personal org's key and narrower keys can read metadata but cannot import values (`403 missing_scope`). Without a terminal, `secrets rm` needs `--yes`. Do not change the user's authentication silently: if value management is rejected, explain that they need an owner/admin session or a workspace key. A 404 for Secret routes means Secret management is not configured on that server.

Use `instabox get <box> --json` to resolve each intended sandbox to its stable `m_...` ID and confirm its `orgId`. No sandbox is required when the user only wants to save credentials. Config copying requires explicitly named running sandboxes; do not create a box merely to verify setup unless creation is authorized.

## 2. Prepare a concrete plan

```bash
node "$S/plan.mjs" write --scan "$W/scan.json" --secrets "$W/secrets.json" \
  --org "$ORG_ID" --sandbox <sandbox-id> > "$W/plan.md"
```

Repeat `--sandbox` for additional targets, or omit it to save Secrets without changing any selection or copying files. The plan lists `Org`, `Sandboxes` and checkboxes; each token row names the hosts its Secret is limited to. The org is bound to the metadata used to generate the plan; regenerate for another org. Sandbox IDs and checkboxes can be edited in the plan; hosts come from the registry and cannot.

The `env:` prefix in a row ID is the scanner's variable ID. Registry token rows are checked by default; keychain-backed sources are unchecked. Existing Secrets changed outside the last successful run are unchecked, and checking them authorizes replacement in the org. Files are unchecked when no sandbox is selected. Checking a config file authorizes replacement of that path on each named sandbox.

Show the concrete names, allowed hosts, org and target sandboxes. Obtain any choices or authorization the original request did not already provide before reading values or writing. Do not ask again for an action already explicitly authorized.

Parse the approved plan:

```bash
node "$S/plan.mjs" parse --scan "$W/scan.json" --secrets "$W/secrets.json" \
  --org "$ORG_ID" --limits "$W/limits.json" "$W/plan.md" > "$W/selection.json"
```

Exit 1 identifies malformed or missing rows, a changed org/catalog, a scan with a token outside the registry, unsafe config, or a file selection without targets. Fix choices without changing item IDs or deleting rows. Exit 3 identifies quota or copy-size limits. Config files have their own copy limits and do not count as Secret entries. Values are measured before push; plan generation never reads token values. Legacy selector-based plans and manifests grant no authority in the new model and must be regenerated.

## 3. Dry-run, then apply the approved selection

```bash
node "$S/push.mjs" --selection "$W/selection.json" --dry-run
node "$S/push.mjs" --selection "$W/selection.json"
```

The dry-run reads the approved credential sources and prepares filtered config, but makes no writes to InstaBox and does not change its local manifest. Sourcing a shell startup file may run its local initialization code; an approved keychain-backed source may invoke its lookup. Values remain in memory and CLI stdin, never in the plan, manifest, arguments or logs. Review the dry-run's metadata before applying any action not yet authorized.

The pusher verifies org ownership, target orgs, Secret IDs and versions, input limits and total Secret quota before mutations. If a selected Secret changed since planning, regenerate the plan. These are preflight checks, not a transaction across all CLI operations: concurrent org edits can still occur during application. A failed run reports partial outcomes; successfully saved Secrets remain in the org. Do not assume rollback or automatic removal of previously copied files.

Only selected token names are added to each target's selection; existing names are preserved, and a target selecting `all` stays `all`. Running targets receive an immediate refresh; stopped targets receive the selection at their next start, but config copying requires them to be running. A failed or pending refresh does not install config that may depend on those credentials. Existing processes need to reload their environment or restart to see new placeholders.

Files are transformed before direct copying: this machine's HOME becomes `/data/home`, recognized credential lines are removed, macOS-only lines and unsupported signing/SSH rewrites are commented out. Structured config suspected of containing credentials is rejected rather than copied verbatim. This filtering is best effort, not a guarantee that arbitrary configuration is credential-free. No git credential helper is added: the proxy fills the placeholder into git's Basic auth, but git on the box needs a helper that returns the placeholder (for example `gh auth setup-git` there). An existing org Secret by itself is not a sandbox selection; add it through an explicitly reviewed `instabox secrets select BOX --secrets ...` that keeps the other selected names.

The local manifest at `~/.config/instabox-basic-setup/pushed.json` stores org IDs, Secret IDs, versions and hosts, and copied sandbox paths, never values. It does not grant reuse across orgs or across deletion and recreation of a Secret. It records completed work for a repeat plan; it does not sync changes automatically.

## 4. Verify and report

```bash
instabox secrets show <box>
instabox exec <box> -- 'test "${GH_TOKEN+x}" = x && test -f "$HOME/.gitconfig"'
```

Use silent presence checks and metadata; never print variables to verify them. A placeholder's presence does not prove the upstream accepts the token. Confirm client behavior without logging credentials, and explain application restarts.

Report the org Secret names and hosts saved, sandbox IDs whose selections changed, config paths copied, failures and manual setup steps. Saving Secrets without targets changes no selection; replacing a value still affects sandboxes already selecting it. Say that git over HTTPS needs a credential helper such as `gh auth setup-git` on the box, and that credentials outside the registry (database URLs, cloud keys, other tokens) were not moved and need their own setup there; an HTTP API key can be added with `instabox secrets set NAME --org ORG --host HOST`. Future boxes created without `--secrets` keep their existing Vault behavior. Previously saved credentials or config not selected this time remain; deletion or cleanup needs its own intended scope.

Config edits in a sandbox are not overwritten at every resume. Shell aliases, SSH keys, cloud credential files, agent sign-in databases and repositories are outside this inventory. Complete the selected manual sign-in steps only within existing authorization. Remove `$W` when no longer needed; it contains metadata and choices, not credential values.
