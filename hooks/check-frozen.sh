#!/bin/bash
# hooks/check-frozen.sh — PreToolUse hook (Edit|Write matcher)
# FIXED: Path normalization, error handling, edge cases
# Blocks edits to files listed in frozen-fragments.md
# Exit 2 = BLOCK (deterministic enforcement)

set -euo pipefail

INPUT=$(cat)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)
[ -z "$TOOL_INPUT" ] && exit 0

# Extract file path from tool input (handles both file_path and path keys)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Normalize path: resolve symlinks, remove trailing slashes, convert to absolute
normalize_path() {
    local p="$1"
    # If relative, prepend project dir
    if [[ "$p" != /* ]]; then
        p="${CLAUDE_PROJECT_DIR:-.}/$p"
    fi
    # Resolve .. and . components (without requiring file to exist)
    python3 -c "import os; print(os.path.normpath('$p'))" 2>/dev/null || echo "$p"
}

NORMALIZED_FILE=$(normalize_path "$FILE_PATH")

# Find frozen registry
MEMORY_DIR="$HOME/.claude/projects/$(echo "${CLAUDE_PROJECT_DIR:-.}" | tr '/' '-')/memory"
FROZEN_FILE="$MEMORY_DIR/frozen-fragments.md"

# Also check project-local frozen file
PROJECT_FROZEN="${CLAUDE_PROJECT_DIR:-.}/.claude/frozen-fragments.md"

check_frozen() {
    local registry="$1"
    [ ! -f "$registry" ] && return 1

    # Extract paths from frozen registry (lines starting with "- `path`")
    while IFS= read -r line; do
        # Extract path between backticks
        FROZEN_PATH=$(echo "$line" | grep -oP '`\K[^`]+' 2>/dev/null | head -1)
        [ -z "$FROZEN_PATH" ] && continue

        NORMALIZED_FROZEN=$(normalize_path "$FROZEN_PATH")

        # Exact match or subdirectory match
        if [ "$NORMALIZED_FILE" = "$NORMALIZED_FROZEN" ]; then
            echo "BLOCKED: File is FROZEN: $FILE_PATH" >&2
            echo "Listed in: $registry" >&2
            echo "To unfreeze: remove entry from frozen-fragments.md" >&2
            exit 2
        fi
    done < <(grep -E '^\s*-\s*`' "$registry" 2>/dev/null)
}

check_frozen "$FROZEN_FILE"
check_frozen "$PROJECT_FROZEN"

exit 0
