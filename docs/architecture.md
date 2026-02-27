# bestAI Architecture

Technical reference for how bestAI works internally. Read the [README](../README.md) first for the high-level overview.

## Design Principles

1. **Enforcement over guidance** — Rules that matter use hooks (`exit 2` = block). Rules that are nice-to-have go in CLAUDE.md.
2. **Progressive disclosure** — Agents load only what they need. CLAUDE.md is always loaded (<100 lines). Modules are loaded on demand (2,300 lines total).
3. **Evidence-based** — Every feature exists because production data showed a need. No speculative features in the stable tier.
4. **Composable hooks** — Hooks are independent scripts with a declared dependency graph. No monolithic enforcement engine.

## Hook Execution Model

### Lifecycle

```
User types prompt
  → UserPromptSubmit hooks run (context injection)
    → Agent decides to use a tool
      → PreToolUse hooks run (protection/blocking)
        → Tool executes
      → PostToolUse hooks run (observation/tracking)
    → Agent produces response
  → Session ends
    → Stop hooks run (state persistence)

Session starts
  → SessionStart hooks run (state restoration)
```

### Execution Rules

- Hooks run in **priority order** (lowest number first, declared in `manifest.json`)
- A hook returning `exit 2` **blocks the action** — the tool call is rejected
- A hook returning `exit 0` **allows the action** to proceed
- Any other exit code is treated as an error (action proceeds, error logged)
- Hooks receive tool context via environment variables:
  - `$TOOL_NAME` — the tool being called (Edit, Write, Bash, Read, etc.)
  - `$TOOL_INPUT` — JSON string of tool parameters
  - `$CLAUDE_PROJECT_DIR` — project root path

### Determinism Spectrum

```
                  Deterministic                    Best-effort
Edit/Write hooks ←————————————————→ Bash hooks
  exact path match                   regex pattern matching
  cannot be bypassed                 creative commands can evade
  100% enforcement                   ~95% enforcement
```

**Why Bash hooks are weaker**: The hook receives the command string and matches patterns (e.g., `grep -q '\.env'`). An agent could construct equivalent commands that don't match the pattern (e.g., variable indirection, base64 encoding). This is inherent to string-based matching and cannot be fully solved without a command parser or sandbox.

## Event Logging

All hooks emit structured events to a JSONL log via `hook-event.sh`:

```json
{
  "ts": "2026-02-27T14:30:00.123Z",
  "hook": "check-frozen.sh",
  "action": "BLOCK",
  "tool": "Edit",
  "project": "a1b2c3d4e5f6g7h8",
  "elapsed_ms": 12,
  "detail": {"file": "config.yml", "reason": "frozen"}
}
```

- **Log path**: `${BESTAI_EVENT_LOG:-~/.cache/bestai/events.jsonl}` (per-user, not per-project)
- **Project isolation**: Events are tagged with a 16-char hash of the project path
- **Rotation**: Log rotates at 10,000 lines (keeps newest 5,000)
- **Querying**: `compliance.sh` reads this log, filters by project hash, reports block/allow counts

### Project Hash

All hooks identify projects using `_bestai_project_hash()` from `hook-event.sh`:

```bash
printf '%s' "$project_dir" | md5sum | awk '{print substr($1,1,16)}'
```

Critical: uses `printf '%s'` (no trailing newline), not `echo`. This is the canonical implementation — all hooks must source `hook-event.sh` or reproduce this exact behavior.

## Memory System

### Weight & Source Tags

- `[USER]` — Set by the user. Permanent. Hooks prevent agent removal.
- `[AUTO]` — Set by the agent. Revisable. Can be updated or removed.

### Generational GC (memory-compiler.sh)

Memory entries are scored by: `relevance × recency × usage_count` (capped at 20). Entries below a threshold are demoted. Three generations: hot → warm → cold → purged.

### State Persistence (sync-state.sh)

At session end, writes a compact delta:
- TOP-10 FACTS (what the agent learned)
- TOP-5 PROOFS (evidence for decisions)
- TOP-3 BLOCKERS (unresolved issues)
- LAST SESSION DELTA (5-10 lines of what changed)

At session start, `rehydrate.sh` reads this delta — zero file globs, paths from memory.

## Circuit Breaker

Two-phase pattern inspired by distributed systems:

### Phase 1: Detection (circuit-breaker.sh, PostToolUse)

Monitors Bash command output for error patterns. Tracks consecutive failures per project. After N failures (default: 3), writes `state=OPEN` to state directory.

### Phase 2: Gating (circuit-breaker-gate.sh, PreToolUse)

Before each Bash command, checks state directory. If OPEN and cooldown not elapsed → blocks (`exit 2`). After cooldown → transitions to HALF-OPEN (allows one attempt). Success → CLOSED. Failure → OPEN again.

```
CLOSED ──(N failures)──→ OPEN ──(cooldown)──→ HALF-OPEN
  ↑                                              │
  └──────────(success)────────────────────────────┘
  OPEN ←──────(failure)───────────────────────────┘
```

State directory: `~/.cache/claude-circuit-breaker/<project-hash>/`

## Smart Context

Two implementations (mutually exclusive, declared as conflicts in manifest):

### v1 (preprocess-prompt.sh) — Stable

Keyword/trigram matching against a pre-built context index. Fast (~200ms). No external API calls. Injects relevant file paths and summaries into the prompt.

### v2 (smart-preprocess-v2.sh) — Stable

LLM-scored context injection. Sends the user's prompt to a fast model (Haiku) to score which context chunks are relevant. Slower (~500ms) but more accurate for ambiguous queries.

Both read from a context index built by `memory-compiler.sh` during Stop hooks.

## Global Project State (GPS)

`.bestai/GPS.json` — shared state bus for multi-agent workflows:

```json
{
  "project": "my-app",
  "version": "1.0",
  "agents": [],
  "active_tasks": [
    {"id": "T1", "description": "...", "status": "in_progress", "assigned_to": "claude-1"}
  ],
  "blockers": [],
  "milestones": [],
  "last_modified": "2026-02-27T14:30:00Z"
}
```

Updated by `sync-gps.sh` at session end. Protected by `flock` for concurrent access.

## Hook Composition

`hooks/manifest.json` declares the dependency graph:

```json
{
  "circuit-breaker-gate.sh": {
    "depends_on": ["circuit-breaker.sh"],
    "conflicts_with": [],
    "priority": 50,
    "estimated_latency_ms": 10
  }
}
```

`hook-lint.sh` validates:
- All hooks in the directory are declared in the manifest
- Dependencies are satisfied (e.g., gate depends on breaker)
- No conflicting hooks are enabled simultaneously
- Total latency per event stays within budget (PreToolUse: 200ms, Stop: 500ms)

## File Relationships

```
hook-event.sh ←── sourced by ──┬── check-frozen.sh
                               ├── circuit-breaker.sh
                               ├── backup-enforcement.sh
                               ├── wal-logger.sh
                               ├── secret-guard.sh
                               └── (all other hooks)

circuit-breaker.sh ──writes──→ state dir ──read by──→ circuit-breaker-gate.sh
memory-compiler.sh ──writes──→ context index ──read by──→ preprocess-prompt.sh
sync-state.sh ──writes──→ state delta ──read by──→ rehydrate.sh
ghost-tracker.sh ──writes──→ ghost-hits.log ──read by──→ preprocess-prompt.sh
```

## Maturity Assessment

| Component | Maturity | Evidence |
|-----------|----------|---------|
| Frozen file protection | **Stable** | 234 sessions, deterministic for Edit/Write |
| Circuit breaker | **Stable** | Tested, has gate integration |
| Memory GC | **Stable** | Generational scoring validated |
| Session persistence | **Stable** | Rehydrate/sync-state cycle tested |
| Event logging | **Stable** | JSONL format, compliance reporting |
| Smart Context v1 | **Stable** | Keyword matching, production-tested |
| Smart Context v2 | **Stable** | LLM scoring, latency-acceptable |
| GPS shared state | **Preview** | Implemented, limited multi-agent testing |
| Multi-vendor dispatch | **Preview** | Dispatcher exists, no production data |
| RAG/vector search | **Preview** | Script exists, no production validation |
| Budget monitoring | **Conceptual** | Script exists, no integration testing |
