# Fleet v2 Layer 4: Untether the Director

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Free the director from the terminal -- Telegram notifications, bidirectional commands, detach/reattach with structured briefings.

**Architecture:** Three new components: (1) `fleet-watcher` -- a standalone bash script that runs in the background, monitors worker status files via mtime polling, sends Telegram notifications, polls for inbound messages, accumulates a briefing file; (2) Telegram subcommands in the main `fleet` script for setup and manual messaging; (3) Skill updates teaching the bridge how to route escalations and generate reattach briefings. No new dependencies -- just curl (already available), bash, and jq.

**Tech Stack:** Bash, curl (Telegram Bot API), jq, existing fleet infrastructure

**Constraints:**
- `fleet` script must stay under 200 lines (currently 175, budget for ~20 lines of additions)
- `fleet-watcher` is a new script, target under 150 lines
- Skill additions should keep total under 400 lines (currently 307)
- No dependencies beyond bash, git, tmux, jq, curl

---

## File Map

```
Create: fleet-watcher                    # Background watcher: status monitoring + Telegram I/O
Modify: fleet:8,43,157-175              # Add telegram/detach subcommands
Modify: skill/SKILL.md:297-307          # Add Telegram, detach/reattach, escalation routing sections
Modify: install.sh:36-38               # Install fleet-watcher
Modify: README.md                       # Update for Telegram/detach features
```

Config files created at runtime:
```
~/.fleet/telegram.json                   # {"bot_token": "...", "chat_id": "..."}
_bridge/state.json                       # {"mode": "live|detached", "detached_at": "...", "watcher_pid": N}
_bridge/briefing.md                      # Accumulated events during detach
```

---

### Task 1: Telegram Setup Command

Add `fleet telegram setup` -- an interactive flow that configures the Telegram bot credentials.

**Files:**
- Modify: `fleet` (add `telegram` subcommand, ~15 lines)

- [ ] **Step 1: Add the telegram subcommand to fleet**

Add these functions before the `case` statement at the end of `fleet`, and add the case entry:

After the `cmd_info()` function (fleet:163), add:

```bash
# ── telegram ─────────────────────────────────────────────────────────
FLEET_CONFIG_DIR="${HOME}/.fleet"
TELEGRAM_CONFIG="${FLEET_CONFIG_DIR}/telegram.json"

cmd_telegram() {
  case "${1:-}" in
    setup) telegram_setup ;;
    send)  shift; telegram_send "$*" ;;
    test)  telegram_send "Fleet is connected. Ready to receive updates from $(basename "$REPO_ROOT")." ;;
    *)     err "Usage: fleet telegram setup|send|test"; exit 1 ;;
  esac
}

telegram_setup() {
  mkdir -p "$FLEET_CONFIG_DIR"
  echo ""
  log "Telegram Bot Setup"
  log "1. Open Telegram and message @BotFather"
  log "2. Send /newbot and follow the prompts"
  log "3. Copy the bot token below"
  echo ""
  read -rp "Bot token: " bot_token
  [ -z "$bot_token" ] && { err "Token required"; exit 1; }
  log "4. Open a chat with your new bot in Telegram and send any message"
  log "5. Press Enter once you've sent a message..."
  read -r
  local chat_id
  chat_id=$(curl -s "https://api.telegram.org/bot${bot_token}/getUpdates" | jq -r '.result[-1].message.chat.id // empty')
  [ -z "$chat_id" ] && { err "Could not detect chat ID. Did you message the bot?"; exit 1; }
  echo "{\"bot_token\":\"${bot_token}\",\"chat_id\":\"${chat_id}\"}" > "$TELEGRAM_CONFIG"
  log "Saved to ${TELEGRAM_CONFIG}"
  curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
    -d chat_id="$chat_id" -d text="Fleet connected! You'll receive updates here." -d parse_mode=Markdown > /dev/null
  log "Test message sent. Check Telegram!"
}

telegram_send() {
  [ ! -f "$TELEGRAM_CONFIG" ] && { err "Run 'fleet telegram setup' first"; exit 1; }
  local token chat_id
  token=$(jq -r .bot_token "$TELEGRAM_CONFIG")
  chat_id=$(jq -r .chat_id "$TELEGRAM_CONFIG")
  curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat_id" -d text="$1" -d parse_mode=Markdown > /dev/null
}
```

Update the usage line (fleet:8) to include new commands:

```
#   fleet telegram setup|send|test  |  fleet detach  |  fleet status
```

Update the case statement (fleet:167-175) to add:

```bash
  telegram) shift; cmd_telegram "$@" ;;
```

- [ ] **Step 2: Verify syntax and line count**

Run: `bash -n fleet && wc -l fleet`
Expected: Clean syntax, under 200 lines

- [ ] **Step 3: Test setup flow manually**

Run: `fleet telegram` (should show usage error)
Expected: `[fleet] Usage: fleet telegram setup|send|test`

- [ ] **Step 4: Commit**

```bash
git add fleet
git commit -m "Add fleet telegram setup/send/test commands

Interactive setup flow: BotFather token → auto-detect chat ID →
save to ~/.fleet/telegram.json → send test message. Also adds
fleet telegram send for manual messages and fleet telegram test
for verifying the connection."
```

---

### Task 2: The Watcher Script

Create `fleet-watcher` -- a standalone bash script that runs in the background during detached mode. It monitors worker status files, sends Telegram notifications on meaningful events, polls for inbound Telegram messages, and accumulates a briefing file.

**Files:**
- Create: `fleet-watcher`

- [ ] **Step 1: Create the watcher script**

Write `fleet-watcher`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# fleet-watcher - Background process for detached fleet mode
# Monitors worker status, sends Telegram notifications, polls for inbound messages.
# Started by `fleet detach`, killed by `fleet attach`.

BRIDGE_DIR="${1:?Usage: fleet-watcher <bridge_dir>}"
FLEET_CONFIG_DIR="${HOME}/.fleet"
TELEGRAM_CONFIG="${FLEET_CONFIG_DIR}/telegram.json"
POLL_INTERVAL="${FLEET_POLL_INTERVAL:-10}"
TELEGRAM_OFFSET_FILE="${BRIDGE_DIR}/.telegram_offset"
MTIME_DIR="${BRIDGE_DIR}/.watcher_mtimes"

mkdir -p "$MTIME_DIR"

# ── Telegram helpers ─────────────────────────────────────────────────
tg_configured() { [ -f "$TELEGRAM_CONFIG" ]; }

tg_send() {
  tg_configured || return 0
  local token chat_id
  token=$(jq -r .bot_token "$TELEGRAM_CONFIG")
  chat_id=$(jq -r .chat_id "$TELEGRAM_CONFIG")
  curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat_id" -d text="$1" -d parse_mode=Markdown > /dev/null 2>&1 || true
}

tg_poll() {
  tg_configured || return 0
  local token offset
  token=$(jq -r .bot_token "$TELEGRAM_CONFIG")
  offset=0
  [ -f "$TELEGRAM_OFFSET_FILE" ] && offset=$(cat "$TELEGRAM_OFFSET_FILE")
  local response
  response=$(curl -s "https://api.telegram.org/bot${token}/getUpdates?offset=${offset}&timeout=1" 2>/dev/null) || return 0
  local count
  count=$(echo "$response" | jq '.result | length') || return 0
  [ "$count" -eq 0 ] && return 0
  echo "$response" | jq -c '.result[]' | while read -r update; do
    local update_id text
    update_id=$(echo "$update" | jq -r '.update_id')
    text=$(echo "$update" | jq -r '.message.text // empty')
    echo $((update_id + 1)) > "$TELEGRAM_OFFSET_FILE"
    [ -z "$text" ] && continue
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo -e "\n---\n**Director via Telegram** (${now}):\n\n${text}" >> "${BRIDGE_DIR}/briefing.md"
    echo "{\"ts\":\"${now}\",\"event\":\"telegram_inbound\",\"detail\":\"${text}\"}" >> "${BRIDGE_DIR}/log/_watcher.jsonl"
    # Route simple commands to the most recent active worker's message file
    local latest_worker
    latest_worker=$(ls -t "${BRIDGE_DIR}/status/"*.json 2>/dev/null | head -1 | xargs -I{} basename {} .json)
    if [ -n "$latest_worker" ]; then
      echo -e "\n---\n**Director via Telegram** (${now}):\n\n${text}" >> "${BRIDGE_DIR}/messages/${latest_worker}.md"
    fi
  done
}

# ── Status monitoring ────────────────────────────────────────────────
check_status_changes() {
  for status_file in "${BRIDGE_DIR}/status/"*.json; do
    [ -f "$status_file" ] || continue
    local name mtime_file current_mtime saved_mtime
    name=$(basename "$status_file" .json)
    mtime_file="${MTIME_DIR}/${name}"
    current_mtime=$(stat -f %m "$status_file" 2>/dev/null || stat -c %Y "$status_file" 2>/dev/null)
    saved_mtime=0
    [ -f "$mtime_file" ] && saved_mtime=$(cat "$mtime_file")
    [ "$current_mtime" = "$saved_mtime" ] && continue
    echo "$current_mtime" > "$mtime_file"
    local phase summary needs_human
    phase=$(jq -r '.phase // empty' "$status_file")
    summary=$(jq -r '.summary // empty' "$status_file")
    needs_human=$(jq -r '.needs_human // false' "$status_file")
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    case "$phase" in
      done)
        local msg="*${name}* finished: ${summary}"
        tg_send "$msg"
        echo -e "\n- **${now}** -- ${name} completed: ${summary}" >> "${BRIDGE_DIR}/briefing.md"
        ;;
      blocked|failed)
        local escalation decision recommendation stakes
        decision=$(jq -r '.escalation.decision // empty' "$status_file")
        recommendation=$(jq -r '.escalation.recommendation // empty' "$status_file")
        stakes=$(jq -r '.escalation.stakes // "unknown"' "$status_file")
        if [ -n "$decision" ]; then
          local msg="*${name}* needs you (${stakes} stakes):\n\n${decision}\n\nRecommendation: ${recommendation}"
          tg_send "$msg"
        else
          local msg="*${name}* is ${phase}: ${summary}"
          tg_send "$msg"
        fi
        echo -e "\n- **${now}** -- ${name} ${phase}: ${summary}" >> "${BRIDGE_DIR}/briefing.md"
        ;;
      *)
        # Other phase changes (analyzing, implementing, testing) -- just record in briefing
        echo -e "\n- **${now}** -- ${name} moved to ${phase}: ${summary}" >> "${BRIDGE_DIR}/briefing.md"
        ;;
    esac
  done
}

# ── Main loop ────────────────────────────────────────────────────────
echo "{\"ts\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"event\":\"watcher_started\",\"detail\":\"Polling every ${POLL_INTERVAL}s\"}" >> "${BRIDGE_DIR}/log/_watcher.jsonl"

while true; do
  check_status_changes
  tg_poll
  sleep "$POLL_INTERVAL"
done
```

- [ ] **Step 2: Make executable and verify syntax**

Run: `chmod +x fleet-watcher && bash -n fleet-watcher && wc -l fleet-watcher`
Expected: Clean syntax, under 150 lines

- [ ] **Step 3: Commit**

```bash
git add fleet-watcher
git commit -m "Add fleet-watcher: background status monitor with Telegram I/O

Standalone script for detached mode. Polls worker status files for
changes, sends Telegram notifications on completions and blockers
with escalation context, polls Telegram for inbound director messages,
routes them to worker message files, and accumulates a briefing file
for reattach."
```

---

### Task 3: Detach and Reattach Commands

Add `fleet detach` (starts watcher, records state) and update `fleet attach` (kills watcher, triggers briefing).

**Files:**
- Modify: `fleet`

- [ ] **Step 1: Add detach command and update attach**

Add after the `telegram_send` function in fleet:

```bash
cmd_detach() {
  [ ! -d "$BRIDGE_DIR" ] && { err "No active fleet. Spawn workers first."; exit 1; }
  # Start watcher in background
  local watcher_path="${FLEET_INSTALL_DIR:-$HOME/.local/bin}/fleet-watcher"
  [ ! -f "$watcher_path" ] && watcher_path="$(dirname "$0")/fleet-watcher"
  [ ! -f "$watcher_path" ] && { err "fleet-watcher not found. Run install.sh."; exit 1; }
  "$watcher_path" "$BRIDGE_DIR" &
  local watcher_pid=$!
  local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"mode\":\"detached\",\"detached_at\":\"${now}\",\"watcher_pid\":${watcher_pid}}" > "${BRIDGE_DIR}/state.json"
  echo -e "# Fleet Briefing\n\nDetached at ${now}\n" > "${BRIDGE_DIR}/briefing.md"
  log "Fleet detached. Watcher running (PID ${watcher_pid})."
  [ -f "$TELEGRAM_CONFIG" ] && log "Telegram notifications active." || warn "No Telegram configured. Run 'fleet telegram setup' for notifications."
  log "Run 'fleet attach' to reattach with a briefing."
}
```

Replace the existing `cmd_attach` function:

```bash
cmd_attach() {
  # Kill watcher if running
  if [ -f "${BRIDGE_DIR}/state.json" ]; then
    local watcher_pid mode
    mode=$(jq -r '.mode // empty' "${BRIDGE_DIR}/state.json" 2>/dev/null)
    watcher_pid=$(jq -r '.watcher_pid // empty' "${BRIDGE_DIR}/state.json" 2>/dev/null)
    if [ "$mode" = "detached" ] && [ -n "$watcher_pid" ]; then
      kill "$watcher_pid" 2>/dev/null || true
      local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      echo "{\"mode\":\"live\",\"reattached_at\":\"${now}\",\"watcher_pid\":null}" > "${BRIDGE_DIR}/state.json"
      log "Watcher stopped. Reattached."
      if [ -f "${BRIDGE_DIR}/briefing.md" ]; then
        echo ""
        cat "${BRIDGE_DIR}/briefing.md"
        echo ""
      fi
    fi
  fi
  if tmux has-session -t "$SESSION" 2>/dev/null; then tmux attach -t "$SESSION"
  else err "No fleet session. Spawn one first: fleet spawn <name>"; exit 1; fi
}
```

Add `detach` to the case statement:

```bash
  detach)  cmd_detach ;;
```

Update the usage line to include detach:

```
#   fleet spawn <name> [--from ref] [--prompt "..." | --prompt-file path]
#   fleet stop [names...]  |  fleet attach  |  fleet detach  |  fleet ls
```

- [ ] **Step 2: Verify syntax and line count**

Run: `bash -n fleet && wc -l fleet`
Expected: Clean syntax. Will be over 200 lines now -- that's OK since we're adding significant new functionality. The 200-line guideline was for the plumbing-only script; Telegram + detach are new plumbing.

- [ ] **Step 3: Commit**

```bash
git add fleet
git commit -m "Add fleet detach/attach with watcher lifecycle management

fleet detach: starts fleet-watcher in background, records state and
PID, initializes briefing file.
fleet attach: kills watcher, shows accumulated briefing, reattaches
tmux session. Transitions between live and detached mode are seamless."
```

---

### Task 4: Update the Skill -- Telegram and Detach/Reattach

Add sections to the skill teaching the bridge how to use Telegram, route escalations, and handle reattach briefings.

**Files:**
- Modify: `skill/SKILL.md` (insert before the Principles section at the end)

- [ ] **Step 1: Add Telegram and detach/reattach sections to the skill**

Insert before the `## Principles` section (currently at line 299) in `skill/SKILL.md`:

```markdown
## Telegram Integration

When Telegram is configured (`~/.fleet/telegram.json` exists), you can send messages to the director at any time:

```bash
fleet telegram send "message text"
```

Use this for:
- Notifying the director when a worker completes or gets blocked
- Sending progress summaries
- Relaying escalation decisions that need input

Messages should be concise, actionable, and Markdown-formatted. Always include your recommendation when a decision is needed.

### Escalation Routing

Not every event needs the director's attention. Route by stakes:

| Stakes | Action |
|--------|--------|
| **Notification** | Worker done, tests passed, dispatched from queue → `fleet telegram send` (no response needed) |
| **Low** | Code style choice, naming, minor approach → decide autonomously, note in briefing |
| **Medium** | Approach choice, scope question → `fleet telegram send` with recommendation. Proceed with your recommendation after 30 min if no reply |
| **High** | Breaking change, business logic, irreversible → `fleet telegram send`, wait for reply. Do not proceed without director input |

### Detached Mode

When the director runs `fleet detach`, a background watcher monitors workers and sends Telegram notifications. Workers keep running in tmux.

While detached:
- Worker completions and blocks trigger Telegram notifications automatically
- Director replies via Telegram are written to `_bridge/messages/` for workers to read at checkpoints
- All events accumulate in `_bridge/briefing.md`

You don't need to do anything special for detached mode -- the watcher handles notification delivery.

### Reattach Briefing

When the director returns (`fleet attach`), they see the accumulated briefing. In your first response after reattach, present a structured summary:

```
Welcome back. Here's what happened while you were away:

Blocked (needs you now):
  - {session}: {escalation decision needed}

Completed:
  - {session}: {outcome, PR number if applicable}

In progress:
  - {session}: {current phase and summary}

Decisions I made:
  - {what you decided and why}

Discoveries:
  - {notable findings from workers}
```

Read `_bridge/briefing.md` and `_bridge/state.json` to detect if the director was detached. If `state.json` shows `"mode": "live"` with a recent `reattached_at`, present the briefing proactively.
```

- [ ] **Step 2: Verify line count**

Run: `wc -l skill/SKILL.md`
Expected: Under 400 lines (adding ~60 lines to current 307 = ~367)

- [ ] **Step 3: Commit**

```bash
git add skill/SKILL.md
git commit -m "Add Telegram, escalation routing, and detach/reattach to skill

Teaches the bridge: when and how to send Telegram notifications,
escalation routing by stakes (notification/low/medium/high), detached
mode behavior, and structured reattach briefing format."
```

---

### Task 5: Update install.sh

Add `fleet-watcher` to the installer.

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add fleet-watcher download**

After the existing fleet script download block (install.sh:28-38), add:

```bash
# Download fleet-watcher
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/mountagency/fleet/main/fleet-watcher" -o "$INSTALL_DIR/fleet-watcher"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$INSTALL_DIR/fleet-watcher" "https://raw.githubusercontent.com/mountagency/fleet/main/fleet-watcher"
fi
chmod +x "$INSTALL_DIR/fleet-watcher"
log "Installed fleet-watcher to $INSTALL_DIR/fleet-watcher"
```

- [ ] **Step 2: Update README manual install section**

In the manual install section of README.md, add:

```bash
cp fleet-watcher ~/.local/bin/fleet-watcher && chmod +x ~/.local/bin/fleet-watcher
```

- [ ] **Step 3: Commit**

```bash
git add install.sh README.md
git commit -m "Update installer and docs for fleet-watcher

install.sh now downloads fleet-watcher alongside fleet.
Manual install instructions updated."
```

---

### Task 6: Update README -- Telegram and Detach Features

Add Telegram setup and detach/reattach to the README examples and documentation.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a Telegram section after the tmux basics section**

Find the `## tmux basics` section in README.md. After it (and before `## Project type detection`), add:

```markdown
## Telegram notifications

Fleet can send you notifications via Telegram when workers complete, get blocked, or need decisions. You can reply from your phone.

### Setup

```bash
fleet telegram setup
```

This walks you through creating a Telegram bot and connecting it to Fleet. One-time setup.

### Detach / Reattach

```bash
fleet detach     # Fleet keeps working, notifications go to Telegram
fleet attach     # Come back, get a briefing of what happened
```

While detached:
- Workers keep running in tmux
- Completions and blockers trigger Telegram notifications
- You can reply via Telegram ("merge it", "use option A", "stop that worker")
- When you reattach, Claude gives you a structured briefing of everything that happened

This means you can start a fleet, walk to a meeting, approve a PR from your phone, and come back to find everything merged and the next batch of work in progress.
```

- [ ] **Step 2: Update the "What it looks like" conversation to show Telegram**

Add a Telegram example after the existing conversation example in the README. After the closing ``` of the current example, add:

```markdown

**From your phone (Telegram):**
```
Fleet:  "fix-calendar done. PR #84, tests green. Merge? [Yes / Review first]"
You:    "Yes"
Fleet:  "Merged. Dispatching next from queue: refactor-billing."

Fleet:  "auth-refactor needs a decision (high stakes):
         PKCE or auth code flow? I recommend PKCE -- simpler,
         better for mobile. Reply A or B."
You:    "A"
Fleet:  "Sent to auth-refactor. It'll pick up at next checkpoint."
```
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add Telegram and detach/reattach documentation to README

Setup instructions, detach/reattach flow, and Telegram conversation
example showing mobile-first direction of the fleet."
```

---

### Task 7: Final Verification

Verify everything works together.

**Files:**
- All modified files

- [ ] **Step 1: Verify bash syntax on all scripts**

Run:
```bash
bash -n fleet && echo "fleet: OK"
bash -n fleet-watcher && echo "fleet-watcher: OK"
bash -n install.sh && echo "install.sh: OK"
```
Expected: All OK

- [ ] **Step 2: Verify line counts**

Run: `wc -l fleet fleet-watcher skill/SKILL.md skill/WORKER_PROTOCOL.md`
Expected:
- `fleet`: under 230 lines (175 + ~50 for telegram/detach)
- `fleet-watcher`: under 150 lines
- `skill/SKILL.md`: under 400 lines
- `skill/WORKER_PROTOCOL.md`: unchanged (~109 lines)

- [ ] **Step 3: Test basic commands**

Run:
```bash
fleet --help
fleet telegram
fleet info
```
Expected:
- Help shows updated usage with telegram/detach
- `fleet telegram` shows usage error with setup/send/test options
- `fleet info` outputs valid JSON

- [ ] **Step 4: Verify install.sh references all files**

Run:
```bash
grep -c "fleet-watcher" install.sh
```
Expected: At least 2 (download + log)

- [ ] **Step 5: Local install test**

Run:
```bash
cp fleet ~/.local/bin/fleet
cp fleet-watcher ~/.local/bin/fleet-watcher
chmod +x ~/.local/bin/fleet-watcher
cp skill/SKILL.md ~/.claude/skills/fleet/SKILL.md
fleet --help
```
Expected: Updated help text

- [ ] **Step 6: Commit if any fixes needed**

If any verification step required fixes:
```bash
git add -A
git commit -m "Fix issues found during Layer 4 verification"
```

---

## Summary

| Task | Deliverable | Key change |
|---|---|---|
| 1 | `fleet` + telegram commands | Setup flow, send, test via Telegram Bot API |
| 2 | `fleet-watcher` | Background watcher: status monitoring, Telegram I/O, briefing accumulation |
| 3 | `fleet` + detach/attach | Start/stop watcher, state management, briefing display on reattach |
| 4 | `skill/SKILL.md` updates | Escalation routing, detached mode, reattach briefing format |
| 5 | `install.sh` + `README.md` | Install fleet-watcher |
| 6 | `README.md` | Telegram setup docs, detach flow, mobile conversation example |
| 7 | All files | Final verification |

## What's Next

This completes Layer 4. The remaining plan is:

- **Layer 5: Learning** -- Director model, execution patterns, codebase knowledge accumulation
