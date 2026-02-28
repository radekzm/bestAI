# Module 04: OpenClaw Integration — Total Recall Mode

> Use this module when deploying bestAI within an **OpenClaw** environment.
> Rule #1: **Never slim down the context.** Context is fuel, and in OpenClaw, we have a full tank.

---

## 🌌 The Total Recall Philosophy

Unlike standard agentic workflows that prune memory to save tokens, the **OpenClaw + bestAI** synergy prioritizes **Total Awareness**. 

### 1. Persistent Memory Binding
Every interaction, decision, and logic-path is stored in the `.bestai/history/` directory. Instead of the Memory Compiler scoring and deleting old logs, we use:
- **Append-Only Journals:** All session summaries are concatenated into a "Master Project Chronology".
- **Deep Linking:** Every milestone in `GPS.json` links to the full tool-call log of its creation.

### 2. Bypassing Efficiency Gates
When `BESTAI_OPENCLAW=1` is active:
- `memory-compiler.sh` acts as an **Archiver**, not a Pruner.
- The 5-Tier Context OS merges T1, T2, and T3 into a single **Super-Tier** loaded at boot.

## 🛠️ OpenClaw Deployment Setup

1. **Environment Variable:** Set `BESTAI_OPENCLAW=1` in your OpenClaw container.
2. **Infinite History:** Configure `rehydrate.sh` to pull the last 50 session logs instead of the usual 5.
3. **Omni-GPS Handshake:** OpenClaw agents use the `swarm-lock` mechanism to ensure that even with massive context, they don't drift into concurrent edit conflicts.

---

## 🔧 Operational Directives for OpenClaw Agents

1. **Self-Document Everything:** Every time you complete a task, write a verbose entry to `.bestai/LOG.md`. Do not summarize; detail the *why*.
2. **Context Injection:** On every prompt, load the "Master Project Chronology".
3. **Zero Deletion:** Never delete a file from the `memory/` or `logs/` directory.

*This integration makes bestAI the most knowledgeable engineer on your team.*