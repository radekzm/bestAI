#!/bin/bash
# hooks/check-user-tags.sh — PreToolUse hook (Write|Edit matcher)
# Blocks writes to memory files that remove [USER] tagged entries.
# Exit 2 = BLOCK (deterministic enforcement)
#
# Rule: [USER] entries are NEVER auto-deleted or overridden by [AUTO].
# (Module 03, Rule #1: "[USER] NEVER overridden by [AUTO]")
#
# Scope: Only checks files in the memory/ directory.
# Non-memory files always pass (exit 0).

set -euo pipefail

BESTAI_DRY_RUN="${BESTAI_DRY_RUN:-0}"

if ! command -v jq &>/dev/null; then
    exit 0  # Fail open — this is a safety net, not a primary gate
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

# Only check Write and Edit tools
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || exit 0

FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Only protect memory directory files
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"

# Resolve the target file path
TARGET=""
if [[ "$FILE_PATH" == "$MEMORY_DIR"/* ]]; then
    TARGET="$FILE_PATH"
elif [[ "$FILE_PATH" == memory/* ]] || [[ "$FILE_PATH" == */memory/* ]]; then
    # Relative path that looks like a memory file
    if [ -f "$MEMORY_DIR/$(basename "$FILE_PATH")" ]; then
        TARGET="$MEMORY_DIR/$(basename "$FILE_PATH")"
    fi
fi

# Not a memory file — allow
[ -z "$TARGET" ] && exit 0

# File doesn't exist yet — allow (new file creation is fine)
[ -f "$TARGET" ] || exit 0

# Extract existing [USER] entries from the current file
CURRENT_USER_LINES=$(mktemp)
trap 'rm -f "$CURRENT_USER_LINES"' EXIT
{ grep '\[USER\]' "$TARGET" 2>/dev/null || true; } | sed 's/^[[:space:]]*//' | sort -u > "$CURRENT_USER_LINES"

# No [USER] entries in current file — nothing to protect
[ ! -s "$CURRENT_USER_LINES" ] && exit 0

# For Write tool: check proposed content for [USER] preservation
if [ "$TOOL_NAME" = "Write" ]; then
    NEW_CONTENT=$(echo "$TOOL_INPUT" | jq -r '.content // empty' 2>/dev/null)
    [ -z "$NEW_CONTENT" ] && exit 0

    # Check each [USER] entry is preserved in new content
    MISSING=""
    while IFS= read -r user_line; do
        [ -z "$user_line" ] && continue
        # Use fixed-string grep to match the [USER] entry in new content
        if ! echo "$NEW_CONTENT" | grep -qF -- "$user_line"; then
            MISSING+="  - $user_line"$'\n'
        fi
    done < "$CURRENT_USER_LINES"

    if [ -n "$MISSING" ]; then
        if [ "$BESTAI_DRY_RUN" = "1" ]; then
            echo "[DRY-RUN] WOULD BLOCK: Write would remove [USER] entries from $(basename "$TARGET")" >&2
            echo "Missing [USER] entries:" >&2
            echo "$MISSING" >&2
            exit 0
        fi
        echo "BLOCKED: Write would remove [USER] entries from $(basename "$TARGET")" >&2
        echo "Rule: [USER] entries are NEVER auto-deleted (Module 03, Rule #1)" >&2
        echo "Missing [USER] entries:" >&2
        echo "$MISSING" >&2
        echo "To override: user must explicitly approve removal." >&2
        exit 2
    fi
fi

# For Edit tool: check that old_string doesn't contain [USER] lines
# that aren't preserved in new_string
if [ "$TOOL_NAME" = "Edit" ]; then
    OLD_STRING=$(echo "$TOOL_INPUT" | jq -r '.old_string // empty' 2>/dev/null)
    NEW_STRING=$(echo "$TOOL_INPUT" | jq -r '.new_string // empty' 2>/dev/null)
    [ -z "$OLD_STRING" ] && exit 0

    # Extract [USER] lines from the old_string being replaced
    OLD_USER_LINES=$(echo "$OLD_STRING" | grep '\[USER\]' 2>/dev/null | sed 's/^[[:space:]]*//' || true)
    [ -z "$OLD_USER_LINES" ] && exit 0

    # Check each [USER] line from old_string exists in new_string
    MISSING=""
    while IFS= read -r user_line; do
        [ -z "$user_line" ] && continue
        if ! echo "$NEW_STRING" | grep -qF -- "$user_line"; then
            MISSING+="  - $user_line"$'\n'
        fi
    done <<< "$OLD_USER_LINES"

    if [ -n "$MISSING" ]; then
        if [ "$BESTAI_DRY_RUN" = "1" ]; then
            echo "[DRY-RUN] WOULD BLOCK: Edit would remove [USER] entries from $(basename "$TARGET")" >&2
            echo "Missing [USER] entries in replacement:" >&2
            echo "$MISSING" >&2
            exit 0
        fi
        echo "BLOCKED: Edit would remove [USER] entries from $(basename "$TARGET")" >&2
        echo "Rule: [USER] entries are NEVER auto-deleted (Module 03, Rule #1)" >&2
        echo "Missing [USER] entries in replacement:" >&2
        echo "$MISSING" >&2
        echo "To override: user must explicitly approve removal." >&2
        exit 2
    fi
fi

exit 0
