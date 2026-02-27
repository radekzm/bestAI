#!/bin/bash
# setup.sh — bestAI Quick Setup
# Usage:
#   bash setup.sh [target-project-dir] [options]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

BESTAI_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="."
PROFILE="default"
MERGE_SETTINGS=1
TARGET_SET=0
NON_INTERACTIVE=0
SECURE_DEFAULTS=0
TEMPLATE_MODE=""
BLUEPRINT_MODE=""
MEMORY_MODE=""
AGENTS_MODE=""
TEST_MODE=""
FAIL_ON_TEST_FAILURE=0

usage() {
    cat <<USAGE
Usage:
  bash setup.sh [target-project-dir] [--profile default|aion-runtime|smart-v2] [--merge-settings|--no-merge-settings]
                [--non-interactive|--yes] [--secure-defaults]
                [--template minimal|standard|skip]
                [--blueprint none|fullstack|swarm]
                [--memory yes|no] [--agents yes|no] [--run-tests yes|no]

Examples:
  bash setup.sh /path/to/project
  bash setup.sh /path/to/project --profile aion-runtime
  bash setup.sh /path/to/project --profile smart-v2
  bash setup.sh . --no-merge-settings
  bash setup.sh /path/to/project --non-interactive --secure-defaults --profile smart-v2
USAGE
}

is_yes() {
    [[ "$1" =~ ^[Yy]$ ]]
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            PROFILE="${2:-}"
            [ -z "$PROFILE" ] && { echo "Missing value for --profile" >&2; exit 1; }
            shift 2
            ;;
        --non-interactive|--yes)
            NON_INTERACTIVE=1
            shift
            ;;
        --secure-defaults)
            SECURE_DEFAULTS=1
            FAIL_ON_TEST_FAILURE=1
            shift
            ;;
        --template)
            TEMPLATE_MODE="${2:-}"
            [ -z "$TEMPLATE_MODE" ] && { echo "Missing value for --template" >&2; exit 1; }
            shift 2
            ;;
        --blueprint)
            BLUEPRINT_MODE="${2:-}"
            [ -z "$BLUEPRINT_MODE" ] && { echo "Missing value for --blueprint" >&2; exit 1; }
            shift 2
            ;;
        --memory)
            MEMORY_MODE="${2:-}"
            [ -z "$MEMORY_MODE" ] && { echo "Missing value for --memory" >&2; exit 1; }
            shift 2
            ;;
        --agents)
            AGENTS_MODE="${2:-}"
            [ -z "$AGENTS_MODE" ] && { echo "Missing value for --agents" >&2; exit 1; }
            shift 2
            ;;
        --run-tests)
            TEST_MODE="${2:-}"
            [ -z "$TEST_MODE" ] && { echo "Missing value for --run-tests" >&2; exit 1; }
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

case "$TEMPLATE_MODE" in
    ""|minimal|standard|skip) ;;
    *)
        echo "Unsupported --template value: $TEMPLATE_MODE (use minimal|standard|skip)" >&2
        exit 1
        ;;
esac

case "$BLUEPRINT_MODE" in
    ""|none|fullstack|swarm) ;;
    *)
        echo "Unsupported --blueprint value: $BLUEPRINT_MODE (use none|fullstack|swarm)" >&2
        exit 1
        ;;
esac

case "$MEMORY_MODE" in
    ""|yes|no) ;;
    *)
        echo "Unsupported --memory value: $MEMORY_MODE (use yes|no)" >&2
        exit 1
        ;;
esac

case "$AGENTS_MODE" in
    ""|yes|no) ;;
    *)
        echo "Unsupported --agents value: $AGENTS_MODE (use yes|no)" >&2
        exit 1
        ;;
esac

case "$TEST_MODE" in
    ""|yes|no) ;;
    *)
        echo "Unsupported --run-tests value: $TEST_MODE (use yes|no)" >&2
        exit 1
        ;;
esac

if [ ! -d "$TARGET" ]; then
    mkdir -p "$TARGET"
fi

echo -e "${BOLD}bestAI Quick Setup${NC}"
echo "Source: $BESTAI_DIR"
echo "Target: $(cd "$TARGET" && pwd)"
echo "Profile: $PROFILE"
echo "Merge settings.json: $MERGE_SETTINGS"
echo "Non-interactive: $NON_INTERACTIVE"
echo "Secure defaults: $SECURE_DEFAULTS"
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
        echo -e "  ${DIM}INFO${NC} $dep (not required — hooks use pure-bash path normalization)"
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
    TEMPLATE_CHOICE="2"
    case "$TEMPLATE_MODE" in
        minimal) TEMPLATE_CHOICE="1" ;;
        standard) TEMPLATE_CHOICE="2" ;;
        skip) TEMPLATE_CHOICE="3" ;;
        "")
            if [ "$NON_INTERACTIVE" -eq 1 ]; then
                TEMPLATE_CHOICE="2"
                echo "  Auto-select template: standard (non-interactive)"
            else
                echo "  1) Minimal (<50 lines) — small projects"
                echo "  2) Standard (<100 lines) — recommended"
                echo "  3) Skip"
                read -r -p "  Choose [1/2/3]: " TEMPLATE_CHOICE
            fi
            ;;
    esac

    case "${TEMPLATE_CHOICE:-2}" in
        1|minimal)
            cp "$BESTAI_DIR/templates/claude-md-minimal.md" "$TARGET/CLAUDE.md"
            echo -e "  ${GREEN}Copied${NC} minimal template"
            ;;
        2|standard)
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

    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        echo "  Skipping CLAUDE.md metadata prompts (non-interactive)"
        return 0
    fi

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
BP_SELECTION=""
case "$BLUEPRINT_MODE" in
    fullstack) BP_SELECTION="1" ;;
    swarm) BP_SELECTION="2" ;;
    none) BP_SELECTION="" ;;
    "")
        if [ "$NON_INTERACTIVE" -eq 1 ]; then
            BP_SELECTION=""
            echo "  Skipped Blueprints (non-interactive default)"
        else
            read -r -p "  Do you want to initialize a Project Blueprint? [y/N]: " BLUEPRINT_CHOICE
            if is_yes "${BLUEPRINT_CHOICE:-N}"; then
                echo "  1) Full-Stack (Next.js + FastAPI + PostgreSQL)"
                echo "  2) Agent Swarm (Master + Multiple sub-agents)"
                read -r -p "  Choose blueprint [1/2]: " BP_SELECTION
            fi
        fi
        ;;
esac

if [ -n "$BP_SELECTION" ]; then
    mkdir -p "$TARGET/.bestai"
    if [ -f "$BESTAI_DIR/templates/gps-template.json" ]; then
        cp "$BESTAI_DIR/templates/gps-template.json" "$TARGET/.bestai/GPS.json"
        echo -e "  ${GREEN}Created${NC} Global Project State (.bestai/GPS.json)"

        # Minimal deterministic scaffold for blueprint-specific artifacts.
        if [ "$BP_SELECTION" == "1" ]; then
            if [ -f "$BESTAI_DIR/templates/blueprint-fullstack.md" ]; then
                cp "$BESTAI_DIR/templates/blueprint-fullstack.md" "$TARGET/.bestai/blueprint.md"
            else
                cat > "$TARGET/.bestai/blueprint.md" <<'EOF'
# Full-Stack Blueprint

- Frontend: Next.js
- Backend: FastAPI
- Database: PostgreSQL
- Add stack-specific frozen files and commands before first run.
EOF
            fi
            echo -e "  ${GREEN}Initialized${NC} Full-Stack Blueprint scaffold (.bestai/blueprint.md)."
        elif [ "$BP_SELECTION" == "2" ]; then
            cat > "$TARGET/.bestai/blueprint.md" <<'EOF'
# Agent Swarm Blueprint

- Define roles: Developer / Reviewer / Tester
- Create per-role instruction files
- Use GPS active_tasks to coordinate ownership
EOF
            echo -e "  ${GREEN}Initialized${NC} Agent Swarm Blueprint scaffold (.bestai/blueprint.md)."
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

secure_default_for_hook() {
    local name="$1" base_default="$2"
    if [ "$SECURE_DEFAULTS" -ne 1 ]; then
        echo "$base_default"
        return
    fi

    case "$name" in
        check-frozen.sh|check-user-tags.sh|secret-guard.sh|backup-enforcement.sh|confidence-gate.sh|wal-logger.sh|circuit-breaker.sh|circuit-breaker-gate.sh|preprocess-prompt.sh|smart-preprocess-v2.sh|rehydrate.sh|sync-state.sh|memory-compiler.sh|observer.sh|sync-gps.sh)
            echo "Y"
            ;;
        *)
            echo "$base_default"
            ;;
    esac
}

install_hook() {
    local name="$1" desc="$2" default="$3"
    local effective_default choice
    effective_default="$(secure_default_for_hook "$name" "$default")"

    if [ -f "$HOOKS_DIR/$name" ]; then
        echo -e "  ${YELLOW}EXISTS${NC} $name — keeping"
        INSTALLED+=("$name")
        return
    fi

    if [ "$NON_INTERACTIVE" -eq 1 ]; then
        choice="$effective_default"
        echo "  Auto-select $name: $choice (non-interactive)"
    else
        read -r -p "  Install $name ($desc)? [${effective_default}]: " choice
        choice="${choice:-$effective_default}"
    fi

    if is_yes "$choice"; then
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
    install_hook "check-user-tags.sh" "protect [USER] memory entries from accidental removal" "Y"
    install_hook "secret-guard.sh" "block obvious secret leakage in commands/writes" "Y"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "confidence-gate.sh" "block dangerous ops when confidence is too low" "Y"
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
    install_hook "check-user-tags.sh" "protect [USER] memory entries from accidental removal" "Y"
    install_hook "secret-guard.sh" "block obvious secret leakage in commands/writes" "y"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "confidence-gate.sh" "block dangerous ops when confidence is too low" "y"
    install_hook "wal-logger.sh" "write-ahead log for destructive actions" "y"
    install_hook "circuit-breaker.sh" "advisory anti-loop tracker (PostToolUse)" "y"
    install_hook "circuit-breaker-gate.sh" "strict anti-loop gate (PreToolUse, optional)" "n"
    install_hook "preprocess-prompt.sh" "UserPromptSubmit smart context compiler" "Y"
    install_hook "rehydrate.sh" "SessionStart runtime bootstrap" "Y"
    install_hook "sync-state.sh" "Stop hook runtime sync" "Y"
    install_hook "memory-compiler.sh" "Stop hook memory GC + indexing" "Y"
    install_hook "sync-gps.sh" "Stop hook for Global Project State (v4.0)" "n"
else
    install_hook "check-frozen.sh" "block edits to frozen files (+ Bash bypass protection)" "Y"
    install_hook "check-user-tags.sh" "protect [USER] memory entries from accidental removal" "y"
    install_hook "secret-guard.sh" "block obvious secret leakage in commands/writes" "n"
    install_hook "backup-enforcement.sh" "require backup before deploy/restart/migrate" "Y"
    install_hook "confidence-gate.sh" "block dangerous ops when confidence is too low" "n"
    install_hook "wal-logger.sh" "write-ahead log for destructive actions" "y"
    install_hook "circuit-breaker.sh" "advisory anti-loop tracker (PostToolUse)" "y"
    install_hook "circuit-breaker-gate.sh" "strict anti-loop gate (PreToolUse, optional)" "n"
    install_hook "preprocess-prompt.sh" "UserPromptSubmit smart context compiler" "y"
    install_hook "rehydrate.sh" "SessionStart runtime bootstrap" "n"
    install_hook "sync-state.sh" "Stop hook runtime sync" "n"
    install_hook "sync-gps.sh" "Stop hook for Global Project State (v4.0)" "n"
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
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
        echo -e "  ${GREEN}Backup${NC} created: settings.json.bak (idempotent)"
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
            check-user-tags.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Write|Edit" ".claude/hooks/check-user-tags.sh"
                ;;
            secret-guard.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash|Write|Edit" ".claude/hooks/secret-guard.sh"
                ;;
            backup-enforcement.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash" ".claude/hooks/backup-enforcement.sh"
                ;;
            confidence-gate.sh)
                add_hook_config "$SETTINGS_FILE" "PreToolUse" "Bash" ".claude/hooks/confidence-gate.sh"
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
MEM_CHOICE="N"
case "$MEMORY_MODE" in
    yes) MEM_CHOICE="Y" ;;
    no) MEM_CHOICE="N" ;;
    "")
        if [ "$NON_INTERACTIVE" -eq 1 ]; then
            if [ "$SECURE_DEFAULTS" -eq 1 ]; then
                MEM_CHOICE="Y"
            else
                MEM_CHOICE="N"
            fi
            echo "  Auto-select memory scaffolding: $MEM_CHOICE (non-interactive)"
        else
            read -r -p "  Create project-local memory templates in $TARGET/memory/? [y/N]: " MEM_CHOICE
            MEM_CHOICE="${MEM_CHOICE:-N}"
        fi
        ;;
esac

if is_yes "$MEM_CHOICE"; then
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
    AGENTS_CHOICE="Y"
    case "$AGENTS_MODE" in
        yes) AGENTS_CHOICE="Y" ;;
        no) AGENTS_CHOICE="N" ;;
        "")
            if [ "$NON_INTERACTIVE" -eq 1 ]; then
                AGENTS_CHOICE="Y"
                echo "  Auto-select AGENTS.md: Y (non-interactive)"
            else
                read -r -p "  Create AGENTS.md? [Y/n]: " AGENTS_CHOICE
                AGENTS_CHOICE="${AGENTS_CHOICE:-Y}"
            fi
            ;;
    esac

    if is_yes "$AGENTS_CHOICE"; then
        cp "$BESTAI_DIR/templates/agents-md-template.md" "$TARGET/AGENTS.md"
        echo -e "  ${GREEN}Copied${NC} AGENTS.md template"
    fi
fi

# Step 7: Optional hook test run
echo ""
echo -e "${BOLD}Step 7: Verify hooks${NC}"
TEST_CHOICE="Y"
case "$TEST_MODE" in
    yes) TEST_CHOICE="Y" ;;
    no) TEST_CHOICE="N" ;;
    "")
        if [ "$NON_INTERACTIVE" -eq 1 ]; then
            TEST_CHOICE="Y"
            echo "  Auto-select hook tests: Y (non-interactive)"
        else
            read -r -p "  Run automated hook tests now (tests/test-hooks.sh)? [Y/n]: " TEST_CHOICE
            TEST_CHOICE="${TEST_CHOICE:-Y}"
        fi
        ;;
esac

if is_yes "$TEST_CHOICE"; then
    if bash "$BESTAI_DIR/tests/test-hooks.sh"; then
        echo -e "  ${GREEN}Hook tests passed${NC}"
    else
        echo -e "  ${RED}Hook tests failed${NC} — review output above"
        if [ "$FAIL_ON_TEST_FAILURE" -eq 1 ] || [ "$NON_INTERACTIVE" -eq 1 ]; then
            echo -e "  ${RED}Aborting setup due to failing tests.${NC}"
            exit 1
        fi
    fi
else
    echo "  Skipped tests"
    if [ "$SECURE_DEFAULTS" -eq 1 ]; then
        echo -e "  ${RED}Aborting setup: --secure-defaults requires test execution.${NC}"
        exit 1
    fi
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
