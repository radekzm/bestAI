#!/bin/bash
# hooks/reflector.sh — Memory defragmentation (maintenance script)
# Run manually: bash hooks/reflector.sh [project-dir]
# Or as cron: */30 * * * * bash /path/to/reflector.sh /path/to/project
#
# Pipeline:
#   1. If Haiku available: merge duplicates across decisions.md + pitfalls.md + observations.md
#   2. Remove contradictory entries
#   3. Update context-index.md with semantic topic clusters
#   4. If Haiku unavailable: no-op (safe fallback)
#
# Env vars:
#   REFLECTOR_MODEL=haiku    — model for merging
#   REFLECTOR_TIMEOUT=10     — Haiku timeout in seconds
#   REFLECTOR_DRY_RUN=1      — print without writing

set -euo pipefail

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR_DEFAULT="$HOME/.claude/projects/$PROJECT_KEY/memory"
MEMORY_DIR="${SMART_CONTEXT_MEMORY_DIR:-$MEMORY_DIR_DEFAULT}"

if [ ! -d "$MEMORY_DIR" ]; then
    echo "reflector: no memory directory at $MEMORY_DIR" >&2
    exit 0
fi

MODEL="${REFLECTOR_MODEL:-haiku}"
TIMEOUT="${REFLECTOR_TIMEOUT:-10}"
DRY_RUN="${REFLECTOR_DRY_RUN:-0}"

# --- Check Haiku availability ---
if ! command -v claude >/dev/null 2>&1; then
    echo "reflector: claude CLI not available, skipping (no-op fallback)"
    exit 0
fi

# --- Collect content from mergeable files ---
MERGE_CONTENT=""
MERGE_FILES=("decisions.md" "pitfalls.md" "observations.md")

for fname in "${MERGE_FILES[@]}"; do
    filepath="$MEMORY_DIR/$fname"
    [ -f "$filepath" ] || continue
    MERGE_CONTENT+="
=== $fname ===
$(head -80 "$filepath")
"
done

[ -z "$MERGE_CONTENT" ] && { echo "reflector: no content to merge"; exit 0; }

# --- Call Haiku for merge + dedup ---
HAIKU_PROMPT="You are a memory defragmenter. Given entries from multiple memory files, produce a clean merged version.

Rules:
1. Merge duplicate entries (same topic from different files) into one
2. If entries contradict each other, keep the most recent or [USER]-tagged one
3. [USER] entries must NEVER be removed
4. Output format: one section per source file, with cleaned entries
5. Each entry on its own line starting with '- '

Input:
$MERGE_CONTENT

Output the merged content in sections:
## decisions
## pitfalls
## observations"

MERGED=""
MERGED=$(timeout "${TIMEOUT}s" claude -p --model "$MODEL" "$HAIKU_PROMPT" 2>/dev/null) || true

if [ -z "$MERGED" ]; then
    echo "reflector: Haiku call failed or timed out, skipping"
    exit 0
fi

# --- Write merged content back ---
if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] Haiku merged output:"
    echo "$MERGED"
    exit 0
fi

# Extract sections and write back
for fname in "${MERGE_FILES[@]}"; do
    filepath="$MEMORY_DIR/$fname"
    [ -f "$filepath" ] || continue
    section_name="${fname%.md}"

    # Extract section from merged output
    section=$(echo "$MERGED" | sed -n "/^## $section_name/,/^## /p" | sed '1d;$d')
    [ -z "$section" ] && continue

    # Preserve header and replace content
    header=$(head -1 "$filepath")
    {
        echo "$header"
        echo ""
        echo "$section"
    } > "${filepath}.new"
    mv "${filepath}.new" "$filepath"
done

# --- Regenerate context-index.md ---
if [ -f "$MEMORY_DIR/.session-counter" ]; then
    HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$HOOKS_DIR/memory-compiler.sh" ]; then
        CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOKS_DIR/memory-compiler.sh" 2>/dev/null || true
    fi
fi

echo "reflector: merge complete"
exit 0
