#!/bin/bash
# hooks/check-frozen.sh — PreToolUse hook (Edit|Write matcher)
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
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>&1) || {
    echo "BLOCKED: Failed to parse hook input JSON." >&2
    exit 2
}
[ -z "$TOOL_INPUT" ] && exit 0

# Extract file path from tool input (handles both file_path and path keys)
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>&1) || {
    echo "BLOCKED: Failed to extract file path from input." >&2
    exit 2
}
[ -z "$FILE_PATH" ] && exit 0

# Normalize path: remove ./ and .. components, convert to absolute
normalize_path() {
    local p="$1"
    # If relative, prepend project dir
    if [[ "$p" != /* ]]; then
        p="${CLAUDE_PROJECT_DIR:-.}/$p"
    fi
    # Use realpath if available (handles .., symlinks), fall back to python3, then block
    if command -v realpath &>/dev/null; then
        realpath -m "$p" 2>/dev/null || echo "$p"
    elif command -v python3 &>/dev/null; then
        python3 -c "import os, sys; print(os.path.normpath(sys.argv[1]))" "$p" 2>/dev/null || echo "$p"
    else
        # No normalization tool available — use raw path (best effort)
        echo "$p"
    fi
}

NORMALIZED_FILE=$(normalize_path "$FILE_PATH")

# Find frozen registry
MEMORY_DIR="$HOME/.claude/projects/$(echo "${CLAUDE_PROJECT_DIR:-.}" | tr '/' '-')/memory"
FROZEN_FILE="$MEMORY_DIR/frozen-fragments.md"

# Also check project-local frozen file
PROJECT_FROZEN="${CLAUDE_PROJECT_DIR:-.}/.claude/frozen-fragments.md"

check_frozen() {
    local registry="$1"
    [ ! -f "$registry" ] && return 0  # No registry = nothing frozen = allow

    # Extract paths from frozen registry (lines starting with "- `path`")
    while IFS= read -r line; do
        # Extract path between backticks (POSIX-compatible, no grep -P)
        FROZEN_PATH=$(echo "$line" | sed -n 's/.*`\([^`]*\)`.*/\1/p' | head -1)
        [ -z "$FROZEN_PATH" ] && continue

        NORMALIZED_FROZEN=$(normalize_path "$FROZEN_PATH")

        # Exact match
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
