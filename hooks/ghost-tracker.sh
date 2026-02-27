#!/bin/bash
# hooks/ghost-tracker.sh — PostToolUse hook (Read|Grep|Glob matcher)
# Tracks manually-read files to support ARC ghost boost in preprocess-prompt.sh.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

INPUT="$(cat)"
TOOL_NAME="$(printf '%s\n' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0

case "$TOOL_NAME" in
    Read|Grep|Glob) ;;
    *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY="$(echo "$PROJECT_DIR" | tr '/' '-')"
MEMORY_DIR_DEFAULT="$HOME/.claude/projects/$PROJECT_KEY/memory"
MEMORY_DIR="${SMART_CONTEXT_MEMORY_DIR:-$MEMORY_DIR_DEFAULT}"
[ -d "$MEMORY_DIR" ] || exit 0

# Best effort extraction from tool_input for read-like tools.
TARGET_PATH="$(
    printf '%s\n' "$INPUT" | jq -r '
      .tool_input.file_path
      // .tool_input.path
      // .tool_input.target
      // empty
    ' 2>/dev/null
)"
[ -n "$TARGET_PATH" ] || exit 0

BASE="$(basename "$TARGET_PATH")"
[ -n "$BASE" ] || exit 0

# Track only memory files already known by preprocess-prompt.
if [ ! -f "$MEMORY_DIR/$BASE" ]; then
    exit 0
fi

GHOST_LOG="$MEMORY_DIR/ghost-hits.log"
mkdir -p "$MEMORY_DIR"
printf '%s\n' "$BASE" >> "$GHOST_LOG"

# Keep the log bounded.
TMP="$(mktemp)"
tail -n 500 "$GHOST_LOG" > "$TMP" 2>/dev/null || true
mv "$TMP" "$GHOST_LOG"

exit 0
