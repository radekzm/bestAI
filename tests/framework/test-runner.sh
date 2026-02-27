#!/bin/bash
# tests/framework/test-runner.sh
# Micro-framework for testing bestAI hooks in isolation.

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

PASS_COUNT=0
FAIL_COUNT=0

export BESTAI_TEST_MODE=1
TEST_TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

describe() {
    echo -e "
${BOLD}==> $1${NC}"
}

it() {
    echo -n "  - $1... "
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" == "$actual" ]; then
        echo -e "${GREEN}PASS${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC}"
        echo -e "    Expected: $expected
    Actual:   $actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_hook() {
    local hook_path="$1"
    local input_json="$2"
    
    # Run hook with mocked stdin
    set +e
    output=$(echo "$input_json" | bash "$hook_path" 2>&1)
    exit_code=$?
    set -e
    
    echo "$exit_code|$output"
}

expect_block() {
    local result="$1"
    local code="${result%%|*}"
    if [ "$code" -eq 2 ]; then
        echo -e "${GREEN}PASS (Blocked)${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL (Should have blocked, got code $code)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

expect_allow() {
    local result="$1"
    local code="${result%%|*}"
    if [ "$code" -eq 0 ]; then
        echo -e "${GREEN}PASS (Allowed)${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL (Should have allowed, got code $code)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

report() {
    echo -e "
${BOLD}Test Summary:${NC}"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}, ${RED}Failed: $FAIL_COUNT${NC}"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    fi
}
