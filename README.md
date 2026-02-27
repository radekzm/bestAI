<div align="center">
  <img src="https://placehold.co/800x200/1e1e2e/61afef?text=bestAI+v7.0+OMNI-VENDOR&font=Montserrat" alt="bestAI Logo" />

  <h1>bestAI v7.0: Omni-Vendor Convergence</h1>
  
  <p><strong>The industry's first Multi-LLM Orchestration Layer for Autonomous Engineering Swarms.</strong></p>

  [![NPM Version](https://img.shields.io/badge/npm-v7.0.0-blue?logo=npm)](https://www.npmjs.com/)
  [![Omni-Agent](https://img.shields.io/badge/swarm-Claude_%7C_Gemini_%7C_Codex-purple)]()
  [![Enforcement](https://img.shields.io/badge/security-Deterministic_Hooks-red)]()
  [![Compliance](https://img.shields.io/badge/observability-Real--time-brightgreen)]()
  
  <p>
    <a href="#-the-v7-vision">The v7 Vision</a> •
    <a href="#-agent-synergy">Agent Synergy</a> •
    <a href="#%EF%B8%8F-quick-start">Quick Start</a> •
    <a href="#-omni-vendor-gps">Omni-GPS</a> •
    <a href="#-architecture">Architecture</a>
  </p>
</div>

---

## 🌌 The v7 Vision

**bestAI v7.0** marks the end of vendor lock-in. Instead of relying on a single AI provider, v7.0 orchestrates a **Heterogeneous Swarm** of specialized agents. Each task is routed to the model with the best architectural fit, while a shared "Project Brain" (GPS) ensures total coherence.

---

## 🤖 Agent Synergy (The Dream Team)

In v7.0, you don't just use an agent; you deploy a **Syndicate**:

| Agent Type | Provider | Unique Edge | Core Task |
|------------|----------|-------------|-----------|
| **Lead Architect** | **Claude Code** | Deep Reasoning & Hooks | Schema, Refactoring, Security |
| **Investigator** | **Gemini CLI** | **2M+ Context Window** | Codebase Mining, T3 Summaries, Docs |
| **Sprint Developer** | **Codex/OpenAI** | High Speed & Boilerplate | Unit Tests, UI Components, Prototypes |

---

## ✨ Omni-Vendor Features

<details open>
<summary><b>🛰️ Global Project State (Omni-GPS)</b></summary>
<br>
A shared context bus protected by `flock` locking. Whether it's Claude writing a module or Gemini analyzing a bug, they all sync milestones, tasks, and blockers into `.bestai/GPS.json`.
</details>

<details open>
<summary><b>🛠️ Multi-Agent Dispatcher</b></summary>
<br>
New command: `bestai swarm --task "Refactor API" --vendor claude`. Automatically routes complex prompts to the correct CLI tools with pre-loaded shared context.
</details>

<details open>
<summary><b>📈 Real-time Compliance & FinOps</b></summary>
<br>
Monitor your heterogeneous swarm usage with `bestai compliance` and `tools/budget-monitor.sh`. Track spend and compliance across different API providers in a single view.
</details>

---

## ⚡ Quick Start

### 1. Global Deployment
```bash
npx bestai setup . --blueprint swarm
```

### 2. Dispatch a Task to the Swarm
Assign a research task to Gemini (utilizing its 2M context) and a coding task to Claude:
```bash
# Agent 1 (Gemini): Summarize the legacy project
bestai swarm --task "Map the entire src/legacy folder" --vendor gemini

# Agent 2 (Claude): Refactor based on Gemini's findings
bestai swarm --task "Implement new auth based on legacy findings in GPS.json" --vendor claude
```

---

## 🏗️ The Pillars of v7.0

| Module | Purpose |
|--------|---------|
| **[01-CORE](modules/01-core.md)** | **The Force Field**: Deterministic hooks & GPS state management. |
| **[02-OPERATIONS](modules/02-operations.md)** | **The Engine**: Session replay, caching, and budget tracking. |
| **[03-ADVANCED](modules/03-advanced.md)** | **The Swarm**: Multi-vendor orchestration, RAG, and worktrees. |

---

## 🔄 Tools & Automation

- `tools/swarm-dispatch.sh`: The master conductor for multi-vendor tasks.
- `tools/session-replay.py`: Debug any agent's thoughts across providers.
- `tools/generate-rules.sh`: Export bestAI v7.0 rules to Cursor or Windsurf.

<div align="center">
  <p><br><b>bestAI v7.0: One Context, Every Agent.</b><br>License: MIT</p>
</div>
