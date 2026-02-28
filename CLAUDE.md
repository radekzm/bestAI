# bestAI — Guidelines for AI Agents v7.1

> Modular, evidence-based guidelines. Hooks enforce, CLAUDE.md guides.

## Quick Start

1. Read relevant module from `modules/` (see table below)
2. Apply hooks from `hooks/` for deterministic enforcement
3. Use templates from `templates/` for new projects

## Modules (Consolidated v7.0)

| Module | Topic | Maturity | Use When |
|--------|-------|----------|----------|
| [01-core](modules/01-core.md) | CORE | Stable | Fundamentals, architecture, persistence, enforcement, memory |
| [02-operations](modules/02-operations.md) | OPERATIONS | Stable | Sessions, patterns, prompt caching |
| [03-advanced](modules/03-advanced.md) | ADVANCED | Mixed | Smart context (stable), RAG/orchestration (preview) |

Maturity: **Stable** = tested in production, has hooks + tests. **Preview** = documented, partial implementation.

## Core Principle

```
CLAUDE.md = guidance (advisory — 6% compliance in production)
Hooks with exit 2 = enforcement
  Edit/Write: deterministic (exact path match, cannot be bypassed)
  Bash:       best-effort (pattern matching, covers common cases)
Critical rules → hooks.  Style/preferences → CLAUDE.md.
```

## Evidence

Based on Nuconic case study: 234 sessions, 16,761 tool calls, 29 days.
