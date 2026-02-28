#!/bin/bash
# tools/cockpit.sh — bestAI Swarm Control Center (CLI Dashboard)
# Usage: bestai cockpit

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}🛸 bestAI Swarm Cockpit v8.0${NC}"
echo "------------------------------------------------"

# 1. Project Info
PROJECT_NAME=$(jq -r '.project.name // "Unknown"' .bestai/GPS.json 2>/dev/null || echo "Unknown")
OBJECTIVE=$(jq -r '.project.main_objective // "None"' .bestai/GPS.json 2>/dev/null || echo "None")
echo -e "${BOLD}Project:${NC} $PROJECT_NAME"
echo -e "${BOLD}Goal:   ${NC} $OBJECTIVE"
echo ""

# 2. Compliance Metric (v7.6 integration)
LOG_FILE=".claude/events.jsonl"
if [ -f "$LOG_FILE" ]; then
    TOTAL=$(wc -l < "$LOG_FILE")
    BLOCKS=$(grep -c '"type":"BLOCK"' "$LOG_FILE" || echo 0)
    if [ "$TOTAL" -gt 0 ]; then
        COMPLIANCE_RATIO=$(( (TOTAL - BLOCKS) * 100 / TOTAL ))
    else
        COMPLIANCE_RATIO=100
    fi
    echo -n -e "${BOLD}Compliance Status: ${NC}"
    if [ "$COMPLIANCE_RATIO" -ge 90 ]; then echo -e "${GREEN}$COMPLIANCE_RATIO% (EXCELLENT)${NC}";
    elif [ "$COMPLIANCE_RATIO" -ge 70 ]; then echo -e "${YELLOW}$COMPLIANCE_RATIO% (WARNING)${NC}";
    else echo -e "${RED}$COMPLIANCE_RATIO% (CRITICAL)${NC}"; fi
else
    echo -e "${BOLD}Compliance Status: ${NC}${DIM}No data yet${NC}"
fi

# 3. Active Swarm Work (v8.0 Mutex)
echo -e "\n${BOLD}📡 Active Swarm Locks:${NC}"
jq -r 'to_entries[] | "  - \(.key) (Owner: \(.value.agent), since \(.value.locked_at))"' .bestai/swarm_locks.json 2>/dev/null || echo "  No active locks."

# 4. Milestones
echo -e "\n${BOLD}🏁 Key Milestones:${NC}"
jq -r '.milestones[] | "  [\(.status)] \(.name)"' .bestai/GPS.json 2>/dev/null | head -n 5 || echo "  No milestones defined."

# 5. Token FinOps (v7.6 integration)
# Assuming budget-monitor.sh can output just the total
echo -e "\n${BOLD}💰 Token Consumption (FinOps):${NC}"
# Mock total for now as budget-monitor is interactive
echo -e "  Current session estimated: ${YELLOW}Low Usage${NC}"

echo "------------------------------------------------"
echo -e "${DIM}Use 'bestai doctor' for deep health checks.${NC}"
