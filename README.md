# claude-statusline

A dense, color-graded status line for [Claude Code](https://code.claude.com), plus a matching subagent status line.

```
🌿 eng-412-retry-uploads 🔀 PR #88 OPEN 📋 ENG-412 📁 api 🤖 Opus ⚡ high 📊 █████░░░ 62% ⏱️  5h 12% 📅 7d 30% ✏️  +42/-7 ⏰ 12m5s 💰 $1.23
```

| Segment | Shows |
| - | - |
| 🌿 branch | Current git branch. Hidden inside a worktree |
| 🌳 worktree | Worktree name ← the branch it was created from |
| 🔀 PR | GitHub PR for the branch, colored by state (needs `gh`; cached 5 min) |
| 📋 issue | Issue key from the branch name (`ENG-412`), or a pinned one |
| 📁 🤖 ⚡ 🚀 🧠 | Directory, model, effort level, fast mode, extended thinking |
| 📡 remote | Session is being driven remotely (claude.ai / FleetView). The input field isn't documented yet, so this probes likely names |
| 📊 | Context window use: green <50%, yellow <80%, red after that |
| ⏱️ 📅 | 5-hour and 7-day rate-limit use, same colors |
| ✏️ ⏰ 💰 | Lines changed, session time, and session cost (yellow at $1, red at $5) |

The subagent line renders each row in the agent panel as `🔭 Explore · haiku-4-5 · ██░░ 60%`, with a 📡 after the model when the session is remote.

## Install

Requires `bash`, `jq` and `git`. `gh` is optional and only needed for the PR segment.

**As a plugin** (recommended, updates through `/plugin`):

```
/plugin marketplace add craigske/claude-statusline
/plugin install statusline@claude-statusline
/statusline:install
```

Claude Code doesn't let a plugin set `statusLine` directly. So `/statusline:install` copies the scripts to `~/.claude/statusline/` and sets `statusLine` and `subagentStatusLine` in `~/.claude/settings.json`. Any values it replaces are saved to `~/.claude/statusline/previous-settings.json` first. Run it again after a plugin update to pick up the new scripts.

**Without the plugin:**

```bash
git clone https://github.com/craigske/claude-statusline
bash claude-statusline/plugins/statusline/scripts/install.sh   # --main | --subagent | --uninstall
```

## Configure

Set these in the `env` block of `~/.claude/settings.json`:

| Variable | Default | Effect |
| - | - | - |
| `STATUSLINE_ISSUE_PREFIXES` | *(any)* | Comma-separated issue prefixes to match in branch names, e.g. `ENG,OPS`. Unset matches any `KEY-123` shape, which can pick up a false positive like `release-2026` |
| `STATUSLINE_PR_TTL` | `300` | Seconds to cache the PR lookup. `0` turns the PR segment off |
| `STATUSLINE_DEBUG_FILE` | *(unset)* | Path to write each render's raw input JSON to, overwritten every time. Handy for finding field names. It contains session ids and paths, so keep it somewhere private |

**Pinning an issue.** If a branch has no key in its name, pin one for that worktree:

```bash
echo ENG-412 > "$(git rev-parse --git-dir)/statusline-issue"
```

The file lives inside `.git`, so it's never committed. Lookup order is branch name, then the worktree's original branch, then the pin.

## Uninstall

```bash
bash ~/.claude/statusline/install.sh --uninstall
```

This removes only the settings that point at `~/.claude/statusline/`. Restore anything you had before from `previous-settings.json`, which is in the same folder.

## License

MIT
