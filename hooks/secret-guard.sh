#!/bin/bash
# hooks/secret-guard.sh — PreToolUse hook (Bash|Write|Edit matcher)
# Blocks obvious secret leakage patterns and git operations on secret files.

set -euo pipefail

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

contains_secret_pattern() {
    local data="$1"
    echo "$data" | grep -Eqi '(ghp_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|aws_secret_access_key|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|api[_-]?key[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|secret[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|token[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{10,}|password[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_\-\/+=]{8,})'
}

contains_secret_file_reference() {
    local data="$1"
    echo "$data" | grep -Eqi '(^|[[:space:]/])(\.env(\.[A-Za-z0-9_-]+)?|id_rsa|id_ed25519|.*\.pem|.*\.p12|.*\.key)([[:space:]]|$)'
}

case "$TOOL_NAME" in
    Bash)
        COMMAND="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)"
        [ -z "$COMMAND" ] && exit 0

        if contains_secret_pattern "$COMMAND"; then
            echo "BLOCKED: Possible secret detected in Bash command." >&2
            exit 2
        fi

        if echo "$COMMAND" | grep -Eqi 'git[[:space:]]+(add|commit|push)'; then
            if contains_secret_file_reference "$COMMAND"; then
                echo "BLOCKED: Bash command references secret-like file in git operation." >&2
                exit 2
            fi
        fi
        ;;
    Write|Edit)
        FILE_PATH="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)"
        CONTENT="$(printf '%s\n' "$TOOL_INPUT" | jq -r '.content // .new_string // empty' 2>/dev/null)"

        if [ -n "$FILE_PATH" ] && contains_secret_file_reference "$FILE_PATH"; then
            if contains_secret_pattern "$CONTENT"; then
                echo "BLOCKED: Writing likely secret to sensitive file path: $FILE_PATH" >&2
                exit 2
            fi
        fi

        if [ -n "$CONTENT" ] && contains_secret_pattern "$CONTENT"; then
            echo "BLOCKED: Write/Edit content contains likely secret material." >&2
            exit 2
        fi
        ;;
esac

exit 0
