#!/bin/bash
# hooks/lib-logging.sh — Shared logging library for bestAI hooks

log_event() {
    local hook_name="$1"
    local event_type="$2" # ALLOW, BLOCK, INFO, ERROR
    local details="$3"    # JSON object string
    
    local project_dir="${CLAUDE_PROJECT_DIR:-.}"
    local log_file="$project_dir/.claude/events.jsonl"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    mkdir -p "$(dirname "$log_file")"
    
    # Ensure details is valid JSON or empty object
    if [ -z "$details" ]; then details="{}"; fi
    
    # Append to JSONL
    printf '{"timestamp":"%s","hook":"%s","type":"%s","details":%s}
' 
        "$timestamp" "$hook_name" "$event_type" "$details" >> "$log_file"
}
