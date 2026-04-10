## Session: build-watch-cmd
Outcome: Committed to main (8167b48)

### What was done
- Added `cmd_watch` function to `fleet` script with 5 subcommands: start, stop, status, once, briefing
- Updated usage header and case statement to include watch command
- Updated `usage()` line range to include the new usage line

### Key decisions
- Used same script-lookup pattern as `fleet-watcher` (`FLEET_INSTALL_DIR` then `dirname $0`) for finding `fleet-watch-github`
- PID management via `_bridge/watch.pid` — simple, matches existing bridge file conventions
- Extra args passed through on `start` and `once` to support `--config`, `--repo` flags from the design doc

### Discoveries
- None — straightforward addition following established patterns

### Files changed
- `fleet` (43 lines added, 1 changed)
