# CLAUDE.md — Minimal Template (<50 lines)

<!-- bestai-template: claude-md-minimal v7.0 -->
<!-- Hook-enforced. Keep under 50 lines. This file is ALWAYS loaded. -->

## Project

- **Stack**: [your stack here]
- **Language**: [primary language]
- **Test command**: `[your test command]`

## Rules

1. Run tests before committing
2. Never edit files in `frozen-fragments.md`
3. Ask before destructive operations (deploy, migrate, restart)
4. After 3 failed attempts → STOP → show ROOT_CAUSE_TABLE → ask user

## Style

- [Your code style rules here]
- [e.g., "Use TypeScript strict mode"]
- [e.g., "Prefer composition over inheritance"]

## Memory

- Read `MEMORY.md` at session start for persistent context
- Update `MEMORY.md` when making decisions or discoveries
- Tag entries: `[USER]` = permanent, `[AUTO]` = revisable

## Context Loading

<!-- Adapt paths below to your project's bestAI location -->

| Trigger | Module |
|---------|--------|
| Architecture questions | → Read `modules/00-fundamentals.md` |
| File structure | → Read `modules/01-file-architecture.md` |
| Session issues | → Read `modules/02-session-management.md` |
| Memory/persistence | → Read `modules/03-persistence.md` |
| Hook enforcement | → Read `modules/04-enforcement.md` |

<!-- Hooks enforce critical rules. See .claude/settings.json -->
