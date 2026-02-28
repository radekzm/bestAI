# Module 05: The Human-AI Nexus (Collaboration)

> This module defines how teams of humans (Junior, Senior, Manager) and swarms of AI agents 
> collaborate within a single project using bestAI as the shared coordination layer.

---

## 👥 Human Roles in the Nexus

bestAI v13.0 introduces explicit roles to tailor the AI's behavior and the intensity of enforcement hooks.

| Role | Responsibility | bestAI Configuration |
| :--- | :--- | :--- |
| **Lead / Architect** | Strategic decisions, Core security | Permissive hooks, High-level GPS access. |
| **Developer** | Feature implementation | Standard hooks, Recursive Swarm access. |
| **Junior / New Joiner** | Bug fixes, learning | Strict hooks (Fail-Closed), mandatory code reviews by Reviewer-Agent. |
| **Stakeholder** | Monitoring, Requirements | Read-only access to Cockpit & ROI Dashboard. |

## 🧠 Shared Decision Capture

All significant engineering decisions must be logged via the Nexus protocol to prevent "Knowledge Silos."

### 1. The Nexus Journal
Every human-driven decision (e.g., "We chose PostgreSQL over MongoDB because...") is stored in `.bestai/nexus_journal.jsonl`. 
- Agents read this at boot (Tier T0).
- Prevents AI from suggesting architectural changes that contradict human decisions.

### 2. Multi-User GPS Handshake
The `GPS.json` now includes a `contributors` array, tracking the evolution of the project state across different team members.

## 🚀 Onboarding a New Human
When a new person joins the project:
1. They run `bestai onboard --user "Name" --role "Junior"`.
2. bestAI generates a custom `CLAUDE.md` / `.cursorrules` tailored to their role.
3. The AI agent becomes a mentor, explaining historical decisions found in the **Research Vault**.

---

*Together, we build better. The Nexus ensures AI works for the team, not just the individual.*