---
name: tabs
description: Set up or change this plugin's iTerm2 tab alerts — tab colors, the iTerm2 status dot, Dock bounce and banner, and spoken phrases. Use when the user runs /statusline:tabs, asks to change, mute, or turn off the tab colors, alerts, or voice, or when a SessionStart note says the tab alerts haven't been set up yet.
---

# Set up iTerm2 tab alerts

The plugin's hooks (`scripts/iterm-tab.sh`) color the iTerm2 tab by Claude's state and alert the user when Claude needs input or finishes. They read their settings from `~/.claude/statusline/tabs.conf` (or `$CLAUDE_CONFIG_DIR/statusline/tabs.conf`). Environment variables with the same names override the file. Outside iTerm2 the hooks do nothing.

1. Read `tabs.conf` if it exists, so you can show the current values as the first option.
2. Ask with AskUserQuestion, in a single call. Put the defaults first and mark them "(Recommended)" on a first run:
   - **Features** (multiSelect): tab colors (green = working, orange = needs input, blue = finished in a background tab), status dot (iTerm2's own `cc-status` helper, which ships inside recent iTerm.app builds), Dock bounce + notification banner, spoken phrases. All are on by default.
   - **Voice**, only if spoken phrases are kept: French, `Amélie` saying "J'ai besoin de vous" / "Terminé" (default); English, `Samantha` saying "Claude needs you" / "Claude is done"; or Other (any voice from `say -v '?'` plus their own two phrases).
   - **Colors**: keep `#00d75f` / `#ff9500` / `#0a84ff` (default), or Other with their own hex colors for working / waiting / unread. The status dot uses iTerm2's fixed palette whatever they choose.

   If the user dismisses the questions or says to skip, keep every default.
3. Write `tabs.conf` with the Write tool, one `KEY=value` per line and no quotes. Always write the file, even when nothing changed from the defaults, because its existence is what stops the first-run prompt:

   ```
   # iTerm2 tab alerts for the statusline plugin. Edit, or run /statusline:tabs.
   STATUSLINE_TAB_COLORS=1
   STATUSLINE_TAB_DOT=1
   STATUSLINE_TAB_ALERTS=1
   STATUSLINE_TAB_VOICE=Amélie
   STATUSLINE_TAB_SAY_WAITING=J'ai besoin de vous
   STATUSLINE_TAB_SAY_DONE=Terminé
   STATUSLINE_TAB_WORKING=#00d75f
   STATUSLINE_TAB_WAITING=#ff9500
   STATUSLINE_TAB_UNREAD=#0a84ff
   ```

   A feature that's off is `0`. No spoken phrases is an empty `STATUSLINE_TAB_VOICE=`.
4. Confirm in one line. Changes take effect on the next hook event, with no restart. If they turned spoken phrases on with a voice other than the default, run `say -v '<voice>' '<waiting phrase>'` once so they can hear it. If the voice isn't installed, `say` will fail; tell them to add it in System Settings → Accessibility → Spoken Content.
