# Fleet

You're deep in a feature. A bug report comes in. A PR needs review. A customer call surfaces an urgent fix.

Today, you stop. Stash changes. Switch branches. Lose your context. Fix the thing. Switch back. Try to remember where you were.

Fleet means you never stop. You say "fix issue 42" and it happens in the background -- separate branch, separate session, separate worktree. Your work continues. You approve the PR from your phone. You never lost your place.

## What it actually does

Fleet gives Claude Code **parallel sessions with branch isolation**. Each session runs in its own git worktree, on its own branch, in its own tmux pane. Your main work is never touched.

```
You:    [deep in Guest Portal feature work]
You:    "A customer reported checkout fails on mobile. Can you fix it?"
Claude: Spawns a worker on a separate branch. You keep working.

        [10 minutes later]
Claude: "fix-checkout done. PR #91 created, tests green. Merge?"
You:    "Yes."
Claude: Merged. Your Guest Portal work never stopped.
```

It also works from your phone:

```
Fleet:  "fix-checkout done. PR #91, tests green. Merge?"
You:    "Yes"
Fleet:  "Merged."

Fleet:  "PR #47 from Alice ready for review."
You:    "Review it"
Fleet:  [spawns reviewer, posts GitHub comments]
```

## When to use Fleet

**Use Fleet when you'd otherwise context-switch:**
- Bug comes in while you're building a feature
- PR needs review but you're mid-task
- Quick fix needed on a different branch
- Research task you want running in the background
- Multiple independent issues to tackle in parallel

**Don't use Fleet when:**
- You're doing deep, interconnected work on one feature (just use Claude Code directly)
- The task requires your full attention and judgment
- You need tight back-and-forth iteration

Fleet is best at handling **everything around your main work** so you can stay focused.

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
cp fleet-watcher ~/.local/bin/fleet-watcher && chmod +x ~/.local/bin/fleet-watcher
cp fleet-watch-github ~/.local/bin/fleet-watch-github && chmod +x ~/.local/bin/fleet-watch-github
cp fleet-watch-triage ~/.local/bin/fleet-watch-triage && chmod +x ~/.local/bin/fleet-watch-triage
mkdir -p ~/.claude/skills/fleet
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
cp skill/WORKER_PROTOCOL.md ~/.claude/skills/fleet/WORKER_PROTOCOL.md
cp -r skill/recipes ~/.claude/skills/fleet/recipes
```

## How it works

You're in a Claude Code session working on your feature. Something else comes up. You tell Claude about it. Fleet handles it:

1. **Spawns a worker** in a separate git worktree on branch `fleet/{name}`
2. **Worker runs autonomously** -- full Claude Code session with file access, terminal, GitHub CLI
3. **You keep working** -- your branch, your context, your flow state are untouched
4. **Worker reports back** -- via the bridge session or Telegram
5. **You approve** -- merge the PR, review the output, or send it back for changes

Workers appear in a separate terminal tab (auto-opened on macOS). You can glance at them or ignore them entirely.

### What you see

Your terminal has two tabs:
- **Tab 1**: Your main Claude Code session (you're working here)
- **Tab 2**: Fleet workers (auto-opened, one pane per worker)

When a worker finishes, Claude tells you in your main session. Or if you have Telegram set up, on your phone.

## Telegram (optional)

Fleet can notify you on Telegram when workers complete or need decisions. You can reply from your phone.

```bash
fleet telegram setup    # One-time: create bot, connect
```

Then from Telegram:
- Get notified when workers finish, get blocked, or need decisions
- Reply with commands: "merge it", "yes", "stop that worker"
- Send natural language: "fix the login bug" (Fleet interprets and acts)
- Check status: "status" or "what's happening"

## Recipes

Fleet comes with reusable workflow recipes for common tasks:

**Review a PR:**
> "Review PR 47"

Spawns parallel workers for code review, security audit, and test coverage analysis. Posts findings as GitHub comments.

**Prepare a release:**
> "Prepare release 2.0"

Generates changelog, checks dependencies, bumps version, validates, creates PR.

**Onboard a codebase:**
> "Onboard me to this codebase"

Maps architecture, discovers conventions, checks test coverage, writes findings to `.fleet/knowledge/`.

Recipes live at `~/.claude/skills/fleet/recipes/`. You can create your own in `.fleet/recipes/`.

## Fleet Watch

Monitor your GitHub repo autonomously:

```bash
fleet watch start     # Start monitoring issues, PRs, CI
fleet watch stop      # Stop, show briefing
fleet watch status    # Check what's happening
```

Fleet Watch polls GitHub for new events, triages them (rule-based + AI), and acts on high-priority items -- reviewing PRs, investigating CI failures, labeling issues. Lower-priority items go to your Telegram or the briefing.

## Architecture

Two layers, sharply separated:

**Scripts (plumbing):** `fleet` creates worktrees, manages tmux, starts Claude sessions. `fleet-watcher` handles Telegram and background monitoring. `fleet-watch-github` and `fleet-watch-triage` handle GitHub monitoring. All bash, no dependencies beyond git/tmux/jq/curl.

**Skill (intelligence):** `skill/SKILL.md` teaches Claude Code how to be a bridge -- decompose work, compose prompts, coordinate workers, escalate decisions. `skill/WORKER_PROTOCOL.md` teaches workers how to report status and communicate via the bridge.

**Coordination (files):** Workers communicate through files in `.fleet-workers/_bridge/` -- status JSON, event logs, message files, discoveries. Simple, debuggable, no database.

## Contributing

Fleet is open source under MIT. The best way to contribute is to use it, find where it breaks, and open issues.

## License

MIT
