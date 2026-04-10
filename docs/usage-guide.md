# Fleet Usage Guide

A real-world walkthrough of using Fleet while building a feature.

---

## Setup

You've installed Fleet. You've run `fleet telegram setup`. You're in your repo.

## The scenario

You're building the Guest Portal for SERVOS -- a large feature that spans data models, API endpoints, frontend pages, and third-party integrations. This is your main work. You and Claude Code are deep in it.

## Starting your day

Open Claude Code in your repo like normal:

```
claude
```

You're working on the Guest Portal. This is your session. Fleet is installed as a skill, but you don't need to think about it. Just work.

```
You:    "Let's continue on the guest portal. Where did we leave off?"
Claude: [reads your branch, recent commits, picks up where you left off]
```

You're in flow. Building the check-in page. Writing the controller, the service, the tests.

## An interruption arrives

Your phone buzzes. Slack message: "Checkout is broken on mobile. Customer reported it 10 minutes ago."

**Without Fleet:** You stop. Stash your changes. Switch to main. Create a fix branch. Lose your context. Fix the bug. Push. Switch back. Try to remember what you were doing.

**With Fleet:** You type one line without leaving your session:

```
You:    "Fix the mobile checkout bug. Customer says it fails when there are 
         multiple guests. Don't touch my branch."
```

Fleet activates. It spawns a worker on a separate branch. A new tab appears in Ghostty showing the worker. Your session continues:

```
Claude: "Spawned fix-mobile-checkout on branch fleet/fix-mobile-checkout.
         Working in a separate worktree. Your guest-portal branch is untouched.
         I'll let you know when it's done."

You:    "Ok. Now back to the check-in page -- we need to handle the case 
         where a guest has dietary restrictions..."
Claude: [continues working on guest portal, exactly where you left off]
```

Ten minutes later:

```
Claude: "fix-mobile-checkout is done. PR #91 created, tests green.
         The bug was a nil check on guest.payment_method when multiple
         guests share a single booking. Want me to merge it?"

You:    "Merge it."
Claude: "Merged. Back to dietary restrictions?"
```

Your flow never broke. The bug is fixed. The PR is merged. You never switched branches.

## A PR needs review

You get a notification: Alice opened PR #47 for the billing refactor.

```
You:    "Review Alice's PR 47"
Claude: "Spawning a review worker."

        [5 minutes later]

Claude: "PR #47 reviewed. Posted 3 comments:
         - SQL injection risk in the search endpoint (SECURITY flagged)
         - Missing test for the edge case with zero-amount invoices
         - Suggestion to use the existing MoneyFormatter helper
         Overall: requested changes due to the SQL injection."

You:    "Good catch. Back to dietary restrictions."
```

## Multiple things at once

It's midday. You're still on the guest portal, but three issues came in from the team:

```
You:    "Three things while I keep working:
         1. Issue #55 - fix the timezone bug in calendar sync
         2. Issue #58 - update the Stripe webhook handler for the new API
         3. Research how competitors handle guest dietary preferences"
```

Fleet spawns three workers in parallel. You see three panes appear in the fleet tab. You ignore them and keep working.

```
        [20 minutes later]

Claude: "All three done:
         - issue-55: PR #92 created. Calendar was using local time 
           instead of UTC for cross-timezone comparisons.
         - issue-58: PR #93 created. Updated Stripe webhook signature
           verification for API v2024-12.
         - research-dietary: Wrote findings to docs/dietary-research.md.
           Key insight: most competitors use tag-based systems, not 
           free-text fields.

         Want me to merge 55 and 58? And the dietary research is relevant 
         to what you're building -- want a summary?"

You:    "Merge both. And yes, give me the highlights."
```

## Stepping away

You're heading to a meeting. The guest portal work is at a good stopping point, but there are still two issues in the queue.

```
You:    "I'm heading out. Keep working on the queue."
```

You close your laptop. Fleet's watcher is running. Workers keep going. You get Telegram notifications:

```
Fleet:  "issue-60 done. PR #94, tests green. Merge? [Yes / Later]"
You:    "Yes"
Fleet:  "Merged. Starting issue-62 from the queue."

Fleet:  "issue-62 needs a decision (medium stakes): 
         The legacy API endpoint should return the old format or the new one?
         Recommendation: new format with a deprecation header.
         Reply A (new + header) or B (old format)."
You:    "A"
Fleet:  "Sent. Will finish and create PR."
```

You come back. Open Claude Code:

```
You:    "I'm back. What happened?"
Claude: "While you were away:
         - issue-60: PR #94 merged (approved via Telegram)
         - issue-62: PR #95 created, using new format with deprecation
           header (your choice via Telegram). Ready for merge.
         - Your guest-portal branch is untouched. 
           Last thing we were working on: dietary restriction tags
           for the check-in page."

You:    "Merge 95. Let's continue on dietary tags."
```

## End of day

```
You:    "What did we ship today?"
Claude: "Today's work:
         - Guest Portal: check-in page with dietary restriction tags (your branch)
         - 4 issues fixed and merged (#55, #58, #60, #62)
         - 1 PR reviewed with security finding (#47)
         - 1 research doc completed (dietary preferences)
         
         All via Fleet workers while you stayed focused on the portal.
         Your guest-portal branch has 12 commits, all yours."
```

---

## Key commands

You rarely need these directly -- Fleet handles them through conversation. But for reference:

| Command | What it does |
|---|---|
| `fleet spawn <name> --prompt "..."` | Start an isolated worker |
| `fleet stop [name]` | Stop a worker (or all workers) |
| `fleet ls` | List active workers |
| `fleet attach` | View worker tmux panes |
| `fleet resume <name> "prompt"` | Send new instructions to an idle worker |
| `fleet telegram setup` | Connect Telegram (one-time) |
| `fleet telegram test` | Verify Telegram works |
| `fleet watch start` | Start GitHub monitoring |
| `fleet watch stop` | Stop monitoring, show briefing |

## Key concepts

**Your session is yours.** Fleet never touches your branch or your Claude Code context. Workers live in separate worktrees.

**Workers are disposable.** They spawn, do their task, create a PR, and get cleaned up. They don't persist between tasks.

**The bridge is the skill.** When Fleet is installed, Claude Code automatically knows how to dispatch workers when you mention side-tasks. You don't invoke Fleet -- it activates when you need it.

**Telegram is optional but powerful.** Without it, Fleet reports back in your terminal session. With it, you can direct work from your phone.

## Tips

- **Don't use Fleet for your main work.** Use Claude Code directly. Fleet is for everything *around* it.
- **Be specific about what "done" means.** "Fix the bug and create a PR" works better than just "fix the bug."
- **Check the fleet tab occasionally.** `Ctrl-b` + arrows in tmux to switch between worker panes.
- **Fleet recipes save time.** "Review PR 47" triggers a 4-step review recipe automatically.
- **Workers write session digests.** After a worker finishes, its findings are preserved in `.fleet/sessions/` for future context.
