# Runbook Multi-Vendor Swarm (v7)

## Cel

Ten runbook opisuje **stan faktyczny** orkiestracji multi-vendor w bestAI:
- co działa produkcyjnie,
- co jest częściowe,
- co jest tylko placeholderem.

## Status wsparcia vendorów

| Vendor | Status | Jak uruchamiać | Ograniczenia |
|---|---|---|---|
| Claude CLI | implemented | `bestai swarm --task "..." --vendor claude` | Wymaga lokalnego binarnego `claude`. |
| Gemini CLI | implemented | `bestai swarm --task "..." --vendor gemini` | Wymaga lokalnego binarnego `gemini`. |
| Codex/OpenAI | partial (placeholder) | `bestai swarm --task "..." --vendor codex` | Aktualnie brak realnego wykonania polecenia przez CLI. |

## Auto-routing (MVP heurystyczny)

`swarm-dispatch.sh` wspiera teraz tryb auto (gdy nie podasz `--vendor`):
- klasyfikuje złożoność zadania (`simple|medium|complex`),
- dobiera głębokość analizy (`fast|balanced|deep`),
- rekomenduje i wybiera vendora z fallbackiem do dostępnego CLI.

Nadal nie ma:
- policy routingu uczącej się na historycznych metrykach,
- schedulerów,
- globalnego load-balancingu.

## Minimalny workflow produkcyjny

1. Ustal rolę agenta (`architect`, `investigator`, `tester`).
2. Uruchom auto-route (`bestai route --task ...`) albo wymuś `--vendor`.
3. Dispatcher tworzy handoff zgodny z kontraktem (`.bestai/handoff-latest.json`).
4. Każdy agent czyta i aktualizuje wspólny stan (`.bestai/GPS.json`).
4. Po każdej rundzie uruchom:
- `bestai test`
- `bestai lint`
- `bestai compliance <project-dir>`

## Rekomendowana mapowanie ról

| Rola | Domyślny vendor |
|---|---|
| Architektura/refaktor | Claude |
| Szerokie skanowanie/research | Gemini |
| Testy/boilerplate | Codex (gdy realna integracja zostanie dowieziona) |

## Warunki wejścia (preflight)

Przed użyciem `bestai swarm`:
- dostępny binarny CLI wybranego vendora,
- poprawny `.bestai/GPS.json` (jeśli pracujesz zespołowo),
- profile i hooki zainstalowane przez `bestai setup`,
- `doctor.sh` bez błędów krytycznych.

## Known limitations

1. `codex` path w dispatcherze jest placeholderem.
2. Auto-routing jest heurystyczny (reguły), nie policy-driven.
3. Brak centralnego SLA/per-vendor retry policy.
4. Brak metryk per-vendor w jednym zunifikowanym dashboardzie (poza podstawowym `bestai cockpit`).

## Plan dojścia do "real swarm"

Etap 1:
- realne wykonanie ścieżki `codex`,
- jednolity kod wyjścia dispatchera.

Etap 2:
- policy router (`task class -> vendor`) z fallbackiem.

Etap 3:
- metryki per-vendor (success/latency/cost) i adaptive routing.

## Komendy operacyjne

```bash
# Dispatch do Claude
bestai swarm --task "Refactor auth gate" --vendor claude

# Dispatch do Gemini
bestai swarm --task "Przeskanuj legacy pod API debt" --vendor gemini

# Auto-routing (bez podawania vendor)
bestai route --task "Audit auth module and propose fixes"
bestai swarm --task "Audit auth module and propose fixes"

# Walidacja handoff contract
bestai validate-context .bestai/handoff-latest.json

# Live cockpit
bestai cockpit .

# Walidacja po rundzie
bestai test
bestai lint
bestai compliance .
```
