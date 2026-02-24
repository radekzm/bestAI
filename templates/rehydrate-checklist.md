# REHYDRATE Checklist

> Quick reference for cold-start bootstrap. Full protocol: `modules/06-operational-patterns.md`.
> Hook implementation: `hooks/rehydrate.sh` (SessionStart).

## On Session Start

1. Read memory index (MEMORY.md, max 8 lines with file pointers)
2. Direct read only listed files (target: 4 files, zero globs):
   - **CLAUDE.md** — core rules and project config
   - **state-of-system-now.md** — TOP-10 FACTS / TOP-5 PROOFS / TOP-3 BLOCKERS
   - **checklist-now.md** — active task checklist with NEXT GOAL
   - **frozen-fragments.md** — files that must not be edited
3. Confirm loaded context: `REHYDRATE: DONE | LOADED: N files`

## Rules

- **ZERO GLOBS** — paths come from memory, no file discovery overhead
- **Max 40 lines per file** (configurable via `REHYDRATE_MAX_LINES`)
- **Parallel reads** where possible to minimize latency
- If a listed file is missing: note `NEED-DATA: [filename]`, continue with rest

## After REHYDRATE

- Check LAST SESSION DELTA for recent changes
- Check TOP-3 BLOCKERS for unresolved issues
- Check NEXT GOAL in checklist for where to resume

## Before `/clear` or Session End

Run SYNC_STATE (see `hooks/sync-state.sh`):
1. Update State (TOP-10/5/3)
2. Update MEMORY.md + session-log.md
3. Replace LAST SESSION DELTA (5-10 lines max)
4. Commit if stable
