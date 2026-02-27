# Module 05: CS Algorithms for AI Agents

> Use this module when implementing robust agent behaviors.
> P0 algorithms include full implementation details (Problem → CS Origin → Agent Implementation → Hook/Rule).
> P1/P2 algorithms provide conceptual mapping for future implementation.

<!-- agents-md-compat -->

---

## P0: Critical (implement first)

### 1. Circuit Breaker Pattern

- **Problem**: Agent retries failing operation endlessly (150 rails runner errors in 40 sessions)
- **CS Origin**: Michael Nygard, "Release It!" (2007), distributed systems
- **States**: CLOSED (normal) → OPEN (failing, block calls) → HALF-OPEN (test one call)
- **Agent Implementation**: Track consecutive failures per error pattern. After N failures → STOP → show alternative → ask user
- **Hook**: PostToolUse (advisory) — tracks failures in `~/.cache/claude-circuit-breaker/`, injects STOP guidance into context after threshold. For deterministic blocking, pair with a PreToolUse hook that checks state.

```bash
# hooks/circuit-breaker.sh — advisory tracker (PostToolUse)
# Tracks: pattern → failure_count → state (CLOSED/OPEN/HALF-OPEN)
# OPEN state: advisory output telling agent to STOP + ROOT_CAUSE_TABLE
# HALF-OPEN: allow 1 attempt, if success → CLOSED
# NOTE: Pair with hooks/circuit-breaker-gate.sh for deterministic strict mode.
```

### 2. Write-Ahead Log (WAL)

- **Problem**: Destructive action without rollback; memory lost after compaction
- **CS Origin**: Database systems (PostgreSQL, SQLite) — log intent before execution
- **Agent Implementation**: Before any destructive action → write intent + timestamp to WAL file
- **Hook**: PreToolUse on Bash|Write|Edit — append to `~/.claude/projects/<project>/wal.log`

```
WAL Entry Format:
[2026-02-23T14:32:01] [LSN:47] [DESTRUCTIVE] [BASH] rm -rf /tmp/old-cache
[2026-02-23T14:35:22] [LSN:48] [WRITE] [FILE] src/auth/login.ts
[2026-02-23T14:36:05] [LSN:49] [MODIFY] [BASH] git commit -m "fix auth"
```

**Two tiers:**
- **P1: WAL Logging** (recommended) — audit trail for destructive actions. Hook: `hooks/wal-logger.sh`. Zero risk, high value.
- **P2: WAL Recovery** (optional, experimental) — SessionStart hook reads WAL after compaction/`/clear` to restore context. Useful in theory, but most agents don't benefit from raw WAL replay. Enable via REHYDRATE hook extension (module 06, line 48).

### 3. ARC (Adaptive Replacement Cache)

- **Problem**: Context window fills with stale/irrelevant information
- **CS Origin**: IBM Research, Megiddo & Modha (2003) — dynamically partitions cache between LRU and LFU sublists
- **Agent Implementation**: Track both recently-used and frequently-used context files. Maintain "ghost lists" (B1, B2) — what was evicted and later needed
- **Application**: Memory eviction policy; smart context preprocessor scoring

```
ARC-inspired heuristic for AI agents:
- T1 (recent): files loaded in current/last session
- T2 (frequent): files loaded in 3+ sessions
- B1 (ghost-recent): recently evicted files agent later needed
- B2 (ghost-frequent): frequently used files agent later needed
- Adaptive: ghost list hits shift the partition point (not a weighted score)
Note: This is an ARC-inspired heuristic, not a faithful ARC implementation.
```

### 4. Exponential Backoff + Jitter

- **Problem**: Repeated retries with same approach; "correction loop" anti-pattern
- **CS Origin**: Ethernet CSMA/CD, AWS retry recommendations
- **Agent Implementation**: Graduated escalation instead of binary retry/stop
- **Rule**: In CLAUDE.md or hook

```
Attempt 1: Retry with minor fix
Attempt 2: Reframe approach (different angle — "jitter")
Attempt 3: Delegate to subagent for independent assessment
Attempt 4: STOP + ROOT_CAUSE_TABLE (what tried | why failed | what to try next)
```

## P1: Recommended

### 5. Copy-on-Write (CoW)

- **Problem**: Subagent gets full memory copy or nothing; risk of overwriting [USER] entries
- **CS Origin**: OS process forking (fork(), ZFS, Btrfs)
- **Application**: Subagent starts with read-only reference to main memory. Writes go to local delta. After completion: merge delta if no [USER] conflicts

### 6. PID Controller

- **Problem**: Static compaction thresholds (50%/70%) don't adapt to project type
- **CS Origin**: Control theory — Proportional-Integral-Derivative feedback loop
- **Application**: Adaptive context budget. P = current occupancy vs target. I = cumulative trend. D = rate of change. Output: when to compact, split session, or delegate

### 7. Bloom Filter

- **Problem**: Preprocessor must scan all memory files for relevance
- **CS Origin**: Probabilistic data structure — O(1) "definitely not" or "maybe yes"
- **Application**: Quick pre-screening of memory files before loading. ~1KB for 1000 keywords, ~1% false positive rate. Eliminates unnecessary file reads

### 8. Feature Flags / Canary Deploy

- **Problem**: New rules may be wrong; need gradual rollout
- **CS Origin**: MLOps / deployment strategies — gradual rollout with metrics
- **Application**: New [AUTO] entries start with CONF: 0.5. After 5 sessions where agent uses and succeeds → CONF += 0.1. After failure → CONF -= 0.2. Below 0.3 → auto-remove. Above 0.8 → promote to FROZEN

### 9. Dead Code Elimination

- **Problem**: CLAUDE.md accumulates rules that never activate
- **CS Origin**: Compiler optimization — remove code with no effect on output
- **Application**: Session Intelligence tracks which rules were actually used. After 30 days unused → mark as CANDIDATE_FOR_REMOVAL → show user → decide: remove / keep / move to Skills

### 10. Generational GC

- **Problem**: Memory entries grow without bound; stale entries waste context
- **CS Origin**: Java/Go garbage collection — young/old generation with different policies
- **Application**: New entries = "young" (review after 7 days). Used 5+ sessions = "old" (review after 30 days). [USER] = "permanent roots" (never auto-collected)

## Algorithm Selection Guide

| Situation | Algorithm | Priority |
|-----------|-----------|----------|
| Agent repeats same error | Circuit Breaker | P0 |
| Need audit trail / recovery | WAL | P0 |
| Context routing optimization | ARC | P0 |
| Correction loop (3 failed batches) | Exponential Backoff | P0 |
| Subagent memory safety | Copy-on-Write | P1 |
| Auto-tuning thresholds | PID Controller | P1 |
| Fast context pre-screening | Bloom Filter | P1 |
| Gradual rule rollout | Feature Flags | P1 |
| Reducing CLAUDE.md bloat | Dead Code Elimination | P1 |
| Cleaning stale memory | Generational GC | P2 |

## Key Insight

> Both bestAI and AION already implement intuitive versions of these algorithms:
> - Progressive disclosure = Demand Paging / Huffman coding
> - [USER]/[AUTO] tags = Elitism (protected roots)
> - DRAFT/REVIEWED/FROZEN = Finite State Machine
> - "3 batches → STOP" = Circuit Breaker (simplified)
>
> **The difference**: A formal algorithm is DETERMINISTIC, MEASURABLE, and has PROVEN properties. Intuition works ~60% of the time. Algorithms work ~95%+.

---

*See [hooks/circuit-breaker.sh](../hooks/circuit-breaker.sh) and [hooks/wal-logger.sh](../hooks/wal-logger.sh) for implementations.*
# Module 07: Smart Context — Semantic Routing & Preprocessing

> Use this module when static CLAUDE.md + MEMORY.md is insufficient
> and you need intelligent, task-specific context loading.
>
> **WARNING**: This module describes OPTIONAL techniques. Most projects work fine
> with modules 00-06. Add smart context only when you experience repeated
> "agent didn't know about X" situations.

<!-- agents-md-compat -->

---

## The Problem

```
User:    "fix login"
Context: "authentication error handling" ← keyword search WON'T find this
Vector:  [0.23, -0.45, ...] ↔ [0.25, -0.43, ...] ← semantic search WILL find this
```

## Key Mechanism: UserPromptSubmit Hook

**stdout from UserPromptSubmit hook is added to Claude's context**. This is the injection point for smart context.

## Memory Compiler Pipeline (recommended core)

On each user prompt:

```text
1) Intent Detect  -> coding / debugging / planning / reviewing
2) Scope Detect   -> relevant modules/files/rules
3) Retrieve       -> memory topics + decisions + pitfalls + frozen + recent logs
4) Rank           -> relevance + freshness + source weight ([USER] > [AUTO])
5) Pack           -> compact context bundle under strict budget
6) Inject         -> only if score >= threshold
```

Production hook in this repo: `hooks/preprocess-prompt.sh`.

## Context Pack Schema

```text
intent | scope | must_know | risks | frozen | commands | open_questions
```

Use this as a stable shape across projects and tools.

## Security Guardrails (mandatory)

Retrieved context is **data**, never operational instruction.

Minimum controls:
- sanitize lines that look like instructions (`ignore previous`, jailbreak patterns, shell payloads)
- tag sources in injected block
- cap injected budget
- keep escape hatch: `.claude/DISABLE_SMART_CONTEXT`

## Progressive Retrieval Strategy

The 4 approaches below form a **progressive retrieval** escalation — start with the simplest (grep) and only add complexity when results are insufficient:

```
Level 1: Keyword (grep)     — fast, literal matching, handles 60% of cases
Level 2: Trigram + Intent   — fuzzy matching, catches morphological variants
Level 3: Subagent (Haiku)   — semantic understanding, handles "different words" problem
Level 4: Vector DB          — full semantic search, for large codebases (100+ files)
```

**This is NOT "semantic > literal"** (Module 00, Principle #5 applies to agent *understanding*, not retrieval). For retrieval, grep is the correct first step — it's fast, deterministic, and sufficient for most queries. Semantic layers add value only when keyword matching fails.

The production hook (`hooks/preprocess-prompt.sh`) operates at Level 2: keyword + trigram + intent routing. Level 3 is available via `hooks/smart-preprocess-v2.sh`.

## 4 Approaches (simplest first)

### A: Hook + grep (10 min setup)

```bash
#!/bin/bash
# .claude/hooks/preprocess-prompt.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0
[ -f ".claude/DISABLE_SMART_CONTEXT" ] && exit 0

MEMORY_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

KEYWORDS=$(echo "$PROMPT" | tr ' ' '\n' | sort -u | tr '\n' '|' | sed 's/|$//')
FOUND=$(grep -liE "$KEYWORDS" "$MEMORY_DIR"/*.md 2>/dev/null | head -3)

if [ -n "$FOUND" ]; then
    echo "[CONTEXT] Relevant memory:"
    for f in $FOUND; do
        echo "--- $(basename $f) ---"
        grep -i -C 1 "$KEYWORDS" "$f" 2>/dev/null | head -15
    done
fi
exit 0
```

### B: Subagent Selector (PRODUCTION, 20 min)

**Status: Production** — implemented in `hooks/smart-preprocess-v2.sh` with automatic fallback to keyword matching. Install via `--profile smart-v2`.

Uses fast model (Haiku) to intelligently select context:

```bash
#!/bin/bash
# .claude/hooks/smart-preprocess.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

CONTEXT_INDEX="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory/context-index.md"
[ ! -f "$CONTEXT_INDEX" ] && exit 0

SELECTED=$(claude -p --model haiku "
Task: '$PROMPT'
Available contexts:
$(cat "$CONTEXT_INDEX")
Return ONLY 1-3 most relevant file paths." 2>/dev/null)

if [ -n "$SELECTED" ]; then
    echo "[CONTEXT] Smart selection:"
    echo "$SELECTED" | while read f; do [ -f "$f" ] && head -30 "$f"; done
fi
exit 0
```

**Cost**: ~$0.001/query. **Latency**: 500ms-2s.

### C: Vector DB (most accurate, 1-2h setup)

For large projects (100+ files):

```python
# Embed: rules, memory, code, commits, issues
# Query: embedding of user prompt → cosine similarity → top 5
# Return: snippets with relevance score > 70%
```

### D: Agent Hook (native, 2026)

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "agent",
        "prompt": "Analyze this task and find relevant context files in docs/ and memory/. $ARGUMENTS",
        "model": "haiku",
        "timeout": 60
      }]
    }]
  }
}
```

## Comparison

| Feature | A: grep | B: Subagent | C: Vector DB | D: Agent Hook |
|---------|---------|-------------|--------------|---------------|
| Accuracy | 60% | 85% | 95% | 85% |
| Latency | <100ms | 500ms-2s | 200ms-1s | 1-3s |
| "Different words" | NO | YES | YES | YES |
| Setup | 10 min | 20 min | 1-2h | 5 min |
| **Recommendation** | MVP | **Best balance** | Large projects | Native option |

## Context Budget Rule

```
NEVER inject more than 15% of context window.
At 200k tokens: max 30,000 tokens from preprocessor (~15%)
```

## Escape Hatch

Always maintain ability to disable:

```bash
# Disable: touch .claude/DISABLE_SMART_CONTEXT
# Enable:  rm .claude/DISABLE_SMART_CONTEXT
```

## Important Caveat: Anthropic's Decision

> Anthropic tested RAG with local vector DB in early Claude Code versions and
> **deliberately dropped it** in favor of "agentic search" (grep + glob + read).
> — [Anthropic Engineering Blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Community filled this gap with open-source projects (claude-mem 4700+ stars, claude-context 4000+ stars). The pragmatic consensus: **agentic as backbone, semantic index only where needed**.

## Security Reference

- OWASP GenAI Top 10 (prompt injection risk model): https://genai.owasp.org/llm-top-10/
- Anthropic Hooks docs (UserPromptSubmit behavior): https://docs.anthropic.com/en/docs/claude-code/hooks

## Evidence Register

| Claim | Status | Evidence |
|------|--------|----------|
| UserPromptSubmit stdout is injected into model context | external | Anthropic hooks docs |
| Guardrails are required for retrieval safety | external | OWASP GenAI Top 10 |
| Lightweight retrieval + ranking is sufficient for many repos | validated locally | `hooks/preprocess-prompt.sh` + tests |
| Semantic/vector layer improves large-codebase recall | heuristic | community benchmarks and practice |

## When Smart Context IS vs ISN'T Worth It

| Project Size | Smart Context? | Why |
|-------------|---------------|-----|
| < 20 files | **NO** | CLAUDE.md + MEMORY.md sufficient |
| 20-100 files | **MAYBE** | If many rules/decisions/memory files |
| 100-500 files | **YES** | Keyword search can't keep up |
| 500+ files | **ESSENTIAL** | Without semantic search, agent drowns |

---

*See [08-advanced](08-advanced.md) for vector DB details and [11-prompt-caching](11-prompt-caching.md) for cache-aware runtime optimization.*
# Module 08: Advanced & Experimental

> Use this module for large-scale projects, multi-agent setups, or research.
>
> **WARNING**: Everything in this module is EXPERIMENTAL. The techniques below
> have limited production validation. Use at your own risk and measure results.

<!-- agents-md-compat -->

---

## Observational Memory (L4) — RECOMMENDED

**Status: Recommended** — implemented in `hooks/observer.sh` (Stop hook) and `hooks/reflector.sh` (maintenance). Install via `--profile smart-v2` or `--profile aion-runtime`.

### Concept: Observer + Reflector

Two background agents compress conversation history in-place:

```
Conversation flow
  │ (every ~30,000 new tokens)
  ↓
OBSERVER
  - Reads new messages
  - Compresses to "observations" (3-6x text, 5-40x tools)
  - Adds observations to context prefix
  - Original messages → removed
  │ (every ~40,000 tokens of observations)
  ↓
REFLECTOR
  - Restructures and condenses observation block
  - Merges related items
  - Removes outdated information
```

**Origin**: Mastra framework (94.87% on LongMemEval benchmark with GPT-5-mini).

**CAVEAT**: The benchmark was measured on Mastra's native implementation, NOT on bash/hook implementations. Your mileage will vary significantly.

### Simplified Hook Implementation

```bash
#!/bin/bash
# hooks/observe-and-compress.sh — Stop hook
# Lightweight version — spawns Haiku subagent for compression

SESSION_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')"
OBSERVATION_FILE="$SESSION_DIR/memory/observations.md"

# Only run every ~50 agent responses (check counter)
COUNTER_FILE="/tmp/claude-observe-counter"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

[ $((COUNT % 50)) -ne 0 ] && exit 0

# Compress recent activity
claude -p --model haiku "
Compress these recent observations into max 10 bullet points.
Focus on: decisions made, files changed, errors encountered, user preferences.
$(tail -100 "$OBSERVATION_FILE" 2>/dev/null)
" >> "${OBSERVATION_FILE}.new" 2>/dev/null

[ -f "${OBSERVATION_FILE}.new" ] && mv "${OBSERVATION_FILE}.new" "$OBSERVATION_FILE"
exit 0
```

## Vector DB Options (2026)

| DB | Type | Best For | Cost |
|----|------|----------|------|
| **sqlite-vec** | Embedded (SQLite ext.) | **2026 trend** — zero infra | Free |
| **Chroma** | Embedded/local | Solo dev, quick start | Free |
| **pgvector** | PostgreSQL extension | Projects with existing PG | Free |
| **Pinecone** | Cloud (managed) | Enterprise, team | $$$→Free tier |
| **LanceDB** | Embedded/serverless | Light, Git-friendly | Free |

**Recommendation**:
- Solo dev → sqlite-vec or Chroma
- Team with PostgreSQL → pgvector
- Enterprise → Pinecone (MCP integration available)

### Hybrid Search

Pure semantic search fails on proper names and file paths. Combine:

```python
def hybrid_search(query, alpha=0.7):
    """alpha=0.7 → 70% semantic, 30% keyword. Optimal for code + docs."""
    semantic = vector_db.search(embed(query), top_k=20)
    keyword = text_index.search(query, top_k=20)
    return merge_and_rerank(semantic, keyword, weights=(alpha, 1-alpha))[:10]
```

## Session Intelligence

### Concept

Analyze historical JSONL transcripts to discover patterns:

```
JSONL transcripts → [Extractor] → [Analyzer] → [Recommender]
  - Which tools are used most?        - Repeated errors?
  - Which files read most often?       - Patterns in successful sessions?
  - Compaction frequency?              - New rules needed?
```

### Existing Tools

| Tool | Architecture | Key Feature |
|------|-------------|-------------|
| [CASS](https://github.com/Dicklesworthstone/coding_agent_session_search) | SQLite + Tantivy | Sub-60ms search, 11+ providers |
| [DuckDB Analysis](https://liambx.com/blog/claude-code-log-analysis-with-duckdb) | SQL on JSONL | Zero ETL |
| [total-recall](https://github.com/radu2lupu/total-recall) | BM25 + vector | Cross-session semantic memory |

**CAVEAT**: Session Intelligence generates reports. Reports need readers. Only implement if you'll actually act on the data.

## Agent Teams (Experimental)

Multi-agent coordination with Claude Code:

```
Team Lead (main session)
  ├─ Agent A: Implementation (worktree A)
  ├─ Agent B: Tests (worktree B)
  ├─ Agent C: Documentation (worktree C)
  └─ DEVIL_ADVOCATE: Reviews all (fresh context)
```

### Requirements
- Git worktrees for isolation
- Shared memory via files (MEMORY.md)
- Team lead orchestrates via `claude -p`
- 5-8 agents max (diminishing returns beyond)
- Use `templates/agent-teams-output.md` for consistent aggregation format

**CAVEAT**: Claude Code Agent Teams is still evolving. Manual coordination overhead may exceed benefits for most projects. Best suited for large refactoring or migration tasks.

## Open-Source Context Systems

| Project | Architecture | Stars | Key Feature |
|---------|-------------|-------|-------------|
| [claude-mem](https://github.com/thedotmack/claude-mem) | 6-layer, FTS5+ChromaDB | 4700+ | Hybrid search, 5 hooks |
| [c0ntextKeeper](https://github.com/Capnjbrown/c0ntextKeeper) | 7 hooks, 187 patterns | — | Temporal decay, PII redaction |
| [Continuous-Claude-v3](https://github.com/parcadei/Continuous-Claude-v3) | 32 agents, 30 hooks | — | Ledger-based continuity |
| [Mem0](https://github.com/mem0ai/mem0) | Graph memory | — | 26% accuracy improvement |
| [Volt](https://github.com/voltropy/volt) | DAG summarization | — | Lossless context management |

## AION Manual vs Automated Pipeline — Trade-offs

Two approaches to context compilation exist in production:

| Aspect | AION (manual) | bestAI (automated) |
|--------|---------------|-------------------|
| **Method** | Agent writes TOP-10/5/3 explicitly via SYNC_STATE | Hooks compute scores, trigrams, and inject automatically |
| **Latency** | ~0ms on read (pre-compiled state file) | ~50-200ms per prompt (scoring pipeline) |
| **Accuracy** | High — agent curates with full session context | Medium — keyword/trigram matching, no semantic understanding |
| **Staleness** | Risk: agent forgets to SYNC_STATE | Low: hooks run deterministically on every event |
| **Token cost** | ~200 tokens for state file | ~50-1500 tokens for injected context |
| **Failure mode** | Incomplete SYNC → stale state next session | Cache miss → slightly slower, still correct |
| **Best for** | Small teams, high-stakes projects | Large memory dirs, frequent prompts |

**Recommendation**: Use both. AION's SYNC_STATE maintains human-readable state (module 06), while automated hooks handle high-frequency scoring (module 07). They complement — SYNC_STATE captures intent, hooks capture relevance.

## Success Metrics for Memory Systems

| Metric | Formula | Target | How to Measure |
|--------|---------|--------|----------------|
| **Token ROI** | useful_tokens / injected_tokens | >0.5 | Count lines from injected context that appear in agent's response |
| **Retrieval accuracy** | relevant_files_injected / relevant_files_total | >0.7 | Compare injected sources vs files agent actually reads |
| **Cost-per-task** | total_tokens_used / tasks_completed | Decreasing | Track via `evals/cache-usage-report.sh` over time |
| **Cache hit rate** | cache_valid / (cache_valid + cache_miss) | >0.8 | Count etag_validate "valid" vs "stale"+"missing" |
| **False injection rate** | irrelevant_injections / total_injections | <0.1 | Review [SMART_CONTEXT] blocks in session transcripts |

**Measuring in practice:**
```bash
# Token ROI proxy: compare injected sources with files agent reads in session
grep 'sources:' /path/to/transcript.jsonl | # what was injected
grep 'Read tool' /path/to/transcript.jsonl   # what agent actually read

# Cache hit rate (from E-Tag cache)
grep -c 'valid' /tmp/etag-debug.log   # hits
grep -c 'stale\|missing' /tmp/etag-debug.log  # misses
```

## Context-Bench Integration (research)

[Context-Bench](https://www.letta.com/blog/context-bench) (Letta, 2026) benchmarks long-context memory tasks. Key finding: even frontier models achieve only **74% accuracy** on structured memory retrieval.

**Relevance to bestAI:**
- Validates the need for active context management (models alone aren't enough)
- Provides standardized tasks for evaluating memory systems
- bestAI's eval framework (`evals/run.sh`) can be extended with Context-Bench-style tasks

**Integration path** (when ready):
1. Add Context-Bench task format to `evals/tasks/`
2. Map bestAI scoring dimensions to Context-Bench metrics
3. Compare: Smart Context injection accuracy vs raw model accuracy on same tasks

**Status**: Not yet integrated. Current evals use custom benchmarks (`evals/data/`). Context-Bench compatibility is a future enhancement.

## Maturity Guide

| Feature | Maturity | Confidence | When to Use |
|---------|----------|------------|-------------|
| Observational Memory | Alpha | Low | Long sessions (>500 tools) |
| Vector DB search | Beta | Medium | Large codebases (100+ files) |
| Session Intelligence | Beta | Medium | When you'll act on reports |
| Agent Teams | Alpha | Low | Large migrations/refactors |
| Hybrid search | Production | High | Multi-language projects |

---

*This module is experimental. Validate everything against your specific use case.*
*See [modules 00-06](../modules/) for production-ready guidelines.*
# Module 13: Agent Orchestration (Team Lead)

> Use this module for complex multi-agent setups where different agents take on specific roles
> such as Developer, Reviewer, and Tester, working in parallel.

<!-- agents-md-compat -->

---

## Overview

As projects scale, a single agent attempting to handle all aspects (frontend, backend, database, testing, devops) leads to context saturation and errors. The **Automated Agent Orchestrator** in bestAI v4.0 solves this through specialized roles.

## Core Concepts

### 1. Parallel Spawning

Instead of linear, step-by-step processing, a master agent (or human user via CLI) can spawn multiple sub-agents in parallel Git worktrees.
- **Git Worktrees:** Allows multiple branches to be checked out simultaneously in different directories.
- **Roles:** For example, Agent A works on `feature-api` in `/worktrees/api`, while Agent B works on `feature-ui` in `/worktrees/ui`.
- **GPS Integration:** The Global Project State (`.bestai/GPS.json`, see Module 12) coordinates these parallel efforts.

### 2. Cross-Agent Review (Devil’s Advocate)

A critical component of reducing bugs is automated peer review.
- Before code is merged, a specialized "Devil's Advocate" agent is invoked.
- This agent's prompt explicitly instructs it to search for security vulnerabilities, edge cases, performance bottlenecks, and style guide violations, *ignoring* the implementation struggle of the primary agent.
- The Reviewer provides feedback in a structured `REVIEW.md` file, which the Developer agent must address before proceeding.

## Implementation Example

```bash
#!/bin/bash
# hooks/parallel-spawn.sh — Example Custom Tool

# Spawns a new Claude session for a specific role
ROLE=$1
TASK_DESC=$2
WORKTREE_DIR=".worktrees/$ROLE"

git worktree add -b "task-$ROLE" "$WORKTREE_DIR" main
echo "Starting agent in $WORKTREE_DIR with role: $ROLE"

# In a real environment, you'd launch the specific agent config here
cd "$WORKTREE_DIR" && claude -p "ROLE: $ROLE. Task: $TASK_DESC. Use GPS.json for context."
```

## Setup

1. Configure your repository to use Git worktrees if you plan to use parallel agents.
2. Define distinct `CLAUDE.md` or `instructions.md` profiles for different roles (e.g., `CLAUDE_REVIEWER.md`, `CLAUDE_DEVELOPER.md`).

---

*This module builds upon the Experimental Agent Teams introduced in Module 08.*# Module 14: Semantic Context Router v4 (RAG-Native)

> Use this module to completely bypass the limitations of keyword-based context
> search by integrating a true Vector Database (RAG) into the agent's memory.

<!-- agents-md-compat -->

---

## Overview

Previous versions of bestAI relied on keyword matching (`grep`) and trigrams for context injection (Module 07). While fast, this fails on semantic queries (e.g., "how does auth work" vs searching for the literal word "auth").

v4.0 introduces the **Semantic Context Router**, transforming the local workspace into a Retrieval-Augmented Generation (RAG) system.

## Key Features

### 1. Cross-Session Long-Term Memory

By embedding session summaries, architectural decisions, and resolved bugs into a local vector DB (like `sqlite-vec` or `ChromaDB`), the agent gains "perfect memory" across weeks of development.
- When an agent encounters an issue, it queries the vector DB: `search_memory("How did we fix the OAuth token refresh bug last month?")`
- The DB returns semantically relevant past decisions without bloating the main `MEMORY.md` file.

### 2. Context Sharding

In massive monorepos, even embedding the whole project is too noisy. **Context Sharding** splits the vector embeddings into role-specific "shards".
- **Backend Shard:** API routes, DB schema, server config.
- **Frontend Shard:** React components, CSS, UI logic.

When a "Backend Agent" is spawned (Module 13), it is only allowed to query the Backend Shard, drastically improving retrieval precision.

## Architecture

```text
[User Prompt]
      │
      ▼
[Semantic Router Hook (v4)]
      │
      ├──> Queries Vector DB (sqlite-vec)
      ├──> Retrieves top-K semantically relevant snippets
      └──> Injects snippets into T2 (COOL) Context Tier
      │
      ▼
[Agent Processes Request]
```

## Migration Path

1. Choose a local vector DB. We recommend **sqlite-vec** for zero-infrastructure setups in 2026.
2. Implement an embedding script (e.g., using `sentence-transformers` locally or an embedding API) that runs periodically on your codebase and `MEMORY.md` overflow.
3. Update `preprocess-prompt.sh` to query this database instead of relying solely on `grep`/trigrams.

---

*This is an advanced feature requiring additional local setup (Vector DB).*