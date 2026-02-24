#!/bin/bash
# doctor.sh — bestAI Health Check & Diagnostics
# Usage: bash doctor.sh [project-dir]
#
# Diagnoses common AI CLI agent problems and suggests bestAI solutions.
# Run this when your agent misbehaves.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

TARGET="${1:-.}"
ISSUES=0
WARNINGS=0

echo -e "${BOLD}bestAI Doctor — AI Agent Health Check${NC}"
echo "Project: $(cd "$TARGET" && pwd)"
echo ""

check() {
    local severity="$1" message="$2" fix="$3"
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
if [ -f "$TARGET/CLAUDE.md" ]; then
    LINES=$(wc -l < "$TARGET/CLAUDE.md")
    if [ "$LINES" -gt 100 ]; then
        check "FAIL" "CLAUDE.md is $LINES lines (>100)" "Trim to <100 lines. Move details to Skills or modules."
    elif [ "$LINES" -gt 50 ]; then
        check "WARN" "CLAUDE.md is $LINES lines (could be shorter)" "Consider trimming to <50 lines for small projects."
    else
        check "OK" "CLAUDE.md is $LINES lines"
    fi

    # Check for common anti-patterns
    if grep -qiE '(todo|fixme|hack|temporary)' "$TARGET/CLAUDE.md" 2>/dev/null; then
        check "WARN" "CLAUDE.md contains TODO/FIXME/HACK" "Remove temporary notes from always-loaded file."
    fi

    if ! grep -qi 'test' "$TARGET/CLAUDE.md" 2>/dev/null; then
        check "WARN" "CLAUDE.md missing test command" "Add: '**Test**: \`your test command\`'"
    fi
else
    check "FAIL" "No CLAUDE.md found" "Run: bash setup.sh $TARGET"
fi

# === Hooks ===
echo ""
echo -e "${BOLD}Hooks${NC}"
HOOKS_DIR="$TARGET/.claude/hooks"
if [ -d "$HOOKS_DIR" ]; then
    HOOK_COUNT=$(ls "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l)
    if [ "$HOOK_COUNT" -eq 0 ]; then
        check "WARN" "Hooks directory exists but empty" "Copy hooks from bestAI: bash setup.sh $TARGET"
    else
        check "OK" "$HOOK_COUNT hooks installed"
        for hook in "$HOOKS_DIR"/*.sh; do
            [ ! -f "$hook" ] && continue
            if [ ! -x "$hook" ]; then
                check "FAIL" "$(basename "$hook") not executable" "chmod +x $hook"
            else
                check "OK" "$(basename "$hook") executable"
            fi
        done
    fi
else
    check "WARN" "No hooks directory" "Run: bash setup.sh $TARGET"
fi

# === settings.json ===
echo ""
echo -e "${BOLD}Hook Configuration${NC}"
SETTINGS="$TARGET/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    if command -v jq &>/dev/null; then
        if jq empty "$SETTINGS" 2>/dev/null; then
            check "OK" "settings.json valid JSON"
            PRE_COUNT=$(jq '.hooks.PreToolUse // [] | length' "$SETTINGS" 2>/dev/null || echo 0)
            POST_COUNT=$(jq '.hooks.PostToolUse // [] | length' "$SETTINGS" 2>/dev/null || echo 0)
            check "OK" "$PRE_COUNT PreToolUse hooks, $POST_COUNT PostToolUse hooks configured"
        else
            check "FAIL" "settings.json invalid JSON" "Validate with: jq . $SETTINGS"
        fi
    else
        check "WARN" "jq not installed — cannot validate settings.json" "Install jq"
    fi
else
    check "WARN" "No .claude/settings.json" "Run: bash setup.sh $TARGET"
fi

# === Dependencies ===
echo ""
echo -e "${BOLD}Dependencies${NC}"
for dep in jq bash; do
    if command -v "$dep" &>/dev/null; then
        check "OK" "$dep installed"
    else
        check "FAIL" "$dep missing (required for enforcement hooks)" "Install $dep"
    fi
done
for dep in realpath python3; do
    if command -v "$dep" &>/dev/null; then
        check "OK" "$dep installed"
    else
        check "WARN" "$dep missing (path normalization degraded)" "Install $dep for better frozen-file matching"
    fi
done

# === MEMORY.md ===
echo ""
echo -e "${BOLD}Memory System${NC}"
MEMORY_DIR="$HOME/.claude/projects/$(echo "$(cd "$TARGET" && pwd)" | tr '/' '-')/memory"
if [ -d "$MEMORY_DIR" ]; then
    MEMORY_FILES=$(ls "$MEMORY_DIR"/*.md 2>/dev/null | wc -l)
    check "OK" "$MEMORY_FILES memory files in $MEMORY_DIR"

    if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
        MEM_LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md")
        if [ "$MEM_LINES" -gt 200 ]; then
            check "WARN" "MEMORY.md is $MEM_LINES lines (>200)" "Compact: keep only active decisions and preferences"
        else
            check "OK" "MEMORY.md is $MEM_LINES lines"
        fi
    fi
else
    check "WARN" "No memory directory yet" "Will be created on first session with auto-memory"
fi

# === AGENTS.md ===
echo ""
echo -e "${BOLD}Multi-Tool Compatibility${NC}"
if [ -f "$TARGET/AGENTS.md" ]; then
    check "OK" "AGENTS.md present (Codex/Cursor/Amp compatible)"
else
    check "WARN" "No AGENTS.md" "Copy from bestAI templates for multi-tool compat"
fi

# === Common Problem Diagnosis ===
echo ""
echo -e "${BOLD}Common Problem Diagnosis${NC}"

# Check for .env in git
if [ -d "$TARGET/.git" ]; then
    if git -C "$TARGET" ls-files --cached | grep -qE '\.env$' 2>/dev/null; then
        check "FAIL" ".env file tracked by git" "Add to .gitignore and remove: git rm --cached .env"
    else
        check "OK" "No secrets in git"
    fi
fi

# Check for frozen-fragments.md
if [ -f "$TARGET/.claude/frozen-fragments.md" ] || [ -f "$MEMORY_DIR/frozen-fragments.md" ]; then
    check "OK" "Frozen fragments registry exists"
else
    check "WARN" "No frozen-fragments.md" "Create one if you have files that should never be auto-edited"
fi

# === Summary ===
echo ""
echo -e "${BOLD}=== SUMMARY ===${NC}"
if [ "$ISSUES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed! Your project is well configured.${NC}"
elif [ "$ISSUES" -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warnings — consider addressing them.${NC}"
else
    echo -e "${RED}$ISSUES issues found — fix these for reliable agent behavior.${NC}"
    [ "$WARNINGS" -gt 0 ] && echo -e "${YELLOW}$WARNINGS additional warnings.${NC}"
fi

echo ""
echo "Quick fixes:"
echo "  Setup:   bash $(dirname "$0")/setup.sh $TARGET"
echo "  Test:    bash $(dirname "$0")/tests/test-hooks.sh"
echo "  Modules: $(dirname "$0")/modules/"
