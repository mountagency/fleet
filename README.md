# Fleet

Direct a fleet of parallel Claude Code sessions from a single bridge session. You focus on **what** to build and **why**. Fleet handles the how.

Fleet uses git worktrees and tmux to run multiple autonomous Claude Code sessions in parallel, each on its own branch, with a shared communication protocol so you can monitor progress, send instructions, and review work from one place.

## What it looks like

```
You:    "Good morning! Let's tackle the open issues."
Claude: Fetches issues, spins up 4 worktrees, launches Claude sessions.
        "4 sessions dispatched, 8 queued. Attach with fleet attach."

You:    "Status?"
Claude: "issue-42 is blocked - needs your input on the pricing model.
         issue-38 just finished - CI green, PR ready for review.
         3 sessions active, 6 in queue."

You:    "Tell issue-42 to use gross pricing, 25% tax."
Claude: Sends message to the session. It picks up and continues.

You:    "Review issue-38."
Claude: Runs a cross-review, presents findings.
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mountagency/fleet/main/install.sh | bash
```

### Requirements

- [tmux](https://github.com/tmux/tmux) - terminal multiplexer
- [jq](https://github.com/jqlang/jq) - JSON processor
- [gh](https://cli.github.com/) - GitHub CLI (for issue/PR features)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) - AI coding assistant

```bash
# macOS
brew install tmux jq gh
```

### Manual install

```bash
# Copy the script
cp fleet ~/.local/bin/fleet
chmod +x ~/.local/bin/fleet

# Install the Claude Code skill (optional, enables natural language control)
mkdir -p ~/.claude/skills/fleet
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
```

## Usage

### Work on GitHub issues

```bash
# Specific issues
fleet start 42 43 44

# All open issues (dispatches up to 4 at a time, queues the rest)
fleet start --open

# Control concurrency
fleet start --open --max 6
```

### Freeform work

```bash
# Spin up a research branch
fleet new "auth-redesign" --prompt "Research OAuth2 PKCE flow for our auth system"

# Branch from something specific
fleet new "fix-calendar" --from feature-branch

# Work on an existing PR
fleet pr 123 --prompt "Address the review comments"
```

### Monitor and direct

```bash
# Full status dashboard
fleet sitrep

# Send instructions to a session
fleet message issue-42 "Use the gross pricing model, 25% tax rate"

# Cross-review completed work
fleet review issue-42

# Show the queue
fleet queue

# Fill open slots from the queue
fleet dispatch
```

### Manage sessions

```bash
# Re-attach to the tmux session
fleet attach

# Tear down a specific worktree
fleet stop issue-42

# Tear down everything
fleet stop
```

### tmux basics

Fleet creates a tmux session with one pane per worktree. Quick reference:

| Keys | Action |
|---|---|
| `Ctrl-b d` | Detach (fleet keeps running) |
| `Ctrl-b` + arrows | Move between panes |
| `Ctrl-b z` | Zoom/unzoom current pane |
| `Ctrl-b [` | Scroll mode (`q` to exit) |

## How it works

### Git worktrees

Each session gets its own [git worktree](https://git-scm.com/docs/git-worktree), a lightweight checkout of the same repo on a separate branch. No cloning, no duplicate history. Worktrees are created at `../{reponame}-fleet/` next to your repo.

### Communication protocol

Worker sessions follow a protocol injected via `--append-system-prompt`:

- **Status updates** (`_bridge/status/{session}.json`) - phase, summary, blockers, CI status
- **Event logs** (`_bridge/log/{session}.jsonl`) - full history of what happened
- **Discoveries** (`_bridge/discoveries/{topic}.md`) - non-obvious findings shared across sessions
- **Messages** (`_bridge/messages/{session}.md`) - instructions from you to sessions

### Auto-detection

Fleet auto-detects your project type and configures dependency installation and test commands:

| Detected | Install | Test |
|---|---|---|
| `Gemfile` | `bundle install` | `bin/ci` or `rake test` |
| `package-lock.json` | `npm install` | `npm test` |
| `yarn.lock` | `yarn install` | `npm test` |
| `pnpm-lock.yaml` | `pnpm install` | `npm test` |
| `requirements.txt` | `pip install -r requirements.txt` | `pytest` |
| `pyproject.toml` + `uv.lock` | `uv sync` | `pytest` |
| `Cargo.toml` | `cargo build` | `cargo test` |
| `go.mod` | `go mod download` | `go test ./...` |
| `mix.exs` | `mix deps.get` | `mix test` |

### Queue system

When you have more issues than slots, fleet queues them. As sessions complete, the next item is dispatched automatically. Priority is configurable (`--priority N`, lower = higher priority).

### Cross-review

When a session finishes, you can trigger a review. Fleet runs `claude -p` (non-interactive) to review the diff, saves the findings, and sends feedback as a message to the original session.

## Claude Code skill

The included skill (`skill/SKILL.md`) teaches Claude Code how to use fleet through natural language. Install it to `~/.claude/skills/fleet/` and you can say things like:

- "Good morning! Let's tackle the open issues."
- "I had this idea about notifications..."
- "What's the status?"
- "Tell the auth session to use OAuth2 instead"
- "Review the calendar fix"

## Options

| Flag | Description |
|---|---|
| `--max N` | Max concurrent worktrees (default: 4) |
| `--no-install` | Skip dependency installation |
| `--no-claude` | Set up worktrees without starting Claude |
| `--priority N` | Queue priority (lower = higher, default: 10) |
| `--from <ref>` | Branch from specific ref (default: main) |
| `--prompt "..."` | Initial context for the Claude session |

## License

MIT
