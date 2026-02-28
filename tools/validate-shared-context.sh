#!/bin/bash
# tools/validate-shared-context.sh — minimal validator for shared context contract
# Usage: bash tools/validate-shared-context.sh <handoff.json>

set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Usage: $0 <handoff.json>" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 1
fi

errors=()

if ! jq empty "$FILE" >/dev/null 2>&1; then
    errors+=("invalid_json")
else
    version=$(jq -r '.version // empty' "$FILE")
    task_id=$(jq -r '.task_id // empty' "$FILE")
    task=$(jq -r '.task // empty' "$FILE")
    status=$(jq -r '.status // empty' "$FILE")
    vendor=$(jq -r '.owner.vendor // empty' "$FILE")
    agent=$(jq -r '.owner.agent // empty' "$FILE")
    depth=$(jq -r '.depth // empty' "$FILE")
    created_at=$(jq -r '.timestamps.created_at // empty' "$FILE")
    updated_at=$(jq -r '.timestamps.updated_at // empty' "$FILE")

    [ "$version" = "1.0" ] || errors+=("version_must_be_1_0")
    [ -n "$task_id" ] || errors+=("task_id_missing")
    [ -n "$task" ] || errors+=("task_missing")
    case "$status" in
        TASK_STARTED|TASK_BLOCKED|TASK_DONE) ;;
        *) errors+=("status_invalid") ;;
    esac
    case "$vendor" in
        claude|gemini|codex|openai|unknown) ;;
        *) errors+=("owner_vendor_invalid") ;;
    esac
    [ -n "$agent" ] || errors+=("owner_agent_missing")
    case "$depth" in
        fast|balanced|deep) ;;
        *) errors+=("depth_invalid") ;;
    esac
    [ -n "$created_at" ] || errors+=("timestamps_created_at_missing")
    [ -n "$updated_at" ] || errors+=("timestamps_updated_at_missing")

    if ! jq -e '.context.binding_refs | arrays' "$FILE" >/dev/null 2>&1; then
        errors+=("context_binding_refs_missing_or_not_array")
    fi
fi

if [ "${#errors[@]}" -gt 0 ]; then
    echo "INVALID: $FILE"
    printf ' - %s\n' "${errors[@]}"
    exit 2
fi

echo "VALID: $FILE"
