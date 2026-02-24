#!/bin/bash
# hooks/circuit-breaker.sh — PostToolUse hook (Bash matcher)
# CS Algorithm: Circuit Breaker (Michael Nygard, "Release It!", 2007)
# States: CLOSED (normal) -> OPEN (block after N failures) -> HALF-OPEN (test 1)
# Tracks error patterns and stops agent after threshold consecutive failures.

set -euo pipefail

STATE_DIR="/tmp/claude-circuit-breaker"
mkdir -p "$STATE_DIR"

THRESHOLD=${CIRCUIT_BREAKER_THRESHOLD:-3}  # Failures before OPEN
COOLDOWN=${CIRCUIT_BREAKER_COOLDOWN:-300}  # Seconds before HALF-OPEN (5 min)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_input.exit_code // .exit_code // 0' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_output.stderr // empty' 2>/dev/null | head -1)

[ -z "$TOOL_NAME" ] && exit 0

# Create error signature (first meaningful line of stderr, normalized)
error_sig() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[0-9]/#/g' | md5sum | cut -c1-8
}

# Get state file for this error pattern
SIG=$(error_sig "$STDERR")
STATE_FILE="$STATE_DIR/$SIG"

# If command succeeded, reset circuit for this pattern
if [ "$EXIT_CODE" = "0" ] || [ -z "$STDERR" ]; then
    if [ -f "$STATE_FILE" ]; then
        STATE=$(cat "$STATE_FILE" | head -1)
        if [ "$STATE" = "HALF-OPEN" ]; then
            echo "[Circuit Breaker] Pattern recovered. HALF-OPEN -> CLOSED."
        fi
        rm -f "$STATE_FILE"
    fi
    exit 0
fi

# Command failed — track the failure
if [ ! -f "$STATE_FILE" ]; then
    echo "CLOSED" > "$STATE_FILE"
    echo "1" >> "$STATE_FILE"
    echo "$(date +%s)" >> "$STATE_FILE"
    exit 0
fi

STATE=$(sed -n '1p' "$STATE_FILE")
COUNT=$(sed -n '2p' "$STATE_FILE")
LAST_FAIL=$(sed -n '3p' "$STATE_FILE")
NOW=$(date +%s)

case "$STATE" in
    CLOSED)
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -ge "$THRESHOLD" ]; then
            echo "OPEN" > "$STATE_FILE"
            echo "$COUNT" >> "$STATE_FILE"
            echo "$NOW" >> "$STATE_FILE"
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
        else
            echo "CLOSED" > "$STATE_FILE"
            echo "$COUNT" >> "$STATE_FILE"
            echo "$NOW" >> "$STATE_FILE"
        fi
        ;;
    OPEN)
        ELAPSED=$((NOW - LAST_FAIL))
        if [ "$ELAPSED" -ge "$COOLDOWN" ]; then
            echo "HALF-OPEN" > "$STATE_FILE"
            echo "$COUNT" >> "$STATE_FILE"
            echo "$NOW" >> "$STATE_FILE"
            echo "[Circuit Breaker] Cooldown elapsed. OPEN -> HALF-OPEN. Allowing 1 retry."
        else
            REMAINING=$((COOLDOWN - ELAPSED))
            echo "[Circuit Breaker] OPEN — blocked. ${REMAINING}s until retry allowed."
            echo "Try a different approach instead of retrying."
        fi
        ;;
    HALF-OPEN)
        # Failed again in half-open state — back to OPEN
        echo "OPEN" > "$STATE_FILE"
        echo "$((COUNT + 1))" >> "$STATE_FILE"
        echo "$NOW" >> "$STATE_FILE"
        echo "[Circuit Breaker] Failed in HALF-OPEN. Back to OPEN."
        echo "This approach is not working. STOP and ask the user."
        ;;
esac

exit 0
