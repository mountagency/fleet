# Fleet Watch: Autonomous Repo Monitoring

> Research document -- April 2026
> Status: Design proposal

## Vision

You go to sleep. Fleet watches your repo overnight. Issues come in -- it triages them, assigns priority, maybe starts investigating. PRs open -- it reviews them and posts comments. CI fails -- it reads the logs, identifies the cause, maybe spawns a fix. You wake up to a Telegram briefing of everything that happened.

Fleet Watch turns Fleet from a tool you use into a system that works for you.

---

## 1. Architecture Overview

```
                          +------------------+
                          |   GitHub Repo    |
                          |  (events source) |
                          +--------+---------+
                                   |
                          polling (gh api)
                          ETag-conditional
                          every 60s idle / 15s active
                                   |
                          +--------v---------+
                          |   fleet-watch    |
                          |   (bash daemon)  |
                          |                  |
                          |  - polls events  |
                          |  - classifies    |
                          |  - decides act   |
                          |    vs. surface   |
                          +----+--------+----+
                               |        |
                    +----------+        +----------+
                    |                              |
           +-------v--------+           +---------v-------+
           |  Triage Engine  |           |  Notification   |
           | (Claude --print)|           |  (Telegram)     |
           |  cheap/fast     |           |  + briefing.md  |
           +-------+--------+           +-----------------+
                   |
          decision: act or surface?
                   |
        +----------+----------+
        |                     |
+-------v--------+    +------v-------+
| fleet spawn    |    |  Log to      |
| (full worker)  |    |  briefing    |
| fix / review   |    |  for morning |
+----------------+    +--------------+
```

### Why polling, not webhooks

Webhooks require infrastructure: a public endpoint, a server, SSL, uptime. Fleet is a CLI tool that runs on your laptop or a dev machine. Polling with `gh api` keeps Fleet zero-infrastructure.

The cost is minimal. GitHub's Events API supports ETag-conditional requests -- if nothing changed, you get a `304 Not Modified` that doesn't count against your rate limit. The `X-Poll-Interval` header tells you the minimum interval (usually 60s). At 1 request/minute, a full night (8 hours) costs ~480 API calls out of your 5,000/hour limit. That's nothing.

**Future option:** For teams that want real-time response, Fleet Watch could optionally accept webhook delivery via a lightweight `nc`-based listener or a smee.io proxy. But polling is the right default for a CLI tool.

---

## 2. Event Sources

### What Fleet watches

| Source | gh API endpoint | What matters |
|--------|----------------|-------------|
| **Issues** | `repos/{owner}/{repo}/issues?state=open&sort=created&direction=desc` | New issues, label changes |
| **Pull Requests** | `repos/{owner}/{repo}/pulls?state=open&sort=created&direction=desc` | New PRs, review requests, ready for review |
| **CI/Workflows** | `repos/{owner}/{repo}/actions/runs?status=failure` | Failed runs on default branch or open PRs |
| **Commits** | `repos/{owner}/{repo}/events` | Pushes to default branch (force pushes, unexpected changes) |
| **Releases** | `repos/{owner}/{repo}/releases?per_page=5` | New releases (for changelog/notification) |
| **Discussions** | `repos/{owner}/{repo}/discussions` (GraphQL) | New discussions with questions |

### What Fleet ignores by default

- Dependabot PRs (configurable -- some teams want auto-merge)
- Bot-authored issues (unless from known bots like Sentry)
- Draft PRs (until marked ready)
- Issues/PRs older than the watch session start time

### Event deduplication

Fleet Watch maintains a local state file (`_bridge/watch-state.json`) tracking:
- Last seen event IDs per source
- ETags for conditional requests
- Events already triaged (to avoid re-processing on restart)

```json
{
  "last_poll": "2026-04-10T03:15:00Z",
  "etags": {
    "issues": "W/\"abc123\"",
    "pulls": "W/\"def456\"",
    "runs": "W/\"ghi789\""
  },
  "seen_events": {
    "issues": [142, 143, 144],
    "pulls": [87, 88],
    "runs": [9901234]
  },
  "session_start": "2026-04-09T22:00:00Z"
}
```

---

## 3. Triage Intelligence

### The two-tier model

Fleet Watch uses two tiers of intelligence to keep costs down:

**Tier 1: Rule-based classification (free, instant)**
Bash logic in fleet-watch that classifies events by type, labels, author, and patterns. No AI needed for obvious cases.

**Tier 2: AI triage (cheap, fast)**
For ambiguous events, a single `claude --print` call with the event context. Uses the cheapest available model. Returns a structured JSON decision. ~$0.01-0.03 per triage call.

### Tier 1 rules (built-in)

```bash
# Priority classification
P0_KEYWORDS="security|vulnerability|crash|data.loss|production.down"
P1_KEYWORDS="regression|breaking|blocker|urgent"
P2_KEYWORDS="bug|error|fail"

# Auto-act triggers
AUTO_REVIEW_IF="pr AND (author in trusted_authors) AND (files_changed < 20)"
AUTO_INVESTIGATE_IF="ci_failure AND (branch == default_branch)"
AUTO_LABEL_IF="issue AND (no labels)"
```

### Tier 2: AI triage prompt

When Tier 1 can't classify confidently, Fleet Watch calls Claude with:

```
You are a GitHub issue/PR triage agent for {repo}.

Event: {type} #{number}
Title: {title}
Body: {body (first 2000 chars)}
Author: {author}
Labels: {labels}
Files changed: {files (for PRs)}

Project context:
{contents of .fleet/knowledge/architecture.md, first 500 chars}

Classify this event. Respond with JSON only:
{
  "priority": "p0|p1|p2|p3",
  "category": "bug|feature|question|maintenance|security",
  "action": "act|surface|ignore",
  "action_type": "review|investigate|fix|label|notify",
  "reasoning": "one sentence",
  "suggested_labels": ["label1", "label2"]
}
```

### Triage decision matrix

| Priority | Category | Default action |
|----------|----------|---------------|
| P0 | security | **ACT**: spawn investigator, Telegram alert immediately |
| P0 | bug | **ACT**: spawn investigator, Telegram alert |
| P1 | bug | **SURFACE**: Telegram notification, add to morning briefing |
| P1 | feature | **SURFACE**: add to morning briefing with recommendation |
| P2 | bug | **SURFACE**: add to morning briefing |
| P2 | feature | **LOG**: add to briefing, low priority section |
| P3 | anything | **LOG**: briefing only |
| any | CI failure (default branch) | **ACT**: spawn investigator |
| any | CI failure (PR branch) | **SURFACE**: comment on PR with failure analysis |
| any | PR (trusted author) | **ACT**: spawn reviewer |
| any | PR (external) | **SURFACE**: Telegram notification |

---

## 4. Autonomous Boundaries

### What Fleet Watch can do without permission

These actions are safe, reversible, and low-stakes:

| Action | Scope | Why safe |
|--------|-------|----------|
| **Read** issues, PRs, CI logs | Read-only | No side effects |
| **Label** issues | Additive, reversible | Labels can be removed |
| **Comment** on issues/PRs | Additive | Comments can be deleted |
| **Review PRs** (comment, not approve) | Read + comment | No merge authority |
| **Create branches** | Namespace: `fleet/watch-*` | Isolated, deletable |
| **Spawn investigation workers** | Local compute | No repo writes |
| **Send Telegram notifications** | Notification | Informational only |
| **Post CI failure analysis** as PR comment | Additive | Helpful, deletable |

### What Fleet Watch CANNOT do without permission

These require explicit director configuration or approval:

| Action | Why restricted | How to enable |
|--------|---------------|---------------|
| **Merge PRs** | Irreversible | `watch.auto_merge: true` in config |
| **Close issues** | Could lose signal | Never auto-enabled |
| **Push commits** | Changes repo state | `watch.auto_fix: true` in config |
| **Create PRs** | Visible to collaborators | `watch.auto_pr: true` in config |
| **Approve PRs** | Trust boundary | `watch.trusted_reviewers: [fleet]` |
| **Delete branches** | Data loss risk | Never auto-enabled |
| **Modify CI/Actions** | Infrastructure change | Never auto-enabled |

### Guardrail implementation

```bash
# In watch config (~/.fleet/watch.yaml or .fleet/watch.yaml)
watch:
  # What to monitor
  sources:
    issues: true
    pulls: true
    ci: true
    discussions: false
    releases: true

  # Autonomy levels
  autonomy:
    review_prs: true          # Post review comments
    label_issues: true        # Auto-label based on triage
    investigate_failures: true # Spawn workers for CI failures
    auto_fix: false           # Create fix PRs (requires explicit opt-in)
    auto_merge: false         # Merge approved PRs (requires explicit opt-in)
    auto_pr: false            # Create PRs from investigations

  # Trust
  trusted_authors: []         # Authors whose PRs get auto-reviewed
  ignore_authors: [dependabot, renovate]

  # Cost controls
  max_triage_calls_per_hour: 20
  max_workers_per_session: 3
  max_worker_runtime_minutes: 30
```

---

## 5. Scheduling and Lifecycle

### Starting watch mode

```bash
# Start watching (runs in background, like fleet-watcher)
fleet watch start

# Start watching with specific config
fleet watch start --config .fleet/watch.yaml

# Watch a specific repo (for multi-repo support)
fleet watch start --repo owner/repo

# Check watch status
fleet watch status

# Stop watching
fleet watch stop

# One-shot: run watch cycle once (good for cron)
fleet watch once
```

### How it runs

Fleet Watch is a background daemon, extending the existing `fleet-watcher` pattern:

```
fleet watch start
  |
  v
fleet-watch-daemon (bash, background)
  |
  +-- polls GitHub every POLL_INTERVAL seconds
  +-- runs triage on new events
  +-- spawns workers when action needed
  +-- monitors spawned workers (reuses fleet-watcher logic)
  +-- sends Telegram notifications
  +-- accumulates briefing
  |
  v
fleet watch stop (or Ctrl+C)
  |
  v
final briefing generated + sent via Telegram
```

### Cron integration

For users who want scheduled watching without a persistent daemon:

```bash
# Watch during off-hours (crontab)
# Run every 5 minutes between 10pm and 7am
*/5 22-23,0-6 * * * cd /path/to/repo && fleet watch once >> ~/.fleet/watch.log 2>&1
```

### Session lifecycle

```
fleet watch start
  |
  v
[polling loop]
  |
  +-- New issue #145 detected
  |     +-- Tier 1: matches P1 bug pattern
  |     +-- Action: SURFACE
  |     +-- Telegram: "New P1 issue #145: Login fails on Safari"
  |     +-- Logged to briefing
  |
  +-- CI run #9902 failed on main
  |     +-- Action: ACT
  |     +-- fleet spawn watch-ci-9902 --prompt "Investigate CI failure..."
  |     +-- Worker runs, finds the cause, comments on the commit
  |     +-- Telegram: "CI fix: test_auth was flaky, added retry. See commit abc123"
  |
  +-- PR #89 opened by trusted author
  |     +-- Action: ACT (review)
  |     +-- fleet spawn watch-review-89 --prompt "Review PR #89..."
  |     +-- Worker reviews, posts comments via gh pr review
  |     +-- Telegram: "Reviewed PR #89: 2 suggestions, LGTM overall"
  |
  +-- [8 hours later, director wakes up]
  |
  v
fleet watch stop (or director runs `fleet attach`)
  |
  v
Morning briefing generated and sent
```

---

## 6. Briefing Format

### Telegram morning briefing

Sent when the director runs `fleet attach`, `fleet watch stop`, or at a configured time (e.g., 7am).

```
Good morning. Here's your overnight watch report.

ACTED ON (3):
- CI #9902 on main: test_auth flaky. Added retry, pushed fix. (commit abc123)
- PR #89 @alice: Reviewed. 2 suggestions posted. Ready for your approval.
- PR #91 @bob: Reviewed. Found a SQL injection risk -- blocked with comment.

NEEDS YOU (1):
- Issue #145 (P1): "Login fails on Safari 18.3". Investigated -- likely
  WebAuthn API change. Fix requires a decision: polyfill or drop Safari 18.3?

NEW ISSUES (2):
- #146 (P2): "Dark mode contrast on settings page" -- labeled ui, cosmetic
- #147 (P3): "Feature request: CSV export" -- labeled enhancement

QUIET:
- No new releases
- No discussion activity
- 4 Dependabot PRs (ignored per config)

Stats: 12 events processed, 3 workers spawned, ~$0.45 AI cost.
```

### Briefing file format

Written to `_bridge/watch-briefing.md` for structured access:

```markdown
# Watch Briefing
Period: 2026-04-09 22:00 UTC -- 2026-04-10 06:30 UTC

## Acted On

### CI Failure #9902 (main)
- **Cause:** Flaky test `test_auth_token_refresh` -- race condition on Redis mock
- **Action:** Added retry with backoff, pushed to main
- **Commit:** abc123
- **Worker:** watch-ci-9902 (runtime: 4m)
- **Cost:** ~$0.12

### PR #89 -- "Add webhook retry logic" (@alice)
- **Action:** Code review posted via `gh pr review`
- **Verdict:** LGTM with 2 suggestions (error message clarity, test coverage)
- **Worker:** watch-review-89 (runtime: 6m)
- **Cost:** ~$0.15

### PR #91 -- "User search endpoint" (@bob)
- **Action:** Code review posted, CHANGES_REQUESTED
- **Finding:** SQL injection via unsanitized `order_by` parameter
- **Worker:** watch-review-91 (runtime: 3m)
- **Cost:** ~$0.08

## Needs Decision

### Issue #145 -- "Login fails on Safari 18.3" (P1)
- **Investigation:** WebAuthn `navigator.credentials.get()` behavior changed in Safari 18.3
- **Options:**
  A. Add polyfill for old behavior (~2 days work)
  B. Require Safari 18.4+ (breaking for ~3% of users)
- **Recommendation:** Option A. 3% is too many users to drop.
- **Worker:** watch-investigate-145 (runtime: 12m)
- **Cost:** ~$0.20

## New Issues

| # | Priority | Title | Labels | Action taken |
|---|----------|-------|--------|-------------|
| 146 | P2 | Dark mode contrast on settings page | ui, cosmetic | Labeled |
| 147 | P3 | Feature request: CSV export | enhancement | Labeled |

## Summary
- Events processed: 12
- Workers spawned: 3
- Total AI cost: ~$0.45
- Polling calls: 390 (360 were 304 Not Modified)
```

---

## 7. Integration with Existing Fleet

### Building on fleet-watcher

Fleet Watch extends, not replaces, the existing `fleet-watcher`. The relationship:

```
fleet-watcher (existing)
  |
  +-- monitors worker status files
  +-- sends Telegram on worker completion/block
  +-- polls Telegram for inbound commands
  +-- handles detach/reattach

fleet-watch (new)
  |
  +-- INCLUDES all fleet-watcher functionality
  +-- ADDS GitHub event polling
  +-- ADDS triage engine
  +-- ADDS autonomous worker spawning
  +-- ADDS briefing generation
  +-- ADDS cost tracking
```

Implementation approach: `fleet-watch` is a new script that sources or embeds `fleet-watcher` functions and adds the GitHub monitoring loop. The existing `fleet detach` / `fleet attach` flow works unchanged.

### New fleet commands

```bash
fleet watch start [--config path]   # Start watch daemon
fleet watch stop                    # Stop watching, generate briefing
fleet watch status                  # Show current watch state
fleet watch once                    # Single poll cycle (for cron)
fleet watch briefing                # Generate and display current briefing
fleet watch config                  # Interactive config setup
```

### New bridge files

```
_bridge/
  watch-state.json          # Polling state, ETags, seen events
  watch-briefing.md         # Accumulated briefing
  watch-config.yaml         # Runtime config (merged from defaults + user)
  watch-cost.json           # Running cost tracker
  log/_watch.jsonl           # Watch-specific event log
```

---

## 8. Cost Management

### The cost model

Fleet Watch has three cost dimensions:

| Activity | Cost | Frequency |
|----------|------|-----------|
| **GitHub API polling** | Free (within rate limits) | Every 60s, ETag-conditional |
| **Tier 2 AI triage** | ~$0.01-0.03 per call | Only when Tier 1 can't classify |
| **Worker sessions** | ~$0.05-0.50 per worker | Only when action is taken |

### Cost controls

1. **Tier 1 first**: Rule-based classification handles 70-80% of events with zero AI cost. Only ambiguous events hit Tier 2.

2. **Triage rate limiting**: `max_triage_calls_per_hour: 20` prevents runaway costs during event storms (e.g., bot spam, mass label changes).

3. **Worker budget**: `max_workers_per_session: 3` limits concurrent workers. `max_worker_runtime_minutes: 30` kills long-running investigations.

4. **Cost tracking**: Every AI call logs its estimated cost to `_bridge/watch-cost.json`. The briefing includes total cost.

5. **Idle optimization**: When no new events are detected (304 responses), the poll interval gradually increases from 60s to 300s. Any new event resets to 60s.

6. **Batching**: If multiple events arrive in the same poll, triage them in a single Claude call rather than one-per-event.

### Projected costs

| Scenario | Events/night | Triage calls | Workers | Estimated cost |
|----------|-------------|-------------|---------|---------------|
| Quiet solo repo | 0-2 | 0-1 | 0 | < $0.05 |
| Active solo repo | 5-10 | 2-5 | 1-2 | $0.20-0.50 |
| Team repo (5 devs) | 10-30 | 5-15 | 2-5 | $0.50-2.00 |
| Popular OSS repo | 50-200 | 20-50 | 3-10 | $2.00-8.00 |

For context: a developer's time costs $50-150/hour. If Fleet Watch saves 30 minutes of morning triage, it pays for itself on the first night.

### Adaptive polling

```
Polling interval logic:

  if consecutive_304_responses > 10:
    interval = min(interval * 1.5, MAX_INTERVAL)  # Back off to 5 min
  elif new_event_detected:
    interval = MIN_INTERVAL  # Snap back to 60s
  elif active_workers > 0:
    interval = ACTIVE_INTERVAL  # 15s while workers running
```

---

## 9. Implementation Plan

### Phase 1: Foundation (MVP)

Add GitHub event polling to fleet-watch. No AI triage yet -- just detection and Telegram notification.

- New script: `fleet-watch-github` (or extend `fleet-watcher`)
- Poll issues, PRs, CI runs via `gh api`
- ETag-conditional requests
- Telegram notifications for new events
- `fleet watch start/stop/status`
- Watch state persistence (`watch-state.json`)

### Phase 2: Triage

Add the two-tier classification system.

- Tier 1 rule engine (bash pattern matching)
- Tier 2 AI triage via `claude --print`
- Triage decision matrix
- Auto-labeling
- Cost tracking

### Phase 3: Autonomous Action

Spawn workers for reviews, investigations, and fixes.

- Worker spawning for CI failures
- Worker spawning for PR reviews
- Investigation workers for high-priority issues
- Briefing generation
- Worker lifecycle management (timeout, cleanup)

### Phase 4: Briefing and Polish

The morning briefing and director experience.

- Structured briefing generation
- Telegram morning summary
- `fleet watch briefing` command
- Cost reports
- Adaptive polling
- Config file support

---

## 10. Comparison: Fleet Watch vs. GitHub Agentic Workflows

GitHub launched [Agentic Workflows](https://github.blog/ai-and-ml/automate-repository-tasks-with-github-agentic-workflows/) in Feb 2026 -- markdown-defined automation that runs AI agents on GitHub Actions runners. How does Fleet Watch differ?

| Dimension | Fleet Watch | GitHub Agentic Workflows |
|-----------|------------|------------------------|
| **Runs on** | Your machine / dev server | GitHub Actions runners |
| **Agent** | Claude Code (full environment) | Copilot CLI / configurable |
| **Config** | YAML + skill (natural language bridge) | Markdown workflow files |
| **Infra needed** | None (CLI tool) | GitHub Actions (included) |
| **Cost** | API calls + Claude usage | Actions minutes + AI provider |
| **Trigger model** | Polling | Webhooks (native) |
| **Flexibility** | Full Claude Code power (file system, tools, MCP) | Sandboxed Actions runner |
| **Integration** | Fleet ecosystem (bridge, workers, Telegram) | GitHub-native |
| **Repo access** | Full local clone | Checkout in runner |

**Fleet Watch's advantage**: It's part of the Fleet ecosystem. A triage decision can spawn a full Fleet worker with complete codebase access, tool use, and the bridge coordination protocol. GitHub Agentic Workflows are powerful but isolated -- each run is a fresh container.

**GitHub AW's advantage**: Native webhook triggers (real-time), no infrastructure to run, and deep GitHub integration. For teams already on GitHub Actions, it's zero-setup.

**Recommendation**: Fleet Watch and GitHub AW serve different use cases. Fleet Watch is for teams/individuals who want an always-on engineering companion with full autonomy. GitHub AW is for teams who want lightweight, event-driven automation within GitHub's ecosystem. They can coexist -- Fleet Watch could even consume GitHub AW outputs as an event source.

---

## 11. Open Questions

1. **Multi-repo**: Should `fleet watch` monitor multiple repos from one daemon? Or one daemon per repo?
   - Recommendation: One daemon per repo, with a `fleet watch list` to see all active watches.

2. **Webhook option**: Should we offer a webhook listener as an alternative to polling?
   - Recommendation: Not in v1. Polling is simpler and sufficient. Revisit if latency becomes a pain point.

3. **Worker reuse**: Should watch workers be long-lived (handle multiple events) or one-shot?
   - Recommendation: One-shot. Keeps context clean, avoids memory bloat, and matches Fleet's existing model.

4. **PR approval**: Should Fleet Watch ever approve PRs, or only comment/request changes?
   - Recommendation: Comment and request changes only. Approval is a trust boundary that should remain with humans.

5. **Morning briefing timing**: Should Fleet Watch send the briefing at a configured time, or only on `fleet attach`?
   - Recommendation: Both. Default to `fleet attach`, but allow `watch.briefing_time: "07:00"` for scheduled delivery.

6. **Event replay**: If fleet-watch crashes and restarts, should it re-process events from the last checkpoint?
   - Recommendation: Yes, using `watch-state.json` as the checkpoint. Only process events newer than `last_poll`.

---

## 12. Security Considerations

- **Token scope**: Fleet Watch uses the user's existing `gh` authentication. No additional tokens needed. The `gh` token should have `repo` scope for private repos.
- **Write actions**: All write actions (comments, labels, reviews) go through `gh` CLI, which respects the token's permissions.
- **Worker isolation**: Watch workers run in git worktrees, same as regular Fleet workers. No additional attack surface.
- **Inbound Telegram**: The existing fleet-watcher's Telegram command handling applies. Fleet Watch inherits its security model.
- **Rate limiting**: Built-in rate limiting prevents Fleet Watch from being used as a DoS vector against GitHub's API.
- **Secret exposure**: AI triage prompts include issue/PR bodies which might contain secrets. Triage responses are logged locally, never posted publicly. Worker-posted comments go through Claude's safety layer.
