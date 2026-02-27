# Reweryfikacja Issue Lifecycle — 2026-02-27

## Zakres

Ponowny przegląd **wszystkich** zgłoszeń `open` i `closed` dla `radekzm/bestAI` na podstawie aktualnego snapshotu GitHub i stanu kodu w `master`.

Snapshot (UTC): 2026-02-27
- wszystkie issue: `53`
- open: `4`
- closed: `49`

## Metoda oceny (surowa, obiektywna)

Każde issue oceniane przez filtr:
1. Czy zakres z treści issue ma jednoznaczny ślad w kodzie.
2. Czy „zamknięte” ma dowód (testy, coverage, zachowanie runtime).
3. Czy komentarz zamykający nie deklaruje więcej niż implementacja.

## Stan otwartych (po re-triage)

| Issue | Ocena | Dlaczego open |
|---|---|---|
| #41 | poprawnie open | Self-healing nie jest realnie wdrożony; obecnie block + instrukcja manualna. |
| #45 | poprawnie open | Smart Context v2 wybiera pliki, ale nie robi rankingu `score per file`. |
| #48 | poprawnie open | Event JSONL nie obejmuje całego manifestu hooków. |
| #52 | poprawnie open | `BESTAI_DRY_RUN` nie jest unified dla wszystkich hooków. |

## Decyzje podjęte w tej rundzie

1. **Reopen #48**
- Uzasadnienie: issue mówi o unified event log "for all hooks", ale w kodzie część hooków nie emituje eventów.
- Źródła:
  - `hooks/manifest.json` definiuje pełny zestaw hooków
  - `hooks/check-user-tags.sh` brak source `hook-event.sh` i brak `emit_event`
  - `hooks/preprocess-prompt.sh` brak source `hook-event.sh` i brak `emit_event`
  - `hooks/sync-state.sh` brak source `hook-event.sh` i brak `emit_event`

2. **Reopen #41**
- Uzasadnienie: issue o self-healing (auto-fix + continue) jest domknięte, ale implementacja dalej działa jako block-only.
- Źródła:
  - `hooks/backup-enforcement.sh:13` (`block_or_dryrun`)
  - `hooks/backup-enforcement.sh:84` (instrukcja `[AUTO-FIX]` tylko do ręcznego wykonania)
  - `hooks/backup-enforcement.sh:86` (finalnie `block_or_dryrun`, czyli brak auto-fix execution)

## Stan zamkniętych — ocena zbiorcza

### To wygląda dobrze
- większość zamkniętych issue ma ślad wdrożenia w kodzie lub dokumentacji,
- testy i lint są utrzymywane na dobrym poziomie (`150/150`, lint PASS, eval gates PASS).

### Nadal ryzykowne zamknięcia (do monitoringu, niekoniecznie do natychmiastowego reopen)
- `#30` — compliance działa, ale wymaga jawnego raportowania *instrumentation coverage* (inaczej wynik może być nadinterpretowany),
- `#44` — framework testowy istnieje, ale adopcja i podpięcie pod CI pozostają ograniczone,
- `#47` — latency budget jest formalnie obecny, ale brakuje twardego runtime benchmarku per hook w regularnym pipeline.

## Metryki governance

Rozkład etykiet (top):
- `enhancement`: 20
- `priority/p1`: 15
- `priority/p2`: 15
- `status/implemented`: 14
- `assessment`: 10

Wskaźnik ryzyka procesowego:
- wiele issue było zamykanych bardzo szybko (poniżej 1h),
- szybkie zamknięcie samo w sobie nie jest błędem, ale bez dowodów istotnie podnosi ryzyko „false done”.

## Ocena końcowa governance (0-10)

**5.6/10**

Dlaczego nie wyżej:
- tempo dostarczania jest wysokie, ale jakość „definition of done” bywa nierówna,
- konieczne były re-openy w obszarach o istotnym wpływie (observability, safety UX).

## Rekomendacje (nowoczesne, mierzalne)

1. Dodać do CI gate: `issue-close-proof` (wymagany link do testu/artefaktu przy statusie `implemented`).
2. Wprowadzić metrykę `event_coverage` = `% hooków z emit_event` i publikować ją w `compliance.sh`.
3. Wprowadzić `close-cooldown` dla `P0/P1`: zamknięcie dopiero po 1 pełnym przebiegu test+lint+eval z referencją do wyniku.
4. Dodać tygodniowy raport `reopen-rate` i traktować wzrost jako sygnał jakościowy procesu, nie „porażkę”.
