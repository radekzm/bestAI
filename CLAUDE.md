# bestAI — Guidelines for AI Agents v3.0

> Modular, evidence-based guidelines. Hooks enforce, CLAUDE.md guides.

## Quick Start

1. Read relevant module from `modules/` (see table below)
2. Apply hooks from `hooks/` for deterministic enforcement
3. Use templates from `templates/` for new projects

## Module Index

| # | Module | Use When |
|---|--------|----------|
| 00 | [Fundamentals](modules/00-fundamentals.md) | Context engineering, token budget |
| 01 | [File Architecture](modules/01-file-architecture.md) | Tool hierarchy, CLAUDE.md structure |
| 02 | [Session Management](modules/02-session-management.md) | Compaction, subagents, /clear |
| 03 | [Persistence](modules/03-persistence.md) | Memory system, [USER]/[AUTO] tags |
| 04 | [Enforcement](modules/04-enforcement.md) | Hooks, frozen files, compliance |
| 05 | [CS Algorithms](modules/05-cs-algorithms.md) | Circuit Breaker, WAL, ARC |
| 06 | [Operational Patterns](modules/06-operational-patterns.md) | Anti-loop, REHYDRATE, checklists |
| 07 | [Smart Context](modules/07-smart-context.md) | Semantic routing (optional) |
| 08 | [Advanced](modules/08-advanced.md) | Vector DB, agent teams (experimental) |
| 09 | [Memory Compiler](modules/09-memory-compiler.md) | GC, scoring, context-index |
| 10 | [Context OS](modules/10-context-os.md) | 5-tier architecture, budget management |
| 11 | [Prompt Caching](modules/11-prompt-caching.md) | Stable prefix, cached token metrics |

## Core Principle

```
CLAUDE.md = guidance (advisory — 6% compliance in production)
Hooks with exit 2 = enforcement (deterministic — cannot be bypassed)
Critical rules → hooks.  Style/preferences → CLAUDE.md.
```

## Evidence

Based on Nuconic case study: 234 sessions, 16,761 tool calls, 29 days.
