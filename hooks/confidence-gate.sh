#!/bin/bash
# hooks/confidence-gate.sh — PreToolUse hook (Bash matcher)
# Blocks deploy/migrate/restart when system CONFIDENCE < threshold.
#
# Design:
#   - Parses state-of-system-now.md for CONFIDENCE: X.XX
#   - If CONF < 0.70: exit 2 (BLOCK)
#   - If no CONF data: pass (fail-open — don't block when no data)
#   - Only triggers on dangerous operations (deploy, migrate, restart)
#
# Env vars:
#   CONFIDENCE_THRESHOLD=0.70 — minimum confidence for dangerous ops

set -euo pipefail

if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || exit 0

# Only check Bash commands
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Only check dangerous operations
if ! echo "$COMMAND" | grep -Eqi '(deploy|migrate|restart|rollback|production|staging)'; then
    exit 0
fi

THRESHOLD="${CONFIDENCE_THRESHOLD:-0.70}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$PROJECT_DIR/.claude/state-of-system-now.md"

# If no state file, pass (fail-open)
[ -f "$STATE_FILE" ] || exit 0

# Extract CONFIDENCE value
CONF=$(grep -ioE 'CONFIDENCE:\s*[0-9]+\.[0-9]+' "$STATE_FILE" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+') || true

# If no CONF data found, pass (fail-open)
[ -z "$CONF" ] && exit 0

# Compare using awk (bash can't do float comparison)
BLOCKED=$(awk -v conf="$CONF" -v thresh="$THRESHOLD" 'BEGIN { print (conf < thresh) ? "1" : "0" }')

if [ "$BLOCKED" = "1" ]; then
    echo "BLOCKED: System confidence $CONF < $THRESHOLD threshold." >&2
    echo "Operation: $COMMAND" >&2
    echo "Update state-of-system-now.md with higher CONFIDENCE before proceeding." >&2
    exit 2
fi

exit 0
