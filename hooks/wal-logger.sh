#!/bin/bash
# hooks/wal-logger.sh — PreToolUse hook (Bash|Write|Edit matcher)
# CS Algorithm: Write-Ahead Log (PostgreSQL, SQLite)
# Logs intent BEFORE destructive/modifying actions execute.
# Recovery: After /clear or compaction, SessionStart hook reads WAL.
#
# NOTE: This is a logging hook, not enforcement. It always exits 0.
# WAL entries use format: [TIMESTAMP] [LSN:N] [CATEGORY] [TYPE] details

set -euo pipefail

# If jq is missing, skip (logging hook, not enforcement)
if ! command -v jq &>/dev/null; then
    exit 0
fi

WAL_DIR="$HOME/.claude/projects/$(echo "${CLAUDE_PROJECT_DIR:-.}" | tr '/' '-')"
WAL_FILE="$WAL_DIR/wal.log"
mkdir -p "$WAL_DIR"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# LSN increment and WAL write under lock (prevents race conditions)
LSN_FILE="$WAL_DIR/.wal-lsn"

log_entry() {
    local entry="$1"
    (
        flock 200
        local lsn
        lsn=$(cat "$LSN_FILE" 2>/dev/null || echo 0)
        lsn=$((lsn + 1))
        echo "$lsn" > "$LSN_FILE"
        echo "[$TIMESTAMP] [LSN:$lsn] $entry" >> "$WAL_FILE"

        # WAL rotation: trigger at 500 entries, keep last 300 (hysteresis)
        if [ -f "$WAL_FILE" ]; then
            local line_count
            line_count=$(wc -l < "$WAL_FILE")
            if [ "$line_count" -gt 500 ]; then
                tail -300 "$WAL_FILE" > "${WAL_FILE}.tmp"
                mv "${WAL_FILE}.tmp" "$WAL_FILE"
            fi
        fi
    ) 200>"$LSN_FILE.lock"
}

case "$TOOL_NAME" in
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        [ -z "$COMMAND" ] && exit 0

        # Sanitize command for log (replace newlines with \n literal)
        SAFE_CMD=$(echo "$COMMAND" | tr '\n' ' ' | head -c 200)

        # Only log potentially destructive commands
        if echo "$COMMAND" | grep -qE '(rm |mv |cp |chmod|chown|deploy|restart|migrate|rsync|docker|git push|git reset|git checkout|kill |drop |truncate )'; then
            log_entry "[DESTRUCTIVE] [BASH] $SAFE_CMD"
        elif echo "$COMMAND" | grep -qE '(git commit|git merge|git rebase|npm publish|pip install)'; then
            log_entry "[MODIFY] [BASH] $SAFE_CMD"
        fi
        ;;
    Write)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [ -z "$FILE_PATH" ] && exit 0
        log_entry "[WRITE] [FILE] $FILE_PATH"
        ;;
    Edit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [ -z "$FILE_PATH" ] && exit 0
        log_entry "[EDIT] [FILE] $FILE_PATH"
        ;;
esac

exit 0
