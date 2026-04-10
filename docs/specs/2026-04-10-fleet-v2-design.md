# Fleet v2: The Orchestration OS

**Date:** 2026-04-10
**Status:** Design approved
**Authors:** Simon Thordal, Claude

## Vision

Fleet today parallelizes Claude Code sessions. Fleet v2 turns a single developer into an engineering organization.

The director thinks at the level of *why* -- why are we solving this problem, what value does it bring, what's the right trade-off. Fleet handles decomposition, dispatch, coordination, and delivery. The director's constraint shifts from "how fast can I type" to "how clearly can I think."

100x is not about speed. It's about operating at a fundamentally higher level of abstraction while maintaining quality and coherence across all the work happening in parallel.

## Design Principles

**The bridge is a chief of staff, not an eager executor.** It thinks before it acts. It challenges vague directives. It never dispatches work it doesn't fully understand. It has opinions and shares them honestly.

**Workers are autonomous professionals.** They have full Claude Code power. The protocol is guidance, not a straitjacket. Trust them to make decisions. Only escalate genuine ambiguity.

**Natural language is the only interface.** The director never needs to learn CLI flags, file formats, or protocol details. If the abstraction leaks implementation details, it's broken.

**Claude Code first, agent-agnostic later.** Nail the Claude Code experience. Architect the worker interface so other agents (Copilot, Cursor, Codex, Gemini CLI) can plug in later. Don't build the abstraction until there's a second backend.

**Fleet gets smarter over time.** Every session contributes to accumulated intelligence. The 50th session should be dramatically better than the 1st.

**The director is untethered.** Fleet works when you're at the terminal and when you're not. The constraint is having an opinion, not being at a computer.

---

## Layer 1: The Intelligent Bridge

### Problem

The bridge today dispatches work based on the director's literal request. If the request is vague, the bridge guesses. If assumptions are wrong, workers waste time. The bridge doesn't explain its reasoning or give the director enough information to make good decisions.

### Why-Drilling Protocol

When the director gives a vague or broad directive, the bridge doesn't guess. It drills to clarity.

The bridge asks focused questions:
- "What problem are we actually solving?"
- "Who benefits and how will we know it worked?"
- "What's the constraint -- time, quality, scope?"

**Termination condition:** The bridge can articulate the goal back to the director in one sentence and the director confirms. Only then does decomposition begin.

**Calibration:** Why-drilling depth is proportional to the vagueness of the input. "Fix the typo on the pricing page" needs zero drilling. "The onboarding sucks" needs three questions. The bridge should recognize clear directives and act immediately -- drilling everything is as wasteful as drilling nothing.

### Assumption Detection

Before dispatching any work, the bridge states its assumptions explicitly:

> "I'm going to decompose this into 3 workers. I'm assuming: the API schema is stable, we want tests for all new endpoints, and this should target main. Correct?"

If the director corrects, the bridge adjusts before spawning. If the director confirms, the bridge logs the confirmed assumptions and proceeds with confidence.

Assumptions are categorized:
- **Technical** -- target branch, test expectations, dependency versions
- **Scope** -- what's included, what's explicitly excluded
- **Quality** -- review required? CI must pass? Documentation needed?

### Honest Escalation Framework

When a worker or the bridge hits a decision point, it provides structured escalation:

1. **The decision** -- what needs to be decided, stated clearly
2. **The options** -- concrete choices with trade-offs, not open-ended "what should I do?"
3. **The recommendation** -- what Fleet would do and why
4. **Why it's escalating** -- categorized reason:
   - *Irreversible* -- can't undo this easily (database migration, public API change)
   - *Business impact* -- affects pricing, customers, legal, brand
   - *Ambiguous requirements* -- multiple valid interpretations, director intent unclear
   - *Risk of wasted work* -- wrong choice means redoing significant work
   - *Outside domain knowledge* -- Fleet doesn't have enough business context
5. **Timeout behavior** -- for detached mode: "I'll proceed with Option A in 30 minutes if I don't hear back" (low/medium stakes only; high-stakes decisions always wait)

**The principle:** Fleet should always have an opinion but know when its opinion isn't sufficient. It comes to the director with a recommendation and a clear ask, not a blank question.

### Intelligent Decomposition

The bridge doesn't just split work into parallel chunks. It considers:

- **Dependencies** -- what must complete before what? Build the dependency graph before spawning.
- **Work type** -- research, implementation, refactoring, review, content each get different context strategies and prompt structures.
- **Scope per worker** -- each worker should have a coherent, completable task. If a task requires understanding the full system, it's too big for one worker.
- **Conflict risk** -- will two workers touch the same files? If so, sequence them or define clear boundaries.

---

## Layer 2: Context Efficiency

### Problem

Every new worker starts cold. It re-reads the same files, rediscovers the same patterns, makes the same initial assessments. Meanwhile, the bridge has already accumulated understanding from prior sessions. This knowledge is wasted.

### Work-Type-Aware Context Strategies

The bridge recognizes the type of work and composes worker prompts with relevant context, not everything:

| Work type | Context includes |
|---|---|
| Bug fix | Reproduction steps, specific files/lines, related tests, error output, recent changes to affected area |
| Feature | Decisions/spec summary, architecture of affected area, relevant patterns, acceptance criteria |
| Refactor | Dependency map of affected area, test coverage, conventions, what NOT to change |
| Research | Goal, constraints, output format template, where to write findings, what decisions this will inform |
| Review | Original intent/decisions, what to focus on, risk areas, how to post feedback |
| Content/docs | Audience, tone, existing examples, where it lives, related content |

The bridge selects context by relevance to the task, not by quantity.

### Session Distillation

When a worker completes, the bridge extracts a **session digest** -- a compact summary of what happened and why:

```markdown
## Session: fix-calendar
Outcome: PR #84 created, CI green

### What was done
- Fixed timezone handling in CalendarService#available_slots
- Added test for multi-timezone guest scenario

### Key decisions
- Used UTC internally, convert at display layer (confirmed by director)
- Did not refactor existing timezone helpers -- out of scope

### Discoveries
- CalendarService has no test coverage for DST transitions
- The `available_slots` query hits the DB N+1 for each guest

### Files changed
- app/services/calendar_service.rb
- spec/services/calendar_service_spec.rb
```

Future workers that touch the same area get relevant digests. The bridge decides what's relevant based on file overlap and topic.

### Committed Breadcrumbs

Each worker branch gets a `.fleet/session.md` committed with it. This file contains:
- The session digest
- Confirmed assumptions from the bridge
- Director guidance given mid-session
- Discoveries

When someone else opens the PR (another developer, another Fleet), this file provides full context for *why* the code looks the way it does. This is the multiplayer knowledge transfer mechanism -- no infrastructure, just a committed file that any Fleet can read.

### Output Quality as Knowledge Transfer

Fleet's artifacts ARE the knowledge layer. Better output = better knowledge transfer:

- **Commit messages** explain why, not what. The diff shows what changed; the message explains the reasoning.
- **PR descriptions** are structured: problem, approach, decisions made, trade-offs accepted, risks, test coverage.
- **Session logs** capture the journey for posterity.

The bridge enforces this through worker prompts. Workers are instructed to write for their future reader, not just to close the task.

---

## Layer 3: Reactive Coordination

### Problem

Parallel workers can collide. Worker A changes a model that Worker B depends on. Worker C finishes the API that Worker D has been waiting for, but D doesn't know. The bridge today is passive -- it only knows what's happening when the director asks.

### Dependency Graph

At decomposition time, the bridge builds a dependency map:

```
worker-api       (no dependencies)        → dispatch immediately
worker-schema    (no dependencies)        → dispatch immediately
worker-frontend  (depends on: worker-api) → dispatch with partial instructions, full context on API completion
worker-e2e-tests (depends on: worker-frontend, worker-api) → queue until both complete
```

The graph is simple and explicit. The bridge maintains it and updates it as work progresses. It's not a formal DAG framework -- it's a mental model the bridge holds and acts on.

### State-Change Reactions

When a worker updates its status file, the bridge reacts:

**Worker completes:**
- Check the dependency graph: who was waiting?
- Distill the session
- Write to dependent workers' message files with relevant context: "The API is ready on branch `fleet/worker-api`. Endpoints: GET /events, POST /events/:id/register. Schema: [brief description]. Proceed with integration."
- Check the queue: dispatch next unblocked task

**Worker gets blocked:**
- Read the blocked reason
- Can the bridge resolve it with information it already has? If yes, write guidance to message file.
- Does another worker's output resolve this? If yes, note the dependency and wait.
- Otherwise, escalate to director via the appropriate channel (terminal or Telegram).

**Worker changes overlapping files:**
- Bridge reads diffs from status updates
- If two workers are modifying the same files, assess whether it's a real conflict
- If conflict: decide who yields based on the dependency graph and task priority. Write instructions to the yielding worker.
- If not a conflict (e.g., different sections of a large file): note it and let both continue, but flag it for the merge step.

### Checkpoint Protocol

Workers follow mandatory checkpoints where they read their message file:

1. **After initial analysis** -- before committing to an approach
2. **Before implementation** -- before writing code
3. **Before committing** -- before creating commits
4. **Before marking done** -- before setting status to `done`

The bridge knows this rhythm and writes messages timed to the relevant checkpoint. This isn't real-time -- workers check at natural pause points. A message arrives within seconds to minutes, which is fast enough for tasks that take minutes to hours.

### Queue Management

When there are more tasks than reasonable parallel workers:

```json
{
  "items": [
    {"id": "feature-waitlist", "priority": 1, "status": "queued", "depends_on": [], "prompt": "..."},
    {"id": "refactor-billing", "priority": 2, "status": "queued", "depends_on": ["feature-waitlist"], "prompt": "..."}
  ]
}
```

The bridge manages this at `_bridge/queue.json`. As workers complete:
1. Distill the completed session
2. Check the graph for newly unblocked tasks
3. Dispatch the highest priority unblocked task, enriched with context from completed sessions
4. Notify the director: "worker-api finished. PR created. Dispatching worker-frontend."

The director can reprioritize at any time: "Do the billing refactor next, it's urgent."

---

## Layer 4: Untether the Director

### Problem

Fleet today requires the director to sit at a terminal. The director can't leave, can't work from their phone, can't go to a meeting while the fleet works. This is the single biggest ceiling on productivity.

### Three Modes

**Live:** Director is in the terminal. Full Claude Code conversation. This is today's experience, enhanced by Layers 1-3.

**Detached:** Director leaves. Fleet continues autonomously. Workers keep working. The bridge monitors, coordinates, dispatches from queue, makes low-stakes decisions autonomously. Decisions that need the director go to Telegram.

**Reattach:** Director returns to the terminal. The bridge provides a structured briefing covering everything that happened while detached.

Transitions are seamless:
- `fleet detach` or closing the terminal → detached mode
- `fleet attach` or opening a new Claude Code session → reattach with briefing
- Telegram is always available in all modes

### Telegram Bot

A lightweight bot that communicates via `curl` to the Telegram Bot API. No SDK, no framework, consistent with Fleet's no-dependencies philosophy.

**Setup:** One-time: create a bot via BotFather, save the token. Fleet stores it in `~/.fleet/telegram.json`. The bridge uses it for all outbound/inbound communication.

**Outbound (Fleet to Director):**

| Event | Message style |
|---|---|
| Worker completed | "fix-calendar done. PR #84, tests green. Merge? [Yes / Review first]" |
| Worker blocked | "auth-refactor needs a decision. PKCE or auth code flow? I recommend PKCE because [1 sentence]. Reply A or B." |
| Discovery | "worker-api found payments table has no index on user_id. Spawn a fix? [Yes / Queue it / Ignore]" |
| Progress summary | "3/5 tasks done. 2 in progress. Nothing blocked." (periodic or on-demand) |
| Autonomous decision made | "I dispatched update-deps from the queue. Low priority, no dependencies. Let me know if you'd rather I held off." |

Messages are concise, actionable, and always include the bridge's recommendation when a decision is needed.

**Inbound (Director to Fleet):**

The bot accepts:
- Simple responses: "yes", "merge it", "A", "stop auth-refactor"
- New directives: "also fix the mobile nav"
- Questions: "what's the auth worker doing?"
- Reprioritization: "do billing next"

The bridge parses natural language, not commands. "ship it" means merge. "hold off" means wait. "kill it" means stop.

### Escalation Routing

Not everything goes to Telegram. The bridge categorizes decisions by stakes:

| Stakes | Behavior |
|---|---|
| **Notification only** | Worker completed, tests passed, dispatched from queue. Telegram, no response needed. |
| **Low stakes** | Code style, naming, minor approach choice. Bridge decides autonomously. Mentioned in reattach briefing. |
| **Medium stakes** | Approach choice, scope question, non-critical trade-off. Telegram with recommendation and timeout ("I'll proceed with A in 30 min"). |
| **High stakes** | Breaking change, business logic, irreversible action, significant scope change. Telegram, waits for response. No timeout. |

The bridge learns the director's risk tolerance over time (Layer 5) and adjusts the routing accordingly.

### Detached Mode: How It Works

When the director detaches, the fleet doesn't stop. Workers are already running in tmux panes -- they continue regardless. The question is: what happens to the bridge?

The bridge accumulates state to a `_bridge/briefing.md` file as events happen (workers completing, blocking, discoveries). Telegram messages go out via `curl` calls from worker-side hooks or a lightweight watcher script that monitors `_bridge/status/` for changes and triggers notifications. When the director sends a Telegram response, the bot relays it to `_bridge/messages/` where the relevant worker picks it up at the next checkpoint.

The bridge doesn't need to be a running process. The intelligence re-activates when the director reattaches (a new Claude Code session reads the accumulated briefing and bridge state) or when the director interacts via Telegram (the bot triggers targeted actions).

This means detached mode is not a daemon -- it's the combination of: (a) workers continuing in tmux, (b) a file watcher sending Telegram notifications, and (c) the bot writing responses back to bridge files. The full bridge intelligence comes back when the director does.

### Reattach Briefing

When the director returns, the bridge presents a structured summary:

```
Welcome back. Here's what happened (45 min detached):

Completed:
  - fix-calendar: PR #84 merged (you approved via Telegram)
  - update-deps: PR #85 created, CI green, awaiting review

In progress:
  - auth-refactor: implementing OAuth2 PKCE (your choice via Telegram)

Decisions I made autonomously:
  - Dispatched update-deps from queue (low priority, no dependencies)
  - Used existing test fixtures for calendar fix rather than creating new ones

Needs you now:
  - auth-refactor found the session store needs migrating.
    Options: A) migrate in this PR (risk: larger scope), B) separate migration PR (risk: temporary incompatibility).
    My recommendation: B -- keep the auth PR focused. I'll queue the migration as a follow-up.

Discoveries:
  - CalendarService has no DST test coverage (queued as low priority)
  - payments table missing index on user_id (queued as medium priority)
```

The briefing is conversational, prioritized, and actionable. Blocked items first, then completions, then autonomous decisions, then discoveries.

---

## Layer 5: Learning

### Problem

Session 1 and session 100 are identical today. The bridge doesn't remember what it learned. Workers start cold every time. The director has to re-explain preferences. Fleet has amnesia.

### Three Types of Accumulated Intelligence

#### 1. Director Model

Fleet learns how the director works:

- **Decomposition style** -- many small workers vs. fewer large ones
- **Quality expectations** -- always tests? Documentation? Specific commit message format?
- **Review focus** -- what they flag, what they let slide
- **Communication preferences** -- terse vs. detailed, notification frequency, risk tolerance for autonomous decisions
- **Domain priorities** -- "Simon always asks about mobile performance", "Asger always checks database implications"

**How it builds:** Passively, from every interaction. The bridge observes:
- Corrections: "no, split that into two workers" → preference for smaller tasks
- Confirmations: "perfect" → validated approach, repeat it
- Patterns: director always asks about test coverage before merging → add it to status updates proactively

**Where it lives:** `~/.fleet/directors/{username}.md` -- local, per-user, not committed to the repo. This is personal to each director.

**How it's used:** The bridge consults the director model before why-drilling (maybe this director's default answers make some questions unnecessary), before escalation routing (this director's risk tolerance), and before composing briefings (this director wants terse updates).

#### 2. Execution Patterns

Fleet learns what works for this codebase:

- "Parallelizing frontend and backend works fine, but don't parallelize two migration workers -- they conflict on schema.rb"
- "Workers on the payments module take longer because the test suite is slow there"
- "Research tasks produce better output when given a specific output template"
- "PRs touching more than 5 files get review pushback -- decompose further"

**How it builds:** From session digests and outcomes. The bridge notes:
- Conflicts that occurred and why
- Tasks that took unexpectedly long and what caused it
- Approaches that worked well (recorded as patterns to repeat)
- Approaches that failed (recorded as patterns to avoid)

**Where it lives:** `.fleet/knowledge/patterns.md` -- committed to the repo, benefits the whole team.

**How it's used:** The bridge consults patterns during decomposition. "Last time we parallelized work in the payments area, workers conflicted. Sequencing this time."

#### 3. Codebase Knowledge

Fleet accumulates institutional knowledge about the project:

- **Architecture map** -- how the system is structured, where the entry points are, how services relate
- **Conventions** -- patterns the codebase follows (service objects for business logic, decorators for presentation, etc.)
- **Gotchas** -- known pitfalls (CI cache breaks if you change the Dockerfile, the legacy API has undocumented rate limits, etc.)
- **Dependencies** -- changing the User model requires updating the GraphQL schema and the mobile serializer

**How it builds:** From session discoveries. When a worker finds something non-obvious, it writes a discovery. The bridge incorporates it into the knowledge base if it's durable (not just a one-off finding).

**Where it lives:** `.fleet/knowledge/` -- committed to the repo:
```
.fleet/knowledge/
  architecture.md     # System map
  conventions.md      # Patterns and rules
  gotchas.md          # Known pitfalls
  patterns.md         # Execution patterns (what works/doesn't)
```

**How it's used:** The bridge includes relevant knowledge in worker prompts. A worker touching CalendarService gets the architecture context for the scheduling domain, the known gotcha about DST, and the convention for service objects.

### The Compound Effect

**Session 1:** Fleet knows nothing. Full why-drilling. Workers start cold. Decomposition is generic. The bridge asks many questions.

**Session 10:** Fleet knows the architecture and basic conventions. Workers get relevant context. The bridge has seen the director's style a few times and makes better guesses.

**Session 50:** Fleet knows the director, the codebase, and what orchestration strategies work. Minimal drilling for routine work. Workers start warm with institutional knowledge. The bridge anticipates conflicts before they happen. Decomposition accounts for known slow test suites and file-level dependencies.

**Session 100:** The director says "ship the waitlist feature" and Fleet already knows: the relevant services and their relationships, the testing conventions, the director's quality bar, that the last time someone touched the booking system they broke the calendar sync (and how to prevent it), and that this director prefers three focused workers over one large one. It decomposes, dispatches, coordinates, and the director reviews a PR over Telegram while walking their dog.

---

## Architecture

### What changes in the script

Minimal. The script stays thin. New commands:

- `fleet detach` -- saves bridge state, enters detached mode
- `fleet attach` -- reattaches with briefing trigger

Everything else (Telegram, dependency graph, learning, escalation) lives in the skill and in bridge-side files. The script remains plumbing.

### What changes in the skill

Significant rewrite. The skill becomes the full intelligence layer:

- Why-drilling and assumption detection logic
- Decomposition with dependency graph construction
- Escalation framework with stakes classification
- Session distillation templates
- Telegram integration (composing messages, parsing responses)
- Reattach briefing generation
- Knowledge base reading/writing
- Director model reading/updating
- Queue management with priority and dependency awareness

### File structure

```
fleet                           # Bash script (plumbing)
skill/SKILL.md                  # Intelligence layer (rewritten)
install.sh                      # Installer (updated for new files)

# Per-project (committed to repo)
.fleet/
  knowledge/
    architecture.md
    conventions.md
    gotchas.md
    patterns.md
  sessions/
    {session-name}.md           # Distilled digests

# Per-project working state (in fleet base dir, not committed)
{repo}-fleet/
  _bridge/
    status/{session}.json
    log/{session}.jsonl
    messages/{session}.md
    discoveries/{topic}.md
    queue.json
    graph.json                  # Dependency graph
    briefing.md                 # Accumulated briefing for reattach
    state.json                  # Bridge mode, detach time, etc.

# Per-user (local)
~/.fleet/
  telegram.json                 # Bot token, chat ID
  directors/
    {username}.md               # Director model
```

### Worker interface (agent-agnostic prep)

Today, workers are Claude Code sessions started via `tmux send-keys`. The worker protocol (status files, log, messages, checkpoints) is already agent-agnostic -- it's just files. Any agent that can read/write files and run terminal commands can follow it.

To prepare for pluggable backends:
- The worker protocol is documented as a standalone spec (not embedded in the bash script)
- `fleet spawn` accepts a `--backend` flag (default: `claude-code`, only option for now)
- The prompt generation is separated from the spawn mechanics

No abstraction layer is built until there's a second backend. But the seams are clean.

---

## Implementation Layers

Each layer is independently shippable and valuable.

### Layer 1: Intelligent Bridge
- Rewrite skill with why-drilling, assumption detection, escalation framework
- Update worker prompt generation for structured output expectations
- Add dependency graph construction to decomposition logic
- Estimated scope: skill rewrite (~400 lines), minor script changes

### Layer 2: Context Efficiency
- Add session distillation to bridge workflow
- Implement work-type-aware context strategies in prompt composition
- Add `.fleet/session.md` generation and commit step to worker protocol
- Structured PR description template in worker prompts
- Estimated scope: skill additions, new bridge-side file conventions

### Layer 3: Reactive Coordination
- Implement state-change reaction logic in bridge
- Add conflict detection (diff-reading between workers)
- Formalize checkpoint protocol in worker prompts
- Queue management with dependency-aware dispatch
- Estimated scope: skill additions, `_bridge/graph.json` and `_bridge/queue.json` conventions

### Layer 4: Untether the Director
- Telegram bot setup flow
- Outbound notification composing (event → message)
- Inbound command parsing (message → action)
- Detach/reattach with briefing accumulation
- Escalation routing logic
- `fleet detach` command in script
- Estimated scope: skill additions for Telegram, script additions for detach/attach, `~/.fleet/telegram.json`

### Layer 5: Learning
- Director model: observation, storage, consultation
- Execution patterns: recording, retrieval, application to decomposition
- Codebase knowledge: aggregation from discoveries, maintenance, inclusion in prompts
- `.fleet/knowledge/` structure and update logic
- `~/.fleet/directors/` structure and update logic
- Estimated scope: skill additions, new file conventions

---

## What This Enables

**A solo developer** opens their terminal in the morning, tells Fleet what matters today, and walks away. Fleet decomposes, dispatches, coordinates, and delivers. The developer reviews PRs from their phone between meetings. By end of day, a team's worth of work is done.

**A team** uses Fleet as their shared orchestration layer. Simon's Fleet writes PRs with full context. Asger's Fleet reviews them with that context. The codebase knowledge accumulates across all team members' sessions. New team members' Fleets start with institutional knowledge from day one.

**Any kind of work** -- not just code. Research, content, analysis, documentation, refactoring, bug triage, dependency updates, security audits. If it can be described in natural language and executed in a terminal, Fleet can orchestrate it.

**The step-change:** The developer stops being a code writer and becomes a strategic director. The bottleneck moves from execution to judgment. Fleet is the operating system for that new way of working.
