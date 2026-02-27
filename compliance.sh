#!/bin/bash
# compliance.sh — bestAI Automated Compliance Measurement
# Usage: bash compliance.sh [target-project-dir] [--json] [--since YYYY-MM-DD]
# Reads events.jsonl to compute enforcement metrics.
# Requires: jq

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TARGET="."
JSON_MODE=0
SINCE=""
TARGET_SET=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=1; shift ;;
        --since) SINCE="${2:-}"; shift 2 ;;
        *)
            if [ "$TARGET_SET" -eq 0 ]; then
                TARGET="$1"
                TARGET_SET=1
            fi
            shift
            ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for compliance measurement." >&2
    exit 1
fi

if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$TARGET" && pwd)"
EVENT_LOG="${BESTAI_EVENT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/bestai/events.jsonl}"

project_hash() {
    local src="$1"
    if command -v md5sum >/dev/null 2>&1; then
        echo "$src" | md5sum | awk '{print substr($1,1,16)}'
    elif command -v shasum >/dev/null 2>&1; then
        echo "$src" | shasum -a 256 | awk '{print substr($1,1,16)}'
    else
        echo "$src" | cksum | awk '{print $1}'
    fi
}

PROJ_HASH=$(project_hash "$PROJECT_DIR")

if [ ! -f "$EVENT_LOG" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        echo '{"error":"no_event_log","message":"No event log found. Run hooks to generate events."}'
    else
        echo -e "${RED}No event log found${NC}: $EVENT_LOG"
        echo "Run hooks to generate events first."
    fi
    exit 1
fi

# Filter events for this project
EVENTS=$(grep "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" 2>/dev/null || true)

if [ -z "$EVENTS" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        echo '{"error":"no_events","message":"No events for this project."}'
    else
        echo -e "${YELLOW}No events found for this project${NC}"
    fi
    exit 0
fi

# Apply --since filter
if [ -n "$SINCE" ]; then
    EVENTS=$(echo "$EVENTS" | jq -c --arg since "$SINCE" 'select(.ts >= $since)' 2>/dev/null || echo "$EVENTS")
fi

# Re-check after filtering
if [ -z "$EVENTS" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        echo '{"error":"no_events","message":"No events match the given filters."}'
    else
        echo -e "${YELLOW}No events match the given filters${NC}"
    fi
    exit 0
fi

TOTAL=$(echo "$EVENTS" | wc -l | tr -d ' ')
BLOCKS=$(echo "$EVENTS" | grep -c '"action":"BLOCK"' || echo 0)
ALLOWS=$(echo "$EVENTS" | grep -c '"action":"ALLOW"' || echo 0)
OTHER=$((TOTAL - BLOCKS - ALLOWS))

# Compliance rate: ratio of ALLOW to total enforcement decisions (BLOCK + ALLOW)
ENFORCEMENT_TOTAL=$((BLOCKS + ALLOWS))
if [ "$ENFORCEMENT_TOTAL" -gt 0 ]; then
    # Integer arithmetic: compliance = allows * 100 / total
    COMPLIANCE=$((ALLOWS * 100 / ENFORCEMENT_TOTAL))
    BLOCK_RATE=$((BLOCKS * 100 / ENFORCEMENT_TOTAL))
else
    COMPLIANCE=0
    BLOCK_RATE=0
fi

if [ "$JSON_MODE" -eq 1 ]; then
    # Per-hook breakdown
    HOOK_BREAKDOWN=$(echo "$EVENTS" | jq -r '.hook' | sort | uniq -c | sort -rn \
        | awk '{printf "{\"hook\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')

    HOOK_BLOCKS=$(echo "$EVENTS" | jq -r 'select(.action == "BLOCK") | .hook' | sort | uniq -c | sort -rn \
        | awk '{printf "{\"hook\":\"%s\",\"blocks\":%d},", $2, $1}' | sed 's/,$//')

    FIRST_TS=$(echo "$EVENTS" | head -1 | jq -r '.ts')
    LAST_TS=$(echo "$EVENTS" | tail -1 | jq -r '.ts')

    cat <<JSON
{
  "project": "$(basename "$PROJECT_DIR")",
  "project_hash": "$PROJ_HASH",
  "period": {"from": "$FIRST_TS", "to": "$LAST_TS"},
  "total_events": $TOTAL,
  "blocks": $BLOCKS,
  "allows": $ALLOWS,
  "other": $OTHER,
  "compliance_pct": $COMPLIANCE,
  "block_rate_pct": $BLOCK_RATE,
  "hooks": [$HOOK_BREAKDOWN],
  "blocks_by_hook": [$HOOK_BLOCKS]
}
JSON
    exit 0
fi

# Human-readable output
echo -e "${BOLD}bestAI Compliance Report${NC} — $(basename "$PROJECT_DIR")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

FIRST_TS=$(echo "$EVENTS" | head -1 | jq -r '.ts')
LAST_TS=$(echo "$EVENTS" | tail -1 | jq -r '.ts')
echo -e "  Period:             ${DIM}$FIRST_TS → $LAST_TS${NC}"
echo "  Total events:       $TOTAL"
echo ""

echo -e "${BOLD}Enforcement Summary${NC}"
echo "  Allowed:            $ALLOWS"
echo "  Blocked:            $BLOCKS"
echo "  Other (CB, etc):    $OTHER"

if [ "$COMPLIANCE" -ge 90 ]; then
    COLOR="$GREEN"
elif [ "$COMPLIANCE" -ge 70 ]; then
    COLOR="$YELLOW"
else
    COLOR="$RED"
fi
echo -e "  Compliance rate:    ${COLOR}${COMPLIANCE}%${NC}"
echo -e "  Block rate:         ${BLOCK_RATE}%"
echo ""

echo -e "${BOLD}By Hook${NC}"
echo "$EVENTS" | jq -r '.hook' | sort | uniq -c | sort -rn | while read -r count hook; do
    local_blocks=$(echo "$EVENTS" | grep "\"hook\":\"$hook\"" | grep -c '"action":"BLOCK"' || echo 0)
    local_allows=$(echo "$EVENTS" | grep "\"hook\":\"$hook\"" | grep -c '"action":"ALLOW"' || echo 0)
    if [ "$local_blocks" -gt 0 ]; then
        echo -e "  $hook: ${GREEN}$local_allows allow${NC} / ${RED}$local_blocks block${NC} ($count total)"
    else
        echo -e "  $hook: ${GREEN}$local_allows allow${NC} ($count total)"
    fi
done
echo ""

# Daily trend (last 7 days)
echo -e "${BOLD}Daily Trend (last 7 days)${NC}"
for i in $(seq 6 -1 0); do
    DAY=$(date -u -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -u -v-${i}d +%Y-%m-%d 2>/dev/null || continue)
    DAY_EVENTS=$(echo "$EVENTS" | grep -c "\"ts\":\"$DAY" || echo 0)
    DAY_BLOCKS=$(echo "$EVENTS" | grep "\"ts\":\"$DAY" | grep -c '"action":"BLOCK"' || echo 0)
    if [ "$DAY_EVENTS" -gt 0 ]; then
        BAR=$(printf '%*s' "$DAY_EVENTS" '' | tr ' ' '█')
        echo -e "  $DAY  ${BAR:0:40} $DAY_EVENTS events ($DAY_BLOCKS blocks)"
    else
        echo -e "  $DAY  ${DIM}—${NC}"
    fi
done
echo ""

# Top blocked patterns
if [ "$BLOCKS" -gt 0 ]; then
    echo -e "${BOLD}Top Block Reasons${NC}"
    echo "$EVENTS" | jq -r 'select(.action == "BLOCK") | .detail.reason // .detail.detail // "unknown"' 2>/dev/null \
        | sort | uniq -c | sort -rn | head -5 \
        | while read -r count reason; do
            echo "  $count× ${reason:0:80}"
        done
    echo ""
fi

echo -e "${DIM}Report generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)${NC}"
echo -e "${DIM}Event log: $EVENT_LOG${NC}"
