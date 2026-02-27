#!/bin/bash
# hooks/hook-event.sh — Shared JSONL event logging for all hooks
# Source this file from any hook: source "$(dirname "$0")/hook-event.sh"
#
# Usage:
#   emit_event "check-frozen" "BLOCK" '{"file":"auth.ts","mode":"direct"}'
#   emit_event "circuit-breaker" "OPEN" '{"sig":"grep_fail","count":3}'
#   emit_event "backup-enforcement" "ALLOW" '{}'
#
# Output: one JSON line per event to $BESTAI_EVENT_LOG
# Format: {"ts":"ISO","hook":"name","action":"BLOCK|ALLOW|OPEN|...","tool":"Bash|Edit|Write","project":"hash","detail":{...}}
#
# Env vars:
#   BESTAI_EVENT_LOG — override log path (default: ~/.cache/bestai/events.jsonl)
#   BESTAI_EVENT_LOG_DISABLED=1 — disable event logging entirely

# Guard against double-sourcing
[ "${_BESTAI_HOOK_EVENT_LOADED:-0}" = "1" ] && return 0
_BESTAI_HOOK_EVENT_LOADED=1

_bestai_project_hash() {
    local src="${CLAUDE_PROJECT_DIR:-.}"
    if command -v md5sum >/dev/null 2>&1; then
        echo "$src" | md5sum | awk '{print substr($1,1,16)}'
    elif command -v shasum >/dev/null 2>&1; then
        echo "$src" | shasum -a 256 | awk '{print substr($1,1,16)}'
    else
        echo "$src" | cksum | awk '{print $1}'
    fi
}

_BESTAI_PROJECT_HASH=$(_bestai_project_hash)

# Timestamp at source-time for latency measurement (nanoseconds if available, seconds otherwise)
if date +%s%N >/dev/null 2>&1 && [ "$(date +%s%N)" != "%N" ]; then
    _BESTAI_START_NS=$(date +%s%N)
    _BESTAI_HAS_NS=1
else
    _BESTAI_START_NS=$(date +%s)
    _BESTAI_HAS_NS=0
fi

# Returns elapsed milliseconds since hook-event.sh was sourced.
_bestai_elapsed_ms() {
    if [ "$_BESTAI_HAS_NS" = "1" ]; then
        local now_ns
        now_ns=$(date +%s%N)
        echo $(( (now_ns - _BESTAI_START_NS) / 1000000 ))
    else
        local now_s
        now_s=$(date +%s)
        echo $(( (now_s - _BESTAI_START_NS) * 1000 ))
    fi
}

if [ -z "${BESTAI_EVENT_LOG:-}" ]; then
    _BESTAI_EVENT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bestai"
    BESTAI_EVENT_LOG="$_BESTAI_EVENT_DIR/events.jsonl"
else
    _BESTAI_EVENT_DIR="${BESTAI_EVENT_LOG%/*}"
fi

# Resolve the tool name from hook input if available.
# Callers may set _BESTAI_TOOL_NAME before sourcing or calling emit_event.
_bestai_resolve_tool() {
    echo "${_BESTAI_TOOL_NAME:-unknown}"
}

# emit_event HOOK_NAME ACTION [DETAIL_JSON]
#   HOOK_NAME: e.g. "check-frozen", "circuit-breaker", "backup-enforcement"
#   ACTION: e.g. "BLOCK", "ALLOW", "OPEN", "CLOSED", "HALF_OPEN", "ERROR"
#   DETAIL_JSON: optional JSON object string (default: "{}")
emit_event() {
    [ "${BESTAI_EVENT_LOG_DISABLED:-0}" = "1" ] && return 0

    local hook="${1:?emit_event requires hook name}"
    local action="${2:?emit_event requires action}"
    local detail="${3:-{\}}"
    local ts tool elapsed_ms

    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    tool=$(_bestai_resolve_tool)
    elapsed_ms=$(_bestai_elapsed_ms)

    mkdir -p "$_BESTAI_EVENT_DIR" 2>/dev/null || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -cn \
            --arg ts "$ts" \
            --arg hook "$hook" \
            --arg action "$action" \
            --arg tool "$tool" \
            --arg project "$_BESTAI_PROJECT_HASH" \
            --argjson elapsed_ms "$elapsed_ms" \
            --argjson detail "$detail" \
            '{ts:$ts,hook:$hook,action:$action,tool:$tool,project:$project,elapsed_ms:$elapsed_ms,detail:$detail}' \
            >> "$BESTAI_EVENT_LOG" 2>/dev/null || true
    else
        printf '{"ts":"%s","hook":"%s","action":"%s","tool":"%s","project":"%s","elapsed_ms":%s,"detail":%s}\n' \
            "$ts" "$hook" "$action" "$tool" "$_BESTAI_PROJECT_HASH" "$elapsed_ms" "$detail" \
            >> "$BESTAI_EVENT_LOG" 2>/dev/null || true
    fi
}

# Convenience: rotate event log when it exceeds MAX_EVENTS lines.
# Call from Stop hooks or periodically.
rotate_event_log() {
    local max_events="${1:-5000}"
    [ ! -f "$BESTAI_EVENT_LOG" ] && return 0

    local count
    count=$(wc -l < "$BESTAI_EVENT_LOG" 2>/dev/null | tr -d ' ')
    [ "$count" -le "$max_events" ] && return 0

    local keep=$((max_events * 4 / 5))  # keep 80%
    local archive="${BESTAI_EVENT_LOG%.jsonl}-archive.jsonl"
    local tmp
    tmp=$(mktemp)

    head -n "$((count - keep))" "$BESTAI_EVENT_LOG" >> "$archive"
    tail -n "$keep" "$BESTAI_EVENT_LOG" > "$tmp"
    mv "$tmp" "$BESTAI_EVENT_LOG"
}
