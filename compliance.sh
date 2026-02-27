#!/bin/bash
# compliance.sh — bestAI Compliance Dashboard
# Usage: bash compliance.sh [project-dir] [--json] [--since YYYY-MM-DD]
# Reads events from BESTAI_EVENT_LOG (default: ~/.cache/bestai/events.jsonl)

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TARGET="${1:-.}"
JSON_MODE=0
SINCE=""

# Parse args
shift || true
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=1; shift ;;
        --since) SINCE="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

# Source hook-event.sh for consistent project hash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=hooks/hook-event.sh
CLAUDE_PROJECT_DIR="$TARGET" source "$SCRIPT_DIR/hooks/hook-event.sh" 2>/dev/null || {
    _bestai_project_hash() {
        printf '%s' "${1:-$TARGET}" | md5sum 2>/dev/null | awk '{print substr($1,1,16)}' || printf '%s' "${1:-$TARGET}" | cksum | awk '{print $1}'
    }
}

PROJ_HASH=$(_bestai_project_hash "$TARGET")
EVENT_LOG="${BESTAI_EVENT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/bestai/events.jsonl}"

if [ ! -f "$EVENT_LOG" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        echo '{"error":"no_log","message":"No event log found. Run hooks to generate events."}'
    else
        echo -e "${YELLOW}No event log found at $EVENT_LOG${NC}"
        echo "Run hooks to generate events first."
    fi
    exit 0
fi

# Filter events for this project
EVENTS=$(grep "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" 2>/dev/null || true)

# Apply --since filter
if [ -n "$SINCE" ] && [ -n "$EVENTS" ]; then
    EVENTS=$(echo "$EVENTS" | jq -c "select(.ts >= \"$SINCE\")" 2>/dev/null || true)
fi

if [ -z "$EVENTS" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        echo '{"error":"no_events","message":"No events match the given filters."}'
    else
        echo -e "${YELLOW}No events match the given filters${NC}"
    fi
    exit 0
fi

# Count using correct field name: "action" (not "type")
TOTAL=$(echo "$EVENTS" | wc -l | tr -d ' ')
BLOCKS=$(echo "$EVENTS" | grep -c '"action":"BLOCK"' || echo 0)
ALLOWS=$(echo "$EVENTS" | grep -c '"action":"ALLOW"' || echo 0)

if [ "$TOTAL" -gt 0 ]; then
    COMPLIANCE_RATIO=$(( (ALLOWS * 100) / TOTAL ))
else
    COMPLIANCE_RATIO=100
fi

if [ "$JSON_MODE" -eq 1 ]; then
    # JSON output
    HOOKS_JSON=$(echo "$EVENTS" | jq -r '.hook' 2>/dev/null | sort | uniq -c | sort -rn | awk '{printf "{\"hook\":\"%s\",\"count\":%s},", $2, $1}' | sed 's/,$//')
    echo "{\"project\":\"$(basename "$TARGET")\",\"total\":$TOTAL,\"blocks\":$BLOCKS,\"allows\":$ALLOWS,\"compliance_pct\":$COMPLIANCE_RATIO,\"hooks\":[$HOOKS_JSON]}"
else
    # Human-readable output
    echo -e "${BOLD}bestAI Compliance Report${NC}"
    echo "Project: $(basename "$TARGET") ($PROJ_HASH)"
    echo "Event log: $EVENT_LOG"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Total events:     $TOTAL"
    echo "  Allowed:          $ALLOWS"
    echo "  Blocked:          $BLOCKS"

    if [ "$COMPLIANCE_RATIO" -ge 80 ]; then
        echo -e "  Compliance:       ${GREEN}${COMPLIANCE_RATIO}%${NC}"
    elif [ "$COMPLIANCE_RATIO" -ge 50 ]; then
        echo -e "  Compliance:       ${YELLOW}${COMPLIANCE_RATIO}%${NC}"
    else
        echo -e "  Compliance:       ${RED}${COMPLIANCE_RATIO}%${NC}"
    fi

    echo ""
    echo "  By hook:"
    echo "$EVENTS" | jq -r '.hook' 2>/dev/null | sort | uniq -c | sort -rn | while read -r count hook; do
        printf "    %-28s %s events\n" "$hook" "$count"
    done

    if [ "$BLOCKS" -gt 0 ]; then
        echo ""
        echo "  Recent blocks:"
        echo "$EVENTS" | grep '"action":"BLOCK"' | tail -5 | jq -r '"    [\(.ts)] \(.hook): \(.detail.file // .detail.reason // "—")"' 2>/dev/null || true
    fi

    echo ""
    if [ "$COMPLIANCE_RATIO" -lt 80 ]; then
        echo -e "  ${RED}Agent frequently attempts to bypass rules.${NC}"
    else
        echo -e "  ${GREEN}Healthy compliance.${NC}"
    fi
fi
