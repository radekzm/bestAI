#!/bin/bash
# tools/hook-lint.sh — Hook Composition and Latency Validator
# Usage: bash tools/hook-lint.sh [project-dir]

set -euo pipefail

TARGET="${1:-.}"
HOOKS_DIR="$TARGET/.claude/hooks"
SETTINGS_FILE="$TARGET/.claude/settings.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}🔍 bestAI Hook Linter & Latency Profiler${NC}"
echo "Project: $TARGET"
echo "------------------------------------------------"

if [ ! -d "$HOOKS_DIR" ]; then
    echo -e "${RED}Error: Hooks directory not found ($HOOKS_DIR)${NC}"
    exit 1
fi

ISSUES=0

# 1. Dependency & Composition Graph
echo -e "${BOLD}[1] Composition Checks${NC}"

has_hook() {
    [ -x "$HOOKS_DIR/$1" ]
}

if has_hook "circuit-breaker-gate.sh" && ! has_hook "circuit-breaker.sh"; then
    echo -e "  ${RED}FAIL${NC} circuit-breaker-gate.sh requires circuit-breaker.sh to track state."
    ISSUES=$((ISSUES + 1))
else
    echo -e "  ${GREEN}PASS${NC} Circuit Breaker composition valid."
fi

if has_hook "sync-gps.sh" && [ ! -f "$TARGET/.bestai/GPS.json" ]; then
    echo -e "  ${YELLOW}WARN${NC} sync-gps.sh is active but .bestai/GPS.json is missing."
fi

if has_hook "confidence-gate.sh" && ! has_hook "sync-state.sh"; then
    echo -e "  ${YELLOW}WARN${NC} confidence-gate.sh works best when sync-state.sh maintains CONFIDENCE metrics."
fi

# 2. Latency Profiling (Budget < 200ms)
echo -e "\n${BOLD}[2] Latency Budget Profiling (Target: < 200ms)${NC}"
echo "Simulating mock executions..."

for hook in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook" ] || continue
    hook_name=$(basename "$hook")
    
    # Mock payload depending on hook type
    payload="{}"
    if [[ "$hook_name" == *"frozen"* || "$hook_name" == *"secret"* ]]; then
        payload='{"tool_name":"Bash","tool_input":{"command":"echo test"}}'
    elif [[ "$hook_name" == *"prompt"* ]]; then
        payload='{"prompt":"test"}'
    fi
    
    # Measure time
    start_ts=$(date +%s%3N)
    echo "$payload" | bash "$hook" >/dev/null 2>&1 || true
    end_ts=$(date +%s%3N)
    
    duration=$((end_ts - start_ts))
    
    if [ "$duration" -gt 500 ]; then
        echo -e "  ${RED}[${duration}ms]${NC} $hook_name (CRITICAL: >500ms!)"
        ISSUES=$((ISSUES + 1))
    elif [ "$duration" -gt 200 ]; then
        echo -e "  ${YELLOW}[${duration}ms]${NC} $hook_name (WARN: >200ms budget)"
    else
        echo -e "  ${GREEN}[${duration}ms]${NC} $hook_name"
    fi
done

echo "------------------------------------------------"
if [ "$ISSUES" -gt 0 ]; then
    echo -e "${RED}Linter found $ISSUES composition/latency issues.${NC}"
    exit 1
else
    echo -e "${GREEN}All checks passed. Hook composition is healthy and fast.${NC}"
    exit 0
fi
