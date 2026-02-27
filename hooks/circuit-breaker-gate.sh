#!/bin/bash
# hooks/circuit-breaker-gate.sh — PreToolUse hook (Bash matcher)
# Deterministically blocks when circuit-breaker state is OPEN and cooldown not elapsed.

set -euo pipefail

STRICT="${CIRCUIT_BREAKER_STRICT:-1}"
[ "$STRICT" = "1" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BASE_STATE_DIR="${XDG_RUNTIME_DIR:-${HOME}/.cache}/claude-circuit-breaker"
COOLDOWN="${CIRCUIT_BREAKER_COOLDOWN_SECS:-${CIRCUIT_BREAKER_COOLDOWN:-300}}"

# shellcheck source=hook-event.sh
source "$(dirname "$0")/hook-event.sh" 2>/dev/null || true

project_hash() {
    if command -v _bestai_project_hash >/dev/null 2>&1; then
        _bestai_project_hash "$PROJECT_DIR"
    else
        echo "$PROJECT_DIR" | tr '/' '-'
    fi
}

PROJECT_HASH="$(project_hash)"
STATE_DIR="$BASE_STATE_DIR/$PROJECT_HASH"
NOW="$(date +%s)"

is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

check_line_state_files() {
    [ -d "$STATE_DIR" ] || return 1

    local blocked=0
    local state_file state count last_fail elapsed remaining
    for state_file in "$STATE_DIR"/*; do
        [ -f "$state_file" ] || continue
        case "$state_file" in
            *.lock) continue ;;
        esac

        state="$(sed -n '1p' "$state_file" 2>/dev/null || echo "CLOSED")"
        count="$(sed -n '2p' "$state_file" 2>/dev/null || echo "0")"
        last_fail="$(sed -n '3p' "$state_file" 2>/dev/null || echo "0")"
        is_numeric "$count" || count=0
        is_numeric "$last_fail" || last_fail=0

        [ "$state" = "OPEN" ] || continue

        elapsed=$((NOW - last_fail))
        if [ "$elapsed" -ge "$COOLDOWN" ]; then
            printf "HALF-OPEN\n%s\n%s\n" "$count" "$NOW" > "$state_file"
            emit_event "circuit-breaker-gate" "HALF_OPEN" "{\"count\":$count}" 2>/dev/null || true
            continue
        fi

        remaining=$((COOLDOWN - elapsed))
        echo "BLOCKED: Circuit Breaker is OPEN ($count failures, ${remaining}s cooldown left)." >&2
        echo "Root Cause Table must be updated or strategy changed before proceeding." >&2
        emit_event "circuit-breaker-gate" "BLOCK" "{\"count\":$count,\"remaining\":$remaining}" 2>/dev/null || true
        blocked=1
        break
    done

    [ "$blocked" -eq 0 ]
}

check_legacy_json_state_file() {
    local legacy_file
    legacy_file="$PROJECT_DIR/.claude/circuit-breaker-state.json"
    [ -f "$legacy_file" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local state fail_count
    state="$(jq -r '.state // "CLOSED"' "$legacy_file" 2>/dev/null || echo "CLOSED")"
    fail_count="$(jq -r '.consecutive_failures // 0' "$legacy_file" 2>/dev/null || echo "0")"
    is_numeric "$fail_count" || fail_count=0

    if [ "$state" = "OPEN" ]; then
        echo "BLOCKED: Legacy Circuit Breaker state OPEN ($fail_count failures)." >&2
        echo "Update project state or clear breaker before proceeding." >&2
        emit_event "circuit-breaker-gate" "BLOCK" "{\"legacy\":true,\"count\":$fail_count}" 2>/dev/null || true
        return 1
    fi
    return 0
}

if ! check_line_state_files; then
    exit 2
fi

if ! check_legacy_json_state_file; then
    exit 2
fi

emit_event "circuit-breaker-gate" "ALLOW" "{\"strict\":1}" 2>/dev/null || true
exit 0
