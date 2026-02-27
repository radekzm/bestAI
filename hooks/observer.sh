#!/bin/bash
# hooks/observer.sh — Stop hook
# Compressed Observational Memory: periodically compresses session-log into observations.
#
# Pipeline (every 5 sessions, counter-based):
#   1. Read session-log.md (last 50 lines)
#   2. If Haiku available: compress to max 5 observations
#   3. If Haiku unavailable: copy raw entries (fallback)
#   4. Append to observations.md
#
# Env vars:
#   OBSERVER_INTERVAL=5      — run every N sessions (default: 5)
#   OBSERVER_MODEL=haiku     — model for compression
#   OBSERVER_TIMEOUT=5       — Haiku timeout in seconds
#   OBSERVER_DRY_RUN=1       — print without writing

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MEMORY_DIR_DEFAULT="$HOME/.claude/projects/$PROJECT_KEY/memory"
MEMORY_DIR="${SMART_CONTEXT_MEMORY_DIR:-$MEMORY_DIR_DEFAULT}"
[ -d "$MEMORY_DIR" ] || exit 0

INTERVAL="${OBSERVER_INTERVAL:-5}"
MODEL="${OBSERVER_MODEL:-haiku}"
TIMEOUT="${OBSERVER_TIMEOUT:-5}"
DRY_RUN="${OBSERVER_DRY_RUN:-0}"

SESSION_COUNTER="$MEMORY_DIR/.session-counter"
OBSERVATION_FILE="$MEMORY_DIR/observations.md"
SESSION_LOG="$MEMORY_DIR/session-log.md"

# --- Check if it's time to run ---
CURRENT_SESSION=0
if [ -f "$SESSION_COUNTER" ]; then
    CURRENT_SESSION=$(cat "$SESSION_COUNTER" 2>/dev/null || echo 0)
    [[ "$CURRENT_SESSION" =~ ^[0-9]+$ ]] || CURRENT_SESSION=0
fi

if [ $((CURRENT_SESSION % INTERVAL)) -ne 0 ] || [ "$CURRENT_SESSION" -eq 0 ]; then
    exit 0
fi

# --- Read recent session log ---
[ -f "$SESSION_LOG" ] || exit 0
RECENT_LOG=$(tail -50 "$SESSION_LOG" 2>/dev/null)
[ -z "$RECENT_LOG" ] && exit 0

# --- Compress with Haiku or fallback ---
COMPRESSED=""
HAIKU_AVAILABLE=0

if command -v claude >/dev/null 2>&1; then
    HAIKU_PROMPT="Compress these session log entries into max 5 bullet points.
Focus on: decisions made, files changed, errors encountered, user preferences, state changes.
Format: one bullet point per line starting with '- '.

Session log:
$RECENT_LOG"

    COMPRESSED=$(timeout "${TIMEOUT}s" claude -p --model "$MODEL" "$HAIKU_PROMPT" 2>/dev/null) || true
    [ -n "$COMPRESSED" ] && HAIKU_AVAILABLE=1
fi

# Fallback: extract key lines from raw log
if [ -z "$COMPRESSED" ]; then
    COMPRESSED=$(echo "$RECENT_LOG" \
        | { grep -iE '(decision|error|changed|created|updated|preference|blocked|deployed|fixed|refactored)' || true; } \
        | head -5 \
        | sed 's/^/- /')
fi

[ -z "$COMPRESSED" ] && exit 0

# --- Write observations ---
if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] Would append to observations.md:"
    echo "$COMPRESSED"
    exit 0
fi

{
    echo ""
    echo "## Session $CURRENT_SESSION observations ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
    if [ "$HAIKU_AVAILABLE" -eq 1 ]; then
        echo "_Compressed by ${MODEL}_"
    else
        echo "_Raw extraction (Haiku unavailable)_"
    fi
    echo "$COMPRESSED"
} >> "$OBSERVATION_FILE"

exit 0
