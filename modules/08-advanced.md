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
