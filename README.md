# Fleet

Direct a fleet of parallel Claude Code sessions from a single conversation. You focus on **what** to build and **why**. Fleet handles everything else.

## What it looks like

```
You:    "Good morning! Let's tackle the open issues."
Claude: Fetches issues, decomposes work, spawns 4 parallel sessions.
        "4 sessions working. 8 queued. I'll dispatch more as slots open."

You:    "Status?"
Claude: "issue-42 is blocked - can't find the pricing spec. What model should it use?"
        "issue-38 finished - CI green. Want me to create a PR?"
        "3 others actively implementing."

You:    "Gross pricing, 25% tax. And yes, PR for 38."
Claude: Sends pricing guidance to issue-42. Creates PR for issue-38.

You:    "Review PR 47 and leave comments on GitHub."
Claude: Spawns a review session that reads the diff and posts review comments via gh.

You:    "I just had a call with a customer - their mobile check-in is broken."
Claude: Spawns a session to investigate and fix, with full context from your description.
```

This isn't a CLI tool with flags. It's an intelligence layer. Claude Code is the brain. Fleet is how it thinks in parallel.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mountagency/fleet/main/install.sh | bash
```

### Requirements

- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [jq](https://github.com/jqlang/jq) - `brew install jq`
- [gh](https://cli.github.com/) - `brew install gh` (for GitHub features)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

### Manual install

```bash
cp fleet ~/.local/bin/fleet && chmod +x ~/.local/bin/fleet
mkdir -p ~/.claude/skills/fleet && cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
```

## How it works

Fleet has two parts:

**1. A thin bash script** (`fleet`) that handles plumbing:
- Creates git worktrees for branch isolation
- Manages tmux panes for parallel sessions
- Starts Claude Code with a communication protocol
- That's it. Four commands: `spawn`, `stop`, `attach`, `ls`

**2. A Claude Code skill** (`skill/SKILL.md`) that is the actual brain:
- Decomposes your intent into concrete tasks
- Composes rich, context-aware prompts for worker sessions
- Reads status files to give you intelligent sitreps
- Sends messages to workers, manages queues, triggers reviews
- Uses `gh` to create PRs, post review comments, merge branches
- Orchestrates the full lifecycle from idea to shipped code

The skill teaches Claude to be a tech lead. You talk to it naturally. It figures out what to spawn, what prompt to give each worker, and how to coordinate the results.

### The communication protocol

Worker sessions follow a lightweight protocol injected via `--append-system-prompt`:

- **Status** (`_bridge/status/{session}.json`) - current phase, blockers, CI status
- **Logs** (`_bridge/log/{session}.jsonl`) - event history
- **Messages** (`_bridge/messages/{session}.md`) - instructions from bridge to worker
- **Discoveries** (`_bridge/discoveries/{topic}.md`) - knowledge shared across sessions

The bridge session (your main conversation) reads these files to know what's happening and writes to them to send instructions.

### Auto-detection

Fleet auto-detects your project type for dependency installation:

| Detected | Install command |
|---|---|
| `Gemfile` | `bundle install` |
| `package-lock.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `pnpm-lock.yaml` | `pnpm install` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `pyproject.toml` + `uv.lock` | `uv sync` |
| `Cargo.toml` | `cargo build` |
| `go.mod` | `go mod download` |
| `mix.exs` | `mix deps.get` |

## Examples

All of these are things you say to Claude in a normal conversation:

**Start of day:**
> "Good morning! What issues do we have open?"

**Dispatch work:**
> "Let's tackle issues 12, 15, and 23."

**Explore an idea:**
> "I've been thinking about adding a waitlist for sold-out events. Can you research that?"

**Fix a bug:**
> "Customer just reported check-in fails on mobile with multiple guests. Fix it."

**Review a PR:**
> "Review PR 47 and post your feedback as GitHub comments."

**Send instructions:**
> "Tell the auth session to use OAuth2 PKCE instead of the implicit flow."

**Check progress:**
> "What's happening?"

**Handle blockers:**
> "The calendar session is blocked? Tell it to use UTC everywhere, we'll handle timezone display in the frontend."

**Ship it:**
> "issue-38 looks good. Create a PR and merge it."

**Non-code work:**
> "Write a changelog summarizing what we shipped this week."
> "Research how competitors handle multi-location pricing."
> "Draft a product spec for the loyalty program."

## tmux basics

Fleet creates a tmux session with one pane per worker. Quick reference:

| Keys | Action |
|---|---|
| `Ctrl-b d` | Detach (everything keeps running) |
| `Ctrl-b` + arrows | Move between panes |
| `Ctrl-b z` | Zoom/unzoom current pane |
| `fleet attach` | Re-attach |

## Philosophy

Fleet is not a task runner. It's not a CLI wrapper. It's a paradigm shift.

The developer becomes a **director**. You think about product, customers, and strategy. You make decisions when they matter. You review results, not process.

Claude becomes your **engineering team**. It decomposes work, implements in parallel, tests, reviews, and ships. Each session has the full power of Claude Code - file editing, terminal access, web search, GitHub integration, MCP servers, everything.

The communication protocol is how they stay coordinated. Status files, event logs, shared discoveries, and messages. Simple files. No framework. No overhead.

## License

MIT
