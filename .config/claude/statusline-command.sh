#!/bin/bash
# Claude Code status line: model, current dir name, git branch with clean/dirty emoji, context usage.
# Bullet-train style powerline segments. Still feeds the status JSON to Ghostex but hides its output.

input=$(cat)

# Single jq call, tab separated. Empty fields become "-" because tab is IFS whitespace and would collapse.
IFS=$'\t' read -r model cwd used < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    ((.context_window.used_percentage // "") | tostring)
  ] | map(if . == "" then "-" else . end) | @tsv'
)
[ "$cwd" = "-" ] && cwd=$PWD
[ "$used" = "-" ] && used=""

SEP=$''
RESET=$'\e[0m'
out=""
prev_bg=""

# segment <bg 256-color> <fg 256-color> <text>
segment() {
  local bg=$1 fg=$2 text=$3
  if [ -n "$prev_bg" ]; then
    out+=$'\e[38;5;'"${prev_bg}"$'m\e[48;5;'"${bg}"$'m'"${SEP}"
  fi
  out+=$'\e[48;5;'"${bg}"$'m\e[38;5;'"${fg}"$'m '"${text}"' '
  prev_bg=$bg
}

segment 61 255 "$model"
segment 31 255 "${cwd##*/}"

if [ -d "$cwd" ]; then
  status=$(cd "$cwd" 2>/dev/null && git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
  if [ -n "$status" ]; then
    branch="" ahead=0 behind=0 staged=0 unstaged=0 untracked=0 conflicts=0
    while IFS= read -r line; do
      case $line in
        '# branch.head '*) branch=${line#'# branch.head '} ;;
        '# branch.oid '*) oid=${line#'# branch.oid '} ;;
        '# branch.ab '*)
          read -r _ _ a b <<<"$line"
          ahead=${a#+}
          behind=${b#-}
          ;;
        '1 '* | '2 '*)
          xy=${line:2:2}
          [ "${xy:0:1}" != "." ] && staged=$((staged + 1))
          [ "${xy:1:1}" != "." ] && unstaged=$((unstaged + 1))
          ;;
        'u '*) conflicts=$((conflicts + 1)) ;;
        '? '*) untracked=$((untracked + 1)) ;;
      esac
    done <<<"$status"

    [ "$branch" = "(detached)" ] && branch="${oid:0:7}"

    if [ $((staged + unstaged + untracked + conflicts)) -eq 0 ]; then
      segment 34 255 $''" $branch ✅"
    else
      segment 178 16 $''" $branch ❌"
    fi
  fi
fi

if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  if [ "$pct" -ge 80 ]; then bg=160
  elif [ "$pct" -ge 50 ]; then bg=178
  else bg=240
  fi
  fg=255
  [ "$bg" = 178 ] && fg=16
  segment "$bg" "$fg" "ctx ${pct}%"
fi

# Close the last segment.
[ -n "$prev_bg" ] && out+=$'\e[0m\e[38;5;'"${prev_bg}"$'m'"${SEP}${RESET}"

printf '%s' "$out"

printf '%s' "$input" | "$HOME/.local/share/ghostex/hooks/agent-statusline.sh" >/dev/null 2>&1
printf '\n'
