#!/bin/bash
# hooks/circuit-breaker.sh — PostToolUse hook (Bash matcher)
# CS Algorithm: Circuit Breaker (Michael Nygard, "Release It!", 2007)
# States: CLOSED (normal) -> OPEN (advisory stop) -> HALF-OPEN (test 1)
#
# NOTE: This is a PostToolUse hook — it runs AFTER the tool executes.
# It provides ADVISORY output (context injection) telling the agent to stop.
# It CANNOT deterministically block the next tool call.
# For deterministic blocking, pair with a PreToolUse hook that checks state.

set -euo pipefail

BASE_STATE_DIR="${XDG_RUNTIME_DIR:-${HOME}/.cache}/claude-circuit-breaker"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

project_hash() {
    local src="$1"
    if command -v md5sum >/dev/null 2>&1; then
        echo "$src" | md5sum | awk '{print substr($1,1,16)}'
    elif command -v md5 >/dev/null 2>&1; then
        echo -n "$src" | md5 -q | cut -c1-16
    elif command -v shasum >/dev/null 2>&1; then
        echo "$src" | shasum -a 256 | awk '{print substr($1,1,16)}'
    else
        echo "$src" | cksum | awk '{print $1}'
    fi
}

PROJECT_HASH=$(project_hash "$PROJECT_DIR")
# Project-scoped breaker state prevents cross-repo strict-gate blocking.
STATE_DIR="$BASE_STATE_DIR/$PROJECT_HASH"
mkdir -p "$STATE_DIR"

THRESHOLD=${CIRCUIT_BREAKER_THRESHOLD:-3}  # Failures before OPEN
COOLDOWN=${CIRCUIT_BREAKER_COOLDOWN_SECS:-${CIRCUIT_BREAKER_COOLDOWN:-300}}  # Seconds before HALF-OPEN (5 min)

# Unified JSONL event logging
# shellcheck source=hook-event.sh
source "$(dirname "$0")/hook-event.sh" 2>/dev/null || true

INPUT=$(cat)

# If jq is missing, skip gracefully (this hook is advisory, not enforcement)
if ! command -v jq &>/dev/null; then
    exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_input.exit_code // .exit_code // empty' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_output.stderr // empty' 2>/dev/null | head -1)

[ -z "$TOOL_NAME" ] && exit 0

# Create error signature (first meaningful line of stderr, normalized)
error_sig() {
    local input="$1"
    local normalized
    normalized=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[0-9]/#/g')
    # Use md5sum (Linux) or md5 (macOS)
    if command -v md5sum &>/dev/null; then
        echo "$normalized" | md5sum | cut -c1-16
    elif command -v md5 &>/dev/null; then
        echo "$normalized" | md5 -q | cut -c1-16
    else
        # Fallback: use cksum
        echo "$normalized" | cksum | cut -d' ' -f1
    fi
}

# Get state file for this error pattern
SIG=$(error_sig "$STDERR")
STATE_FILE="$STATE_DIR/$SIG"

# If command succeeded (explicit exit code 0), reset circuit for this pattern
if [ "$EXIT_CODE" = "0" ]; then
    if [ -f "$STATE_FILE" ]; then
        STATE=$(head -1 "$STATE_FILE")
        if [ "$STATE" = "HALF-OPEN" ]; then
            echo "[Circuit Breaker] Pattern recovered. HALF-OPEN -> CLOSED."
        fi
        rm -f "$STATE_FILE"
    fi
    exit 0
fi

# No exit code or no stderr — not a clear failure, skip
if [ -z "$EXIT_CODE" ] || [ -z "$STDERR" ]; then
    exit 0
fi

# Command failed — track the failure (use flock to prevent race conditions)
(
    flock -n 200 || exit 0  # Skip if can't get lock

    if [ ! -f "$STATE_FILE" ]; then
        printf "CLOSED\n1\n%s\n" "$(date +%s)" > "$STATE_FILE"
        exit 0
    fi

    STATE=$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo "CLOSED")
    COUNT=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "0")
    LAST_FAIL=$(sed -n '3p' "$STATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)

    # Validate COUNT is numeric
    [[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0
    [[ "$LAST_FAIL" =~ ^[0-9]+$ ]] || LAST_FAIL=0

    case "$STATE" in
        CLOSED)
            COUNT=$((COUNT + 1))
            if [ "$COUNT" -ge "$THRESHOLD" ]; then
                printf "OPEN\n%s\n%s\n" "$COUNT" "$NOW" > "$STATE_FILE"
                echo ""
                echo "[Circuit Breaker] OPEN after $COUNT consecutive failures."
                echo "Error pattern: $STDERR"
                echo ""
                echo "ROOT_CAUSE_TABLE:"
                echo "| Attempt | Error | Suggestion |"
                echo "|---------|-------|------------|"
                echo "| $COUNT failures | $(echo "$STDERR" | head -c 60) | Try a different approach |"
                echo ""
                echo "STOP: Ask user for guidance or try a fundamentally different approach."
                emit_event "circuit-breaker" "OPEN" "{\"sig\":\"$SIG\",\"count\":$COUNT}" 2>/dev/null || true
            else
                printf "CLOSED\n%s\n%s\n" "$COUNT" "$NOW" > "$STATE_FILE"
            fi
            ;;
        OPEN)
            ELAPSED=$((NOW - LAST_FAIL))
            if [ "$ELAPSED" -ge "$COOLDOWN" ]; then
                printf "HALF-OPEN\n%s\n%s\n" "$COUNT" "$NOW" > "$STATE_FILE"
                echo "[Circuit Breaker] Cooldown elapsed. OPEN -> HALF-OPEN. Allowing 1 retry."
                emit_event "circuit-breaker" "HALF_OPEN" "{\"sig\":\"$SIG\",\"count\":$COUNT}" 2>/dev/null || true
            else
                REMAINING=$((COOLDOWN - ELAPSED))
                echo "[Circuit Breaker] OPEN — advisory stop. ${REMAINING}s until retry allowed."
                echo "Try a different approach instead of retrying."
            fi
            ;;
        HALF-OPEN)
            printf "OPEN\n%s\n%s\n" "$((COUNT + 1))" "$NOW" > "$STATE_FILE"
            echo "[Circuit Breaker] Failed in HALF-OPEN. Back to OPEN."
            echo "This approach is not working. STOP and ask the user."
            emit_event "circuit-breaker" "REOPEN" "{\"sig\":\"$SIG\",\"count\":$((COUNT + 1))}" 2>/dev/null || true
            ;;
    esac

) 200>"$STATE_FILE.lock"

exit 0
