---
name: install
description: Install, update, or uninstall this plugin's Claude Code status line and subagent status line. Use when the user runs /statusline:install, asks to set up / turn on / update / remove the status line from this plugin, or after a plugin update to refresh the installed scripts.
---

# Install the status line

Plugins can't set `statusLine` themselves, so this skill copies the plugin's scripts to a fixed location (`~/.claude/statusline/`) and points the user's `~/.claude/settings.json` at them. The fixed copy keeps working when the plugin updates and its install directory changes.

1. Tell the user what will happen: the scripts are copied to `~/.claude/statusline/`, and `statusLine` and `subagentStatusLine` in `~/.claude/settings.json` are set to them. Any existing values are saved to `~/.claude/statusline/previous-settings.json` first. If they already have a status line, ask whether to replace both, only the main one (`--main`), or only the subagent one (`--subagent`).
2. Run the installer with the flag they chose:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"
   ```

3. Report the installer's output. The status line appears on the next render.
4. Mention the optional settings, which go in the `env` block of `~/.claude/settings.json`:
   - `STATUSLINE_ISSUE_PREFIXES`: comma-separated issue key prefixes to pick out of branch names, for example `"ENG,OPS"`. When it's unset, any `KEY-123` shape matches.
   - `STATUSLINE_PR_TTL`: how many seconds to cache the `gh pr view` lookup (default `300`). `0` hides the PR segment.
   - `STATUSLINE_DEBUG_FILE`: a path to write each render's raw input JSON to. Only for finding field names. Leave it unset otherwise.
   - To pin an issue for a branch with no key in its name: `echo ENG-123 > "$(git rev-parse --git-dir)/statusline-issue"`

To **uninstall**, run the installer with `--uninstall`. It removes only the settings that point at `~/.claude/statusline/`. Tell the user where their previous settings were saved, if any.
