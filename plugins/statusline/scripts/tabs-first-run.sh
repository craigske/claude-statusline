#!/bin/sh
# SessionStart hook: until iTerm2 tab alerts are configured, ask Claude to offer setup.
# Silent outside iTerm2, in non-interactive sessions, and once ~/.claude/statusline/tabs.conf exists (the
# /statusline:tabs skill writes it, even when the user just keeps the defaults).

[ -n "$ITERM_SESSION_ID" ] || exit 0
# Interactive sessions only: `claude -p` and SDK runs inherit ITERM_SESSION_ID too, and
# can't answer the setup questions.
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in cli) ;; *) exit 0 ;; esac
[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline/tabs.conf" ] && exit 0

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"The statusline plugin's iTerm2 tab alerts (tab colors, status dot, Dock bounce and banner, spoken phrases) are running on their defaults and haven't been set up yet. At the start of your first reply, before other work, invoke the statusline:tabs skill to ask the user their preferences. Keep it brief. If they decline, the skill saves the defaults so this isn't asked again."}}
EOF
