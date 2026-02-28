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
        --task) TASK="${2:-}"; shift 2 ;;
        --project-dir) PROJECT_DIR="${2:-.}"; shift 2 ;;
        --json) JSON_MODE=1; shift ;;
        *) shift ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task 'description' [--project-dir .] [--json]" >&2
    exit 1
fi

NORMALIZED=$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')
WORDS=$(printf '%s' "$NORMALIZED" | tr -cs '[:alnum:]' '\n' | grep -c . || true)

complexity_score=0
reasons=()

if [ "$WORDS" -gt 18 ]; then
    complexity_score=$((complexity_score + 1))
    reasons+=("task_longer_than_18_words")
fi
if [ "$WORDS" -gt 35 ]; then
    complexity_score=$((complexity_score + 2))
    reasons+=("task_longer_than_35_words")
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(architekt|architecture|security|threat|refactor|migration|incident|root cause|critical|krytycz|interoperab|multi[- ]vendor|schema|contract)'; then
    complexity_score=$((complexity_score + 3))
    reasons+=("contains_complex_keywords")
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(debug|fix|napraw|test|optimiz|benchmark|profil|lint|compliance)'; then
    complexity_score=$((complexity_score + 1))
    reasons+=("contains_medium_keywords")
fi

if printf '%s' "$NORMALIZED" | grep -Eqi '(scan|find|list|inventory|grep|map|przeskan|research)'; then
    complexity_score=$((complexity_score + 1))
    reasons+=("discovery_or_research_task")
fi

complexity="simple"
depth="fast"
if [ "$complexity_score" -ge 4 ]; then
    complexity="complex"
    depth="deep"
elif [ "$complexity_score" -ge 2 ]; then
    complexity="medium"
    depth="balanced"
fi

vendor="gemini"
if [ "$complexity" = "complex" ]; then
    vendor="claude"
elif printf '%s' "$NORMALIZED" | grep -Eqi '(boilerplate|stub|scaffold|test case|unit test generation|snapshot)'; then
    vendor="codex"
fi

if [ "$vendor" = "codex" ]; then
    # Codex path is still partial in dispatcher: keep recommendation, not forced execution.
    reasons+=("codex_recommended_for_scaffolding")
fi

if [ "$vendor" = "gemini" ] && [ "$depth" = "deep" ]; then
    # Deep tasks should prefer Claude in current implementation.
    vendor="claude"
    reasons+=("deep_tasks_prefer_claude")
fi

confidence=60
if [ "$complexity" = "complex" ]; then
    confidence=82
elif [ "$complexity" = "medium" ]; then
    confidence=74
fi

reasons_json='[]'
if [ "${#reasons[@]}" -gt 0 ]; then
    reasons_json=$(printf '%s\n' "${reasons[@]}" | jq -R . | jq -s .)
fi

# Persist routing decisions for cockpit/analytics
mkdir -p "$PROJECT_DIR/.bestai"
ROUTE_LOG="$PROJECT_DIR/.bestai/router-decisions.jsonl"

if [ "$JSON_MODE" -eq 1 ]; then
    jq -cn \
        --arg task "$TASK" \
        --arg complexity "$complexity" \
        --arg depth "$depth" \
        --arg vendor "$vendor" \
        --argjson confidence "$confidence" \
        --argjson score "$complexity_score" \
        --argjson reasons "$reasons_json" \
        '{task:$task,complexity:$complexity,depth:$depth,vendor:$vendor,confidence:$confidence,score:$score,reasons:$reasons}'
else
    echo "routing.vendor=$vendor"
    echo "routing.depth=$depth"
    echo "routing.complexity=$complexity"
    echo "routing.confidence=$confidence"
    echo "routing.score=$complexity_score"
    if [ "${#reasons[@]}" -gt 0 ]; then
        echo "routing.reasons=$(IFS=,; echo "${reasons[*]}")"
    fi
fi

jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg task "$TASK" \
    --arg complexity "$complexity" \
    --arg depth "$depth" \
    --arg vendor "$vendor" \
    --argjson confidence "$confidence" \
    --argjson score "$complexity_score" \
    --argjson reasons "$reasons_json" \
    '{ts:$ts,task:$task,complexity:$complexity,depth:$depth,vendor:$vendor,confidence:$confidence,score:$score,reasons:$reasons}' \
    >> "$ROUTE_LOG" 2>/dev/null || true
