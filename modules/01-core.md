# Module 00: Context Engineering Fundamentals

> Use this module when you need to understand WHY context management matters
> and what principles govern effective AI agent behavior.

<!-- agents-md-compat -->

---

## Core Definition

> "Context engineering is curating what the model sees so that you get a better result."
> — Martin Fowler, 2026

Context = EVERYTHING the model sees: system prompt, tool definitions, retrieved docs, message history, tool results. Managing this is the single most impactful skill for AI CLI agents.

## 5 Immutable Principles

| # | Principle | Why | Consequence |
|---|-----------|-----|-------------|
| 1 | **Less = better** | U-shaped attention curve (model loses middle) | Max 25% context for "instructions", 75% free for reasoning |
| 2 | **Correctness > completeness > size** | False info worse than missing info | Verify before saving. Never save speculation |
| 3 | **Lazy loading, not removal** | Agent needs awareness of WHAT exists, not all DETAILS | CLAUDE.md = trigger index, Skills = details on-demand |
| 4 | **Deterministic > advisory** | CLAUDE.md = "please do", Hook = "MUST do" | Critical rules → Hooks, rest → CLAUDE.md |
| 5 | **Semantic > literal** | "Fix login" ≠ grep "login" | Semantic search > keyword match |

## Context Budget (200k tokens)

```
IDEAL DISTRIBUTION:
  System prompt + tools    ~10%
  CLAUDE.md + MEMORY.md     ~5%
  Smart Context (injected)  ~5%
  User prompt + history     ~5%
  FREE for reasoning       ~75%
```

**Key metric**: Claude Code auto-compacts at ~64-75% fill. Stopping at 75% leaves ~50k tokens free for reasoning quality.

### Token Budget Policy (operational thresholds)

| Range | Action | Enforcement |
|------|--------|-------------|
| 0-40% | Normal work | — |
| 40-50% | Proactive compaction recommended | Advisory |
| 50-64% | Warning + selective trimming | Monitoring |
| 64-75% | Auto-compaction likely | System behavior |
| 75%+ | Hard guard: split topic or `/clear` | Team policy / hook rule |

## Context Quality Hierarchy

1. **Correctness** — false information is worst
2. **Completeness** — missing information
3. **Size** — excess noise

## What Eats Context (ranked)

| Operation | Consumption | Mitigation |
|-----------|------------|------------|
| File searching (many files) | Very high | Delegate to subagent |
| Understanding code flow | High | Save summaries to file |
| Test/build logs | High | Filter to relevant sections |
| Large JSON from tools | High | Parse before passing |
| MCP tool definitions | Fixed (per session) | Limit server count |
| Hook injections | Cumulative | Eliminate duplicates |
| Error batches | Cumulative | Max 3 batches, then STOP + ROOT_CAUSE_TABLE |
| Unbounded exploration | Uncontrolled | Scope + subagent |

### Where Tokens Go (empirical pointer)

Tokenomics research (2026) reports a major share of spend in iterative refinement loops (edit-test-fix), not initial generation. Design your workflow to reduce retries, not only prompt size.

## Token Reduction Techniques (Documented Results)

| Technique | Reduction | Source |
|-----------|-----------|--------|
| Trigger tables instead of descriptions | **70%** | John Lindquist, 2026 |
| Identity file consolidation | **82%** | John Lindquist, 2026 |
| Rules-only preferences (no examples) | **78%** | John Lindquist, 2026 |
| Skill compression (stubs) | **93%** | John Lindquist, 2026 |
| Session starting tokens | **54%** | John Lindquist, 2026 |

> **"Lazy loading, not removal"** — agent needs trigger awareness upfront, detailed protocols load on-demand.

## Evidence Register

| Claim | Status | Evidence |
|------|--------|----------|
| Hook enforcement outperforms advisory docs in production | validated locally | Nuconic case study metrics in this module |
| Auto-compaction appears around 64-75% occupancy | external | Anthropic docs / observed sessions |
| Trigger-table style reduces static token load | heuristic | Community measurements (Lindquist) |
| Runtime optimization must be eval-driven | external | Anthropic eval guidance |

## Validated Data: Nuconic Case Study

| Metric | Value | Insight |
|--------|-------|---------|
| Sessions analyzed | 234 + 383 subagents | ~8 sessions/day |
| Total tool calls | 16,761 | Bash 56.5%, Read 12.1% |
| Error rate | 7.7% (1,298 errors) | Bash exit code 1 = 68% |
| CLAUDE.md backup compliance | **6%** | 31/33 deploy sessions without backup |
| Sessions with compaction | 50 (21%) | Every 5th session loses context |

**Critical insight**: Documentation ≠ enforcement. Critical rules MUST be enforced by hooks, not text.

### Methodology: How the 6% Figure Was Measured

**Data source**: Production session logs from Nuconic's OpenProject deployment (task.nuconic.com), Feb 2025.

**Measurement process**:
1. Identified all sessions containing deploy-related commands (`kamal deploy`, `rails runner`, service restarts)
2. Counted 33 deploy sessions out of 234 total
3. Checked each deploy session for a `pg_dump` or backup command executed *before* the deploy command
4. Found backups in only 2 of 33 deploy sessions → 6% compliance (2/33)

**CLAUDE.md rule being tested**: "Always create a database backup before any deployment or destructive operation"

**Limitations**:
- Single project, single team — results may not generalize
- Rule was present in CLAUDE.md for the full measurement period
- No A/B test against hook enforcement (hook was added after measurement)
- "Deploy session" identification used keyword matching, not semantic analysis
- Backup could have been taken via external process not visible in session logs

**Confidence**: The 6% figure is directionally correct (advisory docs alone are insufficient for critical rules) but should not be treated as a universal compliance rate. The key insight — that hooks dramatically outperform advisory text — is supported by the data regardless of the exact percentage.

---

*See [01-file-architecture](01-file-architecture.md) for file structure, [04-enforcement](04-enforcement.md) for hooks.*
# Module 01: File Architecture & Progressive Disclosure

> Use this module when setting up context files for your project
> or choosing between CLAUDE.md, Skills, Rules, and Hooks.

<!-- agents-md-compat -->

---

## Context File Map (2026)

| File | Tool | Loading | Purpose |
|------|------|---------|---------|
| `CLAUDE.md` | Claude Code | Always | Project conventions |
| `CLAUDE.local.md` | Claude Code | Always (not in git) | Private settings |
| `~/.claude/CLAUDE.md` | Claude Code | Always (global) | Global preferences |
| `.claude/skills/*.md` | Claude Code | On-demand (LLM decides) | Specialist knowledge |
| `.claude/rules/*.md` | Claude Code | Conditional (glob) | Per-filetype rules |
| `.claude/agents/*.md` | Claude Code | On request | Subagent tasks |
| `AGENTS.md` | OpenAI/Sourcegraph/Amp | Always | Open standard multi-tool |
| `.cursor/rules/*.md` | Cursor | Conditional (path) | IDE rules |
| `.github/copilot-instructions.md` | GitHub Copilot | Always | Copilot instructions |
| `.junie/guidelines.md` | JetBrains Junie | Always | Agent guidelines |
| `llms.txt` | Universal (proposal) | On request | LLM-friendly metadata |

## Hierarchy (cascading)

```
~/.claude/CLAUDE.md       → global (all projects)
./CLAUDE.md               → per project (team-shared)
./src/api/CLAUDE.md       → per module (specific)
CLAUDE.local.md           → private (not in git)
```

Deeper files override conflicts from higher levels. Layers are additive.

## Who Decides What Loads

| Who | Method | Example | Trade-off |
|-----|--------|---------|-----------|
| **LLM** | Autonomous | Skills | Non-deterministic but automatic |
| **Human** | Manual | Slash commands | Full control, less automation |
| **Software** | Deterministic | Hooks | Predictable, task-specific |

## CLAUDE.md — Golden Rules

| Rule | Details |
|------|---------|
| **Max 100 lines** | Longer → Claude ignores rules (lost in noise) |
| **Trigger tables** | Tables instead of narratives = **70% reduction** |
| **Lazy loading** | CLAUDE.md = minimal triggers; details via Skills |
| **Test each line** | "Will removing this line cause errors?" → if not, cut |
| **Emphasis** | `IMPORTANT`, `MUST`, **bold** → increases adherence |

### Always Include
- Bash commands Claude can't guess
- Code style rules DIFFERENT from defaults
- Testing instructions and preferred runners
- Repo etiquette (branch names, PR conventions)
- Project-specific architectural decisions
- Dev environment quirks (env vars, ports)

### Never Include
- Things Claude infers from code
- Standard language conventions
- Detailed API docs (link instead)
- Frequently changing information
- File-by-file descriptions

## Progressive Disclosure Comparison

| Feature | CLAUDE.md | Skills | Rules | Hooks | Subagents |
|---------|-----------|--------|-------|-------|-----------|
| Loading | Always | On-demand | Conditional | Deterministic | On request |
| Execution guarantee | No (guidance) | No | No | **Yes** | No |
| Context cost | Fixed | Only when active | Conditional | Minimal | Separate window |
| Team editable | Yes (git) | Yes (git) | Yes (git) | Yes | Yes |

## AGENTS.md — Open Standard

Adopted by OpenAI Codex CLI, Sourcegraph Amp, and others.

- Files collected from current directory upward (to `$HOME`)
- `$HOME/.config/AGENTS.md` always included
- Deeper files have priority at conflicts
- Community best practice: **start with COMMANDS, not explanations**

```yaml
# Sourcegraph Amp — conditional scoping
---
globs: ['**/*.ts', '**/*.tsx']
---
# TypeScript Conventions
```

OpenAI Codex CLI: project docs limited to **32 KiB** (`project_doc_max_bytes`).

## CLI vs MCP — Token Efficiency

| Method | Context free for reasoning | Notes |
|--------|---------------------------|-------|
| **CLI tools** (`gh`, `aws`, `kubectl`) | **~95%** | Single pipeline shot |
| **MCP server** (e.g. GitHub, 93 tools) | **~45%** | ~55k tokens on tool definitions |

**Recommendation**: Max 3-4 active MCP servers. Prefer CLI for everything else.

---

*See [02-session-management](02-session-management.md) for session workflow, [04-enforcement](04-enforcement.md) for hooks.*
# Module 03: Persistent Memory — Auto-Persistence & Weight System

> Use this module when you want the agent to remember decisions across sessions,
> distinguish user instructions from auto-discoveries, and never lose critical context.

<!-- agents-md-compat -->

---

## The Problem

After `/new`, `/clear`, or auto-compaction, the agent forgets: decisions, preferences, pitfalls — and repeats the same mistakes.

## Memory Layers (from simplest)

```
L0: Provider prompt caching    — API-level, zero config
L1: Session Memory (built-in)  — automatic summaries, survives /compact
L2: Auto Memory (MEMORY.md)    — persistent files, always loaded
L3: Stop Hook Pipeline         — deterministic save (optional)
```

### L1: Session Memory (zero config)
- Built into Claude Code, works automatically
- Saves every ~5,000 tokens: title, status, decisions
- Survives `/compact`
- Does **not** survive `/clear` (critical facts must live in L2+)
- Limitation: "reference material", not hard instructions

### L2: Auto Memory (KEY LAYER)

**Canonical structure**:
```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — max 200 lines, ALWAYS loaded
├── decisions.md           # Architectural decisions [USER]/[AUTO]
├── preferences.md         # Workflow preferences
├── pitfalls.md            # Pitfalls and solutions
├── frozen-fragments.md    # Registry of frozen files
└── session-log.md         # Chronological change log
```

`memory/frozen-fragments.md` is canonical. `.claude/frozen-fragments.md` is legacy fallback for compatibility.

**MEMORY.md format**:
```markdown
# Project Memory

## Decisions (details: decisions.md)
- [USER] Stack: Rails 8 + Angular 20, don't change
- [AUTO] Database: PostgreSQL 16 on port 45432

## Preferences (details: preferences.md)
- [USER] Commits: English. Documentation: Polish
- [USER] Tests ALWAYS before commit

## Pitfalls (details: pitfalls.md)
- [AUTO] Port 3000 busy — use 3001

## Frozen (details: frozen-fragments.md)
- FROZEN: config/database.yml — production
```

**Critical CLAUDE.md rule** (most effective single instruction):
```markdown
IMPORTANT: After every significant decision, user preference, or pitfall discovery —
save to the appropriate file in memory/ WITHOUT asking the user. Tag [USER] or [AUTO].
Don't wait for session end. Save AS YOU GO.
```

### L3: Stop Hook Pipeline (advanced)

For projects with many architectural decisions or large teams:

| Plugin | Architecture | Best For |
|--------|-------------|----------|
| [claude-code-auto-memory](https://deepwiki.com/severity1/claude-code-auto-memory) | 3-phase: track → spawn → update | Medium projects |
| [claude-memory](https://github.com/idnotbe/claude-memory) | 4-phase: triage → draft → verify → save | Large projects, teams |

## Weight & Source System

| Tag | Source | Weight | Change Policy |
|-----|--------|--------|---------------|
| `[USER]` | User said explicitly | **High** | ONLY with user permission |
| `[AUTO]` | Agent detected/inferred | **Lower** | Agent may revise if justified |

### Priority Rules

```
RULE #1: [USER] NEVER overridden by [AUTO]
RULE #2: [AUTO] can be updated by agent (log the change)
RULE #3: Conflict → [USER] ALWAYS wins
RULE #4: Changing [USER] → STOP → ask user → log in session-log.md
```

## Memory Entry Schema (recommended)

Use structured entries for deterministic ranking and safe updates:

```text
timestamp | source_tag | confidence | scope | statement | evidence_ref
```

Example:

```text
2026-02-24T12:10:00Z | [USER] | 0.98 | deploy | Backups required before restart | docs/runbook.md#backup
```

## Selective Forgetting (required for long-running projects)

Without forgetting, memory quality degrades even if storage grows.

Suggested policy:
- Remove stale `[AUTO]` entries with no supporting evidence after N sessions
- Merge duplicates (same statement, different wording)
- Keep `[USER]` entries unless user explicitly updates them
- Log removals/replacements in `session-log.md`

Minimal cadence:
- Every 5 sessions: review newest `[AUTO]` entries
- Every 20 sessions: defragment topic files and archive obsolete notes

## Memory Lifecycle

Memory evolves through three phases:

```
1. Initialization     — bootstrap from codebase (git log, PRs, code comments)
                        Populate MEMORY.md + topic files with load-bearing decisions.

2. Reflection         — periodic review of memory quality (every 5 sessions)
                        Validate [AUTO] entries against current evidence.
                        Merge duplicates, flag stale entries.
                        Hook: observer.sh runs at configurable interval.

3. Defragmentation    — reorganize and archive (every 20 sessions)
                        Archive old [AUTO] entries → gc-archive.md
                        Compact topic files, remove redundancy.
                        Hook: memory-compiler.sh runs generational GC.
```

| Phase | Trigger | Hook |
|-------|---------|------|
| Initialization | New project / first session | Manual (Decision Extraction Playbook below) |
| Reflection | Every N sessions | `hooks/observer.sh` (configurable via `OBSERVER_INTERVAL`) |
| Defragmentation | Every GC cycle | `hooks/memory-compiler.sh` (configurable via `MEMORY_COMPILER_GC_AGE`) |

## Git-Backed Memory

For projects requiring auditability, version memory changes with git:

```bash
# In CLAUDE.md or hooks/sync-state.sh:
cd "$MEMORY_DIR" && git add -A && git commit -m "SYNC_STATE $(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null
```

**Benefits:**
- Every memory change is versioned (who changed what, when)
- `git log --oneline memory/` shows memory evolution
- `git diff HEAD~1 memory/MEMORY.md` shows what changed last session
- Recoverable: `git checkout HEAD~1 -- memory/decisions.md` restores previous state

**Trade-offs:**
- Adds ~50ms per session end (negligible)
- Repository grows with history (mitigated by `gc-archive.md` reducing active file count)
- Not needed for small projects with few sessions

**When to use:** Projects with >50 sessions, team environments, or compliance requirements.

### Escalation Flow

```
Agent wants to change entry
  ├─ Tag = [AUTO]?
  │   └─ YES → Change it. Log in session-log.md
  └─ Tag = [USER]?
      └─ YES → STOP
          ├─ Ask user
          ├─ Explain WHY
          └─ Accepted?
              ├─ YES → Change. Mark [USER-UPDATED]. Log.
              └─ NO → Keep original. Log refusal.
```

## "Tell, Don't Hope" — The Most Important Rule

Don't rely on the agent "figuring out" what to save. Use the CLAUDE.md rule above (L2 section) — it turns auto-memory from **"might save"** to **"always saves"**.

## Decision Extraction Playbook

When bootstrapping memory in an existing repo, extract decisions from:
- git history (`git log --oneline --since="90 days ago"`)
- code comments with rationale ("because", "instead of", "decision")
- PR/issue descriptions
- runbooks and architecture docs

Store only load-bearing decisions with reason + evidence. Skip obvious facts already inferable from code.

## Common Mistakes

| Mistake | Why Bad | Fix |
|---------|---------|-----|
| MEMORY.md > 200 lines | Rest doesn't load | Move details to topic files |
| No [USER]/[AUTO] tags | Agent changes user decisions | Tagging rule in CLAUDE.md |
| No frozen registry | Agent breaks working files | Create frozen-fragments.md |
| Relying only on L1 | Session Memory = "reference" | Add L2 with MEMORY.md |
| Too much FROZEN | Can't change anything | Freeze ONLY stable, tested fragments |

---

*See [04-enforcement](04-enforcement.md) for hooks enforcing these rules, [06-operational-patterns](06-operational-patterns.md) for REHYDRATE pattern.*
# Module 04: Deterministic Enforcement — Hooks & Frozen Files

> Use this module when you need GUARANTEED rule execution.
> CLAUDE.md is advisory (6% compliance on production). Hooks are deterministic.

<!-- agents-md-compat -->

---

## The Core Insight

**Nuconic production data** (234 sessions, 29 days):
- CLAUDE.md compliance for backup rule: **6%** (31/33 deploy sessions without backup)
- Rails runner multiline error: **150 occurrences** in 40 sessions despite MEMORY.md entry
- Production restarts during work hours: **45%** (63/139)

**Conclusion**: Documentation ≠ enforcement. Critical rules MUST use hooks with `exit 2`.

## Hook Types

| Hook | When | stdout behavior | Use for |
|------|------|----------------|---------|
| `PreToolUse` | Before tool execution | stderr shown, exit 2 = BLOCK | Frozen files, security guards |
| `PostToolUse` | After tool execution | stdout shown | Linting, formatting |
| `UserPromptSubmit` | When user sends prompt | **stdout added to context** | Smart context injection |
| `SessionStart` | On session start | stdout shown | State restoration |
| `Stop` | After agent response | stdout shown | Memory sync, WAL logging (P1) |

## Fragment Freeze — Hook-Enforced Protection

### Frozen Registry (`frozen-fragments.md`)

```markdown
# Frozen Fragments Registry

## FROZEN
<!-- Hook PreToolUse blocks edits to these files. -->
<!-- To unfreeze: say "unfreeze <path>" -->

- `src/auth/login.ts` — auth flow [USER] (frozen: 2026-02-20)
- `config/database.yml` — DB config [USER] production verified (frozen: 2026-02-19)
- `.env.production` — env vars [USER] (frozen: 2026-02-18)
```

### Hook Configuration (`.claude/settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-frozen.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/preprocess-prompt.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Composition Rules

When multiple hooks are attached to the same event:
- Hooks execute in the order defined in `settings.json`
- First `exit 2` blocks the tool call
- Hooks are independent; no hook can override another hook's block
- Place the most restrictive hooks first (`check-frozen`, security guards)

## Hook Execution Latency Budget

Hooks run on every tool call. Excessive latency degrades the agent experience.

| Category | Target | Example |
|----------|--------|---------|
| Fast path (ALLOW) | < 50ms | `check-frozen.sh` file-not-listed path |
| Enforcement (BLOCK) | < 100ms | `check-frozen.sh` matching a frozen file |
| Circuit breaker check | < 100ms | `circuit-breaker-gate.sh` state file read |
| Post-tool analysis | < 200ms | `circuit-breaker.sh` pattern scan |

**Measuring latency**: All hooks using `hook-event.sh` automatically record `elapsed_ms` in each event. View aggregated latency stats with `bash stats.sh <project>` (Hook latency section) or query `events.jsonl` directly:

```bash
# Per-hook avg/max latency
jq -r 'select(.elapsed_ms != null) | "\(.hook) \(.elapsed_ms)"' events.jsonl \
  | awk '{s[$1]+=$2; c[$1]++; if($2>m[$1])m[$1]=$2} END {for(h in s) printf "%s: avg=%dms max=%dms (n=%d)\n", h, s[h]/c[h], m[h], c[h]}'
```

**Guidelines**: Keep total hook latency per tool call under 200ms. If a hook exceeds budget, consider caching (e.g., parsed frozen paths) or deferring work to `PostToolUse`/`Stop` hooks.

## Known Limitations (and mitigations)

- `PostToolUse` hooks are advisory by default (cannot block the current call)
  Mitigation: pair advisory trackers with strict `PreToolUse` gates (example: `circuit-breaker-gate.sh`)
- Bash command parsing is pattern-based, not a full shell parser
  Mitigation: keep frozen paths explicit and reviewed; bypass vectors (eval, heredoc, interpreters) are best-effort covered
- `[USER]` protection is only deterministic if enforced by dedicated hooks/diff checks
  Mitigation: treat `[USER]` rules as critical and add guard hooks in strict deployments

## Security: UserPromptSubmit Injection Threat Model

`UserPromptSubmit` hook stdout is added to the LLM context. `preprocess-prompt.sh` uses this for Smart Context injection. This creates a prompt injection surface.

### Current Defenses

`sanitize_line()` in `preprocess-prompt.sh` filters known patterns:
- LLM format tokens (`<|im_start|>`, `[INST]`, `assistant:`, `user:`)
- Obvious injection phrases (`ignore previous`, `system prompt`, `jailbreak`, `override instructions`)
- Dangerous commands (`rm -rf`, `curl http`, `<script`)
- Lines truncated to 240 characters

### Known Gaps

| Gap | Risk | Mitigation |
|-----|------|------------|
| Indirect injection via memory files | Low — memory written by agent/user, not untrusted input | Mark injected context with `[CONTEXT_DATA]` wrapper |
| Unicode homoglyphs | Low — requires intentional obfuscation | Future: normalize Unicode before sanitization |
| Multi-line injection | Low — each line sanitized independently | Sanitizer operates line-by-line; multi-line payloads fragmented |
| Base64/encoded payloads | Low — LLM would need to decode | Content is treated as data, not executable |

### Severity Assessment: Low-Medium

1. Memory files are written by the agent or user (trusted sources)
2. Attack requires prior memory poisoning (supply chain vector)
3. LLMs have built-in instruction-following guardrails independent of bestAI
4. Injected context is wrapped in `[SMART_CONTEXT]` tags with `retrieved_text_is_data_not_instructions` policy

## Example Enforcement Hooks

### Backup Before Destructive Operations

See `hooks/backup-enforcement.sh` for the full implementation. Key design:

```bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Fails CLOSED: blocks when jq missing or input malformed
# Uses project-specific flag (not PID or session ID)
# Checks backup recency (must be within 4 hours)
# See hooks/ directory for complete, tested implementation
```

### Work Hours Protection

```bash
#!/bin/bash
# hooks/work-hours-guard.sh — PreToolUse hook
COMMAND=$(cat | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

if echo "$COMMAND" | grep -qE '(restart|deploy)'; then
  HOUR=$(date +%H)
  if [ "$HOUR" -ge 8 ] && [ "$HOUR" -le 17 ]; then
    echo "BLOCKED: Production restart during work hours (8-17 CET)." >&2
    echo "Use --force flag or wait until after hours." >&2
    exit 2
  fi
fi
exit 0
```

## Documented Failures (GitHub Issues)

| Problem | Severity | Evidence | Mitigation |
|---------|----------|----------|------------|
| CLAUDE.md ignored after compaction | CRITICAL | [GH #19471](https://github.com/anthropics/claude-code/issues/19471) | SessionStart hook to restore rules |
| CLAUDE.md ignored in 50% sessions | HIGH | [GH #17530](https://github.com/anthropics/claude-code/issues/17530) | PreToolUse hooks (exit 2) |
| Security rules ignored (P0) | CRITICAL | [GH #2142](https://github.com/anthropics/claude-code/issues/2142) | PreToolUse hook blocking secret commits |
| Backup compliance 6% | CRITICAL | Nuconic data: 31/33 without backup | Hook on deploy requiring pg_dump |
| No PostCompact hook | STRUCTURAL | [GH #14258](https://github.com/anthropics/claude-code/issues/14258) | PreCompact + session < 500 tools |
| Context rot at ~147k tokens | STRUCTURAL | Quality drops though limit = 200k | `/clear` at 3+ compactions |
| Digital punding after compactions | HIGH | [GH #6549](https://github.com/anthropics/claude-code/issues/6549) | Max 3 compactions → `/clear` |

## Hook Health Monitoring

**WARNING**: Hooks can silently fail. Add monitoring:

```bash
#!/bin/bash
# hooks/health-check.sh — SessionStart hook
# Verify all hooks are functional

HOOKS_DIR="$CLAUDE_PROJECT_DIR/.claude/hooks"
FAILED=0

for hook in "$HOOKS_DIR"/*.sh; do
  [ ! -x "$hook" ] && {
    echo "WARNING: Hook not executable: $(basename $hook)"
    FAILED=$((FAILED + 1))
  }
done

# Check required dependencies
for dep in jq; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "CRITICAL: $dep not installed — enforcement hooks will BLOCK all operations (fail-closed design)"
    FAILED=$((FAILED + 1))
  }
done

# Check optional dependencies
for dep in realpath python3; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "WARNING: $dep not installed — path normalization may be degraded"
    FAILED=$((FAILED + 1))
  }
done

[ "$FAILED" -gt 0 ] && echo "Hook health check: $FAILED issues found"
exit 0
```

## Key Rule

```
CLAUDE.md = guidance (advisory, model may ignore)
Hooks with exit 2 = enforcement (deterministic, cannot be bypassed)

CRITICAL RULES → HOOKS
STYLE/PREFERENCES → CLAUDE.md
```

## Hook Selection Guide

| Need | Hook | Event |
|------|------|-------|
| Protect frozen files (Edit/Write/Bash) | `check-frozen.sh` | PreToolUse |
| Backup before destructive ops | `backup-enforcement.sh` | PreToolUse |
| Smart context injection | `preprocess-prompt.sh` | UserPromptSubmit |
| Session bootstrap | `rehydrate.sh` | SessionStart |
| Session sync + delta | `sync-state.sh` | Stop |
| Anti-loop advisory tracking | `circuit-breaker.sh` | PostToolUse |
| Anti-loop strict blocking | `circuit-breaker-gate.sh` | PreToolUse |

---

*See [05-cs-algorithms](05-cs-algorithms.md) for Circuit Breaker pattern, [03-persistence](03-persistence.md) for memory system.*
# Module 09: Memory Compiler

> Use this module to understand the automatic memory management pipeline:
> scoring, indexing, garbage collection, and the 200-line MEMORY.md cap.

<!-- agents-md-compat -->

---

## Overview

The Memory Compiler runs as a **Stop hook** (`hooks/memory-compiler.sh`) at the end of each session. It maintains memory health automatically, preventing unbounded growth while preserving critical user decisions.

## Pipeline

```
Session End (Stop hook)
  │
  ├─ 1. Increment session counter (.session-counter)
  │
  ├─ 2. Score each memory file
  │     score = base_weight + recency_bonus + min(usage_count, 20) - age_penalty
  │
  ├─ 3. Generate context-index.md
  │     Sorted index with topic clusters: core, decisions, operational, other
  │
  ├─ 4. Enforce 200-line cap on MEMORY.md
  │     Overflow → memory-overflow.md topic file
  │
  └─ 5. Generational GC
        young (0-3) / mature (3-10) / old (10+) / permanent ([USER])
        Old [AUTO] entries with low usage → gc-archive.md
```

## Scoring Formula

| Component | Value | Description |
|-----------|-------|-------------|
| `base_weight` | 10 for `[USER]`, 5 for `[AUTO]` | User decisions always outweigh auto-generated |
| `recency_bonus` | +3 (≤3 sessions), +1 (3-10), 0 (10+) | Recently used files score higher |
| `usage_count` | +N (capped at 20) | Each access increments count; cap prevents score inflation |
| `age_penalty` | Gradual: (sessions_ago - threshold) / 2, max 15 (AUTO only) | Smooth decay instead of binary cliff |

## Generational GC

Inspired by JVM generational garbage collection:

| Generation | Age (sessions) | Policy |
|------------|---------------|--------|
| **Young** | 0-3 | Keep — too new to evaluate |
| **Mature** | 3-10 | Keep — established utility |
| **Old** | 10+ | GC candidate if AUTO + low usage |
| **Permanent** | Any | `[USER]` tagged — NEVER auto-deleted |

GC threshold: configurable via `MEMORY_COMPILER_GC_AGE` env var (default: 20 sessions).

## Files Managed

| File | Purpose |
|------|---------|
| `.session-counter` | Monotonic session counter |
| `.usage-log` | Per-file usage tracking (TSV) |
| `context-index.md` | Auto-generated sorted index |
| `gc-archive.md` | Archive of GC'd entries |
| `memory-overflow.md` | MEMORY.md overflow content |

## Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `MEMORY_COMPILER_DRY_RUN` | `0` | Print actions without executing |
| `MEMORY_COMPILER_GC_AGE` | `20` | Sessions without use before GC |

## Integration

### With preprocess-prompt.sh

The Memory Compiler generates `context-index.md` which the Smart Context compiler uses for faster file discovery and scoring.

### With Smart Preprocess v2

The context-index.md serves as the "menu" that Haiku reads to decide which files to load (see module 07, Approach B).

## E-Tag Cache

The Memory Compiler generates an E-Tag cache to accelerate `preprocess-prompt.sh` scoring. Instead of re-reading files and recomputing trigrams on every prompt, the cache allows O(1) validation via `stat` comparison.

**Cache lifecycle:** Written on Stop hook (`memory-compiler.sh`), read on UserPromptSubmit (`preprocess-prompt.sh`). Cache miss = graceful fallback to original behavior.

| File | Purpose |
|------|---------|
| `.file-metadata` | TSV cache: filename, mtime, size, md5 etag, has_user flag, trigram_file path |
| `.trigram-cache/` | Directory of pre-sorted `.tri` files (one per `.md`), used for `comm -12` set intersection |

**Cache validation:** `stat -c '%Y %s'` compares mtime+size with cached values. If both match, the file hasn't changed and cached trigrams/has_user/mtime are used directly.

**Debugging:** `cat $MEMORY_DIR/.file-metadata` to inspect cache state. Delete `.file-metadata` to force full recomputation on next session.

## Safety Guarantees

1. `[USER]` entries are **never** auto-deleted
2. GC'd entries are preserved in `gc-archive.md` (recoverable)
3. MEMORY.md overflow is preserved in `memory-overflow.md`
4. Dry-run mode available for testing: `MEMORY_COMPILER_DRY_RUN=1`

---

*See [07-smart-context](07-smart-context.md) for the retrieval pipeline, [03-persistence](03-persistence.md) for memory tagging conventions.*
# Module 10: Context OS — 5-Tier Architecture

> Use this module to understand the full context management system.
> The 5 tiers define what is loaded when, and how the context budget is managed.

<!-- agents-md-compat -->

---

## Overview

The Context OS makes the context window limit **invisible** to the agent. Instead of manually managing what fits, the system automatically routes the right context at the right time using tiered loading.

```
┌──────────────────────────────────────────┐
│ T0: HOT    — always loaded               │ max 400 tokens
│   state-of-system-now.md                 │
│   checklist-now.md                       │
├──────────────────────────────────────────┤
│ T1: WARM   — loaded at BOOT              │ max 800 tokens
│   MEMORY.md index                        │
│   frozen-fragments.md (paths only)       │
├──────────────────────────────────────────┤
│ T2: COOL   — loaded on-demand (ROUTE)    │ max 1500 tokens
│   decisions.md, pitfalls.md,             │
│   preferences.md, observations.md,       │
│   topic files                            │
├──────────────────────────────────────────┤
│ T3: COLD   — never auto-loaded           │ no budget
│   session-log.md, wal.log,               │
│   gc-archive.md, memory-overflow.md      │
├──────────────────────────────────────────┤
│ T4: FROZEN — protected by PreToolUse     │ immutable
│   Files in frozen-fragments.md           │
│   Cannot be edited by any tool           │
└──────────────────────────────────────────┘
```

## Tier Details

### T0: HOT (Always Loaded)

Loaded by `hooks/rehydrate.sh` at every SessionStart.

| File | Purpose | Budget |
|------|---------|--------|
| `state-of-system-now.md` | Current system state, blockers, confidence | ~200 tokens |
| `checklist-now.md` | Active task checklist | ~200 tokens |

**Rule**: T0 must fit in 400 tokens. If larger, trim.

### T1: WARM (Boot-Time)

Loaded by `hooks/rehydrate.sh` at SessionStart.

| File | Purpose | Budget |
|------|---------|--------|
| `MEMORY.md` | Project memory index (capped at 200 lines) | ~600 tokens |
| `frozen-fragments.md` | Path list only (not content) | ~200 tokens |

**Rule**: T1 is the memory index. It tells the agent what exists, not the full content.

### T2: COOL (On-Demand)

Loaded by `hooks/preprocess-prompt.sh` or `hooks/smart-preprocess-v2.sh` based on prompt analysis.

| Selection Method | Hook | Accuracy |
|------------------|------|----------|
| Keyword + trigram matching | `preprocess-prompt.sh` | ~70% |
| Haiku semantic routing | `smart-preprocess-v2.sh` | ~85% |

**Rule**: T2 budget is 1500 tokens max. Selected files are ranked and packed under budget.

### T3: COLD (Never Auto-Loaded)

Only accessed if the agent explicitly reads them.

| File | Purpose |
|------|---------|
| `session-log.md` | Historical session summaries |
| `wal.log` | Write-ahead log of destructive actions |
| `gc-archive.md` | Garbage-collected memory entries |
| `memory-overflow.md` | MEMORY.md overflow content |

**Rule**: T3 files are for audit and recovery. The agent can read them, but they're never injected.

### T4: FROZEN (Immutable)

Protected by `hooks/check-frozen.sh` PreToolUse hook.

- Files listed in `frozen-fragments.md` cannot be modified
- Covers: Edit, Write, Bash (including sed, cp, mv, tee, etc.)
- [USER] tag ensures entries survive garbage collection

## Total Budget

```
T0 (HOT)   =  400 tokens (always)
T1 (WARM)  =  800 tokens (boot)
T2 (COOL)  = 1500 tokens (per-prompt)
─────────────────────────
Total      = 2700 tokens maximum auto-injection

Context window = 200,000 tokens
Budget ratio   = 1.35% (well under 15% safety limit)
```

## Confidence Gate

Dangerous operations (deploy, migrate, restart) are gated by system confidence:

| CONF Range | Action |
|------------|--------|
| >= 0.70 | Allow |
| < 0.70 | BLOCK (exit 2) — update state first |
| No CONF data | Allow (fail-open) |

Hook: `hooks/confidence-gate.sh` (PreToolUse, Bash matcher).

## ARC Ghost Tracking

When the agent manually reads a file that wasn't injected by T2, it's recorded in `ghost-hits.log`. On the next prompt, these files get a +4 score boost, making them more likely to be injected.

This creates a feedback loop: the system learns which files the agent actually needs.

## Lifecycle

```
SessionStart → T0 + T1 loaded (rehydrate.sh)
UserPrompt   → T2 routing (preprocess-prompt.sh or smart-preprocess-v2.sh)
PreToolUse   → T4 protection (check-frozen.sh) + confidence gate
PostToolUse  → Circuit breaker tracking
Stop         → Memory compiler (GC + index) + observer (compression)
```

## Setup

```bash
# Full Context OS with Haiku routing:
bash setup.sh /path/to/project --profile smart-v2

# Context OS with keyword routing only:
bash setup.sh /path/to/project --profile aion-runtime
```

---

*See [07-smart-context](07-smart-context.md) for routing details, [09-memory-compiler](09-memory-compiler.md) for GC pipeline, [04-enforcement](04-enforcement.md) for hook mechanics.*
# Module 12: Global Project State (GPS)

> Use this module to coordinate multiple AI agents working on the same project,
> ensuring they share a single source of truth and don't overwrite each other's progress.

<!-- agents-md-compat -->

---

## Overview

In bestAI v4.0, the **Global Project State (GPS)** serves as the central brain for multi-agent collaboration. It solves the "context paralysis" and "goal amnesia" problems that occur when multiple agents (or even a single agent over a long period) work on a complex project.

The GPS is stored in a structured JSON file, typically `.bestai/GPS.json`.

## Core Components of GPS

A standard GPS file contains:
1. **Main Objective:** The overarching goal of the project.
2. **Milestones:** High-level phases (e.g., "Database Schema", "Auth System").
3. **Active Tasks:** What each specific agent or sub-agent is currently working on.
4. **Blockers:** System-wide issues preventing progress.
5. **Shared Context:** Key architectural decisions that all agents must respect.

## Synchronization Hook (`sync-gps.sh`)

To keep the GPS up-to-date, bestAI uses a PostToolUse or Stop hook (`hooks/sync-gps.sh`).

**How it works:**
1. After significant actions (or at the end of a session), the agent is required to summarize its progress.
2. The `sync-gps.sh` Stop hook parses session output, changed files, and blocker signals, then performs an atomic `GPS.json` update.
3. When a new agent (or the next session) starts, the `rehydrate.sh` hook (from Module 10) loads the `GPS.json` into the T0 (HOT) context tier.

Current schema requires:
- `project.owner`
- `project.target_date`
- `project.success_metric`
- `project.status_updated_at`

## Example GPS File

```json
{
  "project": {
    "name": "E-commerce API",
    "main_objective": "Build a scalable backend for a retail platform."
  },
  "milestones": [
    {
      "id": "m1",
      "name": "Database Schema",
      "status": "completed"
    },
    {
      "id": "m2",
      "name": "Authentication",
      "status": "in_progress"
    }
  ],
  "active_tasks": [
    {
      "agent_id": "Agent-Backend",
      "task": "Implementing JWT validation middleware",
      "status": "working"
    }
  ],
  "blockers": [
    "Awaiting confirmation on the OAuth provider credentials."
  ],
  "shared_context": {
    "architecture_decisions": [
      "Use PostgreSQL with async psycopg3.",
      "All dates must be UTC."
    ]
  }
}
```

## Setup

1. Copy the template: `mkdir -p .bestai && cp templates/gps-template.json .bestai/GPS.json`
2. Enable the hook: Ensure `hooks/sync-gps.sh` is executable and referenced in your `.claude/settings.json` or equivalent agent config.

---

*This is a core component of the v4.0 Distributed Agent Orchestration architecture.*
# Module 15: Invisible Limit Mechanism

> Use this module to dynamically manage the T3 (Cold) Context Tier,
> allowing agents to "know about" thousands of files without loading them.

<!-- agents-md-compat -->

---

## Overview

The Context OS (Module 10) defines T3 (Cold) as files that are never auto-loaded because they would exceed the context budget. However, if the agent doesn't know they exist, it can't choose to read them.

The **Invisible Limit Mechanism** in v4.0 solves this by creating an automated, hierarchical index of summaries.

## How it Works: Dynamic Summarization

Instead of maintaining a massive `context-index.md` listing every file path, the mechanism groups files and creates dense, semantic summaries.

### 1. The Summarization Cron (or Hook)
A background process (or end-of-session hook) analyzes directories in T3:
- It reads files in a module (e.g., `src/auth/`).
- It generates a 1-2 sentence summary: "Contains OAuth2 login flows, JWT validation middleware, and user session types."
- It writes this to a `.bestai/T3-summary.md` index.

### 2. Injection into T1 (WARM)
The `T3-summary.md` index is extremely compact (e.g., 20 lines for 200 files). This summary is injected into the T1 (WARM) tier at boot.

### 3. Progressive Disclosure
The agent reads the summary in T1: *"Oh, `src/auth/` handles JWT."*
If the user asks about login, the agent knows to use its `read_file` or `grep_search` tools on `src/auth/` to pull those files from T3 into active memory.

## Setup

1. Create a periodic script that generates these directory-level summaries.
2. Ensure `rehydrate.sh` includes the resulting summary file in its boot payload.

**Example `T3-summary.md`:**
```markdown
# Cold Storage Index
- `src/billing/`: Stripe integration, invoice generation, webhooks. (Use `read_file` on `src/billing/README.md` for details)
- `tests/e2e/`: Playwright end-to-end tests for user flows.
- `docs/legacy/`: Old v1 API documentation. Do not use for new code.
```

---

*This mechanism completes the Context OS by providing a map to the entire codebase for negligible token cost.*