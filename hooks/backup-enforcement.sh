#!/bin/bash
# hooks/backup-enforcement.sh — PreToolUse hook (Bash matcher)
# Requires backup before destructive operations (deploy, restart, migrate).
# Based on Nuconic data: 31/33 deploy sessions without backup (6% compliance).
# Exit 2 = BLOCK
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)
# Validation is manifest-based (path + timestamp + optional checksum), not touch-flag.
# Optional self-heal mode (BESTAI_SELF_HEAL=1): try_fix -> verify -> allow, else block.

set -euo pipefail

# Load shared libraries (event logging must come before block_or_dryrun)
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=hook-event.sh
source "$HOOKS_DIR/hook-event.sh" 2>/dev/null || true
source "$HOOKS_DIR/lib-dryrun.sh" 2>/dev/null || {
    block_or_log() { echo "[bestAI] BLOCKED: $1" >&2; exit 2; }
}

block_or_dryrun() {
    local message="$*"
    local detail
    if command -v jq >/dev/null 2>&1; then
        detail=$(jq -cn --arg reason "$message" '{reason:$reason}' 2>/dev/null || echo "{\"reason\":\"$message\"}")
    else
        detail="{\"reason\":\"$message\"}"
    fi
    emit_event "backup-enforcement" "BLOCK" "$detail" 2>/dev/null || true
    block_or_log "$message"
}

emit_self_heal_event() {
    local step="$1"
    local code="${2:-}"
    local reason="${3:-}"
    local detail
    detail=$(jq -cn \
        --arg step "$step" \
        --arg code "$code" \
        --arg reason "$reason" \
        '{step:$step,code:$code,reason:$reason}' 2>/dev/null || echo '{}')
    emit_event "backup-enforcement" "TRY_FIX" "$detail" 2>/dev/null || true
}

emit_allow_event() {
    local healed="${1:-false}"
    local detail
    detail=$(jq -cn \
        --arg command "destructive-passed" \
        --argjson self_healed "$healed" \
        '{command:$command,self_healed:$self_healed}' 2>/dev/null || echo '{"command":"destructive-passed"}')
    emit_event "backup-enforcement" "ALLOW" "$detail" 2>/dev/null || true
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

file_mtime_epoch() {
    local file="$1"
    stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || date +%s
}

print_manifest_help() {
    local manifest_path="$1"
    local manifest_dir="$2"
    echo "BLOCKED: Destructive operation requires backup first." >&2
    echo "" >&2
    echo "Run one of:" >&2
    echo "  pg_dump dbname > backup_\$(date +%Y%m%d).sql" >&2
    echo "  tar czf backup_\$(date +%Y%m%d).tar.gz /path/to/data" >&2
    echo "" >&2
    echo "Then create manifest JSON: $manifest_path" >&2
    echo '{' >&2
    echo '  "backup_path": "/absolute/path/to/backup.sql",' >&2
    echo '  "created_at_unix": 1730000000,' >&2
    echo '  "sha256": "optional-but-recommended",' >&2
    echo '  "size_bytes": 12345' >&2
    echo '}' >&2
    echo "" >&2
    echo "[AUTO-FIX] Manual dev mock (explicit, non-production):" >&2
    echo "mkdir -p $manifest_dir && echo '{\"backup_path\":\"/dev/null\",\"created_at_unix\":'\$(date +%s)',\"sha256\":\"mock\",\"size_bytes\":0}' > $manifest_path" >&2
    echo "" >&2
    echo "[SELF-HEAL] Opt-in auto-repair mode:" >&2
    echo "BESTAI_SELF_HEAL=1 BESTAI_SELF_HEAL_BACKUP_PATH=/absolute/path/to/real.backup <command>" >&2
}

set_validation_failure() {
    VALIDATION_CODE="$1"
    VALIDATION_REASON="$2"
    return 1
}

read_manifest_fields() {
    BACKUP_PATH=$(jq -r '.backup_path // empty' "$BACKUP_MANIFEST_FILE")
    CREATED_AT_UNIX=$(jq -r '.created_at_unix // empty' "$BACKUP_MANIFEST_FILE")
    EXPECTED_SHA=$(jq -r '.sha256 // empty' "$BACKUP_MANIFEST_FILE")
    SIZE_BYTES=$(jq -r '.size_bytes // empty' "$BACKUP_MANIFEST_FILE")
}

validate_backup_state() {
    if [ ! -f "$BACKUP_MANIFEST_FILE" ]; then
        set_validation_failure "manifest_missing" "Destructive operation requires backup first."
        return 1
    fi

    if ! jq empty "$BACKUP_MANIFEST_FILE" >/dev/null 2>&1; then
        set_validation_failure "manifest_invalid_json" "Backup manifest is invalid JSON: $BACKUP_MANIFEST_FILE"
        return 1
    fi

    read_manifest_fields

    if [ -z "$BACKUP_PATH" ]; then
        set_validation_failure "manifest_missing_backup_path" "Backup manifest missing backup_path."
        return 1
    fi

    if [ ! -f "$BACKUP_PATH" ]; then
        set_validation_failure "backup_file_missing" "Backup file does not exist: $BACKUP_PATH"
        return 1
    fi

    if [ -n "$SIZE_BYTES" ]; then
        if [[ "$SIZE_BYTES" =~ ^[0-9]+$ ]]; then
            ACTUAL_SIZE=$(wc -c < "$BACKUP_PATH" | tr -d ' ')
            if [ "$ACTUAL_SIZE" -ne "$SIZE_BYTES" ]; then
                set_validation_failure "backup_size_mismatch" "Backup size mismatch (manifest=$SIZE_BYTES, actual=$ACTUAL_SIZE)."
                return 1
            fi
        else
            set_validation_failure "manifest_size_invalid" "Backup manifest size_bytes must be numeric."
            return 1
        fi
    fi

    if [[ "$CREATED_AT_UNIX" =~ ^[0-9]+$ ]]; then
        BACKUP_TIME="$CREATED_AT_UNIX"
    else
        BACKUP_TIME=$(file_mtime_epoch "$BACKUP_PATH")
    fi

    NOW=$(date +%s)
    AGE=$((NOW - BACKUP_TIME))
    if [ "$AGE" -gt "$MAX_AGE" ]; then
        set_validation_failure "backup_stale" "Backup is ${AGE}s old (>${MAX_AGE}s). Run a fresh backup."
        return 1
    fi

    if [ "$REQUIRE_CHECKSUM" = "1" ]; then
        if [ -z "$EXPECTED_SHA" ]; then
            set_validation_failure "checksum_missing" "Backup manifest missing sha256 while checksum required."
            return 1
        fi
        ACTUAL_SHA=$(file_sha256 "$BACKUP_PATH")
        if [ -z "$ACTUAL_SHA" ]; then
            set_validation_failure "checksum_unavailable" "Cannot compute sha256 (install sha256sum or shasum)."
            return 1
        fi
        if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
            set_validation_failure "checksum_mismatch" "Backup checksum mismatch (manifest vs actual)."
            return 1
        fi
    fi

    return 0
}

resolve_self_heal_backup_path() {
    local candidate=""

    if [ -n "${BESTAI_SELF_HEAL_BACKUP_PATH:-}" ]; then
        candidate="$BESTAI_SELF_HEAL_BACKUP_PATH"
    elif [ -f "$BACKUP_MANIFEST_FILE" ] && jq empty "$BACKUP_MANIFEST_FILE" >/dev/null 2>&1; then
        candidate=$(jq -r '.backup_path // empty' "$BACKUP_MANIFEST_FILE")
    fi

    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        echo "$candidate"
        return 0
    fi

    return 1
}

write_manifest_from_backup() {
    local backup_path="$1"
    local created_at_unix="$2"
    local sha256="$3"
    local size_bytes="$4"
    local tmp_manifest

    mkdir -p "$BACKUP_MANIFEST_DIR"
    tmp_manifest=$(mktemp "$BACKUP_MANIFEST_DIR/backup-manifest.tmp.XXXXXX")

    jq -n \
        --arg backup_path "$backup_path" \
        --argjson created_at_unix "$created_at_unix" \
        --arg sha256 "$sha256" \
        --argjson size_bytes "$size_bytes" \
        '{
          backup_path:$backup_path,
          created_at_unix:$created_at_unix,
          sha256:$sha256,
          size_bytes:$size_bytes
        }' > "$tmp_manifest"

    mv "$tmp_manifest" "$BACKUP_MANIFEST_FILE"
}

try_self_heal_manifest() {
    local candidate_path backup_time backup_size backup_sha

    if ! candidate_path=$(resolve_self_heal_backup_path); then
        return 1
    fi

    backup_time=$(file_mtime_epoch "$candidate_path")
    if ! [[ "$backup_time" =~ ^[0-9]+$ ]]; then
        backup_time=$(date +%s)
    fi
    backup_size=$(wc -c < "$candidate_path" | tr -d ' ')
    backup_sha=$(file_sha256 "$candidate_path")

    if [ "$REQUIRE_CHECKSUM" = "1" ] && [ -z "$backup_sha" ]; then
        return 1
    fi

    write_manifest_from_backup "$candidate_path" "$backup_time" "$backup_sha" "$backup_size"
}

if is_destructive "$COMMAND"; then
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    PROJECT_HASH=$(_bestai_project_hash "$PROJECT_DIR")

    BACKUP_MANIFEST_DIR="${BACKUP_MANIFEST_DIR:-/tmp}"
    BACKUP_MANIFEST_FILE="${BACKUP_MANIFEST_FILE:-$BACKUP_MANIFEST_DIR/claude-backup-manifest-${PROJECT_HASH}.json}"
    REQUIRE_CHECKSUM="${BACKUP_REQUIRE_CHECKSUM:-1}"
    SELF_HEAL_MODE="${BESTAI_SELF_HEAL:-0}"

    FRESH_HOURS=${BACKUP_FRESHNESS_HOURS:-4}
    [[ "$FRESH_HOURS" =~ ^[0-9]+$ ]] || FRESH_HOURS=4
    MAX_AGE=$((FRESH_HOURS * 3600))

    VALIDATION_CODE=""
    VALIDATION_REASON=""
    BACKUP_PATH=""
    CREATED_AT_UNIX=""
    EXPECTED_SHA=""
    SIZE_BYTES=""
    ACTUAL_SIZE=""
    ACTUAL_SHA=""
    BACKUP_TIME=0
    NOW=0
    AGE=0

    if ! validate_backup_state; then
        ORIGINAL_CODE="$VALIDATION_CODE"
        ORIGINAL_REASON="$VALIDATION_REASON"

        if [ "$SELF_HEAL_MODE" = "1" ]; then
            echo "[bestAI] SELF-HEAL: attempting manifest repair ($ORIGINAL_CODE)." >&2
            emit_self_heal_event "start" "$ORIGINAL_CODE" "$ORIGINAL_REASON"

            if try_self_heal_manifest; then
                emit_self_heal_event "manifest_rewritten" "$ORIGINAL_CODE" "manifest_updated_from_backup"

                if validate_backup_state; then
                    echo "[bestAI] SELF-HEAL: verify passed, allowing destructive command." >&2
                    emit_allow_event true
                    exit 0
                fi
            fi

            emit_self_heal_event "verify_failed" "$VALIDATION_CODE" "$VALIDATION_REASON"
            echo "[bestAI] SELF-HEAL: verify failed ($VALIDATION_CODE)." >&2
        fi

        case "$ORIGINAL_CODE" in
            manifest_missing)
                print_manifest_help "$BACKUP_MANIFEST_FILE" "$BACKUP_MANIFEST_DIR"
                ;;
            manifest_invalid_json)
                echo "BLOCKED: Backup manifest is invalid JSON: $BACKUP_MANIFEST_FILE" >&2
                ;;
            *)
                echo "BLOCKED: $VALIDATION_REASON" >&2
                ;;
        esac

        if [ "$SELF_HEAL_MODE" = "1" ]; then
            block_or_dryrun "$VALIDATION_REASON"
        else
            block_or_dryrun "$ORIGINAL_REASON"
        fi
    fi

    emit_allow_event false
fi

exit 0
