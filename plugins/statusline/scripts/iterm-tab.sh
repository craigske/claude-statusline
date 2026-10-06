#!/bin/sh
# Claude Code -> iTerm2 tab color, status dot, and attention alerts (a plugin hook).
#
#   working  green   tab color
#   waiting  orange  tab color + Dock bounce, banner "Claude needs input - <project>", spoken phrase
#   idle     blue ("unread") if the tab isn't focused, else cleared
#                    + Dock bounce, banner "Claude finished - <project>", spoken phrase
#
# The status dot is drawn by iTerm2's own cc-status helper (ships inside iTerm.app); this
# script forwards each event to it when it's there.
#
# Settings come from the environment, then ~/.claude/statusline/tabs.conf (KEY=value lines),
# then the defaults below. /statusline:tabs writes tabs.conf.
#   STATUSLINE_TAB_COLORS   1/0  color the tab                     (default 1)
#   STATUSLINE_TAB_DOT      1/0  iTerm2 status dot via cc-status   (default 1)
#   STATUSLINE_TAB_ALERTS   1/0  Dock bounce + notification banner (default 1)
#   STATUSLINE_TAB_VOICE         macOS `say` voice; empty = silent  (default Amélie)
#   STATUSLINE_TAB_SAY_WAITING   phrase when Claude needs input     (default "J'ai besoin de vous")
#   STATUSLINE_TAB_SAY_DONE      phrase when Claude finishes        (default "Terminé")
#   STATUSLINE_TAB_WORKING / _WAITING / _UNREAD   tab colors (#00d75f / #ff9500 / #0a84ff)
#
# Does nothing outside iTerm2. No jq or iTerm2 Python runtime needed.

[ -n "$ITERM_SESSION_ID" ] || exit 0
# Interactive sessions only: a `claude -p` started from inside a session inherits
# ITERM_SESSION_ID and would otherwise repaint (and on SessionEnd, reset) the parent's tab.
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in cli) ;; *) exit 0 ;; esac
sid=${ITERM_SESSION_ID#*:}

input=$(cat)

state_dir="${TMPDIR:-/tmp}"
state_dir="${state_dir%/}/claude-statusline-$(id -u)"
mkdir -p "$state_dir" 2>/dev/null

conf="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline/tabs.conf"

# setting NAME DEFAULT -> env var if set (even empty), else tabs.conf, else DEFAULT
setting() {
  if printenv "$1" >/dev/null 2>&1; then
    printenv "$1"
  elif [ -f "$conf" ] && grep -q "^[[:space:]]*$1=" "$conf"; then
    sed -n "s/^[[:space:]]*$1=//p" "$conf" | tail -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
  else
    printf '%s' "$2"
  fi
}

want_colors=$(setting STATUSLINE_TAB_COLORS 1)
want_dot=$(setting STATUSLINE_TAB_DOT 1)
want_alerts=$(setting STATUSLINE_TAB_ALERTS 1)
voice=$(setting STATUSLINE_TAB_VOICE "Amélie")
say_waiting=$(setting STATUSLINE_TAB_SAY_WAITING "J'ai besoin de vous")
say_done=$(setting STATUSLINE_TAB_SAY_DONE "Terminé")
color_working=$(setting STATUSLINE_TAB_WORKING "#00d75f")
color_waiting=$(setting STATUSLINE_TAB_WAITING "#ff9500")
color_unread=$(setting STATUSLINE_TAB_UNREAD "#0a84ff")

# take_lock NAME: wait until this process holds $state_dir/NAME.lock. Background jobs use it
# to run one at a time per session. Call it in a subshell; the lock is released on exit.
take_lock() {
  lock="$state_dir/$1.lock"
  tries=0
  until mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    # A lock held this long is stale (a killed job); take it over.
    [ "$tries" -ge 100 ] && { rmdir "$lock" 2>/dev/null; tries=0; }
    sleep 0.05
  done
  trap 'rmdir "$lock" 2>/dev/null' EXIT
}

# --- status dot: hand the event to iTerm2's cc-status, if installed ---
if [ "$want_dot" = 1 ]; then
  for cc_status in /Applications/iTerm.app/Contents/Resources/utilities/cc-status "$HOME/.config/iterm2/cc-status"; do
    if [ -x "$cc_status" ]; then
      # Detached, since cc-status takes ~0.3s and PreToolUse/PostToolUse hooks block the
      # tool. Detached jobs can overlap, so run them one at a time per session and drop any
      # that a newer event has superseded: the newest event always runs last.
      cc_seq="$state_dir/cc-$sid.seq"
      cc_token="$$.$(date +%s)"
      printf '%s' "$cc_token" > "$cc_seq"
      (
        take_lock "cc-$sid"
        [ "$(cat "$cc_seq" 2>/dev/null)" = "$cc_token" ] || exit 0
        printf '%s' "$input" | "$cc_status"
      ) </dev/null >/dev/null 2>&1 &
      break
    fi
  done
fi

[ "$want_colors" = 1 ] || [ "$want_alerts" = 1 ] || [ -n "$voice" ] || exit 0

# First match wins: the top-level keys come before tool_input / tool_response, which can
# hold the same key names.
field() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 \
    | sed -e "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//" -e 's/"$//'
}

event=$(field hook_event_name)
tool=$(field tool_name)
ntype=$(field notification_type)
cwd=$(field cwd)

case "$event" in
  Notification)
    case "$ntype" in
      permission_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input|'') state=waiting ;;
      *) exit 0 ;;
    esac ;;
  PermissionRequest) state=waiting ;;
  PreToolUse)
    if [ "$tool" = "AskUserQuestion" ]; then state=waiting; else state=working; fi ;;
  SubagentStop) exit 0 ;;
  Stop|StopFailure) state=idle ;;
  SessionStart|SessionEnd) state=reset ;;
  *) state=working ;;
esac

IT2=/Applications/iTerm.app/Contents/Resources/utilities/it2
[ -x "$IT2" ] || IT2=$(command -v it2) || exit 0

state_file="$state_dir/tab-$sid"
[ "$(cat "$state_file" 2>/dev/null)" = "$state" ] && exit 0
printf '%s' "$state" > "$state_file"

project=${cwd##*/}
[ -n "$project" ] || project=claude

# Everything below talks to iTerm2; run it detached so the hook returns at once. Jobs run
# one at a time per session, and each one stops once a newer event has replaced its state,
# so the newest state is always applied last.
(
  take_lock "tab-$sid"

  it2() { "$IT2" "$@" </dev/null; }

  current() { [ "$(cat "$state_file" 2>/dev/null)" = "$state" ]; }
  current || exit 0
  speak=""

  set_alert_var() { current && it2 session set-var user.claude_alert "$1" --session "$sid"; }

  session_tty() {
    it2 session get-var tty --session "$sid" 2>/dev/null | tr -d '"\\'
  }

  set_color() {
    [ "$want_colors" = 1 ] && current && it2 session set-color "$1" --session "$sid"
  }

  # OSC 6 reset: there is no it2 command to clear a tab color.
  clear_color() {
    [ "$want_colors" = 1 ] || return 0
    current || return 0
    tty=$(session_tty)
    [ -w "$tty" ] && printf '\033]6;1;bg;*;default\007' > "$tty"
  }

  # $1 = banner text, $2 = spoken phrase
  alert() {
    if [ "$want_alerts" = 1 ] && current; then
      tty=$(session_tty)
      [ -w "$tty" ] && printf '\033]1337;RequestAttention=1\007\033]9;%s\007' "$1" > "$tty"
    fi
    speak="$2"
  }

  # Focused = iTerm2 has a key window and this is its current session.
  focused() {
    focus=$(it2 app get-focus 2>/dev/null)
    case "$focus" in *"No current window"*) return 1 ;; esac
    printf '%s' "$focus" | grep -q "Current session: $sid"
  }

  case "$state" in
    working)
      set_color "$color_working"
      set_alert_var ''
      ;;
    waiting)
      set_color "$color_waiting"
      set_alert_var 1
      alert "Claude needs input - $project" "$say_waiting"
      ;;
    idle)
      focused; is_focused=$?
      # The focus lookup is slow; drop this job if a newer event has landed.
      current || exit 0
      if [ "$is_focused" -eq 0 ]; then
        clear_color
        set_alert_var ''
      else
        set_color "$color_unread"
        set_alert_var 1
      fi
      alert "Claude finished - $project" "$say_done"
      ;;
    reset)
      clear_color
      set_alert_var ''
      [ "$event" = "SessionEnd" ] && rm -f "$state_file"
      ;;
  esac

  # Speaking takes seconds, so release the lock first, and stay quiet if the state has
  # already moved on (a permission prompt answered right away, say).
  rmdir "$lock" 2>/dev/null; trap - EXIT
  [ -n "$speak" ] && [ -n "$voice" ] && current && command -v say >/dev/null && say -v "$voice" "$speak"
) </dev/null >/dev/null 2>&1 &

exit 0
