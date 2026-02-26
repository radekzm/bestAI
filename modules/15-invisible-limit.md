# Module 15: Invisible Limit Mechanism

> Use this module to dynamically manage the T3 (Cold) Context Tier,
> allowing agents to "know about" thousands of files without loading them.

<!-- agents-md-compat -->

---

## Overview

The Context OS (Module 10) defines T3 (Cold) as files that are never auto-loaded because they would exceed the context budget. However, if the agent doesn't know they exist, it can't choose to read them.

The **Invisible Limit Mechanism** in v4.0 solves this by creating an automated, hierarchical index of summaries.

## How it Works: Dynamic Summarization

Instead of maintaining a massive `context-index.md` listing every file path, the mechanism groups files and creates dense, semantic summaries.

### 1. The Summarization Cron (or Hook)
A background process (or end-of-session hook) analyzes directories in T3:
- It reads files in a module (e.g., `src/auth/`).
- It generates a 1-2 sentence summary: "Contains OAuth2 login flows, JWT validation middleware, and user session types."
- It writes this to a `.bestai/T3-summary.md` index.

### 2. Injection into T1 (WARM)
The `T3-summary.md` index is extremely compact (e.g., 20 lines for 200 files). This summary is injected into the T1 (WARM) tier at boot.

### 3. Progressive Disclosure
The agent reads the summary in T1: *"Oh, `src/auth/` handles JWT."*
If the user asks about login, the agent knows to use its `read_file` or `grep_search` tools on `src/auth/` to pull those files from T3 into active memory.

## Setup

1. Create a periodic script that generates these directory-level summaries.
2. Ensure `rehydrate.sh` includes the resulting summary file in its boot payload.

**Example `T3-summary.md`:**
```markdown
# Cold Storage Index
- `src/billing/`: Stripe integration, invoice generation, webhooks. (Use `read_file` on `src/billing/README.md` for details)
- `tests/e2e/`: Playwright end-to-end tests for user flows.
- `docs/legacy/`: Old v1 API documentation. Do not use for new code.
```

---

*This mechanism completes the Context OS by providing a map to the entire codebase for negligible token cost.*