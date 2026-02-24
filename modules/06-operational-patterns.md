# Module 06: Operational Patterns — Discipline & Anti-Loop

> Use this module when you need structured operational discipline for AI agents.
> Patterns derived from AION-NEOVERSE Constitution v3 and production experience.

<!-- agents-md-compat -->

---

## REHYDRATE — Cold Start Recovery

When starting a new session or after `/clear`, the agent must recover context immediately.

### Pattern

```
SessionStart:
  1. Read memory index (max 8 lines with file pointers)
  2. Direct read only listed files (target: 4 files, zero globs)
     - Constitution / core rules
     - State_Of_System_Now
     - Checklist_Now
     - Avatar / role profile
  3. Confirm loaded context in one short status block
  → Deterministic bootstrap, no file discovery overhead.
```

### Implementation (SessionStart hook)

```bash
#!/bin/bash
# hooks/rehydrate.sh — minimal implementation (reads 2 core files)
# Extend with session-log.md and WAL reads for full REHYDRATE
MEMORY_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory"
WAL_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')"
[ ! -d "$MEMORY_DIR" ] && exit 0

echo "=== SESSION REHYDRATE ==="
# Step 1: MEMORY.md (always)
[ -f "$MEMORY_DIR/MEMORY.md" ] && head -50 "$MEMORY_DIR/MEMORY.md"
# Step 2: Frozen files (always)
[ -f "$MEMORY_DIR/frozen-fragments.md" ] && {
  echo "--- FROZEN FILES (do not edit) ---"
  grep -E '^\s*-\s*`' "$MEMORY_DIR/frozen-fragments.md" | head -10
}
# Step 3: Session log (optional — uncomment to enable)
# [ -f "$MEMORY_DIR/session-log.md" ] && tail -20 "$MEMORY_DIR/session-log.md"
# Step 4: WAL recovery (optional — uncomment to enable)
# [ -f "$WAL_DIR/wal.log" ] && { echo "--- WAL (last 10) ---"; tail -10 "$WAL_DIR/wal.log"; }
echo "=== END REHYDRATE ==="
exit 0
```

## Anti-Loop Escalation

### The Problem

Agent retries the same failing approach endlessly ("digital punding" — GH #6549). Data: 150 identical rails runner errors across 40 sessions.

### Pattern: 3 Batches → STOP → ROOT_CAUSE_TABLE

```
Batch 1: Execute task normally
  └─ Failure? → Minor adjustment, retry
Batch 2: Adjusted approach
  └─ Failure? → Different strategy
Batch 3: Alternative strategy
  └─ Failure? → HARD STOP

ROOT_CAUSE_TABLE:
| What I Tried          | Why It Failed           | What To Try Next       |
|-----------------------|-------------------------|------------------------|
| inline rails runner   | bash quoting breaks     | write to /tmp/script.rb|
| direct SQL query      | permission denied       | use rails console      |
| API call              | timeout at 30s          | increase timeout/batch |
```

**Agent must NEVER continue past 3 failed batches without user approval.**

## SYNC_STATE — End-of-Task Synchronization

After completing a task or before ending a session:

```
1. Update State (TOP-10 FACTS / TOP-5 PROOFS / TOP-3 BLOCKERS)
2. Update MEMORY.md + session-log.md
3. Replace `LAST SESSION DELTA` (5-10 lines max)
4. Move overflow evidence to `/docs/PROOFS/<AREA>_<YYYYMMDD>.md`
5. Commit if stable and report status
```

## Blocker Taxonomy (canonical names)

| Group | Canonical blockers |
|------|---------------------|
| DATA | `STALE_DATA`, `NEED_DATA` |
| TECH | `BUILD_ERROR`, `DEPLOY_FAIL`, `API_REJECT` |
| PRODUCT | `UX_UNCLEAR`, `SCOPE_CREEP`, `VALUE_UNPROVEN` |
| EXTERNAL | `BLOCKED_EXTERNAL` |
| BUSINESS | `PRICING_UNVALIDATED`, `MARKET_FIT_UNKNOWN` |

## Checklist-Driven Work

### Pattern

One active checklist at a time. Each item has:
- Clear scope (what files, what change)
- Verification method (how to test)
- NEXT GOAL clearly stated

```markdown
## Current Checklist

- [x] Fix authentication token expiry
- [x] Add tests for token refresh
- [ ] **NEXT: Deploy to staging** ← clearly marked
- [ ] Verify on staging
- [ ] Merge to main
```

### Rule: Scope Before Action

Before starting any task:
1. State the scope (which files, which changes)
2. State the verification (how to test success)
3. State the rollback plan (if it fails)

## CONF Scoring (Confidence)

**WARNING**: LLM self-assessed confidence is NOT calibrated. Use CONF as a communication signal, NOT as a reliable metric.

| CONF Range | Meaning | Action |
|------------|---------|--------|
| 0.9-1.0 | Very high confidence | Proceed, but verify |
| 0.7-0.9 | Good confidence | Proceed with extra testing |
| 0.5-0.7 | Moderate confidence | Present options to user |
| < 0.5 | Low confidence | **STOP — ask user for guidance** |

**Best practice**: Combine CONF with evidence. "CONF: 0.85 — tested with 3 cases" is useful. "CONF: 0.85" alone is not.

## DEVIL'S ADVOCATE Pattern

For critical decisions (architecture, data model, security):

```
1. Agent proposes solution
2. Agent MUST argue AGAINST own proposal (find 3 weaknesses)
3. Present both sides to user
4. User decides
```

This prevents confirmation bias and groupthink in agent teams.

## Operational Rules Summary

| Rule | From | Enforcement |
|------|------|-------------|
| REHYDRATE on session start | AION | SessionStart hook |
| Max 3 failed batches → STOP | AION | Circuit Breaker hook |
| SYNC_STATE at task end | AION | Stop hook / manual |
| 1 active checklist | AION | CLAUDE.md rule |
| Scope before action | Best practice | CLAUDE.md rule |
| CONF < 0.5 → ask user | AION | CLAUDE.md rule (advisory) |
| DEVIL'S ADVOCATE for critical | AION | CLAUDE.md rule (advisory) |
| [USER] never overridden | bestAI | CLAUDE.md rule + hook |

## Integration with CS Algorithms

| Pattern | CS Algorithm | Module |
|---------|-------------|--------|
| Anti-loop 3 batches | Circuit Breaker | [05-cs-algorithms](05-cs-algorithms.md) |
| REHYDRATE 4 files | Bootstrap/Cold Start | This module |
| SYNC_STATE commit | WAL checkpoint | [05-cs-algorithms](05-cs-algorithms.md) |
| CONF scoring | Feature Flags | [05-cs-algorithms](05-cs-algorithms.md) |
| DEVIL'S ADVOCATE | Adversarial validation | This module |

---

*See [04-enforcement](04-enforcement.md) for hook implementations, [05-cs-algorithms](05-cs-algorithms.md) for formal algorithms.*
