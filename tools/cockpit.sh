#!/bin/bash
# tools/cockpit.sh — compact operational dashboard for bestAI
# Usage: bash tools/cockpit.sh [project-dir] [--watch 5] [--json] [--compact]

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bestai cockpit [project-dir] [--watch N] [--json] [--compact]

Options:
  --watch N   Refresh every N seconds (text mode only)
  --json      Emit JSON payload
  --compact   Print short human-readable output
  -h, --help  Show this help
EOF
}

TARGET="."
WATCH=0
JSON_MODE=0
COMPACT_MODE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --watch)
            [ "$#" -ge 2 ] || { echo "Error: missing value for --watch" >&2; exit 1; }
            WATCH="${2:-0}"
            shift 2
            ;;
        --json)
            JSON_MODE=1
            shift
            ;;
        --compact)
            COMPACT_MODE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            echo "Error: unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

case "$WATCH" in
    ''|*[!0-9]*)
        echo "Error: --watch must be an integer >= 0" >&2
        exit 1
        ;;
esac

if [ "$JSON_MODE" -eq 1 ] && [ "$WATCH" -gt 0 ]; then
    echo "Error: --watch is not supported with --json" >&2
    exit 1
fi

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

# Source canonical _bestai_project_hash from hook-event.sh
_COCKPIT_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/hook-event.sh
source "$_COCKPIT_SCRIPT_DIR/../hooks/hook-event.sh" 2>/dev/null || {
    _bestai_project_hash() {
        local src="${1:-.}"
        printf '%s' "$src" | md5sum 2>/dev/null | awk '{print substr($1,1,16)}' || printf '%s' "$src" | cksum | awk '{print $1}'
    }
}

project_hash() {
    _bestai_project_hash "$PROJECT_DIR"
}

sanitize_number() {
    local raw="$1"
    raw=$(printf '%s\n' "$raw" | head -n1 | tr -cd '0-9')
    [ -n "$raw" ] || raw=0
    printf '%s' "$raw"
}

percent() {
    local numerator="$1"
    local denominator="$2"
    if [ "$denominator" -gt 0 ]; then
        printf '%s' $(( (numerator * 100) / denominator ))
    else
        printf '0'
    fi
}

render_once() {
    local proj_hash total_events blocks allows block_ratio_pct
    local memory_files user_files
    local active_tasks blockers milestones_total milestones_done
    local total_input total_output total_tokens token_usage_pct_json token_usage_pct
    local route_vendor route_depth route_ts route_total
    local route_vendor_breakdown route_depth_breakdown vendors_human depths_human
    local health_status health_notes_json usage_human
    local project_name objective
    local notes=()

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
    block_ratio_pct=$(percent "$blocks" "$total_events")

    memory_files=0
    user_files=0
    if [ -d "$MEMORY_DIR" ]; then
        memory_files=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        user_files=$(grep -l '\[USER\]' "$MEMORY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    fi
    memory_files=$(sanitize_number "$memory_files")
    user_files=$(sanitize_number "$user_files")

    active_tasks=0
    blockers=0
    milestones_total=0
    milestones_done=0
    project_name="$(basename "$PROJECT_DIR")"
    objective=""
    if [ -f "$GPS_FILE" ]; then
        active_tasks=$(jq '.active_tasks | length' "$GPS_FILE" 2>/dev/null || echo 0)
        blockers=$(jq '.blockers | length' "$GPS_FILE" 2>/dev/null || echo 0)
        milestones_total=$(jq '.milestones | length' "$GPS_FILE" 2>/dev/null || echo 0)
        milestones_done=$(jq '[.milestones[] | select(.status=="completed")] | length' "$GPS_FILE" 2>/dev/null || echo 0)
        project_name=$(jq -r '.project.name // empty' "$GPS_FILE" 2>/dev/null || echo "$project_name")
        objective=$(jq -r '.project.main_objective // empty' "$GPS_FILE" 2>/dev/null || echo "")
        [ -n "$project_name" ] || project_name="$(basename "$PROJECT_DIR")"
    fi
    active_tasks=$(sanitize_number "$active_tasks")
    blockers=$(sanitize_number "$blockers")
    milestones_total=$(sanitize_number "$milestones_total")
    milestones_done=$(sanitize_number "$milestones_done")

    total_input=0
    total_output=0
    total_tokens=0
    token_usage_pct_json="null"
    token_usage_pct=0
    usage_human="n/a"
    if [ -f "$USAGE_JSONL" ]; then
        total_input=$(jq -s 'map(.usage.input_tokens // .input_tokens // 0 | tonumber) | add // 0' "$USAGE_JSONL" 2>/dev/null || echo 0)
        total_output=$(jq -s 'map(.usage.output_tokens // .output_tokens // 0 | tonumber) | add // 0' "$USAGE_JSONL" 2>/dev/null || echo 0)
        total_input=$(sanitize_number "$total_input")
        total_output=$(sanitize_number "$total_output")
        total_tokens=$((total_input + total_output))
        if [ "$TOKEN_LIMIT" -gt 0 ]; then
            token_usage_pct=$(percent "$total_tokens" "$TOKEN_LIMIT")
            token_usage_pct_json="$token_usage_pct"
            usage_human="$total_tokens/$TOKEN_LIMIT (${token_usage_pct}%)"
        else
            usage_human="$total_tokens"
        fi
    fi

    route_vendor="-"
    route_depth="-"
    route_ts="-"
    route_total=0
    route_vendor_breakdown='[]'
    route_depth_breakdown='[]'
    if [ -f "$ROUTE_LOG" ]; then
        route_vendor=$(tail -n 1 "$ROUTE_LOG" | jq -r '.vendor // .route.vendor // "-"' 2>/dev/null || echo "-")
        route_depth=$(tail -n 1 "$ROUTE_LOG" | jq -r '.depth // .route.depth // "-"' 2>/dev/null || echo "-")
        route_ts=$(tail -n 1 "$ROUTE_LOG" | jq -r '.ts // .route.ts // "-"' 2>/dev/null || echo "-")
        route_total=$(jq -s 'length' "$ROUTE_LOG" 2>/dev/null || echo 0)
        route_vendor_breakdown=$(jq -cs '
            map({vendor:(.vendor // .route.vendor // "unknown")})
            | group_by(.vendor)
            | map({vendor:.[0].vendor,count:length})
            | sort_by(-.count)' "$ROUTE_LOG" 2>/dev/null || echo '[]')
        route_depth_breakdown=$(jq -cs '
            map({depth:(.depth // .route.depth // "unknown")})
            | group_by(.depth)
            | map({depth:.[0].depth,count:length})
            | sort_by(-.count)' "$ROUTE_LOG" 2>/dev/null || echo '[]')
    fi
    route_total=$(sanitize_number "$route_total")
    vendors_human=$(printf '%s' "$route_vendor_breakdown" | jq -r 'if length==0 then "-" else map("\(.vendor)=\(.count)") | join(", ") end' 2>/dev/null || echo "-")
    depths_human=$(printf '%s' "$route_depth_breakdown" | jq -r 'if length==0 then "-" else map("\(.depth)=\(.count)") | join(", ") end' 2>/dev/null || echo "-")

    health_status="PASS"
    if [ "$total_events" -gt 0 ] && [ "$block_ratio_pct" -ge 30 ]; then
        health_status="WARN"
        notes+=("high_block_ratio")
    fi
    if [ "$token_usage_pct_json" != "null" ] && [ "$token_usage_pct" -ge 85 ]; then
        health_status="WARN"
        notes+=("token_budget_high")
    fi
    if [ "$route_total" -eq 0 ]; then
        notes+=("routing_history_empty")
    fi

    if [ "${#notes[@]}" -gt 0 ]; then
        health_notes_json=$(printf '%s\n' "${notes[@]}" | jq -R . | jq -s .)
    else
        health_notes_json='["ok"]'
    fi

    if [ "$JSON_MODE" -eq 1 ]; then
        jq -cn \
            --arg project "$project_name" \
            --arg project_dir "$PROJECT_DIR" \
            --arg proj_hash "$proj_hash" \
            --arg objective "$objective" \
            --argjson total_events "$total_events" \
            --argjson blocks "$blocks" \
            --argjson allows "$allows" \
            --argjson block_ratio_pct "$block_ratio_pct" \
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
            --argjson token_usage_pct "$token_usage_pct_json" \
            --arg route_vendor "$route_vendor" \
            --arg route_depth "$route_depth" \
            --arg route_ts "$route_ts" \
            --argjson route_total "$route_total" \
            --argjson route_vendors "$route_vendor_breakdown" \
            --argjson route_depths "$route_depth_breakdown" \
            --arg health_status "$health_status" \
            --argjson health_notes "$health_notes_json" \
            '{
              project:{name:$project,objective:$objective,dir:$project_dir,hash:$proj_hash},
              events:{total:$total_events,blocks:$blocks,allows:$allows,block_ratio_pct:$block_ratio_pct},
              knowledge:{memory_files:$memory_files,user_tagged_files:$user_files},
              tasks:{active:$active_tasks,blockers:$blockers,milestones_done:$milestones_done,milestones_total:$milestones_total},
              usage:{input_tokens:$total_input,output_tokens:$total_output,total_tokens:$total_tokens,limit_tokens:$token_limit,usage_pct:$token_usage_pct},
              routing:{last_vendor:$route_vendor,last_depth:$route_depth,last_ts:$route_ts,total_decisions:$route_total,vendors:$route_vendors,depths:$route_depths},
              health:{status:$health_status,notes:$health_notes}
            }'
    elif [ "$COMPACT_MODE" -eq 1 ]; then
        echo "bestAI cockpit — ${project_name} [compact]"
        echo "health: $health_status | events.block=$blocks/$total_events (${block_ratio_pct}%) | usage=$usage_human | routing=$route_vendor/$route_depth"
        echo "tasks: active=$active_tasks blockers=$blockers milestones=$milestones_done/$milestones_total"
        echo "routing.vendors: $vendors_human"
    else
        echo "bestAI cockpit — ${project_name}"
        echo "========================================"
        if [ -n "$objective" ]; then
            echo "objective: $objective"
        fi
        echo "health: status=$health_status notes=$(printf '%s' "$health_notes_json" | jq -cr '.')"
        echo "events: total=$total_events allow=$allows block=$blocks (${block_ratio_pct}% blocked)"
        echo "knowledge: files=$memory_files user_tagged=$user_files"
        echo "tasks: active=$active_tasks blockers=$blockers milestones=$milestones_done/$milestones_total"
        echo "usage: $usage_human"
        echo "routing(last): vendor=$route_vendor depth=$route_depth ts=$route_ts"
        echo "routing(vendors): $vendors_human"
        echo "routing(depths): $depths_human"
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
