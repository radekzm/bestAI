# Module 12: Global Project State (GPS)

> Use this module to coordinate multiple AI agents working on the same project,
> ensuring they share a single source of truth and don't overwrite each other's progress.

<!-- agents-md-compat -->

---

## Overview

In bestAI v4.0, the **Global Project State (GPS)** serves as the central brain for multi-agent collaboration. It solves the "context paralysis" and "goal amnesia" problems that occur when multiple agents (or even a single agent over a long period) work on a complex project.

The GPS is stored in a structured JSON file, typically `.bestai/GPS.json`.

## Core Components of GPS

A standard GPS file contains:
1. **Main Objective:** The overarching goal of the project.
2. **Milestones:** High-level phases (e.g., "Database Schema", "Auth System").
3. **Active Tasks:** What each specific agent or sub-agent is currently working on.
4. **Blockers:** System-wide issues preventing progress.
5. **Shared Context:** Key architectural decisions that all agents must respect.

## Synchronization Hook (`sync-gps.sh`)

To keep the GPS up-to-date, bestAI uses a PostToolUse or Stop hook (`hooks/sync-gps.sh`).

**How it works:**
1. After significant actions (or at the end of a session), the agent is required to summarize its progress.
2. The `sync-gps.sh` Stop hook parses session output, changed files, and blocker signals, then performs an atomic `GPS.json` update.
3. When a new agent (or the next session) starts, the `rehydrate.sh` hook (from Module 10) loads the `GPS.json` into the T0 (HOT) context tier.

Current schema requires:
- `project.owner`
- `project.target_date`
- `project.success_metric`
- `project.status_updated_at`

## Example GPS File

```json
{
  "project": {
    "name": "E-commerce API",
    "main_objective": "Build a scalable backend for a retail platform."
  },
  "milestones": [
    {
      "id": "m1",
      "name": "Database Schema",
      "status": "completed"
    },
    {
      "id": "m2",
      "name": "Authentication",
      "status": "in_progress"
    }
  ],
  "active_tasks": [
    {
      "agent_id": "Agent-Backend",
      "task": "Implementing JWT validation middleware",
      "status": "working"
    }
  ],
  "blockers": [
    "Awaiting confirmation on the OAuth provider credentials."
  ],
  "shared_context": {
    "architecture_decisions": [
      "Use PostgreSQL with async psycopg3.",
      "All dates must be UTC."
    ]
  }
}
```

## Setup

1. Copy the template: `mkdir -p .bestai && cp templates/gps-template.json .bestai/GPS.json`
2. Enable the hook: Ensure `hooks/sync-gps.sh` is executable and referenced in your `.claude/settings.json` or equivalent agent config.

---

*This is a core component of the v4.0 Distributed Agent Orchestration architecture.*
