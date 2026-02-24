# Evals — Benchmark + Prompt Cache Ops

Pakiet ewaluacyjny bestAI ma dwa niezależne tory:

1. Benchmark profili (`baseline`, `hooks-only`, `smart-context`)
2. Analizę trendów prompt cache (`cached_tokens`, `cache_read_input_tokens`)

## 1) Benchmark profili

Skrypt:

```bash
bash evals/run.sh
```

Co mierzymy:
- `task_success`
- `token_usage` (`input_tokens`, `output_tokens`, `total_tokens`)
- `latency_ms` (avg + p95)
- `retries`
- porównanie profili: `baseline` vs `hooks-only` vs `smart-context`

Format wejścia (`evals/data/{baseline,hooks-only,smart-context}.jsonl`):
- `task_id` (string)
- `success` (bool lub 0/1)
- `input_tokens` (number)
- `output_tokens` (number)
- `latency_ms` (number)
- `retries` (number)

Przykład:
```json
{"task_id":"T01","success":true,"input_tokens":1420,"output_tokens":380,"latency_ms":2100,"retries":0}
```

Opcje:
```bash
bash evals/run.sh \
  --tasks evals/tasks/benchmark_tasks.jsonl \
  --input-dir evals/data \
  --output evals/results/2026-02-24.md
```

Artefakty:
- `evals/results/YYYY-MM-DD.md`
- `evals/results/YYYY-MM-DD.json`

## 2) Prompt cache usage trend

Skrypt:

```bash
bash evals/cache-usage-report.sh --input evals/data/cache-usage-sample.jsonl
```

Domyślnie:
- input: `evals/data/cache-usage-sample.jsonl`
- output: `evals/results/cache-usage-YYYY-MM-DD.md`

Skrypt normalizuje pola OpenAI i Anthropic:
- OpenAI: `usage.prompt_tokens_details.cached_tokens`
- Anthropic: `usage.cache_read_input_tokens`, `usage.cache_creation_input_tokens`

Minimalny JSONL per request:
- `timestamp`
- `provider`
- `model`
- `run_id`
- `usage.*` (input/output + cache fields)

Przykład OpenAI:
```json
{"timestamp":"2026-02-24T12:00:00Z","provider":"openai","model":"gpt-5","run_id":"R-123","usage":{"prompt_tokens":3200,"completion_tokens":420,"total_tokens":3620,"prompt_tokens_details":{"cached_tokens":2400}}}
```

Przykład Anthropic:
```json
{"timestamp":"2026-02-24T12:00:02Z","provider":"anthropic","model":"claude-sonnet-4-5","run_id":"R-123","usage":{"input_tokens":260,"output_tokens":390,"cache_read_input_tokens":2940,"cache_creation_input_tokens":0}}
```

Raport zawiera:
- globalny `weighted_cache_hit_ratio_pct`
- trend dzienny
- rozbicie per provider
- sygnały bustowania cache (`cold_large_prompt_rate`, `low_hit_requests_rate`)
