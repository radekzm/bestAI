# Migration Guide — Existing Project -> bestAI

## Goal
Move from a monolithic prompt file to a deterministic context system with hooks, memory, and runtime discipline.

## Checklist
1. Backup current `CLAUDE.md`.
2. Measure size: `wc -l CLAUDE.md`.
3. Extract critical rules (`MUST`, `NEVER`, `ALWAYS`) and map to hooks.
4. Split non-critical content into topic docs/skills.
5. Keep `CLAUDE.md` as trigger index (target <= 120 lines).
6. Build memory files (`MEMORY.md`, `decisions.md`, `preferences.md`, `pitfalls.md`, `frozen-fragments.md`).
7. Install hooks with setup:
   - default: `bash setup.sh /path/to/project`
   - runtime: `bash setup.sh /path/to/project --profile aion-runtime`
8. Merge hook config into existing `.claude/settings.json` (default behavior).
9. Run diagnostics: `bash doctor.sh /path/to/project`.
10. Validate behavior on 3 representative tasks.

## Decision Extraction Sources
- Git log (`git log --oneline --since="90 days ago"`)
- Code comments with rationale
- Issue/PR descriptions
- Existing runbooks and README

Use tags:
- `[USER]` for explicit user decisions (never auto-overwrite)
- `[AUTO]` for agent observations (revisable with evidence)

## Hook Selection Quick Map
| Need | Hook |
|------|------|
| Protect critical files | `check-frozen.sh` |
| Enforce backup before destructive ops | `backup-enforcement.sh` |
| Anti-loop detection (advisory) | `circuit-breaker.sh` |
| Anti-loop strict blocking | `circuit-breaker-gate.sh` |
| Smart context injection | `preprocess-prompt.sh` |
| Session bootstrap | `rehydrate.sh` |
| Session state sync | `sync-state.sh` |

## Success Checks
- `doctor.sh`: no FAIL items
- `tests/test-hooks.sh`: all tests pass
- Always-loaded docs <= 10-15% of context window (heuristic)
- No repeated failure loops beyond 3 attempts
