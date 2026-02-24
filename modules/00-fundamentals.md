# Module 00: Context Engineering Fundamentals

> Use this module when you need to understand WHY context management matters
> and what principles govern effective AI agent behavior.

<!-- agents-md-compat -->

---

## Core Definition

> "Context engineering is curating what the model sees so that you get a better result."
> — Martin Fowler, 2026

Context = EVERYTHING the model sees: system prompt, tool definitions, retrieved docs, message history, tool results. Managing this is the single most impactful skill for AI CLI agents.

## 5 Immutable Principles

| # | Principle | Why | Consequence |
|---|-----------|-----|-------------|
| 1 | **Less = better** | U-shaped attention curve (model loses middle) | Max 25% context for "instructions", 75% free for reasoning |
| 2 | **Correctness > completeness > size** | False info worse than missing info | Verify before saving. Never save speculation |
| 3 | **Lazy loading, not removal** | Agent needs awareness of WHAT exists, not all DETAILS | CLAUDE.md = trigger index, Skills = details on-demand |
| 4 | **Deterministic > advisory** | CLAUDE.md = "please do", Hook = "MUST do" | Critical rules → Hooks, rest → CLAUDE.md |
| 5 | **Semantic > literal** | "Fix login" ≠ grep "login" | Semantic search > keyword match |

## Context Budget (200k tokens)

```
IDEAL DISTRIBUTION:
  System prompt + tools    ~10%
  CLAUDE.md + MEMORY.md     ~5%
  Smart Context (injected)  ~5%
  User prompt + history     ~5%
  FREE for reasoning       ~75%
```

**Key metric**: Claude Code auto-compacts at ~64-75% fill. Stopping at 75% leaves ~50k tokens free for reasoning quality.

## Context Quality Hierarchy

1. **Correctness** — false information is worst
2. **Completeness** — missing information
3. **Size** — excess noise

## What Eats Context (ranked)

| Operation | Consumption | Mitigation |
|-----------|------------|------------|
| File searching (many files) | Very high | Delegate to subagent |
| Understanding code flow | High | Save summaries to file |
| Test/build logs | High | Filter to relevant sections |
| Large JSON from tools | High | Parse before passing |
| MCP tool definitions | Fixed (per session) | Limit server count |
| Hook injections | Cumulative | Eliminate duplicates |
| Error corrections | Cumulative | Max 2, then `/clear` |
| Unbounded exploration | Uncontrolled | Scope + subagent |

## Token Reduction Techniques (Documented Results)

| Technique | Reduction | Source |
|-----------|-----------|--------|
| Trigger tables instead of descriptions | **70%** | John Lindquist, 2026 |
| Identity file consolidation | **82%** | John Lindquist, 2026 |
| Rules-only preferences (no examples) | **78%** | John Lindquist, 2026 |
| Skill compression (stubs) | **93%** | John Lindquist, 2026 |
| Session starting tokens | **54%** | John Lindquist, 2026 |

> **"Lazy loading, not removal"** — agent needs trigger awareness upfront, detailed protocols load on-demand.

## Validated Data: Nuconic Case Study

| Metric | Value | Insight |
|--------|-------|---------|
| Sessions analyzed | 234 + 383 subagents | ~8 sessions/day |
| Total tool calls | 16,761 | Bash 56.5%, Read 12.1% |
| Error rate | 7.7% (1,298 errors) | Bash exit code 1 = 68% |
| CLAUDE.md backup compliance | **6%** | 31/33 deploy sessions without backup |
| Sessions with compaction | 50 (21%) | Every 5th session loses context |

**Critical insight**: Documentation ≠ enforcement. Critical rules MUST be enforced by hooks, not text.

---

*See [01-file-architecture](01-file-architecture.md) for file structure, [04-enforcement](04-enforcement.md) for hooks.*
