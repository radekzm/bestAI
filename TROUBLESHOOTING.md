# Troubleshooting — Problem → Solution

> Find your problem below. Each links to the specific module and fix.

## Agent Ignores My Rules

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent doesn't follow CLAUDE.md | CLAUDE.md is advisory (6% compliance) | Use hooks with `exit 2` → [01-core](modules/01-core.md) |
| Rules work then stop mid-session | Context compaction drops rules | `/clear` after 3 compactions → [02-operations](modules/02-operations.md) |
| Agent edits files I told it not to | No enforcement on frozen files | Install `check-frozen.sh` hook → [01-core](modules/01-core.md) |
| CLAUDE.md too long, agent skips parts | >100 lines = noise | Trim to <100, use trigger tables → [01-core](modules/01-core.md) |

## Agent Forgets Things

| Symptom | Cause | Fix |
|---------|-------|-----|
| New session = agent forgets everything | No persistent memory | Set up MEMORY.md + [USER]/[AUTO] tags → [01-core](modules/01-core.md) |
| Agent forgets mid-session decisions | Compaction erased them | Save AS YOU GO (don't wait for session end) → [01-core](modules/01-core.md) |
| Agent doesn't know about frozen files | No REHYDRATE on session start | Add SessionStart hook → [02-operations](modules/02-operations.md) |
| Agent re-discovers the same thing every session | Decisions not persisted | Add "Tell don't hope" CLAUDE.md rule → [01-core](modules/01-core.md) |

## Agent Repeats Same Error

| Symptom | Cause | Fix |
|---------|-------|-----|
| Same error 10+ times in a row | No failure escalation | "3 batches → STOP" + strict gate (`circuit-breaker-gate.sh`) → [02-operations](modules/02-operations.md) |
| Agent tries same approach after failure | No backoff/jitter | Exponential Backoff pattern → [03-advanced](modules/03-advanced.md) |
| Agent ignores "digital punding" rule | Advisory only | Pair `circuit-breaker.sh` + `circuit-breaker-gate.sh` for strict mode |

## Session Quality Degrades

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent gets confused after long session | Context rot at ~147k tokens | `/clear` at 3+ compactions → [02-operations](modules/02-operations.md) |
| Agent starts mixing up files/concepts | Overloaded context window | Split into focused sessions → [02-operations](modules/02-operations.md) |
| Agent slower with many MCP servers | Tool definitions eat context (~55k tokens each) | Max 3-4 MCP servers → [01-core](modules/01-core.md) |
| Smart Context injects noisy snippets | No guardrails / oversized budget | Use `preprocess-prompt.sh` defaults + `.claude/DISABLE_SMART_CONTEXT` escape hatch |

## Deployment/Safety Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent deploys without backup | Backup gate missing/disabled | Install `backup-enforcement.sh` and provide backup manifest (path+timestamp+checksum) → [01-core](modules/01-core.md) |
| No audit trail of destructive actions | Nothing logs intent | Install `wal-logger.sh` hook → [03-advanced](modules/03-advanced.md) |
| Agent commits secrets to git | Missing/disabled secret guard | Install/enable `secret-guard.sh` hook → [01-core](modules/01-core.md) |

## Setup Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Hooks don't fire | Not configured in settings.json | Run `bash setup.sh` → auto-generates config |
| Hooks silently fail | Missing `jq` dependency | Run `bash doctor.sh` → checks all deps |
| Frozen file check doesn't work | Hook not executable or `grep -oP` on macOS | Run `bash tests/test-hooks.sh` → finds bugs |

## Quick Commands

```bash
# Diagnose your setup
bash doctor.sh /path/to/your/project

# Install bestAI into your project
bash setup.sh /path/to/your/project

# Test hooks work correctly
bash tests/test-hooks.sh

# Emergency: agent stuck in loop
# Type in Claude Code:
/clear
```
