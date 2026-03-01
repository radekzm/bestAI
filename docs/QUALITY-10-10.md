# bestAI Quality 10/10 Playbook

## Cel

Utrzymać projekt w stanie przewidywalnym, testowalnym i gotowym do rozwoju przez wielu agentów jednocześnie.

## Scorecard 10/10

| Obszar | Kryterium 10/10 | Miernik |
|---|---|---|
| Correctness | Brak regresji na `master` | 100% zielone `quality` |
| CLI Contract | Stabilny interfejs komend | `--help` i `--version` działają dla komend kluczowych |
| Governance | Brak omijania quality gates | Branch protection + required checks aktywne |
| Dokumentacja | Brak driftu wersji i zachowania | README/CHANGELOG zgodne z kodem i testami |
| Orchestrator | Ścieżka build + smoke jest egzekwowana | CI buduje `orchestrator` i wykonuje smoke CLI |

## Release Gate (obowiązkowe)

Przed merge do `master`:

```bash
npm test
bash tools/hook-lint.sh .
bash doctor.sh .
npm pack --dry-run
```

Jeżeli zmiana dotyczy orchestratora:

```bash
npm --prefix orchestrator ci
npm --prefix orchestrator run build
node bin/bestai.js orchestrate status
```

## Weekly Quality Review

1. Przegląd wszystkich otwartych `P0/P1` i regresji.
2. Przegląd ostatnich 7 dni merge na `master`:
   - czy były czerwone runy CI,
   - czy były reopen po merge.
3. Aktualizacja scorecard:
   - obszary <10/10 wymagają planu naprawczego z właścicielem i terminem.

## Reopen Policy

Issue wraca do `OPEN`, gdy:

1. Testy na `master` nie potwierdzają deklarowanej naprawy.
2. CLI/API kontrakt różni się od dokumentacji.
3. Zmiana została zmergowana bez wymaganych dowodów walidacji.

## Backlog 10/10 (aktywny)

- `#112` Orchestrator artifact readiness
- `#115` CI build + smoke orchestratora
- `#114` Centralna scorecard i roadmapa 10/10

## Definition of Done (10/10)

Każdy punkt uznaje się za domknięty dopiero gdy:

1. Jest merge do `master`.
2. CI po merge jest zielone.
3. Dokumentacja została zaktualizowana.
4. Issue ma komentarz z dowodami (pliki + testy + wynik).
