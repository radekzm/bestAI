#!/bin/bash
# tools/hook-lint.sh — Hook composition linter
# Usage: bash tools/hook-lint.sh [project-dir]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$TARGET" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BESTAI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Mode A (repo): target contains hooks/manifest.json
# Mode B (installed project): use manifest from bestAI repo and inspect target/.claude/hooks
if [ -f "$PROJECT_DIR/hooks/manifest.json" ]; then
    LINT_MODE="repo"
    MANIFEST="$PROJECT_DIR/hooks/manifest.json"
    HOOKS_DIR="$PROJECT_DIR/hooks"
else
    LINT_MODE="installed"
    MANIFEST="$BESTAI_ROOT/hooks/manifest.json"
    HOOKS_DIR="$PROJECT_DIR/.claude/hooks"
fi
SETTINGS="$PROJECT_DIR/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 1
fi

ERRORS=0
WARNINGS=0

error() { echo -e "  ${RED}ERROR${NC}  $*"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${YELLOW}WARN${NC}   $*"; WARNINGS=$((WARNINGS + 1)); }
ok()    { echo -e "  ${GREEN}OK${NC}     $*"; }

ENABLED_HOOKS_FILE="$(mktemp)"
trap 'rm -f "$ENABLED_HOOKS_FILE"' EXIT
HAS_ENABLED_FILTER=0

if [ -f "$SETTINGS" ]; then
    jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null \
        | while read -r cmd; do
            [ -z "$cmd" ] && continue
            hook_name=$(basename "$cmd")
            [[ "$hook_name" == *.sh ]] || continue
            echo "$hook_name"
        done \
        | sort -u > "$ENABLED_HOOKS_FILE"

    if [ -s "$ENABLED_HOOKS_FILE" ]; then
        HAS_ENABLED_FILTER=1
    fi
fi

hook_selected() {
    local hook="$1"
    if [ "$HAS_ENABLED_FILTER" -eq 1 ]; then
        grep -Fxq "$hook" "$ENABLED_HOOKS_FILE"
    else
        return 0
    fi
}

echo -e "${BOLD}bestAI Hook Composition Lint${NC} — $(basename "$PROJECT_DIR")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Manifest Check ──
echo -e "${BOLD}Manifest${NC}"
if [ ! -f "$MANIFEST" ]; then
    error "hooks/manifest.json not found (searched: $MANIFEST)"
    echo ""
    echo -e "${BOLD}Result${NC}: $ERRORS errors, $WARNINGS warnings"
    exit 1
fi

HOOK_COUNT=$(jq '.hooks | length' "$MANIFEST")
ok "manifest.json found ($HOOK_COUNT hooks declared)"
echo ""

# ── Dependency Validation ──
echo -e "${BOLD}Dependencies${NC}"
for hook in $(jq -r '.hooks | keys[]' "$MANIFEST"); do
    hook_selected "$hook" || continue
    deps=$(jq -r --arg h "$hook" '.hooks[$h].depends_on // [] | .[]' "$MANIFEST")
    for dep in $deps; do
        if ! jq -e --arg d "$dep" '.hooks[$d]' "$MANIFEST" >/dev/null 2>&1; then
            error "$hook depends on $dep but $dep is not in manifest"
        else
            dep_event=$(jq -r --arg d "$dep" '.hooks[$d].event' "$MANIFEST")
            hook_event=$(jq -r --arg h "$hook" '.hooks[$h].event' "$MANIFEST")
            if [ "$dep_event" = "$hook_event" ]; then
                dep_prio=$(jq -r --arg d "$dep" '.hooks[$d].priority' "$MANIFEST")
                hook_prio=$(jq -r --arg h "$hook" '.hooks[$h].priority' "$MANIFEST")
                if [ "$dep_prio" -ge "$hook_prio" ]; then
                    warn "$hook (priority=$hook_prio) depends on $dep (priority=$dep_prio) — dependency should have lower priority number"
                else
                    ok "$hook -> $dep dependency order correct"
                fi
            elif [ "$dep_event" = "PostToolUse" ] && [ "$hook_event" = "PreToolUse" ]; then
                ok "$hook (PreToolUse) -> $dep (PostToolUse) cross-event dependency"
            else
                ok "$hook ($hook_event) -> $dep ($dep_event)"
            fi
        fi
    done
done
echo ""

# ── Conflict Detection ──
echo -e "${BOLD}Conflicts${NC}"
CONFLICT_FOUND=0
for hook in $(jq -r '.hooks | keys[]' "$MANIFEST"); do
    hook_selected "$hook" || continue
    conflicts=$(jq -r --arg h "$hook" '.hooks[$h].conflicts_with // [] | .[]' "$MANIFEST")
    for conflict in $conflicts; do
        if [ -f "$SETTINGS" ]; then
            hook_in_settings=$(jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null | grep -c "$hook" || echo 0)
            conflict_in_settings=$(jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null | grep -c "$conflict" || echo 0)
            if [ "$hook_in_settings" -gt 0 ] && [ "$conflict_in_settings" -gt 0 ]; then
                error "$hook and $conflict are both enabled but conflict with each other"
                CONFLICT_FOUND=1
            fi
        fi
    done
done
[ "$CONFLICT_FOUND" -eq 0 ] && ok "No active conflicts detected"
echo ""

# ── Latency Budget ──
echo -e "${BOLD}Latency Budget${NC}"
for event in PreToolUse PostToolUse UserPromptSubmit SessionStart Stop; do
    budget=$(jq -r --arg e "$event" '.latency_budgets[$e] // 0' "$MANIFEST")
    [ "$budget" -eq 0 ] && continue

    total_latency=0
    hook_list=""
    for hook in $(jq -r --arg e "$event" '.hooks | to_entries[] | select(.value.event == $e) | .key' "$MANIFEST"); do
        hook_selected "$hook" || continue
        latency=$(jq -r --arg h "$hook" '.hooks[$h].estimated_latency_ms' "$MANIFEST")
        total_latency=$((total_latency + latency))
        hook_list="$hook_list $hook(${latency}ms)"
    done

    if [ "$total_latency" -gt "$budget" ]; then
        warn "$event: total ${total_latency}ms exceeds budget ${budget}ms —$hook_list"
    elif [ "$total_latency" -gt 0 ]; then
        ok "$event: ${total_latency}ms / ${budget}ms budget —$hook_list"
    fi
done
echo ""

# ── Installed Hook Validation ──
echo -e "${BOLD}Hook Files${NC}"
for hook in $(jq -r '.hooks | keys[]' "$MANIFEST"); do
    hook_selected "$hook" || continue
    hook_path="$HOOKS_DIR/$hook"
    if [ ! -f "$hook_path" ]; then
        if [ "$LINT_MODE" = "installed" ]; then
            warn "$hook selected in settings but file missing in .claude/hooks"
        else
            error "$hook declared in manifest but file not found"
        fi
    elif [ ! -x "$hook_path" ]; then
        warn "$hook exists but is not executable"
    fi
done

# Check for hooks in directory not in manifest (ignore known libraries/helpers)
for hook_file in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook_file" ] || continue
    basename=$(basename "$hook_file")
    case "$basename" in
        hook-event.sh|lib-logging.sh|reflector.sh)
            continue
            ;;
    esac
    if ! jq -e --arg h "$basename" '.hooks[$h]' "$MANIFEST" >/dev/null 2>&1; then
        warn "$basename exists in $(basename "$HOOKS_DIR")/ but not declared in manifest.json"
    fi
done
ok "Hook file check complete"
echo ""

# ── Settings Cross-Reference ──
echo -e "${BOLD}Settings Cross-Reference${NC}"
if [ -f "$SETTINGS" ]; then
    jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null | while read -r cmd; do
        [ -z "$cmd" ] && continue
        hook_name=$(basename "$cmd")
        if [[ "$hook_name" == *.sh ]] && ! jq -e --arg h "$hook_name" '.hooks[$h]' "$MANIFEST" >/dev/null 2>&1; then
            warn "$hook_name referenced in settings.json but not in manifest"
        fi
    done
    ok "Settings cross-reference complete"
else
    echo -e "  ${DIM}No .claude/settings.json found${NC}"
fi
echo ""

# ── Dependency Requirements ──
echo -e "${BOLD}System Dependencies${NC}"
ALL_DEPS=$(jq -r '.hooks | keys[]' "$MANIFEST" | while read -r hook; do
    hook_selected "$hook" || continue
    jq -r --arg h "$hook" '.hooks[$h].requires // [] | .[]' "$MANIFEST"
done | sort -u)
for dep in $ALL_DEPS; do
    if command -v "$dep" >/dev/null 2>&1; then
        ok "$dep installed"
    else
        error "$dep required by hooks but not installed"
    fi
done
echo ""

# ── Summary ──
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $ERRORS errors, $WARNINGS warnings"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}PASSED${NC} with $WARNINGS warnings"
    exit 0
else
    echo -e "${GREEN}PASSED${NC}: All checks passed"
    exit 0
fi
