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
bash setup.sh /path/to/your/project --profile aion-runtime
```

This interactive setup (~5 min) installs templates, hooks, merges/creates `settings.json`, and can enable runtime profile (REHYDRATE + SYNC_STATE).

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
bash evals/run.sh
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
| [09-memory-compiler](modules/09-memory-compiler.md) | Memory GC, scoring, context index | ~170 | Recommended |
| [10-context-os](modules/10-context-os.md) | 5-tier context architecture | ~200 | Recommended |
| [11-prompt-caching](modules/11-prompt-caching.md) | Stable prefix + cached token metrics | ~130 | Recommended |
| [12-global-project-state](modules/12-global-project-state.md) | Multi-agent coordination and GPS | ~60 | v4.0 Core |
| [13-agent-orchestration](modules/13-agent-orchestration.md) | Parallel spawning, code reviews | ~50 | v4.0 Advanced |
| [14-rag-context-router](modules/14-rag-context-router.md) | Vector DB context injection | ~50 | v4.0 Advanced |
| [15-invisible-limit](modules/15-invisible-limit.md) | Dynamic summary indexes (T3 tier) | ~50 | v4.0 Core |

### Reading Order

- **Most projects**: Start with modules 00-04 (core)
- **Robust agents**: Add modules 05-06 (CS algorithms + operational patterns)
- **Large codebases (100+ files)**: Add module 07 (smart context)
- **Research/enterprise**: Explore module 08 (experimental)
- **Long-running multi-session work**: Add modules 09-10 (memory compiler + context OS)
- **Cost/latency optimization**: Add module 11 (prompt caching)

## Hooks

| Hook | Type | Purpose |
|------|------|---------|
| [check-frozen.sh](hooks/check-frozen.sh) | PreToolUse | Block edits to frozen files (Edit/Write/Bash) |
| [preprocess-prompt.sh](hooks/preprocess-prompt.sh) | UserPromptSubmit | Smart Context compiler with guardrails |
| [rehydrate.sh](hooks/rehydrate.sh) | SessionStart | Runtime context bootstrap |
| [sync-state.sh](hooks/sync-state.sh) | Stop | Runtime state sync + session delta |
| [circuit-breaker.sh](hooks/circuit-breaker.sh) | PostToolUse | Advisory anti-loop tracker |
| [circuit-breaker-gate.sh](hooks/circuit-breaker-gate.sh) | PreToolUse | Strict anti-loop block when OPEN |
| [wal-logger.sh](hooks/wal-logger.sh) | PreToolUse | Log intent before destructive actions |
| [backup-enforcement.sh](hooks/backup-enforcement.sh) | PreToolUse | Require backup before deploy/migrate |
| [sync-gps.sh](hooks/sync-gps.sh) | Stop | Update Global Project State (v4.0) |

## Tooling

| Tool | Purpose | Usage |
|------|---------|-------|
| [setup.sh](setup.sh) | Interactive project setup | `bash setup.sh /path/to/project` |
| [doctor.sh](doctor.sh) | Health check & diagnostics | `bash doctor.sh /path/to/project` |
| [tests/test-hooks.sh](tests/test-hooks.sh) | Automated hook tests (100+ tests) | `bash tests/test-hooks.sh` |
| [evals/run.sh](evals/run.sh) | Reproducible benchmark report | `bash evals/run.sh` |
| [evals/cache-usage-report.sh](evals/cache-usage-report.sh) | Prompt cache usage trend report | `bash evals/cache-usage-report.sh --input evals/data/cache-usage-sample.jsonl` |
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

v3.0 consolidates legacy guidelines into a modular architecture (currently 12 modules). Key changes:

- Removed unvalidated metrics; retained sourced data (Nuconic, Lindquist)
- Added 10 CS algorithms mapped to AI agent patterns
- Added operational patterns from AION-NEOVERSE project
- Fixed hook implementations (path normalization, error handling)
- Marked experimental features clearly (modules 07-08)
- Added prompt caching playbook module (11) with usage metrics playbook
- Preserved Nuconic case study as sole validated evidence

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
