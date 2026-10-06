#!/usr/bin/env bash
# Claude Code status line.
# Reads the status-line JSON on stdin and prints one line of ANSI-colored segments:
#   🌿 branch | 🌳 worktree ← original | 🔀 PR | 📋 issue | 📁 dir | 🤖 model | ⚡ effort
#   🚀 fast | 🧠 thinking | 📊 context bar | ⏱️ 5h / 📅 7d limits | ✏️ lines | ⏰ time | 💰 cost
# Requires: jq, git. Optional: gh (for the PR segment).
#
# Environment (set in settings.json "env" or your shell):
#   STATUSLINE_ISSUE_PREFIXES  Comma-separated issue key prefixes to look for in branch
#                              names, e.g. "ENG,OPS". Empty = any KEY-123 shape.
#   STATUSLINE_PR_TTL          Seconds to cache the PR lookup (default 300). 0 disables it.

input=$(cat)
jqr() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

cache_root="${TMPDIR:-/tmp}"
cache_root="${cache_root%/}/claude-statusline-$(id -u)"

# --- git branch (from cwd in the JSON) ---
cwd=$(jqr '.workspace.current_dir // .cwd // empty')
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi
dir=$(basename "$cwd")

model=$(jqr '.model.display_name // empty')
used_pct=$(jqr '.context_window.used_percentage // empty')
cost_raw=$(jqr '.cost.total_cost_usd // empty')
duration_ms=$(jqr '.cost.total_duration_ms // empty')
lines_added=$(jqr '.cost.total_lines_added // 0')
lines_removed=$(jqr '.cost.total_lines_removed // 0')
wt_name=$(jqr '.worktree.name // empty')
wt_orig_branch=$(jqr '.worktree.original_branch // empty')
effort_level=$(jqr '.effort.level // empty')
fast_mode=$(jqr '.fast_mode // empty')
thinking_enabled=$(jqr '.thinking.enabled // empty')
rl_5h=$(jqr '.rate_limits.five_hour.used_percentage // empty')
rl_7d=$(jqr '.rate_limits.seven_day.used_percentage // empty')

# --- GitHub PR for current branch (cached; never hits gh on every render) ---
pr_number=""
pr_state=""
pr_ttl="${STATUSLINE_PR_TTL:-300}"
if [ "$pr_ttl" != "0" ] && [ -n "$cwd" ] && [ -n "$branch" ] && command -v gh >/dev/null 2>&1; then
  pr_repo_root=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$pr_repo_root" ]; then
    mkdir -p "$cache_root" 2>/dev/null
    pr_cache_key=$(printf '%s' "${pr_repo_root}|${branch}" | { md5sum 2>/dev/null || md5; } | cut -d' ' -f1)
    pr_cache_file="${cache_root}/pr-${pr_cache_key}.json"
    pr_cache_age=999999
    if [ -f "$pr_cache_file" ]; then
      # GNU stat first: on Linux `stat -f` means filesystem info, not a file's mtime.
      pr_cache_mtime=$(stat -c %Y "$pr_cache_file" 2>/dev/null || stat -f %m "$pr_cache_file" 2>/dev/null)
      [ -n "$pr_cache_mtime" ] && pr_cache_age=$(( $(date +%s) - pr_cache_mtime ))
    fi
    if [ "$pr_cache_age" -ge "$pr_ttl" ]; then
      pr_json=$(cd "$pr_repo_root" && gh pr view --json number,state 2>/dev/null)
      printf '%s' "$pr_json" > "$pr_cache_file" 2>/dev/null
    else
      pr_json=$(cat "$pr_cache_file" 2>/dev/null)
    fi
    pr_number=$(printf '%s' "$pr_json" | jq -r '.number // empty' 2>/dev/null)
    pr_state=$(printf '%s' "$pr_json" | jq -r '.state // empty' 2>/dev/null)
  fi
fi

# --- issue key: from branch, then worktree's original branch, then a pin file ---
# Pin with: echo ENG-123 > "$(git rev-parse --git-dir)/statusline-issue"  (per-worktree, never tracked)
issue_prefixes=$(printf '%s' "${STATUSLINE_ISSUE_PREFIXES:-}" | tr -d '[:space:]' | tr ',' '|')
if [ -n "$issue_prefixes" ]; then
  issue_re="(^|[/_-])(${issue_prefixes})-[0-9]+"
else
  issue_re="(^|[/_-])[A-Za-z][A-Za-z0-9]*-[0-9]+"
fi
issue_key() {
  printf '%s' "$1" | grep -ioE "$issue_re" | head -n 1 | sed -E 's/^[/_-]//' | tr '[:lower:]' '[:upper:]'
}
issue=$(issue_key "$branch")
[ -z "$issue" ] && issue=$(issue_key "$wt_orig_branch")
if [ -z "$issue" ] && [ -n "$cwd" ]; then
  issue_pin=$(git -C "$cwd" --no-optional-locks rev-parse --git-path statusline-issue 2>/dev/null)
  case "$issue_pin" in /*) ;; ?*) issue_pin="$cwd/$issue_pin" ;; esac
  [ -f "$issue_pin" ] && issue=$(head -n 1 "$issue_pin" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
fi

RESET="\033[0m"
parts=""

# Branch — cyan; suppressed in a worktree (the 🌳 segment shows the meaningful branch)
if [ -n "$branch" ] && [ -z "$wt_name" ]; then
  parts="${parts}$(printf "\033[36m🌿 %s${RESET}" "$branch") "
fi

# Worktree — green; name ← original branch
if [ -n "$wt_name" ]; then
  if [ -n "$wt_orig_branch" ]; then
    parts="${parts}$(printf "\033[32m🌳 %s ← %s${RESET}" "$wt_name" "$wt_orig_branch") "
  else
    parts="${parts}$(printf "\033[32m🌳 %s${RESET}" "$wt_name") "
  fi
fi

# PR — colored by state
if [ -n "$pr_number" ]; then
  case "$pr_state" in
    OPEN) pr_color="\033[32m" ;;
    MERGED) pr_color="\033[35m" ;;
    CLOSED) pr_color="\033[31m" ;;
    *) pr_color="\033[2m" ;;
  esac
  parts="${parts}$(printf "${pr_color}🔀 PR #%s %s${RESET}" "$pr_number" "$pr_state") "
fi

# Issue — violet
if [ -n "$issue" ]; then
  parts="${parts}$(printf "\033[38;5;99m📋 %s${RESET}" "$issue") "
fi

if [ -n "$dir" ] && [ "$dir" != "." ]; then
  parts="${parts}$(printf "\033[2m📁 %s${RESET}" "$dir") "
fi

if [ -n "$model" ]; then
  parts="${parts}$(printf "\033[2m🤖 %s${RESET}" "$model") "
fi

if [ -n "$effort_level" ]; then
  parts="${parts}$(printf "\033[2m⚡ %s${RESET}" "$effort_level") "
fi
if [ "$fast_mode" = "true" ]; then
  parts="${parts}$(printf "\033[36m🚀 fast${RESET}") "
fi
if [ "$thinking_enabled" = "true" ]; then
  parts="${parts}$(printf "\033[2m🧠${RESET}") "
fi

# green <50, yellow 50–79, red 80+
grade() {
  if [ "$1" -ge 80 ]; then printf "\033[31m"
  elif [ "$1" -ge 50 ]; then printf "\033[33m"
  else printf "\033[32m"; fi
}

# Context % — 8-cell bar + number
if [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  filled=$(( (pct_int * 8 + 50) / 100 ))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i + 1 )); done
  while [ "$i" -lt 8 ]; do bar="${bar}░"; i=$(( i + 1 )); done
  parts="${parts}$(printf "$(grade "$pct_int")📊 %s %d%%${RESET}" "$bar" "$pct_int") "
fi

# Rate limits — 5h and 7d windows
if [ -n "$rl_5h" ]; then
  rl_5h_int=$(printf "%.0f" "$rl_5h")
  parts="${parts}$(printf "$(grade "$rl_5h_int")⏱️  5h %d%%${RESET}" "$rl_5h_int") "
fi
if [ -n "$rl_7d" ]; then
  rl_7d_int=$(printf "%.0f" "$rl_7d")
  parts="${parts}$(printf "$(grade "$rl_7d_int")📅 7d %d%%${RESET}" "$rl_7d_int") "
fi

# Lines changed — hidden when both are zero
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
  parts="${parts}$(printf "\033[2m✏️  \033[32m+%d\033[2m/\033[31m-%d${RESET}" "$lines_added" "$lines_removed") "
fi

# Session duration — compact (45s, 1m23s, 2h5m)
if [ -n "$duration_ms" ]; then
  total_s=$(( ${duration_ms%.*} / 1000 ))
  if [ "$total_s" -lt 60 ]; then
    dur="${total_s}s"
  elif [ "$total_s" -lt 3600 ]; then
    dur="$(( total_s / 60 ))m$(( total_s % 60 ))s"
  else
    dur="$(( total_s / 3600 ))h$(( (total_s % 3600) / 60 ))m"
  fi
  parts="${parts}$(printf "\033[2m⏰ %s${RESET}" "$dur") "
fi

# Cost — dim <$1, yellow $1–$4.99, red $5+
if [ -n "$cost_raw" ]; then
  cost_dollars=$(printf "%.2f" "$cost_raw")
  cost_cents=$(awk -v c="$cost_raw" 'BEGIN { printf "%.0f", c * 100 }')
  if [ "$cost_cents" -ge 500 ]; then
    cost_color="\033[31m"
  elif [ "$cost_cents" -ge 100 ]; then
    cost_color="\033[33m"
  else
    cost_color="\033[2m"
  fi
  parts="${parts}$(printf "${cost_color}💰 \$%s${RESET}" "$cost_dollars")"
fi

printf "%b" "$parts"
