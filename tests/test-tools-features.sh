#!/bin/bash
# tests/test-tools-features.sh — smoke tests for tool-level features
# Run: bash tests/test-tools-features.sh

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER="$ROOT_DIR/tools/task-router.sh"
BINDING="$ROOT_DIR/tools/task-memory-binding.sh"
VALIDATE="$ROOT_DIR/tools/validate-shared-context.sh"

PASS=0
FAIL=0
SKIP=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TMP_ROOT="$(mktemp -d /tmp/bestai-tools-features.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PROJECT_TMP="$TMP_ROOT/project"
EVENT_LOG="$TMP_ROOT/events.jsonl"
mkdir -p "$PROJECT_TMP"
: > "$EVENT_LOG"

assert_exit() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}PASS${NC} $name (exit=$actual)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (expected=$expected, got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1"
    local haystack="$2"
    local needle="$3"
    if printf '%s' "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $name (contains '$needle')"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (missing '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_jq() {
    local name="$1"
    local json_payload="$2"
    local jq_expr="$3"
    if printf '%s' "$json_payload" | jq -e "$jq_expr" >/dev/null 2>&1; then
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (jq expr failed: $jq_expr)"
        FAIL=$((FAIL + 1))
    fi
}

skip_test() {
    local name="$1"
    local reason="$2"
    echo -e "  ${YELLOW}SKIP${NC} $name ($reason)"
    SKIP=$((SKIP + 1))
}

require_file() {
    local path="$1"
    if [ ! -f "$path" ]; then
        echo "Required file not found: $path" >&2
        exit 1
    fi
}

require_cmd() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        echo "Required command not found: $name" >&2
        exit 1
    fi
}

require_cmd jq
require_file "$ROUTER"
require_file "$BINDING"
require_file "$VALIDATE"

echo "=== task-router --json ==="
ROUTE_OUTPUT=$(BESTAI_EVENT_LOG="$EVENT_LOG" bash "$ROUTER" --task "Audit auth module and propose fixes" --project-dir "$PROJECT_TMP" --json 2>&1)
ROUTE_CODE=$?
assert_exit "task-router exits 0" "0" "$ROUTE_CODE"
if [ "$ROUTE_CODE" = "0" ]; then
    assert_jq "task-router JSON has policy/history/event_signal" "$ROUTE_OUTPUT" '(.policy|type=="object") and (.history|type=="object") and (.event_signal|type=="object")'
fi

echo ""
echo "=== task-memory-binding --json ==="
BIND_OUTPUT=$(bash "$BINDING" --task "Need context for auth policy decisions" --project-dir "$PROJECT_TMP" --json 2>&1)
BIND_CODE=$?
assert_exit "task-memory-binding exits 0" "0" "$BIND_CODE"
if [ "$BIND_CODE" = "0" ]; then
    assert_jq "task-memory-binding JSON has metadata + count fields" "$BIND_OUTPUT" '(.metadata|type=="object")
      and (.hard_count|type=="number")
      and (.soft_count|type=="number")
      and (.overridden_count|type=="number")
      and (.dropped_expired_count|type=="number")
      and (.metadata.hard_count|type=="number")
      and (.metadata.soft_count|type=="number")
      and (.metadata.overridden_count|type=="number")
      and (.metadata.dropped_expired_count|type=="number")'
fi

echo ""
echo "=== validate-shared-context invalid timestamps ==="
INVALID_CONTEXT="$TMP_ROOT/invalid-timestamps.json"
cat > "$INVALID_CONTEXT" <<'JSON'
{
  "version": "1.0",
  "task_id": "T-1",
  "task": "Smoke test timestamps",
  "status": "TASK_STARTED",
  "owner": {"vendor": "claude", "agent": "tester"},
  "depth": "fast",
  "timestamps": {
    "created_at": "not-a-date",
    "updated_at": "also-not-a-date"
  },
  "context": {"binding_refs": []},
  "artifacts": [".bestai/GPS.json"]
}
JSON

VALIDATE_OUTPUT=$(bash "$VALIDATE" "$INVALID_CONTEXT" 2>&1)
VALIDATE_CODE=$?
assert_exit "validate-shared-context returns invalid status" "2" "$VALIDATE_CODE"
if [ "$VALIDATE_CODE" = "2" ]; then
    assert_contains "validator flags created_at invalid" "$VALIDATE_OUTPUT" "timestamps_created_at_invalid"
    assert_contains "validator flags updated_at invalid" "$VALIDATE_OUTPUT" "timestamps_updated_at_invalid"
fi

echo ""
echo "=== shared-context-merge smoke (optional) ==="
MERGE_CMD=()
if [ -x "$ROOT_DIR/tools/shared-context-merge.sh" ]; then
    MERGE_CMD=(bash "$ROOT_DIR/tools/shared-context-merge.sh")
elif [ -x "$ROOT_DIR/tools/shared-context-merge" ]; then
    MERGE_CMD=("$ROOT_DIR/tools/shared-context-merge")
elif command -v shared-context-merge >/dev/null 2>&1; then
    MERGE_CMD=("shared-context-merge")
elif [ -f "$ROOT_DIR/bin/bestai.js" ] && command -v node >/dev/null 2>&1; then
    if node "$ROOT_DIR/bin/bestai.js" --help 2>/dev/null | grep -q "shared-context-merge"; then
        MERGE_CMD=(node "$ROOT_DIR/bin/bestai.js" "shared-context-merge")
    fi
fi

if [ "${#MERGE_CMD[@]}" -eq 0 ]; then
    skip_test "shared-context-merge smoke" "command not found"
else
    MERGE_A="$TMP_ROOT/merge-a.json"
    MERGE_B="$TMP_ROOT/merge-b.json"
    MERGE_OUT_FILE="$TMP_ROOT/merge-out.json"
    MERGED_JSON=""
    MERGED_OK=0

    cat > "$MERGE_A" <<'JSON'
{
  "version": "1.0",
  "task_id": "T-merge-1",
  "task": "Merge smoke task",
  "status": "TASK_STARTED",
  "owner": {"vendor": "claude", "agent": "agent-a"},
  "depth": "balanced",
  "timestamps": {
    "created_at": "2026-02-28T10:00:00Z",
    "updated_at": "2026-02-28T10:00:00Z"
  },
  "context": {
    "binding_refs": ["a"],
    "decisions": []
  },
  "artifacts": [".bestai/GPS.json"]
}
JSON

    cat > "$MERGE_B" <<'JSON'
{
  "version": "1.0",
  "task_id": "T-merge-1",
  "task": "Merge smoke task",
  "status": "TASK_DONE",
  "owner": {"vendor": "gemini", "agent": "agent-b"},
  "depth": "fast",
  "timestamps": {
    "created_at": "2026-02-28T10:00:00Z",
    "updated_at": "2026-02-28T10:05:00Z"
  },
  "context": {
    "binding_refs": ["b"],
    "decisions": [
      {"kind": "policy", "source": "merge-b", "summary": "done"}
    ]
  },
  "artifacts": [".bestai/handoff-latest.json"]
}
JSON

    try_merge() {
        local mode="$1"
        local out=""
        local code=0
        rm -f "$MERGE_OUT_FILE"

        case "$mode" in
            positional)
                out=$("${MERGE_CMD[@]}" "$MERGE_A" "$MERGE_B" 2>/dev/null)
                code=$?
                ;;
            positional_json)
                out=$("${MERGE_CMD[@]}" --json "$MERGE_A" "$MERGE_B" 2>/dev/null)
                code=$?
                ;;
            left_right)
                out=$("${MERGE_CMD[@]}" --left "$MERGE_A" --right "$MERGE_B" 2>/dev/null)
                code=$?
                ;;
            base_overlay)
                out=$("${MERGE_CMD[@]}" --base "$MERGE_A" --overlay "$MERGE_B" 2>/dev/null)
                code=$?
                ;;
            input_a_input_b)
                out=$("${MERGE_CMD[@]}" --input-a "$MERGE_A" --input-b "$MERGE_B" 2>/dev/null)
                code=$?
                ;;
            positional_out)
                out=$("${MERGE_CMD[@]}" "$MERGE_A" "$MERGE_B" --output "$MERGE_OUT_FILE" 2>/dev/null)
                code=$?
                ;;
            left_right_out)
                out=$("${MERGE_CMD[@]}" --left "$MERGE_A" --right "$MERGE_B" --output "$MERGE_OUT_FILE" 2>/dev/null)
                code=$?
                ;;
            base_overlay_out)
                out=$("${MERGE_CMD[@]}" --base "$MERGE_A" --overlay "$MERGE_B" --output "$MERGE_OUT_FILE" 2>/dev/null)
                code=$?
                ;;
            *)
                return 1
                ;;
        esac

        if [ "$code" -ne 0 ]; then
            return 1
        fi

        if [ -n "$out" ] && printf '%s' "$out" | jq empty >/dev/null 2>&1; then
            MERGED_JSON="$out"
            return 0
        fi

        if [ -f "$MERGE_OUT_FILE" ] && jq empty "$MERGE_OUT_FILE" >/dev/null 2>&1; then
            MERGED_JSON="$(cat "$MERGE_OUT_FILE")"
            return 0
        fi

        return 1
    }

    for mode in positional positional_json left_right base_overlay input_a_input_b positional_out left_right_out base_overlay_out; do
        if try_merge "$mode"; then
            MERGED_OK=1
            break
        fi
    done

    if [ "$MERGED_OK" = "1" ]; then
        echo -e "  ${GREEN}PASS${NC} shared-context-merge returns JSON"
        PASS=$((PASS + 1))
        assert_jq "shared-context-merge output contains data from both inputs" "$MERGED_JSON" '(tojson | contains("T-merge-1")) and (tojson | contains("TASK_DONE"))'
    else
        echo -e "  ${RED}FAIL${NC} shared-context-merge command found but no supported invocation worked"
        FAIL=$((FAIL + 1))
    fi
fi

echo ""
echo "=== Summary ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
