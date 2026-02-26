#!/bin/bash
# evals/run.sh — Reproducible benchmark report for bestAI

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASKS_FILE="$ROOT_DIR/evals/tasks/benchmark_tasks.jsonl"
INPUT_DIR="$ROOT_DIR/evals/data"
OUTPUT_FILE="$ROOT_DIR/evals/results/$(date -u +%Y-%m-%d).md"
ENFORCE_GATES=0

usage() {
    cat <<USAGE
Usage:
  bash evals/run.sh [--tasks FILE] [--input-dir DIR] [--output FILE] [--enforce-gates]

Defaults:
  --tasks     evals/tasks/benchmark_tasks.jsonl
  --input-dir evals/data
  --output    evals/results/YYYY-MM-DD.md
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tasks)
            TASKS_FILE="$2"
            shift 2
            ;;
        --input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --enforce-gates)
            ENFORCE_GATES=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

for dep in jq awk; do
    command -v "$dep" >/dev/null 2>&1 || {
        echo "Missing dependency: $dep" >&2
        exit 1
    }
done

[ -f "$TASKS_FILE" ] || {
    echo "Tasks file not found: $TASKS_FILE" >&2
    exit 1
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

PROFILES=("baseline" "hooks-only" "smart-context")
METRICS_DIR=$(mktemp -d)
trap 'rm -rf "$METRICS_DIR"' EXIT

EXPECTED_COUNT=$(jq -s 'length' "$TASKS_FILE")
EXPECTED_IDS_FILE="$METRICS_DIR/expected_ids.txt"
jq -r '.task_id' "$TASKS_FILE" | sort -u > "$EXPECTED_IDS_FILE"

calc_pct() {
    local new="$1"
    local old="$2"
    awk -v n="$new" -v o="$old" 'BEGIN { if (o == 0) { printf "0.00" } else { printf "%.2f", ((n-o)/o)*100 } }'
}

format_num() {
    awk -v n="$1" 'BEGIN { printf "%.2f", n }'
}

profile_exists=0
for profile in "${PROFILES[@]}"; do
    file="$INPUT_DIR/${profile}.jsonl"
    if [ ! -f "$file" ]; then
        continue
    fi

    profile_exists=1

    metrics_json="$METRICS_DIR/${profile}.json"
    coverage_json="$METRICS_DIR/${profile}_coverage.json"

    jq -s '
      def to_num: if type == "number" then . else (tonumber? // 0) end;
      def as_success:
        if (.success|type) == "boolean" then .success
        elif (.success|type) == "number" then (.success > 0)
        elif (.success|type) == "string" then
          ((.success|ascii_downcase) == "true" or .success == "1" or (.success|ascii_downcase) == "yes")
        else false end;

      . as $rows |
      {
        runs: ($rows|length),
        unique_tasks: ($rows|map(.task_id)|map(select(. != null))|unique|length),
        success_count: ($rows|map(select(as_success))|length),
        success_rate: (if ($rows|length)==0 then 0 else (($rows|map(select(as_success))|length) / ($rows|length) * 100) end),
        avg_input_tokens: (if ($rows|length)==0 then 0 else ($rows|map(.input_tokens|to_num)|add / ($rows|length)) end),
        avg_output_tokens: (if ($rows|length)==0 then 0 else ($rows|map(.output_tokens|to_num)|add / ($rows|length)) end),
        avg_total_tokens: (if ($rows|length)==0 then 0 else ($rows|map((.input_tokens|to_num)+(.output_tokens|to_num))|add / ($rows|length)) end),
        avg_latency_ms: (if ($rows|length)==0 then 0 else ($rows|map(.latency_ms|to_num)|add / ($rows|length)) end),
        p95_latency_ms: (if ($rows|length)==0 then 0 else (($rows|map(.latency_ms|to_num)|sort)|.[(((length-1)*0.95)|floor)]) end),
        avg_retries: (if ($rows|length)==0 then 0 else ($rows|map(.retries|to_num)|add / ($rows|length)) end)
      }
    ' "$file" > "$metrics_json"

    jq -n \
      --slurpfile expected "$TASKS_FILE" \
      --slurpfile data "$file" '
        {
          expected_task_ids: ($expected|map(.task_id)|unique|sort),
          observed_task_ids: ($data|map(.task_id)|unique|sort)
        }
        | . + {
          missing_task_ids: (.expected_task_ids - .observed_task_ids),
          extra_task_ids: (.observed_task_ids - .expected_task_ids)
        }
      ' > "$coverage_json"
done

if [ "$profile_exists" -eq 0 ]; then
    echo "No input profile files found in: $INPUT_DIR" >&2
    echo "Expected files: baseline.jsonl, hooks-only.jsonl, smart-context.jsonl" >&2
    exit 1
fi

BASELINE_METRICS="$METRICS_DIR/baseline.json"
HOOKS_METRICS="$METRICS_DIR/hooks-only.json"
SMART_METRICS="$METRICS_DIR/smart-context.json"

GATE_FAIL=0
GATE_REPORT=""
if [ "$ENFORCE_GATES" -eq 1 ]; then
    GATE_REPORT="## Quality Gates"$'\n'
    GATE_REPORT+="Policy: hooks-only and smart-context must not regress vs baseline"$'\n'

    if [ ! -f "$BASELINE_METRICS" ] || [ ! -f "$HOOKS_METRICS" ] || [ ! -f "$SMART_METRICS" ]; then
        GATE_REPORT+="- FAIL: Missing one or more required profiles (baseline/hooks-only/smart-context)."$'\n'
        GATE_FAIL=1
    else
        base_success=$(jq -r '.success_rate' "$BASELINE_METRICS")
        hooks_success=$(jq -r '.success_rate' "$HOOKS_METRICS")
        smart_success=$(jq -r '.success_rate' "$SMART_METRICS")
        base_tokens=$(jq -r '.avg_total_tokens' "$BASELINE_METRICS")
        hooks_tokens=$(jq -r '.avg_total_tokens' "$HOOKS_METRICS")
        smart_tokens=$(jq -r '.avg_total_tokens' "$SMART_METRICS")

        if awk -v h="$hooks_success" -v b="$base_success" 'BEGIN { exit !(h < b) }'; then
            GATE_REPORT+="- FAIL: hooks-only success rate (${hooks_success}%) < baseline (${base_success}%)."$'\n'
            GATE_FAIL=1
        else
            GATE_REPORT+="- PASS: hooks-only success rate (${hooks_success}%) >= baseline (${base_success}%)."$'\n'
        fi

        if awk -v s="$smart_success" -v h="$hooks_success" 'BEGIN { exit !(s < h) }'; then
            GATE_REPORT+="- FAIL: smart-context success rate (${smart_success}%) < hooks-only (${hooks_success}%)."$'\n'
            GATE_FAIL=1
        else
            GATE_REPORT+="- PASS: smart-context success rate (${smart_success}%) >= hooks-only (${hooks_success}%)."$'\n'
        fi

        if awk -v h="$hooks_tokens" -v b="$base_tokens" 'BEGIN { exit !(h > b*1.05) }'; then
            GATE_REPORT+="- FAIL: hooks-only avg tokens (${hooks_tokens}) > baseline +5% (${base_tokens})."$'\n'
            GATE_FAIL=1
        else
            GATE_REPORT+="- PASS: hooks-only avg tokens (${hooks_tokens}) within +5% budget vs baseline (${base_tokens})."$'\n'
        fi

        if awk -v s="$smart_tokens" -v h="$hooks_tokens" 'BEGIN { exit !(s > h*1.05) }'; then
            GATE_REPORT+="- FAIL: smart-context avg tokens (${smart_tokens}) > hooks-only +5% (${hooks_tokens})."$'\n'
            GATE_FAIL=1
        else
            GATE_REPORT+="- PASS: smart-context avg tokens (${smart_tokens}) within +5% budget vs hooks-only (${hooks_tokens})."$'\n'
        fi
    fi
    GATE_REPORT+=$'\n'
fi

{
    echo "# Evals Report — $(date -u +%Y-%m-%d)"
    echo ""
    echo "Generated by: \`bash evals/run.sh\`"
    echo ""
    echo "## Configuration"
    echo "- tasks_file: \`$TASKS_FILE\`"
    echo "- input_dir: \`$INPUT_DIR\`"
    echo "- expected_tasks: $EXPECTED_COUNT"
    echo ""

    echo "## Benchmark Set"
    echo "| Category | Tasks |"
    echo "|----------|------:|"
    jq -r -s 'group_by(.category) | map({category: .[0].category, count: length}) | .[] | "| \(.category) | \(.count) |"' "$TASKS_FILE"
    echo ""

    echo "## Profile Metrics"
    echo "| Profile | Runs | Coverage | Success % | Avg total tokens | Avg latency ms | P95 latency ms | Avg retries |"
    echo "|---------|-----:|---------:|----------:|-----------------:|---------------:|---------------:|------------:|"

    for profile in "${PROFILES[@]}"; do
        metrics_json="$METRICS_DIR/${profile}.json"
        coverage_json="$METRICS_DIR/${profile}_coverage.json"
        [ -f "$metrics_json" ] || continue

        runs=$(jq -r '.runs' "$metrics_json")
        success_rate=$(jq -r '.success_rate' "$metrics_json")
        avg_total_tokens=$(jq -r '.avg_total_tokens' "$metrics_json")
        avg_latency_ms=$(jq -r '.avg_latency_ms' "$metrics_json")
        p95_latency_ms=$(jq -r '.p95_latency_ms' "$metrics_json")
        avg_retries=$(jq -r '.avg_retries' "$metrics_json")

        missing_count=$(jq -r '.missing_task_ids | length' "$coverage_json")
        coverage_pct=$(awk -v e="$EXPECTED_COUNT" -v m="$missing_count" 'BEGIN { if (e==0) { printf "0.00" } else { printf "%.2f", ((e-m)/e)*100 } }')

        printf '| %s | %s | %s%% | %s%% | %s | %s | %s | %s |\n' \
          "$profile" \
          "$runs" \
          "$(format_num "$coverage_pct")" \
          "$(format_num "$success_rate")" \
          "$(format_num "$avg_total_tokens")" \
          "$(format_num "$avg_latency_ms")" \
          "$(format_num "$p95_latency_ms")" \
          "$(format_num "$avg_retries")"
    done
    echo ""

    if [ -f "$BASELINE_METRICS" ]; then
        echo "## Delta vs baseline"
        echo "| Profile | Success delta (pp) | Avg total tokens delta % | Avg latency delta % | Avg retries delta % |"
        echo "|---------|-------------------:|-------------------------:|--------------------:|--------------------:|"

        base_success=$(jq -r '.success_rate' "$BASELINE_METRICS")
        base_tokens=$(jq -r '.avg_total_tokens' "$BASELINE_METRICS")
        base_latency=$(jq -r '.avg_latency_ms' "$BASELINE_METRICS")
        base_retries=$(jq -r '.avg_retries' "$BASELINE_METRICS")

        for profile in "hooks-only" "smart-context"; do
            metrics_json="$METRICS_DIR/${profile}.json"
            [ -f "$metrics_json" ] || continue

            success=$(jq -r '.success_rate' "$metrics_json")
            tokens=$(jq -r '.avg_total_tokens' "$metrics_json")
            latency=$(jq -r '.avg_latency_ms' "$metrics_json")
            retries=$(jq -r '.avg_retries' "$metrics_json")

            success_delta=$(awk -v n="$success" -v b="$base_success" 'BEGIN { printf "%.2f", (n-b) }')
            tokens_delta=$(calc_pct "$tokens" "$base_tokens")
            latency_delta=$(calc_pct "$latency" "$base_latency")
            retries_delta=$(calc_pct "$retries" "$base_retries")

            printf '| %s | %s | %s%% | %s%% | %s%% |\n' "$profile" "$success_delta" "$tokens_delta" "$latency_delta" "$retries_delta"
        done
        echo ""
    fi

    echo "## Coverage Diagnostics"
    for profile in "${PROFILES[@]}"; do
        coverage_json="$METRICS_DIR/${profile}_coverage.json"
        [ -f "$coverage_json" ] || continue

        missing_count=$(jq -r '.missing_task_ids | length' "$coverage_json")
        extra_count=$(jq -r '.extra_task_ids | length' "$coverage_json")

        echo "### $profile"
        echo "- missing_tasks: $missing_count"
        if [ "$missing_count" -gt 0 ]; then
            echo "- missing_task_ids:"
            jq -r '.missing_task_ids[]' "$coverage_json" | sed 's/^/  - /'
        fi
        echo "- extra_tasks: $extra_count"
        if [ "$extra_count" -gt 0 ]; then
            echo "- extra_task_ids:"
            jq -r '.extra_task_ids[]' "$coverage_json" | sed 's/^/  - /'
        fi
        echo ""
    done

    echo "## Interpretation Guide"
    echo "- Success up, retries down, latency stable/down => profile improvement"
    echo "- Token reduction with stable success => context efficiency gain"
    echo "- Success down with token down => over-compression/routing miss"
    echo ""
    if [ "$ENFORCE_GATES" -eq 1 ]; then
        echo "$GATE_REPORT"
    fi
    echo "## Schema Reminder"
    echo "Each JSONL row should include: \`task_id, success, input_tokens, output_tokens, latency_ms, retries\`."
} > "$OUTPUT_FILE"

SUMMARY_JSON="${OUTPUT_FILE%.md}.json"

jq -n \
  --arg tasks_file "$TASKS_FILE" \
  --arg input_dir "$INPUT_DIR" \
  --arg output_file "$OUTPUT_FILE" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson enforce_gates "$ENFORCE_GATES" \
  --argjson gate_failed "$GATE_FAIL" \
  --argjson expected_tasks "$EXPECTED_COUNT" \
  --slurpfile baseline "$METRICS_DIR/baseline.json" \
  --slurpfile hooks "$METRICS_DIR/hooks-only.json" \
  --slurpfile smart "$METRICS_DIR/smart-context.json" '
  {
    generated_at: $generated_at,
    tasks_file: $tasks_file,
    input_dir: $input_dir,
    output_file: $output_file,
    enforce_gates: $enforce_gates,
    gate_failed: $gate_failed,
    expected_tasks: $expected_tasks,
    metrics: {
      baseline: ($baseline[0] // null),
      hooks_only: ($hooks[0] // null),
      smart_context: ($smart[0] // null)
    }
  }
' > "$SUMMARY_JSON"

echo "Report written: $OUTPUT_FILE"
echo "Summary written: $SUMMARY_JSON"

if [ "$ENFORCE_GATES" -eq 1 ] && [ "$GATE_FAIL" -eq 1 ]; then
    echo "Quality gates failed." >&2
    exit 2
fi
