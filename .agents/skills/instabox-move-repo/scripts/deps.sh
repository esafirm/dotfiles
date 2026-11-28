#!/usr/bin/env bash
# instabox-move-repo: install a moved project's toolchain and dependencies on the box.
#
#   bash -l deps.sh [--dry-run] [--no-smoke] [DIR]
#
# Detects the toolchain from the project's lockfiles and manifests (DIR, default the current
# directory, and each first-level subdirectory that has a lockfile of its own), installs a runtime
# only when it is missing or the project pins another version, installs the dependencies with
# the project's own package manager without rewriting its lockfile, then runs an obvious build
# as a smoke test. A failed step is reported and the next one still runs; the exit status is 1
# when any step failed. --dry-run prints the steps without running them.
# Never reads .env files: it only says where one is expected.
set -u

DRY=0
SMOKE=1
DIR=.
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1 ;;
    --no-smoke) SMOKE=0 ;;
    -h | --help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "deps.sh: unknown option $1" >&2
      exit 2
      ;;
    *) DIR=$1 ;;
  esac
  shift
done
cd "$DIR" || exit 2
ROOT=$(pwd)

export DEBIAN_FRONTEND=noninteractive COREPACK_ENABLE_DOWNLOAD_PROMPT=0 CI=1
OK=()
FAILED=()
NOTES=()
DONE_RUNTIMES=" "

have() { command -v "$1" >/dev/null 2>&1; }
note() { NOTES+=("$1"); }

# step LABEL CMD: run CMD (a shell string) in a subshell in the current directory, stdin closed.
step() {
  local label=$1 cmd=$2
  echo "==> $label: $cmd"
  if [ "$DRY" = 1 ]; then
    OK+=("$label")
    return 0
  fi
  if (eval "$cmd") </dev/null; then
    OK+=("$label")
  else
    echo "!!! $label failed" >&2
    FAILED+=("$label")
    return 1
  fi
}

# runtime NAME CMD: like step, in this shell (so PATH changes stick), once per runtime.
runtime() {
  local name=$1 cmd=$2
  case $DONE_RUNTIMES in *" $name "*) return 0 ;; esac
  DONE_RUNTIMES="$DONE_RUNTIMES$name "
  echo "==> install $name: $cmd"
  if [ "$DRY" = 1 ]; then
    OK+=("install $name")
    return 0
  fi
  if eval "$cmd" </dev/null; then
    OK+=("install $name")
  else
    echo "!!! install $name failed" >&2
    FAILED+=("install $name")
    return 1
  fi
}

# persist LINE: add a line to the login and interactive shell files once, for later shells.
persist() {
  [ "$DRY" = 1 ] && return 0
  local f p=
  for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
    [ -e "$f" ] && p=$f && break
  done
  [ -n "$p" ] || p=$HOME/.profile
  for f in "$p" "$HOME/.bashrc"; do
    grep -qxF "$1" "$f" 2>/dev/null || printf '%s\n' "$1" >>"$f"
  done
}

APT_UPDATED=0
apt_install() {
  local pre=
  [ "$APT_UPDATED" = 1 ] || pre='sudo apt-get update -qq && '
  APT_UPDATED=1
  echo "${pre}sudo apt-get install -y -qq $*"
}

arch() {
  case $(uname -m) in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

first_line() { head -n 1 "$1" 2>/dev/null | tr -d ' \r\t' | sed 's/^v//'; }

# --- runtimes -----------------------------------------------------------------------------

ensure_mise() {
  have mise || [ -x "$HOME/.local/bin/mise" ] ||
    runtime mise 'curl -fsSL https://mise.run | sh'
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  persist 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"'
}

ensure_node() {
  local want=$1 have_major=
  have node && have_major=$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')
  case $want in
    '' | node | stable | current | 'lts/*' | lts) [ -n "$have_major" ] && return 0 ;;
    [0-9]*) [ "${want%%.*}" = "$have_major" ] && return 0 ;;
  esac
  [ -n "$want" ] || want=--lts
  local nvm='export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash; . "$NVM_DIR/nvm.sh"'
  runtime "node $want" "$nvm && nvm install $want && nvm alias default $want" &&
    persist 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
}

ensure_pm() { # pnpm | yarn
  have "$1" && return 0
  runtime "$1" "corepack enable 2>/dev/null || sudo -n env PATH=\"\$PATH\" corepack enable 2>/dev/null || npm install -g $1 || sudo -n env PATH=\"\$PATH\" npm install -g $1"
}

ensure_bun() {
  have bun && return 0
  runtime bun 'curl -fsSL https://bun.sh/install | bash' && export PATH="$HOME/.bun/bin:$PATH"
  persist 'export PATH="$HOME/.bun/bin:$PATH"'
}

ensure_uv() {
  have uv && return 0
  runtime uv 'curl -LsSf https://astral.sh/uv/install.sh | sh' && export PATH="$HOME/.local/bin:$PATH"
  persist 'export PATH="$HOME/.local/bin:$PATH"'
}

ensure_uv_tool() { # name
  have "$1" && return 0
  ensure_uv
  runtime "$1" "uv tool install $1" && export PATH="$HOME/.local/bin:$PATH"
}

ensure_rust() {
  have cargo && return 0
  [ -x "$HOME/.cargo/bin/cargo" ] && export PATH="$HOME/.cargo/bin:$PATH" && return 0
  runtime rust "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal" &&
    export PATH="$HOME/.cargo/bin:$PATH"
  persist '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
}

ensure_go() {
  have go && return 0
  [ -x /usr/local/go/bin/go ] && export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH" && return 0
  runtime go "v=\$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n 1) && curl -fsSL \"https://go.dev/dl/\$v.linux-$(arch).tar.gz\" | sudo tar -C /usr/local -xz" &&
    export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
  persist 'export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"'
}

ensure_ruby() {
  have ruby && have bundle && return 0
  have ruby || runtime ruby "$(apt_install ruby-full build-essential)"
  have bundle || runtime bundler 'gem install --user-install bundler' &&
    export PATH="$(ruby -e 'print Gem.user_dir' 2>/dev/null)/bin:$PATH"
  persist 'command -v ruby >/dev/null && export PATH="$(ruby -e "print Gem.user_dir")/bin:$PATH"'
}

ensure_java() { # also maven when asked
  have java && have javac || runtime jdk "$(apt_install default-jdk-headless)"
  [ "${1-}" = maven ] && ! have mvn && runtime maven "$(apt_install maven)"
  return 0
}

ensure_php() {
  have php && have composer && return 0
  runtime php "$(apt_install php-cli php-xml php-mbstring php-curl php-zip unzip composer)"
}

# --- one project directory -------------------------------------------------------------------

# has_script NAME: package.json's "scripts" object has NAME. Node is installed by then; without it
# (a dry run on a machine with no node) fall back to a plain text match.
has_script() {
  have node || { grep -Eq "\"$1\"[[:space:]]*:" package.json 2>/dev/null; return; }
  node -e 'const s=(JSON.parse(require("fs").readFileSync("package.json","utf8"))||{}).scripts; process.exit(s && typeof s[process.argv[1]]==="string" ? 0 : 1)' "$1" 2>/dev/null
}

node_project() { # label
  local L=$1 pm= want=
  [ -f package.json ] || return 0
  pm=$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([a-z]*\)@.*/\1/p' package.json | head -n 1)
  if [ -z "$pm" ]; then
    if [ -f pnpm-lock.yaml ]; then pm=pnpm
    elif [ -f yarn.lock ]; then pm=yarn
    elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm=bun
    else pm=npm
    fi
  fi
  [ -f .nvmrc ] && want=$(first_line .nvmrc)
  [ -z "$want" ] && [ -f .node-version ] && want=$(first_line .node-version)
  if [ "$pm" = bun ]; then ensure_bun; else ensure_node "$want"; fi
  case $pm in
    pnpm)
      ensure_pm pnpm
      step "$L pnpm install" 'pnpm install --frozen-lockfile'
      ;;
    yarn)
      ensure_pm yarn
      if [ -f .yarnrc.yml ]; then step "$L yarn install" 'yarn install --immutable'
      else step "$L yarn install" 'yarn install --frozen-lockfile'
      fi
      ;;
    bun) step "$L bun install" 'bun install --frozen-lockfile' ;;
    *)
      if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then step "$L npm ci" 'npm ci'
      else step "$L npm install" 'npm install --no-package-lock'
      fi
      ;;
  esac
  if [ "$SMOKE" = 1 ] && has_script build; then step "$L build" "$pm run build"; fi
}

python_project() {
  local L=$1 reqs= f
  if [ -f uv.lock ]; then
    ensure_uv
    step "$L uv sync" 'uv sync --frozen'
  elif [ -f poetry.lock ]; then
    ensure_uv_tool poetry
    step "$L poetry install" 'poetry install --no-interaction'
  elif [ -f Pipfile.lock ]; then
    ensure_uv_tool pipenv
    step "$L pipenv sync" 'pipenv sync --dev'
  elif [ -f pdm.lock ]; then
    ensure_uv_tool pdm
    step "$L pdm sync" 'pdm sync'
  else
    for f in requirements*.txt *requirements.txt; do
      [ -f "$f" ] || continue
      case " $reqs " in *" -r $f "*) continue ;; esac
      reqs="$reqs -r $f"
    done
    if [ -n "$reqs" ]; then
      ensure_uv
      step "$L pip install" "{ [ -d .venv ] || uv venv; } && uv pip install$reqs"
    elif [ -f pyproject.toml ] || [ -f setup.py ]; then
      ensure_uv
      step "$L pip install -e ." '{ [ -d .venv ] || uv venv; } && uv pip install -e .'
    fi
  fi
}

project() { # dir label
  local d=$1 L=$2 f
  cd "$ROOT/$d" || return 0
    # Toolchain pins for many languages at once (.tool-versions, mise.toml): mise installs them.
    if [ -f .tool-versions ] || [ -f mise.toml ] || [ -f .mise.toml ]; then
      ensure_mise
      step "$L mise install" 'mise trust --yes . >/dev/null 2>&1; mise install --yes'
    fi
    node_project "$L"
    if [ -f uv.lock ] || [ -f poetry.lock ] || [ -f Pipfile.lock ] || [ -f pdm.lock ] || [ -f pyproject.toml ] ||
      [ -f setup.py ] || ls requirements*.txt *requirements.txt >/dev/null 2>&1; then
      python_project "$L"
    fi
    if [ -f Cargo.toml ] && { [ "$d" = . ] || [ ! -f "$ROOT/Cargo.toml" ]; }; then
      ensure_rust
      if [ -f Cargo.lock ]; then step "$L cargo fetch" 'cargo fetch --locked'
      else step "$L cargo fetch" 'cargo fetch'
      fi
      [ "$SMOKE" = 1 ] && step "$L cargo build" 'cargo build'
    fi
    if [ -f go.mod ] && { [ "$d" = . ] || [ ! -f "$ROOT/go.work" ]; }; then
      ensure_go
      step "$L go mod download" 'go mod download'
      [ "$SMOKE" = 1 ] && step "$L go build" 'go build ./...'
    fi
    if [ -f Gemfile ]; then
      ensure_ruby
      step "$L bundle install" 'bundle config set --global path "$HOME/.bundle/gems" && bundle install'
    fi
    if [ -f pom.xml ]; then
      if [ -x mvnw ]; then
        ensure_java
        step "$L maven deps" './mvnw -B -q dependency:go-offline'
        [ "$SMOKE" = 1 ] && step "$L maven compile" './mvnw -B -q -DskipTests compile'
      else
        ensure_java maven
        step "$L maven deps" 'mvn -B -q dependency:go-offline'
        [ "$SMOKE" = 1 ] && step "$L maven compile" 'mvn -B -q -DskipTests compile'
      fi
    fi
    if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
      if [ -x gradlew ]; then
        ensure_java
        [ "$SMOKE" = 1 ] && step "$L gradle assemble" './gradlew --no-daemon -q assemble'
      elif [ "$d" = . ]; then
        note "$L: Gradle project without ./gradlew: install Gradle by hand"
      fi
    fi
    if [ -f composer.json ]; then
      ensure_php
      step "$L composer install" 'composer install --no-interaction'
    fi
    [ -f mix.exs ] && note "$L: Elixir (mix.exs) is not installed automatically"
    { [ -f deno.json ] || [ -f deno.jsonc ]; } && note "$L: Deno project: install deno (curl -fsSL https://deno.land/install.sh | sh)"
    ls ./*.csproj ./*.sln >/dev/null 2>&1 && note "$L: .NET project: install the dotnet SDK by hand"
    [ -f Package.swift ] && note "$L: Swift package: not installed automatically"
    [ -f pubspec.yaml ] && note "$L: Dart/Flutter (pubspec.yaml): not installed automatically"
    { [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; } &&
      note "$L: has a compose file; its services were not started (docker compose up -d)"
    for f in .env.example .env.sample .env.template; do
      if [ -f "$f" ] && [ ! -e .env ]; then
        note "$L: expects a .env (see $f); .env files are not copied: the user sets it up (instabox-move-repo skill, step 7)"
        break
      fi
    done
  cd "$ROOT" || exit 2
}

# --- main ------------------------------------------------------------------------------------

status() { git status --porcelain 2>/dev/null; }
BEFORE=$(status)

project . root
# First-level subdirectories that are projects of their own (they have a lockfile or a
# standalone manifest); workspace members without one are installed by the root's install.
for d in */; do
  d=${d%/}
  case $d in node_modules | vendor | target | dist | build | out | .* | _*) continue ;; esac
  for m in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock uv.lock poetry.lock Pipfile.lock \
    requirements.txt Cargo.toml go.mod Gemfile pom.xml composer.json; do
    if [ -f "$d/$m" ]; then
      project "$d" "$d"
      break
    fi
  done
done

if [ "$DRY" = 0 ] && [ "$BEFORE" != "$(status)" ]; then
  note "git status changed during the installs (a lockfile or a generated file?): compare with git status and git diff"
fi

echo
if [ "$DRY" = 1 ]; then
  echo "instabox-move-repo deps (dry run): ${#OK[@]} step(s) planned"
  [ ${#OK[@]} -gt 0 ] && printf '  plan:   %s\n' "${OK[@]}"
else
  echo "instabox-move-repo deps: ${#OK[@]} step(s) ok, ${#FAILED[@]} failed"
  [ ${#OK[@]} -gt 0 ] && printf '  ok:     %s\n' "${OK[@]}"
fi
[ ${#FAILED[@]} -gt 0 ] && printf '  FAILED: %s\n' "${FAILED[@]}"
[ ${#NOTES[@]} -gt 0 ] && printf '  note:   %s\n' "${NOTES[@]}"
[ ${#OK[@]} -eq 0 ] && [ ${#FAILED[@]} -eq 0 ] && echo "  no lockfile or manifest found: nothing installed"
[ ${#FAILED[@]} -eq 0 ]
