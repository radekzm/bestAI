# Module 01: File Architecture & Progressive Disclosure

> Use this module when setting up context files for your project
> or choosing between CLAUDE.md, Skills, Rules, and Hooks.

<!-- agents-md-compat -->

---

## Context File Map (2026)

| File | Tool | Loading | Purpose |
|------|------|---------|---------|
| `CLAUDE.md` | Claude Code | Always | Project conventions |
| `CLAUDE.local.md` | Claude Code | Always (not in git) | Private settings |
| `~/.claude/CLAUDE.md` | Claude Code | Always (global) | Global preferences |
| `.claude/skills/*.md` | Claude Code | On-demand (LLM decides) | Specialist knowledge |
| `.claude/rules/*.md` | Claude Code | Conditional (glob) | Per-filetype rules |
| `.claude/agents/*.md` | Claude Code | On request | Subagent tasks |
| `AGENTS.md` | OpenAI/Sourcegraph/Amp | Always | Open standard multi-tool |
| `.cursor/rules/*.md` | Cursor | Conditional (path) | IDE rules |
| `.github/copilot-instructions.md` | GitHub Copilot | Always | Copilot instructions |
| `.junie/guidelines.md` | JetBrains Junie | Always | Agent guidelines |
| `llms.txt` | Universal (proposal) | On request | LLM-friendly metadata |

## Hierarchy (cascading)

```
~/.claude/CLAUDE.md       → global (all projects)
./CLAUDE.md               → per project (team-shared)
./src/api/CLAUDE.md       → per module (specific)
CLAUDE.local.md           → private (not in git)
```

Deeper files override conflicts from higher levels. Layers are additive.

## Who Decides What Loads

| Who | Method | Example | Trade-off |
|-----|--------|---------|-----------|
| **LLM** | Autonomous | Skills | Non-deterministic but automatic |
| **Human** | Manual | Slash commands | Full control, less automation |
| **Software** | Deterministic | Hooks | Predictable, task-specific |

## CLAUDE.md — Golden Rules

| Rule | Details |
|------|---------|
| **Max 100 lines** | Longer → Claude ignores rules (lost in noise) |
| **Trigger tables** | Tables instead of narratives = **70% reduction** |
| **Lazy loading** | CLAUDE.md = minimal triggers; details via Skills |
| **Test each line** | "Will removing this line cause errors?" → if not, cut |
| **Emphasis** | `IMPORTANT`, `MUST`, **bold** → increases adherence |

### Always Include
- Bash commands Claude can't guess
- Code style rules DIFFERENT from defaults
- Testing instructions and preferred runners
- Repo etiquette (branch names, PR conventions)
- Project-specific architectural decisions
- Dev environment quirks (env vars, ports)

### Never Include
- Things Claude infers from code
- Standard language conventions
- Detailed API docs (link instead)
- Frequently changing information
- File-by-file descriptions

## Progressive Disclosure Comparison

| Feature | CLAUDE.md | Skills | Rules | Hooks | Subagents |
|---------|-----------|--------|-------|-------|-----------|
| Loading | Always | On-demand | Conditional | Deterministic | On request |
| Execution guarantee | No (guidance) | No | No | **Yes** | No |
| Context cost | Fixed | Only when active | Conditional | Minimal | Separate window |
| Team editable | Yes (git) | Yes (git) | Yes (git) | Yes | Yes |

## AGENTS.md — Open Standard

Adopted by OpenAI Codex CLI, Sourcegraph Amp, and others.

- Files collected from current directory upward (to `$HOME`)
- `$HOME/.config/AGENTS.md` always included
- Deeper files have priority at conflicts
- Community best practice: **start with COMMANDS, not explanations**

```yaml
# Sourcegraph Amp — conditional scoping
---
globs: ['**/*.ts', '**/*.tsx']
---
# TypeScript Conventions
```

OpenAI Codex CLI: project docs limited to **32 KiB** (`project_doc_max_bytes`).

## CLI vs MCP — Token Efficiency

| Method | Context free for reasoning | Notes |
|--------|---------------------------|-------|
| **CLI tools** (`gh`, `aws`, `kubectl`) | **~95%** | Single pipeline shot |
| **MCP server** (e.g. GitHub, 93 tools) | **~45%** | ~55k tokens on tool definitions |

**Recommendation**: Max 3-4 active MCP servers. Prefer CLI for everything else.

---

*See [02-session-management](02-session-management.md) for session workflow, [04-enforcement](04-enforcement.md) for hooks.*
