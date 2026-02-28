#!/bin/bash
# tools/cockpit.sh — compact operational dashboard for bestAI
# Usage: bash tools/cockpit.sh [project-dir] [--watch 5] [--json]

set -euo pipefail

TARGET="${1:-.}"
WATCH=0
JSON_MODE=0

if [ "${TARGET#--}" != "$TARGET" ]; then
    TARGET="."
fi

ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
    case "${ARGS[$i]}" in
        --watch)
            WATCH="${ARGS[$((i+1))]:-5}"
            ;;
        --json)
            JSON_MODE=1
            ;;
    esac
done

if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required" >&2
    exit 1
fi

PROJECT_DIR="$(cd "$TARGET" && pwd)"
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
EVENT_LOG="${BESTAI_EVENT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/bestai/events.jsonl}"
ROUTE_LOG="$PROJECT_DIR/.bestai/router-decisions.jsonl"
GPS_FILE="$PROJECT_DIR/.bestai/GPS.json"
USAGE_JSONL="${BESTAI_USAGE_LOG:-$HOME/.claude/projects/$PROJECT_KEY/cache-usage.jsonl}"
TOKEN_LIMIT="${BESTAI_TOKEN_LIMIT:-1000000}"

project_hash() {
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$PROJECT_DIR" | md5sum | awk '{print substr($1,1,16)}'
    else
        printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}'
    fi
}

sanitize_number() {
    local raw="$1"
    raw=$(printf '%s\n' "$raw" | head -n1 | tr -cd '0-9')
    [ -n "$raw" ] || raw=0
    printf '%s' "$raw"
}

render_once() {
    local proj_hash total_events blocks allows memory_files user_files active_tasks blockers milestones_total milestones_done total_input total_output total_tokens route_vendor route_depth route_ts

    proj_hash=$(project_hash)

    total_events=0
    blocks=0
    allows=0
    if [ -f "$EVENT_LOG" ]; then
        total_events=$(grep -c "\"project\":\"$proj_hash\"" "$EVENT_LOG" 2>/dev/null || true)
        blocks=$(grep "\"project\":\"$proj_hash\"" "$EVENT_LOG" 2>/dev/null | grep -c '"action":"BLOCK"' || true)
        allows=$(grep "\"project\":\"$proj_hash\"" "$EVENT_LOG" 2>/dev/null | grep -c '"action":"ALLOW"' || true)
    fi
    total_events=$(sanitize_number "$total_events")
    blocks=$(sanitize_number "$blocks")
    allows=$(sanitize_number "$allows")

    memory_files=0
    user_files=0
    if [ -d "$MEMORY_DIR" ]; then
        memory_files=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        user_files=$(grep -l '\[USER\]' "$MEMORY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    fi

    active_tasks=0
    blockers=0
    milestones_total=0
    milestones_done=0
    if [ -f "$GPS_FILE" ]; then
        active_tasks=$(jq '.active_tasks | length' "$GPS_FILE" 2>/dev/null || echo 0)
        blockers=$(jq '.blockers | length' "$GPS_FILE" 2>/dev/null || echo 0)
        milestones_total=$(jq '.milestones | length' "$GPS_FILE" 2>/dev/null || echo 0)
        milestones_done=$(jq '[.milestones[] | select(.status=="completed")] | length' "$GPS_FILE" 2>/dev/null || echo 0)
    fi

    total_input=0
    total_output=0
    total_tokens=0
    if [ -f "$USAGE_JSONL" ]; then
        total_input=$(jq -s 'map(.usage.input_tokens // .input_tokens // 0 | tonumber) | add // 0' "$USAGE_JSONL" 2>/dev/null || echo 0)
        total_output=$(jq -s 'map(.usage.output_tokens // .output_tokens // 0 | tonumber) | add // 0' "$USAGE_JSONL" 2>/dev/null || echo 0)
        total_tokens=$((total_input + total_output))
    fi

    route_vendor="-"
    route_depth="-"
    route_ts="-"
    if [ -f "$ROUTE_LOG" ]; then
        route_vendor=$(tail -n 1 "$ROUTE_LOG" | jq -r '.vendor // "-"' 2>/dev/null || echo "-")
        route_depth=$(tail -n 1 "$ROUTE_LOG" | jq -r '.depth // "-"' 2>/dev/null || echo "-")
        route_ts=$(tail -n 1 "$ROUTE_LOG" | jq -r '.ts // "-"' 2>/dev/null || echo "-")
    fi

    if [ "$JSON_MODE" -eq 1 ]; then
        jq -cn \
            --arg project "$(basename "$PROJECT_DIR")" \
            --arg project_dir "$PROJECT_DIR" \
            --arg proj_hash "$proj_hash" \
            --argjson total_events "$total_events" \
            --argjson blocks "$blocks" \
            --argjson allows "$allows" \
            --argjson memory_files "$memory_files" \
            --argjson user_files "$user_files" \
            --argjson active_tasks "$active_tasks" \
            --argjson blockers "$blockers" \
            --argjson milestones_total "$milestones_total" \
            --argjson milestones_done "$milestones_done" \
            --argjson total_input "$total_input" \
            --argjson total_output "$total_output" \
            --argjson total_tokens "$total_tokens" \
            --argjson token_limit "$TOKEN_LIMIT" \
            --arg route_vendor "$route_vendor" \
            --arg route_depth "$route_depth" \
            --arg route_ts "$route_ts" \
            '{
              project:{name:$project,dir:$project_dir,hash:$proj_hash},
              events:{total:$total_events,blocks:$blocks,allows:$allows},
              knowledge:{memory_files:$memory_files,user_tagged_files:$user_files},
              tasks:{active:$active_tasks,blockers:$blockers,milestones_done:$milestones_done,milestones_total:$milestones_total},
              usage:{input_tokens:$total_input,output_tokens:$total_output,total_tokens:$total_tokens,limit_tokens:$token_limit},
              routing:{last_vendor:$route_vendor,last_depth:$route_depth,last_ts:$route_ts}
            }'
    else
        echo "bestAI cockpit — $(basename "$PROJECT_DIR")"
        echo "========================================"
        echo "events: total=$total_events allow=$allows block=$blocks"
        echo "knowledge: files=$memory_files user_tagged=$user_files"
        echo "tasks: active=$active_tasks blockers=$blockers milestones=$milestones_done/$milestones_total"
        if [ -f "$USAGE_JSONL" ]; then
            pct=0
            if [ "$TOKEN_LIMIT" -gt 0 ]; then
                pct=$(( (total_tokens * 100) / TOKEN_LIMIT ))
            fi
            echo "usage: input=$total_input output=$total_output total=$total_tokens/$TOKEN_LIMIT (${pct}%)"
        else
            echo "usage: n/a (set BESTAI_USAGE_LOG or provide usage jsonl)"
        fi
        echo "routing(last): vendor=$route_vendor depth=$route_depth ts=$route_ts"
        echo "sources:"
        echo "  event_log=$EVENT_LOG"
        echo "  gps=$GPS_FILE"
        echo "  route_log=$ROUTE_LOG"
        echo "  usage_log=$USAGE_JSONL"
    fi
}

if [ "$WATCH" -gt 0 ] && [ "$JSON_MODE" -eq 0 ]; then
    while true; do
        clear
        render_once
        sleep "$WATCH"
    done
else
    render_once
fi
