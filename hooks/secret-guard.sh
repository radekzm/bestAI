#!/bin/bash
# hooks/secret-guard.sh — PreToolUse hook (Bash|Write|Edit matcher)
# Blocks obvious secret leakage patterns and git operations on secret files.

set -euo pipefail

# Dry-run mode: report potential blocks but do not block execution.
BESTAI_DRY_RUN="${BESTAI_DRY_RUN:-0}"

block_or_dryrun() {
    local reason="$1"
    emit_event "secret-guard" "BLOCK" "{\"reason\":\"$reason\"}" 2>/dev/null || true
    if [ "$BESTAI_DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] WOULD BLOCK: $reason" >&2
        exit 0
    fi
    echo "BLOCKED: $reason" >&2
    exit 2
}

if ! command -v jq >/dev/null 2>&1; then
    echo "BLOCKED: secret-guard requires jq for safe parsing." >&2
    exit 2
fi

INPUT="$(cat)"
TOOL_NAME="$(printf '%s\n' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || {
    echo "BLOCKED: Failed to parse hook input JSON." >&2
    exit 2
}
TOOL_INPUT="$(printf '%s\n' "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)" || {
    echo "BLOCKED: Failed to parse tool_input." >&2
    exit 2
}

_BESTAI_TOOL_NAME="$TOOL_NAME"
# shellcheck source=hook-event.sh
source "$(dirname "$0")/hook-event.sh" 2>/dev/null || true

contains_secret_pattern() {
    local data="$1"
    echo "$data" | grep -Eqi '(ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|aws_secret_access_key|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|api[_-]?key[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|secret[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|token[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|password[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{8,})'
}

contains_secret_file_reference() {
    local data="$1"
    echo "$data" | grep -Eqi '(^|[[:space:]/])(\.env(\.[A-Za-z0-9_-]+)?|id_rsa|id_ed25519|.*\.pem|.*\.p12|.*\.key)([[:space:]]|$)'
}

contains_exfil_channel() {
    local data="$1"
    echo "$data" | grep -Eqi '([|]|curl[[:space:]]|wget[[:space:]]|scp[[:space:]]|rsync[[:space:]]|sftp[[:space:]]|ftp[[:space:]]|nc[[:space:]]|netcat[[:space:]]|ssh[[:space:]].*[@:]|http[s]?://|mail[[:space:]]|sendmail[[:space:]]|gh[[:space:]]+gist|xclip|pbcopy)'
}

case "$TOOL_NAME" in
    Bash)
        COMMAND="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)"
        [ -z "$COMMAND" ] && exit 0

        if contains_secret_pattern "$COMMAND"; then
            block_or_dryrun "Possible secret detected in Bash command."
        fi

        if contains_secret_file_reference "$COMMAND"; then
            if echo "$COMMAND" | grep -Eqi 'git[[:space:]]+(add|commit|push)'; then
                block_or_dryrun "Bash command references secret-like file in git operation."
            fi
            if contains_exfil_channel "$COMMAND"; then
                block_or_dryrun "Bash command references secret-like file with exfiltration-like channel."
            fi
        fi
        ;;
    Write|Edit)
        FILE_PATH="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)"
        CONTENT="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.content // .new_string // empty' 2>/dev/null)"

        if [ -n "$FILE_PATH" ] && contains_secret_file_reference "$FILE_PATH"; then
            if contains_secret_pattern "$CONTENT"; then
                block_or_dryrun "Writing likely secret to sensitive file path: $FILE_PATH"
            fi
        fi

        if [ -n "$CONTENT" ] && contains_secret_pattern "$CONTENT"; then
            block_or_dryrun "Write/Edit content contains likely secret material."
        fi
        ;;
esac

emit_event "secret-guard" "ALLOW" "{\"tool\":\"${TOOL_NAME:-unknown}\"}" 2>/dev/null || true
exit 0
