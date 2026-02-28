#!/bin/bash
# tools/swarm-dispatch.sh — Multi-Vendor Task Dispatcher with adaptive routing
# Usage:
#   bash tools/swarm-dispatch.sh --task "Find bugs"
#   bash tools/swarm-dispatch.sh --task "Refactor auth" --vendor claude --depth deep

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TASK=""
VENDOR=""
DEPTH=""
PROJECT_DIR="."
TASK_ID=""
AUTO_ROUTE=1

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task) TASK="${2:-}"; shift 2 ;;
        --vendor) VENDOR="${2:-}"; AUTO_ROUTE=0; shift 2 ;;
        --depth) DEPTH="${2:-}"; shift 2 ;;
        --project-dir) PROJECT_DIR="${2:-.}"; shift 2 ;;
        --task-id) TASK_ID="${2:-}"; shift 2 ;;
        --auto-route) AUTO_ROUTE=1; shift ;;
        *) shift ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task 'description' [--vendor claude|gemini|codex] [--depth fast|balanced|deep] [--project-dir .]" >&2
    exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[ -n "$TASK_ID" ] || TASK_ID="task-$(date -u +%Y%m%dT%H%M%SZ)"

if [ "$AUTO_ROUTE" -eq 1 ]; then
    ROUTE_JSON=$(bash "$SCRIPT_DIR/task-router.sh" --task "$TASK" --project-dir "$PROJECT_DIR" --json 2>/dev/null || true)
    if [ -n "$ROUTE_JSON" ] && printf '%s' "$ROUTE_JSON" | jq -e . >/dev/null 2>&1; then
        VENDOR=$(printf '%s' "$ROUTE_JSON" | jq -r '.vendor // "claude"')
        [ -n "$DEPTH" ] || DEPTH=$(printf '%s' "$ROUTE_JSON" | jq -r '.depth // "balanced"')
    fi
fi

[ -n "$VENDOR" ] || VENDOR="claude"
[ -n "$DEPTH" ] || DEPTH="balanced"

case "$DEPTH" in
    fast|balanced|deep) ;;
    *) DEPTH="balanced" ;;
esac

# Build binding context from historical memory/decisions.
BINDING_CONTEXT=$(bash "$SCRIPT_DIR/task-memory-binding.sh" --task "$TASK" --project-dir "$PROJECT_DIR" --max-files 3 --max-lines 10 2>/dev/null || true)
BINDING_JSON=$(bash "$SCRIPT_DIR/task-memory-binding.sh" --task "$TASK" --project-dir "$PROJECT_DIR" --max-files 3 --max-lines 10 --json 2>/dev/null || echo '{"bindings":[],"hard_count":0,"soft_count":0}')

mkdir -p "$PROJECT_DIR/.bestai"
HANDOFF_FILE="$PROJECT_DIR/.bestai/handoff-latest.json"
TS_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

BINDING_REFS=$(printf '%s' "$BINDING_JSON" | jq -c '[.bindings[]?.source] // []' 2>/dev/null || echo '[]')
DECISIONS=$(printf '%s' "$BINDING_JSON" | jq -c '[.bindings[]? | {kind:.level, source:.source, summary:.excerpt}]' 2>/dev/null || echo '[]')

jq -n \
    --arg version "1.0" \
    --arg task_id "$TASK_ID" \
    --arg task "$TASK" \
    --arg status "TASK_STARTED" \
    --arg vendor "$VENDOR" \
    --arg agent "swarm-dispatch" \
    --arg depth "$DEPTH" \
    --arg created "$TS_NOW" \
    --arg updated "$TS_NOW" \
    --argjson refs "$BINDING_REFS" \
    --argjson decisions "$DECISIONS" \
    '{
      version:$version,
      task_id:$task_id,
      task:$task,
      status:$status,
      owner:{vendor:$vendor,agent:$agent},
      depth:$depth,
      context:{binding_refs:$refs,decisions:$decisions},
      timestamps:{created_at:$created,updated_at:$updated},
      artifacts:[".bestai/GPS.json"]
    }' > "$HANDOFF_FILE"

if [ -x "$SCRIPT_DIR/validate-shared-context.sh" ]; then
    if ! bash "$SCRIPT_DIR/validate-shared-context.sh" "$HANDOFF_FILE" >/dev/null 2>&1; then
        echo "WARN: handoff file failed validation: $HANDOFF_FILE" >&2
    fi
fi

prompt="Read .bestai/GPS.json and .bestai/handoff-latest.json.\nTASK: $TASK\nDEPTH: $DEPTH"
if [ -n "$BINDING_CONTEXT" ]; then
    prompt="$prompt\n\n$BINDING_CONTEXT"
fi

resolve_vendor() {
    local candidate="$1"
    case "$candidate" in
        claude)
            if command -v claude >/dev/null 2>&1; then
                echo "claude"
            elif command -v gemini >/dev/null 2>&1; then
                echo "gemini"
            else
                echo "none"
            fi
            ;;
        gemini)
            if command -v gemini >/dev/null 2>&1; then
                echo "gemini"
            elif command -v claude >/dev/null 2>&1; then
                echo "claude"
            else
                echo "none"
            fi
            ;;
        codex|openai)
            # Keep explicit codex selection (partial support currently).
            echo "codex"
            ;;
        *)
            echo "none"
            ;;
    esac
}

EXEC_VENDOR=$(resolve_vendor "$VENDOR")

echo "Dispatch plan: vendor=$VENDOR execution=$EXEC_VENDOR depth=$DEPTH"
echo "Task: $TASK"
echo "Shared context: .bestai/GPS.json + .bestai/handoff-latest.json"

case "$EXEC_VENDOR" in
    claude)
        claude -p "$prompt"
        ;;
    gemini)
        gemini --prompt "$prompt"
        ;;
    codex)
        echo "Codex/OpenAI dispatch selected. Local execution path is still partial."
        echo "Use handoff file: $HANDOFF_FILE"
        ;;
    none)
        echo "No supported vendor CLI found (claude/gemini)."
        echo "Prepared handoff: $HANDOFF_FILE"
        exit 1
        ;;
esac
