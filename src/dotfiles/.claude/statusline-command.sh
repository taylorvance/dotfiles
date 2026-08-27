#!/bin/bash
# Claude Code statusline:
#   ~/dev/nxt-reels · main* +28 -15 · Fable 5 (high) · 5h 4% (2.1h) · 7d 61% (2.9d)
# Reads the session status JSON on stdin (requires jq).
# Usage segments: 5h comes from rate_limits.five_hour on stdin. Weekly prefers
# rate_limits.seven_day, but on plans with a model-scoped weekly limit (e.g.
# Fable) that field is absent — fall back to the /usage cache Claude Code keeps
# in ~/.claude.json (cachedUsageUtilization.utilization.limits, group "weekly").
# Usage pct color is absolute (pct_color); the (time left) color is the pace
# signal: will usage last until reset (see pace_calc). A colored timer also
# shows the burn ratio, e.g. "(4.9d 1.6x)".
# Docs: https://code.claude.com/docs/en/statusline

input=$(cat)

# one field per line — a tab-separated read would collapse empty fields
{
  IFS= read -r dir
  IFS= read -r model
  IFS= read -r effort
  IFS= read -r five_hour
  IFS= read -r five_hour_left
  IFS= read -r seven_day
  IFS= read -r seven_day_left
  IFS= read -r ctx_pct
} < <(jq -r '
  (.workspace.current_dir // .cwd // ""),
  (.model.display_name // ""),
  (.effort.level // ""),
  ((.rate_limits.five_hour.used_percentage // "") | if type == "number" then round | tostring else . end),
  ((.rate_limits.five_hour.resets_at // "") | if type == "number" then (. - now | floor | tostring) else . end),
  ((.rate_limits.seven_day.used_percentage // "") | if type == "number" then round | tostring else . end),
  ((.rate_limits.seven_day.resets_at // "") | if type == "number" then (. - now | floor | tostring) else . end),
  ((.context_window.used_percentage // "") | if type == "number" then round | tostring else . end)
' <<<"$input" 2>/dev/null)

if [ -z "$seven_day" ] && [ -f ~/.claude.json ]; then
  {
    IFS= read -r seven_day
    IFS= read -r seven_day_left
  } < <(jq -r '
    [.cachedUsageUtilization.utilization.limits[]? | select(.group == "weekly")]
    | max_by(.percent // 0)
    | if . == null then "", "" else
        ((.percent // "") | if type == "number" then round | tostring else . end),
        ((.resets_at // "") | if . == "" then "" else
          (try (sub("\\.[0-9]+"; "") | sub("\\+00:00"; "Z") | fromdateiso8601 - now | floor | tostring) catch "")
        end)
      end
  ' ~/.claude.json 2>/dev/null)
fi

[ -n "$dir" ] || dir=$(pwd)

# fish-style path squeeze: middle components collapse to one letter (two for
# dot-dirs), the last two stay full so worktree paths keep the repo name —
# except a kept component with a jira-key prefix drops its -description tail
squeeze_path() {
  local IFS=/ out="" comp i
  local -a parts
  read -ra parts <<< "$1"
  local n=${#parts[@]}
  for ((i = 0; i < n; i++)); do
    comp=${parts[i]}
    if ((i >= n - 2)) || [ -z "$comp" ] || [ "$comp" = "~" ]; then
      [[ $comp =~ ^([A-Za-z][A-Za-z0-9]*-[0-9]+)- ]] && comp="${BASH_REMATCH[1]}…"
      out+=$comp
    elif [ "${comp:0:1}" = "." ]; then
      out+=${comp:0:2}
    else
      out+=${comp:0:1}
    fi
    ((i < n - 1)) && out+=/
  done
  printf '%s' "$out"
}

# tv/RLS-752-long-description -> tv/RLS-752… (case-insensitive key match, no
# marker when the key is already the whole name); otherwise cap at 25 chars with …
squeeze_branch() {
  if [[ $1 =~ ^(.*/)?([A-Za-z][A-Za-z0-9]*-[0-9]+) ]]; then
    local kept="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    if [ "$kept" = "$1" ]; then printf '%s' "$kept"; else printf '%s…' "$kept"; fi
  elif [ ${#1} -gt 25 ]; then
    printf '%s…' "${1:0:24}"
  else
    printf '%s' "$1"
  fi
}

# git branch + dirty marker + changed-line counts, from the session's directory
branch="" added=0 removed=0 ahead=0 behind=0
if [ -d "$dir" ]; then
  branch=$(cd "$dir" && { git symbolic-ref --short -q HEAD || git rev-parse --short HEAD; } 2>/dev/null)
  if [ -n "$branch" ]; then
    branch=$(squeeze_branch "$branch")
    if [ -n "$(cd "$dir" && git status --porcelain 2>/dev/null | head -1)" ]; then
      branch="${branch}*"
    fi
    # staged + unstaged lines vs HEAD; numstat shows "-" for binary files
    read -r added removed < <(cd "$dir" && git diff HEAD --numstat 2>/dev/null |
      awk '{ if ($1 != "-") a += $1; if ($2 != "-") r += $2 } END { printf "%d %d\n", a, r }')
    # commits behind/ahead of the tracked upstream (empty when no upstream)
    read -r behind ahead < <(cd "$dir" && git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  fi
fi

# abbreviate $HOME as ~ (like \w in PS1), then squeeze middle components
case "$dir" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~${dir#"$HOME"}" ;;
esac
dir=$(squeeze_path "$dir")

BLUE='\033[01;34m'
GREEN='\033[01;32m'
ADD_GREEN='\033[32m'
DEL_RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
MAGENTA='\033[35m'
DIM='\033[02;37m'
RESET='\033[00m'
SEP="${DIM} · ${RESET}"

# pace for the (time left) part: dim means nothing needs attention, and a
# colored timer is always information, carrying the used%/elapsed% burn
# ratio so the math is on screen. Yellow when burning >1.2x the window's
# pace (the slack absorbs work-hours burstiness), red beyond 1.6x; green
# (on pace, <=1.2x) shows only against a yellow/red pct as reassurance, and
# stays dim next to a green pct. Dim below 25% used (pace not meaningful
# yet). Sets pace_hue, and pace_ratio (used%/elapsed% in tenths for integer
# math; empty when the timer is dim).
pace_calc() {
  local used=$1 left=$2 window=$3 elapsed ratio
  pace_hue=$DIM pace_ratio=""
  if [ "$used" -ge 25 ] 2>/dev/null && [ "$left" -gt 0 ] 2>/dev/null; then
    elapsed=$((window - left))
    if [ "$elapsed" -gt 0 ]; then
      ratio=$((used * window / (elapsed * 10)))
      if [ "$ratio" -gt 16 ]; then pace_hue=$DEL_RED pace_ratio=$ratio
      elif [ "$ratio" -gt 12 ]; then pace_hue=$YELLOW pace_ratio=$ratio
      elif [ "$used" -ge 50 ]; then pace_hue=$ADD_GREEN pace_ratio=$ratio
      fi
    fi
  fi
}

# green under 50%, yellow under 80%, red at 80%+
pct_color() {
  if [ "$1" -ge 80 ] 2>/dev/null; then printf '\033[01;31m'
  elif [ "$1" -ge 50 ] 2>/dev/null; then printf '\033[01;33m'
  else printf '\033[32m'
  fi
}

# seconds until reset -> "2.9d" / "2.2h" / "43m" (empty if unknown/past)
# tenths are floored so the display never overstates the time left
fmt_left() {
  [ "$1" -gt 0 ] 2>/dev/null || return 0
  local t
  if [ "$1" -ge 86400 ]; then
    t=$(($1 * 10 / 86400))
    if [ $((t % 10)) -eq 0 ]; then printf '%dd' $((t / 10)); else printf '%d.%dd' $((t / 10)) $((t % 10)); fi
  elif [ "$1" -ge 3600 ]; then
    t=$(($1 * 10 / 3600))
    if [ $((t % 10)) -eq 0 ]; then printf '%dh' $((t / 10)); else printf '%d.%dh' $((t / 10)) $((t % 10)); fi
  else
    printf '%dm' $(($1 / 60))
  fi
}

# usage segment: label, percent, seconds-left, window-seconds
# -> e.g. "5h 4% (2h10m)", "7d 45% (4.9d 1.6x)"; pct colored by absolute
# use, time left by pace (with the burn ratio whenever it's colored)
usage_segment() {
  printf '%b%b%s %s%%%b' "$SEP" "$(pct_color "$2")" "$1" "$2" "$RESET"
  local left
  left=$(fmt_left "$3")
  [ -n "$left" ] || return 0
  pace_calc "$2" "$3" "$4"
  if [ -n "$pace_ratio" ]; then
    printf ' %b(%s %d.%dx)%b' "$pace_hue" "$left" $((pace_ratio / 10)) $((pace_ratio % 10)) "$RESET"
  else
    printf ' %b(%s)%b' "$pace_hue" "$left" "$RESET"
  fi
}

printf '%b%s%b' "$BLUE" "$dir" "$RESET"

if [ -n "$branch" ]; then
  printf '%b%b%s%b' "$SEP" "$GREEN" "$branch" "$RESET"
  [ "${added:-0}" -gt 0 ]   && printf ' %b+%s%b' "$ADD_GREEN" "$added" "$RESET"
  [ "${removed:-0}" -gt 0 ] && printf ' %b-%s%b' "$DEL_RED" "$removed" "$RESET"
  [ "${ahead:-0}" -gt 0 ]  2>/dev/null && printf ' %b↑%s%b' "$CYAN" "$ahead" "$RESET"
  [ "${behind:-0}" -gt 0 ] 2>/dev/null && printf ' %b↓%s%b' "$YELLOW" "$behind" "$RESET"
fi

# model (effort) — dim parens, e.g. "Fable 5 (high)"
if [ -n "$model" ]; then
  printf '%b%b%s%b' "$SEP" "$CYAN" "$model" "$RESET"
  [ -n "$effort" ] && printf ' %b(%b%s%b%b)%b' "$DIM" "$MAGENTA" "$effort" "$RESET" "$DIM" "$RESET"
elif [ -n "$effort" ]; then
  printf '%b%b%s%b' "$SEP" "$MAGENTA" "$effort" "$RESET"
fi

[ -n "$five_hour" ] && usage_segment "5h" "$five_hour" "$five_hour_left" 18000
[ -n "$seven_day" ] && usage_segment "7d" "$seven_day" "$seven_day_left" 604800

# context usage: hidden until 60%, then a yellow/red auto-compact heads-up
if [ -n "$ctx_pct" ] && [ "$ctx_pct" -ge 60 ] 2>/dev/null; then
  printf '%b%bctx %s%%%b' "$SEP" "$(pct_color "$ctx_pct")" "$ctx_pct" "$RESET"
fi

exit 0
