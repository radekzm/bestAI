#!/bin/bash
# setup.sh — bestAI Quick Setup (5 minutes)
# Usage: bash setup.sh [target-project-dir]
#
# Installs bestAI hooks and template into your project.
# Interactive — asks what you want before copying.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

BESTAI_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"

echo -e "${BOLD}bestAI Quick Setup${NC}"
echo "Source: $BESTAI_DIR"
echo "Target: $(cd "$TARGET" && pwd)"
echo ""

# Check dependencies
echo -e "${BOLD}Checking dependencies...${NC}"
MISSING=0
for dep in jq bash; do
    if command -v "$dep" &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} $dep"
    else
        echo -e "  ${RED}MISSING${NC} $dep (required for enforcement hooks)"
        MISSING=$((MISSING + 1))
    fi
done
for dep in realpath python3; do
    if command -v "$dep" &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} $dep"
    else
        echo -e "  ${YELLOW}OPTIONAL${NC} $dep (path normalization)"
    fi
done

if [ "$MISSING" -gt 0 ]; then
    echo -e "\n${RED}Install missing dependencies first.${NC}"
    exit 1
fi

# Step 1: Choose template
echo ""
echo -e "${BOLD}Step 1: CLAUDE.md template${NC}"
if [ -f "$TARGET/CLAUDE.md" ]; then
    echo -e "  ${YELLOW}CLAUDE.md already exists${NC} — skipping"
else
    echo "  1) Minimal (<50 lines) — small projects"
    echo "  2) Standard (<100 lines) — recommended"
    echo "  3) Skip"
    read -p "  Choose [1/2/3]: " TEMPLATE_CHOICE
    case "${TEMPLATE_CHOICE:-2}" in
        1) cp "$BESTAI_DIR/templates/claude-md-minimal.md" "$TARGET/CLAUDE.md"
           echo -e "  ${GREEN}Copied${NC} minimal template" ;;
        2) cp "$BESTAI_DIR/templates/claude-md-standard.md" "$TARGET/CLAUDE.md"
           echo -e "  ${GREEN}Copied${NC} standard template" ;;
        *) echo "  Skipped" ;;
    esac
fi

# Step 2: Choose hooks
echo ""
echo -e "${BOLD}Step 2: Hooks${NC}"
HOOKS_DIR="$TARGET/.claude/hooks"
mkdir -p "$HOOKS_DIR"

install_hook() {
    local name="$1" desc="$2" default="$3"
    if [ -f "$HOOKS_DIR/$name" ]; then
        echo -e "  ${YELLOW}EXISTS${NC} $name — skipping"
        return
    fi
    read -p "  Install $name ($desc)? [${default}]: " CHOICE
    CHOICE="${CHOICE:-$default}"
    if [[ "$CHOICE" =~ ^[Yy] ]]; then
        cp "$BESTAI_DIR/hooks/$name" "$HOOKS_DIR/$name"
        chmod +x "$HOOKS_DIR/$name"
        echo -e "  ${GREEN}Installed${NC} $name"
    else
        echo "  Skipped $name"
    fi
}

install_hook "check-frozen.sh" "block edits to frozen files — PreToolUse" "Y"
install_hook "backup-enforcement.sh" "require backup before deploy — PreToolUse" "Y"
install_hook "circuit-breaker.sh" "advisory stop after N failures — PostToolUse" "y"
install_hook "wal-logger.sh" "log destructive actions — PreToolUse" "y"

# Step 3: Generate settings.json
echo ""
echo -e "${BOLD}Step 3: Hook configuration${NC}"
SETTINGS_FILE="$TARGET/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "  ${YELLOW}settings.json already exists${NC} — skipping"
    echo "  Add hooks manually. See README.md for configuration."
else
    PRE_HOOKS=""
    POST_HOOKS=""

    [ -f "$HOOKS_DIR/check-frozen.sh" ] && PRE_HOOKS="${PRE_HOOKS:+$PRE_HOOKS,}{\"matcher\":\"Edit|Write\",\"hooks\":[{\"type\":\"command\",\"command\":\".claude/hooks/check-frozen.sh\"}]}"
    [ -f "$HOOKS_DIR/backup-enforcement.sh" ] && PRE_HOOKS="${PRE_HOOKS:+$PRE_HOOKS,}{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\".claude/hooks/backup-enforcement.sh\"}]}"
    [ -f "$HOOKS_DIR/wal-logger.sh" ] && PRE_HOOKS="${PRE_HOOKS:+$PRE_HOOKS,}{\"matcher\":\"Bash|Write|Edit\",\"hooks\":[{\"type\":\"command\",\"command\":\".claude/hooks/wal-logger.sh\"}]}"
    [ -f "$HOOKS_DIR/circuit-breaker.sh" ] && POST_HOOKS="${POST_HOOKS:+$POST_HOOKS,}{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\".claude/hooks/circuit-breaker.sh\"}]}"

    cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "hooks": {
    "PreToolUse": [${PRE_HOOKS}],
    "PostToolUse": [${POST_HOOKS}]
  }
}
SETTINGS_EOF
    echo -e "  ${GREEN}Created${NC} .claude/settings.json"
fi

# Step 4: AGENTS.md
echo ""
echo -e "${BOLD}Step 4: AGENTS.md (multi-tool compatibility)${NC}"
if [ -f "$TARGET/AGENTS.md" ]; then
    echo -e "  ${YELLOW}AGENTS.md already exists${NC} — skipping"
else
    read -p "  Create AGENTS.md? [Y/n]: " AGENTS_CHOICE
    if [[ "${AGENTS_CHOICE:-Y}" =~ ^[Yy] ]]; then
        cp "$BESTAI_DIR/templates/agents-md-template.md" "$TARGET/AGENTS.md"
        echo -e "  ${GREEN}Copied${NC} AGENTS.md template"
    fi
fi

# Summary
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — fill in your project details"
echo "  2. Edit AGENTS.md — add your coding standards"
echo "  3. Test hooks: bash $BESTAI_DIR/tests/test-hooks.sh"
echo ""
echo "Key files created:"
[ -f "$TARGET/CLAUDE.md" ] && echo "  $TARGET/CLAUDE.md"
[ -f "$TARGET/AGENTS.md" ] && echo "  $TARGET/AGENTS.md"
ls "$HOOKS_DIR"/*.sh 2>/dev/null | while read f; do echo "  $f"; done
[ -f "$SETTINGS_FILE" ] && echo "  $SETTINGS_FILE"
echo ""
echo -e "Read modules for guidelines: ${BOLD}$BESTAI_DIR/modules/${NC}"
