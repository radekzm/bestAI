# Module 05: CS Algorithms for AI Agents

> Use this module when implementing robust agent behaviors.
> P0 algorithms include full implementation details (Problem → CS Origin → Agent Implementation → Hook/Rule).
> P1/P2 algorithms provide conceptual mapping for future implementation.

<!-- agents-md-compat -->

---

## P0: Critical (implement first)

### 1. Circuit Breaker Pattern

- **Problem**: Agent retries failing operation endlessly (150 rails runner errors in 40 sessions)
- **CS Origin**: Michael Nygard, "Release It!" (2007), distributed systems
- **States**: CLOSED (normal) → OPEN (failing, block calls) → HALF-OPEN (test one call)
- **Agent Implementation**: Track consecutive failures per error pattern. After N failures → STOP → show alternative → ask user
- **Hook**: PostToolUse (advisory) — tracks failures in `~/.cache/claude-circuit-breaker/`, injects STOP guidance into context after threshold. For deterministic blocking, pair with a PreToolUse hook that checks state.

```bash
# hooks/circuit-breaker.sh — see hooks/ directory for full implementation
# Tracks: pattern → failure_count → state (CLOSED/OPEN/HALF-OPEN)
# OPEN state: advisory output telling agent to STOP + ROOT_CAUSE_TABLE
# HALF-OPEN: allow 1 attempt, if success → CLOSED
# NOTE: PostToolUse = advisory (context injection), not deterministic block
```

### 2. Write-Ahead Log (WAL)

- **Problem**: Destructive action without rollback; memory lost after compaction
- **CS Origin**: Database systems (PostgreSQL, SQLite) — log intent before execution
- **Agent Implementation**: Before any destructive action → write intent + timestamp to WAL file
- **Hook**: PreToolUse on Bash|Write|Edit — append to `~/.claude/projects/<project>/wal.log`

```
WAL Entry Format:
[2026-02-23T14:32:01] [LSN:47] [DESTRUCTIVE] [BASH] rm -rf /tmp/old-cache
[2026-02-23T14:35:22] [LSN:48] [WRITE] [FILE] src/auth/login.ts
[2026-02-23T14:36:05] [LSN:49] [MODIFY] [BASH] git commit -m "fix auth"
```

**Recovery**: After compaction or `/clear`, SessionStart hook reads WAL from last checkpoint.

### 3. ARC (Adaptive Replacement Cache)

- **Problem**: Context window fills with stale/irrelevant information
- **CS Origin**: IBM Research, Megiddo & Modha (2003) — dynamically partitions cache between LRU and LFU sublists
- **Agent Implementation**: Track both recently-used and frequently-used context files. Maintain "ghost lists" (B1, B2) — what was evicted and later needed
- **Application**: Memory eviction policy; smart context preprocessor scoring

```
ARC-inspired heuristic for AI agents:
- T1 (recent): files loaded in current/last session
- T2 (frequent): files loaded in 3+ sessions
- B1 (ghost-recent): recently evicted files agent later needed
- B2 (ghost-frequent): frequently used files agent later needed
- Adaptive: ghost list hits shift the partition point (not a weighted score)
Note: This is an ARC-inspired heuristic, not a faithful ARC implementation.
```

### 4. Exponential Backoff + Jitter

- **Problem**: Repeated retries with same approach; "correction loop" anti-pattern
- **CS Origin**: Ethernet CSMA/CD, AWS retry recommendations
- **Agent Implementation**: Graduated escalation instead of binary retry/stop
- **Rule**: In CLAUDE.md or hook

```
Attempt 1: Retry with minor fix
Attempt 2: Reframe approach (different angle — "jitter")
Attempt 3: Delegate to subagent for independent assessment
Attempt 4: STOP + ROOT_CAUSE_TABLE (what tried | why failed | what to try next)
```

## P1: Recommended

### 5. Copy-on-Write (CoW)

- **Problem**: Subagent gets full memory copy or nothing; risk of overwriting [USER] entries
- **CS Origin**: OS process forking (fork(), ZFS, Btrfs)
- **Application**: Subagent starts with read-only reference to main memory. Writes go to local delta. After completion: merge delta if no [USER] conflicts

### 6. PID Controller

- **Problem**: Static compaction thresholds (50%/70%) don't adapt to project type
- **CS Origin**: Control theory — Proportional-Integral-Derivative feedback loop
- **Application**: Adaptive context budget. P = current occupancy vs target. I = cumulative trend. D = rate of change. Output: when to compact, split session, or delegate

### 7. Bloom Filter

- **Problem**: Preprocessor must scan all memory files for relevance
- **CS Origin**: Probabilistic data structure — O(1) "definitely not" or "maybe yes"
- **Application**: Quick pre-screening of memory files before loading. ~1KB for 1000 keywords, ~1% false positive rate. Eliminates unnecessary file reads

### 8. Feature Flags / Canary Deploy

- **Problem**: New rules may be wrong; need gradual rollout
- **CS Origin**: MLOps / deployment strategies — gradual rollout with metrics
- **Application**: New [AUTO] entries start with CONF: 0.5. After 5 sessions where agent uses and succeeds → CONF += 0.1. After failure → CONF -= 0.2. Below 0.3 → auto-remove. Above 0.8 → promote to FROZEN

### 9. Dead Code Elimination

- **Problem**: CLAUDE.md accumulates rules that never activate
- **CS Origin**: Compiler optimization — remove code with no effect on output
- **Application**: Session Intelligence tracks which rules were actually used. After 30 days unused → mark as CANDIDATE_FOR_REMOVAL → show user → decide: remove / keep / move to Skills

### 10. Generational GC

- **Problem**: Memory entries grow without bound; stale entries waste context
- **CS Origin**: Java/Go garbage collection — young/old generation with different policies
- **Application**: New entries = "young" (review after 7 days). Used 5+ sessions = "old" (review after 30 days). [USER] = "permanent roots" (never auto-collected)

## Algorithm Selection Guide

| Situation | Algorithm | Priority |
|-----------|-----------|----------|
| Agent repeats same error | Circuit Breaker | P0 |
| Need audit trail / recovery | WAL | P0 |
| Context routing optimization | ARC | P0 |
| Correction loop (2+ fails) | Exponential Backoff | P0 |
| Subagent memory safety | Copy-on-Write | P1 |
| Auto-tuning thresholds | PID Controller | P1 |
| Fast context pre-screening | Bloom Filter | P1 |
| Gradual rule rollout | Feature Flags | P1 |
| Reducing CLAUDE.md bloat | Dead Code Elimination | P1 |
| Cleaning stale memory | Generational GC | P2 |

## Key Insight

> Both bestAI and AION already implement intuitive versions of these algorithms:
> - Progressive disclosure = Demand Paging / Huffman coding
> - [USER]/[AUTO] tags = Elitism (protected roots)
> - DRAFT/REVIEWED/FROZEN = Finite State Machine
> - "3 batches → STOP" = Circuit Breaker (simplified)
>
> **The difference**: A formal algorithm is DETERMINISTIC, MEASURABLE, and has PROVEN properties. Intuition works ~60% of the time. Algorithms work ~95%+.

---

*See [hooks/circuit-breaker.sh](../hooks/circuit-breaker.sh) and [hooks/wal-logger.sh](../hooks/wal-logger.sh) for implementations.*
