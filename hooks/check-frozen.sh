#!/bin/bash
# hooks/check-frozen.sh — PreToolUse hook (Edit|Write|Bash matcher)
# Blocks edits to files listed in frozen-fragments.md
# Exit 2 = BLOCK (deterministic enforcement)
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)

set -euo pipefail

# Load shared libraries
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/lib-event-bus.sh" 2>/dev/null || true
# shellcheck source=hook-event.sh
source "$HOOKS_DIR/hook-event.sh" 2>/dev/null || true
source "$HOOKS_DIR/lib-dryrun.sh" 2>/dev/null || {
    block_or_log() { echo "[bestAI] BLOCKED: $1" >&2; exit 2; }
}

has_valid_permit() {
    local target_file="$1"
    local permit_db=".bestai/permits.json"
    [ -f "$permit_db" ] || return 1
    
    local expiry
    expiry=$(jq -r ".\"$target_file\" // 0" "$permit_db")
    local now
    now=$(date +%s)
    
    if [ "$expiry" -gt "$now" ]; then
        return 0 # Valid permit
    fi
    return 1 # No permit or expired
}

block_or_dryrun() {
    local reason="$1"
    local file_path="${2:-}"
    
    if [ -n "$file_path" ] && has_valid_permit "$file_path"; then
        echo "[bestAI] [PERMIT] Allowing edit to FROZEN file: $file_path" >&2
        emit_event "check-frozen" "PERMIT_ALLOW" "{\"file\":\"$file_path\"}" 2>/dev/null || true
        return 0
    fi

    emit_event "check-frozen" "BLOCK" "{\"reason\":\"$reason\",\"file\":\"$file_path\"}" 2>/dev/null || true
    block_or_log "$reason"
}

# Fail closed: if jq is missing, block rather than allow
if ! command -v jq &>/dev/null; then
    block_or_dryrun "jq is not installed. Cannot validate frozen files."
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || {
    block_or_dryrun "Failed to parse hook input JSON."
}
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || {
    block_or_dryrun "Failed to parse tool_input from JSON."
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')

_BESTAI_TOOL_NAME="$TOOL_NAME"

check_surgical_patching() {
    # Surgical Patching Policy (Issue #122)
    # Goal: Prevent agents from rewriting large files from scratch.
    if [ "$TOOL_NAME" = "Write" ]; then
        local file_path
        file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
        if [ -f "$file_path" ]; then
            local lines
            lines=$(wc -l < "$file_path")
            if [ "$lines" -gt 100 ]; then
                block_or_dryrun "Surgical Patching Violation: File '$file_path' has $lines lines. Use 'Edit' (diff) instead of 'Write' to avoid regressions." "$file_path"
            fi
        fi
    fi
}

# Normalize path: remove ./ and .. components, convert to absolute.
# Pure-bash implementation — no external dependencies (realpath, python3).
# Handles: relative paths, //, /./, /../, trailing /. sequences.
normalize_path() {
    local p="$1"

    # Make absolute
    if [[ "$p" != /* ]]; then
        p="$PROJECT_DIR/$p"
    fi

    # Remove // sequences
    while [[ "$p" == *//* ]]; do
        p="${p//\/\//\/}"
    done

    # Remove /./ sequences
    while [[ "$p" == */./* ]]; do
        p="${p//\/.\//\/}"
    done

    # Remove trailing /.
    while [[ "$p" == */. ]]; do
        p="${p%/.}"
    done

    # Resolve /../ sequences by splitting into components
    if [[ "$p" == *..* ]]; then
        local -a parts=()
        local segment
        local IFS='/'
        # shellcheck disable=SC2086
        for segment in $p; do
            if [ "$segment" = ".." ]; then
                # Pop last component (if any beyond root)
                if [ "${#parts[@]}" -gt 0 ]; then
                    unset 'parts[${#parts[@]}-1]'
                fi
            elif [ -n "$segment" ] && [ "$segment" != "." ]; then
                parts+=("$segment")
            fi
        done
        p="/"
        if [ "${#parts[@]}" -gt 0 ]; then
            p+=$(printf '%s/' "${parts[@]}")
            p="${p%/}"  # Remove trailing /
        fi
    fi

    # Ensure no trailing slash (unless root)
    [[ "$p" != "/" ]] && p="${p%/}"

    echo "$p"
}

canonicalize_existing_path() {
    local p="$1"
    [ -e "$p" ] || {
        echo ""
        return 0
    }

    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null || true
        return 0
    fi

    if command -v readlink >/dev/null 2>&1; then
        readlink -f "$p" 2>/dev/null || true
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$p" <<'PY' 2>/dev/null || true
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
        return 0
    fi

    echo ""
}

interpreter_script_path_from_command() {
    local command="$1"
    printf '%s\n' "$command" | awk '
        {
            if ($1 ~ /^(python[0-9.]*|ruby|node|perl)$/) {
                for (i = 2; i <= NF; i++) {
                    token = $i
                    if (token ~ /^-/) {
                        continue
                    }
                    gsub(/^["'\''`]+|["'\''`]+$/, "", token)
                    print token
                    exit
                }
            }
        }
    '
}

MEMORY_DIR="$HOME/.claude/projects/$PROJECT_KEY/memory"
CANONICAL_FROZEN="$MEMORY_DIR/frozen-fragments.md"
LEGACY_FROZEN="$PROJECT_DIR/.claude/frozen-fragments.md"

FROZEN_PATHS_FILE=$(mktemp)
trap 'rm -f "$FROZEN_PATHS_FILE"' EXIT

collect_frozen_paths() {
    local registry="$1"
    [ ! -f "$registry" ] && return 0

    while IFS= read -r line; do
        local raw normalized
        raw=$(echo "$line" | sed -n 's/.*`\([^`]*\)`.*/\1/p' | head -1)
        [ -z "$raw" ] && continue
        normalized=$(normalize_path "$raw")
        printf '%s\t%s\n' "$raw" "$normalized" >> "$FROZEN_PATHS_FILE"
    done < <(grep -E '^\s*-\s*`' "$registry" 2>/dev/null)
}

collect_frozen_paths "$CANONICAL_FROZEN"
collect_frozen_paths "$LEGACY_FROZEN"

[ ! -s "$FROZEN_PATHS_FILE" ] && exit 0

check_direct_file_edit() {
    local file_path normalized_file canonical_file

    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
    [ -z "$file_path" ] && return 0

    normalized_file=$(normalize_path "$file_path")
    canonical_file=$(canonicalize_existing_path "$normalized_file")

    while IFS=$'\t' read -r raw frozen_norm; do
        local frozen_canonical=""
        frozen_canonical=$(canonicalize_existing_path "$frozen_norm")

        if [ "$normalized_file" = "$frozen_norm" ] ||
           { [ -n "$canonical_file" ] && [ -n "$frozen_canonical" ] && [ "$canonical_file" = "$frozen_canonical" ]; }; then
            block_or_dryrun "File is FROZEN: $file_path (listed in frozen-fragments.md). To allow edits, use 'bestai permit $file_path' or remove from frozen-fragments.md." "$file_path"
        fi
    done < "$FROZEN_PATHS_FILE"
}

check_bash_bypass() {
    local command
    command=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
    [ -z "$command" ] && return 0

    # Extended pattern: direct editors, redirects, file manipulation, git commands,
    # shell bypass vectors (eval, xargs, bash -c, subshells, heredocs, exec),
    # and scripting interpreters. Best-effort — not a full shell parser.
    if ! echo "$command" | grep -Eqi '(eval|xargs|sh\s+-c|bash\s+-c|exec\s+|source\s+|\.\s+/|\$\(|[`]|<<|sed\s+-i|perl\s+(-i|-e)|awk.*inplace|echo\s+.*>|printf\s+.*>|cat\s+.*>|>\s*[^&]|tee\s+|rm\s+|mv\s+|cp\s+|truncate\s+|dd\s+|install\s+|patch\s+|git\s+(checkout|restore|mv|rm)|chmod\s+|chown\s+|ln\s+|rsync\s+|sponge\s+|python[23]?\s+-c|python[23]?\s+[^-][^[:space:]]*|ruby\s+-e|ruby\s+[^-][^[:space:]]*|node\s+-e|node\s+[^-][^[:space:]]*)'; then
        return 0
    fi

    while IFS=$'\t' read -r raw frozen_norm; do
        if echo "$command" | grep -Fq "$raw" || echo "$command" | grep -Fq "$frozen_norm"; then
            block_or_dryrun "Bash command modifies FROZEN file: $raw. To allow, remove from frozen-fragments.md."
        fi
    done < "$FROZEN_PATHS_FILE"

    local script_path normalized_script
    script_path="$(interpreter_script_path_from_command "$command")"
    [ -z "$script_path" ] && return 0

    normalized_script="$(normalize_path "$script_path")"
    [ -f "$normalized_script" ] || return 0

    while IFS=$'\t' read -r raw frozen_norm; do
        if grep -Fq "$raw" "$normalized_script" 2>/dev/null || grep -Fq "$frozen_norm" "$normalized_script" 2>/dev/null; then
            block_or_dryrun "Interpreter script references FROZEN file path: $raw. To allow, remove from frozen-fragments.md."
        fi
    done < "$FROZEN_PATHS_FILE"
}

case "$TOOL_NAME" in
    Write|Edit)
        check_surgical_patching
        check_direct_file_edit
        ;;
    Bash)
        check_bash_bypass
        ;;
    "")
        # Unknown/empty tool name: best-effort checks for file_path and command.
        check_direct_file_edit
        check_bash_bypass
        ;;
esac

emit_event "check-frozen" "ALLOW" "{\"tool\":\"${TOOL_NAME:-unknown}\"}" 2>/dev/null || true
exit 0
