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
You:    "The onboarding is losing people."
Claude: "Before I dispatch work -- what's the signal? High drop-off on a specific
         step, or a general feeling from customer feedback?"

You:    "Analytics show 60% drop at the profile setup step."
Claude: "Got it. I'll decompose this into three parallel tracks:
         1. Audit the current profile setup flow (code + UX)
         2. Research how top products handle progressive profiling
         3. Analyze the analytics data for patterns in who drops off
         Assumptions: we want to keep the existing page structure and improve it,
         not rebuild from scratch. Tests required. Correct?"

You:    "Yes. Go."
Claude: "3 workers dispatched. Research has no dependencies. Audit and analytics
         are independent. I'll synthesize findings when all three complete."

You:    [30 minutes later] "Status?"
Claude: "Research done -- wrote findings to docs/onboarding-research.md.
         Audit found the profile form makes 4 separate API calls on submit.
         Analytics worker is blocked:

         Decision needed: The analytics data is in two formats -- legacy events
         and new Segment events. Should the worker analyze both or just Segment?
         My recommendation: both, since the drop-off predates the Segment migration.
         Stakes: low (it's an analysis task, easily re-run).

         Approve my recommendation?"

You:    "Yes, both."
Claude: "Sent guidance. I'll have a synthesis ready when all three complete."
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
cp skill/WORKER_PROTOCOL.md ~/.claude/skills/fleet/WORKER_PROTOCOL.md
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

It creates git worktrees, manages tmux panes, starts Claude Code sessions with the worker protocol, and cleans up when done. It auto-detects your project type (Rails, Node, Python, Rust, Go, Elixir) for dependency installation. Nothing more. Under 200 lines of bash.

### The skill: intelligence

The `skill/SKILL.md` is where Fleet actually lives. It teaches Claude Code to be a chief of staff:

- Why-drill vague intent before dispatching work
- Detect and surface assumptions so the director can confirm or correct
- Escalate honestly when workers are blocked, with recommendations and stakes
- Choose context strategies (full codebase, targeted files, discovery docs) per worker
- Build dependency graphs so workers execute in the right order
- Manage a task queue with priority and concurrency limits
- Orchestrate the full lifecycle from idea to shipped code

The skill doesn't limit what workers can do. Each worker is a full Claude Code session with access to everything: file editing, terminal, web search, GitHub CLI, MCP servers. The skill just teaches the bridge how to direct them.

### The worker protocol: coordination

The `skill/WORKER_PROTOCOL.md` is a standalone document given to every worker session. It defines the checkpoint protocol and bridge file conventions:

```
{repo}-fleet/
  _bridge/
    status/{session}.json       # Phase, summary, blockers, CI status
    log/{session}.jsonl          # Append-only event history
    messages/{session}.md        # Bridge-to-worker instructions
    discoveries/{topic}.md       # Knowledge shared across sessions
    queue.json                   # Task queue with priority and state
    graph.json                   # Dependency graph across workers
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

Fleet v2 shipped the intelligent bridge (why-drilling, honest escalation, reactive coordination). Here's what's next:

- **Telegram integration.** Direct the fleet from your phone. Get notified when workers complete or need decisions. Detach from the terminal and reattach with a full briefing.
- **Persistent fleet memory.** Workers accumulate knowledge about your codebase. New sessions start with architecture maps, conventions, and gotchas from previous work.
- **Director model.** Fleet learns your preferences, quality bar, and decomposition style. Fewer questions over time.
- **Multi-repo support.** Direct work across repositories from a single bridge.
- **Agent-agnostic backends.** The worker protocol is file-based and agent-agnostic. Pluggable backends for other AI coding tools are architecturally ready.

## Contributing

Fleet is open source under MIT. We're building this in public because we believe the future of software development is directing intent, not typing code, and that future should be open.

The best way to contribute right now is to use Fleet, find where it breaks, and open issues.

## License

MIT
