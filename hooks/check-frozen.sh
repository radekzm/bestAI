#!/bin/bash
# hooks/check-frozen.sh — PreToolUse hook (Edit|Write|Bash matcher)
# Blocks edits to files listed in frozen-fragments.md
# Exit 2 = BLOCK (deterministic enforcement)
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)

set -euo pipefail

# Fail closed: if jq is missing, block rather than allow
if ! command -v jq &>/dev/null; then
    echo "BLOCKED: jq is not installed. Cannot validate frozen files." >&2
    exit 2
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || {
    echo "BLOCKED: Failed to parse hook input JSON." >&2
    exit 2
}
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || {
    echo "BLOCKED: Failed to parse tool_input from JSON." >&2
    exit 2
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
METRICS_FILE="$HOME/.claude/projects/$PROJECT_KEY/hook-metrics.log"
mkdir -p "$(dirname "$METRICS_FILE")" 2>/dev/null || true

log_metric() {
    local action="$1"
    local details="$2"
    printf '%s check-frozen %s %s\n' "$(date -u +%FT%TZ)" "$action" "$details" >> "$METRICS_FILE" 2>/dev/null || true
}

# Normalize path: remove ./ and .. components, convert to absolute
normalize_path() {
    local p="$1"

    if [[ "$p" != /* ]]; then
        p="$PROJECT_DIR/$p"
    fi

    if command -v realpath &>/dev/null; then
        realpath -m "$p" 2>/dev/null || echo "$p"
    elif command -v python3 &>/dev/null; then
        python3 -c "import os, sys; print(os.path.normpath(sys.argv[1]))" "$p" 2>/dev/null || echo "$p"
    else
        echo "$p"
    fi
}

MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
CANONICAL_FROZEN="$MEMORY_DIR/frozen-fragments.md"
LEGACY_FROZEN="$PROJECT_DIR/.claude/frozen-fragments.md"

FROZEN_PATHS_FILE=$(mktemp)
trap 'rm -f "$FROZEN_PATHS_FILE"' EXIT

collect_frozen_paths() {
    local registry="$1"
    [ ! -f "$registry" ] && return 0

    while IFS= read -r line; do
        local raw normalized
        raw=$(echo "$line" | sed -n 's/.*`\([^`]*\)`.*/\1/p' | head -1)
        [ -z "$raw" ] && continue
        normalized=$(normalize_path "$raw")
        printf '%s\t%s\n' "$raw" "$normalized" >> "$FROZEN_PATHS_FILE"
    done < <(grep -E '^\s*-\s*`' "$registry" 2>/dev/null)
}

collect_frozen_paths "$CANONICAL_FROZEN"
collect_frozen_paths "$LEGACY_FROZEN"

[ ! -s "$FROZEN_PATHS_FILE" ] && exit 0

check_direct_file_edit() {
    local file_path normalized_file

    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
    [ -z "$file_path" ] && return 0

    normalized_file=$(normalize_path "$file_path")

    while IFS=$'\t' read -r raw frozen_norm; do
        if [ "$normalized_file" = "$frozen_norm" ]; then
            log_metric "BLOCK" "mode=direct file=$file_path"
            echo "BLOCKED: File is FROZEN: $file_path" >&2
            echo "Listed in frozen-fragments.md registry." >&2
            echo "To unfreeze: remove entry from frozen-fragments.md" >&2
            exit 2
        fi
    done < "$FROZEN_PATHS_FILE"
}

check_bash_bypass() {
    local command
    command=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
    [ -z "$command" ] && return 0

    # Only check commands that can modify files.
    if ! echo "$command" | grep -Eqi '(sed\s+-i|perl\s+-i|awk.*inplace|echo\s+.*>|printf\s+.*>|cat\s+.*>|tee\s+|rm\s+|mv\s+|cp\s+|truncate\s+|dd\s+|git\s+(checkout|restore))'; then
        return 0
    fi

    while IFS=$'\t' read -r raw frozen_norm; do
        if echo "$command" | grep -Fq "$raw" || echo "$command" | grep -Fq "$frozen_norm"; then
            log_metric "BLOCK" "mode=bash file=$raw"
            echo "BLOCKED: Bash command attempts to modify FROZEN file: $raw" >&2
            echo "Command: $command" >&2
            echo "This is a frozen-file bypass vector; operation blocked." >&2
            exit 2
        fi
    done < "$FROZEN_PATHS_FILE"
}

case "$TOOL_NAME" in
    Write|Edit)
        check_direct_file_edit
        ;;
    Bash)
        check_bash_bypass
        ;;
    "")
        # Unknown/empty tool name: best-effort checks for file_path and command.
        check_direct_file_edit
        check_bash_bypass
        ;;
esac

log_metric "ALLOW" "mode=${TOOL_NAME:-unknown}"
exit 0
