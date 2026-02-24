#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Requires backup before destructive operations (deploy, restart, migrate).
# Based on Nuconic data: 31/33 deploy sessions without backup (6% compliance).
# Exit 2 = BLOCK

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Check if destructive operation
if echo "$COMMAND" | grep -qE '(restart|migrate|deploy|rsync.*prod|docker.*push)'; then
    # Check if backup was done in this session
    BACKUP_FLAG="/tmp/claude-backup-done-${CLAUDE_SESSION_ID:-manual}"

    if [ ! -f "$BACKUP_FLAG" ]; then
        echo "BLOCKED: Destructive operation requires backup first." >&2
        echo "" >&2
        echo "Run one of:" >&2
        echo "  pg_dump dbname > backup_\$(date +%Y%m%d).sql" >&2
        echo "  tar czf backup_\$(date +%Y%m%d).tar.gz /path/to/data" >&2
        echo "" >&2
        echo "Then: touch $BACKUP_FLAG" >&2
        echo "After that, the operation will be allowed." >&2
        exit 2
    fi
fi

exit 0
