# bestAI Quickstart

AI agents ignore CLAUDE.md rules **94% of the time** in production.
bestAI fixes this with **hook-enforced compliance** — deterministic blocks for matched tool events/patterns.

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

For quick install via npm:
```bash
npx bestai init /path/to/your/project
npx bestai doctor /path/to/your/project
npx bestai stats /path/to/your/project
```

## What You Get

| Hook | What it does |
|------|-------------|
| **check-frozen.sh** | Blocks edits to critical files (Edit, Write, Bash) |
| **backup-enforcement.sh** | Requires backup before deploy/migrate |
| **circuit-breaker.sh** | Advisory anti-loop tracker (strict block via `circuit-breaker-gate.sh`) |
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
| `default` | Most projects | Frozen files, backup, circuit breaker (plus core safety hooks) |
| `aion-runtime` | Long-running sessions | + session state, memory compiler, GPS |
| `smart-v2` | Large codebases | + smart context v2 + runtime fallback chain |

```bash
bash bestAI/setup.sh /path/to/project --profile aion-runtime
```

Notes:
- Profile tables show baseline intent; final installed hooks can differ with installer selections and `--secure-defaults`.
- `smart-v2` uses fallback mode by default. LLM-assisted path requires `SMART_CONTEXT_USE_HAIKU=1` and available `claude` CLI.

## Learn More

- [Module 01: Core](modules/01-core.md) — fundamentals, enforcement, memory, context OS
- [Module 02: Operations](modules/02-operations.md) — sessions, patterns, prompt caching
- [Module 03: Advanced](modules/03-advanced.md) — smart context, algorithms, orchestration
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — When things go wrong
- [Full README](README.md) — hooks, templates, and tooling
