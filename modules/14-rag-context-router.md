# Module 14: Semantic Context Router v4 (RAG-Native)

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