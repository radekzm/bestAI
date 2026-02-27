#!/bin/bash
# doctor.sh — bestAI Health Check & Diagnostics
# Usage: bash doctor.sh [--strict] [project-dir]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

STRICT=0
TARGET="."

usage() {
    cat <<USAGE
Usage:
  bash doctor.sh [--strict] [project-dir]

Options:
  --strict   Exit non-zero when warnings are present.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --strict)
            STRICT=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

TARGET_ABS="$(cd "$TARGET" && pwd)"
ISSUES=0
WARNINGS=0

echo -e "${BOLD}bestAI Doctor — AI Agent Health Check${NC}"
echo "Project: $TARGET_ABS"
echo "Strict mode: $STRICT"
echo ""

check() {
    local severity="$1" message="$2" fix="${3:-}"
    if [ "$severity" = "FAIL" ]; then
        echo -e "  ${RED}FAIL${NC} $message"
        echo -e "       Fix: $fix"
        ISSUES=$((ISSUES + 1))
    elif [ "$severity" = "WARN" ]; then
        echo -e "  ${YELLOW}WARN${NC} $message"
        echo -e "       Tip: $fix"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${GREEN}OK${NC} $message"
    fi
}

# === CLAUDE.md ===
echo -e "${BOLD}CLAUDE.md${NC}"
if [ -f "$TARGET_ABS/CLAUDE.md" ]; then
    LINES=$(wc -l < "$TARGET_ABS/CLAUDE.md")
    if [ "$LINES" -gt 120 ]; then
        check "FAIL" "CLAUDE.md is $LINES lines (>120)" "Trim to <=120 lines. Move details to Skills/modules."
    elif [ "$LINES" -gt 100 ]; then
        check "WARN" "CLAUDE.md is $LINES lines (>100)" "Recommended <=100 for always-loaded docs."
    else
        check "OK" "CLAUDE.md is $LINES lines"
    fi

    if grep -qiE '(todo|fixme|hack|temporary)' "$TARGET_ABS/CLAUDE.md" 2>/dev/null; then
        check "WARN" "CLAUDE.md contains TODO/FIXME/HACK" "Move temporary notes to task docs."
    fi

    if ! grep -qi 'test' "$TARGET_ABS/CLAUDE.md" 2>/dev/null; then
        check "WARN" "CLAUDE.md missing test command" "Add explicit test command in Project section."
    fi
else
    check "FAIL" "No CLAUDE.md found" "Run: bash setup.sh $TARGET_ABS"
fi

# === Hooks ===
echo ""
echo -e "${BOLD}Hooks${NC}"
HOOKS_DIR="$TARGET_ABS/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    HOOK_COUNT=$(find "$HOOKS_DIR" -maxdepth 1 -type f -name '*.sh' | wc -l)
    if [ "$HOOK_COUNT" -eq 0 ]; then
        check "WARN" "Hooks directory exists but empty" "Install hooks with setup.sh"
    else
        check "OK" "$HOOK_COUNT hooks installed"
        while IFS= read -r hook; do
            [ -f "$hook" ] || continue
            base=$(basename "$hook")
            if [ ! -x "$hook" ]; then
                check "FAIL" "$base not executable" "chmod +x $hook"
            else
                check "OK" "$base executable"
            fi

            if bash -n "$hook" 2>/dev/null; then
                check "OK" "$base syntax valid"
            else
                check "FAIL" "$base has shell syntax errors" "Run: bash -n $hook"
            fi
        done < <(find "$HOOKS_DIR" -maxdepth 1 -type f -name '*.sh' | sort)
    fi
else
    check "WARN" "No hooks directory" "Run: bash setup.sh $TARGET_ABS"
fi

# === settings.json ===
echo ""
echo -e "${BOLD}Hook Configuration${NC}"
SETTINGS="$TARGET_ABS/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    if command -v jq &>/dev/null; then
        if jq empty "$SETTINGS" 2>/dev/null; then
            check "OK" "settings.json valid JSON"

            PRE_COUNT=$(jq '.hooks.PreToolUse // [] | length' "$SETTINGS")
            POST_COUNT=$(jq '.hooks.PostToolUse // [] | length' "$SETTINGS")
            UPS_COUNT=$(jq '.hooks.UserPromptSubmit // [] | length' "$SETTINGS")
            START_COUNT=$(jq '.hooks.SessionStart // [] | length' "$SETTINGS")
            STOP_COUNT=$(jq '.hooks.Stop // [] | length' "$SETTINGS")
            check "OK" "Hook events: Pre=$PRE_COUNT Post=$POST_COUNT UserPromptSubmit=$UPS_COUNT SessionStart=$START_COUNT Stop=$STOP_COUNT"

            if [ "$UPS_COUNT" -eq 0 ]; then
                check "WARN" "No UserPromptSubmit hooks configured" "Install preprocess-prompt.sh for smart context injection"
            fi

            if [ "$START_COUNT" -eq 0 ] && [ "$STOP_COUNT" -eq 0 ]; then
                check "WARN" "Runtime hooks (SessionStart/Stop) not configured" "Use --profile aion-runtime if you want REHYDRATE/SYNC_STATE"
            fi

            # Check configured command paths exist.
            while IFS= read -r cmd; do
                [ -z "$cmd" ] && continue
                abs_cmd="$TARGET_ABS/$cmd"
                if [ ! -f "$abs_cmd" ]; then
                    check "FAIL" "Configured hook command missing: $cmd" "Re-run setup.sh or fix .claude/settings.json"
                fi
            done < <(jq -r '.hooks | to_entries[]?.value[]?.hooks[]?.command // empty' "$SETTINGS")
        else
            check "FAIL" "settings.json invalid JSON" "Validate with: jq . $SETTINGS"
        fi
    else
        check "WARN" "jq not installed — cannot validate settings.json" "Install jq"
    fi
else
    check "WARN" "No .claude/settings.json" "Run: bash setup.sh $TARGET_ABS"
fi

# === GPS ===
echo ""
echo -e "${BOLD}Global Project State (GPS)${NC}"
GPS_FILE="$TARGET_ABS/.bestai/GPS.json"
if [ -f "$GPS_FILE" ]; then
    if command -v jq &>/dev/null && jq empty "$GPS_FILE" 2>/dev/null; then
        check "OK" "GPS.json valid JSON"

        if jq -e '
          (.project | type == "object")
          and (.project.name | type == "string")
          and (.project.main_objective | type == "string")
          and (.project.owner | type == "string")
          and ((.project.target_date == null) or (.project.target_date | type == "string"))
          and (.project.success_metric | type == "string")
          and (.project.status_updated_at | type == "string")
          and (.milestones | type == "array")
          and (.active_tasks | type == "array")
          and (.blockers | type == "array")
          and (.shared_context | type == "object")
        ' "$GPS_FILE" >/dev/null 2>&1; then
            check "OK" "GPS schema fields present (owner/target_date/success_metric/status_updated_at)"
        else
            check "FAIL" "GPS schema is incomplete" "Regenerate from templates/gps-template.json and update required fields"
        fi

        GPS_OWNER=$(jq -r '.project.owner // empty' "$GPS_FILE")
        GPS_METRIC=$(jq -r '.project.success_metric // empty' "$GPS_FILE")
        if [ "$GPS_OWNER" = "unassigned" ] || [ "$GPS_OWNER" = "" ]; then
            check "WARN" "GPS owner is not assigned" "Set .project.owner to accountable person/team"
        fi
        if [ "$GPS_METRIC" = "not defined" ] || [ "$GPS_METRIC" = "" ]; then
            check "WARN" "GPS success_metric is not defined" "Set measurable KPI in .project.success_metric"
        fi
    else
        check "FAIL" "GPS.json invalid JSON" "Validate with: jq . $GPS_FILE"
    fi
else
    check "WARN" "No .bestai/GPS.json" "Create from templates/gps-template.json if using multi-agent orchestration"
fi

# === Dependencies ===
echo ""
echo -e "${BOLD}Dependencies${NC}"
for dep in jq bash; do
    if command -v "$dep" &>/dev/null; then
        check "OK" "$dep installed"
    else
        check "FAIL" "$dep missing (required for hooks)" "Install $dep"
    fi
done
for dep in realpath python3; do
    if command -v "$dep" &>/dev/null; then
        check "OK" "$dep installed"
    else
        check "WARN" "$dep missing (path normalization degraded)" "Install $dep for better matching"
    fi
done

# === Tools (Python) ===
echo ""
echo -e "${BOLD}Tools (Python)${NC}"
if [ -d "$(dirname "$0")/tools" ] && ls "$(dirname "$0")/tools/"*.py >/dev/null 2>&1; then
    if command -v python3 &>/dev/null; then
        if python3 -m py_compile "$(dirname "$0")"/tools/*.py 2>/dev/null; then
            check "OK" "Python tools compile successfully"
        else
            check "FAIL" "Python tool compile failed" "Run: python3 -m py_compile tools/*.py"
        fi
    else
        check "WARN" "python3 missing — cannot validate tools/*.py" "Install python3"
    fi
else
    check "WARN" "No Python tools found in tools/" "Skip"
fi

# === Memory ===
echo ""
echo -e "${BOLD}Memory System${NC}"
MEMORY_DIR="$HOME/.claude/projects/$(echo "$TARGET_ABS" | tr '/' '-')/memory"
if [ -d "$MEMORY_DIR" ]; then
    MEMORY_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name '*.md' | wc -l)
    check "OK" "$MEMORY_FILES memory files in $MEMORY_DIR"

    if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
        MEM_LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md")
        if [ "$MEM_LINES" -gt 200 ]; then
            check "FAIL" "MEMORY.md is $MEM_LINES lines (>200)" "Compact MEMORY.md and move details to topic files"
        elif [ "$MEM_LINES" -gt 120 ]; then
            check "WARN" "MEMORY.md is $MEM_LINES lines (>120)" "Recommended <=120 for fast rehydrate"
        else
            check "OK" "MEMORY.md is $MEM_LINES lines"
        fi

        if ! grep -qE '\[(USER|AUTO)\]' "$MEMORY_DIR/MEMORY.md" 2>/dev/null; then
            check "WARN" "MEMORY.md has no [USER]/[AUTO] tags" "Tag entries to protect user decisions"
        fi
    else
        check "WARN" "No MEMORY.md in memory dir" "Create MEMORY.md from templates/memory-md-template.md"
    fi
else
    check "WARN" "No memory directory yet" "Will be created on first session with auto-memory"
fi

# === Token Budget Heuristic ===
echo ""
echo -e "${BOLD}Token Budget (heuristic)${NC}"
CONTEXT_WINDOW=${CONTEXT_WINDOW_TOKENS:-200000}
DOC_WORDS=0
if [ -f "$TARGET_ABS/CLAUDE.md" ]; then
    DOC_WORDS=$((DOC_WORDS + $(wc -w < "$TARGET_ABS/CLAUDE.md")))
fi
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
    DOC_WORDS=$((DOC_WORDS + $(wc -w < "$MEMORY_DIR/MEMORY.md")))
fi
EST_TOKENS=$(((DOC_WORDS * 13 + 9) / 10))
EST_RATIO=$((EST_TOKENS * 100 / CONTEXT_WINDOW))

check "OK" "Always-loaded docs estimated at ~${EST_TOKENS} tokens (~${EST_RATIO}% of ${CONTEXT_WINDOW})" "Heuristic: words * 1.3"
if [ "$EST_RATIO" -gt 15 ]; then
    check "FAIL" "Always-loaded docs exceed 15% of context window" "Trim CLAUDE/MEMORY and move details to topic files"
elif [ "$EST_RATIO" -gt 10 ]; then
    check "WARN" "Always-loaded docs exceed 10% of context window" "Recommended target: <=10%"
fi

# === Prompt Cache Hygiene ===
echo ""
echo -e "${BOLD}Prompt Cache Hygiene${NC}"
if [ -f "$TARGET_ABS/CLAUDE.md" ]; then
    if grep -qEi '(\$\(date|\{\{(date|timestamp|uuid|random)\}\}|<TIMESTAMP>|<DATE>|<UUID>|generated at|last updated: [0-9]{4}-[0-9]{2}-[0-9]{2})' "$TARGET_ABS/CLAUDE.md" 2>/dev/null; then
        check "WARN" "Detected dynamic markers in CLAUDE.md (possible prompt cache busting)" "Keep always-loaded prefix stable; move dynamic fields to runtime logs/tail context"
    else
        check "OK" "No obvious dynamic markers in CLAUDE.md"
    fi
fi

CACHE_USAGE_FILE="${CACHE_USAGE_LOG:-$HOME/.claude/projects/$(echo "$TARGET_ABS" | tr '/' '-')/cache-usage.jsonl}"
if [ -f "$CACHE_USAGE_FILE" ]; then
    if command -v jq &>/dev/null; then
        CACHE_TMP="$(mktemp)"
        tail -n 200 "$CACHE_USAGE_FILE" > "$CACHE_TMP"

        if jq empty "$CACHE_TMP" >/dev/null 2>&1; then
            CACHE_METRICS="$(jq -s '
              def num:
                if . == null then 0
                elif type == "number" then .
                elif type == "string" then (tonumber? // 0)
                else 0 end;

              def usage_obj: (.usage // .response.usage // {});
              def provider_guess:
                (
                  (.provider // .metadata.provider // null) as $p
                  | if $p != null then ($p|tostring|ascii_downcase)
                    elif (usage_obj.cache_read_input_tokens? != null or usage_obj.cache_creation_input_tokens? != null) then "anthropic"
                    elif (usage_obj.prompt_tokens_details.cached_tokens? != null) then "openai"
                    else "unknown"
                    end
                );
              def input_tokens:
                (usage_obj.input_tokens? // usage_obj.prompt_tokens? // .input_tokens? // .prompt_tokens? // 0 | num);
              def cached_read_tokens:
                (usage_obj.prompt_tokens_details.cached_tokens? // usage_obj.cache_read_input_tokens? // .cached_tokens? // 0 | num);
              def ratio_denom($p; $i; $c):
                if $p == "anthropic" then ($i + $c) else $i end;

              [ .[] |
                (provider_guess) as $provider
                | (input_tokens) as $input
                | (cached_read_tokens) as $cached
                | (ratio_denom($provider; $input; $cached)) as $denom
                | {
                    denom: $denom,
                    cached: $cached,
                    low_hit: ($denom >= 1500 and (if $denom > 0 then ($cached / $denom * 100) else 0 end) < 20),
                    cold_large: ($cached == 0 and $denom >= 1500),
                    cache_key: (.cache_key // .prompt_cache_key // .prefix_hash // .metadata.cache_key // "")
                  }
              ] as $rows
              | {
                  rows: ($rows|length),
                  weighted_hit_ratio: (if (($rows|map(.denom)|add // 0) > 0) then (($rows|map(.cached)|add // 0) / ($rows|map(.denom)|add // 0) * 100) else 0 end),
                  low_hit_rate: (if ($rows|length) == 0 then 0 else (($rows|map(select(.low_hit))|length) / ($rows|length) * 100) end),
                  cold_large_rate: (if ($rows|length) == 0 then 0 else (($rows|map(select(.cold_large))|length) / ($rows|length) * 100) end),
                  cache_key_rows: ($rows|map(select(.cache_key != ""))|length),
                  cache_key_unique_rate: (
                    if (($rows|map(select(.cache_key != ""))|length) == 0)
                    then 0
                    else (($rows|map(select(.cache_key != "")|.cache_key)|unique|length) / ($rows|map(select(.cache_key != ""))|length) * 100)
                    end
                  )
                }
            ' "$CACHE_TMP")"

            CACHE_ROWS=$(jq -r '.rows' <<< "$CACHE_METRICS")
            CACHE_HIT=$(jq -r '.weighted_hit_ratio' <<< "$CACHE_METRICS")
            LOW_HIT=$(jq -r '.low_hit_rate' <<< "$CACHE_METRICS")
            COLD_RATE=$(jq -r '.cold_large_rate' <<< "$CACHE_METRICS")
            KEY_ROWS=$(jq -r '.cache_key_rows' <<< "$CACHE_METRICS")
            KEY_RATE=$(jq -r '.cache_key_unique_rate' <<< "$CACHE_METRICS")

            check "OK" "Cache usage log found ($CACHE_ROWS recent rows analyzed)"

            if [ "$CACHE_ROWS" -lt 20 ]; then
                check "WARN" "Low sample size for cache trend ($CACHE_ROWS < 20 rows)" "Collect more runs before hard conclusions"
            fi

            if awk -v n="$CACHE_HIT" 'BEGIN { exit !(n < 30) }'; then
                check "WARN" "Weighted cache hit ratio is low (${CACHE_HIT}%)" "Inspect stable prefix and split volatile prompt tail"
            else
                check "OK" "Weighted cache hit ratio looks healthy (${CACHE_HIT}%)"
            fi

            if awk -v n="$COLD_RATE" 'BEGIN { exit !(n > 40) }'; then
                check "WARN" "High cold large prompt rate (${COLD_RATE}%)" "Likely cache busting by dynamic prefix or key churn"
            else
                check "OK" "Cold large prompt rate acceptable (${COLD_RATE}%)"
            fi

            if awk -v n="$LOW_HIT" 'BEGIN { exit !(n > 35) }'; then
                check "WARN" "Many low-hit large prompts (${LOW_HIT}%)" "Track prefix diffs and cache keys between runs"
            fi

            if [ "$KEY_ROWS" -gt 0 ]; then
                if awk -v n="$KEY_RATE" 'BEGIN { exit !(n > 60) }'; then
                    check "WARN" "High cache key uniqueness (${KEY_RATE}%)" "Too many unique keys suggest unstable prompt prefix"
                else
                    check "OK" "Cache key churn seems controlled (${KEY_RATE}%)"
                fi
            fi
        else
            check "WARN" "Cache usage log exists but JSONL is invalid" "Validate log lines and rerun evals/cache-usage-report.sh"
        fi
        rm -f "$CACHE_TMP"
    else
        check "WARN" "jq not installed — cannot analyze prompt cache usage log" "Install jq for cache diagnostics"
    fi
else
    check "WARN" "No cache usage log found" "Optional: store JSONL usage in $CACHE_USAGE_FILE and run evals/cache-usage-report.sh"
fi

# === Hook Activity ===
echo ""
echo -e "${BOLD}Hook Activity${NC}"
METRICS_FILE="$HOME/.claude/projects/$(echo "$TARGET_ABS" | tr '/' '-')/hook-metrics.log"
if [ -f "$METRICS_FILE" ]; then
    check "OK" "Hook metrics file exists"
    for hook in check-frozen check-user-tags secret-guard confidence-gate circuit-breaker backup-enforcement wal-logger sync-state sync-gps; do
        COUNT=$(grep -c "$hook" "$METRICS_FILE" 2>/dev/null || echo 0)
        echo "  $hook: $COUNT events"
    done
else
    check "WARN" "No hook-metrics.log yet" "Will appear after hooks run in real sessions"
fi

# === Runtime profile files ===
echo ""
echo -e "${BOLD}Runtime Profile${NC}"
if [ -f "$TARGET_ABS/.claude/checklist-now.md" ]; then
    check "OK" ".claude/checklist-now.md present"
else
    check "WARN" "No .claude/checklist-now.md" "Create from templates/checklist-now.md for runtime workflow"
fi

if [ -f "$TARGET_ABS/.claude/state-of-system-now.md" ]; then
    check "OK" ".claude/state-of-system-now.md present"
else
    check "WARN" "No .claude/state-of-system-now.md" "Create from templates/state-of-system-now.md"
fi

# === Multi-tool ===
echo ""
echo -e "${BOLD}Multi-Tool Compatibility${NC}"
if [ -f "$TARGET_ABS/AGENTS.md" ]; then
    check "OK" "AGENTS.md present"
else
    check "WARN" "No AGENTS.md" "Copy from templates/agents-md-template.md"
fi

# === Common security checks ===
echo ""
echo -e "${BOLD}Common Problem Diagnosis${NC}"
if [ -d "$TARGET_ABS/.git" ]; then
    if git -C "$TARGET_ABS" ls-files --cached | grep -qE '\.env$' 2>/dev/null; then
        check "FAIL" ".env file tracked by git" "Add to .gitignore and remove from index: git rm --cached .env"
    else
        check "OK" "No .env tracked in git"
    fi
fi

if [ -f "$MEMORY_DIR/frozen-fragments.md" ] || [ -f "$TARGET_ABS/.claude/frozen-fragments.md" ]; then
    check "OK" "Frozen fragments registry exists"
else
    check "WARN" "No frozen-fragments.md" "Create from templates/frozen-fragments-template.md"
fi

# === v4.0 Architecture (RAG & Orchestration) ===
echo ""
echo -e "${BOLD}v4.0 Architecture (RAG & Orchestration)${NC}"

if [ -f "$TARGET_ABS/.bestai/T3-summary.md" ]; then
    check "OK" "T3-summary.md (Invisible Limit) present"
else
    check "WARN" "No T3-summary.md" "Run 'python3 tools/generate-t3-summaries.py' to map codebase."
fi

if [ -f "$TARGET_ABS/.bestai/vector-store.json" ] || [ -d "$TARGET_ABS/.bestai/chroma" ]; then
    check "OK" "RAG Vector Store detected"
else
    check "WARN" "No Vector Store (RAG) found" "Run 'python3 tools/vectorize-codebase.py' if using semantic memory."
fi

if [ -d "$TARGET_ABS/.worktrees" ]; then
    check "OK" "Git Worktrees directory exists for agent orchestration"
else
    check "WARN" "No .worktrees directory" "Required if spawning parallel agent teams."
fi

# === Summary ===
echo ""
echo -e "${BOLD}=== SUMMARY ===${NC}"
if [ "$ISSUES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed. Project looks healthy.${NC}"
elif [ "$ISSUES" -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warnings — improve for better reliability.${NC}"
else
    echo -e "${RED}$ISSUES issues found — fix these first.${NC}"
    [ "$WARNINGS" -gt 0 ] && echo -e "${YELLOW}$WARNINGS additional warnings.${NC}"
fi

echo ""
echo "Quick commands:"
echo "  Setup:   bash $(dirname "$0")/setup.sh $TARGET_ABS"
echo "  Test:    bash $(dirname "$0")/tests/test-hooks.sh"
echo "  Modules: $(dirname "$0")/modules/"

if [ "$ISSUES" -gt 0 ]; then
    exit 2
fi

if [ "$STRICT" -eq 1 ] && [ "$WARNINGS" -gt 0 ]; then
    exit 1
fi

exit 0
