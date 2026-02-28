#!/bin/bash
# hooks/lib-dryrun.sh — Shared dry-run utility for bestAI hooks

check_dryrun() {
    # If BESTAI_DRY_RUN=1 is set, hooks should log but NOT exit with code 2.
    if [ "${BESTAI_DRY_RUN:-0}" = "1" ]; then
        return 0 # Dry run active
    fi
    return 1 # Normal enforcement
}

block_or_log() {
    local message="$1"
    if check_dryrun; then
        echo "[bestAI] [DRY-RUN] Would block: $message" >&2
        exit 0
    else
        echo "[bestAI] BLOCKED: $message" >&2
        exit 2
    fi
}
