#!/bin/bash
# hooks/wal-logger.sh — PreToolUse hook (Bash|Write|Edit matcher)
# CS Algorithm: Write-Ahead Log (PostgreSQL, SQLite)
# Logs intent BEFORE destructive/modifying actions execute.
# Recovery: After /clear or compaction, SessionStart hook reads WAL.

set -euo pipefail

WAL_DIR="$HOME/.claude/projects/$(echo "${CLAUDE_PROJECT_DIR:-.}" | tr '/' '-')"
WAL_FILE="$WAL_DIR/wal.log"
mkdir -p "$WAL_DIR"

# LSN (Log Sequence Number) — monotonically increasing
LSN_FILE="$WAL_DIR/.wal-lsn"
LSN=$(cat "$LSN_FILE" 2>/dev/null || echo 0)
LSN=$((LSN + 1))
echo "$LSN" > "$LSN_FILE"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

case "$TOOL_NAME" in
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        [ -z "$COMMAND" ] && exit 0

        # Only log potentially destructive commands
        if echo "$COMMAND" | grep -qE '(rm |mv |cp |chmod|chown|deploy|restart|migrate|rsync|docker|git push|git reset|git checkout|kill|drop |truncate )'; then
            CATEGORY="DESTRUCTIVE"
        elif echo "$COMMAND" | grep -qE '(git commit|git merge|git rebase|npm publish|pip install)'; then
            CATEGORY="MODIFY"
        else
            exit 0  # Not worth logging
        fi

        echo "[$TIMESTAMP] [LSN:$LSN] [$CATEGORY] [BASH] $COMMAND" >> "$WAL_FILE"
        ;;
    Write)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [ -z "$FILE_PATH" ] && exit 0
        echo "[$TIMESTAMP] [LSN:$LSN] [WRITE] [FILE] $FILE_PATH" >> "$WAL_FILE"
        ;;
    Edit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [ -z "$FILE_PATH" ] && exit 0
        echo "[$TIMESTAMP] [LSN:$LSN] [EDIT] [FILE] $FILE_PATH" >> "$WAL_FILE"
        ;;
esac

# WAL rotation: keep last 500 entries
if [ -f "$WAL_FILE" ]; then
    LINE_COUNT=$(wc -l < "$WAL_FILE")
    if [ "$LINE_COUNT" -gt 500 ]; then
        tail -300 "$WAL_FILE" > "${WAL_FILE}.tmp"
        mv "${WAL_FILE}.tmp" "$WAL_FILE"
    fi
fi

exit 0
