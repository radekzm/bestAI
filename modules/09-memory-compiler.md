# Module 09: Memory Compiler

> Use this module to understand the automatic memory management pipeline:
> scoring, indexing, garbage collection, and the 200-line MEMORY.md cap.

<!-- agents-md-compat -->

---

## Overview

The Memory Compiler runs as a **Stop hook** (`hooks/memory-compiler.sh`) at the end of each session. It maintains memory health automatically, preventing unbounded growth while preserving critical user decisions.

## Pipeline

```
Session End (Stop hook)
  │
  ├─ 1. Increment session counter (.session-counter)
  │
  ├─ 2. Score each memory file
  │     score = base_weight + recency_bonus + usage_count - age_penalty
  │
  ├─ 3. Generate context-index.md
  │     Sorted index with topic clusters: core, decisions, operational, other
  │
  ├─ 4. Enforce 200-line cap on MEMORY.md
  │     Overflow → memory-overflow.md topic file
  │
  └─ 5. Generational GC
        young (0-3) / mature (3-10) / old (10+) / permanent ([USER])
        Old [AUTO] entries with low usage → gc-archive.md
```

## Scoring Formula

| Component | Value | Description |
|-----------|-------|-------------|
| `base_weight` | 10 for `[USER]`, 5 for `[AUTO]` | User decisions always outweigh auto-generated |
| `recency_bonus` | +3 (≤3 sessions), +1 (3-10), 0 (10+) | Recently used files score higher |
| `usage_count` | +N | Each access increments count |
| `age_penalty` | -5 if >20 sessions without use (AUTO only) | Old unused entries decay |

## Generational GC

Inspired by JVM generational garbage collection:

| Generation | Age (sessions) | Policy |
|------------|---------------|--------|
| **Young** | 0-3 | Keep — too new to evaluate |
| **Mature** | 3-10 | Keep — established utility |
| **Old** | 10+ | GC candidate if AUTO + low usage |
| **Permanent** | Any | `[USER]` tagged — NEVER auto-deleted |

GC threshold: configurable via `MEMORY_COMPILER_GC_AGE` env var (default: 20 sessions).

## Files Managed

| File | Purpose |
|------|---------|
| `.session-counter` | Monotonic session counter |
| `.usage-log` | Per-file usage tracking (TSV) |
| `context-index.md` | Auto-generated sorted index |
| `gc-archive.md` | Archive of GC'd entries |
| `memory-overflow.md` | MEMORY.md overflow content |

## Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `MEMORY_COMPILER_DRY_RUN` | `0` | Print actions without executing |
| `MEMORY_COMPILER_GC_AGE` | `20` | Sessions without use before GC |

## Integration

### With preprocess-prompt.sh

The Memory Compiler generates `context-index.md` which the Smart Context compiler uses for faster file discovery and scoring.

### With Smart Preprocess v2

The context-index.md serves as the "menu" that Haiku reads to decide which files to load (see module 07, Approach B).

## Safety Guarantees

1. `[USER]` entries are **never** auto-deleted
2. GC'd entries are preserved in `gc-archive.md` (recoverable)
3. MEMORY.md overflow is preserved in `memory-overflow.md`
4. Dry-run mode available for testing: `MEMORY_COMPILER_DRY_RUN=1`

---

*See [07-smart-context](07-smart-context.md) for the retrieval pipeline, [03-persistence](03-persistence.md) for memory tagging conventions.*
