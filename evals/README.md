# Evals — Reproducible Benchmark Pack

Minimalny pakiet ewaluacji dla bestAI.

## Co mierzymy
- `task_success`
- `token_usage` (`input_tokens`, `output_tokens`, `total_tokens`)
- `latency_ms` (avg + p95)
- `retries`
- porównanie profili: `baseline` vs `hooks-only` vs `smart-context`

## Format danych wejściowych
Każdy profil ma osobny plik JSONL w `evals/data/`:

- `baseline.jsonl`
- `hooks-only.jsonl`
- `smart-context.jsonl`

Wymagane pola per linia:
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

## Uruchomienie
```bash
bash evals/run.sh
```

Domyślnie:
- tasks: `evals/tasks/benchmark_tasks.jsonl`
- input: `evals/data/*.jsonl`
- output: `evals/results/YYYY-MM-DD.md`

## Opcje
```bash
bash evals/run.sh \
  --tasks evals/tasks/benchmark_tasks.jsonl \
  --input-dir evals/data \
  --output evals/results/2026-02-24.md
```

## Dodatkowe artefakty
Skrypt tworzy także JSON summary obok raportu Markdown:
- `evals/results/YYYY-MM-DD.json`
