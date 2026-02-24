#!/bin/bash
# evals/cache-usage-report.sh — Parse usage logs and report cached token trends.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INPUT_FILE="$ROOT_DIR/evals/data/cache-usage-sample.jsonl"
OUTPUT_FILE="$ROOT_DIR/evals/results/cache-usage-$(date -u +%Y-%m-%d).md"

usage() {
    cat <<USAGE
Usage:
  bash evals/cache-usage-report.sh [--input FILE] [--output FILE]

Defaults:
  --input   evals/data/cache-usage-sample.jsonl
  --output  evals/results/cache-usage-YYYY-MM-DD.md
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --input)
            INPUT_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
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

[ -f "$INPUT_FILE" ] || {
    echo "Input file not found: $INPUT_FILE" >&2
    exit 1
}

if ! jq empty "$INPUT_FILE" >/dev/null 2>&1; then
    echo "Input is not valid JSON/JSONL: $INPUT_FILE" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SUMMARY_TMP="$TMP_DIR/cache-summary.json"
SUMMARY_JSON="${OUTPUT_FILE%.md}.json"

jq -s --arg input_file "$INPUT_FILE" '
  def num:
    if . == null then 0
    elif type == "number" then .
    elif type == "string" then (tonumber? // 0)
    else 0 end;

  def usage_obj: (.usage // .response.usage // {});

  def provider_guess:
    (
      (.provider // .metadata.provider // .vendor // null) as $p
      | if $p != null then ($p|tostring|ascii_downcase)
        elif (usage_obj.cache_read_input_tokens? != null or usage_obj.cache_creation_input_tokens? != null) then "anthropic"
        elif (usage_obj.prompt_tokens_details.cached_tokens? != null) then "openai"
        else "unknown"
        end
    );

  def input_tokens:
    (usage_obj.input_tokens? // usage_obj.prompt_tokens? // .input_tokens? // .prompt_tokens? // 0 | num);

  def output_tokens:
    (usage_obj.output_tokens? // usage_obj.completion_tokens? // .output_tokens? // .completion_tokens? // 0 | num);

  def cached_read_tokens:
    (usage_obj.prompt_tokens_details.cached_tokens? // usage_obj.cache_read_input_tokens? // .cached_tokens? // 0 | num);

  def cached_write_tokens:
    (usage_obj.cache_creation_input_tokens? // .cache_creation_tokens? // 0 | num);

  def total_tokens($i; $o):
    (usage_obj.total_tokens? // .total_tokens? // ($i + $o) | num);

  def ts:
    (.timestamp // .created_at // .time // .started_at // .metadata.timestamp // null);

  def day($t):
    if $t == null then "unknown" else (($t|tostring)[0:10]) end;

  def ratio_denom($provider; $input; $cached_read):
    if $provider == "anthropic" then ($input + $cached_read) else $input end;

  def ratio_pct($cached_read; $denom):
    if $denom > 0 then ($cached_read / $denom * 100) else 0 end;

  def mk_row:
    . as $r
    | (provider_guess) as $provider
    | (input_tokens) as $input
    | (output_tokens) as $output
    | (cached_read_tokens) as $cached_read
    | (cached_write_tokens) as $cached_write
    | (ratio_denom($provider; $input; $cached_read)) as $ratio_den
    | {
        timestamp: ts,
        day: day(ts),
        provider: $provider,
        model: (.model // .metadata.model // "unknown"),
        run_id: (.run_id // .session_id // .request_id // "n/a"),
        cache_key: (.cache_key // .prompt_cache_key // .prefix_hash // .metadata.cache_key // ""),
        input_tokens: $input,
        output_tokens: $output,
        total_tokens: total_tokens($input; $output),
        cached_read_tokens: $cached_read,
        cached_write_tokens: $cached_write,
        ratio_denominator: $ratio_den,
        cache_hit_ratio_pct: ratio_pct($cached_read; $ratio_den),
        cold_large_prompt: (($cached_read == 0) and ($ratio_den >= 1500))
      };

  [ .[] | mk_row ] as $rows
  | {
      generated_at: (now | todateiso8601),
      input_file: $input_file,
      rows_count: ($rows|length),
      totals: {
        requests: ($rows|length),
        input_tokens: ($rows|map(.input_tokens)|add // 0),
        output_tokens: ($rows|map(.output_tokens)|add // 0),
        total_tokens: ($rows|map(.total_tokens)|add // 0),
        cached_read_tokens: ($rows|map(.cached_read_tokens)|add // 0),
        cached_write_tokens: ($rows|map(.cached_write_tokens)|add // 0),
        weighted_cache_hit_ratio_pct:
          (if (($rows|map(.ratio_denominator)|add // 0) > 0)
           then (($rows|map(.cached_read_tokens)|add // 0) / ($rows|map(.ratio_denominator)|add // 0) * 100)
           else 0 end),
        cold_large_prompt_rate_pct:
          (if ($rows|length) == 0 then 0 else (($rows|map(select(.cold_large_prompt))|length) / ($rows|length) * 100) end)
      },
      by_provider:
        ($rows
         | sort_by(.provider)
         | group_by(.provider)
         | map({
             provider: .[0].provider,
             requests: length,
             input_tokens: (map(.input_tokens)|add // 0),
             output_tokens: (map(.output_tokens)|add // 0),
             total_tokens: (map(.total_tokens)|add // 0),
             cached_read_tokens: (map(.cached_read_tokens)|add // 0),
             cached_write_tokens: (map(.cached_write_tokens)|add // 0),
             avg_input_tokens: (if length == 0 then 0 else (map(.input_tokens)|add / length) end),
             avg_output_tokens: (if length == 0 then 0 else (map(.output_tokens)|add / length) end),
             weighted_cache_hit_ratio_pct:
               (if ((map(.ratio_denominator)|add // 0) > 0)
                then ((map(.cached_read_tokens)|add // 0) / (map(.ratio_denominator)|add // 0) * 100)
                else 0 end),
             cold_large_prompt_rate_pct:
               (if length == 0 then 0 else ((map(select(.cold_large_prompt))|length) / length * 100) end)
           })),
      trend_daily:
        ($rows
         | sort_by(.day)
         | group_by(.day)
         | map({
             day: .[0].day,
             requests: length,
             input_tokens: (map(.input_tokens)|add // 0),
             output_tokens: (map(.output_tokens)|add // 0),
             cached_read_tokens: (map(.cached_read_tokens)|add // 0),
             cached_write_tokens: (map(.cached_write_tokens)|add // 0),
             weighted_cache_hit_ratio_pct:
               (if ((map(.ratio_denominator)|add // 0) > 0)
                then ((map(.cached_read_tokens)|add // 0) / (map(.ratio_denominator)|add // 0) * 100)
                else 0 end),
             avg_total_tokens: (if length == 0 then 0 else (map(.total_tokens)|add / length) end)
           })),
      bust_signals: {
        low_hit_request_threshold_pct: 20,
        low_hit_requests:
          ($rows|map(select(.ratio_denominator >= 1500 and .cache_hit_ratio_pct < 20))|length),
        low_hit_requests_rate_pct:
          (if ($rows|length) == 0 then 0 else (($rows|map(select(.ratio_denominator >= 1500 and .cache_hit_ratio_pct < 20))|length) / ($rows|length) * 100) end),
        cache_key_rows:
          ($rows|map(select(.cache_key != ""))|length),
        cache_key_unique:
          ($rows|map(select(.cache_key != "")|.cache_key)|unique|length),
        cache_key_unique_rate_pct:
          (if (($rows|map(select(.cache_key != ""))|length) == 0)
           then 0
           else (($rows|map(select(.cache_key != "")|.cache_key)|unique|length) / ($rows|map(select(.cache_key != ""))|length) * 100)
           end)
      }
    }
' "$INPUT_FILE" > "$SUMMARY_TMP"

ROWS_COUNT="$(jq -r '.rows_count' "$SUMMARY_TMP")"
if [ "$ROWS_COUNT" -eq 0 ]; then
    echo "No rows found in: $INPUT_FILE" >&2
    exit 1
fi

format_num() {
    awk -v n="$1" 'BEGIN { printf "%.2f", n }'
}

requests="$(jq -r '.totals.requests' "$SUMMARY_TMP")"
input_tokens="$(jq -r '.totals.input_tokens' "$SUMMARY_TMP")"
output_tokens="$(jq -r '.totals.output_tokens' "$SUMMARY_TMP")"
total_tokens="$(jq -r '.totals.total_tokens' "$SUMMARY_TMP")"
cached_read_tokens="$(jq -r '.totals.cached_read_tokens' "$SUMMARY_TMP")"
cached_write_tokens="$(jq -r '.totals.cached_write_tokens' "$SUMMARY_TMP")"
weighted_hit_ratio="$(jq -r '.totals.weighted_cache_hit_ratio_pct' "$SUMMARY_TMP")"
cold_large_rate="$(jq -r '.totals.cold_large_prompt_rate_pct' "$SUMMARY_TMP")"
low_hit_rate="$(jq -r '.bust_signals.low_hit_requests_rate_pct' "$SUMMARY_TMP")"
cache_key_rows="$(jq -r '.bust_signals.cache_key_rows' "$SUMMARY_TMP")"
cache_key_unique_rate="$(jq -r '.bust_signals.cache_key_unique_rate_pct' "$SUMMARY_TMP")"

{
    echo "# Cache Usage Report — $(date -u +%Y-%m-%d)"
    echo ""
    echo "Generated by: \`bash evals/cache-usage-report.sh\`"
    echo ""
    echo "## Configuration"
    echo "- input_file: \`$INPUT_FILE\`"
    echo "- rows: $ROWS_COUNT"
    echo ""
    echo "## Global Metrics"
    echo "| Metric | Value |"
    echo "|---|---:|"
    printf '| Requests | %s |\n' "$requests"
    printf '| Input tokens | %s |\n' "$input_tokens"
    printf '| Output tokens | %s |\n' "$output_tokens"
    printf '| Total tokens | %s |\n' "$total_tokens"
    printf '| Cached read tokens | %s |\n' "$cached_read_tokens"
    printf '| Cached write tokens | %s |\n' "$cached_write_tokens"
    printf '| Weighted cache hit ratio | %s%% |\n' "$(format_num "$weighted_hit_ratio")"
    printf '| Cold large prompt rate | %s%% |\n' "$(format_num "$cold_large_rate")"
    echo ""
    echo "## Provider Breakdown"
    echo "| Provider | Requests | Avg input | Avg output | Cached read total | Cached write total | Weighted hit ratio | Cold large rate |"
    echo "|---|---:|---:|---:|---:|---:|---:|---:|"
    while IFS= read -r row; do
        provider="$(jq -r '.provider' <<< "$row")"
        prequests="$(jq -r '.requests' <<< "$row")"
        pavg_in="$(jq -r '.avg_input_tokens' <<< "$row")"
        pavg_out="$(jq -r '.avg_output_tokens' <<< "$row")"
        pread="$(jq -r '.cached_read_tokens' <<< "$row")"
        pwrite="$(jq -r '.cached_write_tokens' <<< "$row")"
        phit="$(jq -r '.weighted_cache_hit_ratio_pct' <<< "$row")"
        pcold="$(jq -r '.cold_large_prompt_rate_pct' <<< "$row")"
        printf '| %s | %s | %s | %s | %s | %s | %s%% | %s%% |\n' \
          "$provider" \
          "$prequests" \
          "$(format_num "$pavg_in")" \
          "$(format_num "$pavg_out")" \
          "$pread" \
          "$pwrite" \
          "$(format_num "$phit")" \
          "$(format_num "$pcold")"
    done < <(jq -c '.by_provider[]' "$SUMMARY_TMP")
    echo ""
    echo "## Daily Trend"
    echo "| Day | Requests | Input total | Output total | Cached read total | Cached write total | Weighted hit ratio | Avg total tokens/request |"
    echo "|---|---:|---:|---:|---:|---:|---:|---:|"
    while IFS= read -r row; do
        day="$(jq -r '.day' <<< "$row")"
        drequests="$(jq -r '.requests' <<< "$row")"
        dinput="$(jq -r '.input_tokens' <<< "$row")"
        doutput="$(jq -r '.output_tokens' <<< "$row")"
        dread="$(jq -r '.cached_read_tokens' <<< "$row")"
        dwrite="$(jq -r '.cached_write_tokens' <<< "$row")"
        dhit="$(jq -r '.weighted_cache_hit_ratio_pct' <<< "$row")"
        davg_total="$(jq -r '.avg_total_tokens' <<< "$row")"
        printf '| %s | %s | %s | %s | %s | %s | %s%% | %s |\n' \
          "$day" \
          "$drequests" \
          "$dinput" \
          "$doutput" \
          "$dread" \
          "$dwrite" \
          "$(format_num "$dhit")" \
          "$(format_num "$davg_total")"
    done < <(jq -c '.trend_daily[]' "$SUMMARY_TMP")
    echo ""
    echo "## Cache Bust Signals"
    printf -- '- low_hit_requests_rate: %s%% (threshold: <20%% hit for prompts >=1500 tokens)\n' "$(format_num "$low_hit_rate")"
    printf -- '- cold_large_prompt_rate: %s%%\n' "$(format_num "$cold_large_rate")"
    if [ "$cache_key_rows" -gt 0 ]; then
        printf -- '- cache_key_uniqueness_rate: %s%% (higher = more prefix churn)\n' "$(format_num "$cache_key_unique_rate")"
    else
        echo "- cache_key_uniqueness_rate: n/a (no cache keys in logs)"
    fi
    echo ""
    echo "## Interpretation"
    echo "- Rising hit ratio + stable success metrics => cache strategy is working."
    echo "- High cold large prompt rate => probable prefix instability or cache key churn."
    echo "- Large write tokens with low read tokens => warmup phase or frequent busting."
    echo ""
    echo "## Schema Reminder"
    echo "Recommended fields per JSONL row:"
    echo "\`timestamp, provider, model, run_id, usage.input_tokens|prompt_tokens, usage.output_tokens|completion_tokens, usage.prompt_tokens_details.cached_tokens|usage.cache_read_input_tokens, usage.cache_creation_input_tokens\`."
} > "$OUTPUT_FILE"

cp "$SUMMARY_TMP" "$SUMMARY_JSON"

echo "Report written: $OUTPUT_FILE"
echo "Summary written: $SUMMARY_JSON"
