#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Requires backup before destructive operations (deploy, restart, migrate).
# Based on Nuconic data: 31/33 deploy sessions without backup (6% compliance).
# Exit 2 = BLOCK
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)

set -euo pipefail

# Fail closed: if jq is missing, block destructive ops
if ! command -v jq &>/dev/null; then
    echo "BLOCKED: jq is not installed. Cannot validate backup status." >&2
    exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>&1) || {
    echo "BLOCKED: Failed to parse hook input." >&2
    exit 2
}
[ -z "$COMMAND" ] && exit 0

# Check if destructive operation
if echo "$COMMAND" | grep -qE '(restart|migrate|deploy|rsync.*prod|docker.*push)'; then
    # Use project dir hash for session-independent, project-specific flag
    PROJECT_HASH=$(echo "${CLAUDE_PROJECT_DIR:-.}" | md5sum 2>/dev/null | cut -c1-16 || echo "default")
    BACKUP_FLAG="/tmp/claude-backup-done-${PROJECT_HASH}"

    if [ ! -f "$BACKUP_FLAG" ]; then
        echo "BLOCKED: Destructive operation requires backup first." >&2
        echo "" >&2
        echo "Run one of:" >&2
        echo "  pg_dump dbname > backup_\$(date +%Y%m%d).sql" >&2
        echo "  tar czf backup_\$(date +%Y%m%d).tar.gz /path/to/data" >&2
        echo "" >&2
        echo "Then: touch $BACKUP_FLAG" >&2
        echo "After that, the operation will be allowed for this project." >&2
        echo "Note: flag resets on reboot." >&2
        exit 2
    fi

    # Check backup recency (must be within last 4 hours)
    if [ -f "$BACKUP_FLAG" ]; then
        BACKUP_TIME=$(stat -c %Y "$BACKUP_FLAG" 2>/dev/null || stat -f %m "$BACKUP_FLAG" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        AGE=$((NOW - BACKUP_TIME))
        if [ "$AGE" -gt 14400 ]; then  # 4 hours
            echo "BLOCKED: Backup flag is ${AGE}s old (>4 hours). Run a fresh backup." >&2
            echo "Then: touch $BACKUP_FLAG" >&2
            exit 2
        fi
    fi
fi

exit 0
