#!/bin/bash
# tools/task-memory-binding.sh — build binding context from project history/memory
# Usage: bash tools/task-memory-binding.sh --task "..." [--project-dir .] [--max-files 3] [--max-lines 12] [--json]

set -euo pipefail

TASK=""
PROJECT_DIR="."
MAX_FILES=3
MAX_LINES=12
JSON_MODE=0
HARD_TTL_DAYS="${BESTAI_BINDING_HARD_TTL_DAYS:-0}"
SOFT_TTL_DAYS="${BESTAI_BINDING_SOFT_TTL_DAYS:-0}"
ALLOW_HARD_OVERRIDE_RAW="${BESTAI_BINDING_ALLOW_HARD_OVERRIDE:-0}"

normalize_ttl_days() {
    local raw="${1:-0}"
    if printf '%s' "$raw" | grep -Eq '^[0-9]+$'; then
        printf '%s' "$raw"
    else
        printf '0'
    fi
}

extract_date_hint() {
    local text="${1:-}"
    local file_hint="${2:-}"
    local candidate=""

    candidate=$(printf '%s\n' "$text" | grep -Eo '[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' | head -n 1 || true)
    if [ -z "$candidate" ] && [ -n "$file_hint" ]; then
        candidate=$(printf '%s\n' "$file_hint" | grep -Eo '[0-9]{4}[-_][0-9]{2}[-_][0-9]{2}' | head -n 1 || true)
    fi

    if [ -n "$candidate" ]; then
        candidate=$(printf '%s' "$candidate" | tr '/_' '--')
    fi
    printf '%s' "$candidate"
}

to_epoch_or_empty() {
    local dt="${1:-}"
    [ -n "$dt" ] || return 0
    date -u -d "$dt" +%s 2>/dev/null || true
}

emit_json_empty() {
    local task="${1:-}"
    jq -cn --arg task "$task" '
        {
          task:$task,
          bindings:[],
          hard_count:0,
          soft_count:0,
          overridden_count:0,
          dropped_expired_count:0,
          metadata:{
            hard_count:0,
            soft_count:0,
            overridden_count:0,
            dropped_expired_count:0
          }
        }'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task) TASK="${2:-}"; shift 2 ;;
        --project-dir) PROJECT_DIR="${2:-.}"; shift 2 ;;
        --max-files) MAX_FILES="${2:-3}"; shift 2 ;;
        --max-lines) MAX_LINES="${2:-12}"; shift 2 ;;
        --json) JSON_MODE=1; shift ;;
        *) shift ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task 'description' [--project-dir .] [--max-files N] [--max-lines N] [--json]" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 1
fi

HARD_TTL_DAYS=$(normalize_ttl_days "$HARD_TTL_DAYS")
SOFT_TTL_DAYS=$(normalize_ttl_days "$SOFT_TTL_DAYS")
ALLOW_HARD_OVERRIDE=0
if [ "$ALLOW_HARD_OVERRIDE_RAW" = "1" ]; then
    ALLOW_HARD_OVERRIDE=1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
STATE_FILE="$PROJECT_DIR/.claude/state-of-system-now.md"
GPS_FILE="$PROJECT_DIR/.bestai/GPS.json"
NOW_EPOCH=$(date -u +%s)

TMP_KW=$(mktemp)
TMP_SCORES=$(mktemp)
trap 'rm -f "$TMP_KW" "$TMP_SCORES"' EXIT

printf '%s\n' "$TASK" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]_-' '\n' \
    | awk 'length >= 4' \
    | grep -Evi '^(this|that|with|from|have|will|would|could|should|about|into|your|please|task|problem|issue|which|kiedy|gdzie|jest|oraz|który|ktory|zeby|very|more|less)$' \
    | sort -u > "$TMP_KW" || true

if [ ! -s "$TMP_KW" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        emit_json_empty "$TASK"
    fi
    exit 0
fi

CANDIDATES=()
if [ -d "$MEMORY_DIR" ]; then
    while IFS= read -r f; do
        CANDIDATES+=("$f")
    done < <(find "$MEMORY_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
fi
[ -f "$STATE_FILE" ] && CANDIDATES+=("$STATE_FILE")
[ -f "$GPS_FILE" ] && CANDIDATES+=("$GPS_FILE")

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        emit_json_empty "$TASK"
    fi
    exit 0
fi

for f in "${CANDIDATES[@]}"; do
    [ -f "$f" ] || continue
    score=$(grep -iFf "$TMP_KW" "$f" 2>/dev/null | wc -l | tr -d ' ')
    [ "$score" -gt 0 ] || continue
    printf '%s\t%s\n' "$score" "$f" >> "$TMP_SCORES"
done

if [ ! -s "$TMP_SCORES" ]; then
    if [ "$JSON_MODE" -eq 1 ]; then
        emit_json_empty "$TASK"
    fi
    exit 0
fi

SELECTED=$(sort -t$'\t' -k1,1nr "$TMP_SCORES" | head -n "$MAX_FILES")

HARD_COUNT=0
SOFT_COUNT=0
OVERRIDDEN_COUNT=0
DROPPED_EXPIRED_COUNT=0
OUTPUT_LINES=()
BINDINGS_JSON=()

while IFS=$'\t' read -r score file; do
    [ -z "$file" ] && continue
    [ -f "$file" ] || continue
    file_date_hint=$(extract_date_hint "$(basename "$file")" "$(basename "$file")")

    while IFS= read -r match_line; do
        [ -z "$match_line" ] && continue
        line_no=${match_line%%:*}
        excerpt=${match_line#*:}
        cleaned=$(printf '%s' "$excerpt" | tr '\t\r' '  ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
        [ -z "$cleaned" ] && continue
        cleaned=$(printf '%s' "$cleaned" | cut -c1-220)

        base_level="SOFT"
        if printf '%s' "$cleaned" | grep -Eqi '\[hard\]|\[policy\]|\bmust\b|\bnie wolno\b|\bzakaz\b'; then
            base_level="HARD"
        fi

        ttl_days="$SOFT_TTL_DAYS"
        [ "$base_level" = "HARD" ] && ttl_days="$HARD_TTL_DAYS"

        decision_date=$(extract_date_hint "$cleaned" "$file_date_hint")
        decision_epoch=$(to_epoch_or_empty "$decision_date")
        age_days=-1
        date_status="missing"
        confidence=0.55

        if [ -n "$decision_epoch" ]; then
            date_status="dated"
            age_days=$(( (NOW_EPOCH - decision_epoch) / 86400 ))
            [ "$age_days" -lt 0 ] && age_days=0
            confidence=0.92
        fi

        if [ "$date_status" = "dated" ] && [ "$ttl_days" -gt 0 ] && [ "$age_days" -gt "$ttl_days" ]; then
            DROPPED_EXPIRED_COUNT=$((DROPPED_EXPIRED_COUNT + 1))
            continue
        fi

        level="$base_level"
        if [ "$base_level" = "HARD" ] && [ "$ALLOW_HARD_OVERRIDE" -eq 1 ]; then
            level="OVERRIDDEN"
            OVERRIDDEN_COUNT=$((OVERRIDDEN_COUNT + 1))
            confidence=0.45
        elif [ "$base_level" = "HARD" ]; then
            HARD_COUNT=$((HARD_COUNT + 1))
            if [ "$date_status" = "missing" ]; then
                confidence=0.62
            fi
        else
            SOFT_COUNT=$((SOFT_COUNT + 1))
            if [ "$date_status" = "missing" ]; then
                confidence=0.58
            else
                confidence=0.84
            fi
        fi

        short_file=${file#"$PROJECT_DIR"/}
        [ "$short_file" = "$file" ] && short_file=${file#"$MEMORY_DIR"/}

        OUTPUT_LINES+=("[$level] $short_file:$line_no — $cleaned (confidence=${confidence})")

        if [ "$age_days" -ge 0 ]; then
            age_arg=(--argjson age_days "$age_days")
        else
            age_arg=(--argjson age_days null)
        fi

        if [ -n "$decision_date" ]; then
            date_arg=(--arg decision_date "$decision_date")
        else
            date_arg=(--argjson decision_date null)
        fi

        item=$(jq -cn \
            --arg level "$level" \
            --arg base_level "$base_level" \
            --arg source "$short_file:$line_no" \
            --arg excerpt "$cleaned" \
            --argjson score "$score" \
            --argjson confidence "$confidence" \
            --arg date_status "$date_status" \
            "${date_arg[@]}" \
            "${age_arg[@]}" \
            '{level:$level,base_level:$base_level,source:$source,excerpt:$excerpt,score:$score,confidence:$confidence,date_status:$date_status,decision_date:$decision_date,age_days:$age_days}')
        BINDINGS_JSON+=("$item")

        if [ "${#OUTPUT_LINES[@]}" -ge "$MAX_LINES" ]; then
            break
        fi
    done < <(grep -inFf "$TMP_KW" "$file" 2>/dev/null)

    if [ "${#OUTPUT_LINES[@]}" -ge "$MAX_LINES" ]; then
        break
    fi
done <<< "$SELECTED"

if [ "$JSON_MODE" -eq 1 ]; then
    if [ "${#BINDINGS_JSON[@]}" -eq 0 ]; then
        jq -cn \
            --arg task "$TASK" \
            --argjson dropped "$DROPPED_EXPIRED_COUNT" \
            '{
               task:$task,
               bindings:[],
               hard_count:0,
               soft_count:0,
               overridden_count:0,
               dropped_expired_count:$dropped,
               metadata:{
                 hard_count:0,
                 soft_count:0,
                 overridden_count:0,
                 dropped_expired_count:$dropped
               }
             }'
    else
        printf '%s\n' "${BINDINGS_JSON[@]}" \
            | jq -s \
                --arg task "$TASK" \
                --argjson hard "$HARD_COUNT" \
                --argjson soft "$SOFT_COUNT" \
                --argjson overridden "$OVERRIDDEN_COUNT" \
                --argjson dropped "$DROPPED_EXPIRED_COUNT" \
                '{
                   task:$task,
                   bindings:.,
                   hard_count:$hard,
                   soft_count:$soft,
                   overridden_count:$overridden,
                   dropped_expired_count:$dropped,
                   metadata:{
                     hard_count:$hard,
                     soft_count:$soft,
                     overridden_count:$overridden,
                     dropped_expired_count:$dropped
                   }
                 }'
    fi
else
    [ "${#OUTPUT_LINES[@]}" -eq 0 ] && exit 0
    echo "### Binding Context (auto)"
    printf '%s\n' "${OUTPUT_LINES[@]}"
fi
