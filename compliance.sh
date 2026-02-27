#!/bin/bash
# compliance.sh — bestAI Compliance Dashboard
# Usage: bash compliance.sh [project-dir]

set -euo pipefail

TARGET="${1:-.}"
LOG_FILE="$TARGET/.claude/events.jsonl"

if [ ! -f "$LOG_FILE" ]; then
    echo "No event log found at $LOG_FILE. Run some hooks first!"
    exit 0
fi

echo "📊 bestAI Compliance Report"
echo "Project: $TARGET"
echo "-----------------------------------"

# TOTAL ACTIONS
TOTAL=$(wc -l < "$LOG_FILE")
BLOCKS=$(grep -c '"type":"BLOCK"' "$LOG_FILE" || echo 0)
ALLOWS=$(grep -c '"type":"ALLOW"' "$LOG_FILE" || echo 0)

# Calculate ratio
if [ "$TOTAL" -gt 0 ]; then
    COMPLIANCE_RATIO=$(( (ALLOWS * 100) / TOTAL ))
else
    COMPLIANCE_RATIO=100
fi

echo "Total Hook Events:  $TOTAL"
echo "Allowed Actions:    $ALLOWS"
echo "Blocked Bypasses:   $BLOCKS"
echo "Compliance Score:   $COMPLIANCE_RATIO%"
echo "-----------------------------------"

echo "Breakdown by Hook:"
jq -r '.hook' "$LOG_FILE" | sort | uniq -c | sort -nr

echo -e "\nRecent Blocked Actions:"
grep '"type":"BLOCK"' "$LOG_FILE" | tail -n 5 | jq -r '"[\(.timestamp)] \(.hook): \(.details.mode // "unknown") -> \(.details.file // "unknown")"'

if [ "$COMPLIANCE_RATIO" -lt 80 ]; then
    echo -e "\n🚨 \033[0;31mWARNING: Low compliance score. Agent is frequently attempting to bypass rules.\033[0m"
else
    echo -e "\n✅ \033[0;32mHealthy Compliance\033[0m"
fi
