# Fleet Recipes: Reusable Workflow Orchestration

**Date:** 2026-04-10
**Status:** Research / Design proposal
**Author:** Claude (research-recipes session)

## The Problem

Fleet today is conversational. The director says "fix the checkout bug" and the bridge decomposes on the fly. This is powerful for novel work but wasteful for recurring workflows. Every Monday morning standup briefing, every release prep, every PR review follows the same pattern -- and the bridge rediscovers the pattern each time.

Recipes solve this: named, parameterized, composable workflow definitions that encode proven orchestration patterns. The bridge can invoke them directly or the director can trigger them by name.

Think of it as the difference between explaining how to make coffee every morning vs. having a recipe card. Fleet's intelligence still drives each step -- recipes define the *what* and *structure*, not the implementation details.

## Design Decisions

### Format: Markdown with YAML frontmatter

Not pure YAML. Not code. Markdown.

**Why:** Fleet's entire philosophy is plain text files that humans can read and edit. The skill is markdown. The worker protocol is markdown. Knowledge files are markdown. Recipes should be too.

The frontmatter carries structured metadata (parameters, dependencies, outputs). The body carries the human-readable step definitions that become worker prompts. This mirrors how the skill already works -- structured behavior described in natural language.

```markdown
---
name: review-pr
description: Comprehensive PR review with code, security, and test coverage analysis
params:
  pr: { required: true, description: "PR number" }
  focus: { default: "all", description: "Review focus: all | security | performance" }
steps:
  - id: code-review
  - id: security-audit
  - id: coverage-check
outputs:
  - reviews posted to PR as GitHub comments
---
```

**Why not YAML?** Pure YAML loses the natural language prompts that make Fleet work. You'd end up with `prompt: |` blocks everywhere, which is just worse markdown.

**Why not code (like Dagger)?** Fleet workers are AI agents, not containers. The value of a recipe is that anyone can read and modify it. A TypeScript recipe definition adds a build step, a type system, and a barrier to entry -- all for orchestrating natural language prompts.

### Location: `.fleet/recipes/`

Recipes live in the repo, committed alongside the code. This means:

- They version with the codebase (a recipe that references `OrderService` stays valid as long as the service exists)
- They're discoverable by the bridge (just glob `.fleet/recipes/*.md`)
- They're shareable via git (fork a repo, get its recipes)
- They benefit from Fleet's knowledge system (recipes can reference `.fleet/knowledge/` context)

**Directory structure:**

```
.fleet/
  recipes/
    review-pr.md
    prepare-release.md
    onboard-codebase.md
    morning-standup.md
    investigate-incident.md
  knowledge/
    architecture.md
    conventions.md
    ...
```

### Composition Model: Steps with dependency edges

Each recipe defines steps. Steps are the unit of work -- each becomes a Fleet worker. Steps declare dependencies on other steps, forming a DAG that the bridge resolves at execution time.

```yaml
steps:
  - id: analyze
  - id: fix
    needs: [analyze]
  - id: test
    needs: [fix]
```

Steps with no unmet dependencies run in parallel. This maps directly to Fleet's existing model: `fleet spawn` for independent steps, queue dependent ones, dispatch when predecessors complete. No new infrastructure needed.

**Three composition patterns:**

1. **Parallel**: Steps with no dependencies run simultaneously
2. **Sequential**: Steps with `needs:` wait for predecessors
3. **Fan-in (synthesize)**: A step that `needs:` multiple predecessors, receiving all their outputs

These three cover every real workflow. Conditional branching is deliberately excluded -- it adds complexity that Fleet's conversational intelligence handles better. If a recipe needs branching ("if security issues found, spawn a fixer"), the bridge decides that at runtime based on step outputs, not based on static recipe logic.

### Parameterization: Frontmatter params with `{param}` interpolation

Parameters are declared in frontmatter and interpolated in step prompts with `{param}` syntax. Simple, readable, no `${{ }}` noise.

```yaml
params:
  pr: { required: true, description: "PR number" }
  base: { default: "main", description: "Base branch to compare against" }
```

Referenced in step body:

```markdown
## code-review

Review PR #{pr} against `{base}`. Focus on...
```

**Types are implicit.** Parameters are strings. Fleet workers operate on natural language -- typing a parameter as `integer` adds validation complexity for zero benefit when the consumer is an AI agent that understands "PR #42" regardless of type.

**Special parameters:**

- `{repo}` -- current repository name (auto-injected)
- `{branch}` -- current branch (auto-injected)
- `{date}` -- current date (auto-injected)
- `{knowledge.*}` -- reference to `.fleet/knowledge/` files (e.g., `{knowledge.architecture}` injects the architecture doc)

### Step Definition: Markdown sections as worker prompts

Each step is a markdown section in the recipe body. The section heading is the step ID. The section body becomes the worker prompt.

This is the key insight: **recipe steps are worker prompts, not commands.** Fleet workers are AI agents -- they don't need shell commands, they need context and goals. The recipe body is the bridge's prompt composition, pre-written for recurring workflows.

```markdown
## code-review

Review PR #{pr}. Read the full diff with `gh pr diff {pr}`. Post your review as GitHub comments using `gh pr review {pr}`.

Focus areas:
- Logic correctness
- Error handling
- Naming and readability
- Whether tests cover the changes

Post a summary comment when done.
```

The bridge reads this, interpolates parameters, enriches it with relevant knowledge from `.fleet/knowledge/`, and passes it to `fleet spawn`.

### Inter-Step Context Passing

When a step depends on another, the bridge passes the predecessor's output as context. This uses Fleet's existing mechanism: the bridge reads the completed worker's status, session digest, and discoveries, then includes relevant context in the dependent worker's prompt.

No explicit "output variables" or artifact declarations. The bridge is intelligent -- it reads what the predecessor produced and decides what the successor needs. This is more flexible than typed outputs and consistent with Fleet's conversational model.

However, recipes can hint at what context to pass:

```yaml
steps:
  - id: analyze
    passes: "findings and root cause analysis"
  - id: fix
    needs: [analyze]
    receives: "analysis findings, affected files, and root cause"
```

`passes` and `receives` are hints to the bridge, not a contract. They improve prompt composition without making it rigid.

### Sharing: Git-native, with a community registry later

**Phase 1 (now):** Recipes live in `.fleet/recipes/`. Share them by committing to your repo. Fork a repo, get its recipes. Copy recipes between projects manually.

**Phase 2:** A community registry at `fleet-recipes/` on GitHub (or similar). Install with:

```bash
fleet recipe add fleet-recipes/review-pr
```

This copies the recipe markdown file into `.fleet/recipes/`. No package manager, no lockfile, no dependency resolution. It's copying a markdown file. The recipe is now yours to edit.

**Phase 3:** `fleet recipe search "security audit"` -- search the registry. `fleet recipe update` -- pull latest versions of installed recipes. But these are conveniences, not necessities. The format is just a markdown file in a directory.

### Evolution: Recipes improve from execution

Fleet already has the learning infrastructure (Layer 5). Recipes tap into it:

**Automatic pattern recording:** When a recipe executes, the bridge records what worked and what didn't in `.fleet/knowledge/patterns.md`. "The review-pr recipe works better when the security-audit step runs after code-review (it can reference review findings)" becomes a recorded pattern.

**Recipe suggestions:** After the bridge runs an ad-hoc workflow that resembles a common pattern, it can suggest creating a recipe: "I've run this release-prep workflow 3 times now with the same structure. Want me to save it as a recipe?"

**Step timing data:** The bridge can annotate recipes with observed execution times, helping predict how long a recipe run will take and whether parallelism is effective.

**No auto-modification of recipes.** The bridge suggests improvements; the director approves them. Recipes are committed code -- they don't change without human review.

---

## Integration with Fleet

### How the bridge invokes a recipe

The director says any of:

```
"Run the PR review recipe on PR 47"
"review-pr 47"
"Prepare a release"
"Do the morning standup"
```

The bridge:

1. Matches intent to a recipe in `.fleet/recipes/`
2. Resolves parameters (from the directive or by asking)
3. Reads the recipe, interpolates parameters
4. Enriches step prompts with relevant `.fleet/knowledge/` context
5. Builds the dependency graph from step `needs:`
6. Spawns independent steps via `fleet spawn`
7. Queues dependent steps in `_bridge/queue.json`
8. Monitors and coordinates using existing Fleet mechanisms

**No new commands in the `fleet` script.** Recipe execution is entirely bridge intelligence. The bridge reads markdown files and translates them into `fleet spawn` calls. This is consistent with Fleet's architecture: the script is plumbing, the skill is intelligence.

The skill gets a new section teaching the bridge how to discover, parse, and execute recipes. The script stays unchanged.

### Recipe state tracking

The bridge tracks recipe execution in `_bridge/state.json`:

```json
{
  "active_recipe": {
    "name": "review-pr",
    "params": {"pr": "47"},
    "steps": {
      "code-review": "done",
      "security-audit": "active",
      "coverage-check": "queued"
    },
    "started_at": "2026-04-10T10:00:00Z"
  }
}
```

This allows the bridge to give recipe-aware status reports: "The PR review recipe is 2/3 done. Security audit is active, coverage check is queued."

### Recipe + ad-hoc work

Recipes don't replace conversational Fleet. They complement it. The director can:

- Run a recipe and add ad-hoc steps ("also spawn a worker to check the database migration")
- Override a recipe step ("skip the security audit, this is just a docs change")
- Interrupt a recipe ("pause the release prep, urgent bug incoming")

The bridge handles all of this because recipes are just structured prompts fed through existing Fleet mechanisms, not a separate execution engine.

---

## Three Recipe Examples

### Recipe 1: `review-pr`

```markdown
---
name: review-pr
description: Comprehensive PR review -- code quality, security, and test coverage
params:
  pr: { required: true, description: "PR number to review" }
  focus: { default: "all", description: "Review focus: all | security | performance | correctness" }
steps:
  - id: code-review
  - id: security-audit
  - id: coverage-check
  - id: synthesize
    needs: [code-review, security-audit, coverage-check]
outputs:
  - Individual reviews posted as GitHub PR comments
  - Synthesis comment with overall recommendation (approve/request changes)
---

## code-review

Review PR #{pr}. Read the full diff:

```bash
gh pr diff {pr}
```

Read the PR description for context:

```bash
gh pr view {pr}
```

Post a thorough code review focusing on:
- Logic correctness and edge cases
- Error handling completeness
- Naming clarity and code readability
- Whether the approach matches project conventions
- Opportunities for simplification

If focus is `{focus}` and not "all", weight your review toward that area.

Post your review using `gh pr review {pr} --comment --body "..."`. Use inline comments for specific issues: `gh api repos/{repo}/pulls/{pr}/comments`.

Write your findings summary to `.fleet/session.md` before completing.

## security-audit

Security audit for PR #{pr}. Read the full diff:

```bash
gh pr diff {pr}
```

Check for:
- Input validation gaps (SQL injection, XSS, command injection)
- Authentication/authorization bypasses
- Secrets or credentials in code
- Insecure dependencies (check with `gh pr checks {pr}` for Dependabot)
- OWASP Top 10 vulnerabilities relevant to the changes

Post security findings as PR comments. If you find critical issues, prefix your comment with **SECURITY:** so it stands out.

Write findings to `.fleet/session.md`.

## coverage-check

Test coverage analysis for PR #{pr}. Read the changed files:

```bash
gh pr diff {pr} --name-only
```

For each changed file:
1. Identify the corresponding test file
2. Check if tests exist for the modified code paths
3. Assess whether existing tests cover the new/changed behavior
4. Identify untested edge cases

Post a coverage summary as a PR comment listing:
- Files with adequate coverage
- Files with gaps (and what's missing)
- Suggested test cases to add

Write findings to `.fleet/session.md`.

## synthesize

You are the synthesis step. Read the session digests from the three review workers:
- Code review findings
- Security audit findings
- Coverage analysis

The bridge will provide these in your prompt context.

Write a single summary comment on PR #{pr} with:
1. **Overall recommendation**: Approve, Request Changes, or Comment
2. **Key findings** (top 3-5 across all reviews)
3. **Blockers** (must fix before merge)
4. **Suggestions** (nice to have, non-blocking)

Post using `gh pr review {pr} --comment --body "..."`.
```

---

### Recipe 2: `prepare-release`

```markdown
---
name: prepare-release
description: Prepare a release -- changelog, dependency check, version bump, and validation
params:
  version: { required: true, description: "Version to release (e.g., 1.2.0)" }
  from: { default: "last tag", description: "Starting point for changelog (tag or commit)" }
steps:
  - id: changelog
  - id: dep-check
  - id: version-bump
    needs: [changelog, dep-check]
  - id: validate
    needs: [version-bump]
outputs:
  - Updated CHANGELOG.md
  - Version bumped in package files
  - Validation report (tests pass, no security issues)
  - Ready-to-merge release PR
---

## changelog

Generate a changelog for version {version}. Find commits since {from}:

```bash
# If "last tag", find the most recent tag
git describe --tags --abbrev=0 2>/dev/null || echo "initial"
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~50")..HEAD --oneline --no-merges
```

Read commit messages and PR descriptions to understand each change. Group them:

- **Added** -- new features
- **Changed** -- changes to existing functionality
- **Fixed** -- bug fixes
- **Removed** -- removed features
- **Security** -- security fixes

Write the changelog entry following the existing format in CHANGELOG.md (or create one if it doesn't exist). Use the Keep a Changelog format.

Do NOT commit yet -- the version-bump step will commit everything together.

Write findings to `.fleet/session.md` including a summary of what's in this release.

## dep-check

Check dependencies for issues before release {version}:

1. **Outdated packages**: Check for outdated dependencies and flag any with known security vulnerabilities
2. **Audit**: Run the project's dependency audit tool (`npm audit`, `bundle audit`, `pip audit`, etc.)
3. **License check**: Flag any new dependencies added since {from} and their licenses

Write a dependency report to `.fleet/session.md`. Flag any blockers for the release.

Do NOT make changes -- just report. If there are issues, the version-bump step will decide what to address.

## version-bump

Bump the version to {version} across the project. The bridge will provide context from the changelog and dep-check steps.

1. Update version numbers in all relevant files (package.json, Cargo.toml, version.rb, pyproject.toml, etc.)
2. If the dep-check found blocking issues, address them (update vulnerable deps, etc.)
3. Add the changelog entry (from the changelog step's output)
4. Create a single commit: "Release {version}"
5. Create a PR:

```bash
gh pr create --title "Release {version}" --body "## Release {version}\n\n[changelog summary]\n\n### Dependency report\n[dep-check summary]"
```

## validate

Final validation before the release PR is ready:

1. Pull the release branch and run the full test suite
2. Verify the version number is correct in all files
3. Verify CHANGELOG.md is properly formatted
4. Check CI status on the PR:

```bash
gh pr checks {pr_number}
```

Post a validation report as a PR comment:
- Tests: pass/fail
- Version consistency: correct/mismatched
- Changelog: complete/missing entries
- CI: green/red
- **Verdict**: Ready to merge / Needs attention

Write findings to `.fleet/session.md`.
```

---

### Recipe 3: `onboard-codebase`

```markdown
---
name: onboard-codebase
description: Deep codebase analysis -- architecture, conventions, test coverage, and synthesis into Fleet knowledge
params:
  focus: { default: "full", description: "Focus area: full | backend | frontend | api | data" }
steps:
  - id: architecture-audit
  - id: convention-discovery
  - id: test-coverage-map
  - id: synthesize
    needs: [architecture-audit, convention-discovery, test-coverage-map]
outputs:
  - .fleet/knowledge/architecture.md populated
  - .fleet/knowledge/conventions.md populated
  - .fleet/knowledge/gotchas.md populated
  - Onboarding summary for new developers
---

## architecture-audit

Map the architecture of this codebase{" focusing on " + focus if focus != "full"}.

Explore the project structure systematically:

1. **Entry points**: Where does execution start? (main files, route definitions, CLI entry points)
2. **Layer structure**: How is the code organized? (MVC, hexagonal, microservices, monolith)
3. **Key abstractions**: What are the core domain objects/services/modules?
4. **Data flow**: How does data move through the system? (request -> controller -> service -> model -> database)
5. **External integrations**: What third-party services are used? (databases, APIs, message queues)
6. **Build and deploy**: How is it built? How is it deployed?

Read key files -- don't just list directory structures. Understand the *why* behind the architecture.

Write your findings directly to `.fleet/knowledge/architecture.md` in the worktree. Use clear headings and keep it factual. This file will be read by future Fleet workers who need to understand the system quickly.

Also note any architectural gotchas (circular dependencies, legacy modules, known tech debt) in `.fleet/knowledge/gotchas.md`.

## convention-discovery

Discover the coding conventions in this codebase{" focusing on " + focus if focus != "full"}.

Look for patterns across multiple files:

1. **Naming**: How are files, classes, functions, variables named? Any prefixes/suffixes?
2. **Code organization**: Where do different types of code live? (services in /services, tests alongside source, etc.)
3. **Error handling**: How are errors handled? Custom error classes? Error boundaries?
4. **Testing patterns**: What testing framework? What patterns? (factories, fixtures, mocks, integration tests)
5. **API patterns**: How are endpoints structured? Serialization? Validation?
6. **State management**: How is state handled? (database, cache, session, global state)
7. **Configuration**: How is the app configured? (env vars, config files, feature flags)

Read at least 5-10 representative files in each category to identify real patterns, not just one-offs.

Write your findings directly to `.fleet/knowledge/conventions.md`. Format as clear rules that a developer (or AI worker) can follow. Example: "Service objects live in `app/services/` and follow the pattern `VerbNounService` (e.g., `CreateOrderService`)."

## test-coverage-map

Map the test coverage landscape of this codebase.

1. **Test framework and setup**: What testing tools are used? How are tests run?
2. **Coverage by area**: Which parts of the codebase have good test coverage? Which are under-tested?
3. **Test types**: Unit tests, integration tests, e2e tests -- what exists?
4. **Test infrastructure**: Factories, fixtures, helpers, shared contexts
5. **CI configuration**: How are tests run in CI? Any flaky tests or known issues?
6. **Critical gaps**: What important code paths have no tests?

Run the test suite if possible to verify it passes:

```bash
# Detect and run the appropriate test command
```

Write your coverage map to `.fleet/session.md`. Flag critical gaps as gotchas in `.fleet/knowledge/gotchas.md`.

## synthesize

You are the synthesis step. The bridge will provide findings from:
- Architecture audit
- Convention discovery
- Test coverage map

Your job:

1. **Review the knowledge files** that the other workers wrote to `.fleet/knowledge/`. Clean them up:
   - Remove contradictions
   - Consolidate overlapping findings
   - Ensure consistent formatting
   - Add cross-references between architecture and conventions

2. **Write an onboarding summary** to `docs/ONBOARDING.md` (or append to existing):
   - "Here's what you need to know to work in this codebase"
   - Key architecture decisions and why they were made
   - The 5 most important conventions to follow
   - Where to find things
   - Known gotchas and how to avoid them

3. **Commit the knowledge files**:

```bash
git add .fleet/knowledge/
git commit -m "Populate Fleet knowledge base from codebase onboarding

Architecture map, coding conventions, and known gotchas discovered
through systematic codebase analysis."
```

This recipe bootstraps Fleet's institutional knowledge for a new project. Future workers start warm instead of cold.
```

---

## Skill Integration

The skill needs a new section teaching the bridge to work with recipes. Here's the proposed addition:

```markdown
## Recipes

Recipes are reusable workflow definitions in `.fleet/recipes/*.md`. They encode proven orchestration patterns.

### Discovery

On session start or when the director references a workflow by name, scan `.fleet/recipes/` for matching recipes. Match on name, description, or intent.

### Execution

1. Parse the recipe frontmatter for params, steps, and outputs
2. Resolve parameters -- use values from the director's message, prompt for missing required params
3. Interpolate `{param}` references in step bodies
4. Enrich step prompts with relevant `.fleet/knowledge/` context
5. Build dependency graph from step `needs:` declarations
6. Spawn independent steps via `fleet spawn --prompt "..."`
7. Queue dependent steps in `_bridge/queue.json`
8. Track recipe progress in `_bridge/state.json`
9. When all steps complete, present the outputs to the director

### Ad-hoc Overrides

The director can modify a recipe at invocation:
- "Run review-pr on 47 but skip the security audit"
- "Do the release prep but add a migration check step"
- "Run onboard-codebase but only focus on the backend"

Respect overrides. Recipes are starting points, not rigid scripts.

### Recipe Suggestions

After running an ad-hoc multi-step workflow, check if the pattern resembles a common workflow. If you've run a similar pattern 2+ times, suggest saving it as a recipe:

"I've run this review workflow 3 times now with the same structure. Want me to save it as `.fleet/recipes/review-pr.md`?"
```

---

## What This Doesn't Do (Deliberately)

**No runtime engine.** Recipes are parsed by the bridge at execution time. There's no recipe executor, no state machine, no workflow runtime. The bridge *is* the runtime. This keeps Fleet simple and means recipe execution benefits from all of Fleet's intelligence (knowledge, learning, escalation).

**No conditional branching.** `if:` conditions in recipes create a parallel specification language that fights Fleet's conversational intelligence. Instead, the bridge makes runtime decisions based on step outputs. A recipe says "review the PR"; if the review finds critical issues, the bridge decides to spawn a fixer -- that's intelligence, not configuration.

**No loops or retries.** Retry logic belongs in the bridge's reactive coordination, not in recipe definitions. If a step fails, the bridge assesses why and decides what to do -- retry, adjust, or escalate. Encoding retry policies in recipes is premature complexity.

**No cross-repo recipes.** Fleet doesn't yet support multi-repo orchestration (it's on the roadmap). Recipes inherit this constraint. When multi-repo lands, recipes will naturally extend to it.

**No recipe inheritance or mixins.** A recipe that needs functionality from another recipe just... includes those steps. Copy the step definitions. Premature abstraction is worse than a little duplication, especially when the "code" being duplicated is natural language prompts.

---

## Migration Path

**Phase 1 -- Format and execution (ship first):**
- Define the recipe format (this document)
- Add recipe discovery and execution to the skill
- Ship 3-5 built-in recipe templates
- No script changes needed

**Phase 2 -- Community and sharing:**
- `fleet recipe` subcommand for listing, adding, searching
- Community recipe repository on GitHub
- Recipe versioning (just git tags on the community repo)

**Phase 3 -- Learning integration:**
- Bridge suggests new recipes from repeated patterns
- Bridge suggests recipe improvements from execution data
- Step timing annotations for prediction
- Recipe effectiveness metrics in `.fleet/knowledge/patterns.md`

---

## Summary

Fleet Recipes are markdown files in `.fleet/recipes/` that define reusable multi-step workflows. Each step is a worker prompt. Steps declare dependencies forming a DAG. Parameters use `{param}` interpolation. The bridge parses and executes them using existing Fleet infrastructure -- no new runtime, no new commands, no new dependencies.

The format is opinionated: markdown over YAML, prompts over commands, intelligence over configuration. It bets on Fleet's conversational AI being better at runtime decisions than static workflow definitions, and uses recipes only for the *structure* that's worth encoding -- what steps to run, in what order, with what context.

Recipes make Fleet's orchestration patterns portable, shareable, and improvable -- without sacrificing the flexibility that makes Fleet powerful in the first place.
