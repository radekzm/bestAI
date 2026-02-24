#!/bin/bash
# tests/test-hooks.sh — Automated tests for bestAI hooks
# Run: bash tests/test-hooks.sh
# All hooks are tested against realistic Claude Code hook protocol JSON.

set -uo pipefail
# NOTE: no -e because we test hooks that return non-zero exit codes

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
PASS=0
FAIL=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_exit() {
    local name="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        echo -e "  ${GREEN}PASS${NC} $name (exit=$actual)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (expected exit=$expected, got exit=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1" output="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$output" | grep -q "$expected"; then
        echo -e "  ${GREEN}PASS${NC} $name (contains '$expected')"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (missing '$expected')"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== check-frozen.sh ==="
# ============================================================

# Test 1: No frozen registry → allow (exit 0)
bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/app.ts\",\"content\":\"x\"}}" | CLAUDE_PROJECT_DIR=/tmp/nonexistent bash '"$HOOKS_DIR"'/check-frozen.sh' 2>/dev/null
assert_exit "No frozen registry → allow" "0" "$?"

# Test 2: Empty input → allow (exit 0)
bash -c 'echo "{}" | bash '"$HOOKS_DIR"'/check-frozen.sh' 2>/dev/null
assert_exit "Empty input → allow" "0" "$?"

# Test 3: Frozen file → block (exit 2)
TMPDIR=$(mktemp -d)
FROZEN_DIR="$TMPDIR/.claude"
mkdir -p "$FROZEN_DIR"
cat > "$FROZEN_DIR/frozen-fragments.md" << 'FROZEN'
# Frozen Fragments Registry
## FROZEN
- `src/auth/login.ts` — auth flow [USER]
- `config/database.yml` — DB config [USER]
FROZEN

OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts","content":"hack"}}' | CLAUDE_PROJECT_DIR="$TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1 || true)
LAST_EXIT=$?
# The exit code gets eaten by the subshell, test via output
if echo "$OUTPUT" | grep -q "BLOCKED"; then
    assert_exit "Frozen file → block" "2" "2"
else
    assert_exit "Frozen file → block" "2" "0"
fi

# Test 4: Non-frozen file with registry → allow (exit 0)
bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/utils.ts\",\"content\":\"ok\"}}" | CLAUDE_PROJECT_DIR='"$TMPDIR"' bash '"$HOOKS_DIR"'/check-frozen.sh' 2>/dev/null
assert_exit "Non-frozen file → allow" "0" "$?"

rm -rf "$TMPDIR"

# ============================================================
echo ""
echo "=== backup-enforcement.sh ==="
# ============================================================

# Clean up any leftover flags
rm -f /tmp/claude-backup-done-* 2>/dev/null

# Test 5: Deploy without backup → block (exit 2)
bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"deploy production\"}}" | CLAUDE_PROJECT_DIR=/tmp/test-project bash '"$HOOKS_DIR"'/backup-enforcement.sh' 2>/dev/null
assert_exit "Deploy without backup → block" "2" "$?"

# Test 6: Non-destructive command → allow (exit 0)
bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls -la\"}}" | bash '"$HOOKS_DIR"'/backup-enforcement.sh' 2>/dev/null
assert_exit "Non-destructive → allow" "0" "$?"

# Test 7: Deploy with backup flag → allow (exit 0)
PROJECT_HASH=$(echo "/tmp/test-project" | md5sum 2>/dev/null | cut -c1-16 || echo "default")
touch "/tmp/claude-backup-done-${PROJECT_HASH}"
bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"deploy production\"}}" | CLAUDE_PROJECT_DIR=/tmp/test-project bash '"$HOOKS_DIR"'/backup-enforcement.sh' 2>/dev/null
assert_exit "Deploy with backup → allow" "0" "$?"
rm -f "/tmp/claude-backup-done-${PROJECT_HASH}" 2>/dev/null

# Test 8: Empty command → allow (exit 0)
bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"\"}}" | bash '"$HOOKS_DIR"'/backup-enforcement.sh' 2>/dev/null
assert_exit "Empty command → allow" "0" "$?"

# ============================================================
echo ""
echo "=== wal-logger.sh ==="
# ============================================================

WAL_TEST_DIR=$(mktemp -d)
WAL_PROJECT="$WAL_TEST_DIR/test-wal"
mkdir -p "$WAL_PROJECT"

# Test 9: Destructive command → logged
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/old"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
WAL_FILE=$(find "$WAL_TEST_DIR" -name "wal.log" 2>/dev/null | head -1)
if [ -n "$WAL_FILE" ] && grep -q "DESTRUCTIVE" "$WAL_FILE" 2>/dev/null; then
    assert_exit "Destructive → logged" "0" "0"
else
    assert_exit "Destructive → logged" "0" "1"
fi

# Test 10: Non-destructive bash → not logged
LINES_BEFORE=$(wc -l < "$WAL_FILE" 2>/dev/null || echo 0)
echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
LINES_AFTER=$(wc -l < "$WAL_FILE" 2>/dev/null || echo 0)
if [ "$LINES_BEFORE" = "$LINES_AFTER" ]; then
    assert_exit "Non-destructive → not logged" "0" "0"
else
    assert_exit "Non-destructive → not logged" "0" "1"
fi

# Test 11: Write tool → logged
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
if grep -q "WRITE.*test.ts" "$WAL_FILE" 2>/dev/null; then
    assert_exit "Write tool → logged" "0" "0"
else
    assert_exit "Write tool → logged" "0" "1"
fi

rm -rf "$WAL_TEST_DIR"

# ============================================================
echo ""
echo "=== circuit-breaker.sh ==="
# ============================================================

# Clean state
rm -rf "${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-circuit-breaker" 2>/dev/null

# Test 12: Success → no output, exit 0
bash -c 'echo "{\"tool_name\":\"Bash\",\"exit_code\":\"0\",\"tool_output\":{\"stderr\":\"\"}}" | bash '"$HOOKS_DIR"'/circuit-breaker.sh' 2>/dev/null
assert_exit "Success → allow" "0" "$?"

# Test 13: First failure → exit 0 (tracking started)
bash -c 'echo "{\"tool_name\":\"Bash\",\"exit_code\":\"1\",\"tool_output\":{\"stderr\":\"Error: file not found\"}}" | bash '"$HOOKS_DIR"'/circuit-breaker.sh' 2>/dev/null
assert_exit "First failure → track" "0" "$?"

# Test 14: Three failures → OPEN state advisory
OUTPUT=""
for i in 1 2 3; do
    OUTPUT=$(echo '{"tool_name":"Bash","exit_code":"1","tool_output":{"stderr":"Error: file not found"}}' | bash "$HOOKS_DIR/circuit-breaker.sh" 2>&1 || true)
done
assert_contains "Three failures → OPEN advisory" "$OUTPUT" "Circuit Breaker"

rm -rf "${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-circuit-breaker" 2>/dev/null

# ============================================================
echo ""
echo -e "${YELLOW}=== RESULTS ===${NC}"
echo -e "Total: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
[ "$FAIL" -eq 0 ] && echo -e "${GREEN}ALL TESTS PASSED${NC}" || echo -e "${RED}SOME TESTS FAILED${NC}"
exit "$FAIL"
