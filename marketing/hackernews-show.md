# 🛡️ Hacker News - Show HN Template

**Title:** Show HN: bestAI v7.5 – An OS for multi-vendor AI coding agents (Claude+Gemini)

**First Comment:**

Hi HN!

I built bestAI because I was tired of AI coding agents (like Claude Code, Cursor, Windsurf) completely forgetting architectural rules during long sessions and breaking production code. Data showed that prompt-based rules (like CLAUDE.md) are only followed ~6% of the time in deep workflows.

bestAI v7.5 is an Omni-Vendor CLI that replaces "advisory" prompting with deterministic **Fail-Closed Bash Hooks**. If an agent tries to edit a frozen file or skips a mandatory backup, it gets a hard `Exit 2` block. 

### Key Features of v7.5:
- **Omni-Vendor Swarms:** Deploy a "Syndicate" using Claude (for reasoning), Gemini (utilizing its 2M context window for mining), and Codex (for tests).
- **Omni-GPS:** All agents synchronize via a locked `.bestai/GPS.json` file.
- **Context Tiers:** Infinite scalability via a 5-tier Context OS (Hot, Warm, Cool, Cold, Frozen).
- **Observability:** Built-in tools for session replay, budget monitoring, and compliance metrics.

You can try it instantly via `npx @radekzm/bestai@latest init .`. 

I'd love to hear your thoughts on managing AI agent compliance in massive codebases!

Repo: https://github.com/radekzm/bestAI
Documentation: https://github.com/radekzm/bestAI/blob/master/modules/01-core.md
