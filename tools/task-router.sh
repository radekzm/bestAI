#!/bin/bash
# tools/task-router.sh — Adaptive task routing (vendor + analysis depth)
# Usage: bash tools/task-router.sh --task "..." [--project-dir .] [--json]

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 1
fi

TASK=""
PROJECT_DIR="."
JSON_MODE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task)
            [ "$#" -ge 2 ] || { echo "Missing value for --task" >&2; exit 1; }
            TASK="$2"
            shift 2
            ;;
        --project-dir)
            [ "$#" -ge 2 ] || { echo "Missing value for --project-dir" >&2; exit 1; }
            PROJECT_DIR="$2"
            shift 2
            ;;
        --json)
            JSON_MODE=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task 'description' [--project-dir .] [--json]" >&2
    exit 1
fi

normalize_task() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs '[:alnum:]' ' ' \
        | sed -e 's/^ *//' -e 's/ *$//' -e 's/  */ /g'
}

# Source canonical _bestai_project_hash from hook-event.sh
_ROUTER_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/hook-event.sh
source "$_ROUTER_SCRIPT_DIR/../hooks/hook-event.sh" 2>/dev/null || {
    _bestai_project_hash() {
        local src="${1:-.}"
        printf '%s' "$src" | md5sum 2>/dev/null | awk '{print substr($1,1,16)}' || printf '%s' "$src" | cksum | awk '{print $1}'
    }
}

bestai_hash_path() {
    _bestai_project_hash "$1"
}

valid_vendor() {
    case "$1" in
        claude|gemini|codex) return 0 ;;
        *) return 1 ;;
    esac
}

valid_depth() {
    case "$1" in
        fast|balanced|deep) return 0 ;;
        *) return 1 ;;
    esac
}

read_route_history() {
    local route_file="$1"
    local task_norm="$2"
    local complexity="$3"
    local window="$4"

    if [ ! -f "$route_file" ]; then
        echo '{"total":0,"same_task_count":0,"same_task_vendor":"","same_task_depth":"","same_task_avg_confidence":0,"complexity_count":0,"complexity_vendor":"","complexity_depth":"","vendor_switch_pct":0,"recent_vendor":"","recent_depth":""}'
        return 0
    fi

    tail -n "$window" "$route_file" 2>/dev/null | jq -Rsc --arg task_norm "$task_norm" --arg complexity "$complexity" '
        def norm_task:
            ((. // "") | ascii_downcase | gsub("[^a-z0-9]+"; " ") | gsub("^ +| +$"; ""));
        def top_value(arr; key):
            if (arr | length) == 0 then ""
            else (
                arr
                | map(.[key] // "unknown")
                | group_by(.)
                | map({value: .[0], count: length})
                | sort_by(.count)
                | last
                | .value
            )
            end;
        (split("\n") | map(fromjson?) | map(select(type == "object"))) as $rows
        | ($rows | map(select(((.task // "") | norm_task) == $task_norm))) as $same
        | ($rows | map(select((.complexity // "") == $complexity))) as $cx
        | ($rows | map(.vendor // "")) as $vendors
        | (if ($vendors | length) > 1
           then reduce range(1; ($vendors | length)) as $i (0;
                  . + (if $vendors[$i] != $vendors[$i - 1] then 1 else 0 end))
           else 0 end) as $switches
        | {
            total: ($rows | length),
            same_task_count: ($same | length),
            same_task_vendor: top_value($same; "vendor"),
            same_task_depth: top_value($same; "depth"),
            same_task_avg_confidence: (if ($same | length) > 0 then (((($same | map((.confidence // 0) | tonumber) | add) / ($same | length)) | floor)) else 0 end),
            complexity_count: ($cx | length),
            complexity_vendor: top_value($cx; "vendor"),
            complexity_depth: top_value($cx; "depth"),
            vendor_switch_pct: (if ($vendors | length) > 1 then ((($switches * 100) / (($vendors | length) - 1)) | floor) else 0 end),
            recent_vendor: (($rows | last | .vendor) // ""),
            recent_depth: (($rows | last | .depth) // "")
          }' \
        || echo '{"total":0,"same_task_count":0,"same_task_vendor":"","same_task_depth":"","same_task_avg_confidence":0,"complexity_count":0,"complexity_vendor":"","complexity_depth":"","vendor_switch_pct":0,"recent_vendor":"","recent_depth":""}'
}

read_event_signal() {
    local event_file="$1"
    local project_hash_raw="$2"
    local project_hash_abs="$3"
    local window="$4"

    if [ ! -f "$event_file" ]; then
        echo '{"total":0,"block_like":0,"allow_like":0,"block_pct":0,"open_events":0,"error_events":0}'
        return 0
    fi

    tail -n "$window" "$event_file" 2>/dev/null | jq -Rsc --arg hash_raw "$project_hash_raw" --arg hash_abs "$project_hash_abs" '
        (split("\n")
         | map(fromjson?)
         | map(select(type == "object"
                      and (((.project // "") == $hash_raw) or ((.project // "") == $hash_abs))))) as $rows
        | ($rows | map(select((.action // "") == "BLOCK"
                              or (.action // "") == "OPEN"
                              or (.action // "") == "ERROR")) | length) as $block_like
        | ($rows | map(select((.action // "") == "ALLOW")) | length) as $allow_like
        | {
            total: ($rows | length),
            block_like: $block_like,
            allow_like: $allow_like,
            block_pct: (if ($rows | length) > 0 then ((($block_like * 100) / ($rows | length)) | floor) else 0 end),
            open_events: ($rows | map(select((.action // "") == "OPEN")) | length),
            error_events: ($rows | map(select((.action // "") == "ERROR")) | length)
          }' \
        || echo '{"total":0,"block_like":0,"allow_like":0,"block_pct":0,"open_events":0,"error_events":0}'
}

add_reason() {
    local code="$1"
    local existing=""
    for existing in "${reasons[@]}"; do
        if [ "$existing" = "$code" ]; then
            return 0
        fi
    done
    reasons+=("$code")
}

ROUTER_POLICY="${BESTAI_ROUTER_POLICY:-balanced}"
ROUTE_HISTORY_WINDOW="${BESTAI_ROUTE_HISTORY_WINDOW:-240}"
EVENT_HISTORY_WINDOW="${BESTAI_EVENT_WINDOW:-2000}"

case "$ROUTE_HISTORY_WINDOW" in
    ''|*[!0-9]*) ROUTE_HISTORY_WINDOW=240 ;;
esac
case "$EVENT_HISTORY_WINDOW" in
    ''|*[!0-9]*) EVENT_HISTORY_WINDOW=2000 ;;
esac

NORMALIZED=$(normalize_task "$TASK")
if [ -n "$NORMALIZED" ]; then
    WORDS=$(printf '%s\n' "$NORMALIZED" | wc -w | tr -d ' ')
else
    WORDS=0
fi

complexity_score=0
complexity="simple"
depth="fast"
vendor="gemini"
scaffold_hit=0
reasons=()

if [ "$WORDS" -gt 18 ]; then
    complexity_score=$((complexity_score + 1))
    add_reason "H_WORDS_GT_18"
fi
if [ "$WORDS" -gt 35 ]; then
    complexity_score=$((complexity_score + 2))
    add_reason "H_WORDS_GT_35"
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(architekt|architecture|security|threat|refactor|migration|incident|root cause|critical|krytycz|interoperab|multi[- ]vendor|schema|contract)'; then
    complexity_score=$((complexity_score + 3))
    add_reason "H_COMPLEX_KEYWORDS"
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(debug|fix|napraw|test|optimiz|benchmark|profil|lint|compliance)'; then
    complexity_score=$((complexity_score + 1))
    add_reason "H_MEDIUM_KEYWORDS"
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(scan|find|list|inventory|grep|map|przeskan|research)'; then
    complexity_score=$((complexity_score + 1))
    add_reason "H_DISCOVERY_KEYWORDS"
fi

if [ "$complexity_score" -ge 4 ]; then
    complexity="complex"
    depth="deep"
elif [ "$complexity_score" -ge 2 ]; then
    complexity="medium"
    depth="balanced"
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(boilerplate|stub|scaffold|test case|unit test generation|snapshot)'; then
    scaffold_hit=1
    add_reason "H_SCAFFOLD_KEYWORDS"
fi

if [ "$complexity" = "complex" ]; then
    vendor="claude"
    add_reason "H_COMPLEX_PREFERS_CLAUDE"
elif [ "$scaffold_hit" -eq 1 ]; then
    vendor="codex"
    add_reason "H_SCAFFOLD_PREFERS_CODEX"
else
    vendor="gemini"
    add_reason "H_DEFAULT_GEMINI"
fi

if [ "$vendor" = "gemini" ] && [ "$depth" = "deep" ]; then
    vendor="claude"
    add_reason "H_DEEP_PREFERS_CLAUDE"
fi

if PROJECT_DIR_ABS=$(cd "$PROJECT_DIR" 2>/dev/null && pwd); then
    :
else
    PROJECT_DIR_ABS="$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR/.bestai"
ROUTE_LOG="$PROJECT_DIR/.bestai/router-decisions.jsonl"
EVENT_LOG="${BESTAI_EVENT_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/bestai/events.jsonl}"

PROJECT_HASH_RAW=$(bestai_hash_path "$PROJECT_DIR")
PROJECT_HASH_ABS=$(bestai_hash_path "$PROJECT_DIR_ABS")

history_json=$(read_route_history "$ROUTE_LOG" "$NORMALIZED" "$complexity" "$ROUTE_HISTORY_WINDOW")
event_json=$(read_event_signal "$EVENT_LOG" "$PROJECT_HASH_RAW" "$PROJECT_HASH_ABS" "$EVENT_HISTORY_WINDOW")

mapfile -t history_values < <(printf '%s' "$history_json" | jq -r '
    .total,
    .same_task_count,
    .same_task_vendor,
    .same_task_depth,
    .same_task_avg_confidence,
    .complexity_count,
    .complexity_vendor,
    .complexity_depth,
    .vendor_switch_pct,
    .recent_vendor,
    .recent_depth
')
HISTORY_TOTAL="${history_values[0]:-0}"
HISTORY_SAME_TASK_COUNT="${history_values[1]:-0}"
HISTORY_SAME_TASK_VENDOR="${history_values[2]:-}"
HISTORY_SAME_TASK_DEPTH="${history_values[3]:-}"
HISTORY_SAME_TASK_AVG_CONFIDENCE="${history_values[4]:-0}"
HISTORY_COMPLEXITY_COUNT="${history_values[5]:-0}"
HISTORY_COMPLEXITY_VENDOR="${history_values[6]:-}"
HISTORY_COMPLEXITY_DEPTH="${history_values[7]:-}"
HISTORY_VENDOR_SWITCH_PCT="${history_values[8]:-0}"
HISTORY_RECENT_VENDOR="${history_values[9]:-}"
HISTORY_RECENT_DEPTH="${history_values[10]:-}"

mapfile -t event_values < <(printf '%s' "$event_json" | jq -r '
    .total,
    .block_like,
    .allow_like,
    .block_pct,
    .open_events,
    .error_events
')
EVENT_TOTAL="${event_values[0]:-0}"
EVENT_BLOCK_LIKE="${event_values[1]:-0}"
EVENT_ALLOW_LIKE="${event_values[2]:-0}"
EVENT_BLOCK_PCT="${event_values[3]:-0}"
EVENT_OPEN_EVENTS="${event_values[4]:-0}"
EVENT_ERROR_EVENTS="${event_values[5]:-0}"

if [ "$HISTORY_SAME_TASK_COUNT" -ge 2 ]; then
    if valid_vendor "$HISTORY_SAME_TASK_VENDOR" && [ "$HISTORY_SAME_TASK_VENDOR" != "unknown" ]; then
        if [ "$vendor" != "$HISTORY_SAME_TASK_VENDOR" ]; then
            vendor="$HISTORY_SAME_TASK_VENDOR"
            add_reason "HX_SAME_TASK_VENDOR"
        fi
    fi
    if valid_depth "$HISTORY_SAME_TASK_DEPTH" && [ "$HISTORY_SAME_TASK_DEPTH" != "unknown" ]; then
        if [ "$depth" != "$HISTORY_SAME_TASK_DEPTH" ]; then
            depth="$HISTORY_SAME_TASK_DEPTH"
            add_reason "HX_SAME_TASK_DEPTH"
        fi
    fi
elif [ "$HISTORY_COMPLEXITY_COUNT" -ge 4 ]; then
    if valid_vendor "$HISTORY_COMPLEXITY_VENDOR" && [ "$HISTORY_COMPLEXITY_VENDOR" != "unknown" ]; then
        if [ "$vendor" != "$HISTORY_COMPLEXITY_VENDOR" ]; then
            vendor="$HISTORY_COMPLEXITY_VENDOR"
            add_reason "HX_COMPLEXITY_VENDOR"
        fi
    fi
    if valid_depth "$HISTORY_COMPLEXITY_DEPTH" && [ "$HISTORY_COMPLEXITY_DEPTH" != "unknown" ]; then
        if [ "$depth" != "$HISTORY_COMPLEXITY_DEPTH" ]; then
            depth="$HISTORY_COMPLEXITY_DEPTH"
            add_reason "HX_COMPLEXITY_DEPTH"
        fi
    fi
else
    add_reason "HX_HISTORY_SPARSE"
fi

if [ "$HISTORY_TOTAL" -ge 6 ] && [ "$HISTORY_VENDOR_SWITCH_PCT" -ge 60 ]; then
    add_reason "HX_VENDOR_CHURN_HIGH"
fi

if [ "$EVENT_TOTAL" -ge 8 ]; then
    if [ "$EVENT_BLOCK_PCT" -ge 35 ]; then
        if [ "$vendor" != "claude" ]; then
            vendor="claude"
        fi
        if [ "$depth" = "fast" ]; then
            depth="balanced"
        fi
        add_reason "EV_BLOCK_RATIO_HIGH"
    elif [ "$EVENT_BLOCK_PCT" -le 10 ]; then
        add_reason "EV_BLOCK_RATIO_LOW"
    else
        add_reason "EV_BLOCK_RATIO_MID"
    fi
else
    add_reason "EV_SIGNAL_SPARSE"
fi

confidence=58
case "$complexity" in
    simple) confidence=$((confidence + 6)) ;;
    medium) confidence=$((confidence + 16)) ;;
    complex) confidence=$((confidence + 24)) ;;
esac

if [ "$HISTORY_TOTAL" -eq 0 ]; then
    confidence=$((confidence - 6))
fi
if [ "$HISTORY_SAME_TASK_COUNT" -ge 1 ]; then
    confidence=$((confidence + 8))
fi
if [ "$HISTORY_SAME_TASK_COUNT" -ge 3 ]; then
    confidence=$((confidence + 5))
fi
if [ "$HISTORY_COMPLEXITY_COUNT" -ge 4 ]; then
    confidence=$((confidence + 4))
fi
if [ "$HISTORY_SAME_TASK_COUNT" -ge 2 ] && [ "$HISTORY_SAME_TASK_AVG_CONFIDENCE" -lt 65 ]; then
    confidence=$((confidence - 5))
    add_reason "HX_SAME_TASK_LOW_CONFIDENCE"
fi
if [ "$HISTORY_TOTAL" -ge 6 ] && [ "$HISTORY_VENDOR_SWITCH_PCT" -ge 60 ]; then
    confidence=$((confidence - 4))
fi

if [ "$EVENT_TOTAL" -ge 20 ]; then
    confidence=$((confidence + 4))
elif [ "$EVENT_TOTAL" -eq 0 ]; then
    confidence=$((confidence - 2))
fi

if [ "$EVENT_BLOCK_PCT" -ge 35 ]; then
    confidence=$((confidence - 12))
elif [ "$EVENT_BLOCK_PCT" -ge 20 ]; then
    confidence=$((confidence - 6))
fi

policy_applied=0
fallback_triggered=0
if [ "$confidence" -lt 75 ] || [ "$HISTORY_TOTAL" -lt 3 ] || [ "$EVENT_TOTAL" -lt 8 ]; then
    fallback_triggered=1
fi

case "$ROUTER_POLICY" in
    prefer_fast|prefer_reliability|balanced) ;;
    *)
        ROUTER_POLICY="balanced"
        add_reason "POLICY_INVALID_DEFAULT_BALANCED"
        ;;
esac

if [ "$ROUTER_POLICY" != "balanced" ] && [ "$fallback_triggered" -eq 1 ]; then
    policy_applied=1
    add_reason "POLICY_FALLBACK_TRIGGERED"
    case "$ROUTER_POLICY" in
        prefer_fast)
            add_reason "POLICY_PREFER_FAST"
            if [ "$complexity" = "simple" ]; then
                depth="fast"
            elif [ "$complexity" = "medium" ] && [ "$EVENT_BLOCK_PCT" -le 25 ]; then
                depth="fast"
            fi
            if [ "$vendor" = "claude" ] && [ "$complexity" != "complex" ] && [ "$EVENT_BLOCK_PCT" -le 25 ]; then
                vendor="gemini"
            fi
            ;;
        prefer_reliability)
            add_reason "POLICY_PREFER_RELIABILITY"
            if [ "$vendor" = "gemini" ] || [ "$vendor" = "codex" ]; then
                vendor="claude"
            fi
            if [ "$depth" = "fast" ]; then
                depth="balanced"
            fi
            if [ "$complexity" = "complex" ] || [ "$EVENT_BLOCK_PCT" -ge 25 ]; then
                depth="deep"
            fi
            ;;
    esac
fi

if ! valid_vendor "$vendor"; then
    vendor="claude"
    add_reason "SAFE_VENDOR_DEFAULTED"
    confidence=$((confidence - 4))
fi

if ! valid_depth "$depth"; then
    depth="balanced"
    add_reason "SAFE_DEPTH_DEFAULTED"
    confidence=$((confidence - 2))
fi

if [ "$policy_applied" -eq 1 ]; then
    confidence=$((confidence - 3))
fi

if [ "$confidence" -lt 35 ]; then
    confidence=35
fi
if [ "$confidence" -gt 95 ]; then
    confidence=95
fi

reasons_json='[]'
if [ "${#reasons[@]}" -gt 0 ]; then
    reasons_json=$(printf '%s\n' "${reasons[@]}" | jq -R . | jq -s .)
fi

history_out=$(jq -cn \
    --argjson total "$HISTORY_TOTAL" \
    --argjson same_task_count "$HISTORY_SAME_TASK_COUNT" \
    --arg same_task_vendor "$HISTORY_SAME_TASK_VENDOR" \
    --arg same_task_depth "$HISTORY_SAME_TASK_DEPTH" \
    --argjson same_task_avg_confidence "$HISTORY_SAME_TASK_AVG_CONFIDENCE" \
    --argjson complexity_count "$HISTORY_COMPLEXITY_COUNT" \
    --arg complexity_vendor "$HISTORY_COMPLEXITY_VENDOR" \
    --arg complexity_depth "$HISTORY_COMPLEXITY_DEPTH" \
    --argjson vendor_switch_pct "$HISTORY_VENDOR_SWITCH_PCT" \
    '{total:$total,same_task_count:$same_task_count,same_task_vendor:$same_task_vendor,same_task_depth:$same_task_depth,same_task_avg_confidence:$same_task_avg_confidence,complexity_count:$complexity_count,complexity_vendor:$complexity_vendor,complexity_depth:$complexity_depth,vendor_switch_pct:$vendor_switch_pct}')

event_out=$(jq -cn \
    --argjson total "$EVENT_TOTAL" \
    --argjson block_like "$EVENT_BLOCK_LIKE" \
    --argjson allow_like "$EVENT_ALLOW_LIKE" \
    --argjson block_pct "$EVENT_BLOCK_PCT" \
    --argjson open_events "$EVENT_OPEN_EVENTS" \
    --argjson error_events "$EVENT_ERROR_EVENTS" \
    '{total:$total,block_like:$block_like,allow_like:$allow_like,block_pct:$block_pct,open_events:$open_events,error_events:$error_events}')

policy_out=$(jq -cn \
    --arg mode "$ROUTER_POLICY" \
    --argjson fallback_triggered "$fallback_triggered" \
    --argjson fallback_applied "$policy_applied" \
    '{mode:$mode,fallback_triggered:$fallback_triggered,fallback_applied:$fallback_applied}')

route_json=$(jq -cn \
    --arg task "$TASK" \
    --arg complexity "$complexity" \
    --arg depth "$depth" \
    --arg vendor "$vendor" \
    --argjson confidence "$confidence" \
    --argjson score "$complexity_score" \
    --argjson reasons "$reasons_json" \
    --argjson history "$history_out" \
    --argjson event_signal "$event_out" \
    --argjson policy "$policy_out" \
    '{task:$task,complexity:$complexity,depth:$depth,vendor:$vendor,confidence:$confidence,score:$score,reasons:$reasons,history:$history,event_signal:$event_signal,policy:$policy}')

if [ "$JSON_MODE" -eq 1 ]; then
    printf '%s\n' "$route_json"
else
    echo "routing.vendor=$vendor"
    echo "routing.depth=$depth"
    echo "routing.complexity=$complexity"
    echo "routing.confidence=$confidence"
    echo "routing.score=$complexity_score"
    echo "routing.policy=$ROUTER_POLICY"
    if [ "${#reasons[@]}" -gt 0 ]; then
        echo "routing.reasons=$(IFS=,; echo "${reasons[*]}")"
    fi
fi

jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson route "$route_json" \
    '$route + {ts:$ts}' \
    >> "$ROUTE_LOG" 2>/dev/null || true
