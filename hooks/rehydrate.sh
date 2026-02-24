#!/bin/bash
# hooks/rehydrate.sh — SessionStart hook
# Deterministic cold-start bootstrap (AION-style, zero glob discovery).

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="${REHYDRATE_MEMORY_DIR:-$HOME/.claude/projects/$PROJECT_KEY/memory}"
INDEX_FILE="${REHYDRATE_INDEX_FILE:-$MEMORY_DIR/MEMORY.md}"
MAX_LINES=${REHYDRATE_MAX_LINES:-40}

normalize_path() {
    local p="$1"
    if [[ "$p" != /* ]]; then
        p="$PROJECT_DIR/$p"
    fi
    if command -v realpath >/dev/null 2>&1; then
        realpath -m "$p" 2>/dev/null || echo "$p"
    else
        echo "$p"
    fi
}

TARGETS=()
if [ -f "$INDEX_FILE" ]; then
    while IFS= read -r raw; do
        [ -z "$raw" ] && continue
        TARGETS+=("$(normalize_path "$raw")")
    done < <(sed -n 's/.*`\([^`]*\)`.*/\1/p' "$INDEX_FILE" | head -n 4)
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
    TARGETS+=("$(normalize_path "$MEMORY_DIR/MEMORY.md")")
    TARGETS+=("$(normalize_path "$MEMORY_DIR/frozen-fragments.md")")
    TARGETS+=("$(normalize_path ".claude/state-of-system-now.md")")
    TARGETS+=("$(normalize_path ".claude/checklist-now.md")")
fi

declare -A seen
SELECTED=()
for path in "${TARGETS[@]}"; do
    [ -z "$path" ] && continue
    if [ -z "${seen[$path]:-}" ]; then
        seen[$path]=1
        SELECTED+=("$path")
    fi
done

echo "REHYDRATE: START"
LOADED=0
for file in "${SELECTED[@]}"; do
    [ -f "$file" ] || continue
    LOADED=$((LOADED + 1))
    echo "--- $(basename "$file") ---"
    sed -n "1,${MAX_LINES}p" "$file"
    echo ""
done

if [ "$LOADED" -eq 0 ]; then
    echo "REHYDRATE: NEED-DATA (no readable files found)"
    exit 0
fi

echo "REHYDRATE: DONE"
echo "LOADED_COUNT: $LOADED"

exit 0
