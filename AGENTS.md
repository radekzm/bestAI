# AGENTS.md — bestAI Guidelines for AI Agents

<!-- Compatible with: Claude Code, OpenAI Codex, Sourcegraph Amp, Cursor, Windsurf -->

## Overview

bestAI provides modular, evidence-based guidelines for AI coding agents.
Structured as independent modules that can be loaded on demand.

## Guidelines

- Read `modules/` for detailed guidelines (00-11)
- Core modules (00-04): context engineering, file architecture, sessions, persistence, enforcement
- Advanced modules (05-11): CS algorithms, operational patterns, smart context, context OS, prompt caching

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
