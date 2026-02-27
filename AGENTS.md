# AGENTS.md — bestAI Guidelines for AI Agents v7.0

<!-- Compatible with: Claude Code, OpenAI Codex, Sourcegraph Amp, Cursor, Windsurf, Gemini CLI -->

## Overview

bestAI v7.0 (Omni-Vendor Convergence) provides modular, evidence-based guidelines for heterogeneous AI coding agent swarms.
It leverages the unique strengths of different LLM providers (Anthropic, Google, OpenAI) while maintaining a unified project state.
Structured as independent modules that can be loaded on demand. Includes compliance measurement, hook composition, cross-tool rule generation, and observability.

## Guidelines

- Read `modules/` for detailed guidelines (01-03)
- Module 01 (CORE): Fundamentals, architecture, memory, enforcement, GPS
- Module 02 (OPERATIONS): Sessions, operational patterns, caching
- Module 03 (ADVANCED): CS algorithms, Smart Context, RAG, orchestration

## Key Rules

1. Hooks enforce critical rules deterministically (exit 2 = block)
2. CLAUDE.md is advisory only — use hooks for compliance
3. Memory uses Weight & Source: `[USER]` (permanent) / `[AUTO]` (revisable)
4. After 3 consecutive failures → STOP → ROOT_CAUSE_TABLE → ask user
5. One active checklist at a time. Scope before action.

## Templates

- `templates/claude-md-minimal.md` — Under 50 lines, hook-enforced
- `templates/claude-md-standard.md` — Under 100 lines, with context loading
- `templates/agents-md-template.md` — Multi-tool AGENTS.md template

## Hooks

- `hooks/check-frozen.sh` — Block edits to frozen files (PreToolUse)
- `hooks/circuit-breaker.sh` — Stop after N consecutive failures (PostToolUse)
- `hooks/wal-logger.sh` — Log intent before destructive actions (PreToolUse)
- `hooks/backup-enforcement.sh` — Require backup before deploy (PreToolUse)
