#!/bin/bash
# hooks/circuit-breaker-gate.sh — PreToolUse strict gate for circuit breaker
# Blocks new Bash actions while circuit is OPEN and cooldown is active.

set -euo pipefail

if [ "${CIRCUIT_BREAKER_STRICT:-1}" != "1" ]; then
    exit 0
fi

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    [ -n "$TOOL_NAME" ] && [ "$TOOL_NAME" != "Bash" ] && exit 0
fi

STATE_DIR="${XDG_RUNTIME_DIR:-${HOME}/.cache}/claude-circuit-breaker"
COOLDOWN=${CIRCUIT_BREAKER_COOLDOWN:-300}
NOW=$(date +%s)

[ -d "$STATE_DIR" ] || exit 0

BLOCKED=0
MIN_REMAINING=999999
BLOCK_FILE=""

for state_file in "$STATE_DIR"/*; do
    [ -f "$state_file" ] || continue
    [[ "$state_file" == *.lock ]] && continue

    STATE=$(sed -n '1p' "$state_file" 2>/dev/null || echo "")
    COUNT=$(sed -n '2p' "$state_file" 2>/dev/null || echo "0")
    LAST_FAIL=$(sed -n '3p' "$state_file" 2>/dev/null || echo "0")

    [[ "$COUNT" =~ ^[0-9]+$ ]] || COUNT=0
    [[ "$LAST_FAIL" =~ ^[0-9]+$ ]] || LAST_FAIL=0

    if [ "$STATE" = "OPEN" ]; then
        ELAPSED=$((NOW - LAST_FAIL))
        if [ "$ELAPSED" -lt "$COOLDOWN" ]; then
            REMAINING=$((COOLDOWN - ELAPSED))
            if [ "$REMAINING" -lt "$MIN_REMAINING" ]; then
                MIN_REMAINING=$REMAINING
                BLOCK_FILE=$(basename "$state_file")
            fi
            BLOCKED=1
        else
            printf "HALF-OPEN\n%s\n%s\n" "$COUNT" "$NOW" > "$state_file"
        fi
    fi
done

if [ "$BLOCKED" -eq 1 ]; then
    echo "BLOCKED: Circuit Breaker OPEN (strict mode)." >&2
    echo "Pattern: $BLOCK_FILE" >&2
    echo "Retry allowed in ${MIN_REMAINING}s or use a fundamentally different approach." >&2
    exit 2
fi

exit 0
