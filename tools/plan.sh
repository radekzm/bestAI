#!/bin/bash
# tools/plan.sh — bestAI Architect Mode (v1.4)
# Usage: bestai plan "Analyze the auth system"

set -euo pipefail

TASK="${1:-}"
if [ -z "$TASK" ]; then
    echo "Usage: bestai plan 'description'"
    exit 1
fi

echo -e "\033[1;34m🏛️ bestAI Architect Mode: Initializing High-Level Planning...\033[0m"
echo -e "\033[2m[SAFE] Code writing tools are temporarily restricted.\033[0m"

# We use the swarm dispatcher but force a specialized "Planning" prompt
# and a lower depth to save tokens.
bestai swarm --vendor gemini --task "ARCHITECT MODE: Create a detailed PROPOSAL.md for: $TASK. DO NOT edit or write code. Analyze only." --depth fast

echo -e "\n\033[1;32m✅ Proposal generated.\033[0m"
echo "Review PROPOSAL.md then use 'bestai permit' to allow implementation."
