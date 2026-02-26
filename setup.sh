#!/bin/bash
# setup.sh — bestAI Quick Setup (5 minutes)
# Usage: bash setup.sh [target-project-dir] [--profile default|aion-runtime|smart-v2] [--merge-settings|--no-merge-settings]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

BESTAI_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="."
PROFILE="default"
MERGE_SETTINGS=1
TARGET_SET=0

usage() {
    cat <<USAGE
Usage:
  bash setup.sh [target-project-dir] [--profile default|aion-runtime] [--merge-settings|--no-merge-settings]

Examples:
  bash setup.sh /path/to/project
  bash setup.sh /path/to/project --profile aion-runtime
  bash setup.sh /path/to/project --profile smart-v2
  bash setup.sh . --no-merge-settings
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            [ -z "$PROFILE" ] && { echo "Missing value for --profile" >&2; exit 1; }
            shift 2
            ;;
        --merge-settings)
            MERGE_SETTINGS=1
            shift
            ;;
        --no-merge-settings)
            MERGE_SETTINGS=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [ "$TARGET_SET" -eq 0 ]; then
                TARGET="$1"
                TARGET_SET=1
                shift
            else
                echo "Unknown argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

if [ "$PROFILE" != "default" ] && [ "$PROFILE" != "aion-runtime" ] && [ "$PROFILE" != "smart-v2" ]; then
    echo "Unsupported profile: $PROFILE" >&2
    echo "Supported: default, aion-runtime, smart-v2" >&2
    exit 1
fi

echo -e "${BOLD}bestAI Quick Setup${NC}"
echo "Source: $BESTAI_DIR"
echo "Target: $(cd "$TARGET" && pwd)"
echo "Profile: $PROFILE"
echo "Merge settings.json: $MERGE_SETTINGS"
echo ""

# Check dependencies
echo -e "${BOLD}Checking dependencies...${NC}"
MISSING=0
for dep in jq bash; do
    if command -v "$dep" &>/dev/null; then
        echo -e "  ${GREEN}OK${NC} $dep"
    else
        echo -e "  ${RED}MISSING${NC} $dep (required for hooks + settings merge)"
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
    echo -e "  ${YELLOW}CLAUDE.md already exists${NC} — keeping current file"
else
    echo "  1) Minimal (<50 lines) — small projects"
    echo "  2) Standard (<100 lines) — recommended"
    echo "  3) Skip"
    read -r -p "  Choose [1/2/3]: " TEMPLATE_CHOICE
    case "${TEMPLATE_CHOICE:-2}" in
        1)
            cp "$BESTAI_DIR/templates/claude-md-minimal.md" "$TARGET/CLAUDE.md"
            echo -e "  ${GREEN}Copied${NC} minimal template"
            ;;
        2)
            cp "$BESTAI_DIR/templates/claude-md-standard.md" "$TARGET/CLAUDE.md"
            echo -e "  ${GREEN}Copied${NC} standard template"
            ;;
        *)
            echo "  Skipped"
            ;;
    esac
fi

customize_claude() {
    local file="$1"
    [ -f "$file" ] || return 0

    read -r -p "  Fill CLAUDE.md project metadata now? [Y/n]: " META_CHOICE
    if ! [[ "${META_CHOICE:-Y}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    read -r -p "  Project name: " PNAME
    read -r -p "  Stack (e.g. Rails + React): " PSTACK
    read -r -p "  Primary language: " PLANG
    read -r -p "  Test command (e.g. npm test): " PTEST
    read -r -p "  Build command (e.g. npm run build): " PBUILD
    read -r -p "  Deploy command (e.g. ./deploy.sh): " PDELOY

    [ -n "$PNAME" ] && sed -i "s|\[project name\]|$PNAME|g" "$file"
    [ -n "$PSTACK" ] && sed -i "s|\[your stack here\]|$PSTACK|g" "$file"
    [ -n "$PLANG" ] && sed -i "s|\[primary language\]|$PLANG|g" "$file"
    [ -n "$PTEST" ] && sed -i "s|\[your test command\]|$PTEST|g" "$file"
    [ -n "$PBUILD" ] && sed -i "s|\[your build command\]|$PBUILD|g" "$file"
    [ -n "$PDELOY" ] && sed -i "s|\[your deploy command\]|$PDELOY|g" "$file"

    echo -e "  ${GREEN}Updated${NC} CLAUDE.md metadata"
}

customize_claude "$TARGET/CLAUDE.md"

# Step 1b: Project Blueprints (v4.0)
echo ""
echo -e "${BOLD}Step 1b: Project Blueprints (v4.0)${NC}"
read -r -p "  Do you want to initialize a Project Blueprint? [y/N]: " BLUEPRINT_CHOICE
if [[ "${BLUEPRINT_CHOICE:-N}" =~ ^[Yy]$ ]]; then
    echo "  1) Full-Stack (Next.js + FastAPI + PostgreSQL)"
    echo "  2) Agent Swarm (Master + Multiple sub-agents)"
    read -r -p "  Choose blueprint [1/2]: " BP_SELECTION
    mkdir -p "$TARGET/.bestai"
    if [ -f "$BESTAI_DIR/templates/gps-template.json" ]; then
        cp "$BESTAI_DIR/templates/gps-template.json" "$TARGET/.bestai/GPS.json"
        echo -e "  ${GREEN}Created${NC} Global Project State (.bestai/GPS.json)"
        
        # Here we could inject stack-specific frozen files or linting hooks
        if [ "$BP_SELECTION" == "1" ]; then
            echo -e "  ${GREEN}Initialized${NC} Full-Stack Blueprint settings."
        elif [ "$BP_SELECTION" == "2" ]; then
            echo -e "  ${GREEN}Initialized${NC} Agent Swarm Blueprint settings."
        fi
    fi
else
    echo "  Skipped Blueprints"
fi

# Step 2: Choose hooks
echo ""
echo -e "${BOLD}Step 2: Hooks${NC}"
HOOKS_DIR="$TARGET/.claude/hooks"
mkdir -p "$HOOKS_DIR"

INSTALLED=()

install_hook() {
    local name="$1" desc="$2" default="$3"
    if [ -f "$HOOKS_DIR/$name" ]; then
        echo -e "  ${YELLOW}EXISTS${NC} $name — keeping"
        INSTALLED+=("$name")
        return
    fi

    read -r -p "  Install $name ($desc)? [${default}]: " CHOICE
    CHOICE="${CHOICE:-$default}"
    if [[ "$CHOICE" =~ ^[Yy]$ ]]; then
        cp "$BESTAI_DIR/hooks/$name" "$HOOKS_DIR/$name"
        chmod +x "$HOOKS_DIR/$name"
        INSTALLED+=("$name")
        echo -e "  ${GREEN}Installed${NC} $name"
    else
        echo "  Skipped $name"
    fi
}

if [ "$PROFILE" = "smart-v2" ]; then
    install_hook "check-frozen.sh" "block edits to frozen files (+ Bash bypass protection)" "Y"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "wal-logger.sh" "write-ahead log for destructive actions" "Y"
    install_hook "circuit-breaker.sh" "advisory anti-loop tracker (PostToolUse)" "Y"
    install_hook "circuit-breaker-gate.sh" "strict anti-loop gate (PreToolUse, optional)" "n"
    install_hook "smart-preprocess-v2.sh" "Haiku semantic context routing (UserPromptSubmit)" "Y"
    install_hook "preprocess-prompt.sh" "keyword context compiler (fallback for smart-v2)" "Y"
    install_hook "rehydrate.sh" "SessionStart runtime bootstrap" "Y"
    install_hook "sync-state.sh" "Stop hook runtime sync" "Y"
    install_hook "memory-compiler.sh" "Stop hook memory GC + indexing" "Y"
    install_hook "observer.sh" "Stop hook observational memory compression" "Y"
    install_hook "sync-gps.sh" "Stop hook for Global Project State (v4.0)" "Y"
elif [ "$PROFILE" = "aion-runtime" ]; then
    install_hook "check-frozen.sh" "block edits to frozen files (+ Bash bypass protection)" "Y"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "wal-logger.sh" "write-ahead log for destructive actions" "y"
    install_hook "circuit-breaker.sh" "advisory anti-loop tracker (PostToolUse)" "y"
    install_hook "circuit-breaker-gate.sh" "strict anti-loop gate (PreToolUse, optional)" "n"
    install_hook "preprocess-prompt.sh" "UserPromptSubmit smart context compiler" "Y"
    install_hook "rehydrate.sh" "SessionStart runtime bootstrap" "Y"
    install_hook "sync-state.sh" "Stop hook runtime sync" "Y"
    install_hook "memory-compiler.sh" "Stop hook memory GC + indexing" "Y"
else
    install_hook "check-frozen.sh" "block edits to frozen files (+ Bash bypass protection)" "Y"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "wal-logger.sh" "write-ahead log for destructive actions" "y"
    install_hook "circuit-breaker.sh" "advisory anti-loop tracker (PostToolUse)" "y"
    install_hook "circuit-breaker-gate.sh" "strict anti-loop gate (PreToolUse, optional)" "n"
    install_hook "preprocess-prompt.sh" "UserPromptSubmit smart context compiler" "y"
    install_hook "rehydrate.sh" "SessionStart runtime bootstrap" "n"
    install_hook "sync-state.sh" "Stop hook runtime sync" "n"
fi

# Step 3: Configure settings.json
add_hook_config() {
    local file="$1" event="$2" matcher="$3" command="$4"
    local tmp
    tmp=$(mktemp)

    jq \
      --arg event "$event" \
      --arg matcher "$matcher" \
      --arg command "$command" '
        .hooks = (.hooks // {}) |
        .hooks[$event] = (.hooks[$event] // []) |
        if (.hooks[$event] | map(select(.matcher == $matcher)) | length) > 0 then
          .hooks[$event] = (
            .hooks[$event] | map(
              if .matcher == $matcher then
                .hooks = (.hooks // []) |
                if (.hooks | map(select(.type == "command" and .command == $command)) | length) == 0 then
                  .hooks += [{"type":"command","command":$command}]
                else
                  .
                end
              else
                .
              end
            )
          )
        else
          .hooks[$event] += [{"matcher":$matcher,"hooks":[{"type":"command","command":$command}]}]
        end
      ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

remove_hook_config() {
    local file="$1" event="$2" matcher="$3" command="$4"
    local tmp
    tmp=$(mktemp)

    jq \
      --arg event "$event" \
      --arg matcher "$matcher" \
      --arg command "$command" '
        .hooks = (.hooks // {}) |
        .hooks[$event] = (.hooks[$event] // []) |
        .hooks[$event] = (
          .hooks[$event] | map(
            if .matcher == $matcher then
              .hooks = (
                (.hooks // [])
                | map(select(.type != "command" or .command != $command))
              )
            else
              .
            end
          )
        )
      ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

echo ""
echo -e "${BOLD}Step 3: Hook configuration${NC}"
SETTINGS_FILE="$TARGET/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ] && [ "$MERGE_SETTINGS" -eq 0 ]; then
    echo -e "  ${YELLOW}settings.json exists${NC} and merge disabled — skipping configuration"
else
    if [ ! -f "$SETTINGS_FILE" ]; then
        mkdir -p "$TARGET/.claude"
        echo '{"hooks":{}}' > "$SETTINGS_FILE"
        echo -e "  ${GREEN}Created${NC} .claude/settings.json"
    else
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak.$(date +%Y%m%d_%H%M%S)"
        echo -e "  ${GREEN}Backup${NC} created for existing settings.json"
    fi

    if ! jq empty "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "  ${RED}Invalid settings.json${NC} — fix JSON before running setup"
        exit 1
    fi

    for hook in "${INSTALLED[@]}"; do
        case "$hook" in
            check-frozen.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Edit|Write|Bash" ".claude/hooks/check-frozen.sh"
                ;;
            backup-enforcement.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash" ".claude/hooks/backup-enforcement.sh"
                ;;
            wal-logger.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash|Write|Edit" ".claude/hooks/wal-logger.sh"
                ;;
            circuit-breaker.sh)
                add_hook_config "$SETTINGS_FILE" "PostToolUse" "Bash" ".claude/hooks/circuit-breaker.sh"
                ;;
            circuit-breaker-gate.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash" ".claude/hooks/circuit-breaker-gate.sh"
                ;;
            preprocess-prompt.sh)
                add_hook_config "$SETTINGS_FILE" "UserPromptSubmit" "" ".claude/hooks/preprocess-prompt.sh"
                ;;
            rehydrate.sh)
                add_hook_config "$SETTINGS_FILE" "SessionStart" "" ".claude/hooks/rehydrate.sh"
                ;;
            sync-state.sh)
                add_hook_config "$SETTINGS_FILE" "Stop" "" ".claude/hooks/sync-state.sh"
                ;;
            memory-compiler.sh)
                add_hook_config "$SETTINGS_FILE" "Stop" "" ".claude/hooks/memory-compiler.sh"
                ;;
            smart-preprocess-v2.sh)
                add_hook_config "$SETTINGS_FILE" "UserPromptSubmit" "" ".claude/hooks/smart-preprocess-v2.sh"
                ;;
            observer.sh)
                add_hook_config "$SETTINGS_FILE" "Stop" "" ".claude/hooks/observer.sh"
                ;;
            sync-gps.sh)
                add_hook_config "$SETTINGS_FILE" "Stop" "" ".claude/hooks/sync-gps.sh"
                ;;
        esac
    done

    # smart-v2 uses preprocess-prompt as internal fallback.
    # Keep only smart-preprocess-v2 in UserPromptSubmit to avoid duplicate injection.
    if [ "$PROFILE" = "smart-v2" ] && [[ " ${INSTALLED[*]} " == *" smart-preprocess-v2.sh "* ]]; then
        remove_hook_config "$SETTINGS_FILE" "UserPromptSubmit" "" ".claude/hooks/preprocess-prompt.sh"
    fi

    PRE_COUNT=$(jq '.hooks.PreToolUse // [] | length' "$SETTINGS_FILE")
    POST_COUNT=$(jq '.hooks.PostToolUse // [] | length' "$SETTINGS_FILE")
    UPS_COUNT=$(jq '.hooks.UserPromptSubmit // [] | length' "$SETTINGS_FILE")
    START_COUNT=$(jq '.hooks.SessionStart // [] | length' "$SETTINGS_FILE")
    STOP_COUNT=$(jq '.hooks.Stop // [] | length' "$SETTINGS_FILE")

    echo -e "  ${GREEN}Configured${NC} hooks in settings.json"
    echo "  Counts: PreToolUse=$PRE_COUNT PostToolUse=$POST_COUNT UserPromptSubmit=$UPS_COUNT SessionStart=$START_COUNT Stop=$STOP_COUNT"
fi

# Step 4: Runtime templates (optional)
echo ""
echo -e "${BOLD}Step 4: Runtime templates${NC}"
RUNTIME_DIR="$TARGET/.claude"
mkdir -p "$RUNTIME_DIR"

if [ "$PROFILE" = "aion-runtime" ] || [[ " ${INSTALLED[*]} " == *" rehydrate.sh "* ]] || [[ " ${INSTALLED[*]} " == *" sync-state.sh "* ]]; then
    if [ ! -f "$RUNTIME_DIR/checklist-now.md" ]; then
        cp "$BESTAI_DIR/templates/checklist-now.md" "$RUNTIME_DIR/checklist-now.md"
        echo -e "  ${GREEN}Created${NC} .claude/checklist-now.md"
    else
        echo -e "  ${YELLOW}EXISTS${NC} .claude/checklist-now.md"
    fi

    if [ ! -f "$RUNTIME_DIR/state-of-system-now.md" ]; then
        cp "$BESTAI_DIR/templates/state-of-system-now.md" "$RUNTIME_DIR/state-of-system-now.md"
        echo -e "  ${GREEN}Created${NC} .claude/state-of-system-now.md"
    else
        echo -e "  ${YELLOW}EXISTS${NC} .claude/state-of-system-now.md"
    fi
else
    echo "  Skipped (runtime profile not enabled)"
fi

# Step 5: Memory scaffolding (optional, project-local reference)
echo ""
echo -e "${BOLD}Step 5: Memory scaffolding${NC}"
read -r -p "  Create project-local memory templates in $TARGET/memory/? [y/N]: " MEM_CHOICE
if [[ "${MEM_CHOICE:-N}" =~ ^[Yy]$ ]]; then
    mkdir -p "$TARGET/memory"
    [ -f "$TARGET/memory/MEMORY.md" ] || cp "$BESTAI_DIR/templates/memory-md-template.md" "$TARGET/memory/MEMORY.md"
    [ -f "$TARGET/memory/frozen-fragments.md" ] || cp "$BESTAI_DIR/templates/frozen-fragments-template.md" "$TARGET/memory/frozen-fragments.md"
    [ -f "$TARGET/memory/decisions.md" ] || printf '# Decisions\n\n' > "$TARGET/memory/decisions.md"
    [ -f "$TARGET/memory/preferences.md" ] || printf '# Preferences\n\n' > "$TARGET/memory/preferences.md"
    [ -f "$TARGET/memory/pitfalls.md" ] || printf '# Pitfalls\n\n' > "$TARGET/memory/pitfalls.md"
    echo -e "  ${GREEN}Created${NC} memory template files"
else
    echo "  Skipped memory scaffolding"
fi

# Step 6: AGENTS.md
echo ""
echo -e "${BOLD}Step 6: AGENTS.md (multi-tool compatibility)${NC}"
if [ -f "$TARGET/AGENTS.md" ]; then
    echo -e "  ${YELLOW}AGENTS.md already exists${NC} — keeping"
else
    read -r -p "  Create AGENTS.md? [Y/n]: " AGENTS_CHOICE
    if [[ "${AGENTS_CHOICE:-Y}" =~ ^[Yy]$ ]]; then
        cp "$BESTAI_DIR/templates/agents-md-template.md" "$TARGET/AGENTS.md"
        echo -e "  ${GREEN}Copied${NC} AGENTS.md template"
    fi
fi

# Step 7: Optional hook test run
echo ""
echo -e "${BOLD}Step 7: Verify hooks${NC}"
read -r -p "  Run automated hook tests now (tests/test-hooks.sh)? [Y/n]: " TEST_CHOICE
if [[ "${TEST_CHOICE:-Y}" =~ ^[Yy]$ ]]; then
    if bash "$BESTAI_DIR/tests/test-hooks.sh"; then
        echo -e "  ${GREEN}Hook tests passed${NC}"
    else
        echo -e "  ${RED}Hook tests failed${NC} — review output above"
    fi
else
    echo "  Skipped tests"
fi

# Summary
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review CLAUDE.md and AGENTS.md"
echo "  2. Run: bash $BESTAI_DIR/doctor.sh $TARGET"
echo "  3. If using runtime profile: keep .claude/state-of-system-now.md updated"
echo ""
echo "Installed hooks:"
for hook in "${INSTALLED[@]}"; do
    echo "  .claude/hooks/$hook"
done
[ -f "$SETTINGS_FILE" ] && echo "  .claude/settings.json"

echo ""
echo -e "Read modules for guidelines: ${BOLD}$BESTAI_DIR/modules/${NC}"
