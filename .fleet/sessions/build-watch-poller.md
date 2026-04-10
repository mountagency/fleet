## Session: build-watch-poller
Outcome: committed fleet-watch-github script

### What was done
- Created `fleet-watch-github` (135 lines) -- GitHub event poller for Fleet Watch
- Polls issues, PRs, and failed CI runs via `gh api` with ETag-conditional requests
- Writes new events to `_bridge/watch-events/{type}-{number}.json`
- Appends new events to `_bridge/watch-briefing.md`
- Sends Telegram notifications for new events
- Tracks seen event IDs in `_bridge/watch-state.json` to avoid reprocessing
- Configurable poll interval via `WATCH_POLL_INTERVAL` env var (default 60s)

### Key decisions
- Used `gh api --include` to get response headers for ETag extraction
- Separate field extraction for runs vs issues/pulls due to different JSON structures
- Atomic state file updates via tmp + mv to prevent corruption

### Discoveries
- `gh api --include` returns HTTP headers followed by a blank line then the JSON body

### Files changed
- `fleet-watch-github` (new)
