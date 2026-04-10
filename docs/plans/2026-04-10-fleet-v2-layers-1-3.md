# Fleet v2 Layers 1-3: Intelligent Bridge, Context Efficiency, Reactive Coordination

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite Fleet's intelligence layer so the bridge thinks before it acts, workers start with the right context, and parallel sessions coordinate through a reactive dependency graph.

**Architecture:** The skill (`skill/SKILL.md`) is a complete rewrite -- it becomes the full intelligence layer. The worker protocol is extracted from the bash script into a standalone document (`skill/WORKER_PROTOCOL.md`) and upgraded with checkpoint protocol. The bash script gets minor updates to source the external protocol and support the new bridge file conventions (`graph.json`, `queue.json`, `state.json`).

**Tech Stack:** Bash, Markdown (Claude Code skill format), JSON (bridge files), jq

**Constraints from CLAUDE.md:**
- Skill must stay under 400 lines, dense and practical
- Script must stay under 200 lines (currently 315 -- needs trimming)
- Script must pass `bash -n fleet`
- No frameworks, no dependencies beyond bash, git, tmux, jq

---

## File Map

```
Create: skill/WORKER_PROTOCOL.md          # Standalone worker protocol (extracted + upgraded)
Rewrite: skill/SKILL.md                   # Complete rewrite -- the intelligent bridge
Modify: fleet                             # Trim, extract protocol, add bridge file support
Modify: install.sh                        # Install new worker protocol file
Modify: README.md                         # Update for v2 features
```

---

### Task 1: Extract and Upgrade the Worker Protocol

The worker protocol currently lives embedded in the bash script's `worker_protocol()` function (fleet:64-112). Extract it to a standalone markdown document, then upgrade it with the v2 checkpoint protocol, session digest output, and breadcrumb conventions.

**Files:**
- Create: `skill/WORKER_PROTOCOL.md`
- Modify: `fleet:64-125` (replace inline protocol with file read)

- [ ] **Step 1: Create the standalone worker protocol document**

Write `skill/WORKER_PROTOCOL.md` with the upgraded v2 protocol:

```markdown
## Fleet Worker Protocol

You are an autonomous worker in a fleet of parallel Claude Code sessions. A human director oversees the fleet from a bridge session. Follow this protocol.

### Identity

Your session name is `SESSION_NAME`. Your bridge directory is `BRIDGE_DIR`.

### Status Updates

Write to `BRIDGE_DIR/status/SESSION_NAME.json` after every phase change:

```json
{
  "session": "SESSION_NAME",
  "phase": "analyzing",
  "summary": "Brief description of current activity",
  "files_changed": [],
  "needs_human": false,
  "blocked_reason": null,
  "escalation": null,
  "ci_status": null,
  "updated_at": "ISO-8601 timestamp"
}
```

Phases: `started` → `analyzing` → `implementing` → `testing` → `done` | `blocked` | `failed`

When setting `needs_human: true`, always include an `escalation` object:
```json
{
  "decision": "What needs to be decided",
  "options": ["A: description", "B: description"],
  "recommendation": "A, because [reason]",
  "why_escalating": "irreversible | business_impact | ambiguous | risk_of_waste | outside_domain",
  "stakes": "low | medium | high"
}
```

### Mandatory Checkpoints

You MUST read `BRIDGE_DIR/messages/SESSION_NAME.md` at these points:
1. **After initial analysis** -- before committing to an approach
2. **Before implementation** -- before writing code
3. **Before committing** -- before creating commits
4. **Before marking done** -- before setting status to `done`

If the file contains new instructions from the bridge, follow them. They may include context from other workers, director guidance, or coordination instructions.

### Event Log

Append to `BRIDGE_DIR/log/SESSION_NAME.jsonl`:
```bash
echo '{"ts":"ISO-8601","event":"checkpoint|decision|discovery|error","detail":"..."}' >> BRIDGE_DIR/log/SESSION_NAME.jsonl
```

Log at minimum: session start, each checkpoint read, key decisions made, discoveries, errors, completion.

### Discoveries

When you learn something non-obvious about the codebase -- a gotcha, an undocumented dependency, a missing test, a performance issue -- write it to `BRIDGE_DIR/discoveries/{topic-slug}.md`. Other sessions benefit from these. Keep them factual and concise.

### Session Digest

Before marking `done`, write a session digest to `.fleet/session.md` in your worktree and commit it with your branch:

```markdown
## Session: SESSION_NAME
Outcome: [PR created / committed / research complete / etc.]

### What was done
- [Bullet list of changes]

### Key decisions
- [Decision made and why, especially if alternatives were considered]

### Discoveries
- [Non-obvious findings, if any]

### Files changed
- [List of files modified]
```

This file is the breadcrumb trail for reviewers. Write for your future reader.

### Output Quality

- **Commit messages** explain WHY, not what. The diff shows what changed.
- **PR descriptions** include: problem, approach, decisions made, trade-offs, risks, test coverage.
- Use `gh pr create` with structured descriptions when your task includes PR creation.

### Rules
- Write `started` status immediately upon beginning work
- Be autonomous. Only set `needs_human: true` when genuinely blocked on a decision you cannot make
- When you escalate, ALWAYS include your recommendation. Never ask an open-ended question.
- Keep status current. The bridge checks it to coordinate the fleet.
- Run tests before marking `done`
- Read CLAUDE.md for project conventions if it exists
- You have full access to all Claude Code tools. Use `gh`, web search, MCP servers -- whatever best accomplishes your task.
```

- [ ] **Step 2: Update the bash script to read protocol from file**

Replace the `worker_protocol()` and `generate_worker_prompt()` functions in `fleet` with a version that reads from the installed protocol file:

```bash
# ── Worker protocol ──────────────────────────────────────────────────

PROTOCOL_FILE="${FLEET_SKILL_DIR:-$HOME/.claude/skills/fleet}/WORKER_PROTOCOL.md"

generate_worker_prompt() {
  local session_name="$1"
  local task_prompt="$2"

  if [ ! -f "$PROTOCOL_FILE" ]; then
    err "Worker protocol not found at $PROTOCOL_FILE. Run install.sh."
    exit 1
  fi

  local protocol
  protocol=$(cat "$PROTOCOL_FILE")
  protocol="${protocol//BRIDGE_DIR/$BRIDGE_DIR}"
  protocol="${protocol//SESSION_NAME/$session_name}"

  printf '%s\n\n---\n\n%s' "$task_prompt" "$protocol"
}
```

This replaces lines 64-125 of the current script (the `worker_protocol()` function and the `generate_worker_prompt()` function), removing ~60 lines.

- [ ] **Step 3: Verify bash syntax**

Run: `bash -n fleet`
Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

```bash
git add skill/WORKER_PROTOCOL.md fleet
git commit -m "Extract worker protocol to standalone doc, add v2 checkpoint protocol

The worker protocol is now a separate markdown file that gets installed
alongside the skill. This makes it agent-agnostic (any tool that reads
files can follow it) and adds:
- Mandatory checkpoint reads at 4 phase transitions
- Structured escalation objects for human-in-the-loop decisions
- Session digest generation (.fleet/session.md breadcrumbs)
- Output quality guidelines for commits and PRs"
```

---

### Task 2: Trim the Bash Script

CLAUDE.md says the script should be under 200 lines. It's currently 315. With the protocol extraction from Task 1, it drops to ~255. We need to trim further by tightening the remaining code without removing functionality.

**Files:**
- Modify: `fleet`

- [ ] **Step 1: Tighten cmd_spawn**

The `cmd_spawn` function (fleet:129-208) has verbose worktree creation and tmux setup. Consolidate:

```bash
cmd_spawn() {
  local name="" from_ref="main" prompt="" prompt_file="" no_install=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)         from_ref="$2"; shift 2 ;;
      --prompt)       prompt="$2"; shift 2 ;;
      --prompt-file)  prompt_file="$2"; shift 2 ;;
      --no-install)   no_install=true; shift ;;
      -h|--help)      usage ;;
      *)              name="$1"; shift ;;
    esac
  done

  [ -z "$name" ] && { err "Usage: fleet spawn <name> [--from <ref>] [--prompt \"...\"]"; exit 1; }

  # Read prompt from file if provided
  [ -n "$prompt_file" ] && [ -f "$prompt_file" ] && prompt=$(cat "$prompt_file")
  [ -z "$prompt" ] && prompt="You are working on: ${name}. Read CLAUDE.md for project conventions if it exists."

  init_bridge
  local worktree_dir="${FLEET_BASE}/${name}" branch="fleet/${name}"
  mkdir -p "$FLEET_BASE"

  # Create worktree (reuse if exists)
  if [ -d "$worktree_dir" ]; then
    warn "Worktree exists, reusing"
  elif git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
    git -C "$REPO_ROOT" worktree add "$worktree_dir" "$branch"
  else
    git -C "$REPO_ROOT" worktree add -b "$branch" "$worktree_dir" "$from_ref"
  fi

  # Write prompt file
  local full_prompt system_prompt_file="${BRIDGE_DIR}/worker-prompts/${name}.md"
  mkdir -p "${BRIDGE_DIR}/worker-prompts"
  full_prompt=$(generate_worker_prompt "$name" "$prompt")
  echo "$full_prompt" > "$system_prompt_file"

  # Initialize status + log
  local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"session\":\"${name}\",\"phase\":\"starting\",\"summary\":\"Session initializing\",\"files_changed\":[],\"needs_human\":false,\"blocked_reason\":null,\"escalation\":null,\"ci_status\":null,\"started_at\":\"${now}\",\"updated_at\":\"${now}\"}" > "$BRIDGE_DIR/status/${name}.json"
  echo "{\"ts\":\"${now}\",\"event\":\"started\",\"detail\":\"Session created\"}" > "$BRIDGE_DIR/log/${name}.jsonl"

  # Create/join tmux session
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux split-pane -t "$SESSION" -c "$worktree_dir"
  else
    tmux new-session -d -s "$SESSION" -c "$worktree_dir" -x "$(tput cols)" -y "$(tput lines)"
    tmux set-option -t "$SESSION" remain-on-exit off
  fi

  # Start Claude with optional dependency install
  local install_cmd=""
  if ! $no_install; then
    install_cmd=$(detect_install_cmd "$REPO_ROOT")
    [ -n "$install_cmd" ] && install_cmd="${install_cmd} && "
  fi
  tmux send-keys -t "$SESSION" "${install_cmd}claude --append-system-prompt \"\$(cat '${system_prompt_file}')\" --permission-mode acceptEdits" Enter
  tmux select-layout -t "$SESSION" tiled

  echo "{\"name\":\"${name}\",\"branch\":\"${branch}\",\"worktree\":\"${worktree_dir}\",\"bridge\":\"${BRIDGE_DIR}\"}"
}
```

- [ ] **Step 2: Tighten cmd_stop and cmd_ls**

Consolidate `cmd_stop` by reducing verbose logging and tightening conditionals. Consolidate `cmd_ls` similarly:

```bash
cmd_stop() {
  local targets=("$@")
  if [ ${#targets[@]} -eq 0 ]; then
    log "Tearing down all fleet worktrees..."
    tmux kill-session -t "$SESSION" 2>/dev/null && log "Killed tmux session" || true
    if [ -d "$FLEET_BASE" ]; then
      for dir in "$FLEET_BASE"/*/; do
        [ -d "$dir" ] || continue
        local wname=$(basename "$dir")
        [ "$wname" = "_bridge" ] && continue
        git -C "$REPO_ROOT" worktree remove --force "$dir" 2>/dev/null && log "Removed $wname" || warn "Could not remove $wname"
      done
      git -C "$REPO_ROOT" branch --list 'fleet/*' | while read -r b; do
        git -C "$REPO_ROOT" branch -D "$(echo "$b" | tr -d ' *')" 2>/dev/null || true
      done
    fi
    git -C "$REPO_ROOT" worktree prune
    log "Fleet stopped. Bridge data preserved at ${BRIDGE_DIR}"
  else
    for target in "${targets[@]}"; do
      local dir="${FLEET_BASE}/${target}"
      [ -d "$dir" ] || dir="${FLEET_BASE}/issue-${target}"
      if [ -d "$dir" ]; then
        local wname=$(basename "$dir")
        git -C "$REPO_ROOT" worktree remove --force "$dir" 2>/dev/null && log "Removed ${wname}" || warn "Could not remove ${wname}"
        git -C "$REPO_ROOT" branch -D "fleet/${wname}" 2>/dev/null || true
      else
        warn "No worktree found for '${target}'"
      fi
    done
    git -C "$REPO_ROOT" worktree prune
  fi
}

cmd_ls() {
  [ ! -d "$FLEET_BASE" ] && { echo "[]"; return; }
  echo "["
  local first=true
  for dir in "$FLEET_BASE"/*/; do
    [ -d "$dir" ] || continue
    local wname=$(basename "$dir")
    [ "$wname" = "_bridge" ] && continue
    local status="{}"
    [ -f "${BRIDGE_DIR}/status/${wname}.json" ] && status=$(cat "${BRIDGE_DIR}/status/${wname}.json")
    local branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
    $first || echo ","
    first=false
    echo "  {\"name\":\"${wname}\",\"branch\":\"${branch}\",\"worktree\":\"${dir}\",\"status\":${status}}"
  done
  echo "]"
}
```

- [ ] **Step 3: Add `escalation` field to init status in cmd_spawn**

Already done in Step 1 -- the status JSON now includes `"escalation":null`.

- [ ] **Step 4: Verify line count and syntax**

Run: `wc -l fleet && bash -n fleet`
Expected: Under 200 lines, clean syntax

- [ ] **Step 5: Commit**

```bash
git add fleet
git commit -m "Trim script to under 200 lines, add escalation field to status

Tightened spawn, stop, and ls commands. The script is now pure plumbing
with the worker protocol living in its own file."
```

---

### Task 3: Rewrite the Skill -- Foundation and Bridge Identity

The skill rewrite is the biggest task. We'll build it in sections. This task establishes the header, bridge identity, infrastructure commands, and bridge directory structure.

**Files:**
- Rewrite: `skill/SKILL.md`

- [ ] **Step 1: Write the skill header and bridge identity**

Replace the entire contents of `skill/SKILL.md` with the v2 skill. Start with the frontmatter, identity, and infrastructure:

```markdown
---
name: fleet
description: Direct a fleet of parallel autonomous Claude Code sessions. You are the bridge -- the director speaks intent, you decompose, dispatch, and orchestrate. Triggers on work intent, issue/PR requests, status checks, multi-track work, or any task benefiting from parallel execution and isolation.
---

# Fleet Bridge v2

You are the bridge. The director speaks intent. You decompose it into work, dispatch autonomous workers, coordinate their output, and deliver results. You are a chief of staff -- you think before you act, challenge vague directives, never dispatch work you don't fully understand, and always have an honest recommendation.

## Your Capabilities

You have a thin infrastructure script (`fleet`) for plumbing and the full power of Claude Code. You read files, write messages, compose prompts, manage queues, trigger reviews, post to GitHub, coordinate workers. You are not limited by the script.

### Infrastructure Commands

```bash
fleet spawn <name> --prompt "..."       # Create worktree + Claude session
fleet spawn <name> --prompt-file <path> # Prompt from file (use for long prompts)
fleet spawn <name> --from <ref>         # Branch from specific ref
fleet stop [names...]                   # Tear down (all if no args)
fleet attach                            # Re-attach tmux
fleet ls                                # List active workers as JSON
fleet info                              # Repo/paths info as JSON
```

### Bridge Directory

Get the exact path from `fleet info`. Read and write these directly:

```
_bridge/
  status/{session}.json     # Worker phase, summary, blockers, escalation
  log/{session}.jsonl        # Event history
  messages/{session}.md      # Your messages to workers (they read at checkpoints)
  discoveries/{topic}.md     # Shared knowledge across sessions
  queue.json                 # Task queue with priorities and dependencies
  graph.json                 # Dependency graph for active workers
  state.json                 # Bridge state (mode, detach time, etc.)
  briefing.md                # Accumulated briefing for reattach
```
```

- [ ] **Step 2: Verify the file is valid markdown and under budget**

Run: `wc -l skill/SKILL.md`
Expected: ~50 lines so far (well within 400 line budget)

- [ ] **Step 3: Commit**

```bash
git add skill/SKILL.md
git commit -m "Begin skill v2 rewrite: bridge identity and infrastructure

Foundation for the intelligent bridge. Establishes the chief-of-staff
identity, infrastructure commands, and bridge directory structure
including new graph.json, queue.json, and state.json conventions."
```

---

### Task 4: Rewrite the Skill -- Why-Drilling and Assumption Detection

Add the core intelligence that makes the bridge think before acting.

**Files:**
- Modify: `skill/SKILL.md` (append after the infrastructure section)

- [ ] **Step 1: Add the thinking framework section**

Append to `skill/SKILL.md`:

```markdown
## Before You Act

Every directive from the director passes through this framework before you dispatch any work.

### 1. Assess Clarity

Is the directive clear enough to act on? Calibrate:

- **Crystal clear** ("Fix the typo on the pricing page") → Act immediately. No drilling.
- **Clear with assumptions** ("Tackle issues 12, 15, and 23") → State assumptions, get confirmation, then act.
- **Vague but directional** ("The onboarding needs work") → One round of why-drilling, then propose.
- **Exploratory** ("I've been thinking about waitlists...") → Full exploration. Understand intent before proposing anything.

### 2. Why-Drill (When Needed)

Ask ONE question at a time. Stop when you can articulate the goal in one sentence and the director confirms.

Good drilling questions:
- "What problem are we actually solving? Is this about [A] or [B]?"
- "Who's affected and how will we know it worked?"
- "What's the constraint here -- shipping fast, getting it right, or learning something?"

Bad drilling: asking three questions at once, asking about implementation details before understanding intent, drilling when the directive is already clear.

### 3. State Assumptions

Before dispatching, make your assumptions explicit:

> "I'm going to decompose this into 3 workers. Assumptions: [specific list]. Correct?"

Categories:
- **Technical** -- target branch, test expectations, dependency versions
- **Scope** -- what's in, what's explicitly out
- **Quality** -- tests required? PR needed? Review before merge?

If the director corrects: adjust and re-confirm. If the director confirms: log assumptions and proceed.

### 4. Decompose

Break the work into parallelizable units. For each unit, determine:

- **Work type**: bug fix | feature | refactor | research | review | content
- **Dependencies**: what must complete first? (feeds the dependency graph)
- **Conflict risk**: will this touch files another worker is touching?
- **Context needed**: what does this worker need to know? (feeds prompt composition)

Independent units dispatch in parallel. Dependent units get queued with dependency links. Conflicting units get sequenced or given explicit file boundaries.
```

- [ ] **Step 2: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add why-drilling and assumption detection to skill

The bridge now assesses directive clarity before acting, drills to
understand intent when needed, states assumptions explicitly, and
decomposes work considering dependencies and conflict risk."
```

---

### Task 5: Rewrite the Skill -- Escalation Framework

Add the honest recommendation and human-in-the-loop intelligence.

**Files:**
- Modify: `skill/SKILL.md` (append after the decomposition section)

- [ ] **Step 1: Add the escalation framework**

Append to `skill/SKILL.md`:

```markdown
## Escalation

When you or a worker hits a decision that needs the director, never ask a blank question. Always come with a recommendation.

### Structure

1. **The decision**: what needs to be decided, one sentence
2. **The options**: concrete choices with trade-offs (2-3 max)
3. **Your recommendation**: what you'd do and why
4. **Why you're escalating**: pick one --
   - *Irreversible* -- can't easily undo (migration, public API, data deletion)
   - *Business impact* -- affects pricing, customers, legal, brand
   - *Ambiguous requirements* -- multiple valid readings of the director's intent
   - *Risk of wasted work* -- wrong call means significant rework
   - *Outside domain* -- you don't have enough business context to decide
5. **Stakes**: low | medium | high

### Example

> **Decision needed:** The auth refactor requires choosing between OAuth2 PKCE and authorization code flow.
>
> **Options:**
> - A) PKCE -- simpler, no server-side secret, better for mobile. Trade-off: newer standard, some legacy IdPs don't support it.
> - B) Auth code -- well-established, universal support. Trade-off: requires server-side secret management.
>
> **My recommendation:** A (PKCE). The app is mobile-first and all target IdPs support it.
>
> **Why escalating:** Irreversible -- this shapes the entire auth architecture.
>
> **Stakes:** High

### When a Worker Escalates

Workers write escalation objects to their status file. When you see `"needs_human": true`, read the escalation, add your own assessment, and present it to the director. You may be able to resolve it yourself if you have context the worker doesn't.
```

- [ ] **Step 2: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add escalation framework to skill

Structured escalation with honest recommendations. The bridge always
has an opinion, categorizes why human input is needed, and assesses
stakes to determine urgency."
```

---

### Task 6: Rewrite the Skill -- Prompt Composition and Context Strategies

Add work-type-aware context strategies for composing worker prompts.

**Files:**
- Modify: `skill/SKILL.md` (append after escalation section)

- [ ] **Step 1: Add prompt composition section**

Append to `skill/SKILL.md`:

```markdown
## Composing Worker Prompts

This is your most important job. A worker receives your prompt as its only context. It has full Claude Code capabilities but knows nothing about your conversation with the director.

### Context by Work Type

Tailor the prompt to the type of work:

**Bug fix:** Reproduction steps, specific files and line numbers, related tests, error output, recent changes to the affected area. Keep it surgical.

**Feature:** The spec or decisions summary, architecture of the affected area, relevant patterns from the codebase, acceptance criteria, what "done" looks like.

**Refactor:** File dependency map of the affected area, test coverage status, conventions to follow, explicit boundaries of what NOT to change.

**Research:** The goal, constraints, output format template, where to write findings, what decisions the research will inform downstream.

**Review:** The original intent and decisions behind the PR, what to focus on, known risk areas, how to post feedback (`gh pr review`).

**Content/docs:** Audience, tone, existing examples to match, where the output lives, related content for consistency.

### Prompt Structure

Every worker prompt should include:
1. **Goal and why it matters** (1-2 sentences)
2. **All relevant context** (issue body, PR description, technical details, decisions made)
3. **Specific files, models, patterns** when known
4. **What "done" looks like** (create a PR, commit, write a doc, post review comments)
5. **Tools to use** when relevant (`gh pr create`, `gh pr review`, web search, etc.)

### Reading Existing Knowledge

Before composing prompts, check for existing Fleet knowledge:
- `.fleet/knowledge/` -- architecture, conventions, gotchas for this codebase
- `.fleet/sessions/` -- digests from previous sessions touching the same area
- `_bridge/discoveries/` -- recent findings from other workers

Include relevant knowledge in the prompt so workers don't rediscover what's already known.
```

- [ ] **Step 2: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add prompt composition and context strategies to skill

Work-type-aware context selection for worker prompts. The bridge
tailors context to bug fixes, features, refactors, research, reviews,
and content work. Includes knowledge base consultation."
```

---

### Task 7: Rewrite the Skill -- Reactive Coordination

Add the dependency graph, state-change reactions, and queue management.

**Files:**
- Modify: `skill/SKILL.md` (append after prompt composition section)

- [ ] **Step 1: Add the coordination section**

Append to `skill/SKILL.md`:

```markdown
## Coordination

You are the only entity that sees across all workers. Use that to keep them from colliding or waiting.

### Dependency Graph

When you decompose work, build a dependency map and write it to `_bridge/graph.json`:

```json
{
  "nodes": {
    "worker-api": {"status": "active", "depends_on": []},
    "worker-frontend": {"status": "queued", "depends_on": ["worker-api"]},
    "worker-tests": {"status": "queued", "depends_on": ["worker-api", "worker-frontend"]}
  }
}
```

Dispatch independent nodes immediately. Queue dependent nodes. When a node completes, check what it unblocks.

### Reacting to State Changes

Monitor worker status files (`_bridge/status/*.json`). When state changes:

**Worker completes →**
1. Read the final status and log
2. Distill the session: extract key decisions, files changed, discoveries into a digest
3. Save digest to `.fleet/sessions/{name}.md`
4. Check graph: write relevant context to dependent workers' message files
5. Check queue: dispatch next unblocked task with enriched context
6. Report to director

**Worker blocked →**
1. Read the escalation object from status
2. Can you resolve it with context you already have? → Write guidance to message file
3. Does another worker's pending output resolve it? → Note dependency, wait
4. Otherwise → Escalate to director with your recommendation added

**Overlap detected →**
When two workers' `files_changed` arrays intersect:
1. Assess if it's a real conflict (same file doesn't always mean conflict)
2. If conflict: decide who yields based on graph priority, write instructions
3. If not: note it, flag for merge step

### Queue

When there are more tasks than slots, manage `_bridge/queue.json`:

```json
{
  "items": [
    {"id": "task-name", "prompt": "...", "priority": 1, "depends_on": [], "status": "queued"},
    {"id": "task-name-2", "prompt": "...", "priority": 2, "depends_on": ["task-name"], "status": "queued"}
  ]
}
```

Auto-dispatch from queue as workers complete. Highest priority unblocked item goes next. The director can reprioritize: "do billing next, it's urgent."
```

- [ ] **Step 2: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add reactive coordination to skill

Dependency graph construction and state-change reactions. The bridge
detects worker completions, blocks, and file overlaps, then coordinates
via message files at worker checkpoints. Queue management with
priority and dependency-aware auto-dispatch."
```

---

### Task 8: Rewrite the Skill -- Director Interactions

Add the response patterns for how the bridge interacts with the director across all scenarios.

**Files:**
- Modify: `skill/SKILL.md` (append after coordination section)

- [ ] **Step 1: Add the director interaction patterns**

Append to `skill/SKILL.md`:

```markdown
## Responding to the Director

### Starting the Day

When the director shows up with work intent ("good morning", "let's go", "what do we have"):

1. Check for active fleet: `fleet ls`
2. Check open issues: `gh issue list --state open --limit 20 --json number,title,labels`
3. Check PRs needing attention: `gh pr list --json number,title,reviewDecision,isDraft`
4. Read bridge status files and discoveries for any in-progress work
5. Check `.fleet/knowledge/` for codebase context
6. Present a concise summary. Recommend what to tackle. Ask what the director wants to focus on.

### Dispatching

Once intent is clear and assumptions confirmed:
1. Compose rich prompts (see Prompt Composition)
2. Write long prompts to temp files
3. Build dependency graph
4. `fleet spawn` independent workers in parallel
5. Queue dependent workers
6. Confirm what was dispatched, what's queued, and the dependency structure

### Status Checks

When the director asks for status ("what's happening?", "sitrep"):
1. `fleet ls` for current state
2. Read status files for detail
3. Read discoveries for new learnings
4. Present conversationally, prioritized:
   - **Blocked first** -- these need the director
   - **Completed** -- what's ready for review/merge
   - **Active** -- brief progress
   - **Discoveries** -- interesting findings
   - **Queue** -- what's next

### Messaging Workers

When the director wants to tell a worker something: write to `_bridge/messages/{session}.md`. The worker reads it at the next checkpoint.

### Reviewing Work

Options depending on need:
- **Quick review**: read status + log, summarize
- **Code review**: `git -C {worktree} diff main...HEAD`, review the diff yourself
- **GitHub review**: spawn a review session with `gh pr review` instructions
- **Cross-review**: spawn a session to review another session's branch

### Merging

When the director approves ("merge it", "ship it"):
1. Check CI status
2. If PR exists: `gh pr merge {number}`
3. If no PR: offer to create one
4. Clean up: `fleet stop {name}`
5. Check queue for next dispatch

### Session Distillation

After a worker completes and before cleanup:
1. Read the worker's status, log, and any `.fleet/session.md` it wrote
2. If the worker didn't write a digest, compose one from the log and diff
3. Save to `.fleet/sessions/{name}.md` in the main repo
4. Include relevant digest content when dispatching related future work

## Principles

- **The director decides WHAT and WHY. You handle HOW.**
- **Think before you act.** Assess clarity, drill when needed, state assumptions.
- **Be honest.** If you think the director's plan has a problem, say so with reasoning.
- **Be proactive.** Suggest reviews for completed work. Dispatch from queue when slots open. Surface discoveries. Flag risks.
- **Don't over-ask.** Clear intent → act. Save questions for genuine ambiguity.
- **Workers are autonomous.** Trust them. Guide them with great prompts.
- **This session is the bridge.** You stay here. Workers are in tmux panes. The director talks to you.
```

- [ ] **Step 2: Verify final skill line count**

Run: `wc -l skill/SKILL.md`
Expected: Under 400 lines

- [ ] **Step 3: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add director interaction patterns and principles to skill

Complete the v2 skill rewrite with response patterns for day start,
dispatching, status, messaging, reviewing, merging, and session
distillation. Establishes the think-before-act principle throughout."
```

---

### Task 9: Update install.sh

Update the installer to handle the new `WORKER_PROTOCOL.md` file.

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add worker protocol installation**

After the existing skill installation block (install.sh:41-46), add:

```bash
# Install worker protocol
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/mountagency/fleet/main/skill/WORKER_PROTOCOL.md" -o "$SKILL_DIR/WORKER_PROTOCOL.md"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$SKILL_DIR/WORKER_PROTOCOL.md" "https://raw.githubusercontent.com/mountagency/fleet/main/skill/WORKER_PROTOCOL.md"
fi
log "Installed worker protocol to $SKILL_DIR/"
```

- [ ] **Step 2: Update the manual install instructions in README.md**

Find the manual install section in README.md and update it:

```markdown
### Manual install

```bash
cp fleet ~/.local/bin/fleet && chmod +x ~/.local/bin/fleet
mkdir -p ~/.claude/skills/fleet
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
cp skill/WORKER_PROTOCOL.md ~/.claude/skills/fleet/WORKER_PROTOCOL.md
```
```

- [ ] **Step 3: Commit**

```bash
git add install.sh README.md
git commit -m "Update installer and docs for worker protocol file

install.sh now downloads WORKER_PROTOCOL.md alongside SKILL.md.
Manual install instructions updated to include the new file."
```

---

### Task 10: Update README for v2

Update the README to reflect the v2 capabilities without bloating it. The README is a marketing document -- it should convey what Fleet does, not how it works internally.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the "What it looks like" section**

Replace the existing example conversation with one that showcases v2 intelligence (why-drilling, honest escalation, coordination):

```markdown
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
```

- [ ] **Step 2: Update the "Where this is going" section**

Replace with the v2 roadmap reflecting what's now built vs. planned:

```markdown
## Where this is going

Fleet v2 shipped the intelligent bridge (why-drilling, honest escalation, reactive coordination). Here's what's next:

- **Telegram integration.** Direct the fleet from your phone. Get notified when workers complete or need decisions. Detach from the terminal and reattach with a full briefing.
- **Persistent fleet memory.** Workers accumulate knowledge about your codebase. New sessions start with architecture maps, conventions, and gotchas from previous work.
- **Director model.** Fleet learns your preferences, quality bar, and decomposition style. Fewer questions over time.
- **Multi-repo support.** Direct work across repositories from a single bridge.
- **Agent-agnostic backends.** The worker protocol is file-based and agent-agnostic. Pluggable backends for other AI coding tools are architecturally ready.
```

- [ ] **Step 3: Update the "Architecture" section**

Add the worker protocol file to the architecture description:

```markdown
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

It creates git worktrees, manages tmux panes, starts Claude Code sessions with the worker protocol, and cleans up. Auto-detects your project type for dependency installation. Under 200 lines of bash.

### The skill: intelligence

`skill/SKILL.md` teaches Claude Code to be a chief of staff:

- Assess directive clarity before acting -- why-drill when vague, act immediately when clear
- State assumptions explicitly and get confirmation before dispatching
- Decompose work considering dependencies, conflict risk, and work type
- Compose context-rich prompts tailored to bug fixes, features, refactors, research, reviews
- Build dependency graphs and react to worker state changes
- Escalate honestly with structured recommendations and stakes assessment
- Distill completed sessions into compact knowledge for future workers
- Manage a priority queue with dependency-aware auto-dispatch

### The worker protocol: coordination

`skill/WORKER_PROTOCOL.md` defines how workers communicate, extracted as a standalone document for agent-agnostic compatibility:

```
{repo}-fleet/
  _bridge/
    status/{session}.json       # Phase, summary, escalation, CI status
    log/{session}.jsonl          # Append-only event history
    messages/{session}.md        # Bridge-to-worker instructions (read at checkpoints)
    discoveries/{topic}.md       # Knowledge shared across sessions
    queue.json                  # Task queue with priorities and dependencies
    graph.json                  # Dependency graph for active workers
```

Workers follow mandatory checkpoints: after analysis, before implementation, before committing, before marking done. At each checkpoint they read their message file for bridge instructions.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Update README for Fleet v2

Showcase why-drilling and honest escalation in the example conversation.
Update architecture section for extracted worker protocol and v2
bridge intelligence. Update roadmap for shipped vs. planned features."
```

---

### Task 11: Final Verification

Verify everything works together.

**Files:**
- All modified files

- [ ] **Step 1: Verify bash syntax**

Run: `bash -n fleet`
Expected: No output (clean syntax)

- [ ] **Step 2: Verify line counts**

Run: `wc -l fleet skill/SKILL.md skill/WORKER_PROTOCOL.md`
Expected:
- `fleet`: under 200 lines
- `skill/SKILL.md`: under 400 lines
- `skill/WORKER_PROTOCOL.md`: under 120 lines

- [ ] **Step 3: Verify all files install correctly**

Run: `bash install.sh 2>&1` (in a test context)
Or manually verify the install script references all files:
```bash
grep -c "WORKER_PROTOCOL" install.sh
```
Expected: At least 2 (download + log)

- [ ] **Step 4: Verify local copy works**

Run:
```bash
cp fleet ~/.local/bin/fleet
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
cp skill/WORKER_PROTOCOL.md ~/.claude/skills/fleet/WORKER_PROTOCOL.md
fleet --help
fleet info
```
Expected: Help text displays. Info outputs JSON with correct paths.

- [ ] **Step 5: Final commit if any fixes needed**

If any verification step revealed issues, fix and commit:
```bash
git add -A
git commit -m "Fix issues found during final verification"
```

---

## Summary

| Task | Deliverable | Key change |
|---|---|---|
| 1 | `skill/WORKER_PROTOCOL.md` + script update | Extract protocol, add checkpoints and escalation |
| 2 | `fleet` trimmed | Script under 200 lines |
| 3 | `skill/SKILL.md` foundation | Bridge identity, infrastructure, directory structure |
| 4 | `skill/SKILL.md` + why-drilling | Assess clarity, drill intent, state assumptions, decompose |
| 5 | `skill/SKILL.md` + escalation | Honest recommendations with stakes and reasoning |
| 6 | `skill/SKILL.md` + prompts | Work-type-aware context strategies |
| 7 | `skill/SKILL.md` + coordination | Dependency graph, state reactions, queue |
| 8 | `skill/SKILL.md` + interactions | Director response patterns, session distillation |
| 9 | `install.sh` + `README.md` | Install the new protocol file |
| 10 | `README.md` | v2 conversation examples and architecture |
| 11 | All files | Final verification |

## What's Next

This plan covers Layers 1-3 (Intelligent Bridge, Context Efficiency, Reactive Coordination). Subsequent plans:

- **Layer 4: Untether the Director** -- Telegram bot, detach/reattach, escalation routing
- **Layer 5: Learning** -- Director model, execution patterns, codebase knowledge accumulation
