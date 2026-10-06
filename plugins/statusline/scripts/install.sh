#!/usr/bin/env bash
# Install the status line scripts into ~/.claude/statusline/ and point
# ~/.claude/settings.json at them. Safe to re-run: it refreshes the scripts.
#
#   install.sh             install both status lines
#   install.sh --main      main status line only
#   install.sh --subagent  subagent status line only
#   install.sh --uninstall remove the settings keys this installer wrote
#
# Any statusLine / subagentStatusLine it replaces is saved to
# ~/.claude/statusline/previous-settings.json first.
set -euo pipefail

src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dest_dir="$claude_dir/statusline"
settings="$claude_dir/settings.json"

want_main=1
want_sub=1
uninstall=0
case "${1:-}" in
  --main) want_sub=0 ;;
  --subagent) want_main=0 ;;
  --uninstall) uninstall=1 ;;
  "") ;;
  *) echo "usage: $0 [--main|--subagent|--uninstall]" >&2; exit 2 ;;
esac

for dep in jq git; do
  command -v "$dep" >/dev/null 2>&1 || { echo "error: $dep is required" >&2; exit 1; }
done
command -v gh >/dev/null 2>&1 || echo "note: gh not found; the PR segment will stay hidden"

mkdir -p "$dest_dir"
[ -f "$settings" ] || echo '{}' > "$settings"
jq -e 'type == "object"' "$settings" >/dev/null || { echo "error: $settings is not a JSON object" >&2; exit 1; }

main_cmd="bash \"$dest_dir/statusline.sh\""
sub_cmd="bash \"$dest_dir/subagent-statusline.sh\""

write_settings() {
  local tmp
  tmp=$(mktemp "$settings.XXXXXX")
  jq "$@" "$settings" > "$tmp" && mv "$tmp" "$settings"
}

if [ "$uninstall" = 1 ]; then
  write_settings --arg m "$main_cmd" --arg s "$sub_cmd" '
    (if .statusLine.command == $m then del(.statusLine) else . end)
    | (if .subagentStatusLine.command == $s then del(.subagentStatusLine) else . end)'
  echo "Removed status line settings pointing at $dest_dir."
  [ -f "$dest_dir/previous-settings.json" ] && echo "Your earlier settings are in $dest_dir/previous-settings.json."
  exit 0
fi

# Back up whatever we are about to replace (only if it isn't already ours).
jq --arg m "$main_cmd" --arg s "$sub_cmd" --argjson wm "$want_main" --argjson ws "$want_sub" '
  { statusLine: (if $wm == 0 or .statusLine.command == $m then null else .statusLine end),
    subagentStatusLine: (if $ws == 0 or .subagentStatusLine.command == $s then null else .subagentStatusLine end) }
  | with_entries(select(.value != null))' "$settings" > "$dest_dir/.prev.json"
if [ "$(jq 'length' "$dest_dir/.prev.json")" -gt 0 ]; then
  mv "$dest_dir/.prev.json" "$dest_dir/previous-settings.json"
  echo "Saved your previous status line settings to $dest_dir/previous-settings.json"
else
  rm -f "$dest_dir/.prev.json"
fi

# Keep a copy of the installer next to the scripts so uninstall needs no clone.
if [ "$src_dir" != "$dest_dir" ]; then
  install -m 0755 "$src_dir/install.sh" "$dest_dir/install.sh"
fi

if [ "$want_main" = 1 ]; then
  install -m 0755 "$src_dir/statusline.sh" "$dest_dir/statusline.sh"
  write_settings --arg c "$main_cmd" '.statusLine = {type: "command", command: $c}'
  echo "Installed statusLine        -> $dest_dir/statusline.sh"
fi
if [ "$want_sub" = 1 ]; then
  install -m 0755 "$src_dir/subagent-statusline.sh" "$dest_dir/subagent-statusline.sh"
  write_settings --arg c "$sub_cmd" '.subagentStatusLine = {type: "command", command: $c}'
  echo "Installed subagentStatusLine -> $dest_dir/subagent-statusline.sh"
fi
echo "Done. The status line refreshes on the next message."
