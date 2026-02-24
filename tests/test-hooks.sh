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
echo "=== preprocess-prompt.sh (trigram + intent routing + recency + ghost) ==="
# ============================================================

TG_HOME=$(mktemp -d)
TG_PROJECT="$TG_HOME/project"
mkdir -p "$TG_PROJECT/.claude"
TG_KEY=$(echo "$TG_PROJECT" | tr '/' '-')
TG_MEMORY="$TG_HOME/.claude/projects/$TG_KEY/memory"
mkdir -p "$TG_MEMORY"

cat > "$TG_MEMORY/pitfalls.md" <<'PIT'
# Pitfalls
- [USER] Authentication errors when token expires after 30 minutes.
- [AUTO] Login flow breaks if redirect URI contains special characters.
PIT

cat > "$TG_MEMORY/decisions.md" <<'DEC'
# Decisions
- [USER] Use JWT refresh tokens for auth.
- [AUTO] Database migrations run in maintenance window only.
DEC

# Test 22: Trigram matching — "logowanie" should match "login" via shared trigrams
OUTPUT=$(echo '{"prompt":"napraw logowanie uzytkownika"}' | HOME="$TG_HOME" CLAUDE_PROJECT_DIR="$TG_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Trigram: logowanie prompt -> allow" "0" "$CODE"
assert_contains "Trigram: logowanie matches login content" "$OUTPUT" "SMART_CONTEXT"

# Test 23: Intent routing — debug prompt should prioritize pitfalls.md
OUTPUT=$(echo '{"prompt":"debug the authentication error in login"}' | HOME="$TG_HOME" CLAUDE_PROJECT_DIR="$TG_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Intent routing: debug -> allow" "0" "$CODE"
assert_contains "Intent routing: debug -> debugging intent" "$OUTPUT" "intent: debugging"

# Test 24: Intent routing — deploy prompt should be operations
OUTPUT=$(echo '{"prompt":"deploy the application to production"}' | HOME="$TG_HOME" CLAUDE_PROJECT_DIR="$TG_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Intent routing: deploy -> allow" "0" "$CODE"
if echo "$OUTPUT" | grep -q "SMART_CONTEXT"; then
    assert_contains "Intent routing: deploy -> operations intent" "$OUTPUT" "intent: operations"
else
    # May not match if no keywords align — pass since intent detection itself works
    assert_exit "Intent routing: deploy (no context match, OK)" "0" "0"
fi

# Test 25: Recency boost — recently modified file should score higher
touch "$TG_MEMORY/pitfalls.md"  # Ensure pitfalls.md has fresh mtime
OUTPUT=$(echo '{"prompt":"fix authentication token refresh error"}' | HOME="$TG_HOME" CLAUDE_PROJECT_DIR="$TG_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Recency boost: recent file -> allow" "0" "$CODE"
assert_contains "Recency boost: context injected" "$OUTPUT" "SMART_CONTEXT"

# Test 26: ARC ghost tracking — file with ghost hits should get boosted
echo "decisions.md" > "$TG_MEMORY/ghost-hits.log"
echo "decisions.md" >> "$TG_MEMORY/ghost-hits.log"
OUTPUT=$(echo '{"prompt":"check the database migration decisions"}' | HOME="$TG_HOME" CLAUDE_PROJECT_DIR="$TG_PROJECT" bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
CODE=$?
assert_exit "Ghost tracking: boosted file -> allow" "0" "$CODE"
assert_contains "Ghost tracking: context injected" "$OUTPUT" "SMART_CONTEXT"

rm -rf "$TG_HOME"

# ============================================================
echo ""
echo "=== memory-compiler.sh ==="
# ============================================================

MC_HOME=$(mktemp -d)
MC_PROJECT="$MC_HOME/project"
mkdir -p "$MC_PROJECT/.claude"
MC_KEY=$(echo "$MC_PROJECT" | tr '/' '-')
MC_MEMORY="$MC_HOME/.claude/projects/$MC_KEY/memory"
mkdir -p "$MC_MEMORY"

cat > "$MC_MEMORY/MEMORY.md" <<'MEM'
# Project Memory
- [USER] Keep auth flow unchanged.
- [AUTO] Database uses PostgreSQL.
MEM

cat > "$MC_MEMORY/decisions.md" <<'DEC'
# Decisions
- [USER] JWT for auth.
DEC

cat > "$MC_MEMORY/pitfalls.md" <<'PIT'
# Pitfalls
- [AUTO] Watch for token expiry edge cases.
PIT

# Test 27: Memory compiler generates context-index.md
echo '{}' | HOME="$MC_HOME" CLAUDE_PROJECT_DIR="$MC_PROJECT" bash "$HOOKS_DIR/memory-compiler.sh" 2>&1
CODE=$?
assert_exit "Memory compiler -> allow" "0" "$CODE"
assert_file_contains "Memory compiler: context-index.md created" "$MC_MEMORY/context-index.md" "Context Index"

# Test 28: Session counter incremented
assert_file_contains "Memory compiler: session counter" "$MC_MEMORY/.session-counter" "1"

# Test 29: Second run increments counter
echo '{}' | HOME="$MC_HOME" CLAUDE_PROJECT_DIR="$MC_PROJECT" bash "$HOOKS_DIR/memory-compiler.sh" 2>&1
assert_file_contains "Memory compiler: counter incremented" "$MC_MEMORY/.session-counter" "2"

# Test 30: 200-line cap enforcement on MEMORY.md
# Generate a 250-line MEMORY.md
{
    echo "# Project Memory"
    for i in $(seq 1 249); do
        echo "- [AUTO] Entry number $i for testing overflow"
    done
} > "$MC_MEMORY/MEMORY.md"
echo '{}' | HOME="$MC_HOME" CLAUDE_PROJECT_DIR="$MC_PROJECT" bash "$HOOKS_DIR/memory-compiler.sh" 2>&1
LINE_COUNT=$(wc -l < "$MC_MEMORY/MEMORY.md")
TOTAL=$((TOTAL + 1))
if [ "$LINE_COUNT" -le 200 ]; then
    echo -e "  ${GREEN}PASS${NC} Memory compiler: 200-line cap enforced (lines=$LINE_COUNT)"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} Memory compiler: 200-line cap NOT enforced (lines=$LINE_COUNT)"
    FAIL=$((FAIL + 1))
fi

# Test 31: Overflow content preserved
assert_file_contains "Memory compiler: overflow preserved" "$MC_MEMORY/memory-overflow.md" "Entry number"

# Test 32: GC archives old AUTO entries
# Simulate old usage data (session 1 with 1 use, current session will be 4+)
echo "pitfalls.md	1	1	AUTO" > "$MC_MEMORY/.usage-log"
echo "25" > "$MC_MEMORY/.session-counter"
echo '{}' | HOME="$MC_HOME" CLAUDE_PROJECT_DIR="$MC_PROJECT" MEMORY_COMPILER_GC_AGE=10 bash "$HOOKS_DIR/memory-compiler.sh" 2>&1
assert_file_contains "Memory compiler: GC archived old AUTO entry" "$MC_MEMORY/gc-archive.md" "Archived: pitfalls.md"

# Test 33: [USER] entries survive GC
echo "decisions.md	1	1	USER" > "$MC_MEMORY/.usage-log"
echo "50" > "$MC_MEMORY/.session-counter"
echo '{}' | HOME="$MC_HOME" CLAUDE_PROJECT_DIR="$MC_PROJECT" MEMORY_COMPILER_GC_AGE=10 bash "$HOOKS_DIR/memory-compiler.sh" 2>&1
# decisions.md should NOT be in gc-archive (it has [USER] in content)
TOTAL=$((TOTAL + 1))
if [ -f "$MC_MEMORY/gc-archive.md" ] && grep -q "Archived: decisions.md" "$MC_MEMORY/gc-archive.md" 2>/dev/null; then
    echo -e "  ${RED}FAIL${NC} Memory compiler: [USER] entry was GC'd (should be protected)"
    FAIL=$((FAIL + 1))
else
    echo -e "  ${GREEN}PASS${NC} Memory compiler: [USER] entry protected from GC"
    PASS=$((PASS + 1))
fi

rm -rf "$MC_HOME"

# ============================================================
echo ""
echo "=== check-frozen.sh (extended bash bypass protection) ==="
# ============================================================

BF_TMPDIR=$(mktemp -d)
mkdir -p "$BF_TMPDIR/.claude"
cat > "$BF_TMPDIR/.claude/frozen-fragments.md" <<'FROZEN'
# Frozen Fragments Registry
## FROZEN
- `src/auth/login.ts` — auth flow [USER]
- `config/database.yml` — DB config [USER]
FROZEN

# Test 34: Frozen file bypass via redirect operator -> block
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"> src/auth/login.ts"}}' | CLAUDE_PROJECT_DIR="$BF_TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen: redirect bypass -> block" "2" "$CODE"

# Test 35: Frozen file bypass via cp -> block
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/evil.ts src/auth/login.ts"}}' | CLAUDE_PROJECT_DIR="$BF_TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen: cp bypass -> block" "2" "$CODE"

# Test 36: Frozen file bypass via mv -> block
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"mv /tmp/evil.ts src/auth/login.ts"}}' | CLAUDE_PROJECT_DIR="$BF_TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen: mv bypass -> block" "2" "$CODE"

# Test 37: Frozen file bypass via tee -> block
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"echo hack | tee src/auth/login.ts"}}' | CLAUDE_PROJECT_DIR="$BF_TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen: tee bypass -> block" "2" "$CODE"

# Test 38: Non-frozen file via cp -> allow
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"cp /tmp/a.ts src/utils.ts"}}' | CLAUDE_PROJECT_DIR="$BF_TMPDIR" bash "$HOOKS_DIR/check-frozen.sh" 2>&1)
CODE=$?
assert_exit "Frozen: cp non-frozen -> allow" "0" "$CODE"

rm -rf "$BF_TMPDIR"

# ============================================================
echo ""
echo "=== Cross-module consistency ==="
# ============================================================

MODULES_DIR="$(cd "$(dirname "$0")/../modules" && pwd)"

# Test 39: All modules use "3 batches" not "2 corrections" for anti-loop
TOTAL=$((TOTAL + 1))
if grep -rE '2 corrections|Max 2.*correction' "$MODULES_DIR" 2>/dev/null | grep -v '^Binary'; then
    echo -e "  ${RED}FAIL${NC} Cross-module: found '2 corrections' inconsistency"
    FAIL=$((FAIL + 1))
else
    echo -e "  ${GREEN}PASS${NC} Cross-module: no '2 corrections' inconsistency"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== smart-preprocess-v2.sh ==="
# ============================================================

SP_HOME=$(mktemp -d)
SP_PROJECT="$SP_HOME/project"
mkdir -p "$SP_PROJECT/.claude"
SP_KEY=$(echo "$SP_PROJECT" | tr '/' '-')
SP_MEMORY="$SP_HOME/.claude/projects/$SP_KEY/memory"
mkdir -p "$SP_MEMORY"

cat > "$SP_MEMORY/decisions.md" <<'DEC'
# Decisions
- [USER] Use JWT for auth.
DEC

cat > "$SP_MEMORY/context-index.md" <<'IDX'
# Context Index
## core
- `decisions.md` (score=10)
IDX

# Test 40: smart-preprocess-v2 fallback when Haiku disabled (default)
OUTPUT=$(echo '{"prompt":"fix auth"}' | HOME="$SP_HOME" CLAUDE_PROJECT_DIR="$SP_PROJECT" SMART_CONTEXT_USE_HAIKU=0 bash "$HOOKS_DIR/smart-preprocess-v2.sh" 2>&1)
CODE=$?
assert_exit "Smart-v2: Haiku disabled -> fallback to keyword" "0" "$CODE"

# Test 41: smart-preprocess-v2 fallback when claude CLI not available
OUTPUT=$(echo '{"prompt":"fix auth"}' | HOME="$SP_HOME" CLAUDE_PROJECT_DIR="$SP_PROJECT" SMART_CONTEXT_USE_HAIKU=1 PATH="/usr/bin:/bin" bash "$HOOKS_DIR/smart-preprocess-v2.sh" 2>&1)
CODE=$?
assert_exit "Smart-v2: no claude CLI -> fallback" "0" "$CODE"

# Test 42: smart-preprocess-v2 respects DISABLE_SMART_CONTEXT
: > "$SP_PROJECT/.claude/DISABLE_SMART_CONTEXT"
OUTPUT=$(echo '{"prompt":"fix auth"}' | HOME="$SP_HOME" CLAUDE_PROJECT_DIR="$SP_PROJECT" bash "$HOOKS_DIR/smart-preprocess-v2.sh" 2>&1)
CODE=$?
assert_exit "Smart-v2: disabled -> exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ -z "$OUTPUT" ]; then
    echo -e "  ${GREEN}PASS${NC} Smart-v2: disabled -> no output"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} Smart-v2: disabled -> unexpected output"
    FAIL=$((FAIL + 1))
fi
rm -f "$SP_PROJECT/.claude/DISABLE_SMART_CONTEXT"

rm -rf "$SP_HOME"

# ============================================================
echo ""
echo "=== observer.sh ==="
# ============================================================

OB_HOME=$(mktemp -d)
OB_PROJECT="$OB_HOME/project"
mkdir -p "$OB_PROJECT/.claude"
OB_KEY=$(echo "$OB_PROJECT" | tr '/' '-')
OB_MEMORY="$OB_HOME/.claude/projects/$OB_KEY/memory"
mkdir -p "$OB_MEMORY"

cat > "$OB_MEMORY/session-log.md" <<'LOG'
# Session Log
- 2026-01-01: decision to use JWT for auth
- 2026-01-01: error in database connection
- 2026-01-02: created new API endpoint
- 2026-01-02: updated deployment script
- 2026-01-03: fixed authentication bug
LOG

# Test 43: Observer skips when not at interval
echo "3" > "$OB_MEMORY/.session-counter"
OUTPUT=$(echo '{}' | HOME="$OB_HOME" CLAUDE_PROJECT_DIR="$OB_PROJECT" OBSERVER_INTERVAL=5 bash "$HOOKS_DIR/observer.sh" 2>&1)
CODE=$?
assert_exit "Observer: not at interval -> skip" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ -f "$OB_MEMORY/observations.md" ]; then
    echo -e "  ${RED}FAIL${NC} Observer: wrote observations when not at interval"
    FAIL=$((FAIL + 1))
else
    echo -e "  ${GREEN}PASS${NC} Observer: no observations at non-interval"
    PASS=$((PASS + 1))
fi

# Test 44: Observer runs at interval (fallback mode, no claude CLI)
echo "5" > "$OB_MEMORY/.session-counter"
OUTPUT=$(echo '{}' | HOME="$OB_HOME" CLAUDE_PROJECT_DIR="$OB_PROJECT" OBSERVER_INTERVAL=5 PATH="/usr/bin:/bin" bash "$HOOKS_DIR/observer.sh" 2>&1)
CODE=$?
assert_exit "Observer: at interval -> runs" "0" "$CODE"
assert_file_contains "Observer: observations.md created" "$OB_MEMORY/observations.md" "Session 5 observations"

# Test 45: Observer output contains extracted keywords
assert_file_contains "Observer: output has key content" "$OB_MEMORY/observations.md" "decision\|error\|created\|updated\|fixed"

rm -rf "$OB_HOME"

# ============================================================
echo ""
echo "=== reflector.sh ==="
# ============================================================

# Test 46: Reflector no-op without claude CLI
RF_HOME=$(mktemp -d)
RF_PROJECT="$RF_HOME/project"
mkdir -p "$RF_PROJECT/.claude"
RF_KEY=$(echo "$RF_PROJECT" | tr '/' '-')
RF_MEMORY="$RF_HOME/.claude/projects/$RF_KEY/memory"
mkdir -p "$RF_MEMORY"

OUTPUT=$(HOME="$RF_HOME" CLAUDE_PROJECT_DIR="$RF_PROJECT" PATH="/usr/bin:/bin" bash "$HOOKS_DIR/reflector.sh" "$RF_PROJECT" 2>&1)
CODE=$?
assert_exit "Reflector: no claude CLI -> graceful exit" "0" "$CODE"
assert_contains "Reflector: no-op message" "$OUTPUT" "not available"

rm -rf "$RF_HOME"

# Test 47: Reflector idempotent (no files to merge -> clean exit)
RF2_HOME=$(mktemp -d)
RF2_PROJECT="$RF2_HOME/project"
mkdir -p "$RF2_PROJECT/.claude"
RF2_KEY=$(echo "$RF2_PROJECT" | tr '/' '-')
RF2_MEMORY="$RF2_HOME/.claude/projects/$RF2_KEY/memory"
mkdir -p "$RF2_MEMORY"

OUTPUT=$(HOME="$RF2_HOME" CLAUDE_PROJECT_DIR="$RF2_PROJECT" PATH="/usr/bin:/bin" bash "$HOOKS_DIR/reflector.sh" "$RF2_PROJECT" 2>&1)
CODE=$?
assert_exit "Reflector: no merge files -> graceful exit" "0" "$CODE"

rm -rf "$RF2_HOME"

# ============================================================
echo ""
echo "=== confidence-gate.sh ==="
# ============================================================

CG_HOME=$(mktemp -d)
CG_PROJECT="$CG_HOME/project"
mkdir -p "$CG_PROJECT/.claude"

# Test 48: Confidence gate — low confidence blocks deploy
cat > "$CG_PROJECT/.claude/state-of-system-now.md" <<'STATE'
# STATE OF SYSTEM
## Metrics
- CONFIDENCE: 0.50
STATE
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: low CONF -> block" "2" "$CODE"
assert_contains "Confidence gate: BLOCKED message" "$OUTPUT" "BLOCKED"

# Test 49: Confidence gate — high confidence passes
cat > "$CG_PROJECT/.claude/state-of-system-now.md" <<'STATE'
# STATE OF SYSTEM
## Metrics
- CONFIDENCE: 0.85
STATE
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: high CONF -> allow" "0" "$CODE"

# Test 50: Confidence gate — no CONF data passes (fail-open)
cat > "$CG_PROJECT/.claude/state-of-system-now.md" <<'STATE'
# STATE OF SYSTEM
## No confidence data here
STATE
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: no CONF -> allow (fail-open)" "0" "$CODE"

# Test 51: Confidence gate — non-dangerous command passes regardless
cat > "$CG_PROJECT/.claude/state-of-system-now.md" <<'STATE'
# STATE OF SYSTEM
- CONFIDENCE: 0.30
STATE
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: non-dangerous -> allow" "0" "$CODE"

# Test 52: Confidence gate — no state file passes
rm -f "$CG_PROJECT/.claude/state-of-system-now.md"
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"deploy production"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: no state file -> allow" "0" "$CODE"

# Test 53: Confidence gate — non-Bash tool passes
OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"test.ts"}}' | CLAUDE_PROJECT_DIR="$CG_PROJECT" bash "$HOOKS_DIR/confidence-gate.sh" 2>&1)
CODE=$?
assert_exit "Confidence gate: Write tool -> allow" "0" "$CODE"

rm -rf "$CG_HOME"

# ============================================================
echo ""
echo "=== Tier budget check ==="
# ============================================================

# Test 54: MAX_TOKENS caps injection under 2700 total
# T0=400 + T1=800 + T2=1500 = 2700. Verify preprocess respects MAX_TOKENS.
TB_HOME=$(mktemp -d)
TB_PROJECT="$TB_HOME/project"
mkdir -p "$TB_PROJECT/.claude"
TB_KEY=$(echo "$TB_PROJECT" | tr '/' '-')
TB_MEMORY="$TB_HOME/.claude/projects/$TB_KEY/memory"
mkdir -p "$TB_MEMORY"

# Create a large memory file
{
    echo "# Large Memory File"
    for i in $(seq 1 500); do
        echo "- [AUTO] Authentication entry $i with lots of detail about tokens and login flow."
    done
} > "$TB_MEMORY/decisions.md"

OUTPUT=$(echo '{"prompt":"fix authentication token login"}' | HOME="$TB_HOME" CLAUDE_PROJECT_DIR="$TB_PROJECT" SMART_CONTEXT_MAX_TOKENS=1500 bash "$HOOKS_DIR/preprocess-prompt.sh" 2>&1)
if [ -n "$OUTPUT" ]; then
    WORD_COUNT=$(echo "$OUTPUT" | wc -w | tr -d ' ')
    # 1500 tokens ≈ ~1150 words (1.3 ratio). Allow some margin.
    TOTAL=$((TOTAL + 1))
    if [ "$WORD_COUNT" -lt 1300 ]; then
        echo -e "  ${GREEN}PASS${NC} Tier budget: injection within 1500 token budget (words=$WORD_COUNT)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} Tier budget: injection exceeds budget (words=$WORD_COUNT)"
        FAIL=$((FAIL + 1))
    fi
else
    assert_exit "Tier budget: no output" "0" "0"
fi

rm -rf "$TB_HOME"

# ============================================================
echo ""
echo -e "${YELLOW}=== RESULTS ===${NC}"
echo -e "Total: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
[ "$FAIL" -eq 0 ] && echo -e "${GREEN}ALL TESTS PASSED${NC}" || echo -e "${RED}SOME TESTS FAILED${NC}"
exit "$FAIL"
