# Module 10: Context OS — 5-Tier Architecture

> Use this module to understand the full context management system.
> The 5 tiers define what is loaded when, and how the context budget is managed.

<!-- agents-md-compat -->

---

## Overview

The Context OS makes the context window limit **invisible** to the agent. Instead of manually managing what fits, the system automatically routes the right context at the right time using tiered loading.

```
┌──────────────────────────────────────────┐
│ T0: HOT    — always loaded               │ max 400 tokens
│   state-of-system-now.md                 │
│   checklist-now.md                       │
├──────────────────────────────────────────┤
│ T1: WARM   — loaded at BOOT              │ max 800 tokens
│   MEMORY.md index                        │
│   frozen-fragments.md (paths only)       │
├──────────────────────────────────────────┤
│ T2: COOL   — loaded on-demand (ROUTE)    │ max 1500 tokens
│   decisions.md, pitfalls.md,             │
│   preferences.md, observations.md,       │
│   topic files                            │
├──────────────────────────────────────────┤
│ T3: COLD   — never auto-loaded           │ no budget
│   session-log.md, wal.log,               │
│   gc-archive.md, memory-overflow.md      │
├──────────────────────────────────────────┤
│ T4: FROZEN — protected by PreToolUse     │ immutable
│   Files in frozen-fragments.md           │
│   Cannot be edited by any tool           │
└──────────────────────────────────────────┘
```

## Tier Details

### T0: HOT (Always Loaded)

Loaded by `hooks/rehydrate.sh` at every SessionStart.

| File | Purpose | Budget |
|------|---------|--------|
| `state-of-system-now.md` | Current system state, blockers, confidence | ~200 tokens |
| `checklist-now.md` | Active task checklist | ~200 tokens |

**Rule**: T0 must fit in 400 tokens. If larger, trim.

### T1: WARM (Boot-Time)

Loaded by `hooks/rehydrate.sh` at SessionStart.

| File | Purpose | Budget |
|------|---------|--------|
| `MEMORY.md` | Project memory index (capped at 200 lines) | ~600 tokens |
| `frozen-fragments.md` | Path list only (not content) | ~200 tokens |

**Rule**: T1 is the memory index. It tells the agent what exists, not the full content.

### T2: COOL (On-Demand)

Loaded by `hooks/preprocess-prompt.sh` or `hooks/smart-preprocess-v2.sh` based on prompt analysis.

| Selection Method | Hook | Accuracy |
|------------------|------|----------|
| Keyword + trigram matching | `preprocess-prompt.sh` | ~70% |
| Haiku semantic routing | `smart-preprocess-v2.sh` | ~85% |

**Rule**: T2 budget is 1500 tokens max. Selected files are ranked and packed under budget.

### T3: COLD (Never Auto-Loaded)

Only accessed if the agent explicitly reads them.

| File | Purpose |
|------|---------|
| `session-log.md` | Historical session summaries |
| `wal.log` | Write-ahead log of destructive actions |
| `gc-archive.md` | Garbage-collected memory entries |
| `memory-overflow.md` | MEMORY.md overflow content |

**Rule**: T3 files are for audit and recovery. The agent can read them, but they're never injected.

### T4: FROZEN (Immutable)

Protected by `hooks/check-frozen.sh` PreToolUse hook.

- Files listed in `frozen-fragments.md` cannot be modified
- Covers: Edit, Write, Bash (including sed, cp, mv, tee, etc.)
- [USER] tag ensures entries survive garbage collection

## Total Budget

```
T0 (HOT)   =  400 tokens (always)
T1 (WARM)  =  800 tokens (boot)
T2 (COOL)  = 1500 tokens (per-prompt)
─────────────────────────
Total      = 2700 tokens maximum auto-injection

Context window = 200,000 tokens
Budget ratio   = 1.35% (well under 15% safety limit)
```

## Confidence Gate

Dangerous operations (deploy, migrate, restart) are gated by system confidence:

| CONF Range | Action |
|------------|--------|
| >= 0.70 | Allow |
| < 0.70 | BLOCK (exit 2) — update state first |
| No CONF data | Allow (fail-open) |

Hook: `hooks/confidence-gate.sh` (PreToolUse, Bash matcher).

## ARC Ghost Tracking

When the agent manually reads a file that wasn't injected by T2, it's recorded in `ghost-hits.log`. On the next prompt, these files get a +4 score boost, making them more likely to be injected.

This creates a feedback loop: the system learns which files the agent actually needs.

## Lifecycle

```
SessionStart → T0 + T1 loaded (rehydrate.sh)
UserPrompt   → T2 routing (preprocess-prompt.sh or smart-preprocess-v2.sh)
PreToolUse   → T4 protection (check-frozen.sh) + confidence gate
PostToolUse  → Circuit breaker tracking
Stop         → Memory compiler (GC + index) + observer (compression)
```

## Setup

```bash
# Full Context OS with Haiku routing:
bash setup.sh /path/to/project --profile smart-v2

# Context OS with keyword routing only:
bash setup.sh /path/to/project --profile aion-runtime
```

---

*See [07-smart-context](07-smart-context.md) for routing details, [09-memory-compiler](09-memory-compiler.md) for GC pipeline, [04-enforcement](04-enforcement.md) for hook mechanics.*
