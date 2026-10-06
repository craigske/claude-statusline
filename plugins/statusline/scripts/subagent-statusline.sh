#!/usr/bin/env bash
# Claude Code subagent status line (settings key: subagentStatusLine).
# Input: one JSON object with a `tasks` array (id, name, type, status, model,
#   contextWindowSize, tokenCount, ...) and `columns`.
# Output: one JSON line per row, {"id": "<task id>", "content": "<row body>"}.
# Row body: <icon> <name> · <model> · [📡] · <4-cell context bar> <pct>%
# Requires: jq.
# Docs: https://code.claude.com/docs/en/statusline#subagent-status-lines

jq -c '
  def esc(c): "\u001b[" + c + "m";
  def reset: esc("0");

  # Emoji by agent name/type (case-insensitive substring match)
  def icon:
    ascii_downcase as $n
    | [ ["explore","🔭"], ["plan","📋"], ["code","🛠"], ["test","🧪"],
        ["review","🔍"], ["debug","🐛"], ["docs","📝"], ["search","🔎"],
        ["build","🏗"], ["deploy","🚀"], ["db","🗄"], ["data","🗄"],
        ["statusline","📊"], ["architect","🧭"], ["analyst","📈"],
        ["migrate","🔄"], ["lint","✨"], ["fmt","✨"], ["format","✨"] ]
    | (map(select(.[0] as $k | $n | contains($k))) | first | .[1]) // "🤖";

  # claude-sonnet-5-20260101 -> sonnet-5
  def short_model:
    sub("^claude-"; "") | sub("-[0-9]{8}$"; "") | sub("\\[.*\\]$"; "");

  def grade(p): if p >= 80 then esc("31") elif p >= 50 then esc("33") else esc("32") end;

  def bar(p):
    ((p * 4 + 50) / 100 | floor | if . > 4 then 4 elif . < 0 then 0 else . end) as $f
    # not `"█" * n`: jq returns null for n = 0
    | ([range($f)] | map("█") | join("")) + ([range(4 - $f)] | map("░") | join(""));

  # Remote control (session driven from claude.ai / FleetView). Same probe as statusline.sh;
  # narrow both once the real field is known.
  (.remote_control // .is_remote // .driven_by_remote //
   .session.remote // .session.driven_remotely //
   .source == "remote" // .channel == "remote" // null
   | . == true or . == "true" or . == "remote") as $remote

  | .tasks[]?
  | ((.name // .label // .type // "subagent") | tostring) as $name
  | ([ esc("1") + ($name | icon) + " " + $name + reset ]
     + (if .model then [ esc("2") + (.model | short_model) + reset ] else [] end)
     + (if $remote then [ esc("35") + "📡" + reset ] else [] end)
     + (if (.tokenCount != null and (.contextWindowSize // 0) > 0)
        then ((.tokenCount * 100 / .contextWindowSize) | round) as $p
             | [ grade($p) + bar($p) + " " + ($p | tostring) + "%" + reset ]
        else [] end)
    ) as $parts
  | { id, content: ($parts | join(" ")) }
'
