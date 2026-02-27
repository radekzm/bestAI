#!/bin/bash
# stats.sh — bestAI Observability Dashboard
# Usage: bash stats.sh [target-project-dir]
# Parses existing hook metrics, circuit breaker state, memory usage,
# and GPS to show a unified health/metrics report.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$TARGET" && pwd)"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
METRICS_FILE="$HOME/.claude/projects/$PROJECT_KEY/hook-metrics.log"
SESSION_COUNTER="$MEMORY_DIR/.session-counter"
USAGE_LOG="$MEMORY_DIR/.usage-log"
GPS_FILE="$PROJECT_DIR/.bestai/GPS.json"
EVENT_LOG="${BESTAI_EVENT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/bestai/events.jsonl}"
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"

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

CB_STATE_DIR="${XDG_RUNTIME_DIR:-${HOME}/.cache}/claude-circuit-breaker/$(project_hash "$PROJECT_DIR")"

echo -e "${BOLD}bestAI Health Report${NC} — $(basename "$PROJECT_DIR")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Sessions ──
echo -e "${BOLD}Sessions${NC}"
if [ -f "$SESSION_COUNTER" ]; then
    SESSIONS=$(cat "$SESSION_COUNTER" 2>/dev/null || echo 0)
    [[ "$SESSIONS" =~ ^[0-9]+$ ]] || SESSIONS=0
    echo "  Total sessions:  $SESSIONS"
else
    echo -e "  ${DIM}No session data (.session-counter not found)${NC}"
fi
echo ""

# ── Hook Metrics ──
echo -e "${BOLD}Hook Enforcement${NC}"
if [ -f "$METRICS_FILE" ]; then
    TOTAL_EVENTS=$(wc -l < "$METRICS_FILE" | tr -d ' ')
    BLOCKS=$(grep -c ' BLOCK ' "$METRICS_FILE" 2>/dev/null || echo 0)
    ALLOWS=$(grep -c ' ALLOW ' "$METRICS_FILE" 2>/dev/null || echo 0)

    echo "  Total hook events:  $TOTAL_EVENTS"
    echo "  Blocked:            $BLOCKS"
    echo "  Allowed:            $ALLOWS"

    if [ "$BLOCKS" -gt 0 ]; then
        echo ""
        echo "  Top blocked hooks:"
        awk '$3 == "BLOCK" {print $2}' "$METRICS_FILE" \
            | sort | uniq -c | sort -rn | head -5 \
            | while read -r count hook; do
                echo "    $hook: $count blocks"
            done

        LAST_BLOCK=$(grep ' BLOCK ' "$METRICS_FILE" | tail -1)
        if [ -n "$LAST_BLOCK" ]; then
            LAST_TS=$(echo "$LAST_BLOCK" | awk '{print $1}')
            echo -e "  Last block:         ${DIM}$LAST_TS${NC}"
        fi
    fi
else
    echo -e "  ${DIM}No metrics data (hook-metrics.log not found)${NC}"
fi
echo ""

# ── Circuit Breaker ──
echo -e "${BOLD}Circuit Breaker${NC}"
if [ -d "$CB_STATE_DIR" ]; then
    OPEN_COUNT=0
    HALF_OPEN_COUNT=0
    CLOSED_COUNT=0

    for state_file in "$CB_STATE_DIR"/*; do
        [ -f "$state_file" ] || continue
        [[ "$state_file" == *.lock ]] && continue

        STATE=$(sed -n '1p' "$state_file" 2>/dev/null || echo "")
        case "$STATE" in
            OPEN) OPEN_COUNT=$((OPEN_COUNT + 1)) ;;
            HALF-OPEN) HALF_OPEN_COUNT=$((HALF_OPEN_COUNT + 1)) ;;
            CLOSED) CLOSED_COUNT=$((CLOSED_COUNT + 1)) ;;
        esac
    done

    TOTAL_PATTERNS=$((OPEN_COUNT + HALF_OPEN_COUNT + CLOSED_COUNT))
    if [ "$TOTAL_PATTERNS" -eq 0 ]; then
        echo -e "  ${GREEN}No tracked error patterns${NC}"
    else
        echo "  Tracked patterns:   $TOTAL_PATTERNS"
        [ "$CLOSED_COUNT" -gt 0 ] && echo -e "    ${GREEN}CLOSED:     $CLOSED_COUNT${NC}"
        [ "$HALF_OPEN_COUNT" -gt 0 ] && echo -e "    ${YELLOW}HALF-OPEN:  $HALF_OPEN_COUNT${NC}"
        [ "$OPEN_COUNT" -gt 0 ] && echo -e "    ${RED}OPEN:       $OPEN_COUNT${NC}"
    fi

    if [ -f "$METRICS_FILE" ]; then
        CB_TRIPS=$(grep -c 'circuit-breaker OPEN' "$METRICS_FILE" 2>/dev/null || echo 0)
        [ "$CB_TRIPS" -gt 0 ] && echo "  Historical trips:   $CB_TRIPS"
    fi
else
    echo -e "  ${DIM}No circuit breaker state${NC}"
fi
echo ""

# ── Memory ──
echo -e "${BOLD}Memory${NC}"
if [ -d "$MEMORY_DIR" ]; then
    MD_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  Memory files:       $MD_FILES"

    if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
        MEM_LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md" | tr -d ' ')
        if [ "$MEM_LINES" -gt 200 ]; then
            echo -e "  MEMORY.md lines:    ${RED}$MEM_LINES (over 200-line cap!)${NC}"
        else
            echo "  MEMORY.md lines:    $MEM_LINES / 200"
        fi
    fi

    USER_COUNT=0
    AUTO_COUNT=0
    for f in "$MEMORY_DIR"/*.md; do
        [ -f "$f" ] || continue
        if grep -q '\[USER\]' "$f" 2>/dev/null; then
            USER_COUNT=$((USER_COUNT + 1))
        else
            AUTO_COUNT=$((AUTO_COUNT + 1))
        fi
    done
    echo "  [USER] tagged:      $USER_COUNT"
    echo "  [AUTO] only:        $AUTO_COUNT"

    if [ -f "$USAGE_LOG" ]; then
        echo ""
        echo "  Top by usage:"
        sort -t$'\t' -k3 -rn "$USAGE_LOG" 2>/dev/null | head -5 \
            | while IFS=$'\t' read -r fname last_sess count tag; do
                [ -z "$fname" ] && continue
                echo "    $fname: $count accesses [$tag]"
            done
    fi

    if [ -f "$MEMORY_DIR/gc-archive.md" ]; then
        GC_ENTRIES=$(grep -c '^-' "$MEMORY_DIR/gc-archive.md" 2>/dev/null || echo 0)
        [ "$GC_ENTRIES" -gt 0 ] && echo "  GC'd entries:       $GC_ENTRIES"
    fi
else
    echo -e "  ${DIM}No memory directory${NC}"
fi
echo ""

# ── GPS ──
echo -e "${BOLD}Global Project State${NC}"
if [ -f "$GPS_FILE" ] && command -v jq >/dev/null 2>&1; then
    GPS_NAME=$(jq -r '.project.name // "unknown"' "$GPS_FILE" 2>/dev/null)
    GPS_OBJ=$(jq -r '.project.main_objective // "not set"' "$GPS_FILE" 2>/dev/null)
    MILESTONES_TOTAL=$(jq '.milestones | length' "$GPS_FILE" 2>/dev/null || echo 0)
    MILESTONES_DONE=$(jq '[.milestones[] | select(.status == "completed")] | length' "$GPS_FILE" 2>/dev/null || echo 0)
    MILESTONES_PROG=$(jq '[.milestones[] | select(.status == "in_progress")] | length' "$GPS_FILE" 2>/dev/null || echo 0)
    BLOCKERS=$(jq '.blockers | length' "$GPS_FILE" 2>/dev/null || echo 0)
    TASKS=$(jq '.active_tasks | length' "$GPS_FILE" 2>/dev/null || echo 0)
    LAST_UPDATE=$(jq -r '.project.status_updated_at // "never"' "$GPS_FILE" 2>/dev/null)

    echo "  Project:            $GPS_NAME"
    echo "  Objective:          ${GPS_OBJ:0:60}"
    echo "  Milestones:         $MILESTONES_DONE/$MILESTONES_TOTAL completed, $MILESTONES_PROG in progress"
    [ "$BLOCKERS" -gt 0 ] && echo -e "  ${RED}Blockers:           $BLOCKERS${NC}"
    echo "  Active tasks:       $TASKS"
    echo -e "  Last update:        ${DIM}$LAST_UPDATE${NC}"
else
    echo -e "  ${DIM}No GPS file (.bestai/GPS.json)${NC}"
fi
echo ""

# ── Hook Health ──
echo -e "${BOLD}Hook Health${NC}"
if [ -d "$HOOKS_DIR" ]; then
    HOOK_COUNT=0
    HOOK_OK=0
    HOOK_ISSUES=0

    for hook in "$HOOKS_DIR"/*.sh; do
        [ -f "$hook" ] || continue
        HOOK_COUNT=$((HOOK_COUNT + 1))
        BASENAME=$(basename "$hook")

        if [ ! -x "$hook" ]; then
            echo -e "  ${RED}NOT EXECUTABLE${NC}  $BASENAME"
            HOOK_ISSUES=$((HOOK_ISSUES + 1))
        else
            HOOK_OK=$((HOOK_OK + 1))
        fi
    done

    if [ "$HOOK_ISSUES" -eq 0 ] && [ "$HOOK_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}All $HOOK_COUNT hooks executable${NC}"
    elif [ "$HOOK_COUNT" -eq 0 ]; then
        echo -e "  ${DIM}No hooks installed${NC}"
    fi

    # Check dependencies
    for dep in jq; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "  ${RED}MISSING${NC}  $dep (required for enforcement hooks)"
            HOOK_ISSUES=$((HOOK_ISSUES + 1))
        fi
    done

    # Check settings.json references
    if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
        CONFIGURED=$(jq -r '.. | .command? // empty' "$SETTINGS_FILE" 2>/dev/null | grep -c '\.sh' || echo 0)
        echo "  Hooks in settings:  $CONFIGURED configured"

        # Check for missing hooks referenced in settings
        jq -r '.. | .command? // empty' "$SETTINGS_FILE" 2>/dev/null | while read -r cmd; do
            [ -z "$cmd" ] && continue
            HOOK_PATH="$PROJECT_DIR/$cmd"
            if [[ "$cmd" == *.sh ]] && [ ! -f "$HOOK_PATH" ]; then
                echo -e "  ${RED}MISSING${NC}  $cmd (referenced in settings.json but not found)"
            fi
        done
    fi
else
    echo -e "  ${DIM}No hooks directory${NC}"
fi
echo ""

# ── Event Log (JSONL) ──
echo -e "${BOLD}Event Log${NC}"
if [ -f "$EVENT_LOG" ] && command -v jq >/dev/null 2>&1; then
    PROJ_HASH=$(project_hash "$PROJECT_DIR")
    TOTAL_EVENTS=$(wc -l < "$EVENT_LOG" | tr -d ' ')
    PROJ_EVENTS=$(grep -c "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" 2>/dev/null || echo 0)
    PROJ_BLOCKS=$(grep "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" 2>/dev/null | grep -c '"action":"BLOCK"' || echo 0)

    echo "  Event log:          $EVENT_LOG"
    echo "  Total events:       $TOTAL_EVENTS (all projects)"
    echo "  This project:       $PROJ_EVENTS events, $PROJ_BLOCKS blocks"

    if [ "$PROJ_EVENTS" -gt 0 ]; then
        echo ""
        echo "  Events by hook:"
        grep "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" 2>/dev/null \
            | jq -r '.hook' 2>/dev/null \
            | sort | uniq -c | sort -rn | head -5 \
            | while read -r count hook; do
                echo "    $hook: $count"
            done

        LAST_EVENT_TS=$(grep "\"project\":\"$PROJ_HASH\"" "$EVENT_LOG" | tail -1 | jq -r '.ts' 2>/dev/null)
        [ -n "$LAST_EVENT_TS" ] && echo -e "  Last event:         ${DIM}$LAST_EVENT_TS${NC}"
    fi
else
    echo -e "  ${DIM}No event log (events.jsonl)${NC}"
fi
echo ""

echo -e "${DIM}Report generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)${NC}"
