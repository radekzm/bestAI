#!/bin/bash
# tools/budget-monitor.sh
# Real-time token usage tracking and budget limit enforcer.

set -euo pipefail

LOG_FILE="${1:-}"
LIMIT_TOKENS=${2:-1000000} # Default 1M tokens

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    echo "Usage: bash budget-monitor.sh <path-to-cache-usage.jsonl> [limit-tokens]"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required."
    exit 1
fi

echo "📊 bestAI Context Budget Monitor"
echo "Monitoring: $LOG_FILE"
echo "Budget Limit: $LIMIT_TOKENS tokens"
echo "-----------------------------------"

# Calculate totals
TOTAL_INPUT=$(jq -s 'map(.usage.input_tokens // .input_tokens // 0 | tonumber) | add' "$LOG_FILE")
TOTAL_OUTPUT=$(jq -s 'map(.usage.output_tokens // .output_tokens // 0 | tonumber) | add' "$LOG_FILE")
TOTAL_CACHED=$(jq -s 'map(.usage.prompt_tokens_details.cached_tokens // .cached_tokens // 0 | tonumber) | add' "$LOG_FILE")

TOTAL=$((TOTAL_INPUT + TOTAL_OUTPUT))
PERCENT=$((TOTAL * 100 / LIMIT_TOKENS))

echo "Input Tokens:  $TOTAL_INPUT"
echo "Output Tokens: $TOTAL_OUTPUT"
echo "Cached Reads:  $TOTAL_CACHED"
echo "-----------------------------------"
echo "Total Usage:   $TOTAL / $LIMIT_TOKENS ($PERCENT%)"

if [ "$TOTAL" -gt "$LIMIT_TOKENS" ]; then
    echo -e "
🚨 \033[0;31mBUDGET EXCEEDED!\033[0m"
    echo "Consider running 'memory-compiler' or stopping the agent."
    exit 2
else
    echo -e "
✅ \033[0;32mBudget OK\033[0m"
    exit 0
fi
