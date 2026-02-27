# bestAI Quickstart

AI agents ignore CLAUDE.md rules **94% of the time** in production.
bestAI fixes this with **hook-enforced compliance** — deterministic rules that can't be bypassed.

## 2-Minute Setup

```bash
git clone https://github.com/radekzm/bestAI.git
bash bestAI/setup.sh /path/to/your/project
```

Setup is interactive — it asks which hooks and templates to install (~5 min).

For CI/automation:
```bash
bash bestAI/setup.sh /path/to/your/project --non-interactive --secure-defaults
```

## What You Get

| Hook | What it does |
|------|-------------|
| **check-frozen.sh** | Blocks edits to critical files (Edit, Write, Bash) |
| **backup-enforcement.sh** | Requires backup before deploy/migrate |
| **circuit-breaker.sh** | Stops agent after 3 repeated failures |
| **preprocess-prompt.sh** | Injects relevant memory context per prompt |

Plus: CLAUDE.md template, AGENTS.md for cross-tool compatibility, and `doctor.sh` diagnostics.

## Verify Installation

```bash
bash bestAI/doctor.sh /path/to/your/project
```

## How It Works

```
CLAUDE.md = guidance   (advisory — agent may ignore)
Hooks     = enforcement (deterministic — exit 2 blocks the action)
```

Critical rules go in hooks. Style preferences stay in CLAUDE.md.

## Profiles

| Profile | Use case | Hooks installed |
|---------|----------|-----------------|
| `default` | Most projects | Frozen files, backup, circuit breaker |
| `aion-runtime` | Long-running sessions | + session state, memory compiler |
| `smart-v2` | Large codebases | + Haiku-powered semantic context |

```bash
bash bestAI/setup.sh /path/to/project --profile aion-runtime
```

## Learn More

- [Module 00: Fundamentals](modules/00-fundamentals.md) — Why context engineering matters
- [Module 04: Enforcement](modules/04-enforcement.md) — How hooks work
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — When things go wrong
- [Full README](README.md) — All 16 modules, templates, and tooling
