#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Requires backup before destructive operations (deploy, restart, migrate).
# Based on Nuconic data: 31/33 deploy sessions without backup (6% compliance).
# Exit 2 = BLOCK
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)
# Validation is manifest-based (path + timestamp + optional checksum), not touch-flag.

set -euo pipefail

# Load shared libraries (event logging must come before block_or_dryrun)
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=hook-event.sh
source "$HOOKS_DIR/hook-event.sh" 2>/dev/null || true
source "$HOOKS_DIR/lib-dryrun.sh" 2>/dev/null || {
    block_or_log() { echo "[bestAI] BLOCKED: $1" >&2; exit 2; }
}

block_or_dryrun() {
    emit_event "backup-enforcement" "BLOCK" "{\"reason\":\"$*\"}" 2>/dev/null || true
    block_or_log "$*"
}

if ! command -v jq &>/dev/null; then
    block_or_dryrun "jq is not installed. Cannot validate backup status."
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || {
    block_or_dryrun "Failed to parse hook input."
}
[ -z "$COMMAND" ] && exit 0

_BESTAI_TOOL_NAME="Bash"

is_destructive() {
    # Match command tokens, not substrings (e.g. "deployment-notes.txt" is safe).
    echo "$1" | grep -Eqi '(^|[^[:alnum:]_])(restart|migrate|deploy)([^[:alnum:]_]|$)|rsync.*prod|docker.*(push|kill|rm)|systemctl[[:space:]]+(restart|stop)|dropdb|truncate[[:space:]]+'
}

# project_hash delegated to _bestai_project_hash from hook-event.sh (sourced above)

file_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        echo ""
    fi
}

if is_destructive "$COMMAND"; then
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    PROJECT_HASH=$(_bestai_project_hash "$PROJECT_DIR")

    BACKUP_MANIFEST_DIR="${BACKUP_MANIFEST_DIR:-/tmp}"
    BACKUP_MANIFEST_FILE="${BACKUP_MANIFEST_FILE:-$BACKUP_MANIFEST_DIR/claude-backup-manifest-${PROJECT_HASH}.json}"
    REQUIRE_CHECKSUM="${BACKUP_REQUIRE_CHECKSUM:-1}"

    FRESH_HOURS=${BACKUP_FRESHNESS_HOURS:-4}
    [[ "$FRESH_HOURS" =~ ^[0-9]+$ ]] || FRESH_HOURS=4
    MAX_AGE=$((FRESH_HOURS * 3600))

    if [ ! -f "$BACKUP_MANIFEST_FILE" ]; then
        echo "BLOCKED: Destructive operation requires backup first." >&2
        echo "" >&2
        echo "Run one of:" >&2
        echo "  pg_dump dbname > backup_\$(date +%Y%m%d).sql" >&2
        echo "  tar czf backup_\$(date +%Y%m%d).tar.gz /path/to/data" >&2
        echo "" >&2
        echo "Then create manifest JSON: $BACKUP_MANIFEST_FILE" >&2
        echo '{' >&2
        echo '  "backup_path": "/absolute/path/to/backup.sql",' >&2
        echo '  "created_at_unix": 1730000000,' >&2
        echo '  "sha256": "optional-but-recommended",' >&2
        echo '  "size_bytes": 12345' >&2
        echo '}' >&2
        echo "" >&2
        echo "[AUTO-FIX] If you are in a dev environment and want to bypass this securely, run:" >&2
        echo "mkdir -p $BACKUP_MANIFEST_DIR && echo '{\"backup_path\":\"/dev/null\",\"created_at_unix\":'\$(date +%s)',\"sha256\":\"mock\",\"size_bytes\":0}' > $BACKUP_MANIFEST_FILE" >&2
        block_or_dryrun "Destructive operation requires backup first."
    fi

    if ! jq empty "$BACKUP_MANIFEST_FILE" >/dev/null 2>&1; then
        echo "BLOCKED: Backup manifest is invalid JSON: $BACKUP_MANIFEST_FILE" >&2
        block_or_dryrun "Backup manifest is invalid JSON: $BACKUP_MANIFEST_FILE"
    fi

    BACKUP_PATH=$(jq -r '.backup_path // empty' "$BACKUP_MANIFEST_FILE")
    CREATED_AT_UNIX=$(jq -r '.created_at_unix // empty' "$BACKUP_MANIFEST_FILE")
    EXPECTED_SHA=$(jq -r '.sha256 // empty' "$BACKUP_MANIFEST_FILE")
    SIZE_BYTES=$(jq -r '.size_bytes // empty' "$BACKUP_MANIFEST_FILE")

    if [ -z "$BACKUP_PATH" ]; then
        echo "BLOCKED: Backup manifest missing backup_path." >&2
        block_or_dryrun "Backup manifest missing backup_path."
    fi

    if [ ! -f "$BACKUP_PATH" ]; then
        echo "BLOCKED: Backup file from manifest does not exist: $BACKUP_PATH" >&2
        block_or_dryrun "Backup file does not exist: $BACKUP_PATH"
    fi

    if [ -n "$SIZE_BYTES" ] && [[ "$SIZE_BYTES" =~ ^[0-9]+$ ]]; then
        ACTUAL_SIZE=$(wc -c < "$BACKUP_PATH" | tr -d ' ')
        if [ "$ACTUAL_SIZE" -ne "$SIZE_BYTES" ]; then
            echo "BLOCKED: Backup size mismatch (manifest=$SIZE_BYTES, actual=$ACTUAL_SIZE)." >&2
            block_or_dryrun "Backup size mismatch (manifest=$SIZE_BYTES, actual=$ACTUAL_SIZE)."
        fi
    fi

    BACKUP_TIME=0
    if [[ "$CREATED_AT_UNIX" =~ ^[0-9]+$ ]]; then
        BACKUP_TIME="$CREATED_AT_UNIX"
    else
        BACKUP_TIME=$(stat -c %Y "$BACKUP_PATH" 2>/dev/null || stat -f %m "$BACKUP_PATH" 2>/dev/null || echo 0)
    fi

    NOW=$(date +%s)
    AGE=$((NOW - BACKUP_TIME))

    if [ "$AGE" -gt "$MAX_AGE" ]; then
        echo "BLOCKED: Backup is ${AGE}s old (>${MAX_AGE}s). Run a fresh backup." >&2
        echo "Update manifest: $BACKUP_MANIFEST_FILE" >&2
        block_or_dryrun "Backup is ${AGE}s old (>${MAX_AGE}s). Run a fresh backup."
    fi

    if [ "$REQUIRE_CHECKSUM" = "1" ]; then
        if [ -z "$EXPECTED_SHA" ]; then
            echo "BLOCKED: Backup manifest missing sha256 while BACKUP_REQUIRE_CHECKSUM=1." >&2
            block_or_dryrun "Backup manifest missing sha256 while checksum required."
        fi
        ACTUAL_SHA=$(file_sha256 "$BACKUP_PATH")
        if [ -z "$ACTUAL_SHA" ]; then
            echo "BLOCKED: Cannot compute sha256 (install sha256sum or shasum)." >&2
            block_or_dryrun "Cannot compute sha256 (install sha256sum or shasum)."
        fi
        if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
            echo "BLOCKED: Backup checksum mismatch (manifest vs actual)." >&2
            block_or_dryrun "Backup checksum mismatch (manifest vs actual)."
        fi
    fi
    emit_event "backup-enforcement" "ALLOW" "{\"command\":\"destructive-passed\"}" 2>/dev/null || true
fi

exit 0
