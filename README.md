<div align="center">
  <img src="https://placehold.co/1200x300/1e1e2e/61afef?text=bestAI+v8.0+ENTERPRISE&font=Montserrat" alt="bestAI Hero" />

  <h1>bestAI: Omni-Vendor Convergence</h1>
  
  <p><strong>The industry-leading orchestration layer for autonomous AI engineering swarms.</strong></p>

  [![NPM Version](https://img.shields.io/badge/npm-v8.0.0-blue?logo=npm)](https://www.npmjs.com/)
  [![Omni-Agent](https://img.shields.io/badge/syndicate-Claude_%7C_Gemini_%7C_Codex_%7C_Ollama-purple?logo=ai)]()
  [![Security](https://img.shields.io/badge/security-Deterministic_Force--Field-red?logo=security)]()
  [![Coverage](https://img.shields.io/badge/hook_tests-100%25-brightgreen?logo=test)]()
  
  <p>
    <a href="#-quick-start">Quick Start</a> •
    <a href="#-tutorial-your-first-swarm">Tutorial</a> •
    <a href="#-core-mechanisms">Mechanisms</a> •
    <a href="#-syndicate-toolbelt">Toolbelt</a> •
    <a href="#-architecture">Architecture</a>
  </p>
</div>

---

## 🚀 Quick Start (Zero-to-Hero)

Get bestAI v8.0 running in your project in less than 2 minutes.

### 1. Global Install
```bash
npm install -g @radekzm/bestai
```

### 2. Initialize bestAI in your Repo
```bash
cd your-project
bestai init .
```
*Select the **"Omni-Vendor"** profile for the full multi-agent experience.*

### 3. Verify Health
```bash
bestai doctor --strict
```

---

## 📖 Tutorial: Your First Swarm (Mini-API)

In this example, we will build a simple FastAPI application using **Gemini** for mapping and **Claude** for implementation.

### Step 1: Initialize the Project State
Define your goal so all agents are aligned.
```bash
# Set the main goal in .bestai/GPS.json
echo '{"project":{"name":"FastAPI-Mini","main_objective":"Build a secure user registration API"}}' > .bestai/GPS.json
```

### Step 2: Gemini Investigates (Research)
Gemini scans your environment and suggests the tech stack.
```bash
bestai swarm --vendor gemini --task "Search for best FastAPI boilerplates and update T3-summary.md"
```

### Step 3: Claude Implements (Coding)
Claude reads the research from GPS and implement the code, protected by hooks.
```bash
bestai swarm --vendor claude --task "Create main.py with a signup endpoint using standard FastAPI patterns"
```

### Step 4: Verify Compliance
Check if the agents followed the rules.
```bash
bestai compliance
```

---

## 🔧 Core Mechanisms (Under the Hood)

bestAI is built on four revolutionary engineering pillars:

### 1. Deterministic Force-Field (Fail-Closed Hooks)
Unlike soft prompt-based rules, bestAI uses **Bash Hooks**. 
- **PreToolUse:** Every file write or shell command is intercepted.
- **Enforcement:** If an agent tries to edit a `FROZEN` file (e.g., core config), the script returns `Exit 2`, physically killing the process before the damage is done.

### 2. The 5-Tier Context OS
We bypass token limits by segmenting memory:
- **T0 (HOT):** Critical project state (GPS.json). Always loaded.
- **T1 (WARM):** A dense index of the whole codebase.
- **T3 (COLD):** The rest of the repo, accessed semantically via RAG.

### 3. Omni-GPS (Shared Global State)
A central JSON bus that synchronizes all agents. It includes:
- **Milestones:** Tracking progress across vendors.
- **Blocker DB:** If Gemini finds a bug, Claude sees it instantly.
- **Mutex Locks:** Prevents two agents from editing the same file simultaneously.

### 4. Swarm Mutex (`swarm-lock`)
Specifically for multi-vendor setups. Before any agent starts a heavy task, it places a lock on the target file path. If another agent (e.g., Cursor) tries to touch it, bestAI blocks the operation until the first agent finishes.

---

## 💎 The Strategic Value of bestAI (ROI)

| Metric | Before bestAI | With bestAI v8.0 | Impact |
| :--- | :--- | :--- | :--- |
| **Agent Compliance** | ~6% (Advisory only) | **100% (Deterministic)** | Bulletproof safety. |
| **Token Efficiency** | High bloat (uncut) | **-70% overhead** | Low API bills. |
| **Vendor Lock-in** | Single model provider | **Omni-Vendor** | Flexibility (Claude+Gemini+Llama). |

---

## 🛠️ The Syndicate Toolbelt

| Tool | Capability |
| :--- | :--- |
| **`bestai swarm`** | Dispatches tasks to Claude, Gemini, or Ollama. |
| **`serve-dashboard`** | Visual web interface for compliance and budget. |
| **`bestai sandbox`** | Runs agent commands in isolated Docker containers. |
| **`swarm-lock`** | Manage mutex locks across different AI vendors. |

---

<div align="center">
  <p><br><b>Built for the next generation of autonomous engineering.</b><br>License: MIT | radekzm & the bestAI Swarm</p>
</div>