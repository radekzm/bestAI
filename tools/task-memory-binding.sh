#!/bin/bash
# tools/task-memory-binding.sh — build binding context from project history/memory
# Usage: bash tools/task-memory-binding.sh --task "..." [--project-dir .] [--max-files 3] [--max-lines 12] [--json]

set -euo pipefail

TASK=""
PROJECT_DIR="."
MAX_FILES=3
MAX_LINES=12
JSON_MODE=0

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

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
STATE_FILE="$PROJECT_DIR/.claude/state-of-system-now.md"
GPS_FILE="$PROJECT_DIR/.bestai/GPS.json"

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
        echo '{"task":"","bindings":[],"hard_count":0,"soft_count":0}'
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
        jq -cn --arg task "$TASK" '{task:$task,bindings:[],hard_count:0,soft_count:0}'
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
        jq -cn --arg task "$TASK" '{task:$task,bindings:[],hard_count:0,soft_count:0}'
    fi
    exit 0
fi

SELECTED=$(sort -t$'\t' -k1,1nr "$TMP_SCORES" | head -n "$MAX_FILES")

HARD_COUNT=0
SOFT_COUNT=0
OUTPUT_LINES=()
BINDINGS_JSON=()

while IFS=$'\t' read -r score file; do
    [ -z "$file" ] && continue
    [ -f "$file" ] || continue

    while IFS= read -r match_line; do
        [ -z "$match_line" ] && continue
        line_no=${match_line%%:*}
        excerpt=${match_line#*:}
        cleaned=$(printf '%s' "$excerpt" | tr '\t\r' '  ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
        [ -z "$cleaned" ] && continue
        cleaned=$(printf '%s' "$cleaned" | cut -c1-220)

        level="SOFT"
        if printf '%s' "$cleaned" | grep -Eqi '\[hard\]|\[policy\]|\bmust\b|\bnie wolno\b|\bzakaz\b'; then
            level="HARD"
            HARD_COUNT=$((HARD_COUNT + 1))
        else
            SOFT_COUNT=$((SOFT_COUNT + 1))
        fi

        short_file=${file#"$PROJECT_DIR"/}
        [ "$short_file" = "$file" ] && short_file=${file#"$MEMORY_DIR"/}

        OUTPUT_LINES+=("[$level] $short_file:$line_no — $cleaned")

        item=$(jq -cn \
            --arg level "$level" \
            --arg source "$short_file:$line_no" \
            --arg excerpt "$cleaned" \
            --argjson score "$score" \
            '{level:$level,source:$source,excerpt:$excerpt,score:$score}')
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
        jq -cn --arg task "$TASK" '{task:$task,bindings:[],hard_count:0,soft_count:0}'
    else
        printf '%s\n' "${BINDINGS_JSON[@]}" \
            | jq -s --arg task "$TASK" --argjson hard "$HARD_COUNT" --argjson soft "$SOFT_COUNT" \
                '{task:$task,bindings:.,hard_count:$hard,soft_count:$soft}'
    fi
else
    [ "${#OUTPUT_LINES[@]}" -eq 0 ] && exit 0
    echo "### Binding Context (auto)"
    printf '%s\n' "${OUTPUT_LINES[@]}"
fi
