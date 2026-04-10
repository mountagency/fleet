# Fleet v2 Layer 5: Learning

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Fleet compound over time -- the bridge learns the director's style, records what works in this codebase, and accumulates institutional knowledge so session 50 is dramatically better than session 1.

**Architecture:** Three knowledge stores, each with a different scope: (1) Director model (`~/.fleet/directors/{username}.md`) -- per-user, local, learns preferences and style; (2) Execution patterns (`.fleet/knowledge/patterns.md`) -- per-repo, committed, records what orchestration strategies work; (3) Codebase knowledge (`.fleet/knowledge/architecture.md`, `conventions.md`, `gotchas.md`) -- per-repo, committed, institutional knowledge from worker discoveries. The skill gets a new "Learning" section teaching the bridge when to observe, record, and consult each store. No bash script changes.

**Tech Stack:** Markdown files, skill instructions

**Constraints:**
- Skill is at 368 lines with a 400-line budget -- only ~30 lines available for the Learning section
- `.fleet/` directory is committed to repos where Fleet is used (not the Fleet repo itself)
- `~/.fleet/directors/` is local, never committed
- No new dependencies

---

## File Map

```
Create: .fleet/knowledge/architecture.md    # Template: codebase architecture map
Create: .fleet/knowledge/conventions.md     # Template: patterns and rules
Create: .fleet/knowledge/gotchas.md         # Template: known pitfalls
Create: .fleet/knowledge/patterns.md        # Template: execution patterns (what works/doesn't)
Modify: skill/SKILL.md:358-368             # Add Learning section before Principles
Modify: skill/WORKER_PROTOCOL.md           # Add knowledge contribution instructions
Modify: README.md                           # Document learning features
```

---

### Task 1: Create Knowledge Base Templates

Create the `.fleet/knowledge/` directory with template files that teach the bridge (and future developers) what each file is for and how to maintain it.

**Files:**
- Create: `.fleet/knowledge/architecture.md`
- Create: `.fleet/knowledge/conventions.md`
- Create: `.fleet/knowledge/gotchas.md`
- Create: `.fleet/knowledge/patterns.md`

- [ ] **Step 1: Create architecture.md**

```markdown
# Architecture

> This file is maintained by Fleet. It captures the system's structure as discovered by workers.
> The bridge reads this before composing worker prompts so they start with architectural context.

<!-- Fleet will populate this as workers explore the codebase. -->
<!-- Format: describe components, their responsibilities, and how they connect. -->
```

Write to `.fleet/knowledge/architecture.md`.

- [ ] **Step 2: Create conventions.md**

```markdown
# Conventions

> This file is maintained by Fleet. It captures patterns and rules discovered in the codebase.
> The bridge includes relevant conventions in worker prompts so they follow established patterns.

<!-- Fleet will populate this as workers discover coding patterns. -->
<!-- Format: state the convention and where it applies. -->
```

Write to `.fleet/knowledge/conventions.md`.

- [ ] **Step 3: Create gotchas.md**

```markdown
# Gotchas

> This file is maintained by Fleet. It captures known pitfalls discovered by workers.
> The bridge warns workers about relevant gotchas before they start work in affected areas.

<!-- Fleet will populate this as workers discover pitfalls. -->
<!-- Format: state the gotcha, what triggers it, and how to avoid it. -->
```

Write to `.fleet/knowledge/gotchas.md`.

- [ ] **Step 4: Create patterns.md**

```markdown
# Execution Patterns

> This file is maintained by Fleet. It records what orchestration strategies work (and don't) for this codebase.
> The bridge consults this during decomposition to avoid repeating mistakes and reuse successful approaches.

<!-- Fleet will populate this after sessions complete. -->
<!-- Format: state the pattern, when it applies, and why it works/fails. -->
```

Write to `.fleet/knowledge/patterns.md`.

- [ ] **Step 5: Commit**

```bash
git add .fleet/knowledge/
git commit -m "Add .fleet/knowledge/ templates for persistent learning

Four knowledge files that Fleet maintains over time:
- architecture.md: system structure map
- conventions.md: codebase patterns and rules
- gotchas.md: known pitfalls
- patterns.md: what orchestration strategies work/don't

Committed to the repo so all team members' Fleets benefit."
```

---

### Task 2: Add Learning Section to the Skill

Add a "Learning" section to the skill that teaches the bridge when and how to observe, record, and consult all three knowledge stores. Must fit in ~30 lines.

**Files:**
- Modify: `skill/SKILL.md` (insert before `## Principles`, currently at line 360)

- [ ] **Step 1: Add the Learning section**

Insert before the `## Principles` section in `skill/SKILL.md`:

```markdown
## Learning

Fleet gets smarter over time. You maintain three knowledge stores -- consult them before acting, update them after sessions.

### Director Model (`~/.fleet/directors/{username}.md`)

**Read** before why-drilling, escalation routing, and composing briefings. The director's defaults may make some questions unnecessary.

**Update** when you observe:
- Corrections ("no, split that into two workers") → record the preference
- Confirmations ("perfect") → record the validated approach
- Patterns (always asks about test coverage before merging) → record for proactive inclusion

Format: simple markdown with sections for decomposition style, quality expectations, communication preferences, domain priorities.

### Execution Patterns (`.fleet/knowledge/patterns.md`)

**Read** before decomposition. Past conflicts, slow areas, and successful strategies inform how you split work.

**Update** after session distillation when you notice: conflicts between workers, tasks that took unexpectedly long, approaches that worked well, or decomposition strategies that failed.

### Codebase Knowledge (`.fleet/knowledge/`)

**Read** before composing worker prompts. Include relevant architecture, conventions, and gotchas so workers don't rediscover known information.

**Update** by incorporating durable discoveries from `_bridge/discoveries/` into the appropriate knowledge file (architecture, conventions, or gotchas). One-off findings stay as discoveries; recurring patterns get promoted to knowledge.
```

- [ ] **Step 2: Verify line count**

Run: `wc -l skill/SKILL.md`
Expected: Under 400 lines (~368 + 28 = ~396)

- [ ] **Step 3: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add Learning section to skill: director model, patterns, codebase knowledge

Teaches the bridge to maintain three knowledge stores:
- Director model (~/.fleet/directors/) for preferences and style
- Execution patterns (.fleet/knowledge/patterns.md) for what works
- Codebase knowledge (.fleet/knowledge/) for institutional memory

Read before acting, update after sessions."
```

---

### Task 3: Update Worker Protocol for Knowledge Contribution

Add a brief section to the worker protocol instructing workers to contribute to the knowledge base when they discover durable patterns.

**Files:**
- Modify: `skill/WORKER_PROTOCOL.md`

- [ ] **Step 1: Add knowledge contribution to the Discoveries section**

In `skill/WORKER_PROTOCOL.md`, find the Discoveries section (around line 69-70) and expand it:

Replace:
```markdown
### Discoveries

When you learn something non-obvious about the codebase -- a gotcha, an undocumented dependency, a missing test, a performance issue -- write it to `BRIDGE_DIR/discoveries/{topic-slug}.md`. Other sessions benefit from these. Keep them factual and concise.
```

With:
```markdown
### Discoveries and Knowledge

When you learn something non-obvious about the codebase -- a gotcha, an undocumented dependency, a missing test, a performance issue -- write it to `BRIDGE_DIR/discoveries/{topic-slug}.md`. Other sessions benefit from these. Keep them factual and concise.

If you discover something durable (an architectural pattern, a convention, a recurring pitfall), also check `.fleet/knowledge/` in your worktree. If the finding belongs in `architecture.md`, `conventions.md`, or `gotchas.md`, append it there and commit it with your branch. The bridge will review and incorporate it.
```

- [ ] **Step 2: Commit**

```bash
git add skill/WORKER_PROTOCOL.md
git commit -m "Update worker protocol: workers contribute to .fleet/knowledge/

Workers now check if their discoveries are durable patterns that
belong in the persistent knowledge base, and append them directly."
```

---

### Task 4: Create Director Model Template

Create the directory structure and a template for the director model. This is local (not committed to repos).

**Files:**
- Modify: `fleet` (add `~/.fleet/directors/` creation to init if needed)

- [ ] **Step 1: Update skill to include director model initialization**

The skill already references `~/.fleet/directors/{username}.md`. The bridge will create this file when it first observes director preferences. No script change needed -- the skill instruction is sufficient.

However, we should document the format. Add a note to the skill's Learning section. Find the director model subsection and after "Format: simple markdown with sections for decomposition style, quality expectations, communication preferences, domain priorities." add an example:

After the line about "Format: simple markdown..." in the Learning section, this is already covered. Instead, let's create the directory in the fleet script's `init_bridge` function to ensure it exists.

In `fleet`, update the `init_bridge` function:

Replace:
```bash
init_bridge() { mkdir -p "$BRIDGE_DIR"/{status,log,messages,discoveries,worker-prompts}; }
```

With:
```bash
init_bridge() { mkdir -p "$BRIDGE_DIR"/{status,log,messages,discoveries,worker-prompts} "$HOME/.fleet/directors"; }
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n fleet`
Expected: Clean

- [ ] **Step 3: Commit**

```bash
git add fleet
git commit -m "Ensure ~/.fleet/directors/ exists on bridge init

The director model directory is created alongside the bridge
directory so the skill can write preferences immediately."
```

---

### Task 5: Update the Existing "Reading Existing Knowledge" Section

The skill already has a "Reading Existing Knowledge" subsection (lines 145-153) that lists the knowledge sources. Update it to include the director model and be more specific about how to use each source.

**Files:**
- Modify: `skill/SKILL.md`

- [ ] **Step 1: Update the Reading Existing Knowledge section**

Replace the current section (skill/SKILL.md, around lines 145-153):

```markdown
### Reading Existing Knowledge

Before composing prompts, check for prior context:
- `.fleet/knowledge/` -- persistent project knowledge
- `.fleet/sessions/` -- digests from past worker sessions
- `_bridge/discoveries/` -- findings from current fleet
- `_bridge/status/` -- what workers have learned so far

Weave relevant findings into new worker prompts.
```

With:

```markdown
### Reading Existing Knowledge

Before composing prompts, consult prior context:
- `.fleet/knowledge/architecture.md` -- system structure, component relationships
- `.fleet/knowledge/conventions.md` -- coding patterns to follow
- `.fleet/knowledge/gotchas.md` -- pitfalls to warn workers about
- `.fleet/knowledge/patterns.md` -- orchestration strategies (consult during decomposition)
- `.fleet/sessions/` -- digests from past worker sessions touching the same area
- `_bridge/discoveries/` -- findings from current fleet workers
- `~/.fleet/directors/{username}.md` -- director preferences (consult before why-drilling and escalation)

Include relevant knowledge in worker prompts. Don't include everything -- match knowledge to the work type and affected area.
```

- [ ] **Step 2: Verify line count**

Run: `wc -l skill/SKILL.md`
Expected: Under 400 lines (adding ~4 net lines)

- [ ] **Step 3: Commit**

```bash
git add skill/SKILL.md
git commit -m "Update knowledge source list with specific files and director model

The Reading Existing Knowledge section now lists each .fleet/knowledge
file by name with its purpose, plus the director model path."
```

---

### Task 6: Update README

Add a section about Fleet's learning capabilities.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a "Fleet learns" section**

Find the `## Where this is going` section in README.md. Before it, add:

```markdown
## Fleet learns

Fleet gets smarter the more you use it. Three types of knowledge accumulate:

**Codebase knowledge** (`.fleet/knowledge/`) -- committed to your repo. As workers explore the codebase, Fleet records architecture, conventions, and gotchas. New workers start with institutional knowledge instead of cold-reading the repo.

**Execution patterns** (`.fleet/knowledge/patterns.md`) -- committed to your repo. Fleet records what orchestration strategies work: which tasks parallelize safely, where conflicts happen, what takes longer than expected. Decomposition improves over time.

**Director model** (`~/.fleet/directors/`) -- local to your machine. Fleet learns your preferences: how you decompose problems, your quality bar, your communication style. Fewer clarifying questions over time.

All knowledge is plain markdown. No database, no service. Read it, edit it, delete it. It's your data.
```

- [ ] **Step 2: Update the "Where this is going" section**

In the roadmap, the "Persistent fleet memory" and "Director model" bullets are now shipped. Update them:

Replace the lines about persistent fleet memory and director model with:
```markdown
- **~~Persistent fleet memory.~~** Shipped. Workers accumulate knowledge in `.fleet/knowledge/`.
- **~~Director model.~~** Shipped. Fleet learns preferences in `~/.fleet/directors/`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add Fleet learning documentation to README

Documents the three knowledge stores: codebase knowledge, execution
patterns, and director model. Updates roadmap to mark these as shipped."
```

---

### Task 7: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Verify bash syntax**

Run: `bash -n fleet`
Expected: Clean

- [ ] **Step 2: Verify line counts**

Run: `wc -l fleet skill/SKILL.md skill/WORKER_PROTOCOL.md`
Expected:
- `fleet`: ~243 lines (one line added to init_bridge)
- `skill/SKILL.md`: under 400 lines
- `skill/WORKER_PROTOCOL.md`: ~113 lines

- [ ] **Step 3: Verify .fleet/knowledge/ files exist**

Run: `ls -la .fleet/knowledge/`
Expected: architecture.md, conventions.md, gotchas.md, patterns.md

- [ ] **Step 4: Local install test**

Run:
```bash
cp fleet ~/.local/bin/fleet
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
cp skill/WORKER_PROTOCOL.md ~/.claude/skills/fleet/WORKER_PROTOCOL.md
fleet info
```
Expected: Valid JSON output

- [ ] **Step 5: Commit if any fixes needed**

```bash
git add -A
git commit -m "Fix issues found during Layer 5 verification"
```

---

## Summary

| Task | Deliverable | Key change |
|---|---|---|
| 1 | `.fleet/knowledge/` templates | Architecture, conventions, gotchas, patterns files |
| 2 | `skill/SKILL.md` Learning section | When to observe, record, and consult each knowledge store |
| 3 | `skill/WORKER_PROTOCOL.md` update | Workers contribute durable discoveries to knowledge base |
| 4 | `fleet` init update | Ensure `~/.fleet/directors/` exists |
| 5 | `skill/SKILL.md` knowledge sources | Expanded list with specific files and director model |
| 6 | `README.md` | Document learning features, update roadmap |
| 7 | All files | Final verification |

## What This Completes

Layer 5 is the final layer. With this, Fleet v2 is feature-complete:

1. **Intelligent Bridge** -- why-drilling, assumption detection, honest escalation
2. **Context Efficiency** -- session distillation, work-type-aware prompts, breadcrumbs
3. **Reactive Coordination** -- dependency graph, state-change reactions, queue management
4. **Untether the Director** -- Telegram, detach/reattach, escalation routing
5. **Learning** -- director model, execution patterns, codebase knowledge
