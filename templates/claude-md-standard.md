# CLAUDE.md — Standard Template (<100 lines)

<!-- Hook-enforced. Keep under 100 lines. This file is ALWAYS loaded. -->

## Project

- **Name**: [project name]
- **Stack**: [your stack here]
- **Language**: [primary language]
- **Test**: `[your test command]`
- **Build**: `[your build command]`
- **Deploy**: `[your deploy command]`

## Critical Rules (hook-enforced)

1. **FROZEN FILES**: Never edit files in `frozen-fragments.md` (PreToolUse hook blocks)
2. **BACKUP FIRST**: Run backup before deploy/migrate/restart (PreToolUse hook blocks)
3. **3 FAILURES → STOP**: After 3 failed attempts, show ROOT_CAUSE_TABLE, ask user
4. **NO SECRETS**: Never commit `.env`, credentials, API keys

## Style & Conventions

- [Your code style rules — be specific]
- [e.g., "TypeScript strict mode, no `any`"]
- [e.g., "Tests: Vitest, co-located in `__tests__/`"]
- [e.g., "Commits: conventional format (feat:, fix:, chore:)"]
- [e.g., "Max file length: 300 lines"]

## Architecture Decisions

<!-- Tag each: [USER] = permanent, [AUTO] = revisable by agent -->

- [USER] Stack: [your stack] — not changeable
- [USER] Database: [your DB] — production verified
- [AUTO] API pattern: [REST/GraphQL/etc.]

## Memory System

- `MEMORY.md` = persistent project index (read at session start)
- Weight tags: `[USER]` (never auto-override) / `[AUTO]` (revisable)
- Update memory when: new decision, new discovery, resolved error

## Context Loading (progressive disclosure)

| Trigger | Module | When |
|---------|--------|------|
| Core principles | `modules/00-fundamentals.md` | Architecture discussions |
| File hierarchy | `modules/01-file-architecture.md` | Tool/config questions |
| Session management | `modules/02-session-management.md` | Compaction/subagent issues |
| Memory & persistence | `modules/03-persistence.md` | Memory system questions |
| Hook enforcement | `modules/04-enforcement.md` | Compliance/security |
| CS algorithms | `modules/05-cs-algorithms.md` | Implementing robust patterns |
| Operational patterns | `modules/06-operational-patterns.md` | Anti-loop, cold start |
| Smart context | `modules/07-smart-context.md` | Large codebase (100+ files) |
| Advanced/experimental | `modules/08-advanced.md` | Vector DB, agent teams |
| Prompt caching ops | `modules/09-prompt-caching-ops.md` | Long sessions, cost/latency optimization |

## Session Rules

1. Read `MEMORY.md` at session start
2. If runtime profile enabled: run REHYDRATE on session start and SYNC_STATE before `/clear`
3. Use `/clear` after 3+ compactions (context rot prevention)
4. One active checklist at a time
5. Scope before action: state files, changes, verification, rollback plan
6. Sync state at task end: update memory, commit if stable

## Frozen Files

<!-- Enforced by PreToolUse hook — cannot be bypassed -->

- `[list your frozen files here]`

<!-- Hooks: see .claude/settings.json for configuration -->
<!-- Full guidelines: see modules/ directory -->
