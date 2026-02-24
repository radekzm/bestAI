# SESSION STATE TEMPLATE

> Alias for `state-of-system-now.md`. Use this when creating a new project's session state file.
> Place as `.claude/state-of-system-now.md` in your project.

# STATE OF SYSTEM

## Timestamp
- updated_utc: 1970-01-01T00:00:00Z

## TOP-10 FACTS
1. [USER][FAKT] [load-bearing fact] — source: [file/decision], CONF: 0.95
2. [AUTO][OBSERWACJA] [validated observation] — source: [evidence], CONF: 0.80

## TOP-5 PROOFS
- [P1] [path/link] — [what this proves]

## TOP-3 BLOCKERS
1. DATA: [NEED_DATA / STALE_DATA] — [evidence]
2. TECH: [BUILD_ERROR / DEPLOY_FAIL / API_REJECT] — [evidence]
3. EXTERNAL: [BLOCKED_EXTERNAL] — [dependency]

## NEXT GOAL
- -> Checklist_Now: [phase] (step X = [description])

## CONFIDENCE
- 0.70
- To increase confidence: [what evidence is needed]

## LAST SESSION DELTA (auto)
- updated_utc: 1970-01-01T00:00:00Z
- changed_files:
  - (none)
