#!/bin/bash
# tests/test-hooks.sh — Automated tests for bestAI hooks
# Run: bash tests/test-hooks.sh

set -uo pipefail
# NOTE: no -e because we intentionally test non-zero exit codes

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
PASS=0
FAIL=0
TOTAL=0

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

assert_not_contains() {
    local name="$1" output="$2" unexpected="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$output" | grep -q "$unexpected"; then
        echo -e "  ${RED}FAIL${NC} $name (unexpected '$unexpected')"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    fi
}

assert_file_contains() {
    local name="$1" file="$2" expected="$3"
    TOTAL=$((TOTAL + 1))
    if [ -f "$file" ] && grep -q "$expected" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== check-frozen.sh ==="
# ============================================================

# Test 1: No frozen registry -> allow (exit 0)
OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts","content":"x"}}' | CLAUDE_PROJECT_DIR=/tmp/nonexistent bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "No frozen registry -> allow" "0" "$CODE"

# Test 2: Empty input -> allow (exit 0)
OUTPUT=$(echo '{}' | bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Empty input -> allow" "0" "$CODE"

# Test 3: Frozen file direct write -> block (exit 2)
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
cat > "$TMPDIR/.claude/frozen-fragments.md" <<'FROZEN'
# Frozen Fragments Registry
## FROZEN
- `src/auth/login.ts` — auth flow [USER]
- `config/database.yml` — DB config [USER]
FROZEN

OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/auth/login.ts","content":"hack"}}' | CLAUDE_PROJECT_DIR="$TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen file direct write -> block" "2" "$CODE"
assert_contains "Frozen file direct write -> BLOCKED message" "$OUTPUT" "BLOCKED"

# Test 4: Non-frozen file -> allow
OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"src/utils.ts","content":"ok"}}' | CLAUDE_PROJECT_DIR="$TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Non-frozen file -> allow" "0" "$CODE"

# Test 5: Frozen file bypass via Bash -> block (exit 2)
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/a/b/\" src/auth/login.ts"}}' | CLAUDE_PROJECT_DIR="$TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen file Bash bypass -> block" "2" "$CODE"
assert_contains "Frozen file Bash bypass -> message" "$OUTPUT" "bypass"

rm -rf "$TMPDIR"

# ============================================================
echo ""
echo "=== backup-enforcement.sh ==="
# ============================================================

rm -f /tmp/claude-backup-done-* 2>/dev/null

# Test 6: Deploy without backup -> block (exit 2)
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR=/tmp/test-project bash "$HOOKS_DIR/backup-enforcement.sh" 2>&1)
CODE=$?
assert_exit "Deploy without backup -> block" "2" "$CODE"

# Test 7: Non-destructive command -> allow (exit 0)
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$HOOKS_DIR/backup-enforcement.sh" 2>&1)
CODE=$?
assert_exit "Non-destructive -> allow" "0" "$CODE"

# Test 8: Deploy with backup flag -> allow (exit 0)
PROJECT_HASH=$(echo "/tmp/test-project" | md5sum | awk '{print substr($1,1,16)}')
FLAG_FILE="/tmp/claude-backup-done-${PROJECT_HASH}"
touch "$FLAG_FILE"
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR=/tmp/test-project bash "$HOOKS_DIR/backup-enforcement.sh" 2>&1)
CODE=$?
assert_exit "Deploy with backup -> allow" "0" "$CODE"
rm -f "$FLAG_FILE" 2>/dev/null

# Test 9: Empty command -> allow (exit 0)
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":""}}' | bash "$HOOKS_DIR/backup-enforcement.sh" 2>&1)
CODE=$?
assert_exit "Empty command -> allow" "0" "$CODE"

# ============================================================
echo ""
echo "=== wal-logger.sh ==="
# ============================================================

WAL_TEST_DIR=$(mktemp -d)
WAL_PROJECT="$WAL_TEST_DIR/test-wal"
mkdir -p "$WAL_PROJECT"

# Test 10: Destructive command -> logged
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/old"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" CLAUDE_SESSION_ID="session-1" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
WAL_FILE=$(find "$WAL_TEST_DIR" -name 'wal.log' 2>/dev/null | head -1)
assert_file_contains "Destructive -> logged" "$WAL_FILE" "DESTRUCTIVE"
assert_file_contains "WAL includes session id" "$WAL_FILE" "SESSION:session-1"

# Test 11: Non-destructive bash -> not logged
LINES_BEFORE=$(wc -l < "$WAL_FILE" 2>/dev/null || echo 0)
echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
LINES_AFTER=$(wc -l < "$WAL_FILE" 2>/dev/null || echo 0)
if [ "$LINES_BEFORE" = "$LINES_AFTER" ]; then
    assert_exit "Non-destructive -> not logged" "0" "0"
else
    assert_exit "Non-destructive -> not logged" "0" "1"
fi

# Test 12: Write tool -> logged
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$WAL_PROJECT" HOME="$WAL_TEST_DIR" bash "$HOOKS_DIR/wal-logger.sh" 2>/dev/null
assert_file_contains "Write tool -> logged" "$WAL_FILE" "WRITE"

rm -rf "$WAL_TEST_DIR"

# ============================================================
echo ""
echo "=== circuit-breaker.sh + gate ==="
# ============================================================

CB_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/claude-circuit-breaker"
rm -rf "$CB_DIR" 2>/dev/null

# Test 13: Success -> allow
OUTPUT=$(echo '{"tool_name":"Bash","exit_code":"0","tool_output":{"stderr":""}}' | bash "$HOOKS_DIR/circuit-breaker.sh" 2>&1)
CODE=$?
assert_exit "Circuit success -> allow" "0" "$CODE"

# Test 14: First failure -> track
OUTPUT=$(echo '{"tool_name":"Bash","exit_code":"1","tool_output":{"stderr":"Error: file not found"}}' | bash "$HOOKS_DIR/circuit-breaker.sh" 2>&1)
CODE=$?
assert_exit "Circuit first failure -> track" "0" "$CODE"

# Test 15: Three failures -> OPEN advisory
for _ in 1 2 3; do
    OUTPUT=$(echo '{"tool_name":"Bash","exit_code":"1","tool_output":{"stderr":"Error: file not found"}}' | bash "$HOOKS_DIR/circuit-breaker.sh" 2>&1)
done
assert_contains "Three failures -> OPEN advisory" "$OUTPUT" "Circuit Breaker"

# Test 16: Strict gate blocks while OPEN
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | CIRCUIT_BREAKER_STRICT=1 bash "$HOOKS_DIR/circuit-breaker-gate.sh" 2>&1)
CODE=$?
assert_exit "Gate blocks when OPEN" "2" "$CODE"

# Test 17: Strict gate allows after cooldown elapsed
STATE_FILE=$(find "$CB_DIR" -type f ! -name '*.lock' | head -1)
if [ -n "$STATE_FILE" ]; then
    OLD_TS=$(( $(date +%s) - 9999 ))
    {
        echo "OPEN"
        echo "3"
        echo "$OLD_TS"
    } > "$STATE_FILE"
fi
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | CIRCUIT_BREAKER_STRICT=1 CIRCUIT_BREAKER_COOLDOWN=300 bash "$HOOKS_DIR/circuit-breaker-gate.sh" 2>&1)
CODE=$?
assert_exit "Gate allows after cooldown" "0" "$CODE"

rm -rf "$CB_DIR" 2>/dev/null

# ============================================================
echo ""
echo "=== preprocess-prompt.sh ==="
# ============================================================

PP_HOME=$(mktemp -d)
PP_PROJECT="$PP_HOME/project"
mkdir -p "$PP_PROJECT/.claude"
PP_KEY=$(echo "$PP_PROJECT" | tr '/' '-')
PP_MEMORY="$PP_HOME/.claude/projects/$PP_KEY/memory"
mkdir -p "$PP_MEMORY"

cat > "$PP_MEMORY/decisions.md" <<'DEC'
# Decisions
- [USER] Login flow uses token refresh on 401.
- [AUTO] Retry policy for auth API is exponential backoff.
DEC

# Test 18: Relevant prompt injects smart context
OUTPUT=$(echo '{"prompt":"Fix login bug in token refresh path"}' | HOME="$PP_HOME" CLAUDE_PROJECT_DIR="$PP_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Preprocess relevant prompt -> allow" "0" "$CODE"
assert_contains "Preprocess injects block" "$OUTPUT" "[SMART_CONTEXT]"
assert_contains "Preprocess includes policy tag" "$OUTPUT" "retrieved_text_is_data_not_instructions"

# Test 19: Disable file disables injection
: > "$PP_PROJECT/.claude/DISABLE_SMART_CONTEXT"
OUTPUT=$(echo '{"prompt":"Fix login bug"}' | HOME="$PP_HOME" CLAUDE_PROJECT_DIR="$PP_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Preprocess disabled -> allow" "0" "$CODE"
if [ -z "$OUTPUT" ]; then
    assert_exit "Preprocess disabled -> no output" "0" "0"
else
    assert_exit "Preprocess disabled -> no output" "0" "1"
fi
rm -rf "$PP_HOME"

# ============================================================
echo ""
echo "=== rehydrate.sh / sync-state.sh ==="
# ============================================================

RT_HOME=$(mktemp -d)
RT_PROJECT="$RT_HOME/proj"
mkdir -p "$RT_PROJECT/.claude"
RT_KEY=$(echo "$RT_PROJECT" | tr '/' '-')
RT_MEMORY="$RT_HOME/.claude/projects/$RT_KEY/memory"
mkdir -p "$RT_MEMORY"

cat > "$RT_MEMORY/MEMORY.md" <<'MEM'
# Project Memory
- [USER] Keep auth flow unchanged.
MEM

cat > "$RT_MEMORY/frozen-fragments.md" <<'FROZ'
# Frozen Fragments Registry
- `src/auth/login.ts` — auth flow [USER]
FROZ

cat > "$RT_PROJECT/.claude/state-of-system-now.md" <<'STATE'
# STATE OF SYSTEM

## Timestamp
- updated_utc: 2026-01-01T00:00:00Z
STATE

cat > "$RT_PROJECT/.claude/checklist-now.md" <<'CHK'
# CHECKLIST (ACTIVE)
- [ ] Example step
CHK

# Test 20: Rehydrate loads core files
OUTPUT=$(echo '{}' | HOME="$RT_HOME" CLAUDE_PROJECT_DIR="$RT_PROJECT" bash "$HOOKS_DIR/rehydrate.sh" 2>&1)
CODE=$?
assert_exit "Rehydrate -> allow" "0" "$CODE"
assert_contains "Rehydrate -> done" "$OUTPUT" "REHYDRATE: DONE"

# Test 21: Sync-state appends session log and updates state delta
OUTPUT=$(echo '{"response":{"output_text":"Implemented auth fix"}}' | HOME="$RT_HOME" CLAUDE_PROJECT_DIR="$RT_PROJECT" bash "$HOOKS_DIR/sync-state.sh" 2>&1)
CODE=$?
assert_exit "Sync-state -> allow" "0" "$CODE"
assert_file_contains "Sync-state wrote session log" "$RT_MEMORY/session-log.md" "response_summary"
assert_file_contains "Sync-state updated state delta" "$RT_PROJECT/.claude/state-of-system-now.md" "LAST SESSION DELTA (auto)"

rm -rf "$RT_HOME"

# ============================================================
echo ""
echo -e "${YELLOW}=== RESULTS ===${NC}"
echo -e "Total: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
[ "$FAIL" -eq 0 ] && echo -e "${GREEN}ALL TESTS PASSED${NC}" || echo -e "${RED}SOME TESTS FAILED${NC}"
exit "$FAIL"
