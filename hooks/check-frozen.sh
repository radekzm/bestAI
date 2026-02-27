#!/bin/bash
# hooks/check-frozen.sh — PreToolUse hook (Edit|Write|Bash matcher)
# Blocks edits to files listed in frozen-fragments.md
# Exit 2 = BLOCK (deterministic enforcement)
# DESIGN: Fails CLOSED — blocks when uncertain (missing deps, bad input)

set -euo pipefail

# Dry-run mode: log what would be blocked but don't actually block
BESTAI_DRY_RUN="${BESTAI_DRY_RUN:-0}"
block_or_dryrun() {
    emit_event "check-frozen" "BLOCK" "{\"reason\":\"$*\"}" 2>/dev/null || true
    if [ "$BESTAI_DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] WOULD BLOCK: $*" >&2
        exit 0
    else
        echo "BLOCKED: $*" >&2
        exit 2
    fi
}

# Fail closed: if jq is missing, block rather than allow
if ! command -v jq &>/dev/null; then
    echo "BLOCKED: jq is not installed. Cannot validate frozen files." >&2
    exit 2
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || {
    echo "BLOCKED: Failed to parse hook input JSON." >&2
    exit 2
}
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || {
    echo "BLOCKED: Failed to parse tool_input from JSON." >&2
    exit 2
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')

# Unified JSONL event logging
_BESTAI_TOOL_NAME="$TOOL_NAME"
# shellcheck source=hook-event.sh
source "$(dirname "$0")/hook-event.sh" 2>/dev/null || true

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
    local file_path normalized_file

    file_path=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)
    [ -z "$file_path" ] && return 0

    normalized_file=$(normalize_path "$file_path")

    while IFS=$'\t' read -r raw frozen_norm; do
        if [ "$normalized_file" = "$frozen_norm" ]; then
            block_or_dryrun "File is FROZEN: $file_path (listed in frozen-fragments.md)"
        fi
    done < "$FROZEN_PATHS_FILE"
}

check_bash_bypass() {
    local command
    command=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
    [ -z "$command" ] && return 0

    # Extended pattern covers: direct editors, redirect operators, file manipulation,
    # git file-level commands, pipe-to-file patterns, and shell bypass vectors (eval, xargs, etc.)
    if ! echo "$command" | grep -Eqi '(eval|xargs|sh\s+-c|bash\s+-c|\$\(|[`]|sed\s+-i|perl\s+-i|awk.*inplace|echo\s+.*>|printf\s+.*>|cat\s+.*>|>\s*[^&]|tee\s+|rm\s+|mv\s+|cp\s+|truncate\s+|dd\s+|install\s+|patch\s+|git\s+(checkout|restore|mv|rm)|chmod\s+|chown\s+|ln\s+|rsync\s+|sponge\s+)'; then
        return 0
    fi

    while IFS=$'\t' read -r raw frozen_norm; do
        if echo "$command" | grep -Fq "$raw" || echo "$command" | grep -Fq "$frozen_norm"; then
            block_or_dryrun "Bash command modifies FROZEN file: $raw (command: $command)"
        fi
    done < "$FROZEN_PATHS_FILE"
}

case "$TOOL_NAME" in
    Write|Edit)
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
