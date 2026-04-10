# Fleet

Software is no longer built by typing code. It's built by directing intent.

Fleet turns Claude Code into a parallel engineering team. You open your terminal, say what you want to build, and Fleet decomposes the work, dispatches autonomous sessions, coordinates their output, and ships the result. You stay in one conversation. The work happens around you.

This is not a task runner. This is not a wrapper around git commands. This is the operating layer for AI-native software development.

## Why Fleet exists

We're in the middle of a phase change in how software gets built. The bottleneck is no longer writing code. It's deciding what to write, understanding why it matters, and coordinating the work. Those are human problems. Everything downstream of a clear decision can be automated.

Today, Claude Code is a single-threaded conversation. One session, one task, one branch. You context-switch between issues manually. You run reviews yourself. You remember which PR needs what. That's the old model.

Fleet makes Claude Code multi-threaded. You talk to one session (the bridge) and it orchestrates many (the workers). Each worker gets its own git worktree, its own branch, its own tmux pane. They run in parallel, follow a communication protocol, and report back. You make decisions. They make code.

The developer becomes a director. The product manager becomes the bottleneck again (in a good way). The constraint moves from "how fast can I type" to "how clearly can I think."

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

No flags. No configuration files. No CLI to learn. Just conversation.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mountagency/fleet/main/install.sh | bash
```

### Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [jq](https://github.com/jqlang/jq) - `brew install jq`
- [gh](https://cli.github.com/) - `brew install gh` (for GitHub features)

### Manual install

```bash
cp fleet ~/.local/bin/fleet && chmod +x ~/.local/bin/fleet
mkdir -p ~/.claude/skills/fleet && cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
```

## Architecture

Fleet is intentionally split into two layers with very different jobs.

### The script: plumbing

The `fleet` bash script does exactly four things:

```bash
fleet spawn <name> [--from ref] [--prompt "..."]   # Worktree + tmux + Claude
fleet stop [names...]                                # Tear down
fleet attach                                         # Re-attach tmux
fleet ls                                             # List worktrees (JSON)
```

It creates git worktrees, manages tmux panes, starts Claude Code sessions with the worker protocol, and cleans up when done. It auto-detects your project type (Rails, Node, Python, Rust, Go, Elixir) for dependency installation. Nothing more. 150 lines of bash.

### The skill: intelligence

The `skill/SKILL.md` is where Fleet actually lives. It teaches Claude Code to be a tech lead:

- Decompose vague intent into concrete parallel tasks
- Compose rich prompts so worker sessions start fully informed
- Read bridge status files and give intelligent sitreps
- Write messages to workers to unblock them
- Manage a queue when there are more tasks than slots
- Trigger reviews, create PRs, merge branches, post GitHub comments
- Orchestrate the full lifecycle from idea to shipped code

The skill doesn't limit what workers can do. Each worker is a full Claude Code session with access to everything: file editing, terminal, web search, GitHub CLI, MCP servers. The skill just teaches the bridge how to direct them.

### The protocol: coordination

Worker sessions follow a lightweight file-based protocol:

```
{repo}-fleet/
  _bridge/
    status/{session}.json       # Phase, summary, blockers, CI status
    log/{session}.jsonl          # Append-only event history
    messages/{session}.md        # Bridge-to-worker instructions
    discoveries/{topic}.md       # Knowledge shared across sessions
```

Workers write status after every phase change. The bridge reads it when you ask for a sitrep. Workers check for messages before major decisions. If they learn something non-obvious about the codebase, they write a discovery that other sessions can benefit from.

Simple files. No database. No daemon. No framework.

## Examples

Everything below is a natural language conversation with Claude Code. Fleet activates automatically through the skill.

**Start of day:**
> "Good morning! What do we have today?"

**Dispatch work:**
> "Let's tackle issues 12, 15, and 23."

**Explore an idea:**
> "I've been thinking about adding a waitlist for sold-out events. Can you research how other platforms handle this and write up a brief?"

**Fix a bug from a customer call:**
> "Just got off a call. Customer says check-in fails on mobile when there are multiple guests. Can you investigate and fix?"

**Review and comment on a PR:**
> "Review PR 47 and post your feedback as GitHub comments."

**Direct a worker:**
> "Tell the auth session to use OAuth2 PKCE instead of the implicit flow."

**Check progress:**
> "What's happening?"

**Unblock a session:**
> "The calendar session is blocked? Tell it to use UTC everywhere. We'll handle timezone display in the frontend."

**Ship it:**
> "issue-38 looks good. Create a PR and merge it."

**Non-code work:**
> "Write a changelog summarizing what we shipped this week."
> "Research how competitors handle multi-location pricing."
> "Draft a product spec for the loyalty program feature."

**End of day:**
> "Wrap up. What did we ship today?"

## tmux basics

Fleet creates a tmux session with one pane per worker. You don't need to know tmux to use Fleet, but four shortcuts help:

| Keys | Action |
|---|---|
| `Ctrl-b d` | Detach (everything keeps running in background) |
| `Ctrl-b` + arrows | Move between panes |
| `Ctrl-b z` | Zoom/unzoom current pane (fullscreen toggle) |
| `fleet attach` | Re-attach to the session |

## Project type detection

Fleet detects your stack and handles dependency installation automatically:

| Detected | Install |
|---|---|
| `Gemfile` | `bundle install` |
| `package-lock.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `pnpm-lock.yaml` | `pnpm install` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `pyproject.toml` + `uv.lock` | `uv sync` |
| `pyproject.toml` + `poetry.lock` | `poetry install` |
| `Cargo.toml` | `cargo build` |
| `go.mod` | `go mod download` |
| `mix.exs` | `mix deps.get` |

## Where this is going

Fleet is early. It works today for parallelizing Claude Code sessions with coordination. Here's what we're building toward:

- **Persistent fleet memory.** Workers accumulate knowledge about your codebase over time. New sessions start smarter.
- **Cross-session dependency awareness.** If session A changes a model that session B depends on, the bridge detects it and coordinates.
- **Scheduled fleets.** Spin up a fleet overnight. Review the results in the morning.
- **Multi-repo support.** Direct work across repositories from a single bridge.
- **Custom worker personas.** Specialized sessions for frontend, backend, security review, performance optimization.
- **Fleet-to-fleet.** Bridge sessions that orchestrate other bridge sessions for truly large-scale work.

## Contributing

Fleet is open source under MIT. We're building this in public because we believe the future of software development is directing intent, not typing code, and that future should be open.

The best way to contribute right now is to use Fleet, find where it breaks, and open issues.

## License

MIT
