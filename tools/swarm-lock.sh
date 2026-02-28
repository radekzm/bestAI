#!/bin/bash
# tools/swarm-lock.sh — Multi-agent coordination Mutex
# Usage: bash tools/swarm-lock.sh --lock "file_path" --agent "AgentID"
#        bash tools/swarm-lock.sh --unlock "file_path"
#        bash tools/swarm-lock.sh --status
# Locks auto-expire after SWARM_LOCK_TTL seconds (default: 300 = 5 min).

set -euo pipefail

LOCK_DB=".bestai/swarm_locks.json"
LOCK_TTL="${SWARM_LOCK_TTL:-300}"
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

# Purge expired locks (TTL-based deadlock prevention)
purge_expired() {
    local now
    now=$(date +%s)
    TMP=$(mktemp)
    jq --argjson now "$now" --argjson ttl "$LOCK_TTL" '
        to_entries | map(
            select(
                (.value.locked_at_unix // 0) > ($now - $ttl)
            )
        ) | from_entries
    ' "$LOCK_DB" > "$TMP" && mv "$TMP" "$LOCK_DB"
}

purge_expired

case "$COMMAND" in
    --lock)
        if [ -z "$FILE" ]; then echo "Missing file"; exit 1; fi
        CURRENT_OWNER=$(jq -r ".\"$FILE\".agent // empty" "$LOCK_DB")
        if [ -n "$CURRENT_OWNER" ] && [ "$CURRENT_OWNER" != "$AGENT" ]; then
            echo "[SWARM] BLOCKED: $FILE is already locked by $CURRENT_OWNER"
            exit 1
        fi
        NOW_UNIX=$(date +%s)
        TMP=$(mktemp)
        jq --arg file "$FILE" --arg agent "$AGENT" \
           --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson ts_unix "$NOW_UNIX" \
           '.[$file] = {"agent": $agent, "locked_at": $ts, "locked_at_unix": $ts_unix}' \
           "$LOCK_DB" > "$TMP" && mv "$TMP" "$LOCK_DB"
        echo "[SWARM] OK: Locked $FILE for $AGENT (TTL: ${LOCK_TTL}s)"
        ;;
    --unlock)
        if [ -z "$FILE" ]; then echo "Missing file"; exit 1; fi
        TMP=$(mktemp)
        jq --arg file "$FILE" "del(.\"$FILE\")" "$LOCK_DB" > "$TMP" && mv "$TMP" "$LOCK_DB"
        echo "[SWARM] OK: Unlocked $FILE"
        ;;
    --status)
        echo "[SWARM] Active locks (TTL: ${LOCK_TTL}s):"
        jq . "$LOCK_DB"
        ;;
esac
