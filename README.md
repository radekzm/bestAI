# bestAI v7.0

**Deterministic guardrails for AI coding agents.** Hooks enforce what CLAUDE.md cannot.

[![npm](https://img.shields.io/badge/npm-v7.0.0-blue?logo=npm)](https://www.npmjs.com/)
[![Tests](https://img.shields.io/badge/tests-150%2F150-brightgreen)]()
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)]()

---

## The Problem

AI coding agents ignore instructions. In a study of 234 sessions and 16,761 tool calls, CLAUDE.md rules achieved **6% compliance**. Agents delete frozen files, commit secrets, loop on failures, and lose context across sessions.

Instructions don't work. Enforcement does.

## The Solution

bestAI uses **shell hooks** that run before and after every tool call. A hook that exits with code 2 **blocks the action deterministically** — the agent cannot bypass it, regardless of prompt, context window state, or model hallucination.

```
CLAUDE.md says "don't edit config.yml"  →  agent ignores it  →  config.yml edited
check-frozen.sh blocks Edit on config.yml  →  exit 2  →  edit rejected, every time
```

### What's Deterministic vs Best-Effort

| Hook Type | Enforcement | Example |
|-----------|-------------|---------|
| **Edit/Write hooks** | **Deterministic** — exact path match, cannot be bypassed | `check-frozen.sh` blocking edits to frozen files |
| **Bash hooks** | **Best-effort** — pattern matching, covers common cases | `secret-guard.sh` detecting `.env` in commands |

Bash hooks can be circumvented by creative command construction. This is a fundamental limitation, not a bug. Critical protection should use Edit/Write hooks where possible.

---

## Quick Start

```bash
# Install into your project
npx bestai setup .

# Verify installation
npx bestai doctor

# Run test suite
npx bestai test
```

This installs hooks into `.claude/hooks/`, creates `CLAUDE.md` and `MEMORY.md` templates, and optionally sets up a project blueprint.

### What Gets Installed

```
your-project/
├── .claude/
│   ├── settings.json          # Hook configuration
│   └── hooks/ → bestai/hooks  # Symlinked hook scripts
├── CLAUDE.md                  # Agent guidance (advisory)
├── MEMORY.md                  # Persistent memory index
└── memory/
    ├── frozen-fragments.md    # Files agents cannot edit
    └── state-of-system-now.md # Session state delta
```

---

## Hooks

18 hooks organized by lifecycle event. All declared in `hooks/manifest.json` with priority ordering, dependency graph, and latency budgets.

### Protection Hooks (PreToolUse)

| Hook | What It Does | Enforcement |
|------|-------------|-------------|
| `check-frozen.sh` | Blocks edits to files in `frozen-fragments.md` | Deterministic (Edit/Write), best-effort (Bash) |
| `secret-guard.sh` | Blocks `.env` access, credential operations | Best-effort |
| `check-user-tags.sh` | Prevents removal of `[USER]` memory tags | Deterministic |
| `confidence-gate.sh` | Blocks low-confidence destructive commands | Best-effort |
| `backup-enforcement.sh` | Requires backup manifest before deploy/migrate | Best-effort |
| `circuit-breaker-gate.sh` | Blocks commands when circuit breaker is OPEN | Best-effort |
| `wal-logger.sh` | Write-ahead log before destructive operations | Passive (logs, doesn't block) |

### Observability Hooks (PostToolUse)

| Hook | What It Does |
|------|-------------|
| `circuit-breaker.sh` | Tracks error patterns, opens breaker after N failures |
| `ghost-tracker.sh` | Records file reads for Smart Context scoring |

### Context Hooks (UserPromptSubmit)

| Hook | What It Does |
|------|-------------|
| `preprocess-prompt.sh` | Smart Context v1 — keyword/trigram context injection |
| `smart-preprocess-v2.sh` | Smart Context v2 — LLM-scored injection (conflicts with v1) |

### Session Lifecycle

| Hook | Event | What It Does |
|------|-------|-------------|
| `rehydrate.sh` | SessionStart | Restores state from previous session delta |
| `memory-compiler.sh` | Stop | Generational GC for memory, context index |
| `sync-state.sh` | Stop | Persists session delta (facts, proofs, blockers) |
| `sync-gps.sh` | Stop | Updates Global Project State |
| `observer.sh` | Stop | Meta-observations about memory patterns |
| `reflector.sh` | Manual | Memory defragmentation (requires Haiku) |

### Shared Library

`hook-event.sh` — Canonical JSONL event logging and `_bestai_project_hash()`. Sourced by all hooks. Events written to `~/.cache/bestai/events.jsonl`.

---

## CLI Tools

```bash
npx bestai setup       # Install hooks and templates
npx bestai doctor      # Validate installation
npx bestai test        # Run 150-test suite
npx bestai stats       # Hook latency dashboard
npx bestai compliance  # Compliance report from event log
npx bestai lint        # Validate hook manifest
npx bestai swarm       # Multi-vendor task dispatch
```

Additional tools (not in CLI):
- `tools/generate-rules.sh` — Export to `.cursorrules`, `.windsurfrules`, `codex.md`
- `tools/generate-t3-summaries.py` — Hierarchical summaries for large codebases
- `tools/budget-monitor.sh` — Token/cost tracking across vendors

---

## Modules

Documentation is organized into three modules, loaded progressively (agents read only what they need).

| Module | Lines | Topic | Maturity |
|--------|-------|-------|----------|
| [01-core](modules/01-core.md) | 1089 | Architecture, memory, enforcement, GPS, frozen files | **Stable** — tested in production |
| [02-operations](modules/02-operations.md) | 484 | Sessions, operational patterns, prompt caching | **Stable** |
| [03-advanced](modules/03-advanced.md) | 723 | Smart Context, CS algorithms, RAG, orchestration | **Mixed** — Smart Context stable, RAG preview |

### Maturity Levels

- **Stable**: Has hooks, has tests, used in production (234+ sessions)
- **Preview**: Documented, partial implementation, no production data
- **Conceptual**: Described algorithmically, not implemented

---

## Multi-Vendor Support

bestAI can coordinate agents from different providers working on the same codebase. All agents share state via `.bestai/GPS.json`.

| Role | Recommended Provider | Why |
|------|---------------------|-----|
| Architect | Claude Code | Deep reasoning, hook compliance |
| Investigator | Gemini CLI | 2M+ context window for codebase mining |
| Tester | OpenAI Codex | Fast boilerplate and test generation |

**Honest assessment**: Multi-vendor orchestration is at **preview** maturity. The dispatcher exists (`tools/swarm-dispatch.sh`) and GPS sharing works, but there is no production data on multi-vendor workflows. Single-vendor (Claude Code) is the battle-tested path.

---

## Templates

| Template | Purpose | Size |
|----------|---------|------|
| `claude-md-minimal.md` | Minimal CLAUDE.md with hook enforcement | <50 lines |
| `claude-md-standard.md` | Production CLAUDE.md with context loading table | <100 lines |
| `agents-md-template.md` | Multi-tool AGENTS.md (Cursor, Windsurf, Codex compatible) | ~58 lines |
| `blueprint-fullstack.md` | Full-stack scaffold (Next.js + FastAPI + PostgreSQL) | ~80 lines |
| `blueprint-multivendor.md` | Multi-vendor swarm task assignment | ~26 lines |

---

## Evidence Base

All claims are grounded in the [Nuconic case study](modules/01-core.md):

| Metric | Value |
|--------|-------|
| Sessions analyzed | 234 |
| Tool calls analyzed | 16,761 |
| Study duration | 29 days |
| CLAUDE.md compliance rate | 6% (CI: 4.1%–8.6%) |
| Hook enforcement rate | 100% (Edit/Write), ~95% (Bash) |

**Limitations**: Single-project study. Results may not generalize to all codebases, team sizes, or agent configurations. The 6% figure measures strict rule adherence; agents may partially comply in ways not captured by binary measurement.

---

## Project Structure

```
bestAI/
├── hooks/                 # 18 shell hook scripts + manifest.json
│   ├── hook-event.sh      # Shared library (logging + hash)
│   ├── check-frozen.sh    # PreToolUse: frozen file protection
│   ├── circuit-breaker.sh # PostToolUse: failure tracking
│   └── ...
├── tools/                 # CLI tools and utilities
├── modules/               # Documentation (01-core, 02-ops, 03-advanced)
├── templates/             # CLAUDE.md, AGENTS.md, blueprint templates
├── tests/                 # 150 tests in test-hooks.sh
├── bin/bestai.js          # npm CLI entry point
├── setup.sh               # Interactive installer
├── doctor.sh              # Installation validator
├── stats.sh               # Latency dashboard
├── compliance.sh          # Event log reporter
├── CLAUDE.md              # This project's guidelines
├── AGENTS.md              # Multi-tool agent instructions
└── CHANGELOG.md           # Release history
```

---

## Known Limitations

1. **Bash hooks are bypassable** — creative command construction can evade pattern matching. This is inherent to the approach, not fixable without a full command parser.
2. **No Windows support** — hooks are bash scripts. WSL2 works but is untested.
3. **RAG/vector search is preview** — `vectorize-codebase.py` exists but has no production validation.
4. **Multi-vendor orchestration is preview** — GPS sharing works, but automated dispatch lacks production data.
5. **Memory compiler requires disciplined use** — without regular `[USER]`/`[AUTO]` tagging, memory quality degrades.
6. **Context injection latency** — Smart Context v2 adds ~500ms per prompt (LLM scoring). Use v1 for latency-sensitive workflows.

---

## Contributing

```bash
# Clone and run tests
git clone https://github.com/radekzm/bestAI.git
cd bestAI
bash tests/test-hooks.sh

# Add a new hook
# 1. Create hooks/your-hook.sh (exit 2 to block, exit 0 to allow)
# 2. Add entry to hooks/manifest.json
# 3. Add tests to tests/test-hooks.sh
# 4. Run: npx bestai lint (validate manifest)
```

---

## License

MIT

---

<div align="center">
<sub>Built on evidence from 234 sessions. Hooks enforce what instructions cannot.</sub>
</div>
