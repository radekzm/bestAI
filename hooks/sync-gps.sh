#!/bin/bash
# hooks/sync-gps.sh — Stop hook
# Updates Global Project State (GPS) from end-of-session context.

set -euo pipefail

# Shared event logging
source "$(dirname "$0")/hook-event.sh" 2>/dev/null || true
source "$(dirname "$0")/lib-event-bus.sh" 2>/dev/null || true

BESTAI_DRY_RUN="${BESTAI_DRY_RUN:-0}"

if ! command -v jq >/dev/null 2>&1; then
    echo "[bestAI] BLOCKED: sync-gps requires jq." >&2
    exit 2
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
GPS_FILE="${GPS_FILE:-$PROJECT_DIR/.bestai/GPS.json}"
GPS_DIR="$(dirname "$GPS_FILE")"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="${CLAUDE_SESSION_ID:-session-unknown}"

mkdir -p "$GPS_DIR"

validate_gps_schema() {
    local file="$1"
    jq -e '
      (.project | type == "object")
      and (.project.name | type == "string")
      and (.project.main_objective | type == "string")
      and (.project.owner | type == "string")
      and ((.project.target_date == null) or (.project.target_date | type == "string"))
      and (.project.success_metric | type == "string")
      and (.project.status_updated_at | type == "string")
      and (.milestones | type == "array")
      and (.active_tasks | type == "array")
      and (.blockers | type == "array")
      and (.shared_context | type == "object")
    ' "$file" >/dev/null 2>&1
}

ensure_default_gps() {
    local file="$1"
    if [ -f "$file" ]; then
        return 0
    fi

    cat > "$file" <<EOF
{
  "project": {
    "name": "Unknown",
    "main_objective": "To be defined",
    "owner": "unassigned",
    "target_date": null,
    "success_metric": "not defined",
    "status_updated_at": "$TIMESTAMP"
  },
  "milestones": [],
  "active_tasks": [],
  "blockers": [],
  "shared_context": {
    "architecture_decisions": [],
    "environment_variables_needed": []
  }
}
EOF
}

sanitize_line() {
    echo "$1" | tr '\n\r\t' '   ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

INPUT="$(cat)"
SUMMARY_RAW="$(printf '%s\n' "$INPUT" | jq -r '.response.output_text // .assistant_message // .output // empty' 2>/dev/null | head -n 1)"
SUMMARY="$(sanitize_line "${SUMMARY_RAW:-}")"
[ -z "$SUMMARY" ] && SUMMARY="No session summary provided"
SUMMARY="${SUMMARY:0:220}"

BLOCKERS_JSON="$(
    printf '%s\n' "$INPUT" \
    | jq -r '.response.output_text // .assistant_message // .output // empty' 2>/dev/null \
    | { grep -Ei '(^|\b)(blocker|blocked|cannot|failed|error:)' || true; } \
    | head -n 5 \
    | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' \
    | jq -Rsc 'split("\n") | map(select(length > 0))'
)"
[ -z "$BLOCKERS_JSON" ] && BLOCKERS_JSON='[]'

CHANGED_FILES_JSON='[]'
if [ -d "$PROJECT_DIR/.git" ]; then
    CHANGED_FILES_JSON="$(
        git -C "$PROJECT_DIR" status --porcelain 2>/dev/null \
        | awk '{print $2}' \
        | head -n 10 \
        | jq -Rsc 'split("\n") | map(select(length > 0))'
    )"
    [ -z "$CHANGED_FILES_JSON" ] && CHANGED_FILES_JSON='[]'
fi

ensure_default_gps "$GPS_FILE"

if [ "$BESTAI_DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] Would update GPS: $GPS_FILE (session=$SESSION_ID)" >&2
    emit_event "sync-gps" "DRY_RUN" "{\"session\":\"$SESSION_ID\"}" 2>/dev/null || true
    exit 0
fi

# Use a lock file to prevent concurrent writes from multiple agents
LOCKFILE="${GPS_FILE}.lock"
exec 200>"$LOCKFILE"
flock -x 200

TMP_FILE="$(mktemp)"
if jq \
  --arg ts "$TIMESTAMP" \
  --arg sid "$SESSION_ID" \
  --arg summary "$SUMMARY" \
  --argjson changed_files "$CHANGED_FILES_JSON" \
  --argjson blockers "$BLOCKERS_JSON" \
  '
    .project = (.project // {}) |
    .project.name = (.project.name // "Unknown") |
    .project.main_objective = (.project.main_objective // "To be defined") |
    .project.owner = (.project.owner // "unassigned") |
    .project.target_date = (.project.target_date // null) |
    .project.success_metric = (.project.success_metric // "not defined") |
    .project.status_updated_at = $ts |
    .milestones = (.milestones // []) |
    .active_tasks = (
      (.active_tasks // [])
      + [{
          "agent_id": $sid,
          "task": $summary,
          "status": "reported",
          "updated_at": $ts,
          "changed_files": $changed_files
        }]
    ) |
    .active_tasks = (.active_tasks | reverse | .[0:20]) |
    .blockers = ((.blockers // []) + $blockers | map(select(length > 0)) | unique | .[0:20]) |
    .shared_context = (.shared_context // {}) |
    .shared_context.last_session = {
      "updated_at": $ts,
      "agent_id": $sid,
      "summary": $summary,
      "changed_files": $changed_files
    }
  ' "$GPS_FILE" > "$TMP_FILE"; then
    mv "$TMP_FILE" "$GPS_FILE"
else
    rm -f "$TMP_FILE"
    echo "[bestAI] ERROR: Failed to update GPS JSON." >&2
    flock -u 200
    exit 2
fi

flock -u 200

if ! validate_gps_schema "$GPS_FILE"; then
    echo "[bestAI] BLOCKED: GPS schema validation failed after update." >&2
    exit 2
fi

echo "[bestAI] GPS synced: $GPS_FILE"
emit_event "sync-gps" "DONE" "{\"session\":\"$SESSION_ID\"}" 2>/dev/null || true
exit 0
