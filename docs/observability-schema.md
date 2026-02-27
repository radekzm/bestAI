# Observability Schema (bestAI)

## Cel

Ujednolicony opis źródeł metryk, lokalizacji logów i pól JSON.

## Event log (JSONL)

Domyślna ścieżka:
- `~/.cache/bestai/events.jsonl`

Override:
- `BESTAI_EVENT_LOG=/custom/path/events.jsonl`

Generator:
- `hooks/hook-event.sh` (`emit_event`)

## Rekord eventu

Każda linia to osobny obiekt JSON:

```json
{
  "ts": "2026-02-27T02:08:01Z",
  "hook": "check-frozen",
  "action": "BLOCK",
  "tool": "Edit",
  "project": "abc123...",
  "elapsed_ms": 12,
  "detail": {"reason": "File is FROZEN"}
}
```

Pola:
- `ts`: timestamp UTC
- `hook`: nazwa hooka
- `action`: `ALLOW|BLOCK|OPEN|HALF_OPEN|...`
- `tool`: narzędzie (`Bash|Edit|Write|...`)
- `project`: hash projektu
- `elapsed_ms`: opóźnienie wykonania
- `detail`: dodatkowe dane kontekstowe

## Compliance source of truth

`compliance.sh` czyta:
- `BESTAI_EVENT_LOG` (lub domyślny cache path),
- filtruje po hashu projektu.

Wniosek operacyjny:
- jeżeli hook nie emituje eventów, nie będzie widoczny w compliance.

## Stats source of truth

`stats.sh` korzysta z:
- event logu JSONL,
- local runtime state (`~/.claude/projects/...`),
- `hook-metrics.log` (jeśli obecny),
- `GPS.json` w projekcie.

## Minimalne checki diagnostyczne

```bash
# Czy event log istnieje
test -f "${BESTAI_EVENT_LOG:-$HOME/.cache/bestai/events.jsonl}" && echo OK

# Ostatnie wpisy dla projektu
PROJ_HASH="$(bash -lc 'source hooks/hook-event.sh; _bestai_project_hash .')"
grep "\"project\":\"$PROJ_HASH\"" "${BESTAI_EVENT_LOG:-$HOME/.cache/bestai/events.jsonl}" | tail -20

# Raport compliance
bash compliance.sh . --json
```

## Known gaps

1. Nie wszystkie hooki emitują eventy z równą granularnością.
2. Coverage eventów trzeba traktować jako osobną metrykę jakości.
3. `detail` powinien być zawsze bezpiecznie serializowany (escaping).
