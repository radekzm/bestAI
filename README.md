# bestAI — Guidelines for AI Coding Agents v3.0

Evidence-based, modular guidelines for AI coding agents (Claude Code, Codex, Cursor, Windsurf, Amp).

## Why bestAI?

AI agents follow CLAUDE.md rules only **6% of the time** in production (Nuconic: 234 sessions, 29 days). bestAI solves this with **hook-enforced deterministic compliance** alongside advisory guidelines.

```
CLAUDE.md = guidance (advisory, model may ignore)
Hooks + exit 2 = enforcement (deterministic, cannot be bypassed)
```

## Quick Start

**Automated (recommended):**
```bash
bash setup.sh /path/to/your/project
```

This interactive setup (~5 min) installs templates, hooks, and generates `settings.json`.

**Manual:**
1. Copy a template: `cp templates/claude-md-standard.md your-project/CLAUDE.md`
2. Copy hooks: `cp hooks/*.sh your-project/.claude/hooks/ && chmod +x your-project/.claude/hooks/*.sh`
3. Configure in `.claude/settings.json` (see [04-enforcement](modules/04-enforcement.md))

**Diagnose problems:**
```bash
bash doctor.sh /path/to/your/project
```

**Run tests:**
```bash
bash tests/test-hooks.sh
```

## Modules

| Module | Topic | Lines | Status |
|--------|-------|-------|--------|
| [00-fundamentals](modules/00-fundamentals.md) | Context engineering, token budget | ~85 | Core |
| [01-file-architecture](modules/01-file-architecture.md) | File hierarchy, progressive disclosure | ~110 | Core |
| [02-session-management](modules/02-session-management.md) | Sessions, compaction, subagents | ~130 | Core |
| [03-persistence](modules/03-persistence.md) | Memory layers, Weight & Source | ~130 | Core |
| [04-enforcement](modules/04-enforcement.md) | Hooks, frozen files, Nuconic data | ~170 | Core |
| [05-cs-algorithms](modules/05-cs-algorithms.md) | 10 CS algorithms for AI agents | ~140 | Recommended |
| [06-operational-patterns](modules/06-operational-patterns.md) | Anti-loop, REHYDRATE, checklists | ~165 | Recommended |
| [07-smart-context](modules/07-smart-context.md) | Semantic routing, preprocessing | ~155 | Optional |
| [08-advanced](modules/08-advanced.md) | Vector DB, agent teams | ~160 | Experimental |

### Reading Order

- **Most projects**: Start with modules 00-04 (core)
- **Robust agents**: Add modules 05-06 (CS algorithms + operational patterns)
- **Large codebases (100+ files)**: Add module 07 (smart context)
- **Research/enterprise**: Explore module 08 (experimental)

## Hooks

| Hook | Type | Purpose |
|------|------|---------|
| [check-frozen.sh](hooks/check-frozen.sh) | PreToolUse | Block edits to frozen files |
| [circuit-breaker.sh](hooks/circuit-breaker.sh) | PostToolUse | Stop after N consecutive failures |
| [wal-logger.sh](hooks/wal-logger.sh) | PreToolUse | Log intent before destructive actions |
| [backup-enforcement.sh](hooks/backup-enforcement.sh) | PreToolUse | Require backup before deploy/migrate |

## Tooling

| Tool | Purpose | Usage |
|------|---------|-------|
| [setup.sh](setup.sh) | Interactive project setup | `bash setup.sh /path/to/project` |
| [doctor.sh](doctor.sh) | Health check & diagnostics | `bash doctor.sh /path/to/project` |
| [tests/test-hooks.sh](tests/test-hooks.sh) | Automated hook tests (14 tests) | `bash tests/test-hooks.sh` |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problem → Solution lookup | Read when agent misbehaves |

## Templates

| Template | Size | Use Case |
|----------|------|----------|
| [claude-md-minimal](templates/claude-md-minimal.md) | <50 lines | Small projects, quick start |
| [claude-md-standard](templates/claude-md-standard.md) | <100 lines | Standard projects with full context loading |
| [agents-md-template](templates/agents-md-template.md) | ~60 lines | Multi-tool compatibility (Codex, Cursor, etc.) |

## Key Concepts

### Progressive Disclosure (load on demand)
```
CLAUDE.md (always loaded, <100 lines)
  → Skills (on-demand, per-task)
    → Rules (conditional, glob-matched)
      → Hooks (deterministic, exit 2 = block)
```

### Memory Weight & Source
```
[USER] = Human decision, never auto-overridden
[AUTO] = Agent discovery, revisable with evidence
```

### Circuit Breaker Pattern
```
Attempt 1: Try normally
Attempt 2: Adjust approach
Attempt 3: Different strategy
Failure → HARD STOP → ROOT_CAUSE_TABLE → ask user
```

## Evolution

v3.0 consolidates 6 files (5,268 lines, ~3,000 duplicated) into 9 focused modules (~1,250 lines total — 76% reduction). Key changes:

- Removed unvalidated metrics; retained sourced data (Nuconic, Lindquist)
- Added 10 CS algorithms mapped to AI agent patterns
- Added operational patterns from AION-NEOVERSE project
- Fixed hook implementations (path normalization, error handling)
- Marked experimental features clearly (modules 07-08)
- Preserved Nuconic case study as sole validated evidence

## Sources & Inspiration

- [Anthropic: Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [claude-mem](https://github.com/thedotmack/claude-mem) — 6-layer memory, 4700+ stars
- [AION-NEOVERSE](https://github.com/damianjedryka39-create/AION-NEOVERSE-NEW) — Operational discipline patterns
- [CASS](https://github.com/Dicklesworthstone/coding_agent_session_search) — Session search
- Michael Nygard, "Release It!" — Circuit Breaker pattern
- IBM Research (2003) — ARC cache algorithm

## License

MIT
