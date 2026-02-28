#!/bin/bash
# tools/shared-context-merge.sh — deterministic resolver for shared-context v1.0
# Usage:
#   bash tools/shared-context-merge.sh <left.json> <right.json> [--output merged.json]

set -euo pipefail

usage() {
    echo "Usage: $0 <left.json> <right.json> [--output merged.json]" >&2
}

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    exit 1
fi

LEFT_FILE="${1:-}"
RIGHT_FILE="${2:-}"

if [ -z "$LEFT_FILE" ] || [ -z "$RIGHT_FILE" ]; then
    usage
    exit 1
fi

shift 2

OUTPUT_FILE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output)
            OUTPUT_FILE="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ ! -f "$LEFT_FILE" ] || [ ! -f "$RIGHT_FILE" ]; then
    echo "Input files must exist." >&2
    exit 1
fi

if ! jq empty "$LEFT_FILE" >/dev/null 2>&1; then
    echo "Invalid JSON: $LEFT_FILE" >&2
    exit 2
fi

if ! jq empty "$RIGHT_FILE" >/dev/null 2>&1; then
    echo "Invalid JSON: $RIGHT_FILE" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-shared-context.sh"

if [ -x "$VALIDATOR" ]; then
    bash "$VALIDATOR" "$LEFT_FILE" >/dev/null
    bash "$VALIDATOR" "$RIGHT_FILE" >/dev/null
fi

MERGED_TMP=$(mktemp)

jq -s '
    def status_rank($status):
      if $status == "TASK_DONE" then 3
      elif $status == "TASK_BLOCKED" then 2
      elif $status == "TASK_STARTED" then 1
      else 0
      end;

    def ts_epoch($ts): ($ts | fromdateiso8601? // 0);

    def winner($left; $right):
      if status_rank($left.status) > status_rank($right.status) then $left
      elif status_rank($left.status) < status_rank($right.status) then $right
      elif ts_epoch($left.timestamps.updated_at) > ts_epoch($right.timestamps.updated_at) then $left
      elif ts_epoch($left.timestamps.updated_at) < ts_epoch($right.timestamps.updated_at) then $right
      elif ($left | tojson) <= ($right | tojson) then $left
      else $right
      end;

    def uniq_strings($arr):
      ($arr
       | map(select(type == "string" and length > 0))
       | unique);

    def uniq_decisions($arr):
      ($arr
       | map(select(type == "object"))
       | sort_by(.kind // "", .source // "", .summary // "")
       | unique_by((.kind // "") + "\u0000" + (.source // "") + "\u0000" + (.summary // "")));

    .[0] as $left
    | .[1] as $right
    | winner($left; $right) as $selected
    | {
        version: "1.0",
        task_id: ($selected.task_id // $left.task_id // $right.task_id // "task-merged"),
        task: ($selected.task // $left.task // $right.task // "Merged shared context"),
        status: $selected.status,
        owner: {
          vendor: ($selected.owner.vendor // $left.owner.vendor // $right.owner.vendor // "unknown"),
          agent: ($selected.owner.agent // $left.owner.agent // $right.owner.agent // "shared-context-merge")
        },
        depth: ($selected.depth // $left.depth // $right.depth // "balanced"),
        context: {
          binding_refs: uniq_strings(($left.context.binding_refs // []) + ($right.context.binding_refs // [])),
          decisions: uniq_decisions(($left.context.decisions // []) + ($right.context.decisions // []))
        },
        timestamps: {
          created_at:
            (if ts_epoch($left.timestamps.created_at) <= ts_epoch($right.timestamps.created_at)
             then ($left.timestamps.created_at // $right.timestamps.created_at)
             else ($right.timestamps.created_at // $left.timestamps.created_at)
             end),
          updated_at:
            (if ts_epoch($left.timestamps.updated_at) >= ts_epoch($right.timestamps.updated_at)
             then ($left.timestamps.updated_at // $right.timestamps.updated_at)
             else ($right.timestamps.updated_at // $left.timestamps.updated_at)
             end)
        },
        artifacts: uniq_strings(($left.artifacts // []) + ($right.artifacts // []))
      }
' "$LEFT_FILE" "$RIGHT_FILE" > "$MERGED_TMP"

if [ -x "$VALIDATOR" ]; then
    bash "$VALIDATOR" "$MERGED_TMP" >/dev/null
fi

if [ -n "$OUTPUT_FILE" ]; then
    mv "$MERGED_TMP" "$OUTPUT_FILE"
else
    cat "$MERGED_TMP"
    rm -f "$MERGED_TMP"
fi
