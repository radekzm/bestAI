# Module 13: Agent Orchestration (Team Lead)

> Use this module for complex multi-agent setups where different agents take on specific roles
> such as Developer, Reviewer, and Tester, working in parallel.

<!-- agents-md-compat -->

---

## Overview

As projects scale, a single agent attempting to handle all aspects (frontend, backend, database, testing, devops) leads to context saturation and errors. The **Automated Agent Orchestrator** in bestAI v4.0 solves this through specialized roles.

## Core Concepts

### 1. Parallel Spawning

Instead of linear, step-by-step processing, a master agent (or human user via CLI) can spawn multiple sub-agents in parallel Git worktrees.
- **Git Worktrees:** Allows multiple branches to be checked out simultaneously in different directories.
- **Roles:** For example, Agent A works on `feature-api` in `/worktrees/api`, while Agent B works on `feature-ui` in `/worktrees/ui`.
- **GPS Integration:** The Global Project State (`.bestai/GPS.json`, see Module 12) coordinates these parallel efforts.

### 2. Cross-Agent Review (Devil’s Advocate)

A critical component of reducing bugs is automated peer review.
- Before code is merged, a specialized "Devil's Advocate" agent is invoked.
- This agent's prompt explicitly instructs it to search for security vulnerabilities, edge cases, performance bottlenecks, and style guide violations, *ignoring* the implementation struggle of the primary agent.
- The Reviewer provides feedback in a structured `REVIEW.md` file, which the Developer agent must address before proceeding.

## Implementation Example

```bash
#!/bin/bash
# hooks/parallel-spawn.sh — Example Custom Tool

# Spawns a new Claude session for a specific role
ROLE=$1
TASK_DESC=$2
WORKTREE_DIR=".worktrees/$ROLE"

git worktree add -b "task-$ROLE" "$WORKTREE_DIR" main
echo "Starting agent in $WORKTREE_DIR with role: $ROLE"

# In a real environment, you'd launch the specific agent config here
cd "$WORKTREE_DIR" && claude -p "ROLE: $ROLE. Task: $TASK_DESC. Use GPS.json for context."
```

## Setup

1. Configure your repository to use Git worktrees if you plan to use parallel agents.
2. Define distinct `CLAUDE.md` or `instructions.md` profiles for different roles (e.g., `CLAUDE_REVIEWER.md`, `CLAUDE_DEVELOPER.md`).

---

*This module builds upon the Experimental Agent Teams introduced in Module 08.*