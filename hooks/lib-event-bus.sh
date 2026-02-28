#!/bin/bash
# hooks/lib-event-bus.sh — Centralized Log Aggregator for Multi-Agent Swarms

emit_swarm_event() {
    local agent_id="${BESTAI_AGENT_ID:-unknown}"
    local hook="${1:-generic}"
    local type="${2:-INFO}"
    local msg="${3:-}"
    
    local bus_file=".bestai/event_bus.jsonl"
    mkdir -p .bestai
    
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Atomic append to central bus
    printf '{"ts":"%s","agent":"%s","hook":"%s","type":"%s","data":%s}
' 
        "$ts" "$agent_id" "$hook" "$type" "${msg:-"{}"}" >> "$bus_file"
}
