# 🎭 bestAI v10.0 Living Swarm Demo

This document explains the demo scenario for the **Syndicate Conductor** (v10.0).

## The Scenario: "Legacy Migration"

In this demo, you will witness how bestAI manages a high-stakes migration task using multiple specialized agents working in parallel.

### 🎬 How to run:
```bash
python3 tools/v10-demo.py
```

### 🧠 What you are seeing:

1.  **Instant Delegation:** The Conductor (Lead Agent) instantly routes a research task to Gemini (optimized for large context) while keeping the conversation open with you.
2.  **Parallel Thinking:** While Gemini is scanning "45 legacy files" in the background, you are already making architectural decisions (naming secrets) with the Conductor.
3.  **Noise Filtering:** Notice that Gemini's low-level logs are hidden ("SILENT"). The Conductor only interrupts you when Gemini finds a **Critical Security Risk** (MD5 usage).
4.  **Handoff:** The Conductor automatically uses Gemini's research to brief Claude (Lead Architect) for the implementation phase.
5.  **Research Vault:** The system mentions saving 45k tokens. This is because Gemini's findings were cached with a TTL, so no future agent needs to re-scan those legacy files.

---

## 🚀 Experience the Power
Version 10.0 isn't just about coding; it's about **Autonomous Team Management**. 

**[Go back to README](../README.md)**
