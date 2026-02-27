# AGENTS.md — bestAI Guidelines for AI Agents v7.0

<!-- Compatible with: Claude Code, OpenAI Codex, Sourcegraph Amp, Cursor, Windsurf, Gemini CLI -->

## Overview

bestAI v7.0 provides modular, evidence-based guidelines for AI coding agents. Built on data from 234 sessions and 16,761 tool calls, it uses **hooks for enforcement** (deterministic, cannot be bypassed) and **CLAUDE.md for guidance** (advisory, 6% compliance in production). Supports multi-vendor orchestration across Claude Code, Gemini CLI, and OpenAI Codex.

## Modules

| Module | Topic | Use When |
|--------|-------|----------|
| `modules/01-core.md` | Fundamentals, architecture, memory, enforcement, GPS | Architecture decisions, memory system, rule enforcement |
| `modules/02-operations.md` | Sessions, operational patterns, prompt caching | Session management, compaction, cost optimization |
| `modules/03-advanced.md` | Smart Context, CS algorithms, RAG, orchestration | Large codebases (100+ files), agent teams, vector search |

## Key Rules

1. **Hooks enforce, CLAUDE.md guides** — critical rules go in hooks (`exit 2` = block)
2. **Memory weight**: `[USER]` tags are permanent, `[AUTO]` tags are agent-revisable
3. **3 failures → STOP** → show `ROOT_CAUSE_TABLE` → ask user
4. **One active checklist** at a time. Scope before action.
5. **Frozen files**: listed in `frozen-fragments.md`, enforced by `check-frozen.sh`

## Hooks Reference

All hooks live in `hooks/` and are declared in `hooks/manifest.json` with priority, latency budget, and dependency graph.

### PreToolUse (run before tool execution)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `check-frozen.sh` | Edit, Write, Bash | 1 | Blocks edits to files listed in `frozen-fragments.md`. Resolves symlinks. Scans interpreter commands (`python script.py`). |
| `secret-guard.sh` | Bash, Write, Edit | 5 | Blocks commands containing secrets, `.env` access, or credential file operations. |
| `check-user-tags.sh` | Edit, Write | 10 | Prevents removal of `[USER]` tags from memory files. |
| `confidence-gate.sh` | Bash | 15 | Blocks low-confidence destructive commands (deploy, migrate, rm). |
| `backup-enforcement.sh` | Bash | 20 | Requires validated backup manifest before deploy/migrate/restart. |
| `circuit-breaker-gate.sh` | Bash | 50 | Blocks commands matching patterns from an OPEN circuit breaker. Supports HALF-OPEN auto-transition. Depends on `circuit-breaker.sh`. |
| `wal-logger.sh` | Bash, Write, Edit | 90 | Write-ahead log — records intent before destructive operations for audit trail. |

### PostToolUse (run after tool execution)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `circuit-breaker.sh` | Bash | 10 | Tracks error patterns in command output. Opens circuit breaker after N consecutive failures. |
| `ghost-tracker.sh` | Read, Grep, Glob | 20 | Tracks manually-read files to build ARC `ghost-hits.log` for Smart Context scoring. |

### UserPromptSubmit (run on user input)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `preprocess-prompt.sh` | — | 10 | Smart Context v1 — keyword/trigram-based context injection. Conflicts with v2. |
| `smart-preprocess-v2.sh` | — | 10 | Smart Context v2 — LLM-scored context injection (requires Claude CLI). Conflicts with v1. |

### SessionStart (run at session begin)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `rehydrate.sh` | — | 10 | Restores session state from `sync-state.sh` delta. Zero globs — reads paths from memory. |

### Stop (run at session end)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `memory-compiler.sh` | — | 10 | Generational GC for memory entries. Builds context index. Increments session counter. |
| `sync-state.sh` | — | 20 | Persists TOP-10 FACTS, TOP-5 PROOFS, TOP-3 BLOCKERS, LAST SESSION DELTA. |
| `sync-gps.sh` | — | 30 | Updates Global Project State (`.bestai/GPS.json`) from session work. |
| `observer.sh` | — | 40 | Periodic meta-observations about memory usage patterns and drift. |

### Maintenance (manual/cron)

| Hook | Matcher | Pri | Description |
|------|---------|-----|-------------|
| `reflector.sh` | — | 99 | Memory defragmentation. Requires Haiku model. Depends on `memory-compiler.sh`. |

### Shared Libraries

| File | Purpose |
|------|---------|
| `hook-event.sh` | Canonical JSONL event logging + `_bestai_project_hash()`. Sourced by all hooks. |

### Latency Budgets

| Event | Budget |
|-------|--------|
| PreToolUse | 200ms |
| PostToolUse | 200ms |
| UserPromptSubmit | 700ms |
| SessionStart | 300ms |
| Stop | 500ms |

## Templates

| Template | Lines | Use Case |
|----------|-------|----------|
| `templates/claude-md-minimal.md` | <50 | Quick setup, small projects |
| `templates/claude-md-standard.md` | <100 | Production projects with context loading |
| `templates/agents-md-template.md` | ~58 | Multi-tool AGENTS.md (Cursor, Windsurf, Codex) |
| `templates/blueprint-fullstack.md` | ~80 | Full-stack app scaffold (Next.js + FastAPI + PostgreSQL) |
| `templates/blueprint-multivendor.md` | ~26 | Multi-vendor swarm task assignment |

## Tools

| Tool | Command | Description |
|------|---------|-------------|
| `setup.sh` | `npx bestai setup` | Install hooks, templates, blueprints into a project |
| `doctor.sh` | `npx bestai doctor` | Validate installation, check versions, verify hooks |
| `stats.sh` | `npx bestai stats` | Hook latency dashboard (avg/max/count per hook) |
| `compliance.sh` | `npx bestai compliance` | Compliance report from JSONL event log (`--json`, `--since`) |
| `hook-lint.sh` | `npx bestai lint` | Validate manifest, check dependencies/conflicts, latency budget |
| `swarm-dispatch.sh` | `npx bestai swarm` | Multi-vendor task dispatch via GPS roles |
| `generate-rules.sh` | — | Export rules to `.cursorrules`, `.windsurfrules`, `codex.md` |
| `generate-t3-summaries.py` | — | Build T3 hierarchical summaries for large codebases |
| `vectorize-codebase.py` | — | Generate embeddings for RAG-native context |

## Do NOT

- Edit files listed in `frozen-fragments.md` (hook-enforced)
- Commit secrets, `.env`, credentials, or API keys (hook-enforced)
- Skip tests before committing
- Remove `[USER]` tags from memory files (hook-enforced)
- Make breaking changes without discussion
- Use deprecated APIs or libraries
