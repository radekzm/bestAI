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
| `Stop` | After agent response | stdout shown | Memory sync, WAL |

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
        "matcher": "Edit|Write",
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

## Example Enforcement Hooks

### Backup Before Destructive Operations

```bash
#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook
# Requires backup before deploy/restart/migrate

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# Check if destructive operation
if echo "$COMMAND" | grep -qE '(restart|migrate|deploy|rsync.*prod)'; then
  # Check if backup was done in this session
  BACKUP_FLAG="/tmp/claude-backup-done-$$"
  if [ ! -f "$BACKUP_FLAG" ]; then
    echo "BLOCKED: Run backup first (pg_dump). Then retry." >&2
    echo "After backup, the operation will be allowed." >&2
    exit 2
  fi
fi
exit 0
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

# Check jq availability (required by most hooks)
command -v jq >/dev/null 2>&1 || {
  echo "WARNING: jq not installed — hooks may fail silently"
  FAILED=$((FAILED + 1))
}

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

---

*See [05-cs-algorithms](05-cs-algorithms.md) for Circuit Breaker pattern, [03-persistence](03-persistence.md) for memory system.*
