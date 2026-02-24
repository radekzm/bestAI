#!/bin/bash
# evals/report.sh — Generate pass/fail report from eval results
# Usage: bash evals/report.sh [results-dir]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${1:-$ROOT_DIR/evals/results}"
SCENARIOS_DIR="$ROOT_DIR/evals/scenarios"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}bestAI Evals Report${NC}"
echo "Results: $RESULTS_DIR"
echo "Scenarios: $SCENARIOS_DIR"
echo ""

# Count scenarios
SCENARIO_COUNT=0
if [ -d "$SCENARIOS_DIR" ]; then
    SCENARIO_COUNT=$(find "$SCENARIOS_DIR" -name '*.md' -type f | wc -l)
fi
echo -e "${BOLD}Scenarios defined: $SCENARIO_COUNT${NC}"

# List scenario categories
if [ "$SCENARIO_COUNT" -gt 0 ]; then
    echo ""
    echo "| Scenario | Category | Tasks |"
    echo "|----------|----------|------:|"
    while IFS= read -r scenario; do
        name=$(basename "$scenario" .md)
        category=$(grep -m1 '^## Category:' "$scenario" 2>/dev/null | sed 's/## Category: //' || echo "unknown")
        tasks=$(grep -c '^### ' "$scenario" 2>/dev/null || echo 0)
        echo "| $name | $category | $tasks |"
    done < <(find "$SCENARIOS_DIR" -name '*.md' -type f | sort)
fi

# Parse latest results
echo ""
LATEST_MD=$(find "$RESULTS_DIR" -name '*.md' -type f | sort | tail -1)
LATEST_JSON=$(find "$RESULTS_DIR" -name '*.json' -type f ! -name 'README*' | sort | tail -1)

if [ -z "$LATEST_MD" ] && [ -z "$LATEST_JSON" ]; then
    echo -e "${YELLOW}No results found. Run: bash evals/run.sh${NC}"
    exit 0
fi

if [ -n "$LATEST_JSON" ] && command -v jq &>/dev/null; then
    echo -e "${BOLD}Latest Results: $(basename "$LATEST_JSON")${NC}"
    echo ""

    for profile in baseline hooks_only smart_context; do
        display_name=$(echo "$profile" | tr '_' '-')
        success=$(jq -r ".metrics.${profile}.success_rate // \"N/A\"" "$LATEST_JSON")
        runs=$(jq -r ".metrics.${profile}.runs // \"N/A\"" "$LATEST_JSON")
        tokens=$(jq -r ".metrics.${profile}.avg_total_tokens // \"N/A\"" "$LATEST_JSON")

        if [ "$success" != "N/A" ] && [ "$success" != "null" ]; then
            formatted=$(awk -v s="$success" 'BEGIN { printf "%.1f%%", s }')
            echo -e "  $display_name: ${BOLD}$formatted${NC} success ($runs runs, avg $tokens tokens)"
        fi
    done
fi

# Hook test results
echo ""
echo -e "${BOLD}Hook Tests${NC}"
if bash "$ROOT_DIR/tests/test-hooks.sh" 2>&1 | tail -3; then
    echo -e "  ${GREEN}Hook tests passed${NC}"
else
    echo -e "  ${RED}Hook tests failed${NC}"
fi

echo ""
echo "Run full benchmark: bash evals/run.sh"
echo "Run hook tests:     bash tests/test-hooks.sh"
