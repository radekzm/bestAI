# Multi-Vendor Swarm Blueprint (v7.0)

This blueprint assigns tasks to different AI vendors based on their unique architectural strengths. All agents share context via `.bestai/GPS.json`.

## 1. The Architect / Backend Developer
**Recommended Vendor:** `Claude Code` (Anthropic)
**Why:** Superior logical reasoning, deep refactoring capabilities, and strict adherence to Bash hooks.
**Task Scope:** DB Schema, API logic, Security implementations, architectural decisions.
**Command:** `claude -p "ROLE: Architect. Read GPS.json. Build the core API."`

## 2. The Investigator / Context Miner
**Recommended Vendor:** `Gemini CLI` (Google)
**Why:** Massive 2M+ context window, blazing fast, native web-search if needed.
**Task Scope:** Ingesting massive amounts of legacy code, writing `.bestai/T3-summary.md` indexes, generating documentation, or finding bugs across thousands of files.
**Command:** `gemini -p "ROLE: Investigator. Read the entire /src dir and update T3-summary.md."`

## 3. The Tester / UI Iteration
**Recommended Vendor:** `Codex / OpenAI`
**Why:** Fast generation of boilerplate, strong at unit tests and standard UI components.
**Task Scope:** Writing Jest/PyTest unit tests for logic built by Claude, or churning out React/Tailwind components.
**Command:** `codex-cli --prompt "ROLE: Tester. Look at recent GPS.json tasks. Write tests for them."`

## Context Rules
- **Shared Bus:** ALL agents MUST read `.bestai/GPS.json` at the start of their session.
- **Hook Enforcement:** Ensure your specific CLI tool is configured to run the scripts in `.claude/hooks/` (or run `bestai test` manually if the CLI doesn't support automatic pre-tool hooks).
