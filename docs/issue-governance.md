# Governance zgłoszeń (Issue Lifecycle)

## Cel

Ograniczyć przedwczesne zamykanie issue i poprawić traceability decyzji.

## Definition of Done dla `close`

Issue może być zamknięte dopiero gdy:
1. Zakres z issue ma pokrycie w kodzie (nie tylko w opisie PR).
2. Istnieją testy lub reprodukcja potwierdzająca zachowanie.
3. Komentarz zamykający zawiera:
- co wdrożono,
- linki do plików,
- wynik walidacji (`test/lint/doctor/evals`).
4. Jeżeli zakres jest częściowy, issue pozostaje otwarte lub jest rozbijane na podzadania.

## Kiedy `reopen`

Reopen gdy:
1. Zakres issue był szerszy niż faktyczna implementacja.
2. Po merge wykryto brakujące ścieżki testowe.
3. Dokumentacja deklaruje coś, czego kod nie realizuje.
4. Zmiana regresyjna unieważnia wcześniejsze „done”.

## Triage severity

| Poziom | Znaczenie |
|---|---|
| P0 | Krytyczne ryzyko bezpieczeństwa/correctness |
| P1 | Wysoki wpływ, pilne domknięcie |
| P2 | Usprawnienia i dług techniczny |

## Minimalna checklista komentarza końcowego

```markdown
## Podsumowanie
- Zakres: ...
- Status: done/partial

## Dowody
- [plik:linia](...)
- test: ...
- lint: ...
- doctor/evals: ...

## Ryzyka
- ...
```

## Anti-patterny (zakazane)

1. Batch-close wielu issue bez dowodów per issue.
2. Zamknięcie na podstawie samego „wydaje się zaimplementowane”.
3. Deklaracja `implemented`, gdy istnieje tylko placeholder.

## Rekomendacja operacyjna

- Raz dziennie uruchamiaj przegląd:
  - open issues + mapping do kodu,
  - closed high-impact issues z ostatnich 72h,
  - lista reopen candidate.

## Governance gates (zalecane)

1. `issue-close-proof`: przy `close` wymagany link do testu/artefaktu.
2. `close-cooldown` dla `P0/P1`: zamknięcie dopiero po pełnym przebiegu test+lint+eval.
3. `reopen-rate` monitorowany tygodniowo jako KPI jakości decyzji.
