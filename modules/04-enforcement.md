# Module 04: Deterministic Enforcement — Hooks & Frozen Files

> Use this module when you need GUARANTEED rule execution.
> CLAUDE.md is advisory (6% compliance on production). Hooks are deterministic.

<!-- agents-md-compat -->

---

## The Core Insight

**Nuconic production data** (234 sessions, 29 days):
- CLAUDE.md compliance for backup rule: **6%** (31/33 deploy sessions without backup)
- Rails runner multiline error: **150 occurrences** in 40 sessions despite MEMORY.md entry
- Production restarts during work hours: **45%** (63/139)

**Conclusion**: Documentation ≠ enforcement. Critical rules MUST use hooks with `exit 2`.

## Hook Types

| Hook | When | stdout behavior | Use for |
|------|------|----------------|---------|
| `PreToolUse` | Before tool execution | stderr shown, exit 2 = BLOCK | Frozen files, security guards |
| `PostToolUse` | After tool execution | stdout shown | Linting, formatting |
| `UserPromptSubmit` | When user sends prompt | **stdout added to context** | Smart context injection |
| `SessionStart` | On session start | stdout shown | State restoration |
| `Stop` | After agent response | stdout shown | Memory sync, WAL logging (P1) |

## Fragment Freeze — Hook-Enforced Protection

### Frozen Registry (`frozen-fragments.md`)

```markdown
# Frozen Fragments Registry

## FROZEN
<!-- Hook PreToolUse blocks edits to these files. -->
<!-- To unfreeze: say "unfreeze <path>" -->

- `src/auth/login.ts` — auth flow [USER] (frozen: 2026-02-20)
- `config/database.yml` — DB config [USER] production verified (frozen: 2026-02-19)
- `.env.production` — env vars [USER] (frozen: 2026-02-18)
```

### Hook Configuration (`.claude/settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-frozen.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/preprocess-prompt.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Composition Rules

When multiple hooks are attached to the same event:
- Hooks execute in the order defined in `settings.json`
- First `exit 2` blocks the tool call
- Hooks are independent; no hook can override another hook's block
- Place the most restrictive hooks first (`check-frozen`, security guards)

## Known Limitations (and mitigations)

- `PostToolUse` hooks are advisory by default (cannot block the current call)
  Mitigation: pair advisory trackers with strict `PreToolUse` gates (example: `circuit-breaker-gate.sh`)
- Bash command parsing is pattern-based, not a full shell parser
  Mitigation: keep frozen paths explicit and reviewed
- `[USER]` protection is only deterministic if enforced by dedicated hooks/diff checks
  Mitigation: treat `[USER]` rules as critical and add guard hooks in strict deployments

## Example Enforcement Hooks

### Backup Before Destructive Operations

See `hooks/backup-enforcement.sh` for the full implementation. Key design:

```bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Fails CLOSED: blocks when jq missing or input malformed
# Uses project-specific flag (not PID or session ID)
# Checks backup recency (must be within 4 hours)
# See hooks/ directory for complete, tested implementation
```

### Work Hours Protection

```bash
#!/bin/bash
# hooks/work-hours-guard.sh — PreToolUse hook
COMMAND=$(cat | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

if echo "$COMMAND" | grep -qE '(restart|deploy)'; then
  HOUR=$(date +%H)
  if [ "$HOUR" -ge 8 ] && [ "$HOUR" -le 17 ]; then
    echo "BLOCKED: Production restart during work hours (8-17 CET)." >&2
    echo "Use --force flag or wait until after hours." >&2
    exit 2
  fi
fi
exit 0
```

## Documented Failures (GitHub Issues)

| Problem | Severity | Evidence | Mitigation |
|---------|----------|----------|------------|
| CLAUDE.md ignored after compaction | CRITICAL | [GH #19471](https://github.com/anthropics/claude-code/issues/19471) | SessionStart hook to restore rules |
| CLAUDE.md ignored in 50% sessions | HIGH | [GH #17530](https://github.com/anthropics/claude-code/issues/17530) | PreToolUse hooks (exit 2) |
| Security rules ignored (P0) | CRITICAL | [GH #2142](https://github.com/anthropics/claude-code/issues/2142) | PreToolUse hook blocking secret commits |
| Backup compliance 6% | CRITICAL | Nuconic data: 31/33 without backup | Hook on deploy requiring pg_dump |
| No PostCompact hook | STRUCTURAL | [GH #14258](https://github.com/anthropics/claude-code/issues/14258) | PreCompact + session < 500 tools |
| Context rot at ~147k tokens | STRUCTURAL | Quality drops though limit = 200k | `/clear` at 3+ compactions |
| Digital punding after compactions | HIGH | [GH #6549](https://github.com/anthropics/claude-code/issues/6549) | Max 3 compactions → `/clear` |

## Hook Health Monitoring

**WARNING**: Hooks can silently fail. Add monitoring:

```bash
#!/bin/bash
# hooks/health-check.sh — SessionStart hook
# Verify all hooks are functional

HOOKS_DIR="$CLAUDE_PROJECT_DIR/.claude/hooks"
FAILED=0

for hook in "$HOOKS_DIR"/*.sh; do
  [ ! -x "$hook" ] && {
    echo "WARNING: Hook not executable: $(basename $hook)"
    FAILED=$((FAILED + 1))
  }
done

# Check required dependencies
for dep in jq; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "CRITICAL: $dep not installed — enforcement hooks will BLOCK all operations (fail-closed design)"
    FAILED=$((FAILED + 1))
  }
done

# Check optional dependencies
for dep in realpath python3; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "WARNING: $dep not installed — path normalization may be degraded"
    FAILED=$((FAILED + 1))
  }
done

[ "$FAILED" -gt 0 ] && echo "Hook health check: $FAILED issues found"
exit 0
```

## Key Rule

```
CLAUDE.md = guidance (advisory, model may ignore)
Hooks with exit 2 = enforcement (deterministic, cannot be bypassed)

CRITICAL RULES → HOOKS
STYLE/PREFERENCES → CLAUDE.md
```

## Hook Selection Guide

| Need | Hook | Event |
|------|------|-------|
| Protect frozen files (Edit/Write/Bash) | `check-frozen.sh` | PreToolUse |
| Backup before destructive ops | `backup-enforcement.sh` | PreToolUse |
| Smart context injection | `preprocess-prompt.sh` | UserPromptSubmit |
| Session bootstrap | `rehydrate.sh` | SessionStart |
| Session sync + delta | `sync-state.sh` | Stop |
| Anti-loop advisory tracking | `circuit-breaker.sh` | PostToolUse |
| Anti-loop strict blocking | `circuit-breaker-gate.sh` | PreToolUse |

---

*See [05-cs-algorithms](05-cs-algorithms.md) for Circuit Breaker pattern, [03-persistence](03-persistence.md) for memory system.*
