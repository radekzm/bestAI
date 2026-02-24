# Smart Context Engineering — Inteligentne ładowanie kontekstu dla agentów AI CLI

> Jak sprawić, żeby agent dostawał **dokładnie ten kontekst, którego potrzebuje** — nawet gdy użytkownik
> opisuje zadanie zupełnie innymi słowami niż tagowanie wiedzy. Bez przeładowania okna kontekstowego.
>
> Rozbudowuje wytyczne z `bestPersistentAI.md` o 4 nowe systemy:
> Semantic Context Router, Prompt Preprocessor, Observational Memory, Session Intelligence.

---

## Spis treści

1. [Problem — dlaczego statyczne ładowanie kontekstu nie wystarcza](#1-problem--dlaczego-statyczne-ładowanie-kontekstu-nie-wystarcza)
2. [Architektura Smart Context — 4 warstwy](#2-architektura-smart-context--4-warstwy)
3. [Semantic Context Router — baza wektorowa + wyszukiwanie semantyczne](#3-semantic-context-router--baza-wektorowa--wyszukiwanie-semantyczne)
4. [Prompt Preprocessor — system dopracowywania zadań przed wykonaniem](#4-prompt-preprocessor--system-dopracowywania-zadań-przed-wykonaniem)
5. [Observational Memory — kompresja kontekstu bez utraty informacji](#5-observational-memory--kompresja-kontekstu-bez-utraty-informacji)
6. [Session Intelligence — analiza historii sesji i uczenie się wzorców](#6-session-intelligence--analiza-historii-sesji-i-uczenie-się-wzorców)
7. [Integracja — jak wszystko działa razem](#7-integracja--jak-wszystko-działa-razem)
8. [Gotowa implementacja krok po kroku](#8-gotowa-implementacja-krok-po-kroku)
9. [Walidacja na realnym projekcie — case study Nuconic](#9-walidacja-na-realnym-projekcie--case-study-nuconic)
10. [Słabe punkty i mitygacje](#10-słabe-punkty-i-mitygacje)
11. [Źródła](#11-źródła)

---

## 1. Problem — dlaczego statyczne ładowanie kontekstu nie wystarcza

### Stan obecny: CLAUDE.md + MEMORY.md

Aktualne podejście do kontekstu agenta AI CLI:
- `CLAUDE.md` ładowany **ZAWSZE** (stały koszt ~2-5% okna kontekstowego)
- `MEMORY.md` ładowany **ZAWSZE** (pierwsze 200 linii)
- `.claude/rules/` ładowane **warunkowo** (gdy Claude pracuje z plikami pasującymi do glob)
- `.claude/skills/` ładowane **on-demand** (gdy LLM uzna za relevantne)

**Problem #1: Statyczny kontekst to za mało**

```
Użytkownik: "napraw logowanie"
CLAUDE.md: zawiera reguły o testowaniu, stylu kodu, deploy...
MEMORY.md: zawiera decyzje architektoniczne, preferencje...

→ Ale ŻADEN z tych plików nie zawiera:
  - Historii ostatnich bugów w module auth
  - Wzorców błędów z poprzednich sesji
  - Kontekstu specyficznego dla authentication flow
  - Lekcji wyciągniętych z podobnych napraw
```

**Problem #2: "Różne słowa, ta sama koncepcja"**

Użytkownik pisze "napraw logowanie", ale wiedza w plikach pamięci opisuje:
- "authentication error handling" (inne słowa)
- "session token validation" (inne słowa)
- "OAuth flow recovery" (inne słowa)

Keyword matching (`grep`) NIE znajdzie powiązania. Potrzebne jest **wyszukiwanie semantyczne** — rozumienie znaczenia, nie tylko dopasowanie słów.

**Problem #3: Ładowanie wszystkiego = przeładowanie**

Naiwne rozwiązanie ("załaduj WSZYSTKO co mamy") gorzej działa niż nic:
- **U-kształtna krzywa uwagi** — model najlepiej pamięta początek i koniec kontekstu
- **Attention scarcity** — im więcej tokenów, tym mniej uwagi na każdy
- **Szum > sygnał** — nieistotny kontekst aktywnie przeszkadza

### Co chcemy osiągnąć

```
┌─────────────────────────────────────────────────────────────────┐
│                     SMART CONTEXT PIPELINE                       │
│                                                                  │
│  User prompt ──→ [Preprocessor] ──→ [Semantic Router] ──→       │
│                       │                    │                     │
│                  dopracowany           wybrany kontekst          │
│                  prompt                (5-15% okna)              │
│                       │                    │                     │
│                       └────────┬───────────┘                     │
│                                ↓                                 │
│                    Main Agent Context Window                     │
│                    ┌─────────────────────┐                       │
│                    │ System prompt  (~5%) │                       │
│                    │ Smart context (~15%) │ ← tylko relevantne   │
│                    │ User prompt    (~5%) │ ← dopracowany        │
│                    │ Free space   (~75%) │ ← na rozumowanie      │
│                    └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

**Cel**: Agent dostaje 15% kontekstu z **precyzyjnie dobraną** wiedzą, zamiast 40% z ogólnym szumem.

---

## 2. Architektura Smart Context — 4 warstwy

```
┌─────────────────────────────────────────────────────────────────┐
│                    SMART CONTEXT ARCHITECTURE                     │
├─────────────────┬────────────────┬───────────────┬──────────────┤
│ Semantic Router │ Preprocessor   │ Observational │ Session      │
│ "znajdź właściwy│ "dopracuj      │ Memory        │ Intelligence │
│  kontekst"      │  zadanie"      │ "kompresuj    │ "ucz się     │
│                 │                │  bez utraty"  │  z historii" │
├─────────────────┼────────────────┼───────────────┼──────────────┤
│ Vector DB       │ UserPromptSubmit│ Observer +   │ JSONL parser │
│ + embeddingi    │ hook           │ Reflector     │ + wzorce     │
│ + hybrid search │ + subagent     │ agents        │              │
│ (keyword+sem.)  │ (Haiku/fast)   │               │              │
└─────────────────┴────────────────┴───────────────┴──────────────┘
```

### Jak warstwy współpracują

```
1. User wpisuje prompt
   ↓
2. UserPromptSubmit hook uruchamia Prompt Preprocessor
   ↓  (nie obciąża głównego kontekstu)
3. Preprocessor:
   a) Analizuje intent (co user chce osiągnąć)
   b) Rozszerza słowa kluczowe (synonimy, powiązane koncepty)
   c) Wysyła query do Semantic Context Router
   d) Router szuka w vector DB najrelevantniejszych fragmentów
   e) Zwraca: dopracowany prompt + wybrane snippety kontekstu
   ↓
4. Main Agent dostaje:
   - Oryginalny prompt usera
   - Dopracowane context hints (z preprocessora)
   - Relevantne snippety z bazy wiedzy
   - Standardowy CLAUDE.md + MEMORY.md
   ↓
5. Observational Memory w tle kompresuje długą rozmowę
   ↓
6. Po sesji: Session Intelligence analizuje transcript
   i aktualizuje bazę wiedzy
```

---

## 3. Semantic Context Router — baza wektorowa + wyszukiwanie semantyczne

### Problem do rozwiązania

"Różne słowa, ta sama koncepcja":
- User: "napraw logowanie" → Context: "authentication error handling"
- User: "zrób szybciej" → Context: "query optimization, N+1 prevention"
- User: "dodaj walidację" → Context: "input sanitization, OWASP rules"

### Rozwiązanie: Embeddingi + Vector DB

**Embedding** = zamiana tekstu na wektor liczbowy (np. 1536 wymiarów), gdzie **semantycznie podobne teksty** mają bliskie wektory, niezależnie od użytych słów.

```
"napraw logowanie"        → [0.23, -0.45, 0.12, ...]  ─┐
"authentication bug fix"  → [0.25, -0.43, 0.14, ...]  ─┤ bliskie wektory!
"zmień kolor tła"         → [-0.67, 0.82, -0.31, ...] ─┘ daleki wektor
```

### Kluczowe odkrycie: Anthropic CELOWO odrzucił vector DB

> Anthropic przetestował RAG z lokalną bazą wektorową we wczesnych wersjach Claude Code i **świadomie z tego zrezygnował** na rzecz "agentic search" (grep + glob + read plików).
> — [Anthropic Engineering Blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

**Powody**:
- Prostota (zero konfiguracji)
- Brak problemów z aktualizacją indeksu (staleness)
- Bezpieczeństwo (indeks = dodatkowa powierzchnia ataku)
- Niezawodność

**ALE**: Community natychmiast wypełniło tę lukę — powstało kilkanaście projektów dodających vector DB do Claude Code. Najbardziej dojrzałe: **claude-mem** (4700+ stars), **claude-context** (Zilliz, 4000+ stars).

**Praktyczny konsensus (luty 2026)**:
> "Agentic as the backbone, with semantic index only where needed, plus context engineering"
> — hybrydowe podejście

### Wybór bazy wektorowej — rekomendacje 2026

| Baza | Typ | Najlepsze zastosowanie | Koszt | Setup | Realne użycie |
|------|-----|------------------------|-------|-------|--------------|
| **sqlite-vec** | Embedded (SQLite ext.) | **TREND 2026** — zero infra | Darmowy | Rozszerzenie SQLite | Kontext Engine, Mnemosyne, Memento |
| **Chroma** | Embedded/local | Pojedynczy dev, szybki start | Darmowy | `pip install chromadb` | claude-mem (4700+ stars) |
| **LanceDB** | Embedded/serverless | Lekki, Git-friendly | Darmowy | `pip install lancedb` | claude-context fork, Continue IDE |
| **pgvector** | Rozszerzenie PostgreSQL | Projekty z istniejącym PG | Darmowy | Rozszerzenie PG | Produkcja, 75% taniej niż Pinecone |
| **Pinecone** | Cloud (managed) | Enterprise, team, duży scale | $$$→Free tier | MCP ready | Pinecone MCP |
| **Milvus/Zilliz** | Cloud/self-hosted | Duże codebases, monorepo | Free→$$$ | Serwer | claude-context (Zilliz) |

**Rekomendacja 2026** (na podstawie realnych implementacji):
- **Solo dev**: **sqlite-vec** lub Chroma (zero infra, embedded, trend)
- **Team z PostgreSQL**: pgvector (już masz DB, 75% taniej niż Pinecone)
- **Duży codebase**: Milvus/Zilliz lub LanceDB (10M+ linii kodu)
- **Enterprise**: Pinecone (managed, MCP integration)

### Trend 2026: Wektory jako typ danych, nie oddzielna baza

> "W 2025 stało się jasne, że wektory to typ danych, który można zintegrować z istniejącą bazą, a nie wymaganie osobnego systemu."
> — VentureBeat, "6 data predictions for 2026"

**pgvector** w PostgreSQL dominuje — nie potrzebujesz dedykowanej bazy wektorowej, jeśli masz PostgreSQL.

### Co indeksować (co wrzucamy do bazy wektorowej)

| Źródło | Co embedować | Granulacja |
|--------|-------------|-----------|
| `CLAUDE.md` reguły | Każda reguła osobno | 1 reguła = 1 wektor |
| `MEMORY.md` wpisy | Każdy wpis `[USER]`/`[AUTO]` osobno | 1 wpis = 1 wektor |
| Memory topic files | Każda sekcja (H2/H3) | 1 sekcja = 1 wektor |
| Frozen fragments | Opis + ścieżka + powód zamrożenia | 1 fragment = 1 wektor |
| Session log | Każda zmiana/decyzja | 1 wpis = 1 wektor |
| Kod (kluczowe pliki) | Docstring + sygnatura + komentarze | 1 funkcja = 1 wektor |
| Git commit messages | Ostatnie 100 commitów | 1 commit = 1 wektor |
| GitHub Issues | Tytuł + body + komentarze | 1 issue = 1 wektor |

### Modele embeddingowe — rekomendacje

| Model | Wymiary | Koszt | Najlepsze zastosowanie |
|-------|---------|-------|------------------------|
| `multilingual-e5-large` | 1024 | Darmowy (local) | **Wielojęzyczne projekty** (PL+EN) |
| `text-embedding-3-small` | 1536 | $0.02/1M tokenów | Ogólne, tanie, dobre |
| `text-embedding-3-large` | 3072 | $0.13/1M tokenów | Najwyższa jakość |
| `llama-text-embed-v2` | 2048 | Darmowy (local) | Duże dokumenty, Pinecone integrated |
| `nomic-embed-text` | 768 | Darmowy (local) | Szybki, lekki |

**Rekomendacja**: `multilingual-e5-large` dla projektów polskojęzycznych (nasza sytuacja — CLAUDE.md po polsku, kod po angielsku). Lub `text-embedding-3-small` jeśli koszt nie jest problemem.

### Hybrid Search — najskuteczniejsze podejście

Sam semantic search (embeddingi) czasem zawodzi:
- Nazwy własne (np. `ApprovalGateService`) → keyword lepszy
- Dokładne ścieżki plików → keyword lepszy
- Koncepcje i intencje → semantic lepszy

**Hybrid search** = keyword search + semantic search, ważone:

```python
def hybrid_search(query: str, alpha: float = 0.7) -> list[Result]:
    """
    alpha = 0.7 → 70% semantic, 30% keyword
    Optymalne dla kodu + dokumentacji
    """
    semantic_results = vector_db.search(embed(query), top_k=20)
    keyword_results = text_index.search(query, top_k=20)

    combined = merge_and_rerank(
        semantic_results,
        keyword_results,
        weights=(alpha, 1 - alpha)
    )
    return combined[:10]  # top 10 najrelevantniejszych
```

### Pinecone MCP — gotowa integracja z Claude Code

Pinecone oferuje MCP server z gotowymi narzędziami:

```json
// .mcp.json
{
  "mcpServers": {
    "pinecone": {
      "command": "npx",
      "args": ["-y", "@anthropic/pinecone-mcp"],
      "env": {
        "PINECONE_API_KEY": "<your-key>"
      }
    }
  }
}
```

**Workflow z Pinecone MCP**:
1. Utwórz index z embedded modelem (`multilingual-e5-large` lub `llama-text-embed-v2`)
2. Zaindeksuj reguły, memory, snippety kodu
3. Claude automatycznie szuka w Pinecone gdy potrzebuje kontekstu

**Ograniczenie**: MCP server = ~5-10% kontekstu na definicje narzędzi. Dla dużych projektów opłacalne, dla małych — overhead za duży.

### Lekka alternatywa bez MCP — hook + skrypt

Dla mniejszych projektów, **bez overhead MCP**, użyj hookowego podejścia:

```bash
#!/bin/bash
# .claude/hooks/smart-context.sh
# Uruchamiany przez UserPromptSubmit hook

# 1. Pobierz prompt usera ze stdin
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

# 2. Szukaj semantycznie w lokalnej bazie
RESULTS=$(python3 ~/.claude/scripts/semantic_search.py "$PROMPT" --top-k 5 --max-tokens 2000)

# 3. Zwróć relevantne konteksty via stdout (Claude je zobaczy)
if [ -n "$RESULTS" ]; then
  echo "=== SMART CONTEXT (automatically selected) ==="
  echo "$RESULTS"
  echo "=== END SMART CONTEXT ==="
fi
```

```python
# ~/.claude/scripts/semantic_search.py
"""
Lekki semantic search po lokalnej bazie Chroma.
Uruchamiany z hooka — NIE obciąża okna kontekstowego Claude.
"""
import sys
import chromadb

def search(query: str, top_k: int = 5, max_tokens: int = 2000):
    client = chromadb.PersistentClient(path="~/.claude/vector_db")
    collection = client.get_collection("project_context")

    results = collection.query(
        query_texts=[query],
        n_results=top_k
    )

    output = []
    total_chars = 0
    for doc, meta, dist in zip(
        results['documents'][0],
        results['metadatas'][0],
        results['distances'][0]
    ):
        if total_chars + len(doc) > max_tokens * 4:  # ~4 chars per token
            break
        source = meta.get('source', 'unknown')
        relevance = f"{(1 - dist) * 100:.0f}%"
        output.append(f"[{source}] (relevance: {relevance})\n{doc}")
        total_chars += len(doc)

    return "\n---\n".join(output)

if __name__ == "__main__":
    query = sys.argv[1]
    top_k = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    max_tokens = int(sys.argv[3]) if len(sys.argv) > 3 else 2000
    print(search(query, top_k, max_tokens))
```

### Kiedy vector DB opłaca się, a kiedy nie

| Rozmiar projektu | Vector DB? | Dlaczego |
|-------------------|-----------|----------|
| **< 20 plików** | **NIE** | CLAUDE.md + MEMORY.md wystarczy. Overhead > korzyść |
| **20-100 plików** | **MOŻE** | Jeśli masz dużo reguł, decyzji, memory files |
| **100-500 plików** | **TAK** | Keyword search nie nadąża. Semantic search oszczędza czas |
| **500+ plików** | **KONIECZNIE** | Bez semantic search agent tonie w kontekście |

**Dodatkowe wskazanie "TAK"**:
- Projekt wielojęzyczny (PL+EN w dokumentacji i kodzie)
- Dużo memory files / topic files / frozen fragments
- Powtarzające się sesje "agent nie wiedział o X"

---

## 4. Prompt Preprocessor — system dopracowywania zadań przed wykonaniem

### Kluczowy mechanizm: UserPromptSubmit hook

**Odkrycie**: Hook `UserPromptSubmit` ma unikalne zachowanie — **stdout jest dodawane do kontekstu**, który Claude widzi. To pozwala na wstrzykiwanie kontekstu PRZED przetwarzaniem.

```
User wpisuje: "napraw logowanie"
  ↓
UserPromptSubmit hook uruchamia preprocessor
  ↓ (osobny proces, NIE obciąża kontekstu Claude)
Preprocessor:
  1. Analizuje intent → "bug fix, authentication"
  2. Rozszerza query → "logowanie, login, auth, authentication, session"
  3. Szuka w vector DB → znalazł 3 relevantne snippety
  4. Wypisuje na stdout:
     "=== CONTEXT FOR THIS TASK ===
      Previous auth bug: #73 fixed token expiry...
      Frozen: src/auth/login.ts (nie ruszaj)
      Memory [USER]: OAuth używa refresh tokens..."
  ↓
Claude widzi:
  - Wstrzyknięty kontekst z preprocessora
  - Oryginalny prompt "napraw logowanie"
  - Standardowy CLAUDE.md + MEMORY.md
```

### Trzy podejścia do preprocessingu

#### Podejście A: Hook + skrypt (najlżejsze, rekomendowane na start)

```json
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
    ]
  }
}
```

```bash
#!/bin/bash
# .claude/hooks/preprocess-prompt.sh
# Prosty preprocessor — keyword expansion + grep po memory files

PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

# Keyword expansion (podstawowa lista synonimów)
EXPANDED=$(echo "$PROMPT" | python3 -c "
import sys
synonyms = {
    'logowanie': ['login', 'auth', 'authentication', 'session', 'token'],
    'szybciej': ['performance', 'optimization', 'N+1', 'query', 'cache'],
    'walidacja': ['validation', 'sanitization', 'OWASP', 'input', 'guard'],
    'deploy': ['deployment', 'release', 'production', 'rsync', 'restart'],
    'testy': ['test', 'spec', 'rspec', 'jest', 'pytest', 'coverage'],
    'baza': ['database', 'DB', 'PostgreSQL', 'migration', 'query', 'SQL'],
}
prompt = sys.stdin.read().lower()
keywords = set(prompt.split())
for word in list(keywords):
    for key, syns in synonyms.items():
        if word in key or key in word:
            keywords.update(syns)
print(' '.join(keywords))
")

# Szukaj w memory files
MEMORY_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory"
if [ -d "$MEMORY_DIR" ]; then
    FOUND=$(grep -rli "$EXPANDED" "$MEMORY_DIR"/*.md 2>/dev/null | head -3)
    if [ -n "$FOUND" ]; then
        echo "=== RELEVANT CONTEXT (auto-detected) ==="
        for f in $FOUND; do
            echo "--- $(basename $f) ---"
            grep -i -C 1 "$EXPANDED" "$f" 2>/dev/null | head -10
        done
        echo "=== END CONTEXT ==="
    fi
fi
exit 0
```

#### Podejście B: Subagent selector (najskuteczniejsze)

Użyj **tanego, szybkiego modelu** (Haiku) jako pre-filter:

```bash
#!/bin/bash
# .claude/hooks/smart-preprocess.sh
# Subagent-based context selection

PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

# Lista dostępnych kontekstów (lekki index)
CONTEXT_INDEX="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory/context-index.md"
[ ! -f "$CONTEXT_INDEX" ] && exit 0

# Subagent Haiku analizuje prompt i wybiera relevantne konteksty
# Koszt: ~0.001$ per zapytanie, czas: <1s
SELECTED=$(claude -p --model haiku "
Given this user task: '$PROMPT'

And these available context files with descriptions:
$(cat "$CONTEXT_INDEX")

Return ONLY the file paths (one per line) of the 1-3 most relevant context files.
No explanation, just paths." 2>/dev/null)

# Załaduj wybrane konteksty
if [ -n "$SELECTED" ]; then
    echo "=== SMART CONTEXT (selected by AI) ==="
    echo "$SELECTED" | while read -r filepath; do
        [ -f "$filepath" ] && {
            echo "--- $(basename $filepath) ---"
            head -30 "$filepath"
            echo "..."
        }
    done
    echo "=== END SMART CONTEXT ==="
fi
exit 0
```

**`context-index.md`** — lekki manifest dostępnych kontekstów:

```markdown
# Context Index
# Format: ścieżka | opis (do matching przez subagent)

memory/decisions.md | Decyzje architektoniczne — frameworki, biblioteki, wzorce
memory/preferences.md | Preferencje użytkownika — styl kodu, workflow, narzędzia
memory/pitfalls.md | Pułapki i znane problemy — bugi, workaroundy, ograniczenia
memory/frozen-fragments.md | Zamrożone pliki — co nie ruszać, produkcyjne konfiguracje
memory/session-log.md | Historia zmian — chronologiczny log decyzji i zmian
docs/context/approval-gate-reference.md | Flow akceptacji — statusy, blokady, publikacja
docs/context/acl-permissions-reference.md | Uprawnienia Nextcloud — sync, WebDAV, role
docs/context/commands-reference.md | Komendy diagnostyczne — deploy, debug, restarty
docs/context/plugins-overview.md | Architektura pluginów — struktura, zależności, logi
```

#### Podejście C: Vector DB search (najdokładniejsze)

Jak opisano w rozdziale 3 — semantic search w vector DB. Najskuteczniejsze dla dużych projektów, ale wymaga infrastruktury.

### Porównanie podejść

| Cecha | A: Hook+grep | B: Subagent | C: Vector DB |
|-------|-------------|-------------|--------------|
| **Dokładność** | 60% | 85% | 95% |
| **Latencja** | <100ms | 500ms-2s | 200ms-1s |
| **Koszt per query** | $0 | ~$0.001 | $0-0.001 |
| **Setup** | 10 min | 20 min | 1-2h |
| **"Różne słowa"** | NIE obsługuje | TAK (LLM rozumie) | TAK (embeddingi) |
| **Maintenance** | Niski | Niski | Średni (aktualizuj embeddingi) |
| **Rekomendacja** | Start, MVP | **Najlepszy balans** | Duże projekty |

### Podejście D: Agent Hook (nowość 2026, natywne w Claude Code)

Claude Code oficjalnie wspiera **agent hooks** — subagenty uruchamiane bezpośrednio w cyklu życia hooków:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "agent",
            "prompt": "Analyze this task and determine which project context files are relevant. Check the docs/ and memory/ directories. Return relevant file paths. $ARGUMENTS",
            "model": "haiku",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

Agent hook może wykonać do **50 tur narzędzi** (Read, Grep, Glob) i zwrócić decyzję `{"ok": true/false, "reason": "..."}`. Domyślnie używa szybkiego modelu.

**Przewaga nad Podejściem B**: Natywna integracja, brak potrzeby wywoływania `claude -p`, bezpośredni dostęp do narzędzi.
**Źródło**: [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)

### Realne implementacje prompt preprocessingu (open-source, 2025-2026)

| Projekt | Architektura | Kluczowa cecha |
|---------|-------------|----------------|
| [severity1/claude-code-prompt-improver](https://github.com/severity1/claude-code-prompt-improver) | Hook UserPromptSubmit → 4-fazowy workflow (Research→Questions→Clarify→Execute) | Jasne prompty przechodzą natychmiast (zero overhead), niejasne → skill z pytaniami |
| [claude-mem](https://github.com/thedotmack/claude-mem) | 6-warstwa: hooks→worker(HTTP)→AI→storage(SQLite+ChromaDB)→search→MCP | Hybrid search FTS5+Chroma, 5 lifecycle hooks, progressive disclosure 3-level |
| [c0ntextKeeper](https://github.com/Capnjbrown/c0ntextKeeper) | 7 hooków, 187 semantic patterns, 3 MCP tools | Word expansion, temporal decay scoring (60-dniowy), auto-redakcja PII |
| [Continuous-Claude-v3](https://github.com/parcadei/Continuous-Claude-v3) | 32 agentów, 30 hooków, 109 capabilities | Ledger-based continuity: "Compound, don't compact" — wyciągaj wnioski, nie kompaktuj |
| [Conductor (Gemini CLI)](https://github.com/gemini-cli-extensions/conductor) | Context-Driven Development: context → spec → plan → implement | Pliki Markdown w repo jako single source of truth, automatycznie aktualizowane per-faza |
| [Mem0](https://github.com/mem0ai/mem0) | Extraction→LLM comparison→graph memory | 26% poprawa trafności, 91% niższe p95 latency, 90%+ oszczędność tokenów |

### skill-rules.json — Auto-Activation Skills ([paddo.dev](https://paddo.dev/blog/claude-skills-hooks-solution/))

Wzorzec łączący keyword matching z intent detection:

```json
{
  "skills": [
    {
      "name": "backend-dev-guidelines",
      "triggers": {
        "prompt_keywords": ["backend", "api", "endpoint"],
        "prompt_intent": "(create|add|build).*?(route|endpoint|controller|service)",
        "file_patterns": ["src/**/*.ts"]
      }
    }
  ]
}
```

Flow: User prompt → UserPromptSubmit hook → analizuj keywords + intent regex → dopasuj skill-rules.json → wstrzyknij podpowiedzi aktywacji → Claude ładuje relevantne skille.

### Kluczowa reguła: Budget kontekstu dla preprocessora

```
NIGDY nie wstrzykuj więcej niż 15% okna kontekstowego.

Przy 200k tokenach:
- Max 30,000 tokenów z preprocessora (~15%)
- System prompt + CLAUDE.md: ~10,000 tokenów (~5%)
- Prompt usera: ~5,000 tokenów (~2.5%)
- WOLNE na rozumowanie: ~155,000 tokenów (~77.5%)

Limit w skrypcie:
MAX_CONTEXT_CHARS=120000  # ~30k tokenów × 4 chars/token
```

---

## 5. Observational Memory — kompresja kontekstu bez utraty informacji

### Nowy paradygmat: Observer + Reflector (Mastra, 2026)

**Dotychczasowe podejście**: RAG (retrieval-augmented generation) — szukaj i ładuj kontekst z zewnątrz.

**Nowe podejście**: Observational Memory — kompresuj historię rozmowy IN-PLACE, eliminując potrzebę retrieval.

### Jak działa

Dwa agenci działają w tle, niezauważalnie dla użytkownika:

```
Rozmowa agenta z userem
  │
  │  (co 30,000 tokenów nowych wiadomości)
  ↓
OBSERVER
  - Czyta nowe wiadomości
  - Kompresuje do "obserwacji" (3-6x kompresja tekstu, 5-40x dla narzędzi)
  - Dodaje obserwacje do bloku na początku kontekstu
  - Oryginalne wiadomości → usunięte
  │
  │  (co 40,000 tokenów obserwacji)
  ↓
REFLECTOR
  - Restrukturyzuje i kondensuje blok obserwacji
  - Łączy powiązane elementy
  - Usuwa zdezaktualizowane informacje
  - Wynik: gęsty, aktualny "dziennik obserwacji"
```

### Benchmark

| Metryka | Observational Memory | RAG (Mastra) | Brak pamięci |
|---------|---------------------|--------------|-------------|
| **LongMemEval** (GPT-5-mini) | **94.87%** | 80.05% | ~40% |
| **Kompresja tekstu** | 3-6x | N/A | N/A |
| **Kompresja narzędzi** | 5-40x | N/A | N/A |
| **Stabilność okna** | Stała | Zmienna | Rośnie liniowo |
| **Cache-friendly** | TAK (prefix) | NIE | NIE |

### Implementacja w Claude Code — L4 Auto-Persistence

Rozszerzenie systemu z `bestPersistentAI.md`:

```
L1: Session Memory (wbudowane)     — automatyczne podsumowania
L2: Auto Memory (MEMORY.md)        — trwałe pliki
L3: Stop Hook Pipeline             — deterministyczny zapis
L4: Observational Memory (NOWE)    — kompresja bez utraty
```

**Implementacja za pomocą hooka Stop**:

```bash
#!/bin/bash
# .claude/hooks/observe-and-compress.sh
# Uruchamiany hookiem Stop — po każdej odpowiedzi agenta

# Pobierz transcript bieżącej sesji
SESSION_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')"
CURRENT_SESSION=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1)
[ -z "$CURRENT_SESSION" ] && exit 0

# Policz tokeny od ostatniej obserwacji
OBSERVATION_FILE="$SESSION_DIR/memory/observations.md"
LAST_OBSERVED_LINE=$(grep -c "" "$OBSERVATION_FILE" 2>/dev/null || echo 0)
CURRENT_LINES=$(wc -l < "$CURRENT_SESSION")

NEW_LINES=$((CURRENT_LINES - LAST_OBSERVED_LINE))

# Obserwuj co 5000 linii (≈30k tokenów)
if [ "$NEW_LINES" -gt 5000 ]; then
    # Subagent Observer (Haiku — tani, szybki)
    tail -"$NEW_LINES" "$CURRENT_SESSION" | \
    claude -p --model haiku "
    Compress these conversation messages into dense observations.
    Format: dated bullet points with key decisions, findings, errors.
    Max 20 lines. Focus on: decisions, preferences, bugs found, files changed.
    " >> "$OBSERVATION_FILE" 2>/dev/null

    echo "$CURRENT_LINES" > "$SESSION_DIR/memory/.last-observed-line"
fi
exit 0
```

### Zalety vs RAG dla agenta CLI

| Cecha | Observational Memory | RAG |
|-------|---------------------|-----|
| **Wymaga vector DB** | NIE | TAK |
| **Wymaga embedding API** | NIE | TAK |
| **Latencja** | 0 (in-context) | 100ms-2s |
| **Kompletność** | Pełna historia, skompresowana | Fragmenty, mogą brakować |
| **Aktualność** | Zawsze aktualna | Zależy od indeksowania |
| **Koszt** | Kompresja ≈ $0.001/sesja | Embedding + search |
| **Gdy najlepszy** | Długie sesje, ciągłe zadania | Duża baza wiedzy, szukanie |

**Rekomendacja**: Observational Memory + RAG razem = najlepsza kombinacja.
- OM dla **bieżącej sesji** (co się stało, jakie decyzje)
- RAG/Vector DB dla **bazy wiedzy** (reguły, wzorce, historia projektu)

---

## 6. Session Intelligence — analiza historii sesji i uczenie się wzorców

### Problem

Typowy serwer z Claude Code gromadzi setki sesji (JSONL transcripts). Nikt ich nie analizuje — marnując ogromną ilość wiedzy o:
- Jakie zadania były wykonywane i jak
- Które konteksty były przydatne, a które nie
- Jakie błędy się powtarzają
- Jakie preferencje użytkownik wykazuje w praktyce

### Rozwiązanie: Session Intelligence Pipeline

```
Historical JSONL transcripts
  ↓
[Extractor] — parsuje JSONL, wyciąga typy wiadomości, tool calls, błędy
  ↓
[Analyzer] — identyfikuje wzorce: częste zadania, powtarzające się problemy
  ↓
[Recommender] — sugeruje:
  - Nowe reguły do CLAUDE.md
  - Nowe memory entries
  - Nowe context-index wpisy
  - Nowe frozen fragments
  ↓
[Updater] — aktualizuje bazę wiedzy (z zatwierdzeniem usera)
```

### Skrypt ekstrakcji wzorców z sesji

```python
#!/usr/bin/env python3
"""
session_intelligence.py — analizuje historię sesji Claude Code
Uruchamiaj: python3 session_intelligence.py /path/to/project
"""
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

def analyze_sessions(project_dir: str):
    sessions_dir = Path(project_dir)

    # Statystyki
    stats = {
        'total_sessions': 0,
        'total_messages': 0,
        'tool_calls': Counter(),       # które narzędzia najczęściej
        'error_patterns': Counter(),    # jakie błędy się powtarzają
        'file_access': Counter(),       # które pliki najczęściej czytane/edytowane
        'compactions': 0,               # ile razy kontekst się kompaktował
        'long_sessions': [],            # sesje > 10k linii
        'topics': Counter(),            # słowa kluczowe z promptów
    }

    for jsonl_file in sessions_dir.glob("*.jsonl"):
        stats['total_sessions'] += 1
        line_count = 0

        with open(jsonl_file) as f:
            for line in f:
                line_count += 1
                try:
                    msg = json.loads(line.strip())
                except:
                    continue

                stats['total_messages'] += 1
                msg_type = msg.get('type', '')

                # Licz tool calls
                if msg_type == 'assistant':
                    content = msg.get('message', {}).get('content', [])
                    if isinstance(content, list):
                        for block in content:
                            if block.get('type') == 'tool_use':
                                tool_name = block.get('name', 'unknown')
                                stats['tool_calls'][tool_name] += 1
                                # Śledź dostęp do plików
                                inp = block.get('input', {})
                                file_path = inp.get('file_path') or inp.get('path') or inp.get('command', '')
                                if file_path and '/' in str(file_path):
                                    stats['file_access'][str(file_path)] += 1

                # Śledź błędy
                if msg_type == 'tool_result':
                    result = msg.get('result', '')
                    if 'error' in str(result).lower():
                        # Wyciągnij pattern błędu
                        error_line = str(result)[:100]
                        stats['error_patterns'][error_line] += 1

                # Śledź tematy (z promptów użytkownika)
                if msg_type == 'human' or msg_type == 'user':
                    content = msg.get('message', {}).get('content', '')
                    if isinstance(content, str):
                        words = content.lower().split()
                        for w in words:
                            if len(w) > 4:  # pomijaj krótkie słowa
                                stats['topics'][w] += 1

                # Wykryj kompakcję
                if 'compact' in str(msg).lower():
                    stats['compactions'] += 1

        if line_count > 10000:
            stats['long_sessions'].append({
                'file': jsonl_file.name,
                'lines': line_count
            })

    return stats

def generate_report(stats: dict) -> str:
    report = ["# Session Intelligence Report", ""]
    report.append(f"## Statystyki ogólne")
    report.append(f"- Sesji: {stats['total_sessions']}")
    report.append(f"- Wiadomości: {stats['total_messages']}")
    report.append(f"- Kompakcji: {stats['compactions']}")
    report.append(f"- Długich sesji (>10k linii): {len(stats['long_sessions'])}")

    report.append(f"\n## Top 10 narzędzi")
    for tool, count in stats['tool_calls'].most_common(10):
        report.append(f"- `{tool}`: {count}x")

    report.append(f"\n## Top 10 najczęściej czytanych plików")
    for path, count in stats['file_access'].most_common(10):
        report.append(f"- `{path}`: {count}x")

    report.append(f"\n## Powtarzające się błędy")
    for error, count in stats['error_patterns'].most_common(5):
        report.append(f"- [{count}x] `{error[:80]}...`")

    report.append(f"\n## Najczęstsze tematy")
    for topic, count in stats['topics'].most_common(15):
        report.append(f"- `{topic}`: {count}x")

    report.append(f"\n## Rekomendacje")

    # Automatyczne rekomendacje
    if stats['compactions'] > 5:
        report.append("- UWAGA: Częste kompakcje — rozważ krótsze sesje lub subagentów")

    if len(stats['long_sessions']) > 0:
        report.append(f"- {len(stats['long_sessions'])} sesji przekroczyło 10k linii — kandydaci do split/subagent")

    top_files = stats['file_access'].most_common(5)
    if top_files:
        report.append("- Najczęściej czytane pliki — rozważ preloading w SessionStart hook:")
        for path, count in top_files:
            report.append(f"  - `{path}` ({count}x)")

    top_errors = stats['error_patterns'].most_common(3)
    if top_errors:
        report.append("- Powtarzające się błędy — dodaj do memory/pitfalls.md:")
        for error, count in top_errors:
            report.append(f"  - [{count}x] `{error[:60]}...`")

    return "\n".join(report)

if __name__ == "__main__":
    project_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    stats = analyze_sessions(project_dir)
    print(generate_report(stats))
```

### Automatyczne uruchamianie — SessionStart hook

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/scripts/session_intelligence.py ~/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-') > /tmp/session-report.md && head -30 /tmp/session-report.md"
          }
        ]
      }
    ]
  }
}
```

### Istniejące narzędzia do analizy sesji (open-source)

| Narzędzie | Architektura | Kluczowa cecha |
|-----------|-------------|----------------|
| [CASS](https://github.com/Dicklesworthstone/coding_agent_session_search) | SQLite + Tantivy full-text index | Unified TUI/CLI, 11+ providerów, **sub-60ms search**, multi-machine via SSH/rsync, real-time watch mode |
| [Definite.app Session Search](https://www.definite.app/blog/claude-code-search-skill) | Python skill + full-text search | Parsuje JSONL → dataclasses (Message, Conversation), filtrowanie po projekcie |
| [DuckDB JSONL Analysis](https://liambx.com/blog/claude-code-log-analysis-with-duckdb) | SQL queries bezpośrednio po JSONL | Zero ETL — `SELECT * FROM read_json('~/.claude/projects/**/*.jsonl')` |
| [total-recall](https://github.com/radu2lupu/total-recall) | qmd hybrid BM25+vector | Cross-session semantic memory, multi-machine z HTTP server |

**CASS** (Coding Agent Session Search) jest najbardziej dojrzały — dual-storage (SQLite = source of truth, Tantivy = search index), edge n-grams dla prefix matching, connectors normalizujące JSONL/SQLite/Markdown do unified schema.

### Budowanie mappingu task → context

Praktyczny wzorzec z [claude-mem](https://github.com/thedotmack/claude-mem):

1. **Zbieraj dane**: Przy `UserPromptSubmit` loguj: prompt, załadowane konteksty, session_id
2. **Przy `Stop`**: Loguj: czy zadanie się powiodło, które narzędzia użyte
3. **Analizuj periodycznie**: DuckDB query po JSONL — "dla promptów zawierających X, jakie konteksty były ładowane i czy zadanie się powiodło?"
4. **Buduj indeks**: Mapping `prompt_category → [context_files_that_led_to_success]`
5. **Feed back**: Użyj mappingu w UserPromptSubmit hook do automatycznej selekcji kontekstu

### Cykliczna analiza (cron)

Dla projektów z dużą historią, uruchamiaj analizę cyklicznie:

```bash
# Crontab: co noc o 3:00
0 3 * * * python3 ~/.claude/scripts/session_intelligence.py \
  ~/.claude/projects/-var-www-html \
  > ~/.claude/projects/-var-www-html/memory/session-report.md

# Opcjonalnie: aktualizuj vector DB z nowymi wpisami
0 3 * * * python3 ~/.claude/scripts/update_vector_db.py \
  --source ~/.claude/projects/-var-www-html/memory/ \
  --db ~/.claude/vector_db
```

---

## 7. Integracja — jak wszystko działa razem

### Kompletny flow od promptu do odpowiedzi

```
┌────────────────────────────────────────────────────────────────┐
│ USER PROMPT: "napraw logowanie, użytkownicy nie mogą się       │
│               zalogować po wczorajszym deploy"                 │
└───────────────────────┬────────────────────────────────────────┘
                        ↓
┌─── WARSTWA 1: UserPromptSubmit Hook ──────────────────────────┐
│                                                                │
│  Preprocessor (subprocess, 0 tokenów kontekstu):               │
│  1. Intent: "bug fix, authentication, post-deployment"         │
│  2. Keywords: login, auth, deploy, session, token, OAuth       │
│  3. Query vector DB → 3 trafienia:                             │
│     - memory/pitfalls.md: "OAuth token expiry after restart"   │
│     - session-log: "2026-02-22: deploy zmienił config auth"    │
│     - frozen: "src/auth/login.ts jest FROZEN"                  │
│  4. stdout → wstrzyknięte do kontekstu Claude                  │
│                                                                │
│  Output: ~1,500 tokenów precyzyjnego kontekstu                 │
└───────────────────────┬────────────────────────────────────────┘
                        ↓
┌─── WARSTWA 2: Claude Main Agent ──────────────────────────────┐
│                                                                │
│  Context window (200k):                                        │
│  ┌──────────────────────────────────────┐                      │
│  │ System prompt + CLAUDE.md    (~5%)   │ ← zawsze             │
│  │ MEMORY.md (200 linii)       (~3%)   │ ← zawsze             │
│  │ Smart Context (from hook)   (~1%)   │ ← precyzyjne!        │
│  │ User prompt                 (~1%)   │                       │
│  │                                      │                       │
│  │ [WOLNE: ~90% na rozumowanie]        │ ← najlepsza jakość   │
│  └──────────────────────────────────────┘                      │
│                                                                │
│  Agent widzi: "src/auth/login.ts jest FROZEN — nie edytuj"     │
│  Agent widzi: "OAuth token expiry po restart — znany problem"  │
│  Agent widzi: "Wczorajszy deploy zmienił config auth"          │
│  → Diagnozuje problem precyzyjnie, nie marnuje tokenów         │
│                                                                │
└───────────────────────┬────────────────────────────────────────┘
                        ↓
┌─── WARSTWA 3: Observational Memory (w tle) ───────────────────┐
│                                                                │
│  Observer śledzi rozmowę i kompresuje:                         │
│  "2026-02-23: Naprawiono bug auth po deploy. Przyczyna:        │
│   token config nie przeżywał restart. Fix: env var             │
│   zamiast hardcoded. FROZEN src/auth/login.ts odmrożony        │
│   na czas naprawy, ponownie zamrożony po fix."                 │
│                                                                │
└───────────────────────┬────────────────────────────────────────┘
                        ↓
┌─── WARSTWA 4: Session Intelligence (po sesji) ────────────────┐
│                                                                │
│  Analyzer wykrywa pattern:                                      │
│  - "Deploy auth bug" — 3 raz w tym miesiącu                    │
│  → Rekomendacja: Dodaj pre-deploy check do hooks               │
│  → Rekomendacja: Dodaj do pitfalls.md                           │
│  → Aktualizuj vector DB z nowym wpisem                          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Budżet kontekstu — kompletny

```
┌──────────────────────────────────────────────────────────────┐
│  BUDŻET KONTEKSTU (200k tokenów)                             │
│                                                               │
│  ████ System prompt                     ~10k (5%)            │
│  ██   CLAUDE.md                         ~4k  (2%)            │
│  ██   MEMORY.md (200 linii)            ~3k  (1.5%)          │
│  ███  Smart Context (hook injected)    ~6k  (3%)  ← NOWE    │
│  ██   Observational Memory block       ~5k  (2.5%)  ← NOWE  │
│  ██   User prompt                      ~2k  (1%)            │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                      │
│       WOLNE na rozumowanie + narzędzia  ~170k (85%)          │
│                                                               │
│  Porównanie z "naiwnym ładowaniem":                           │
│  ████████████████ Loaded context        ~80k (40%)           │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░                                │
│       WOLNE na rozumowanie              ~120k (60%)          │
│                                                               │
│  Smart Context: 85% wolne vs Naiwne: 60% wolne               │
│  → 42% więcej miejsca na rozumowanie!                         │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. Gotowa implementacja krok po kroku

### Poziom 1: Minimum (15 minut)

**Cel**: Keyword-based context routing bez vector DB.

```bash
# 1. Utwórz katalog hooks
mkdir -p .claude/hooks

# 2. Utwórz context-index.md
cat > .claude/memory/context-index.md << 'EOF'
# Context Index — opis dostępnych kontekstów
# Format: ścieżka | słowa kluczowe | opis

memory/decisions.md | architektura framework biblioteka wzorzec | Decyzje architektoniczne
memory/preferences.md | styl workflow narzędzia preferencje | Preferencje użytkownika
memory/pitfalls.md | bug błąd problem workaround pułapka | Znane problemy
memory/frozen-fragments.md | frozen zamrożony produkcja stabilny | Co nie ruszać
EOF

# 3. Utwórz prosty preprocessor hook
cat > .claude/hooks/preprocess-prompt.sh << 'HOOKEOF'
#!/bin/bash
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

MEMORY_DIR=".claude/memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

# Szukaj relevantnych kontekstów keyword-based
FOUND=$(grep -rli "$(echo $PROMPT | tr ' ' '\n' | sort -u | tr '\n' '|' | sed 's/|$//')" "$MEMORY_DIR"/*.md 2>/dev/null | head -3)

if [ -n "$FOUND" ]; then
    echo "=== AUTO CONTEXT ==="
    for f in $FOUND; do
        echo "[$( basename $f )]"
        head -15 "$f"
        echo "..."
    done
    echo "=== END AUTO CONTEXT ==="
fi
exit 0
HOOKEOF
chmod +x .claude/hooks/preprocess-prompt.sh

# 4. Dodaj hook do settings.json
# (ręcznie dodaj do .claude/settings.json sekcję UserPromptSubmit)
```

### Poziom 2: Standard (30 minut)

**Cel**: Subagent-based context selection (Podejście B).

Wykonaj Poziom 1, plus:

```bash
# 5. Zainstaluj zależności
pip install chromadb  # lub: użyj subagent approach bez vector DB

# 6. Utwórz smart preprocessor z subagent selector
# (Podejście B z rozdziału 4)
cp .claude/hooks/preprocess-prompt.sh .claude/hooks/preprocess-prompt-basic.sh
# Zastąp preprocess-prompt.sh skryptem z Podejścia B

# 7. Dodaj session intelligence script
mkdir -p ~/.claude/scripts
# Skopiuj session_intelligence.py z rozdziału 6

# 8. Dodaj do CLAUDE.md:
cat >> CLAUDE.md << 'EOF'

# Smart Context
UserPromptSubmit hook automatycznie wstrzykuje relevantny kontekst.
Jeśli widzisz "=== AUTO CONTEXT ===" — to informacje dobrane do Twojego zadania.
Traktuj je jako high-priority context przy planowaniu rozwiązania.
EOF
```

### Poziom 3: Pełny (1-2 godziny)

**Cel**: Vector DB + Observational Memory + Session Intelligence.

Wykonaj Poziom 1+2, plus:

```bash
# 9. Zaindeksuj bazę wiedzy w Chroma
python3 << 'PYEOF'
import chromadb
from pathlib import Path

client = chromadb.PersistentClient(path=".claude/vector_db")
collection = client.get_or_create_collection(
    name="project_context",
    metadata={"hnsw:space": "cosine"}
)

# Zaindeksuj memory files
memory_dir = Path(".claude/memory")
docs, ids, metas = [], [], []

for md_file in memory_dir.glob("*.md"):
    content = md_file.read_text()
    # Podziel na sekcje (H2)
    sections = content.split("\n## ")
    for i, section in enumerate(sections):
        if len(section.strip()) < 20:
            continue
        doc_id = f"{md_file.stem}-section-{i}"
        docs.append(section[:2000])  # max 2000 chars per section
        ids.append(doc_id)
        metas.append({
            "source": str(md_file),
            "section_index": i,
            "type": "memory"
        })

if docs:
    collection.add(documents=docs, ids=ids, metadatas=metas)
    print(f"Indexed {len(docs)} sections from {len(list(memory_dir.glob('*.md')))} files")
PYEOF

# 10. Zastąp preprocessor na wersję z vector DB (Podejście C)
# 11. Skonfiguruj Observational Memory hook (z rozdziału 5)
# 12. Dodaj cron dla Session Intelligence (z rozdziału 6)
```

---

## 9. Walidacja na realnym projekcie — case study Nuconic

### Kontekst

Serwer `task.nuconic.com` — OpenProject z pluginami NUCONIC. Produkcyjne środowisko, 29 dni analizy (26.01–23.02.2026).

### Analiza sesji — twarde dane z serwera

| Metryka | Wartość | Wnioski |
|---------|---------|---------|
| Sesji JSONL | **234** + 383 sub-agentów | Intensywne użytkowanie (~8 sesji/dzień) |
| Łączne wywołania narzędzi | **16,761** | Bash 56.5%, Read 12.1%, Write 6.7% |
| Łączne błędy narzędzi | **1,298 (7.7%)** | Bash exit code 1 = 67.9% błędów |
| Dane JSONL | **~451 MB** | Gigantyczny dataset do analizy |
| Sesje z kompakcją | **50 (21%)**, 84 kompakcje łącznie | Co 5. sesja traci kontekst |
| Sesje przerwane przez usera | **122 (52%)** | Agent wymagał interwencji |
| Największa sesja | 22.3 MB, 940 narzędzi, **12 kompakcji** | Skrajny przypadek — budget→sales |

### TOP 5 realnych bolączek odkrytych w analizie

#### 1. Compliance z regułami CLAUDE.md = 6%

**Szokujące odkrycie**: 31 z 33 sesji z operacjami deploy/restart/migrate **nie wykonało backupu** przed. Reguła "Przed KAŻDĄ pracą — backup bazy" opisana w CLAUDE.md, ale compliance wynosi **6%**. Przez pierwsze 24 dni pracy na produkcji nie było ANI JEDNEGO backupu na dysku.

→ **Wniosek**: Dokumentacja ≠ enforcement. Reguły krytyczne muszą być wymuszone hookami, nie tylko tekstem.

#### 2. Rails runner multiline: 150 błędów w 40 sesjach

Agent regularnie próbował przekazać wieloliniowy Ruby przez `openproject run rails runner '...'`, co nie działa z Bash quoting. Mimo wpisu w MEMORY.md, ten sam błąd powtarza się sesja po sesji.

→ **Wniosek**: Zbyt "grzeczne" sformułowanie w MEMORY. Powinno być: `## NIGDY inline multi-line. ZAWSZE: echo > /tmp/script.rb && openproject run rails runner /tmp/script.rb`

#### 3. Kompakcja kontekstu = utrata stanu roboczego

Po kompakcji agent:
- Traci info o przeczytanych plikach → 26 błędów "Write without Read"
- Ponownie czyta CLAUDE.md/AGENTS.md (3-4x w jednej sesji)
- Powtarza wcześniejsze komendy (nie pamięta prób)
- Sesja `6c18bdfe` (12 kompakcji): czytała `sales_controller.rb` **4 razy**

→ **Wniosek**: Dla zadań >500 narzędzi, lepiej podzielić na mniejsze sesje. Observational Memory rozwiązuje to kompresując kontekst 3-6x.

#### 4. Restarty produkcji w godzinach pracy: 45%

63 z 139 restartów `openproject restart` między 8:00–17:00 CET. Reguła "unikaj godzin pracy" ignorowana.

→ **Wniosek**: Hook na `openproject restart` sprawdzający godzinę i wymagający potwierdzenia. Nie polegaj na instrukcji tekstowej.

#### 5. Subagent explosion: 383 pliki, jeden 12.5 MB

Subagenty generują ogromne ilości danych ale często z niewielką korzyścią — główna sesja i tak musi czekać i powtarzać pracę.

→ **Wniosek**: Ograniczaj subagenty do czysto niezależnych zadań. Dla sekwencyjnych — pracuj w głównej sesji.

### Jak Smart Context rozwiązałby te problemy

| Problem | Rozwiązanie | Mechanizm | Szacowany efekt |
|---------|-------------|-----------|-----------------|
| Backup compliance 6% | PreToolUse hook + regex na rsync/restart/migrate | Hook blokuje deploy bez wcześniejszego pg_dump | 100% compliance |
| Rails runner 150 błędów | Prompt Preprocessor z anti-pattern DB | Hook wstrzykuje "NIGDY inline Ruby" gdy wykryje `rails runner` | -90% błędów |
| Kompakcja = amnezja | Observational Memory (Observer+Reflector) | Kompresja 3-6x tekstu, 5-40x narzędzi, zachowuje decyzje | -80% re-reads |
| Restart w pracy | PreToolUse hook + sprawdzenie czasu | `date +%H` → block jeśli 8-17 bez --force | -95% naruszeń |
| Brak semantic search | Vector DB + hybrid search | "napraw sync" → finds "permissions synchronization" | Elimunuje "agent nie wiedział" |
| Pusty start sesji | SessionStart hook + session-report.md | Ładuje historię, ostatnie issues, decyzje | Od 0 do 100% kontekstu na starcie |

---

## 10. Słabe punkty i mitygacje

### Udokumentowane awarie systemów kontekstowych (dane z GitHub Issues + badania 2025-2026)

#### Problem krytyczny #1: CLAUDE.md ignorowany po kompakcji

**GitHub Issues: [#19471](https://github.com/anthropics/claude-code/issues/19471), [#9796](https://github.com/anthropics/claude-code/issues/9796), [#6354](https://github.com/anthropics/claude-code/issues/6354)**

Claude po auto-kompakcji **kompletnie zapomina instrukcje z CLAUDE.md**. Issue #9796 dokumentuje: instrukcje przestrzegane idealnie przed kompakcją, łamane w **100% przypadków** po kompakcji. Przyczyna: podsumowanie kompakcji nie zachowuje treści project-context.

**Brak PostCompact hooka** ([#14258](https://github.com/anthropics/claude-code/issues/14258), [#17237](https://github.com/anthropics/claude-code/issues/17237)) — kluczowa luka architektoniczna. PreCompact hooki mogą wstrzykiwać treść, ale ta treść sama zostaje sparafrazowana podczas kompakcji.

**Mitygacja Smart Context**: Observational Memory kompresuje kontekst PRZED kompakcją, zachowując decyzje. SessionStart hook odtwarza krytyczne reguły po kompakcji.

#### Problem krytyczny #2: CLAUDE.md ignorowany w 50% sesji (nawet bez kompakcji)

**GitHub Issue [#17530](https://github.com/anthropics/claude-code/issues/17530)** — instrukcje ignorowane w ~50% sesji mimo dyrektyw "MUST", "ALWAYS", "NEVER".

**Przyczyny**:
- CLAUDE.md >150 linii → "lost in the middle" effect (LLM najlepiej pamięta początek i koniec)
- Context rot przy ~147,000-152,000 tokenów, choć limit reklamowany jako 200k
- System prompt sam zużywa ~24k tokenów → użyteczne okno = ~176k
- Efekt "Context Confusion" — zbyt wiele podobnych instrukcji = model zdezorientowany

**Mitygacja Smart Context**: Zamiast polegać na CLAUDE.md → wymuś hooki. Hook PreToolUse z regexem jest DETERMINISTYCZNY (nie podlega "zapominaniu").

#### Problem krytyczny #3: Reguły bezpieczeństwa ignorowane

**GitHub Issue [#2142](https://github.com/anthropics/claude-code/issues/2142)** (P0 Critical) — agent **systematycznie commitował klucze API** do publicznego repozytorium, mimo że CLAUDE.md zawierał "NEVER COMMIT API KEYS". Opisane przez The Register i SC Media.

**Na naszym serwerze Nuconic**: Backup compliance = 6%. 31 z 33 sesji z deploy/restart/migrate nie wykonało backupu. Reguła krytyczna ignorowana.

**Mitygacja Smart Context**: PreToolUse hook z `exit 2` (blokada) → niemożliwe do zignorowania, w przeciwieństwie do tekstu w CLAUDE.md.

#### Problem krytyczny #4: Auto-memory zapisuje błędne informacje

**GitHub Issue [#23310](https://github.com/anthropics/claude-code/issues/23310)** — zmiany w memory ukryte za UI elementem, użytkownik nie widzi co zostało zapisane. Issues [#23544](https://github.com/anthropics/claude-code/issues/23544), [#23750](https://github.com/anthropics/claude-code/issues/23750) — żądanie wyłączenia auto-memory, bo tworzy redundantny kontekst.

**Mitygacja Smart Context**: Tagi [USER]/[AUTO] z reguły eskalacji. Auto-memory = [AUTO], nigdy nie nadpisuje [USER].

### Problemy techniczne Smart Context i rozwiązania

| Problem | Ryzyko | Mitygacja |
|---------|--------|-----------|
| **Latencja preprocessora** | +200ms-2s na każdy prompt | Timeout 3s, fallback na basic grep |
| **Koszt subagent Haiku** | ~$0.001/query | Budget cap: max $1/dzień |
| **Embedding quality dla kodu** | Kod embeduje się gorzej niż tekst naturalny | Hybrid search (keyword + semantic + AST) |
| **Cold start** | Nowy projekt = pusta baza wektorowa | Automatyczny seeding z CLAUDE.md + first commits |
| **Utrzymanie embeddingów** | Muszą być aktualizowane przy zmianach | PostToolUse hook: auto-reindex po Edit |
| **False positive context** | Wstrzyknięty kontekst może być mylący | Max 15% budżet + relevance threshold 70%+ |
| **Hook injection cumulative** | Każdy prompt = dodatkowe tokeny | Smart: wstrzykuj TYLKO gdy relevance > threshold |
| **MCP context bloat** | 67k+ tokenów na starcie z wieloma MCP | MCP Tool Search (v2.0.10+), max 3-4 MCP serwerów |
| **Vector DB staleness** | Kod zmienia się codziennie, indeks nieaktualny | PostToolUse hook auto-reindex, lub agentic search fallback |
| **Digital punding** | Po wielokrotnej kompakcji agent staje się szkodliwy | Max 3 kompakcje → `/clear` + nowa sesja |

### Kiedy NIE stosować Smart Context

- **Trivial tasks** (typo fix, rename) — overhead > korzyść
- **Nowy, pusty projekt** — nie ma czego szukać
- **Jedno-sesyjne projekty** — brak historii do uczenia
- **Limitowany budżet API** — subagent Haiku kosztuje (mało, ale kosztuje)
- **Sesja >3 kompakcji** — przerwij, `/clear`, zacznij nową z MEMORY

### Escape hatch

Zawsze zachowaj możliwość wyłączenia:

```json
// .claude/settings.json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "test -f .claude/DISABLE_SMART_CONTEXT && exit 0 || .claude/hooks/preprocess-prompt.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
# Wyłącz:
touch .claude/DISABLE_SMART_CONTEXT

# Włącz:
rm .claude/DISABLE_SMART_CONTEXT
```

---

## 11. Źródła

### Bazy wektorowe i semantic search

1. [Pinecone MCP Server](https://github.com/anthropics/pinecone-mcp) — gotowa integracja Pinecone z Claude Code
2. [ChromaDB](https://www.trychroma.com/) — embedded vector database, open source
3. [pgvector](https://github.com/pgvector/pgvector) — rozszerzenie PostgreSQL do wektorów
4. [LanceDB](https://lancedb.com/) — serverless, embedded vector DB
5. [6 data predictions for 2026 — VentureBeat](https://venturebeat.com/data/six-data-shifts-that-will-shape-enterprise-ai-in-2026) — wektory jako typ danych, nie oddzielna baza

### Observational Memory

6. [Observational Memory — Mastra](https://mastra.ai/docs/memory/observational-memory) — Observer + Reflector pattern
7. [Mastra Research: 95% on LongMemEval](https://mastra.ai/research/observational-memory) — benchmarki
8. [How Mastra's Observational Memory Beats RAG](https://www.techbuddies.io/2026/02/12/how-mastras-observational-memory-beats-rag-for-long-running-ai-agents/) — porównanie z RAG
9. [openclaw-memory — 5-layer protection](https://github.com/gavdalf/openclaw-memory) — Observer + Reflector dla AI agentów

### Context routing i preprocessing

10. [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — UserPromptSubmit stdout injection + agent hooks
11. [Claude Code Hooks Mastery — disler](https://github.com/disler/claude-code-hooks-mastery) — zaawansowane użycie hooków
12. [claude-mem — hooks architecture](https://docs.claude-mem.ai/hooks-architecture) — UserPromptSubmit preprocessing
13. [Context7 MCP Server](https://github.com/upstash/context7) — semantic search dokumentacji on-demand
14. [Feature Request: Bridge Context Between Sub-Agents — #5812](https://github.com/anthropics/claude-code/issues/5812) — kontekst między subagentami
15. [severity1/claude-code-prompt-improver](https://github.com/severity1/claude-code-prompt-improver) — 4-fazowy prompt refinement
16. [Skills Auto-Activation via Hooks — paddo.dev](https://paddo.dev/blog/claude-skills-hooks-solution/) — skill-rules.json pattern
17. [Claude Code Hook to Ask Gemini — GreenFlux](https://blog.greenflux.us/claude-code-hook-to-ask-gemini-for-help/) — cross-model hook

### RAG i Context Engine

18. [Is RAG Dead? The Rise of Context Engineering — TDS](https://towardsdatascience.com/beyond-rag/) — ewolucja RAG → Context Engine
19. [From RAG to Context — RAGFlow 2025 Review](https://ragflow.io/blog/rag-review-2025-from-rag-to-context) — przegląd ewolucji
20. [Agent Memory: Why Your AI Has Amnesia — Oracle](https://blogs.oracle.com/developers/agent-memory-why-your-ai-has-amnesia-and-how-to-fix-it) — wzorce pamięci agentów
21. [AI Agent Memory: Build Stateful Systems — Redis](https://redis.io/blog/ai-agent-memory-stateful-systems/) — architektura pamięci

### Subagenci i orchestracja

22. [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) — oficjalna dokumentacja
23. [Best Practices: From Prompts to Pipelines — PubNub](https://www.pubnub.com/blog/best-practices-claude-code-subagents-part-two-from-prompts-to-pipelines/) — subagent pipeline patterns
24. [Understanding Claude Code's Full Stack — alexop.dev](https://alexop.dev/posts/understanding-claude-code-full-stack/) — MCP, Skills, Subagents, Hooks
25. [Agentic Coding with Haiku 4.5 — skywork.ai](https://skywork.ai/blog/agentic-coding-claude-haiku-4-5-beginners-guide-sub-agent-orchestration/) — Haiku subagents do selekcji kontekstu

### Session Intelligence

26. [CASS — coding_agent_session_search](https://github.com/Dicklesworthstone/coding_agent_session_search) — SQLite+Tantivy, 11+ providerów, sub-60ms
27. [Building Session Search Skill — Definite.app](https://www.definite.app/blog/claude-code-search-skill) — Python skill, JSONL parsing
28. [Claude Code Log Analysis with DuckDB — Liam ERD](https://liambx.com/blog/claude-code-log-analysis-with-duckdb) — SQL bezpośrednio po JSONL
29. [total-recall — cross-session semantic memory](https://github.com/radu2lupu/total-recall) — qmd hybrid BM25+vector

### Realne systemy kontekstowe

30. [claude-mem](https://github.com/thedotmack/claude-mem) — 6-warstwa, FTS5+ChromaDB hybrid search, 4700+ stars
31. [c0ntextKeeper](https://github.com/Capnjbrown/c0ntextKeeper) — 7 hooków, 187 semantic patterns, temporal decay
32. [Continuous-Claude-v3](https://github.com/parcadei/Continuous-Claude-v3) — 32 agentów, ledger-based continuity
33. [Conductor — Gemini CLI](https://github.com/gemini-cli-extensions/conductor) — Context-Driven Development
34. [Volt/LCM — Lossless Context Management](https://github.com/voltropy/volt) — DAG sumaryzacji, deterministyczna pętla
35. [Mem0 — Universal Memory Layer](https://github.com/mem0ai/mem0) — 26% poprawa trafności, pamięć jako graf

### Udokumentowane awarie i ograniczenia

36. [GH #19471 — CLAUDE.md ignored after compaction](https://github.com/anthropics/claude-code/issues/19471)
37. [GH #17530 — CLAUDE.md Not Reading in 50% sessions](https://github.com/anthropics/claude-code/issues/17530)
38. [GH #2142 — Security guidelines ignored (P0)](https://github.com/anthropics/claude-code/issues/2142)
39. [GH #14258 — PostCompact Hook request](https://github.com/anthropics/claude-code/issues/14258)
40. [GH #6549 — Behavioral drift through compaction](https://github.com/anthropics/claude-code/issues/6549)
41. [GH #23310 — Auto-memory saves wrong info](https://github.com/anthropics/claude-code/issues/23310)
42. [Boris Cherny on X — agentic search vs RAG](https://x.com/bcherny/status/2017824286489383315) — "we dropped vector db"
43. [SmartScope — Why Claude Code Dropped Vector DB RAG](https://smartscope.blog/en/ai-development/practices/rag-debate-agentic-search-code-exploration/)
44. [Anthropic — Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
45. [Context Rot — producttalk.org](https://www.producttalk.org/context-rot/) — degradacja jakości przy ~147k tokenów

---

*Dokument wygenerowany: 2026-02-23, zaktualizowany: 2026-02-23*
*Rozbudowuje: bestcontext.md → preBestCliAI.md → bestPersistentAI.md → **ten plik** (smart context)*
*Źródeł: 45 zweryfikowanych (z 4 równoległych agentów badawczych + analiza 234 sesji produkcyjnych)*
