#!/bin/bash
# tools/swarm-dispatch.sh — Multi-Vendor Task Dispatcher
# Usage: bash tools/swarm-dispatch.sh --task "Find bugs" --vendor gemini

set -euo pipefail

TASK=""
VENDOR="claude"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task) TASK="${2:-}"; shift 2 ;;
        --vendor) VENDOR="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

if [ -z "$TASK" ]; then
    echo "Usage: $0 --task 'description' --vendor [claude|gemini|codex]"
    exit 1
fi

echo "🚀 Dispatching task to $VENDOR..."
echo "Task: $TASK"
echo "Shared Context: .bestai/GPS.json"

case "$VENDOR" in
    claude)
        # Claude is great for strict coding and architecture
        if command -v claude >/dev/null; then
            claude -p "Read .bestai/GPS.json. TASK: $TASK"
        else
            echo "Claude Code CLI not installed."
        fi
        ;;
    gemini)
        # Gemini is used for large context or fast research
        # (Assuming 'gemini' is the binary name for the Gemini CLI)
        if command -v gemini >/dev/null; then
            gemini --prompt "Read .bestai/GPS.json. TASK: $TASK"
        else
            echo "Gemini CLI not installed. Please install it first."
        fi
        ;;
    codex|openai)
        echo "Dispatching to Codex/OpenAI for boilerplate/testing..."
        # Add local codex CLI execution here
        ;;
    *)
        echo "Unknown vendor: $VENDOR. Supported: claude, gemini, codex."
        exit 1
        ;;
esac
