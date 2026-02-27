# bestAI — Guidelines for AI Coding Agents v5.0

Evidence-based, modular guidelines for AI coding agents. Full enforcement via hooks on **Claude Code**; advisory guidelines via AGENTS.md for Codex, Cursor, Windsurf, and Amp. Use `tools/generate-rules.sh` to export rules to other tools.

## Why bestAI?

AI agents follow CLAUDE.md rules only **6% of the time** in production ([methodology](modules/01-core.md#methodology-how-the-6-figure-was-measured): Nuconic, 234 sessions, 29 days). bestAI solves this with **hook-enforced deterministic controls** alongside advisory guidelines.

v5.0 adds **compliance measurement**, **hook composition framework**, **cross-tool rule generation**, **security hardening**, and **observability tooling**.

```
CLAUDE.md = guidance (advisory, model may ignore)
Hooks + exit 2 = enforcement for matched tool events/patterns
  Edit/Write tools:  deterministic (exact path match, cannot be bypassed)
  Bash tool:         best-effort (pattern matching, covers common cases)
```

## Quick Start

**Automated (recommended):**
```bash
bash setup.sh /path/to/your/project
bash setup.sh /path/to/your/project --profile aion-runtime
bash setup.sh /path/to/your/project --profile smart-v2 --non-interactive --secure-defaults
```

**npx (MVP distribution):**
```bash
npx bestai init /path/to/your/project
npx bestai doctor /path/to/your/project
npx bestai stats /path/to/your/project
```

Setup installs templates/hooks, merges or creates `settings.json`, and supports deterministic CI mode (`--non-interactive`).

**Manual:**
1. Copy a template: `cp templates/claude-md-standard.md your-project/CLAUDE.md`
2. Copy hooks: `cp hooks/*.sh your-project/.claude/hooks/ && chmod +x your-project/.claude/hooks/*.sh`
3. Configure in `.claude/settings.json` (see [01-core](modules/01-core.md))

**Diagnose problems:**
```bash
bash doctor.sh /path/to/your/project
bash doctor.sh --strict /path/to/your/project
```

**Run tests:**
```bash
bash tests/test-hooks.sh
bash evals/run.sh --enforce-gates
```

## Modules (Consolidated v5.0)

| Module | Topic | Content | Status |
|--------|-------|---------|--------|
| [01-core](modules/01-core.md) | **CORE** | Fundamentals, Architecture, Persistence, Enforcement, Memory Compiler, Context OS, GPS, Invisible Limit | **Core** |
| [02-operations](modules/02-operations.md) | **OPERATIONS** | Sessions, Patterns, Prompt Caching | **Recommended** |
| [03-advanced](modules/03-advanced.md) | **ADVANCED** | CS Algorithms, Smart Context, RAG Router, Agent Orchestration | **Advanced** |

### Reading Order

- **Most projects**: Start with Module 01 (CORE)
- **Robust agents**: Add Module 02 (OPERATIONS)
- **Large codebases (100+ files)**: Add Module 03 (ADVANCED)

## Hooks

| Hook | Type | Purpose |
|------|------|---------|
| [check-frozen.sh](hooks/check-frozen.sh) | PreToolUse | Block edits to frozen files (Edit/Write/Bash) |
| [check-user-tags.sh](hooks/check-user-tags.sh) | PreToolUse | Block edits that remove `[USER]` memory entries |
| [secret-guard.sh](hooks/secret-guard.sh) | PreToolUse | Block obvious secret leakage patterns and secret-file git ops |
| [confidence-gate.sh](hooks/confidence-gate.sh) | PreToolUse | Block dangerous operations below confidence threshold |
| [preprocess-prompt.sh](hooks/preprocess-prompt.sh) | UserPromptSubmit | Smart Context compiler with guardrails |
| [smart-preprocess-v2.sh](hooks/smart-preprocess-v2.sh) | UserPromptSubmit | Smart Context v2 with LLM-assisted selection and safe fallback |
| [rehydrate.sh](hooks/rehydrate.sh) | SessionStart | Runtime context bootstrap |
| [sync-state.sh](hooks/sync-state.sh) | Stop | Runtime state sync + session delta |
| [memory-compiler.sh](hooks/memory-compiler.sh) | Stop | Session counter, GC, and context index maintenance |
| [circuit-breaker.sh](hooks/circuit-breaker.sh) | PostToolUse | Advisory anti-loop tracker |
| [ghost-tracker.sh](hooks/ghost-tracker.sh) | PostToolUse | ARC ghost-hit tracker for files manually read by agent |
| [circuit-breaker-gate.sh](hooks/circuit-breaker-gate.sh) | PreToolUse | Strict anti-loop block when OPEN |
| [wal-logger.sh](hooks/wal-logger.sh) | PreToolUse | Log intent before destructive actions |
| [backup-enforcement.sh](hooks/backup-enforcement.sh) | PreToolUse | Require validated backup manifest before deploy/migrate |
| [sync-gps.sh](hooks/sync-gps.sh) | Stop | Update Global Project State |
| [observer.sh](hooks/observer.sh) | Stop | Periodic observational memory compression |
| [hook-event.sh](hooks/hook-event.sh) | Library | Shared JSONL event logging library used by selected hooks |

## Tooling

| Tool | Purpose | Usage |
|------|---------|-------|
| [setup.sh](setup.sh) | Interactive or deterministic project setup | `bash setup.sh /path/to/project --non-interactive --secure-defaults` |
| [stats.sh](stats.sh) | Observability dashboard (metrics, CB state, GPS, events) | `bash stats.sh /path/to/project` |
| [doctor.sh](doctor.sh) | Health check & diagnostics (`--strict` for CI) | `bash doctor.sh --strict /path/to/project` |
| [tests/test-hooks.sh](tests/test-hooks.sh) | Automated hook tests (100+ tests) | `bash tests/test-hooks.sh` |
| [evals/run.sh](evals/run.sh) | Reproducible benchmark report (+ optional quality gates) | `bash evals/run.sh --enforce-gates` |
| [evals/cache-usage-report.sh](evals/cache-usage-report.sh) | Prompt cache usage trend report | `bash evals/cache-usage-report.sh --input evals/data/cache-usage-sample.jsonl` |
| [tools/hook-lint.sh](tools/hook-lint.sh) | Hook composition validator (deps, conflicts, latency) | `bash tools/hook-lint.sh /path/to/project` |
| [tools/generate-rules.sh](tools/generate-rules.sh) | Export rules for Cursor/Windsurf/Codex | `bash tools/generate-rules.sh . --format cursor > .cursorrules` |
| [compliance.sh](compliance.sh) | Automated compliance reporting from events.jsonl | `bash compliance.sh /path/to/project --json` |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problem → Solution lookup | Read when agent misbehaves |
| [docs/migration-guide.md](docs/migration-guide.md) | Existing project migration playbook | Follow checklist step-by-step |

## Templates

| Template | Size | Use Case |
|----------|------|----------|
| [claude-md-minimal](templates/claude-md-minimal.md) | <50 lines | Small projects, quick start |
| [claude-md-standard](templates/claude-md-standard.md) | <100 lines | Standard projects with full context loading |
| [agents-md-template](templates/agents-md-template.md) | ~60 lines | Multi-tool compatibility (Codex, Cursor, etc.) |
| [checklist-now](templates/checklist-now.md) | runtime | Active checklist template |
| [state-of-system-now](templates/state-of-system-now.md) | runtime | Bounded state template (facts/proofs/blockers) |
| [memory-md-template](templates/memory-md-template.md) | runtime | Decision extraction starter |
| [agent-teams-output](templates/agent-teams-output.md) | optional | Structured multi-agent verdict |
| [blocker-taxonomy](templates/blocker-taxonomy.md) | optional | Canonical blocker map |

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

v5.0 (current) adds compliance measurement, hook composition framework, cross-tool rule generation, security hardening, and observability tooling. Key additions:

- **Compliance Measurement**: Automated reporting from hook events (`compliance.sh --json`).
- **Hook Composition Framework**: `hooks/manifest.json` + `tools/hook-lint.sh` for dependency/conflict/latency validation.
- **Cross-Tool Rule Generation**: Export bestAI rules to Cursor, Windsurf, Codex (`tools/generate-rules.sh`).
- **Security Hardening**: Extended Bash bypass detection (heredoc, exec, interpreters), threat model for UserPromptSubmit.
- **Observability**: Hook latency tracking (`elapsed_ms`), `stats.sh` dashboard, WAL logging.
- **npm Distribution**: `npx bestai setup`, `npx bestai doctor`.

v4.0 introduced distributed agent orchestration and Global Project State (GPS).

v3.0 consolidated legacy guidelines into a modular architecture.

## Sources & Inspiration

- [Anthropic: Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic Docs: Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [OpenAI Docs: Prompt Caching](https://platform.openai.com/docs/guides/prompt-caching)
- [Anthropic Docs: Prompt Caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Anthropic Docs: Context Editing / Tool Result Clearing](https://docs.anthropic.com/en/docs/claude-code/context-windows)
- [Anthropic: Claude Code 1.0.43](https://www.anthropic.com/news/claude-code-1-0-43)
- [OWASP GenAI Top 10](https://genai.owasp.org/llm-top-10/)
- [Google: Agent Development Kit](https://developers.googleblog.com/en/agent-development-kit-easy-to-build-multi-agent-applications/)
- [Letta: Context Repositories](https://www.letta.com/blog/context-repositories)
- [claude-mem](https://github.com/thedotmack/claude-mem) — 6-layer memory, 4700+ stars
- [AION-NEOVERSE](https://github.com/damianjedryka39-create/AION-NEOVERSE-NEW) — Operational discipline patterns
- [CASS](https://github.com/Dicklesworthstone/coding_agent_session_search) — Session search
- Michael Nygard, "Release It!" — Circuit Breaker pattern
- IBM Research (2003) — ARC cache algorithm

## License

MIT
