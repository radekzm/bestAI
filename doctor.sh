#!/bin/bash
# doctor.sh — bestAI Health Check & Diagnostics
# Usage: bash doctor.sh [project-dir]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TARGET="${1:-.}"
TARGET_ABS="$(cd "$TARGET" && pwd)"
ISSUES=0
WARNINGS=0

echo -e "${BOLD}bestAI Doctor — AI Agent Health Check${NC}"
echo "Project: $TARGET_ABS"
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

# === Hook Activity ===
echo ""
echo -e "${BOLD}Hook Activity${NC}"
METRICS_FILE="$HOME/.claude/projects/$(echo "$TARGET_ABS" | tr '/' '-')/hook-metrics.log"
if [ -f "$METRICS_FILE" ]; then
    check "OK" "Hook metrics file exists"
    for hook in check-frozen circuit-breaker backup-enforcement wal-logger; do
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
