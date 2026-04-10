## Session: build-session-digests
Outcome: committed

### What was done
- Updated WORKER_PROTOCOL.md to require workers output both JSON and markdown session digests
- Updated SKILL.md Session Distillation section with bridge-side indexing instructions
- Created .fleet/index/sessions.json as empty index file

### Key decisions
- Workers write both JSON and markdown directly (no generation step)
- Replaced verbose markdown template in SKILL.md with compact numbered steps to stay under 400-line limit

### Discoveries
- SKILL.md on main already had the updated Session Distillation (from commit 4218102)

### Files changed
- skill/WORKER_PROTOCOL.md
- skill/SKILL.md
- .fleet/index/sessions.json
- .fleet/sessions/build-session-digests.json
- .fleet/sessions/build-session-digests.md
