# claude-statusline

A dense, color-graded status line for [Claude Code](https://code.claude.com), plus a matching subagent status line and iTerm2 tab alerts.

```
🌿 eng-412-retry-uploads 🔀 PR #88 OPEN 📋 ENG-412 📁 api 🤖 Opus ⚡ high 📊 █████░░░ 62% ⏱️  5h 12% 📅 7d 30% ✏️  +42/-7 ⏰ 12m5s 💰 $1.23
```

| Segment | Shows |
| - | - |
| 🌿 branch | Current git branch. Hidden inside a worktree |
| 🌳 worktree | Worktree name ← the branch it was created from |
| 🔀 PR | GitHub PR for the branch, colored by state (needs `gh`; cached 5 min) |
| 🐙 gh account | The active `gh` account for the repo's host, read from `gh`'s `hosts.yml`. Shown only when you're logged in to two or more accounts there, since that's when pushing as the wrong one can happen |
| 📋 issue | Linear issue key from the branch name, falling back to a Jira key, or a pinned one. Hidden if neither is found |
| 📁 🤖 ⚡ 🚀 🧠 | Directory, model, effort level, fast mode, extended thinking |
| 📡 remote | Session is being driven remotely (claude.ai / FleetView). The input field isn't documented yet, so this probes likely names |
| 📊 | Context window use: green <50%, yellow <80%, red after that |
| ⏱️ 📅 | 5-hour and 7-day rate-limit use, same colors |
| ✏️ ⏰ 💰 | Lines changed, session time, and session cost (yellow at $1, red at $5) |

The subagent line renders each row in the agent panel as `🔭 Explore · haiku-4-5 · ██░░ 60%`, with a 📡 after the model when the session is remote.

## Install

Requires `bash`, `jq` and `git`. `gh` is optional and only needed for the PR and gh account segments.

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
| `STATUSLINE_LINEAR_PREFIXES` | *(none)* | Comma-separated Linear team keys, e.g. `ENG`. Checked first. Unset skips the Linear pass |
| `STATUSLINE_JIRA_PREFIXES` | *(any)* | Comma-separated Jira project keys, e.g. `OPS,SUP`. Checked only when no Linear key is found. Unset matches any `KEY-123` shape, which can pick up a false positive like `release-2026`. The older `STATUSLINE_ISSUE_PREFIXES` still works as an alias |
| `STATUSLINE_PR_TTL` | `300` | Seconds to cache the PR lookup. `0` turns the PR segment off |
| `STATUSLINE_DEBUG_FILE` | *(unset)* | Path to write each render's raw input JSON to, overwritten every time. Handy for finding field names. It contains session ids and paths, so keep it somewhere private |

**Pinning an issue.** If a branch has no key in its name, pin one for that worktree:

```bash
echo ENG-412 > "$(git rev-parse --git-dir)/statusline-issue"
```

The file lives inside `.git`, so it's never committed. The pin has to match one of your prefixes.

**Lookup order.** The Linear pass checks the branch name, then the worktree's original branch, then the pin. Only if all three come up empty does the Jira pass check the same three. So a Linear key anywhere beats a Jira key anywhere, and the segment is hidden if neither pass finds one.

## iTerm2 tab alerts

When the plugin is installed and you're in iTerm2, its hooks also track Claude's state in the tab:

| State | Tab | Alert |
| - | - | - |
| Working | green `#00d75f` | |
| Needs input (permission prompt, question) | orange `#ff9500` | Dock bounce, "Claude needs input – <project>" banner, spoken phrase |
| Finished | blue `#0a84ff` if the tab is in the background, else cleared | Dock bounce, "Claude finished – <project>" banner, spoken phrase |

It also forwards each event to iTerm2's own `cc-status` helper, which draws the status dot. That helper ships inside iTerm.app and isn't bundled here, so the dot appears only if your iTerm2 has it. Outside iTerm2 the hooks do nothing.

**First run.** The first session in iTerm2 after install asks for your preferences: which features to use, the voice and phrases, and the colors. Out of the box all features are on, and the voice is French (`Amélie`: "J'ai besoin de vous" / "Terminé"). Run `/statusline:tabs` to change them later.

Your answers go in `~/.claude/statusline/tabs.conf`. Environment variables with the same names override that file:

| Variable | Default | Effect |
| - | - | - |
| `STATUSLINE_TAB_COLORS` | `1` | Color the tab |
| `STATUSLINE_TAB_DOT` | `1` | Forward events to iTerm2's `cc-status` for the status dot |
| `STATUSLINE_TAB_ALERTS` | `1` | Dock bounce and notification banner |
| `STATUSLINE_TAB_VOICE` | `Amélie` | macOS `say` voice. Empty means silent |
| `STATUSLINE_TAB_SAY_WAITING` / `_SAY_DONE` | `J'ai besoin de vous` / `Terminé` | Spoken phrases |
| `STATUSLINE_TAB_WORKING` / `_WAITING` / `_UNREAD` | `#00d75f` / `#ff9500` / `#0a84ff` | Tab colors. The status dot keeps iTerm2's own palette |

The tab alerts come from plugin hooks, so they need the plugin install. The `git clone` + `install.sh` route sets up only the status lines.

## Uninstall

```bash
bash ~/.claude/statusline/install.sh --uninstall
```

This removes only the settings that point at `~/.claude/statusline/`. Restore anything you had before from `previous-settings.json`, which is in the same folder.

## License

MIT
