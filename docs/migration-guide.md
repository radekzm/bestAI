# bestAI Migration & Onboarding Guide

## New Project Setup

```bash
npx bestai setup /path/to/your/project
npx bestai doctor                        # verify installation
npx bestai test                          # run test suite
```

The setup script:
1. Creates `.claude/settings.json` with hook configuration
2. Symlinks hooks from bestAI to your project
3. Creates `CLAUDE.md`, `MEMORY.md`, `frozen-fragments.md` templates
4. Optionally initializes a project blueprint (fullstack or swarm)

## Migrating from Existing CLAUDE.md

If you already have a CLAUDE.md:

**Problem**: Long CLAUDE.md files (>100 lines) cause agents to skip sections. The critical rules buried on line 87 are effectively invisible.

**Solution**:

1. **Keep CLAUDE.md under 100 lines** — project name, stack, test commands, critical rules only
2. **Move detailed rules to hooks** — anything that must be enforced goes in a hook script
3. **Move reference material to modules** — architecture docs, patterns, API details go in separate files loaded on demand

```bash
# Before: 250-line CLAUDE.md with "never edit config.yml" on line 143
# After:
#   CLAUDE.md (80 lines) — project overview + "run tests before committing"
#   memory/frozen-fragments.md — config.yml listed here
#   check-frozen.sh — hook that actually blocks the edit
```

## Migrating from .cursorrules / .windsurfrules

bestAI can export its rules to other tools:

```bash
bash tools/generate-rules.sh /path/to/your/project
```

This creates `.cursorrules`, `.windsurfrules`, and `codex.md` from your CLAUDE.md and hook configuration. The generated files are one-way exports — edit the bestAI source, not the generated files.

## Enabling Deterministic Hooks

1. Define your frozen files in `memory/frozen-fragments.md` (one path per line)
2. Hooks are configured in `.claude/settings.json` — setup script handles this
3. Test enforcement: ask the agent to edit a frozen file → should see `exit 2` block
4. Validate with `npx bestai lint` to check manifest, dependencies, latency budgets

## Upgrading Between Versions

### v5 → v7

```bash
# Re-run setup (preserves your custom files)
npx bestai setup .

# Verify
npx bestai doctor
npx bestai test
```

Key changes:
- `compliance.sh` was **completely broken** in v5 — it read wrong field names and wrong log path. v7 is a complete rewrite. If you had custom scripts reading events, update field `"type"` → `"action"` and path from `.claude/events.jsonl` → `~/.cache/bestai/events.jsonl`.
- `project_hash()` changed from `echo` to `printf '%s'` (different hash output). If you have state files from v5, circuit breaker state will reset (new hash = new state directory). This is harmless.
- Module numbering changed from legacy (00, 04, 05...) to hierarchical (01-A through 03-E). Update any cross-references in your project files.
- `lib-logging.sh` was removed (dead code). If you sourced it, switch to `hook-event.sh`.

### Adding Multi-Vendor Support (Optional)

```bash
npx bestai setup . --blueprint swarm
```

This creates `.bestai/GPS.json` for shared state. The `sync-gps.sh` Stop hook updates GPS at session end. Ensure `sync-gps.sh` is enabled in `.claude/settings.json` (blueprint scaffolding does not force-enable every hook).

**Honest note**: Multi-vendor orchestration is at preview maturity. If you're using a single agent (Claude Code), you get full benefit from hooks without needing GPS or swarm dispatch.

## Validating Your Setup

```bash
# Full diagnostic
npx bestai doctor --strict .

# Expected output:
# [OK] CLAUDE.md found
# [OK] Hooks directory exists
# [OK] check-frozen.sh installed
# [OK] frozen-fragments.md exists
# [OK] jq available
# [OK] Template versions match (v7.0)
```

## Common Migration Issues

| Issue | Fix |
|-------|-----|
| Hooks don't fire | Check `.claude/settings.json` has hooks configured. Re-run `npx bestai setup .` |
| `jq` not found | Install: `apt install jq` / `brew install jq` |
| Frozen file check passes when it shouldn't | Verify file is listed in `frozen-fragments.md` with exact path |
| Old compliance data missing | v7 changed the event log path. Old events at `.claude/events.jsonl` won't be read. Start fresh or move the file to `~/.cache/bestai/events.jsonl`. |
| Tests fail after upgrade | Clear circuit breaker state: `rm -rf ~/.cache/claude-circuit-breaker/` |
| Circuit breaker stuck OPEN | Delete state: `rm -rf ~/.cache/claude-circuit-breaker/<project-hash>/` |
