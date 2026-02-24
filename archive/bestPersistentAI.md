# Persistent AI Brain — System trwałej pamięci agenta AI CLI

> Jak sprawić, żeby agent AI CLI **nigdy nie zapominał**, rozróżniał instrukcje od auto-odkryć
> i nie psuł już działających fragmentów projektu.
>
> Rozbudowuje wytyczne z `preBestCliAI.md` o 3 nowe systemy:
> Auto-Persistence, Weight & Source, Fragment Freeze.

---

## Spis treści

1. [Problem — dlaczego agent zapomina](#1-problem--dlaczego-agent-zapomina)
2. [Auto-Persistence System — 3 warstwy zapisu](#2-auto-persistence-system--3-warstwy-zapisu)
3. [Weight & Source System — wagi i tagowanie](#3-weight--source-system--wagi-i-tagowanie)
4. [Fragment Freeze System — zamrażanie ukończonych fragmentów](#4-fragment-freeze-system--zamrażanie-ukończonych-fragmentów)
5. [Gotowa konfiguracja — pliki, hooks, reguły](#5-gotowa-konfiguracja--pliki-hooks-reguły)
6. [Rekomendacje implementacji](#6-rekomendacje-implementacji)
7. [Źródła](#7-źródła)

---

## 1. Problem — dlaczego agent zapomina

### Co się dzieje po `/new` i `/clear`

Agent AI CLI (Claude Code, Codex, Cursor) działa w ramach **okna kontekstowego** — ograniczonej ilości tekstu, którą "widzi" w danym momencie. Gdy użytkownik:

- Uruchamia `/new` (nowa sesja) → **cały kontekst rozmowy znika**
- Uruchamia `/clear` (reset kontekstu) → **historia bieżącej sesji znika**
- Kontekst się zapełnia → **auto-kompakcja** podsumowuje i kasuje szczegóły

**Efekt**: Agent "zapomina" ustalenia, preferencje, decyzje, pułapki — i powtarza te same błędy lub pyta o to samo.

### Co chcemy osiągnąć

| Problem | Cel |
|---------|-----|
| Agent zapomina ustalenia po `/new` | Automatycznie zapisuje WSZYSTKO istotne do plików trwałych |
| Agent traktuje swoje domysły jak fakty | System wag: instrukcja usera ≠ auto-odkrycie |
| Agent "poprawia" działający kod | Zamrożone fragmenty — nie dotykaj bez zgody |
| User musi mówić "zapamiętaj to" | Agent zapisuje SAM, bez proszenia |

### 3 systemy rozwiązujące te problemy

```
┌─────────────────────────────────────────────────────────┐
│                  PERSISTENT AI BRAIN                     │
├───────────────────┬──────────────────┬──────────────────┤
│  Auto-Persistence │  Weight & Source │  Fragment Freeze │
│  "nigdy nie       │  "rozróżniaj    │  "nie psuj       │
│   zapominaj"      │   czyje to"     │   działających"  │
├───────────────────┼──────────────────┼──────────────────┤
│  L1: Session Mem  │  [USER] tag     │  DRAFT state     │
│  L2: Auto Memory  │  [AUTO] tag     │  REVIEWED state  │
│  L3: Stop Hook    │  Reguły eskal.  │  FROZEN state    │
└───────────────────┴──────────────────┴──────────────────┘
```

---

## 2. Auto-Persistence System — 3 warstwy zapisu

### Filozofia: warstwowość

Zamiast polegać na jednym mechanizmie, stosujemy **3 warstwy** — jeśli jedna zawiedzie, pozostałe łapią kontekst.

### L1: Session Memory (wbudowane, zero konfiguracji)

**Co to jest**: Wbudowany system Claude Code, który automatycznie w tle zapisuje podsumowania sesji.

**Jak działa**:
- Pierwszy zapis po ~10,000 tokenów rozmowy
- Kolejne aktualizacje co ~5,000 tokenów LUB co 3 tool calls
- Zapisuje: tytuł sesji, status, kluczowe decyzje, log prac
- Przeżywa `/compact` (instant compaction korzysta z gotowych summary)

**Gdzie zapisuje**:
```
~/.claude/projects/<project-hash>/<session-id>/session-memory/summary.md
```

**Jak odzyskać**: Nowa sesja automatycznie ładuje summary z poprzednich sesji jako kontekst referencyjny.

**Konfiguracja**:
```bash
# Upewnij się że włączone (jeśli nie jest domyślne)
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=0
```

**Ograniczenia**:
- Zapisuje *intent i outcomes*, nie pełne transkrypty
- Dostępne tylko na natywnym API Anthropic (nie Bedrock/Vertex)
- Traktowane jako "materiał referencyjny", nie twarde instrukcje

### L2: Auto Memory (MEMORY.md + topic files)

**Co to jest**: Persystentny katalog, gdzie agent zapisuje wzorce, preferencje i insights.

**Jak działa**:
- `MEMORY.md` ładowane do system prompt **przy KAŻDEJ sesji** (pierwsze 200 linii)
- Topic files (`debugging.md`, `patterns.md`) czytane on-demand
- Agent zapisuje SAM gdy uzna coś za ważne, LUB gdy użytkownik powie "zapamiętaj X"

**Struktura plików**:
```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — max 200 linii, ZAWSZE ładowany
├── decisions.md           # Decyzje architektoniczne
├── preferences.md         # Preferencje workflow i styl kodu
├── pitfalls.md            # Pułapki i rozwiązania
├── frozen-fragments.md    # Registry zamrożonych fragmentów
└── session-log.md         # Chronologiczny log kluczowych ustaleń
```

**Format MEMORY.md (rekomendowany)**:
```markdown
# Pamięć projektu

## Kluczowe decyzje
- [USER] Używamy bun, nie npm — link: decisions.md#bun
- [AUTO] Projekt korzysta z ESM modules — wykryte z package.json

## Preferencje (szczegóły: preferences.md)
- [USER] Commity po angielsku, dokumentacja po polsku
- [USER] Testy przed commitem ZAWSZE

## Pułapki (szczegóły: pitfalls.md)
- [AUTO] Port 3000 zajęty przez inny serwis — używaj 3001

## Zamrożone fragmenty (szczegóły: frozen-fragments.md)
- FROZEN: src/auth/login.ts — nie ruszaj
```

**Kluczowa reguła w CLAUDE.md** (najbardziej skuteczna pojedyncza linia):
```markdown
IMPORTANT: Po każdej istotnej decyzji, preferencji użytkownika lub odkryciu pułapki —
zapisz do odpowiedniego pliku w memory/ BEZ pytania użytkownika. Taguj [USER] lub [AUTO].
```

### L3: Stop Hook Pipeline (zaawansowane)

**Co to jest**: Hook uruchamiany po każdej odpowiedzi agenta, który deterministycznie sprawdza czy warto coś zapisać.

**Kiedy warto**: Dla projektów z wieloma decyzjami architektonicznymi, dużymi teamami, lub gdy L1+L2 nie wystarczają.

**2 gotowe implementacje**:

#### Opcja A: claude-code-auto-memory (prostsza)

3-fazowy pipeline:
1. `PostToolUse` hook → śledzi zmienione pliki (dirty-files), 0 tokenów
2. `Stop` hook → sprawdza dirty-files, spawni subagenta do aktualizacji pamięci
3. Subagent aktualizuje `AUTO-MANAGED` sekcje w CLAUDE.md

**Repo**: [severity1/claude-code-auto-memory](https://deepwiki.com/severity1/claude-code-auto-memory)

#### Opcja B: claude-memory (pełna)

4-fazowy pipeline z 6 kategoriami pamięci:
1. **Triage** (deterministyczny) — keyword scoring, zero LLM cost
2. **Drafting** (równoległy) — subagenci per kategoria (haiku/sonnet)
3. **Verification** (sonnet) — jakość + deduplikacja
4. **Save** — atomic write + index update

**Kategorie**:
| Kategoria | Cel | Model |
|-----------|-----|-------|
| session_summary | Co się stało, co dalej | Haiku |
| decision | Dlaczego X a nie Y | **Sonnet** |
| runbook | Problem → fix → weryfikacja | Haiku |
| constraint | Czego nie da się zrobić i dlaczego | **Sonnet** |
| tech_debt | Co pominięto i jaki koszt | Haiku |
| preference | Jak rzeczy powinny być robione | Haiku |

**Repo**: [idnotbe/claude-memory](https://github.com/idnotbe/claude-memory)

### Rekomendacja: która warstwa kiedy

| Sytuacja | Rekomendacja |
|----------|-------------|
| Mały projekt, 1 osoba | **L1 + L2** wystarczą |
| Średni projekt, wiele decyzji | L1 + L2 + **L3 opcja A** |
| Duży projekt, team, compliance | L1 + L2 + **L3 opcja B** |
| Każdy projekt (minimum) | Reguła "Tell, don't hope" w CLAUDE.md |

### "Tell, don't hope" — najważniejsza zasada

Nie licz na to, że agent "sam się domyśli" co zapisać. Wpisz w CLAUDE.md:

```markdown
IMPORTANT: Po każdej istotnej decyzji, preferencji użytkownika lub odkryciu pułapki —
zapisz do odpowiedniego pliku w memory/ BEZ pytania użytkownika. Taguj [USER] lub [AUTO].
Nie czekaj na koniec sesji. Zapisuj NA BIEŻĄCO.
```

To zamienia auto-memory z **"może zapisze"** na **"zawsze zapisuje"**.

---

## 3. Weight & Source System — wagi i tagowanie

### Problem

Agent traktuje swoje auto-odkrycia tak samo jak wyraźne instrukcje użytkownika:
- Użytkownik mówi "zawsze używaj bun" → agent zmienia na npm bo "tak lepiej"
- Agent sam wykrył wzorzec → potem zmienia zdanie → niestabilność

### Rozwiązanie: 2 tagi, 2 wagi

| Tag | Źródło | Waga | Opis |
|-----|--------|------|------|
| `[USER]` | Użytkownik powiedział wprost | **Wysoka** | Nie zmieniaj bez pytania. Traktuj jako fakt. |
| `[AUTO]` | Agent wykrył/wywnioskował sam | **Niższa** | Możesz zrewidować jeśli znajdziesz lepsze rozwiązanie. |

### Format w plikach pamięci

```markdown
## Preferencje

- [USER] Zawsze używaj bun, nie npm
- [USER] Commity po angielsku, dokumentacja po polsku
- [USER] Testy przed commitem — bez wyjątków
- [AUTO] Projekt używa ESM modules (wykryte z package.json)
- [AUTO] Preferowany port deweloperski: 3001 (3000 zajęty)
- [AUTO] Testy uruchamiane przez `bun test` (wykryte z scripts)
```

### Reguły priorytetów

```
┌──────────────────────────────────────────────────────┐
│  REGUŁA #1: [USER] NIGDY nie nadpisywane przez [AUTO] │
│  REGUŁA #2: [AUTO] może być zaktualizowane przez agenta│
│  REGUŁA #3: Konflikt → ZAWSZE wygrywa [USER]          │
│  REGUŁA #4: Zmiana [USER] → MUSI pytać użytkownika    │
└──────────────────────────────────────────────────────┘
```

**Szczegółowo**:

1. **`[USER]` nigdy nie nadpisywane przez `[AUTO]`**
   - Jeśli user powiedział "używaj bun" — agent NIE zmienia na npm, nawet jeśli "npm byłoby lepsze"
   - Zmiana wymaga explicit zgody usera

2. **`[AUTO]` może być zaktualizowane gdy**:
   - Znaleziono lepsze rozwiązanie (zaloguj zmianę)
   - Poprzednie okazało się błędne
   - Projekt się zmienił (nowa wersja, nowe zależności)

3. **Konflikt `[USER]` vs `[AUTO]`** → zawsze `[USER]`
   - Przykład: `[USER] port 3000` vs `[AUTO] port 3001` → użyj 3000

4. **Agent chce zmienić `[USER]`** → eskalacja:
   - STOP. Zapytaj użytkownika.
   - Wyjaśnij DLACZEGO zmiana jest potrzebna.
   - Po akceptacji: zmień, oznacz `[USER-UPDATED]`, zaloguj w session-log.md

### Diagram eskalacji

```
Agent chce zmienić wpis
  │
  ├─ Tag = [AUTO]?
  │   └─ TAK → Zmień sam. Zaloguj zmianę w session-log.md
  │
  └─ Tag = [USER]?
      └─ TAK → STOP
          ├─ Zapytaj użytkownika
          ├─ Wyjaśnij dlaczego
          └─ Akceptacja?
              ├─ TAK → Zmień. Oznacz [USER-UPDATED]. Zaloguj.
              └─ NIE → Zachowaj oryginał. Zaloguj odmowę.
```

### Log zmian (session-log.md)

Każda zmiana w plikach pamięci powinna być zalogowana:

```markdown
# Session Log

## 2026-02-23, sesja "auth-refactor"
- ZMIENIONO [AUTO] decisions.md: port 3001→3002 (konflikt z nowym serwisem)
- DODANO [USER] preferences.md: "zawsze używaj TypeScript strict mode"
- PYTANIE do usera: zmiana [USER] "bun"→"pnpm" — ODRZUCONE, zostaje bun

## 2026-02-22, sesja "initial-setup"
- DODANO [AUTO] pitfalls.md: "port 3000 zajęty przez legacy serwis"
- DODANO [USER] preferences.md: "bun, nie npm"
```

### Reguła CLAUDE.md wymuszająca tagowanie

```markdown
IMPORTANT: Każdy wpis w plikach memory/ MUSI mieć tag [USER] lub [AUTO].
- [USER] = użytkownik powiedział wprost. NIE zmieniaj bez pytania.
- [AUTO] = wykryte automatycznie. Możesz zrewidować jeśli uzasadnione.
Przy konflikcie: [USER] ZAWSZE wygrywa nad [AUTO].
Przy zmianie [USER]: ZAWSZE pytaj użytkownika. NIGDY nie zmieniaj sam.
Loguj KAŻDĄ zmianę w session-log.md.
```

---

## 4. Fragment Freeze System — zamrażanie ukończonych fragmentów

### Problem

Agent "poprawia" już działający kod, konfigurację lub dokumentację:
- Zmienia formatowanie pliku, który był OK
- "Refaktoryzuje" działający moduł, wprowadzając bug
- Modyfikuje konfigurację produkcyjną "bo tak lepiej"

### Rozwiązanie: 3-stanowy lifecycle fragmentów

```
DRAFT  ────→  REVIEWED  ────→  FROZEN
  ↑               ↑                │
  │ agent         │ user           │ user only
  │ pracuje       │ akceptuje      │ (explicit unfreeze)
  │ swobodnie     │                │
  └───────────────┘                │
        ↑                          │
        └──────────────────────────┘
              user: "odmroź X"
```

### Stany i reguły

| Stan | Kto może edytować | Kiedy | Reguła |
|------|-------------------|-------|--------|
| `DRAFT` | Agent swobodnie | Praca w toku | Zmiany dozwolone bez ograniczeń |
| `REVIEWED` | Agent za zgodą usera | User potwierdził "to działa" | Drobne poprawki OK po zapytaniu. Duże zmiany = pytaj |
| `FROZEN` | **Nikt** (poza explicit unfreeze) | Stabilny, przetestowany, produkcyjny | Hook blokuje edycję. Punkt. |

### Registry zamrożonych fragmentów

Plik `frozen-fragments.md` w katalogu memory/:

```markdown
# Frozen Fragments Registry

## FROZEN
<!-- Nie edytuj tych plików. Hook PreToolUse blokuje zmiany. -->
<!-- Aby odmrozić: powiedz "odmroź <ścieżka>" -->

- `src/auth/login.ts` — auth flow [USER] "działa, nie ruszaj" (zamrożone: 2026-02-20)
- `config/database.yml` — DB config [USER] produkcja zweryfikowana (zamrożone: 2026-02-19)
- `.env.production` — env vars [USER] (zamrożone: 2026-02-18)
- `docker-compose.prod.yml` — stack produkcyjny [USER] (zamrożone: 2026-02-15)

## REVIEWED
<!-- Drobne poprawki OK po zapytaniu usera. Duże zmiany = pytaj. -->

- `src/api/users.ts` — CRUD endpoints [AUTO] testy przechodzą (reviewed: 2026-02-22)
- `src/middleware/cors.ts` — CORS config [USER] "ok" (reviewed: 2026-02-22)

## DRAFT
<!-- Agent pracuje swobodnie. -->

- `src/api/billing.ts` — w trakcie implementacji
- `src/utils/validators.ts` — nowe walidatory
```

### Hook blokujący edycję FROZEN plików

#### Konfiguracja (`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-frozen.sh"
          }
        ]
      }
    ]
  }
}
```

#### Skrypt `.claude/hooks/check-frozen.sh`:

```bash
#!/bin/bash
# Sprawdza czy edytowany plik jest FROZEN
# Exit 0 = dozwolone, Exit 2 = zablokowane

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

# Brak ścieżki = pozwól (nie blokuj nieznanych narzędzi)
[ -z "$FILE_PATH" ] && exit 0

# Normalizuj ścieżkę (usuń prefix projektu jeśli obecny)
FILE_PATH=$(echo "$FILE_PATH" | sed "s|^$CLAUDE_PROJECT_DIR/||")

FROZEN_REGISTRY="$CLAUDE_PROJECT_DIR/.claude/memory/frozen-fragments.md"

# Brak registry = pozwól
[ ! -f "$FROZEN_REGISTRY" ] && exit 0

# Sprawdź czy plik jest w sekcji FROZEN
IN_FROZEN_SECTION=false
while IFS= read -r line; do
  # Wykryj sekcje
  if echo "$line" | grep -q "^## FROZEN"; then
    IN_FROZEN_SECTION=true
    continue
  fi
  if echo "$line" | grep -q "^## " && [ "$IN_FROZEN_SECTION" = true ]; then
    IN_FROZEN_SECTION=false
    continue
  fi
  # Sprawdź czy ścieżka pliku jest w linii FROZEN
  if [ "$IN_FROZEN_SECTION" = true ] && echo "$line" | grep -qF "$FILE_PATH"; then
    echo "BLOCKED: '$FILE_PATH' is FROZEN. Ask user to unfreeze first." >&2
    echo "To unfreeze, user should say: 'odmroź $FILE_PATH'" >&2
    exit 2
  fi
done < "$FROZEN_REGISTRY"

exit 0
```

**Nie zapomnij**: `chmod +x .claude/hooks/check-frozen.sh`

### Workflow zamrażania w praktyce

#### Zamrażanie:

```
User: "zamroź src/auth/login.ts"

Agent:
1. Dodaje wpis do frozen-fragments.md sekcja ## FROZEN
2. Usuwa z ## DRAFT lub ## REVIEWED (jeśli był)
3. Loguje w session-log.md
4. Potwierdza: "Zamrożono src/auth/login.ts. Hook będzie blokował edycję."
```

#### Odmrażanie:

```
User: "odmroź src/auth/login.ts"

Agent:
1. Przenosi wpis z ## FROZEN do ## DRAFT
2. Loguje w session-log.md
3. Potwierdza: "Odmrożono src/auth/login.ts. Edycja ponownie dozwolona."
```

#### Automatyczne promowanie DRAFT → REVIEWED:

```
Agent kończy implementację + testy przechodzą:
1. Pyta usera: "src/api/users.ts jest gotowy i testy przechodzą.
   Czy mogę oznaczyć jako REVIEWED?"
2. User: "tak"
3. Agent przenosi z ## DRAFT do ## REVIEWED
```

### Reguła CLAUDE.md

```markdown
IMPORTANT: PRZED każdą edycją pliku sprawdź frozen-fragments.md:
- FROZEN → NIE edytuj. Powiedz userowi że plik jest zamrożony.
- REVIEWED → Drobne poprawki OK po zapytaniu usera. Duże zmiany = pytaj.
- DRAFT → Swobodna edycja.
Gdy kończysz fragment i testy przechodzą: zaproponuj userowi REVIEWED.
User może zamrozić/odmrozić słowami "zamroź X" / "odmroź X".
```

---

## 5. Gotowa konfiguracja — pliki, hooks, reguły

### Kompletna sekcja do dodania do CLAUDE.md

Skopiuj poniższy blok do CLAUDE.md projektu:

```markdown
# Persistent AI Brain

## Auto-zapis pamięci
IMPORTANT: Po każdej istotnej decyzji, preferencji użytkownika lub odkryciu pułapki —
zapisz do odpowiedniego pliku w memory/ BEZ pytania użytkownika.
Nie czekaj na koniec sesji. Zapisuj NA BIEŻĄCO.

## Tagowanie źródła
Każdy wpis w plikach memory/ MUSI mieć tag [USER] lub [AUTO].
- [USER] = użytkownik powiedział wprost. NIE zmieniaj bez pytania.
- [AUTO] = wykryte automatycznie. Możesz zrewidować jeśli uzasadnione.
Przy konflikcie: [USER] ZAWSZE wygrywa nad [AUTO].
Przy zmianie [USER]: ZAWSZE pytaj użytkownika. NIGDY nie zmieniaj sam.

## Zamrożone fragmenty
PRZED każdą edycją pliku sprawdź frozen-fragments.md:
- FROZEN → NIE edytuj. Powiedz userowi że plik jest zamrożony.
- REVIEWED → Drobne poprawki OK po zapytaniu usera. Duże zmiany = pytaj.
- DRAFT → Swobodna edycja.
Gdy kończysz fragment i testy przechodzą: zaproponuj userowi REVIEWED.

## Logowanie zmian
Loguj KAŻDĄ zmianę w plikach memory/ do session-log.md z datą i kontekstem.
```

### Kompletna konfiguracja hooks (`.claude/settings.json`)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-frozen.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Reminder: Check memory/MEMORY.md for project state. Check frozen-fragments.md before editing files.'"
          }
        ]
      }
    ]
  }
}
```

### Struktura katalogu memory/

Utwórz przy inicjalizacji projektu:

```bash
mkdir -p ~/.claude/projects/<project>/memory
touch ~/.claude/projects/<project>/memory/MEMORY.md
touch ~/.claude/projects/<project>/memory/decisions.md
touch ~/.claude/projects/<project>/memory/preferences.md
touch ~/.claude/projects/<project>/memory/pitfalls.md
touch ~/.claude/projects/<project>/memory/frozen-fragments.md
touch ~/.claude/projects/<project>/memory/session-log.md
```

---

## 6. Rekomendacje implementacji

### Poziomy wdrożenia

| Poziom | Co wdrażasz | Wysiłek | Efekt |
|--------|-------------|---------|-------|
| **Minimum** | Reguła "Tell, don't hope" w CLAUDE.md + tagowanie [USER]/[AUTO] | 5 min | 70% poprawy |
| **Standard** | + struktura memory/ + frozen-fragments.md + reguły CLAUDE.md | 15 min | 90% poprawy |
| **Pełny** | + check-frozen.sh hook + SessionStart re-inject + L3 plugin | 30 min | 99% poprawy |

### Najczęstsze błędy

| Błąd | Dlaczego źle | Rozwiązanie |
|------|-------------|-------------|
| MEMORY.md > 200 linii | Reszta nie ładuje się | Przenieś szczegóły do topic files |
| Brak tagów [USER]/[AUTO] | Agent zmienia instrukcje usera | Reguła tagowania w CLAUDE.md |
| Brak frozen registry | Agent psuje działające pliki | Utwórz frozen-fragments.md |
| Poleganie tylko na L1 | Session Memory to "referencja", nie instrukcje | Dodaj L2 z MEMORY.md |
| Za dużo FROZEN | Nie można nic zmienić | Zamrażaj TYLKO stabilne, przetestowane fragmenty |

### Iteracyjne wdrażanie

**Tydzień 1**: Wdróż MINIMUM — reguła w CLAUDE.md + tagowanie.
Obserwuj: czy agent zapisuje? Czy tagi są poprawne?

**Tydzień 2**: Wdróż STANDARD — memory/ structure + frozen-fragments.
Obserwuj: czy hook blokuje? Czy lifecycle działa?

**Tydzień 3**: Wdróż PEŁNY — jeśli potrzebujesz L3 plugin.
Obserwuj: czy triage trafnie rozpoznaje ważne momenty?

---

## 7. Źródła

### Oficjalna dokumentacja

1. [Manage Claude's memory — oficjalna dokumentacja](https://code.claude.com/docs/en/memory)
2. [Automate workflows with hooks — oficjalna dokumentacja](https://code.claude.com/docs/en/hooks-guide)
3. [Claude Code Session Memory](https://claudefa.st/blog/guide/mechanics/session-memory)

### Pluginy i implementacje

4. [claude-code-auto-memory — severity1](https://deepwiki.com/severity1/claude-code-auto-memory) — 3-fazowy pipeline, zero-token tracking
5. [claude-memory — idnotbe](https://github.com/idnotbe/claude-memory) — 6 kategorii, system wag haiku/sonnet, triage
6. [claude-mem — thedotmack](https://github.com/thedotmack/claude-mem) — 5 hooks, SQLite + Chroma, semantic search
7. [claude-skills-automation — Toowiredd](https://github.com/Toowiredd/claude-skills-automation) — zero-friction memory + context management
8. [claude-memory-bank — russbeye](https://github.com/russbeye/claude-memory-bank) — automatic work tracking
9. [claude-supermemory — supermemoryai](https://github.com/supermemoryai/claude-supermemory) — real-time learning across sessions
10. [memory-mcp — yuvalsuede](https://github.com/yuvalsuede/memory-mcp) — MCP-based persistent memory

### Artykuły

11. [Never Lose a Claude Code Conversation Again](https://jeradbitner.com/blog/claude-code-auto-save-conversations)
12. [Teaching Claude To Remember: Sessions And Resumable Workflow](https://medium.com/@porter.nicholas/teaching-claude-to-remember-part-3-sessions-and-resumable-workflow-1c356d9e442f)
13. [Claude Code Hooks Complete Guide (February 2026)](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/)
14. [Claude Code Hooks: 20+ Ready-to-Use Examples](https://aiorg.dev/blog/claude-code-hooks)
15. [Claude Code Hooks Mastery — disler](https://github.com/disler/claude-code-hooks-mastery)

---

*Dokument wygenerowany: 2026-02-23*
*Rozbudowuje: bestcontext.md (fundamenty) → preBestCliAI.md (optymalizacja) → **ten plik** (trwała pamięć)*
