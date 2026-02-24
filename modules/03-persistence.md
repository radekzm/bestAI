# Module 03: Persistent Memory — Auto-Persistence & Weight System

> Use this module when you want the agent to remember decisions across sessions,
> distinguish user instructions from auto-discoveries, and never lose critical context.

<!-- agents-md-compat -->

---

## The Problem

After `/new`, `/clear`, or auto-compaction, the agent forgets: decisions, preferences, pitfalls — and repeats the same mistakes.

## Memory Layers (from simplest)

```
L0: Provider prompt caching    — API-level, zero config
L1: Session Memory (built-in)  — automatic summaries, survives /compact
L2: Auto Memory (MEMORY.md)    — persistent files, always loaded
L3: Stop Hook Pipeline         — deterministic save (optional)
```

### L1: Session Memory (zero config)
- Built into Claude Code, works automatically
- Saves every ~5,000 tokens: title, status, decisions
- Survives `/compact`
- Limitation: "reference material", not hard instructions

### L2: Auto Memory (KEY LAYER)

**Structure**:
```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — max 200 lines, ALWAYS loaded
├── decisions.md           # Architectural decisions [USER]/[AUTO]
├── preferences.md         # Workflow preferences
├── pitfalls.md            # Pitfalls and solutions
├── frozen-fragments.md    # Registry of frozen files
└── session-log.md         # Chronological change log
```

**MEMORY.md format**:
```markdown
# Project Memory

## Decisions (details: decisions.md)
- [USER] Stack: Rails 8 + Angular 20, don't change
- [AUTO] Database: PostgreSQL 16 on port 45432

## Preferences (details: preferences.md)
- [USER] Commits: English. Documentation: Polish
- [USER] Tests ALWAYS before commit

## Pitfalls (details: pitfalls.md)
- [AUTO] Port 3000 busy — use 3001

## Frozen (details: frozen-fragments.md)
- FROZEN: config/database.yml — production
```

**Critical CLAUDE.md rule** (most effective single instruction):
```markdown
IMPORTANT: After every significant decision, user preference, or pitfall discovery —
save to the appropriate file in memory/ WITHOUT asking the user. Tag [USER] or [AUTO].
Don't wait for session end. Save AS YOU GO.
```

### L3: Stop Hook Pipeline (advanced)

For projects with many architectural decisions or large teams:

| Plugin | Architecture | Best For |
|--------|-------------|----------|
| [claude-code-auto-memory](https://deepwiki.com/severity1/claude-code-auto-memory) | 3-phase: track → spawn → update | Medium projects |
| [claude-memory](https://github.com/idnotbe/claude-memory) | 4-phase: triage → draft → verify → save | Large projects, teams |

## Weight & Source System

| Tag | Source | Weight | Change Policy |
|-----|--------|--------|---------------|
| `[USER]` | User said explicitly | **High** | ONLY with user permission |
| `[AUTO]` | Agent detected/inferred | **Lower** | Agent may revise if justified |

### Priority Rules

```
RULE #1: [USER] NEVER overridden by [AUTO]
RULE #2: [AUTO] can be updated by agent (log the change)
RULE #3: Conflict → [USER] ALWAYS wins
RULE #4: Changing [USER] → STOP → ask user → log in session-log.md
```

### Escalation Flow

```
Agent wants to change entry
  ├─ Tag = [AUTO]?
  │   └─ YES → Change it. Log in session-log.md
  └─ Tag = [USER]?
      └─ YES → STOP
          ├─ Ask user
          ├─ Explain WHY
          └─ Accepted?
              ├─ YES → Change. Mark [USER-UPDATED]. Log.
              └─ NO → Keep original. Log refusal.
```

## "Tell, Don't Hope" — The Most Important Rule

Don't rely on the agent "figuring out" what to save:

```markdown
IMPORTANT: After every significant decision, user preference, or pitfall discovery —
save to the appropriate file in memory/ WITHOUT asking the user. Tag [USER] or [AUTO].
Don't wait for session end. Save AS YOU GO.
```

This turns auto-memory from **"might save"** to **"always saves"**.

## Common Mistakes

| Mistake | Why Bad | Fix |
|---------|---------|-----|
| MEMORY.md > 200 lines | Rest doesn't load | Move details to topic files |
| No [USER]/[AUTO] tags | Agent changes user decisions | Tagging rule in CLAUDE.md |
| No frozen registry | Agent breaks working files | Create frozen-fragments.md |
| Relying only on L1 | Session Memory = "reference" | Add L2 with MEMORY.md |
| Too much FROZEN | Can't change anything | Freeze ONLY stable, tested fragments |

---

*See [04-enforcement](04-enforcement.md) for hooks enforcing these rules, [06-operational-patterns](06-operational-patterns.md) for REHYDRATE pattern.*
