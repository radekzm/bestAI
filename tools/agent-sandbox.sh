#!/bin/bash
# tools/agent-sandbox.sh — bestAI Agent Containerization (v8.0)
# Usage: bestai sandbox --cmd "bash my-script.sh"

set -euo pipefail

COMMAND="${1:-}"
if [ "$COMMAND" = "--cmd" ]; then
    CMD_TO_RUN="${2:-}"
else
    echo "Usage: bestai sandbox --cmd 'command'"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "[bestAI] 🛑 Docker not found. Cannot run sandbox."
    exit 1
fi

echo "[bestAI] 🛡️ Spawning sandbox for command: $CMD_TO_RUN"

# We mount only current directory as read-only for safety (except .claude for logging)
docker run --rm 
    -v "$(pwd):/work:ro" 
    -v "$(pwd)/.claude:/work/.claude:rw" 
    -w /work 
    alpine:latest 
    sh -c "apk add --no-cache bash jq && $CMD_TO_RUN"
