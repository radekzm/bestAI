#!/bin/bash
# tools/swarm-lock.sh — Multi-agent coordination Mutex
# Usage: bash tools/swarm-lock.sh --lock "file_path" --agent "AgentID"
#        bash tools/swarm-lock.sh --status

set -euo pipefail

LOCK_DB=".bestai/swarm_locks.json"
mkdir -p .bestai

if [ ! -f "$LOCK_DB" ]; then
    echo "{}" > "$LOCK_DB"
fi

COMMAND=""
FILE=""
AGENT="UnknownAgent"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --lock|--unlock|--status) COMMAND="$1"; shift ;;
        --agent) AGENT="${2:-}"; shift 2 ;;
        *) FILE="$1"; shift ;;
    esac
done

case "$COMMAND" in
    --lock)
        if [ -z "$FILE" ]; then echo "Missing file"; exit 1; fi
        CURRENT_OWNER=$(jq -r ".\"$FILE\".agent // empty" "$LOCK_DB")
        if [ -n "$CURRENT_OWNER" ] && [ "$CURRENT_OWNER" != "$AGENT" ]; then
            echo "[SWARM] 🛑 ABORT: $FILE is already locked by $CURRENT_OWNER"
            exit 1
        fi
        TMP=$(mktemp)
        jq --arg file "$FILE" --arg agent "$AGENT" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
           '.[$file] = {"agent": $agent, "locked_at": $ts}' "$LOCK_DB" > "$TMP" && mv "$TMP" "$LOCK_DB"
        echo "[SWARM] ✅ Locked $FILE for $AGENT"
        ;;
    --unlock)
        if [ -z "$FILE" ]; then echo "Missing file"; exit 1; fi
        TMP=$(mktemp)
        jq --arg file "$FILE" "del(.\"$FILE\")" "$LOCK_DB" > "$TMP" && mv "$TMP" "$LOCK_DB"
        echo "[SWARM] 🔓 Unlocked $FILE"
        ;;
    --status)
        echo "🔒 Active Swarm Locks:"
        jq . "$LOCK_DB"
        ;;
esac
