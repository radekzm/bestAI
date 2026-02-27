#!/bin/bash
# hooks/circuit-breaker-gate.sh — PreToolUse hook (Bash matcher)
# Blocks tools when the circuit is OPEN (too many consecutive failures).

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/circuit-breaker-state.json"

if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

STATE=$(jq -r '.state // "CLOSED"' "$STATE_FILE")
FAIL_COUNT=$(jq -r '.consecutive_failures // 0' "$STATE_FILE")

if [ "$STATE" = "OPEN" ]; then
    echo "BLOCKED: Circuit Breaker is OPEN due to $FAIL_COUNT consecutive failures." >&2
    echo "Root Cause Table must be updated or project state re-evaluated before proceeding." >&2
    exit 2
fi

exit 0
