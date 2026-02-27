<div align="center">
  <img src="https://placehold.co/1200x300/1e1e2e/61afef?text=bestAI+v7.5&font=Montserrat" alt="bestAI Hero" />

  <h1>bestAI: Omni-Vendor Convergence</h1>
  
  <p><strong>The industry-leading orchestration layer for autonomous AI engineering swarms.</strong></p>

  [![NPM Version](https://img.shields.io/badge/npm-v7.5.0-blue?logo=npm)](https://www.npmjs.com/)
  [![Omni-Agent](https://img.shields.io/badge/syndicate-Claude_%7C_Gemini_%7C_Codex-purple?logo=ai)]()
  [![Security](https://img.shields.io/badge/security-Deterministic_Force--Field-red?logo=security)]()
  [![Coverage](https://img.shields.io/badge/hook_tests-100%25-brightgreen?logo=test)]()
  
  <p>
    <a href="#-the-vision">Vision</a> •
    <a href="#-syndicate-model">Syndicate Model</a> •
    <a href="#%EF%B8%8F-quick-start">Quick Start</a> •
    <a href="#-architecture">Architecture</a> •
    <a href="#-observability">Observability</a>
  </p>
</div>

---

## 🌌 The Vision: v7.5 (The Omni-Vendor Era)

**bestAI** is not just a tool; it's an operational standard for high-stakes software engineering. While others rely on prompt-engineering that agents follow only **6% of the time**, bestAI implements a **Deterministic Force Field (Bash Hooks)** that physically prevents agents from bypassing project rules.

> [!IMPORTANT]
> **New in v7.5:** Native support for **Heterogeneous Swarms**. Deploy the model that fits the task: Claude for architecture, Gemini for 2M context analysis, and Codex for boilerplate.

---

## 🤖 The Syndicate Model (Agent Roles)

<div align="center">
  <img src="assets/swarm-architecture.svg" alt="Swarm Architecture" width="800" />
</div>

| Role | Provider | Unique Strength | Task Focus |
| :--- | :--- | :--- | :--- |
| **Lead Architect** | **Claude Code** | Deep Reasoning & Hooks | Schema, Refactoring, Security |
| **Investigator** | **Gemini CLI** | **2M+ Context Window** | Codebase Mining, T3 Summaries |
| **Sprint Dev** | **Codex/OpenAI** | High Speed Boilerplate | Unit Tests, UI Components |

---

## 🏗️ The 5-Tier Context OS

We solve the **"Context Overload"** problem by segmenting information into distinct tiers, ensuring the agent always knows the most critical state without drowning in data.

<div align="center">
  <img src="assets/context-os-tiers.svg" alt="Context OS Tiers" width="800" />
</div>

- **T0 (HOT):** The **Global Project State (GPS.json)**. The project's brain.
- **T1 (WARM):** **T3-Summary.md**. The map of the entire codebase.
- **T2 (COOL):** The active module files the agent is editing.
- **T3 (COLD):** The rest of the codebase, accessed via **RAG-native router**.
- **T4 (FROZEN):** Configs and secrets protected by **Deterministic Hooks**.

---

## ⚡ Quick Start

### 1. Global Installation
```bash
npm install -g bestai
# or use npx instantly:
npx bestai init .
```

### 2. Dispatch Tasks to the Syndicate
```bash
# Research task for Gemini (utilizing 2M context)
bestai swarm --task "Find all deprecated auth calls" --vendor gemini

# Coding task for Claude
bestai swarm --task "Replace auth calls using results in GPS.json" --vendor claude
```

---

## 📊 Observability & Compliance

> [!TIP]
> **Trust but Verify.** Use the built-in dashboard to monitor your swarm's performance.

- **`bestai compliance`**: Real-time audit of how many times agents attempted to bypass rules.
- **`bestai doctor`**: Strict validation of your v7.5 project structure.
- **`tools/budget-monitor.sh`**: Automatic FinOps for token consumption.
- **`tools/session-replay.py`**: Interactively debug agent thoughts step-by-step.

---

## 🔄 Cross-Tool Compatibility

Already using Cursor or Windsurf? Translate bestAI standards instantly:
```bash
bestai generate-rules --format cursor
```

---

<div align="center">
  <p><br><b>Built for the next generation of autonomous engineering.</b><br>License: MIT | radekzm & the bestAI Swarm</p>
</div>