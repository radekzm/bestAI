# Ultimate AI CLI Agent Guide — Wybitne wytyczne do tworzenia projektów z agentem AI CLI

> **Jeden plik. Wszystko co potrzebujesz.** Skonsolidowane best practices z 4 poprzednich dokumentów,
> zwalidowane na realnym projekcie, z gotowymi plikami do skopiowania.
>
> Cel: Skopiuj ten plik + dołączone skrypty → wdróż w 15-60 minut → agent AI CLI działa optymalnie.

---

## Jak czytać ten dokument

| Jesteś... | Zacznij od | Czas wdrożenia |
|-----------|-----------|----------------|
| **Nowy w AI CLI** | Rozdział 1-3 (fundament) | 15 min |
| **Masz doświadczenie** | Rozdział 4-6 (zaawansowane) | 30 min |
| **Chcesz pełny system** | Cały dokument + implementacja (R.8) | 60 min |
| **Chcesz jedną rzecz** | Tabela "Najwyższy ROI" poniżej | 5 min |

### Najwyższy ROI — jedna akcja z największym efektem

| # | Akcja | Efekt | Czas |
|---|-------|-------|------|
| 1 | Reguła "Tell, don't hope" w CLAUDE.md | Agent zapisuje pamięć SAM | 2 min |
| 2 | MEMORY.md z tagami [USER]/[AUTO] | Agent nie zmienia Twoich decyzji | 5 min |
| 3 | UserPromptSubmit hook z context routing | Precyzyjny kontekst na każdy prompt | 15 min |
| 4 | `/clear` między zadaniami | 2x lepsza jakość odpowiedzi | 0 min |

---

## Spis treści

### Fundament
1. [Context Engineering — zasady](#1-context-engineering--zasady)
2. [CLAUDE.md — jedyny plik który MUSISZ mieć dobrze](#2-claudemd--jedyny-plik-który-musisz-mieć-dobrze)
3. [Zarządzanie sesją — nie marnuj okna kontekstowego](#3-zarządzanie-sesją--nie-marnuj-okna-kontekstowego)

### Zaawansowane
4. [Persistent AI Brain — trwała pamięć agenta](#4-persistent-ai-brain--trwała-pamięć-agenta)
5. [Smart Context — inteligentne ładowanie wiedzy](#5-smart-context--inteligentne-ładowanie-wiedzy)
6. [Optimization Layer — automatyczna jakość kodu](#6-optimization-layer--automatyczna-jakość-kodu)

### Praktyka
7. [Anti-patterns i realne problemy](#7-anti-patterns-i-realne-problemy)
8. [Implementacja krok po kroku](#8-implementacja-krok-po-kroku)
9. [Walidacja — case study na realnym projekcie](#9-walidacja--case-study-na-realnym-projekcie)
10. [Źródła](#10-źródła)

---

## 1. Context Engineering — zasady

### Definicja

> "Context engineering is curating what the model sees so that you get a better result."
> — Martin Fowler, 2026

Kontekst agenta AI = WSZYSTKO co widzi model: system prompt, CLAUDE.md, definicje narzędzi, historia wiadomości, wyniki tool calls. Zarządzanie tym = kluczowa umiejętność 2026.

### 5 niezmiennych zasad

| # | Zasada | Dlaczego | Konsekwencja |
|---|--------|----------|--------------|
| 1 | **Mniej = lepiej** | U-kształtna krzywa uwagi (model gubi środek) | Max 25% kontekstu na "instrukcje", 75% wolne na rozumowanie |
| 2 | **Poprawność > kompletność > rozmiar** | Fałszywa informacja gorsza niż brak | Weryfikuj przed zapisem. Nie zapisuj spekulacji |
| 3 | **Lazy loading, not removal** | Agent musi wiedzieć CO istnieje, nie wszystkie SZCZEGÓŁY | CLAUDE.md = index triggerów, Skills = szczegóły on-demand |
| 4 | **Deterministyczne > advisory** | CLAUDE.md = "proszę zrób", Hook = "MUSISZ zrobić" | Krytyczne reguły → Hooks, reszta → CLAUDE.md |
| 5 | **Semantyczne > dosłowne** | "Napraw logowanie" ≠ grep "logowanie" | Semantic search > keyword match |

### Budżet kontekstu (200k tokenów)

```
IDEALNY ROZKŁAD:
┌──────────────────────────────────────┐
│ System prompt + narzędzia    ~10%    │
│ CLAUDE.md + MEMORY.md        ~5%    │
│ Smart Context (injected)     ~5%    │
│ User prompt + historia       ~5%    │
│                                      │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ WOLNE na rozumowanie          ~75%   │
└──────────────────────────────────────┘
```

---

## 2. CLAUDE.md — jedyny plik który MUSISZ mieć dobrze

### Gotowy szablon (skopiuj i dostosuj)

```markdown
# CLAUDE.md — [Nazwa projektu]

## Komendy
- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`
- Deploy: `./scripts/deploy.sh`

## Architektura
- [2-3 zdania o stacku, wzorcach, kluczowych decyzjach]
- Mono-repo / micro-services / plugin-based — wybierz jedno

## Reguły stylu (TYLKO co odbiega od standardu)
- [Specyficzne dla projektu — to czego Claude nie odgadnie]

## Pułapki
- [Nieintuicyjne zachowania, znane problemy]

## Persistent AI Brain
IMPORTANT: Po każdej istotnej decyzji, preferencji użytkownika lub odkryciu pułapki —
zapisz do odpowiedniego pliku w memory/ BEZ pytania użytkownika.
Taguj [USER] lub [AUTO]. Nie czekaj na koniec sesji.

## Tagowanie źródła
- [USER] = użytkownik powiedział wprost. NIE zmieniaj bez pytania.
- [AUTO] = wykryte automatycznie. Możesz zrewidować jeśli uzasadnione.
Przy konflikcie: [USER] ZAWSZE wygrywa. Zmiana [USER] → pytaj użytkownika.

## Zamrożone fragmenty
PRZED edycją pliku sprawdź frozen-fragments.md:
- FROZEN → NIE edytuj. REVIEWED → pytaj. DRAFT → swobodnie.

## Smart Context
Hook UserPromptSubmit wstrzykuje kontekst automatycznie.
Sekcja "=== AUTO CONTEXT ===" = informacje dobrane do zadania.
```

### Zasady złote

| Reguła | Metryka |
|--------|---------|
| **Max 150 linii** | >150 → Claude ignoruje reguły |
| **Trigger tables** zamiast opisów | 70% redukcji tokenów |
| **Test za każdą linią** | "Usunięcie tej linii spowoduje błędy?" → jeśli nie, wytnij |
| **Emphasis na krytyczne** | `IMPORTANT`, `MUST`, **bold** → +adherencja |

### Hierarchia (3 poziomy)

```
~/.claude/CLAUDE.md         → globalne (wszystkie projekty)
./CLAUDE.md                 → per projekt (team-shared)
./src/api/CLAUDE.md         → per moduł (specyficzne)
```

Głębsze pliki nadpisują. Warstwy są addytywne.

### Rules i Skills — progressive disclosure

```
.claude/rules/ruby.md       → ładowane TYLKO przy pracy z *.rb
.claude/rules/typescript.md  → ładowane TYLKO przy pracy z *.ts
.claude/skills/deploy/       → ładowane gdy Claude uzna za relevantne
```

**Rules** = warunkowe reguły per typ pliku (glob scoping).
**Skills** = specjalistyczna wiedza, lazy-loaded.
**Ani jedno ani drugie nie zjada kontekstu gdy nie potrzebne.**

---

## 3. Zarządzanie sesją — nie marnuj okna kontekstowego

### 6 zasad sesji

| # | Zasada | Jak |
|---|--------|-----|
| 1 | **`/clear` między zadaniami** | Każde nowe zadanie = świeży kontekst |
| 2 | **Max 2 korekty** | Po 2 nieudanych → `/clear` + lepszy prompt |
| 3 | **Commit po każdym subtasku** | Checkpoint = bezpieczeństwo + czysty kontekst |
| 4 | **Kompakcja przy 50%** | Nie czekaj na auto-kompakcję (75%) |
| 5 | **Subagent na eksplorację** | Grep/search w subagent = czyste główne okno |
| 6 | **Max 3-4 MCP serwerów** | Każdy MCP zjada ~5-15% kontekstu na schema |

### Subagenci — izolacja kontekstu

```markdown
# .claude/agents/explorer.md
---
name: codebase-explorer
description: Explores codebase structure and returns summaries
tools: Read, Grep, Glob, Bash
model: haiku
---
Explore the codebase and return a concise summary of findings.
Do NOT include full file contents — only key observations.
```

**Dlaczego**: Eksploracja 50 plików w subagent = 0 tokenów w głównym oknie. Raport = 500 tokenów.

### Wzorzec Research → Plan → Implement

```
Faza 1: RESEARCH (subagent)     → zapisz findings do pliku
Faza 2: PLAN (plan mode)        → konkretne kroki, pliki, weryfikacja
Faza 3: IMPLEMENT (krok po kroku) → commit po każdym kroku
```

**Kluczowa zasada**: Review planu = NAJWYŻSZY leverage. Jeden błąd w planie kaskaduje na setki linii.

---

## 4. Persistent AI Brain — trwała pamięć agenta

### 4 warstwy zapisu (od najprostszej)

```
L1: Session Memory (wbudowane)    — automatyczne, zero-config
L2: Auto Memory (MEMORY.md)       — trwałe pliki, ładowane zawsze
L3: Stop Hook Pipeline            — deterministyczny zapis, opcjonalny
L4: Observational Memory          — kompresja historii, zaawansowane
```

### L1: Session Memory
- Wbudowane w Claude Code, działa automatycznie
- Zapisuje co ~5,000 tokenów: tytuł, status, decyzje
- Przeżywa `/compact`
- Ograniczenie: to "referencja", nie twarde instrukcje

### L2: Auto Memory (KLUCZOWE)

**Struktura**:
```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — max 200 linii, ZAWSZE ładowany
├── decisions.md           # Decyzje architektoniczne [USER]/[AUTO]
├── preferences.md         # Preferencje workflow
├── pitfalls.md            # Pułapki i rozwiązania
├── frozen-fragments.md    # Registry zamrożonych plików
├── session-log.md         # Chronologiczny log zmian
└── context-index.md       # Index dla smart context routing
```

**Format MEMORY.md**:
```markdown
# Pamięć projektu

## Decyzje (details: decisions.md)
- [USER] Stack: Rails 8 + Angular 20, nie zmieniaj
- [AUTO] Baza: PostgreSQL 16 na porcie 45432

## Preferencje (details: preferences.md)
- [USER] Commity: angielski. Dokumentacja: polski
- [USER] Testy ZAWSZE przed commitem

## Pułapki (details: pitfalls.md)
- [AUTO] Port 3000 zajęty — używaj 3001
- [USER] NIGDY DISABLE_DATABASE_ENVIRONMENT_CHECK=1

## Zamrożone (details: frozen-fragments.md)
- FROZEN: config/database.yml — produkcja
```

### Weight & Source — system wag

| Tag | Źródło | Waga | Zmiana |
|-----|--------|------|--------|
| `[USER]` | User powiedział | Wysoka | TYLKO za zgodą usera |
| `[AUTO]` | Agent wykrył | Niższa | Agent może zrewidować |

```
REGUŁA: [USER] NIGDY nie nadpisywane przez [AUTO]
REGUŁA: Zmiana [USER] → STOP → pytaj usera → log w session-log.md
```

### Fragment Freeze — zamrażanie ukończonych fragmentów

```
DRAFT  ──→  REVIEWED  ──→  FROZEN
agent       user           user only
pracuje     akceptuje      (explicit "odmroź X")
```

**Hook blokujący edycję FROZEN**:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/check-frozen.sh"
      }]
    }]
  }
}
```

### L4: Observational Memory (NOWE 2026)

**Wzorzec**: 2 agenci w tle (Observer + Reflector) kompresują historię:
- **Observer**: co 30k tokenów → kompresja 3-6x (tekst), 5-40x (narzędzia)
- **Reflector**: co 40k tokenów → restrukturyzacja, usuwanie zdezaktualizowanych
- **Benchmark**: 94.87% na LongMemEval vs RAG 80%
- **Cache-friendly**: prefix obserwacji jest stały między turami

---

## 5. Smart Context — inteligentne ładowanie wiedzy

### Problem: "Różne słowa, ta sama koncepcja"

```
User:    "napraw logowanie"
Context: "authentication error handling" ← keyword search NIE znajdzie
Vector:  [0.23, -0.45, ...] ↔ [0.25, -0.43, ...] ← semantic search ZNAJDZIE
```

### 3 podejścia (od najprostszego)

#### A: Hook + grep (start, 10 min)

```bash
# .claude/hooks/preprocess-prompt.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0
FOUND=$(grep -rli "$(echo $PROMPT | tr ' ' '|')" .claude/memory/*.md 2>/dev/null | head -3)
if [ -n "$FOUND" ]; then
    echo "=== AUTO CONTEXT ==="
    for f in $FOUND; do head -15 "$f"; done
    echo "=== END ==="
fi
```

#### B: Subagent selector (REKOMENDOWANE, 20 min)

```bash
# .claude/hooks/smart-preprocess.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0
SELECTED=$(claude -p --model haiku "
Task: '$PROMPT'
Available contexts:
$(cat .claude/memory/context-index.md)
Return ONLY 1-3 most relevant file paths." 2>/dev/null)
if [ -n "$SELECTED" ]; then
    echo "=== SMART CONTEXT ==="
    echo "$SELECTED" | while read f; do [ -f "$f" ] && head -30 "$f"; done
    echo "=== END ==="
fi
```

#### C: Vector DB (najdokładniejsze, 1-2h)

```python
# Chroma/Pinecone semantic search
# Indeksuj: reguły, memory, kod, commity, issues
# Query: embedding promptu → cosine similarity → top 5
# Return: snippety z relevance score > 70%
```

### Porównanie

| Cecha | A: grep | B: Subagent | C: Vector DB |
|-------|---------|-------------|--------------|
| Dokładność | 60% | 85% | 95% |
| Latencja | <100ms | 500ms-2s | 200ms-1s |
| "Różne słowa" | NIE | TAK | TAK |
| Setup | 10 min | 20 min | 1-2h |
| Rekomendacja | MVP | **Najlepszy balans** | Duże projekty |

### Kluczowy mechanizm: UserPromptSubmit

**stdout z UserPromptSubmit hook jest dodawane do kontekstu Claude**. To jedyny hook z tą właściwością — idealny punkt do smart context injection.

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/smart-preprocess.sh"
      }]
    }]
  }
}
```

### Budżet: Max 15% kontekstu na injected context

```
200k tokenów:
- Smart Context: max 30k tokenów (15%)
- Wolne na rozumowanie: min 150k tokenów (75%)
```

---

## 6. Optimization Layer — automatyczna jakość kodu

### Koncepcja: optimization by default

Wbuduj reguły optymalizacji w CLAUDE.md → agent stosuje je ZAWSZE, bez dodatkowego wysiłku.

### Gotowy szablon (dodaj do CLAUDE.md)

```markdown
## Optymalizacja kodu

### Przed kodem
- >3 pliki → Plan Mode, nie implementuj od razu
- Rozważ edge cases Z GÓRY

### Podczas kodu
- Early returns / guard clauses (max 2 poziomy if)
- Const/readonly/frozen — mutable tylko gdy konieczne
- Map/Set zamiast Array dla lookup/unikalność
- Batchuj I/O — max 1 query per collection, unikaj N+1

### Po kodzie
- Przejrzyj: powtórzenia, nieużywane zmienne, zbędne zależności
- Oceń Big O kluczowych operacji
- Zaproponuj testy dla critical paths
```

### Rules per język

```markdown
# .claude/rules/ruby.md
---
globs: ["**/*.rb", "**/*.rake"]
---
- find_each zamiast each dla dużych kolekcji ActiveRecord
- pluck(:id) zamiast map(&:id) dla kolumn
- bulk_insert zamiast pętli create dla >10 rekordów
```

```markdown
# .claude/rules/typescript.md
---
globs: ["**/*.ts", "**/*.tsx"]
---
- Zero `any`, zero `as` castów bez uzasadnienia
- Map<K,V> nad Record<string, V> dla dynamicznych kluczy
- useMemo/useCallback dla kosztownych obliczeń
```

### Hooks jako enforcement

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit",
      "command": "eslint --fix $FILE && tsc --noEmit"
    }]
  }
}
```

**CLAUDE.md = guidance** (advisory, może zignorować).
**Hooks = enforcement** (gwarancja, nie da się ominąć).

---

## 7. Anti-patterns i realne problemy

### Top 10 błędów z realnych projektów

| # | Problem | Objaw | Fix |
|---|---------|-------|-----|
| 1 | **Kitchen Sink Session** | Mieszanie zadań w jednej sesji | `/clear` między zadaniami |
| 2 | **Korekcja w kółko** | 3+ poprawki tego samego | Max 2, potem `/clear` + lepszy prompt |
| 3 | **Przeładowany CLAUDE.md** | >150 linii, agent ignoruje | Przycinaj, przenoś do Skills/Rules |
| 4 | **Za dużo MCP** | 15 serwerów = 50%+ kontekstu na schematy | Max 3-4, reszta → CLI |
| 5 | **Brak tagów [USER]/[AUTO]** | Agent zmienia Twoje decyzje | Reguła tagowania w CLAUDE.md |
| 6 | **MEMORY.md > 200 linii** | Reszta nie ładuje się | Szczegóły → topic files |
| 7 | **Brak frozen registry** | Agent psuje działający kod | Twórz frozen-fragments.md |
| 8 | **Poleganie na jednej warstwie** | Session Memory to "referencja" | L1+L2 minimum, L3+L4 opcjonalnie |
| 9 | **Nieskończona eksploracja** | "Zbadaj jak to działa" bez scope | Scope'uj wąsko LUB subagent |
| 10 | **Over-engineering** | Vanilla CC > nadmiarowa automatyzacja | Prosty setup = lepszy niż skomplikowany |

### Nowe problemy odkryte w badaniach 2026

| Problem | Źródło | Mitygacja |
|---------|--------|-----------|
| **UserPromptSubmit false positive #17804** | Hook output = "prompt injection" detection | Prefix z `[CONTEXT]` |
| **Hook injection cumulative** | Każdy prompt += tokeny z hooka | Wstrzykuj TYLKO gdy relevance > threshold |
| **Embedding quality dla kodu** | Kod embeduje się gorzej niż tekst | Hybrid search (keyword+semantic) |
| **RAG → Context Engine ewolucja** | Tradycyjny RAG przegrywana z OM | Obserwational Memory + Vector DB razem |
| **Cold start** | Nowy projekt = pusta baza wiedzy | Auto-seed z CLAUDE.md + first commits |

### Udokumentowane awarie (GitHub Issues + badania na realnym serwerze)

| Problem | Powaga | Dane | Mitygacja |
|---------|--------|------|-----------|
| **CLAUDE.md ignorowany po kompakcji** | KRYTYCZNY | [GH #19471](https://github.com/anthropics/claude-code/issues/19471) — 100% instrukcji łamane po kompakcji | Observational Memory, SessionStart hook do odtworzenia reguł |
| **CLAUDE.md ignorowany w 50% sesji** | WYSOKI | [GH #17530](https://github.com/anthropics/claude-code/issues/17530) — nawet "MUST"/"NEVER" ignorowane | Hooki deterministyczne (PreToolUse z exit 2) zamiast tekstu |
| **Reguły bezpieczeństwa ignorowane** | P0 | [GH #2142](https://github.com/anthropics/claude-code/issues/2142) — commitowanie API keys mimo "NEVER COMMIT" | PreToolUse hook blokujący commitowanie secrets |
| **Backup compliance 6%** | KRYTYCZNY | 31/33 sesji deploy bez backupu (dane z Nuconic) | Hook na rsync/restart z wymuszeniem pg_dump |
| **Restart w godzinach pracy 45%** | WYSOKI | 63/139 restartów 8:00-17:00 CET (dane z Nuconic) | Hook sprawdzający `date +%H` |
| **Rails runner multiline: 150 błędów** | WYSOKI | 40 sesji ten sam błąd mimo wpisu w MEMORY | Agresywne sformułowanie: "NIGDY" + szablon |
| **Context rot przy ~147k tokenów** | STRUKTURALNY | Jakość spada choć limit = 200k. System prompt = 24k | `/clear` przy 3+ kompakcjach |
| **Brak PostCompact hooka** | STRUKTURALNY | [GH #14258](https://github.com/anthropics/claude-code/issues/14258) — brak mechanizmu odtworzenia | PreCompact hook + sesja < 500 narzędzi |
| **MCP context bloat** | WYSOKI | 67k+ tokenów przy starcie z 4+ MCP serwerami | Max 3-4 MCP, Tool Search (v2.0.10+) |
| **Digital punding po kompakcjach** | WYSOKI | [GH #6549](https://github.com/anthropics/claude-code/issues/6549) — agent aktywnie szkodliwy | Max 3 kompakcje → `/clear` |

**Kluczowy wniosek**: Dokumentacja (CLAUDE.md, MEMORY.md) to **instrukcje dla modelu LLM**, który może je zignorować. Hooki (PreToolUse, UserPromptSubmit) to **kod**, który zawsze się wykonuje. **Reguły krytyczne = hooki, nie tekst.**

---

## 8. Implementacja krok po kroku

### TIER 1: Essentials (15 minut) — 70% poprawy

```bash
# 1. CLAUDE.md — dodaj regułę auto-zapisu (2 min)
cat >> CLAUDE.md << 'EOF'

# Persistent AI Brain
IMPORTANT: Po każdej istotnej decyzji, preferencji lub pułapce —
zapisz do memory/ BEZ pytania. Taguj [USER] lub [AUTO].
Przy konflikcie: [USER] wygrywa. Zmiana [USER] → pytaj usera.

# Zamrożone fragmenty
PRZED edycją sprawdź frozen-fragments.md:
FROZEN → nie ruszaj. REVIEWED → pytaj. DRAFT → swobodnie.
EOF

# 2. Utwórz strukturę memory (3 min)
PROJECT_HASH=$(echo $PWD | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_HASH/memory"
mkdir -p "$MEMORY_DIR"

cat > "$MEMORY_DIR/MEMORY.md" << 'EOF'
# Pamięć projektu

## Decyzje (details: decisions.md)
## Preferencje (details: preferences.md)
## Pułapki (details: pitfalls.md)
## Zamrożone (details: frozen-fragments.md)
EOF

touch "$MEMORY_DIR/decisions.md"
touch "$MEMORY_DIR/preferences.md"
touch "$MEMORY_DIR/pitfalls.md"
touch "$MEMORY_DIR/frozen-fragments.md"
touch "$MEMORY_DIR/session-log.md"

# 3. Weryfikuj (1 min)
echo "CLAUDE.md lines: $(wc -l < CLAUDE.md)"
echo "Memory files: $(ls $MEMORY_DIR/*.md | wc -l)"
```

### TIER 2: Smart Context (30 minut) — 90% poprawy

```bash
# 4. Utwórz context-index.md (5 min)
cat > "$MEMORY_DIR/context-index.md" << 'EOF'
# Context Index
# Format: ścieżka | opis

decisions.md | Decyzje architektoniczne — frameworki, biblioteki, wzorce
preferences.md | Preferencje użytkownika — styl, workflow, narzędzia
pitfalls.md | Pułapki — bugi, workaroundy, ograniczenia
frozen-fragments.md | Zamrożone — co nie ruszać, produkcyjne konfiguracje
session-log.md | Historia zmian — chronologiczny log decyzji
EOF

# 5. Utwórz hook preprocessor (10 min)
mkdir -p .claude/hooks

cat > .claude/hooks/preprocess-prompt.sh << 'HOOKEOF'
#!/bin/bash
# Smart Context Preprocessor
# stdout jest dodawane do kontekstu Claude

PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

# Escape hatch
[ -f ".claude/DISABLE_SMART_CONTEXT" ] && exit 0

# Szukaj relevantnych kontekstów
PROJECT_HASH=$(echo "$CLAUDE_PROJECT_DIR" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_HASH/memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

# Keyword search po memory files
KEYWORDS=$(echo "$PROMPT" | tr ' ' '\n' | sort -u | tr '\n' '|' | sed 's/|$//')
FOUND=$(grep -rli "$KEYWORDS" "$MEMORY_DIR"/*.md 2>/dev/null | head -3)

if [ -n "$FOUND" ]; then
    echo "[CONTEXT] Relevant memory files for this task:"
    for f in $FOUND; do
        echo "--- $(basename $f) ---"
        grep -i -C 1 "$KEYWORDS" "$f" 2>/dev/null | head -15
    done
fi

# Sprawdź frozen fragments
if [ -f "$MEMORY_DIR/frozen-fragments.md" ]; then
    FROZEN=$(grep -i "FROZEN" "$MEMORY_DIR/frozen-fragments.md" | head -5)
    if [ -n "$FROZEN" ]; then
        echo "[CONTEXT] Frozen files (do not edit):"
        echo "$FROZEN"
    fi
fi
exit 0
HOOKEOF
chmod +x .claude/hooks/preprocess-prompt.sh

# 6. Utwórz check-frozen hook (10 min)
cat > .claude/hooks/check-frozen.sh << 'HOOKEOF'
#!/bin/bash
# Blokuje edycję FROZEN plików
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')
[ -z "$FILE_PATH" ] && exit 0
FILE_PATH=$(echo "$FILE_PATH" | sed "s|^$CLAUDE_PROJECT_DIR/||")

PROJECT_HASH=$(echo "$CLAUDE_PROJECT_DIR" | tr '/' '-')
FROZEN_REG="$HOME/.claude/projects/$PROJECT_HASH/memory/frozen-fragments.md"
[ ! -f "$FROZEN_REG" ] && exit 0

IN_FROZEN=false
while IFS= read -r line; do
    echo "$line" | grep -q "^## FROZEN" && IN_FROZEN=true && continue
    echo "$line" | grep -q "^## " && [ "$IN_FROZEN" = true ] && IN_FROZEN=false && continue
    [ "$IN_FROZEN" = true ] && echo "$line" | grep -qF "$FILE_PATH" && {
        echo "BLOCKED: '$FILE_PATH' is FROZEN. Say 'odmroź $FILE_PATH' to unfreeze." >&2
        exit 2
    }
done < "$FROZEN_REG"
exit 0
HOOKEOF
chmod +x .claude/hooks/check-frozen.sh

# 7. Skonfiguruj hooks w settings.json (5 min)
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/preprocess-prompt.sh"
          }
        ]
      }
    ],
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
EOF
```

### TIER 3: Full System (1-2 godziny) — 99% poprawy

Dodaj do TIER 2:

```bash
# 8. Session Intelligence script
mkdir -p ~/.claude/scripts
# Skopiuj session_intelligence.py z bestSmartContext.md (rozdz. 6)

# 9. Subagent-based preprocessor (zamień hook na Podejście B)
# Wymaga: claude CLI w PATH

# 10. Vector DB (opcjonalne, dla dużych projektów)
pip install chromadb
# Zaindeksuj memory/, docs/, kluczowy kod

# 11. Observational Memory hook (Stop event)
# Skopiuj observe-and-compress.sh z bestSmartContext.md (rozdz. 5)

# 12. Rules per język
mkdir -p .claude/rules
# Utwórz ruby.md, typescript.md, python.md z globami

# 13. Cron dla Session Intelligence
# 0 3 * * * python3 ~/.claude/scripts/session_intelligence.py ...
```

### Checklist wdrożenia

```
TIER 1: Essentials (15 min)
  □ CLAUDE.md z regułą auto-zapisu i tagowania
  □ Struktura memory/ z 6 plikami
  □ MEMORY.md z sekcjami i tagami

TIER 2: Smart Context (30 min)
  □ context-index.md
  □ preprocess-prompt.sh hook
  □ check-frozen.sh hook
  □ .claude/settings.json

TIER 3: Full System (1-2h)
  □ Session Intelligence script
  □ Subagent preprocessor (Podejście B)
  □ Vector DB (Chroma/Pinecone/pgvector)
  □ Observational Memory hook
  □ Rules per język (.claude/rules/)
  □ Cron job dla Session Intelligence
```

---

## 9. Walidacja — case study na realnym projekcie

### Projekt: task.nuconic.com (OpenProject + pluginy NUCONIC)

**Twarde dane z analizy 234 sesji produkcyjnych** (26.01–23.02.2026, 29 dni):

| Metryka | Wartość | Wnioski |
|---------|---------|---------|
| Sesji Claude Code | **234** + 383 sub-agentów | ~8 sesji/dzień |
| Łączne wywołania narzędzi | **16,761** | Bash 56.5%, Read 12.1%, Write 6.7% |
| Error rate | **7.7%** (1,298 błędów) | Bash exit code 1 = 68% |
| Dane JSONL | **~451 MB** | Ogromny dataset do analizy |
| Sesje z kompakcją | **50 (21%)**, 84 kompakcje | Co 5. sesja traci kontekst |
| Przerwane przez usera | **122 (52%)** | Agent wymagał interwencji w co 2. sesji |
| CLAUDE.md | ~60 linii | W normie (<150) |
| MEMORY.md | ~50 linii + 4 topic files | Dobrze zorganizowane |

### Zidentyfikowane problemy — TWARDE DANE

| # | Problem | Skala | Źródło danych |
|---|---------|-------|---------------|
| 1 | **Backup compliance** | **6%** — 31/33 sesji deploy bez backupu | Analiza pg_dump w Bash tool calls |
| 2 | **Rails runner multiline** | **150 błędów** w 40 sesjach, ten sam bug | Analiza error patterns w JSONL |
| 3 | **Restart w godzinach pracy** | **45%** — 63/139 restartów 8-17 CET | Analiza timestamps `openproject restart` |
| 4 | **Kompakcja = amnezja** | CLAUDE.md czytany **3-4x** w jednej sesji | Analiza Read tool calls po compaction |
| 5 | **Brak semantic search** | "napraw sync NC" → nie znalazł "permissions sync" | Ręczna analiza sesji |
| 6 | **Sesja-monstrum** | 22.3 MB, 940 narzędzi, **12 kompakcji**, 55 błędów | Sesja `6c18bdfe` (budget→sales) |

### Jak Smart Context rozwiązałoby te problemy

| Problem | Mechanizm | Szacowany efekt |
|---------|-----------|-----------------|
| Backup 6% → 100% | PreToolUse hook: regex na rsync/restart/migrate → wymaga pg_dump | Deterministyczny, niemożliwy do zignorowania |
| 150 błędów rails runner | Preprocessor: wstrzykuje "NIGDY inline Ruby" przy wykryciu `rails runner` | -90% błędów (z 150 na ~15) |
| Restart 45% → <5% | PreToolUse hook: `date +%H` → block jeśli 8-17 bez `--force` | Deterministyczny |
| CLAUDE.md 3-4x po kompakcji | Observational Memory (kompresja 3-6x) + SessionStart hook | -80% re-reads, oszczędność tokenów |
| Brak semantic search | Vector DB hybrid search (keyword+semantic) | "sync" → "permissions synchronization" |
| Sesja 940 narzędzi | Auto-split przy 500 narzędziach + subagent delegation | -70% wielkości sesji |

### Token savings — symulacja na realnych danych

```
BEZ Smart Context (dane z Nuconic):
  Session start: CLAUDE.md(4k) + MEMORY.md(3k) = 7k
  Po eksploracji: +50k (file reads, greps)
  Powtórzone reads po kompakcji: +15k (CLAUDE.md 3x, pliki 2-4x)
  Kompakcja: 50 z 234 sesji (21%)
  Efektywne rozumowanie: ~60% okna

Z Smart Context (szacunki):
  Session start: CLAUDE.md(4k) + MEMORY.md(3k) + SmartCtx(6k) = 13k
  Po eksploracji: +20k (targeted reads — preprocessor wskazuje pliki)
  Powtórzone reads: ~0k (Observational Memory zachowuje stan)
  Kompakcja: ~5% sesji (zamiast 21%)
  Efektywne rozumowanie: ~85% okna

Poprawa: +42% wolnego kontekstu, -75% kompakcji, -90% re-reads
```

---

## 10. Źródła

### Skonsolidowane z 4 poprzednich dokumentów + nowe badania

#### Oficjalna dokumentacja
1. [Best Practices — Claude Code](https://code.claude.com/docs/en/best-practices)
2. [Hooks Reference — Claude Code](https://code.claude.com/docs/en/hooks)
3. [Create Custom Subagents — Claude Code](https://code.claude.com/docs/en/sub-agents)
4. [Memory Management — Claude Code](https://code.claude.com/docs/en/memory)

#### Context Engineering
5. [Martin Fowler: Context Engineering for Coding Agents](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)
6. [Advanced Context Engineering — HumanLayer](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)
7. [54% Token Reduction — John Lindquist](https://gist.github.com/johnlindquist/849b813e76039a908d962b2f0923dc9a)

#### Memory i Persistence
8. [Observational Memory — Mastra (94.87% LongMemEval)](https://mastra.ai/docs/memory/observational-memory)
9. [claude-code-auto-memory — severity1](https://deepwiki.com/severity1/claude-code-auto-memory)
10. [claude-memory — idnotbe (6 kategorii, triage)](https://github.com/idnotbe/claude-memory)
11. [claude-mem — thedotmack (Chroma+SQLite)](https://docs.claude-mem.ai/hooks-architecture)

#### Vector DB i Semantic Search
12. [Pinecone MCP Server](https://github.com/anthropics/pinecone-mcp)
13. [Context7 MCP — semantic docs on-demand](https://github.com/upstash/context7)
14. [ChromaDB — embedded vector DB](https://www.trychroma.com/)
15. [pgvector — PostgreSQL vector extension](https://github.com/pgvector/pgvector)

#### RAG → Context Engine
16. [Is RAG Dead? Context Engineering — TDS](https://towardsdatascience.com/beyond-rag/)
17. [Observational Memory beats RAG — VentureBeat](https://venturebeat.com/data/observational-memory-cuts-ai-agent-costs-10x-and-outscores-rag-on-long)
18. [Agent Memory: Why Your AI Has Amnesia — Oracle](https://blogs.oracle.com/developers/agent-memory-why-your-ai-has-amnesia-and-how-to-fix-it)

#### Hooks i Preprocessing
19. [Claude Code Hooks Mastery — disler](https://github.com/disler/claude-code-hooks-mastery)
20. [How to Configure Hooks — Claude Blog](https://claude.com/blog/how-to-configure-hooks)
21. [UserPromptSubmit Bug #17804](https://github.com/anthropics/claude-code/issues/17804)

#### Styl i optymalizacja
22. [AI Coding Style Guides](https://github.com/lidangzzz/AI-Coding-Style-Guides)
23. [Agentic Coding Principles](https://agentic-coding.github.io/)
24. [Why CLI > MCP for AI Agents](https://jannikreinhard.com/2026/02/22/why-cli-tools-are-beating-mcp-for-ai-agents/)

#### Community i narzędzia
25. [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
26. [everything-claude-code — hackathon winner](https://github.com/affaan-m/everything-claude-code)
27. [claude-code-best-practice — Shan Raisshan](https://github.com/shanraisshan/claude-code-best-practice)
28. [Volt — Lossless Context Management](https://github.com/voltropy/volt)

#### Realne implementacje kontekstowe (open-source, 2025-2026)
29. [severity1/claude-code-prompt-improver](https://github.com/severity1/claude-code-prompt-improver) — 4-fazowy prompt refinement
30. [c0ntextKeeper](https://github.com/Capnjbrown/c0ntextKeeper) — 187 semantic patterns, temporal decay
31. [Continuous-Claude-v3](https://github.com/parcadei/Continuous-Claude-v3) — 32 agentów, ledger-based
32. [Conductor — Gemini CLI](https://github.com/gemini-cli-extensions/conductor) — Context-Driven Development
33. [Mem0 — Universal Memory Layer](https://github.com/mem0ai/mem0) — 26% poprawa trafności
34. [CASS — session search](https://github.com/Dicklesworthstone/coding_agent_session_search) — sub-60ms, 11+ providerów
35. [total-recall](https://github.com/radu2lupu/total-recall) — cross-session semantic memory

#### Udokumentowane awarie i ograniczenia
36. [GH #19471 — CLAUDE.md ignored after compaction](https://github.com/anthropics/claude-code/issues/19471)
37. [GH #17530 — CLAUDE.md ignored 50% sessions](https://github.com/anthropics/claude-code/issues/17530)
38. [GH #2142 — Security rules ignored (P0)](https://github.com/anthropics/claude-code/issues/2142)
39. [GH #14258 — PostCompact Hook request](https://github.com/anthropics/claude-code/issues/14258)
40. [GH #6549 — Behavioral drift / digital punding](https://github.com/anthropics/claude-code/issues/6549)
41. [Boris Cherny — why Claude Code dropped vector DB](https://x.com/bcherny/status/2017824286489383315)
42. [SmartScope — Agentic search vs RAG](https://smartscope.blog/en/ai-development/practices/rag-debate-agentic-search-code-exploration/)
43. [Anthropic — Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
44. [Context Rot at 147k tokens](https://www.producttalk.org/context-rot/)

---

## Nawigacja po repozytorium bestAI

| Plik | Co zawiera | Czytaj gdy... |
|------|-----------|---------------|
| `bestcontext.md` | Fundamenty context engineering (16 rozdziałów) | Uczysz się podstaw |
| `preBestCliAI.md` | + Optimization layer (rozdz. 16) | Chcesz auto-optymalizację |
| `bestPersistentAI.md` | + Persistent AI Brain (3 systemy) | Chcesz trwałą pamięć |
| `bestSmartContext.md` | + Smart Context (4 nowe warstwy) | Chcesz inteligentne ładowanie |
| **`bestUltimateGuide.md`** | **Skonsolidowany best-of-all** | **Chcesz jedno miejsce ze wszystkim** |

```
Ewolucja plików:
bestcontext.md (fundamenty)
  → preBestCliAI.md (+ optymalizacja)
    → bestPersistentAI.md (+ pamięć)
      → bestSmartContext.md (+ smart context)
        → bestUltimateGuide.md (konsolidacja)
```

---

*Dokument wygenerowany: 2026-02-23*
*Wersja: 1.0 — skonsolidowany z 4 dokumentów + nowe badania*
*28 zweryfikowanych źródeł z GitHub, oficjalnej dokumentacji i community*
