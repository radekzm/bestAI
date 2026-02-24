#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Requires backup before destructive operations (deploy, restart, migrate).
# Based on Nuconic data: 31/33 deploy sessions without backup (6% compliance).
# Exit 2 = BLOCK
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)

set -euo pipefail

if ! command -v jq &>/dev/null; then
    echo "BLOCKED: jq is not installed. Cannot validate backup status." >&2
    exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || {
    echo "BLOCKED: Failed to parse hook input." >&2
    exit 2
}
[ -z "$COMMAND" ] && exit 0

is_destructive() {
    # Match command tokens, not substrings (e.g. "deployment-notes.txt" is safe).
    echo "$1" | grep -Eqi '(^|[^[:alnum:]_])(restart|migrate|deploy)([^[:alnum:]_]|$)|rsync.*prod|docker.*(push|kill|rm)|systemctl[[:space:]]+(restart|stop)|dropdb|truncate[[:space:]]+'
}

project_hash() {
    local src="$1"
    if command -v md5sum >/dev/null 2>&1; then
        echo "$src" | md5sum | awk '{print substr($1,1,16)}'
    elif command -v md5 >/dev/null 2>&1; then
        echo -n "$src" | md5 -q | cut -c1-16
    elif command -v shasum >/dev/null 2>&1; then
        echo "$src" | shasum -a 256 | awk '{print substr($1,1,16)}'
    else
        # Last-resort portable fallback (still project-specific, never "default")
        echo "$src" | cksum | awk '{print $1}'
    fi
}

if is_destructive "$COMMAND"; then
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    PROJECT_HASH=$(project_hash "$PROJECT_DIR")

    BACKUP_FLAG_DIR="${BACKUP_FLAG_DIR:-/tmp}"
    BACKUP_FLAG="${BACKUP_FLAG_FILE:-$BACKUP_FLAG_DIR/claude-backup-done-${PROJECT_HASH}}"

    FRESH_HOURS=${BACKUP_FRESHNESS_HOURS:-4}
    [[ "$FRESH_HOURS" =~ ^[0-9]+$ ]] || FRESH_HOURS=4
    MAX_AGE=$((FRESH_HOURS * 3600))

    if [ ! -f "$BACKUP_FLAG" ]; then
        echo "BLOCKED: Destructive operation requires backup first." >&2
        echo "" >&2
        echo "Run one of:" >&2
        echo "  pg_dump dbname > backup_\$(date +%Y%m%d).sql" >&2
        echo "  tar czf backup_\$(date +%Y%m%d).tar.gz /path/to/data" >&2
        echo "" >&2
        echo "Then: touch $BACKUP_FLAG" >&2
        echo "After that, the operation will be allowed for this project." >&2
        echo "Note: flag location is configurable with BACKUP_FLAG_DIR/BACKUP_FLAG_FILE." >&2
        exit 2
    fi

    BACKUP_TIME=$(stat -c %Y "$BACKUP_FLAG" 2>/dev/null || stat -f %m "$BACKUP_FLAG" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$((NOW - BACKUP_TIME))

    if [ "$AGE" -gt "$MAX_AGE" ]; then
        echo "BLOCKED: Backup flag is ${AGE}s old (>${MAX_AGE}s). Run a fresh backup." >&2
        echo "Then: touch $BACKUP_FLAG" >&2
        exit 2
    fi
fi

exit 0
