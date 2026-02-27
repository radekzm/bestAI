# Full-Stack Blueprint (v7.0)

<!-- bestai-template: blueprint-fullstack v7.0 -->

This blueprint provides a structured starting point for full-stack web applications. Adapt the stack components to your project.

## Stack

| Layer | Default | Alternatives |
|-------|---------|-------------|
| Frontend | Next.js (App Router) | Remix, SvelteKit, Nuxt |
| Backend | FastAPI | Express, NestJS, Django |
| Database | PostgreSQL | MySQL, MongoDB, SQLite |
| ORM | Prisma / SQLAlchemy | Drizzle, TypeORM, Tortoise |
| Auth | NextAuth / OAuth2 | Clerk, Supabase Auth |
| Deploy | Docker + Railway | Vercel, Fly.io, AWS |

## Directory Structure

```
project/
├── .bestai/
│   ├── GPS.json              # Global Project State
│   └── blueprint.md          # This file (project copy)
├── .claude/
│   ├── settings.json         # Hook configuration
│   └── hooks/ → bestai/hooks # Symlinked hooks
├── frontend/
│   ├── src/
│   │   ├── app/              # Next.js App Router pages
│   │   ├── components/       # UI components
│   │   ├── lib/              # Client utilities
│   │   └── types/            # TypeScript types
│   └── __tests__/            # Frontend tests (Vitest)
├── backend/
│   ├── app/
│   │   ├── api/              # Route handlers
│   │   ├── models/           # DB models
│   │   ├── services/         # Business logic
│   │   └── schemas/          # Pydantic/Zod schemas
│   └── tests/                # Backend tests (pytest)
├── shared/                   # Shared types/constants
├── docker-compose.yml
└── CLAUDE.md
```

## Frozen Files (add to frozen-fragments.md)

```
docker-compose.yml
.env.example
database/migrations/
```

## Commands

| Task | Command |
|------|---------|
| Dev (frontend) | `npm run dev` |
| Dev (backend) | `uvicorn app.main:app --reload` |
| Test (all) | `npm test && pytest` |
| Migrate | `alembic upgrade head` |
| Build | `docker compose build` |
| Deploy | `docker compose up -d` |

## GPS Task Workflow

1. Define tasks in `.bestai/GPS.json` with `status: "pending"`
2. Agent claims task → sets `status: "in_progress"`, `assigned_to: "agent-id"`
3. Agent completes → sets `status: "done"`, updates `last_modified`
4. Review cycle: another agent verifies → sets `status: "verified"`

## Hook Integration

Recommended hooks for full-stack projects:

- `check-frozen.sh` — Protect migrations, docker config, env files
- `backup-enforcement.sh` — Require backup before deploy/migrate
- `circuit-breaker.sh` — Stop after repeated failures
- `hook-event.sh` — Event logging for compliance tracking
