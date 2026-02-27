#!/bin/bash
# tools/hook-lint.sh — Hook composition linter
# Validates hooks/manifest.json against settings.json and installed hooks.
# Detects: missing dependencies, conflicts, latency budget overruns, missing hooks.
# Usage: bash tools/hook-lint.sh [project-dir]
# Requires: jq

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
MANIFEST="$PROJECT_DIR/hooks/manifest.json"
SETTINGS="$PROJECT_DIR/.claude/settings.json"
HOOKS_DIR="$PROJECT_DIR/hooks"

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 1
fi

ERRORS=0
WARNINGS=0

error() { echo -e "  ${RED}ERROR${NC}  $*"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${YELLOW}WARN${NC}   $*"; WARNINGS=$((WARNINGS + 1)); }
ok()    { echo -e "  ${GREEN}OK${NC}     $*"; }

echo -e "${BOLD}bestAI Hook Composition Lint${NC} — $(basename "$PROJECT_DIR")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Manifest Check ──
echo -e "${BOLD}Manifest${NC}"
if [ ! -f "$MANIFEST" ]; then
    error "hooks/manifest.json not found"
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
    deps=$(jq -r --arg h "$hook" '.hooks[$h].depends_on // [] | .[]' "$MANIFEST")
    for dep in $deps; do
        if ! jq -e --arg d "$dep" '.hooks[$d]' "$MANIFEST" >/dev/null 2>&1; then
            error "$hook depends on $dep but $dep is not in manifest"
        else
            dep_event=$(jq -r --arg d "$dep" '.hooks[$d].event' "$MANIFEST")
            hook_event=$(jq -r --arg h "$hook" '.hooks[$h].event' "$MANIFEST")

            # Check: dependency must run before dependent (for same-event hooks, lower priority)
            if [ "$dep_event" = "$hook_event" ]; then
                dep_prio=$(jq -r --arg d "$dep" '.hooks[$d].priority' "$MANIFEST")
                hook_prio=$(jq -r --arg h "$hook" '.hooks[$h].priority' "$MANIFEST")
                if [ "$dep_prio" -ge "$hook_prio" ]; then
                    warn "$hook (priority=$hook_prio) depends on $dep (priority=$dep_prio) — dependency should have lower priority number"
                else
                    ok "$hook → $dep dependency order correct"
                fi
            elif [ "$dep_event" = "PostToolUse" ] && [ "$hook_event" = "PreToolUse" ]; then
                ok "$hook (PreToolUse) → $dep (PostToolUse) — cross-event dependency"
            else
                ok "$hook ($hook_event) → $dep ($dep_event)"
            fi
        fi
    done
done
echo ""

# ── Conflict Detection ──
echo -e "${BOLD}Conflicts${NC}"
CONFLICT_FOUND=0
for hook in $(jq -r '.hooks | keys[]' "$MANIFEST"); do
    conflicts=$(jq -r --arg h "$hook" '.hooks[$h].conflicts_with // [] | .[]' "$MANIFEST")
    for conflict in $conflicts; do
        # Check if both are installed (in settings.json)
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
    hook_path="$HOOKS_DIR/$hook"
    if [ ! -f "$hook_path" ]; then
        error "$hook declared in manifest but file not found"
    elif [ ! -x "$hook_path" ]; then
        warn "$hook exists but is not executable"
    fi
done

# Check for hooks in directory not in manifest
for hook_file in "$HOOKS_DIR"/*.sh; do
    [ -f "$hook_file" ] || continue
    basename=$(basename "$hook_file")
    [ "$basename" = "hook-event.sh" ] && continue  # library, not a hook
    if ! jq -e --arg h "$basename" '.hooks[$h]' "$MANIFEST" >/dev/null 2>&1; then
        warn "$basename exists in hooks/ but not declared in manifest.json"
    fi
done
ok "Hook file check complete"
echo ""

# ── Settings.json Cross-Reference ──
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
ALL_DEPS=$(jq -r '.hooks[].requires // [] | .[]' "$MANIFEST" | sort -u)
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
