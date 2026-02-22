# Best Context Engineering Guidelines for AI CLI Agents

> Kompletny przewodnik optymalizacji okna kontekstowego dla agentów AI CLI.
> Opracowano na podstawie badań GitHub, oficjalnej dokumentacji i praktyk community (stan: luty 2026).

---

## Spis treści

1. [Fundamenty — dlaczego kontekst to kluczowy zasób](#1-fundamenty--dlaczego-kontekst-to-kluczowy-zasób)
2. [Architektura plików kontekstowych](#2-architektura-plików-kontekstowych)
3. [CLAUDE.md — optymalizacja dla Claude Code](#3-claudemd--optymalizacja-dla-claude-code)
4. [AGENTS.md — standard otwarty (OpenAI / multi-tool)](#4-agentsmd--standard-otwarty-openai--multi-tool)
5. [Pliki kontekstowe innych narzędzi](#5-pliki-kontekstowe-innych-narzędzi)
6. [Zarządzanie sesją i kompakcja](#6-zarządzanie-sesją-i-kompakcja)
7. [Wzorzec Research → Plan → Implement](#7-wzorzec-research--plan--implement)
8. [Subagenci — izolacja kontekstu](#8-subagenci--izolacja-kontekstu)
9. [CLI vs MCP — efektywność tokenowa](#9-cli-vs-mcp--efektywność-tokenowa)
10. [Co zjada kontekst i jak temu zapobiegać](#10-co-zjada-kontekst-i-jak-temu-zapobiegać)
11. [Techniki redukcji tokenów — konkretne wyniki](#11-techniki-redukcji-tokenów--konkretne-wyniki)
12. [Skills, Rules, Hooks — progressive disclosure](#12-skills-rules-hooks--progressive-disclosure)
13. [Anti-patterns — czego unikać](#13-anti-patterns--czego-unikać)
14. [Wzorce pracy równoległej](#14-wzorce-pracy-równoległej)
15. [Nowości i trendy 2026](#15-nowości-i-trendy-2026)
16. [Źródła](#16-źródła)

---

## 1. Fundamenty — dlaczego kontekst to kluczowy zasób

### Definicja context engineering

> "Context engineering is curating what the model sees so that you get a better result."
> — Martin Fowler, 2026

Context engineering to dyscyplina zarządzania oknem kontekstowym LLM, obejmująca kurację WSZYSTKICH informacji wchodzących do modelu: system prompts, definicje narzędzi, pobrane dokumenty, historia wiadomości i wyniki narzędzi.

### Dlaczego to krytyczne

- **Okno kontekstowe to jedyny kontrolowalny zasób** wpływający na jakość odpowiedzi AI.
- **Wydajność LLM degraduje się** w miarę zapełniania kontekstu — modele potrzebują "pamięci roboczej" do rozumowania.
- **Efekt "lost-in-the-middle"** — modele wykazują U-kształtną krzywą uwagi: najlepiej pamiętają początek i koniec kontekstu, gorzej środek.
- **Attention scarcity** — wraz ze wzrostem kontekstu modele mają coraz mniej zasobów uwagi na token.

### Kluczowa metryka

Claude Code uruchamia teraz auto-kompakcję przy **~64-75% zapełnienia** (wcześniej 90%+). To paradoksalnie **wydłuża** produktywne sesje, bo każda interakcja zachowuje wyższą jakość rozumowania.

Przy 200k oknie kontekstowym, zatrzymanie przy 75% zostawia ~50,000 tokenów wolnych na procesy rozumowania.

### Hierarchia jakości kontekstu

1. **Poprawność** (false information = najgorzej)
2. **Kompletność** (brakujące informacje)
3. **Rozmiar** (nadmiar szumu)

---

## 2. Architektura plików kontekstowych

### Mapa plików kontekstowych per narzędzie

| Plik | Narzędzie | Ładowanie | Cel |
|------|-----------|-----------|-----|
| `CLAUDE.md` | Claude Code | Zawsze | Konwencje projektu |
| `CLAUDE.local.md` | Claude Code | Zawsze (nie w git) | Prywatne ustawienia |
| `~/.claude/CLAUDE.md` | Claude Code | Zawsze (globalnie) | Globalne preferencje |
| `.claude/skills/*.md` | Claude Code | On-demand (LLM decyduje) | Specjalistyczna wiedza |
| `.claude/rules/*.md` | Claude Code | Warunkowe (ścieżka/glob) | Reguły per typ pliku |
| `.claude/agents/*.md` | Claude Code | Na żądanie | Izolowane zadania subagentów |
| `AGENTS.md` | OpenAI/Sourcegraph/Amp | Zawsze | Standard otwarty multi-tool |
| `.cursor/rules/*.md` | Cursor | Warunkowe (path scope) | Reguły IDE |
| `.github/copilot-instructions.md` | GitHub Copilot | Zawsze | Instrukcje Copilot |
| `.github/instructions/**/*.instructions.md` | GitHub Copilot | Warunkowe (applyTo) | Scoped instrukcje |
| `.continuerules` | Continue | Zawsze | Reguły surowe |
| `.continue/rules/` | Continue | Warunkowe | Structured rules |
| `.aiassistant/rules/` | JetBrains AI | Zawsze | Reguły projektu |
| `.junie/guidelines.md` | JetBrains Junie | Zawsze | Wytyczne agenta |
| `llms.txt` | Uniwersalny (propozycja) | Na żądanie | LLM-friendly metadata |

### Zasada hierarchii

Pliki kontekstowe działają kaskadowo:
- **Global** (`~/.claude/CLAUDE.md`) → bazowe reguły dla wszystkich projektów
- **Root** (`./CLAUDE.md`) → reguły projektu, współdzielone przez team
- **Podkatalogi** (`src/api/CLAUDE.md`) → reguły specyficzne dla modułu
- **Local** (`CLAUDE.local.md`) → prywatne, nie w git

Pliki z głębszych katalogów nadpisują konflikty z wyższych poziomów.

### Kto decyduje o załadowaniu kontekstu

| Kto decyduje | Metoda | Przykład | Trade-off |
|-------------|--------|---------|-----------|
| **LLM** | Autonomiczny wybór | Skills | Niedeterministyczne, ale automatyczne |
| **Człowiek** | Manualne wywołanie | Slash commands | Pełna kontrola, mniej automatyzacji |
| **Software** | Deterministyczne triggery | Hooks | Przewidywalne, task-specific |

---

## 3. CLAUDE.md — optymalizacja dla Claude Code

### Zasady złote

| Reguła | Szczegóły |
|--------|-----------|
| **Max 150 linii** | Dłuższe pliki → Claude ignoruje instrukcje (reguły gubią się w szumie) |
| **Trigger tables** zamiast narracji | Zamiana opisów na tabelę "kiedy aktywować" = **70% redukcji** rozmiaru |
| **Lazy loading** | CLAUDE.md = minimalne triggery; szczegóły ładowane on-demand przez Skills |
| **Test za każdą linią** | "Czy usunięcie tej linii spowoduje błędy Claude?" → jeśli nie, wytnij |
| **Emphasis** | `IMPORTANT`, `YOU MUST`, bold → zwiększa adherencję do krytycznych reguł |
| **Commit do git** | Zespół iteruje wspólnie; traktuj jak kod |

### Co ZAWSZE umieszczać

- Komendy bash, których Claude nie odgadnie sam
- Reguły stylu kodu RÓŻNIĄCE się od domyślnych
- Instrukcje testowania i preferowane runnery
- Etykieta repo (nazwy branchy, konwencje PR)
- Decyzje architektoniczne specyficzne dla projektu
- Dziwactwa środowiska deweloperskiego (env vars, porty, hasła)
- Typowe pułapki i nieintuicyjne zachowania

### Czego NIGDY nie umieszczać

- Rzeczy, które Claude odgadnie z kodu (oczywistości)
- Standardowe konwencje języka (Claude je zna)
- Szczegółowa dokumentacja API (linkuj zamiast kopiować)
- Informacje często się zmieniające
- Długie wyjaśnienia i tutoriale
- Opisy plik-po-pliku (Claude czyta sam)
- Oczywistości typu "pisz czysty kod"

### Importy przez `@`

```markdown
# CLAUDE.md
See @README.md for project overview and @package.json for available npm commands.

# Additional Instructions
- Git workflow: @docs/git-instructions.md
- Personal overrides: @~/.claude/my-project-instructions.md
```

### Inicjalizacja

Użyj `/init` — analizuje codebase, wykrywa build systems, test frameworks, code patterns. Daje solidną bazę do refinementu.

### Diagnostyka skuteczności

- Jeśli Claude powtarza błąd mimo reguły → CLAUDE.md za długi, reguła ginie
- Jeśli Claude pyta o coś opisanego → sformułowanie niejednoznaczne
- Traktuj jak kod: review gdy coś idzie nie tak, przycinaj regularnie

---

## 4. AGENTS.md — standard otwarty (OpenAI / multi-tool)

### Specyfikacja

AGENTS.md to otwarty format wytycznych dla agentów kodujących, adoptowany przez:
- OpenAI Codex CLI
- Sourcegraph Amp
- Inne narzędzia (rosnąca adopcja)

### Odkrywanie i hierarchia

- Pliki zbierane od bieżącego katalogu w górę (do `$HOME`)
- `$HOME/.config/AGENTS.md` zawsze dołączany
- Pliki z podkatalogów dołączane gdy agent czyta pliki z danego subtree
- Głębsze pliki mają priorytet przy konfliktach
- Bezpośrednie instrukcje użytkownika/systemu nadpisują AGENTS.md

### Best practices (community)

> "Najskuteczniejsze pliki AGENTS.md zaczynają od KOMEND, nie wyjaśnień.
> Setup commands first, testing second, deployment third, debugging last."

### Sourcegraph Amp — zaawansowane scoping

```markdown
# AGENTS.md
@doc/style.md
@specs/**/*.md
```

YAML front matter z polem `globs` stosuje wytyczne warunkowo:
```yaml
---
globs: ['**/*.ts', '**/*.tsx']
---
# TypeScript Conventions
- Use strict mode...
```

### OpenAI Codex CLI — limity

```toml
# config.toml
project_doc_max_bytes = 32768  # domyślnie
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
```

Łączne docs projektowe ograniczone do **32 KiB** — dziel na podkatalogi lub zwiększ limit.

---

## 5. Pliki kontekstowe innych narzędzi

### Cursor IDE

- Legacy `.cursorrules` → nowy system: `.cursor/rules/*.md`
- Każda reguła to osobny plik z path-pattern scoping
- User Rules (globalne, osobiste) vs. Project Rules (team-shared)
- MCP: `.cursor/mcp.json` (projekt) lub `~/.cursor/mcp.json` (globalny)

### GitHub Copilot

- Główny: `.github/copilot-instructions.md`
- Scoped: `.github/instructions/**/*.instructions.md` z YAML frontmatter:
  ```yaml
  ---
  applyTo: "src/api/**/*.ts"
  ---
  ```
- Setup workflow: `.github/workflows/copilot-setup-steps.yml` (pre-instalacja zależności)
- Instrukcje powinny być "krótkie, samodzielne stwierdzenia"

### Continue (IDE Extension)

- YAML-based assistants and blocks
- `.continue/` z podfolderami: `/rules`, `/models`, `/prompts`, `/context`, `/docs`, `/data`, `/mcpServers`
- `.continuerules` — surowy tekst traktowany jako reguły

### JetBrains AI Assistant

- `.aiassistant/rules/*.md` — markdown rules
- `.noai` w root → wyłącza AI kompletnie
- `.aiignore` — ogranicza dostęp do plików (składnia jak `.gitignore`)

### JetBrains Junie

- `.junie/guidelines.md` — wersjonowane wytyczne
- Auto-generowanie z analizy projektu
- `.junie/mcp.json` — konfiguracja MCP serwerów

### llms.txt (propozycja standardu)

- Markdown na root strony (obok robots.txt)
- Krótkie tło + linki do szczegółowych stron markdown
- Strony dostarczają czyste wersje `.md` przez appended extension

---

## 6. Zarządzanie sesją i kompakcja

### Komendy Claude Code

| Komenda | Działanie |
|---------|-----------|
| `/clear` | Reset kontekstu — między niepowiązanymi zadaniami |
| `/compact <instrukcje>` | Ręczna kompakcja z ukierunkowanym zachowaniem |
| `/compact Focus on the API changes` | Zachowaj zmiany API, skompresuj resztę |
| `/context` | Sprawdź aktualny stan kontekstu |
| `/cost` | Sprawdź zużycie tokenów |
| `/rewind` lub `Esc+Esc` | Cofnij do checkpointu (konwersacja, kod, lub oba) |
| `Esc` | Przerwij bieżącą akcję (kontekst zachowany) |

### Strategia kompakcji

| Strategia | Opis |
|-----------|------|
| `/clear` między zadaniami | Obowiązkowe przy zmianie tematu |
| Kompakcja przy **50%** | Nie czekaj na auto-kompakcję (~75%) |
| Commit po każdym subtasku | Checkpoint = bezpieczeństwo + czysty kontekst |
| **Max 2 korekty** | Po 2 nieudanych poprawkach → `/clear` + lepszy prompt |
| Resumable sessions | `claude --continue` / `claude --resume` |
| Nazwane sesje | `/rename "oauth-migration"` → łatwiejsze wyszukiwanie |

### Konfiguracja kompakcji w CLAUDE.md

```markdown
When compacting, always preserve:
- Full list of modified files
- Test commands and their results
- Key architectural decisions made in this session
```

### Rewind z checkpointami

Każda akcja Claude tworzy checkpoint. Można przywrócić:
- Tylko konwersację
- Tylko kod
- Oba
- Podsumować od wybranego punktu (`Summarize from here`)

Checkpointy persystują między sesjami.

---

## 7. Wzorzec Research → Plan → Implement

### Trójfazowy workflow (Advanced Context Engineering)

#### Faza 1: Research (świeży kontekst)
- Zrozum strukturę codebase, zależności, flow informacji
- **Użyj subagenta** do eksploracji (nie zanieczyszczaj głównego kontekstu)
- Zapisz findings do pliku markdown

#### Faza 2: Plan (zapisz do pliku)
- Konkretne kroki, pliki do edycji, weryfikacja
- Użyj Plan Mode (`Ctrl+G` do edycji planu w edytorze)
- Review planu = **najwyższy leverage** — jeden błąd w planie kaskaduje na setki linii kodu

#### Faza 3: Implement (faza po fazie)
- Wykonuj plan krok po kroku
- Kompaktuj status po każdej weryfikacji
- Utrzymuj wykorzystanie kontekstu na **40-60%**

### Hierarchia leverage ludzkiego review

```
Research quality  ████████████████████  (1 błędne ustalenie → tysiące złych linii)
Plan correctness  ██████████████████    (1 błąd planu → setki złych linii)
Individual lines  ████                  (najniższy impact per review)
```

### Kiedy POMINĄĆ planowanie

- Scope jasny, zmiana mała (typo, log line, rename)
- Potrafisz opisać diff w jednym zdaniu
- Nie modyfikujesz wielu plików

---

## 8. Subagenci — izolacja kontekstu

### Dlaczego subagenci to game-changer

> "Subagenci to jedno z najpotężniejszych narzędzi, ponieważ kontekst jest fundamentalnym ograniczeniem."
> — Oficjalna dokumentacja Claude Code

Gdy Claude bada codebase, czyta DUŻO plików — wszystkie zużywają kontekst. Subagenci działają w **osobnych oknach kontekstowych** i raportują podsumowania.

### Przypadki użycia

| Użycie | Dlaczego subagent |
|--------|-------------------|
| Eksploracja kodu | Dziesiątki plików nie zanieczyszczają głównego kontekstu |
| Code review | Świeży kontekst = brak bias wobec własnego kodu |
| Szukanie/grep | Wyniki raportowane jako zwięzłe podsumowanie |
| Security review | Specjalizacja + izolacja |
| Weryfikacja po implementacji | Niezależna walidacja |

### Definicja subagenta

```markdown
# .claude/agents/security-reviewer.md
---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior security engineer. Review code for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Secrets or credentials in code
- Insecure data handling

Provide specific line references and suggested fixes.
```

### Wzorzec Writer/Reviewer

| Session A (Writer) | Session B (Reviewer) |
|--------------------|---------------------|
| `Implement a rate limiter` | — |
| — | `Review the rate limiter in @src/middleware/rateLimiter.ts` |
| `Address review feedback: [...]` | — |

---

## 9. CLI vs MCP — efektywność tokenowa

### Dane porównawcze (2026)

| Metoda | Kontekst dostępny na rozumowanie | Uwagi |
|--------|----------------------------------|-------|
| **CLI tools** (`gh`, `aws`, `kubectl`) | **~95%** | Pipeline w jednym strzale |
| **MCP server** (np. GitHub, 93 tools) | **~45%** | ~55,000 tokenów na definicje narzędzi |

### Dlaczego CLI wygrywa

1. **Modele AI trenowane na miliardach interakcji terminalowych** — `git`, `docker`, `kubectl` to głęboko wyuczone wzorce
2. **Brak schema** — CLI nie wymaga definicji JSON schema per narzędzie
3. **Composability** — pipeline `|` łączy narzędzia bez overhead
4. **Edge cases** — CLI obsługuje je proaktywnie w jednej sesji

### Rekomendacja: ile MCP serwerów

Community finding (682 upvotes):
> "Poszedłem na 15 MCP serwerów myśląc more = better. Używam na co dzień tylko 4."

**Rekomendowane MCP (max 3-4 dziennie)**:
- **Context7** — aktualna dokumentacja bibliotek (zapobiega hallucynacji outdated API)
- **Playwright** — automatyzacja przeglądarki
- **Claude in Chrome** — inspekcja DOM
- **Serena/DeepWiki** — opcjonalnie, do nawigacji symbolicznej / dokumentacji

**Wszystko inne** → preferuj CLI: `gh`, `aws`, `gcloud`, `sentry-cli`, `docker`, `kubectl`.

### Nauka nowego CLI przez agenta

```
Use 'foo-cli-tool --help' to learn about foo tool, then use it to solve A, B, C.
```

Claude jest skuteczny w uczeniu się CLI narzędzi on-the-fly.

---

## 10. Co zjada kontekst i jak temu zapobiegać

### Ranking "pożeraczy" kontekstu

| Operacja | Zużycie | Mitygacja |
|----------|---------|-----------|
| File searching/grep (wiele plików) | Bardzo wysokie | Deleguj do subagenta |
| Understanding code flow | Wysokie | Zapisz diagramy/podsumowania do pliku |
| Test/build logi | Wysokie | Filtruj do relevant sekcji |
| Duże JSON z narzędzi | Wysokie | Parsuj przed przekazaniem |
| MCP tool definitions | Stałe (per sesja) | Ogranicz liczbę serwerów |
| Hook injections | Kumulatywne | Eliminuj duplikaty |
| Korekty błędów | Kumulatywne | Max 2, potem `/clear` |
| Nieograniczona eksploracja | Niekontrolowane | Scope + subagent |

### Duplikaty hook injections — konkretny case

Problem: Hook `UserPromptSubmit` uruchamiał `bd ready` na KAŻDY prompt, zalewając kontekst powtarzającą się treścią.
Rozwiązanie: Przeniesienie do jednorazowego `SessionStart` → odzyskanie cennych tokenów.

---

## 11. Techniki redukcji tokenów — konkretne wyniki

### Udokumentowane rezultaty (John Lindquist, 2026)

| Technika | Przed | Po | Redukcja |
|----------|-------|----|----------|
| **Trigger tables** zamiast opisów skilli | 10,204 B | 2,997 B | **70%** |
| **Konsolidacja plików tożsamości** | 6,843 B | 1,252 B | **82%** |
| **Rules-only preferences** (bez przykładów) | 4,887 B | 1,084 B | **78%** |
| **Skill compression** (stubs) | 12 KB/skill | 800 B/skill | **93%** |
| **Archiwum skilli łącznie** | 244 KB | 17 KB | **93%** |
| **Tokeny początkowe sesji** | 7,584 | 3,434 | **54%** |

### Techniki szczegółowo

#### Trigger Tables (70% redukcji)
**Przed** — pełna dokumentacja każdego skilla w CLAUDE.md:
```markdown
## Code Review Skill
This skill performs comprehensive code review analyzing...
When activated it checks for security vulnerabilities...
It follows the OWASP top 10 guidelines and...
(100+ linii per skill)
```

**Po** — tabela triggerów:
```markdown
| Skill | Triggers |
|-------|----------|
| code-review | "review", "check code", after implementation |
| security | "security", "vulnerability", "OWASP" |
| deploy | "deploy", "release", "push to prod" |
```

#### Konsolidacja plików (82% redukcji)
Połączenie `identity.md` i `simulator-paradigm.md` w jeden dokument, eliminacja redundantnych wyjaśnień filozofii.

#### Rules-Only Preferences (78% redukcji)
Usunięcie przykładów i edge cases z preferencji. Szczegółowe scenariusze ładowane on-demand przez `Skill()`.

#### Registry-Driven Tool Metadata
Centralne `cm-tools.json` z indeksem triggerów i kategoriami narzędzi. Hooks routują inteligentnie bez replikowania opisów narzędzi w wielu plikach.

#### Zautomatyzowana kompresja skilli
Skrypt ekstrahujący minimalne stuby z pełnej dokumentacji (12KB → 800B per skill). Pełne protokoły dostępne przez `Skill()` calls.

### Filozofia

> **"Lazy loading, not removal"** — Claude potrzebuje świadomości triggerów i kategorii upfront, ale szczegółowe protokoły ładują się on-demand zamiast zużywać początkowy kontekst.

---

## 12. Skills, Rules, Hooks — progressive disclosure

### Porównanie mechanizmów

| Cecha | CLAUDE.md | Skills | Rules | Hooks | Subagents |
|-------|-----------|--------|-------|-------|-----------|
| Ładowanie | Zawsze | On-demand | Warunkowe | Deterministyczne | Na żądanie |
| Gwarancja wykonania | Nie (guidance) | Nie | Nie | **Tak** | Nie |
| Zużycie kontekstu | Stałe | Tylko gdy aktywne | Warunkowe | Minimalne | Osobne okno |
| Edytowalne przez team | Tak (git) | Tak (git) | Tak (git) | Tak | Tak |
| Kontrola | Człowiek + LLM | LLM | Software | Software | Człowiek + LLM |

### Skills — lazy-loaded specjalistyczna wiedza

```markdown
# .claude/skills/api-conventions/SKILL.md
---
name: api-conventions
description: REST API design conventions for our services
---
# API Conventions
- Use kebab-case for URL paths
- Use camelCase for JSON properties
- Always include pagination for list endpoints
```

Claude ładuje automatycznie gdy uzna za relevantne, lub przez `/skill-name`.

### Rules — warunkowe reguły per ścieżka

```markdown
# .claude/rules/typescript.md
---
globs: ["**/*.ts", "**/*.tsx"]
---
- Use strict TypeScript, no `any`
- Prefer interfaces over types for object shapes
```

Ładowane TYLKO gdy Claude pracuje z plikami pasującymi do glob.

### Hooks — deterministyczne gwarancje

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "command": "npx eslint --fix $FILE"
      }
    ]
  }
}
```

W przeciwieństwie do CLAUDE.md (advisory), hooks **gwarantują** wykonanie akcji.

### Wzorzec: Command + Skill + Subagent

```
Command (entry point)
  → Agent (orkiestruje workflow z preloaded skills)
    → Skill (domain-specific knowledge)
```

To layering umożliwia progressive disclosure i single execution contexts.

---

## 13. Anti-patterns — czego unikać

### 1. "Kitchen Sink Session"
**Objaw**: Zaczynasz od jednego zadania, pytasz o coś niepowiązanego, wracasz.
**Problem**: Kontekst pełen nieistotnych informacji.
**Fix**: `/clear` między niepowiązanymi zadaniami.

### 2. Korekcja w kółko
**Objaw**: Claude robi coś źle, korygujesz, nadal źle, korygujesz ponownie (3+).
**Problem**: Kontekst zanieczyszczony nieudanymi podejściami.
**Fix**: Po 2 nieudanych korektach → `/clear` + lepszy initial prompt z lekcjami.

### 3. Przeładowany CLAUDE.md
**Objaw**: >150 linii, Claude ignoruje połowę reguł.
**Problem**: Ważne reguły giną w szumie.
**Fix**: Bezlitośnie przycinaj. Przenieś do Skills/Rules co nie musi być zawsze.

### 4. Trust-then-verify gap
**Objaw**: Claude produkuje coś wyglądającego poprawnie, ale nie obsługującego edge cases.
**Problem**: Brak mechanizmu weryfikacji.
**Fix**: Zawsze dostarczaj testy, skrypty, screenshots. Nie shippuj bez weryfikacji.

### 5. Nieskończona eksploracja
**Objaw**: "Zbadaj jak to działa" bez scope'a → Claude czyta setki plików.
**Problem**: Kontekst zapełniony wynikami eksploracji.
**Fix**: Scope'uj wąsko LUB użyj subagenta.

### 6. Za dużo MCP serwerów
**Objaw**: 15 serwerów skonfigurowanych → same definicje narzędzi zjadają 50%+ kontekstu.
**Problem**: Tokeny na metadata zanim padnie pierwsze pytanie.
**Fix**: Max 3-4 aktywnych serwerów, resztę przez CLI.

### 7. Kopiowanie cudzych konfiguracji
**Objaw**: Skopiowany CLAUDE.md z innego projektu/osoby.
**Problem**: Kontekst odbiorcy ≠ kontekst autora. Ryzyko duplikacji/sprzeczności.
**Fix**: Buduj konfigurację iteracyjnie, testuj skuteczność.

### 8. "Vanilla CC is better"
**Objaw**: Over-engineering z wieloma agentami, skomplikowane orkiestracje.
**Problem**: Overhead > korzyść.
**Fix**: Prosty Claude Code bez zbędnych warstw = lepszy niż nadmiarowa automatyzacja.

---

## 14. Wzorce pracy równoległej

### Headless mode (`claude -p`)

```bash
# Jednorazowe zapytania
claude -p "Explain what this project does"

# Structured output
claude -p "List all API endpoints" --output-format json

# Streaming
claude -p "Analyze this log file" --output-format stream-json
```

### Fan-out — masowe operacje

```bash
# 1. Wygeneruj listę plików
claude -p "list all Python files needing migration" > files.txt

# 2. Przetwarzaj równolegle
for file in $(cat files.txt); do
  claude -p "Migrate $file from React to Vue. Return OK or FAIL." \
    --allowedTools "Edit,Bash(git commit *)" &
done
wait
```

### Writer/Reviewer pattern

Dwie sesje z osobnymi kontekstami:
- **Session A** implementuje
- **Session B** reviewuje (świeży kontekst = brak bias)

### Agent Teams

Zautomatyzowana koordynacja wielu sesji:
- Wspólne zadania
- Komunikacja między agentami
- Team lead orkiestruje

---

## 15. Nowości i trendy 2026

### Volt — Lossless Context Management
**Repo**: [voltropy/volt](https://github.com/voltropy/volt)
- Asynchroniczna kompresja kontekstu między turami (zero opóźnień)
- Immutable store — każda wiadomość zapisywana bezstratnie
- Zero forgetting — odzyskanie dowolnej wiadomości
- Outperforms frontier coding agents na long-context tasks

### Conductor (Gemini CLI)
**Źródło**: Google Developers Blog
- Context-driven development
- Automatyczna orkiestracja kontekstu
- Integracja z Gemini CLI

### GitHub Agents HQ
- Agenci AI wykonują zadania deweloperskie WEWNĄTRZ GitHub
- Kontekst przywiązany do pracy (nie stateless prompty)
- Zachowanie historii sesji i review workflows

### Agent Teams (Claude Code)
- Wieloagentowa koordynacja z team lead
- Wspólne zadania i messaging
- Izolowane worktrees per sesja

### Context7 MCP
- Aktualna dokumentacja bibliotek on-demand
- Zapobiega hallucynacji outdated APIs
- Minimalne zużycie kontekstu (ładowanie na żądanie)

### Trend: CLI > MCP
95% kontekstu wolne przy CLI vs 45% przy typowym MCP serverze. Modele trenowane na miliardach terminalowych interakcji — CLI to naturalny interfejs.

---

## 16. Źródła

### Repozytoria GitHub

1. [Claude Code Context Optimization: 54% reduction](https://gist.github.com/johnlindquist/849b813e76039a908d962b2f0923dc9a) — John Lindquist, konkretne techniki redukcji tokenów
2. [Advanced Context Engineering for Coding Agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents) — HumanLayer, wzorzec Research→Plan→Implement
3. [claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) — Shan Raisshan, community best practices
4. [claude-code-hub optimization guide](https://github.com/davidkimai/claude-code-hub/blob/main/optimization-guide.md) — David Kimai, optymalizacja CLAUDE.md
5. [everything-claude-code](https://github.com/affaan-m/everything-claude-code) — Affaan, kompletna kolekcja konfiguracji (hackathon winner)
6. [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — kurowana lista zasobów
7. [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering) — Murat Koylan, skille inżynierii kontekstu
8. [Volt — Lossless Context Management](https://github.com/voltropy/volt) — Voltropy, bezstratne zarządzanie kontekstem
9. [AI Coding Style Guides](https://github.com/lidangzzz/AI-Coding-Style-Guides) — wytyczne stylu kodowania dla agentów
10. [AI Agent Rule Files — 0xdevalias](https://gist.github.com/0xdevalias/f40bc5a6f84c4c5ad862e314894b2fa6) — przegląd plików kontekstowych across tools

### Artykuły i dokumentacja

11. [Best Practices for Claude Code — oficjalna dokumentacja](https://code.claude.com/docs/en/best-practices)
12. [Context Engineering for Coding Agents — Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)
13. [How Claude Code Got Better by Protecting Context](https://hyperdev.matsuoka.com/p/how-claude-code-got-better-by-protecting)
14. [Why CLI Tools Are Beating MCP for AI Agents](https://jannikreinhard.com/2026/02/22/why-cli-tools-are-beating-mcp-for-ai-agents/)
15. [Context Window Management Strategies — getmaxim.ai](https://www.getmaxim.ai/articles/context-window-management-strategies-for-long-context-ai-agents-and-chatbots/)
16. [AGENTS.md best practices — 0xfauzi](https://gist.github.com/0xfauzi/7c8f65572930a21efa62623557d83f6e)
17. [Agentic Coding Principles & Practices](https://agentic-coding.github.io/)
18. [Agent Design Patterns — rlancemartin](https://rlancemartin.github.io/2026/01/09/agent_design/)
19. [Conductor: Context-Driven Development — Google Developers Blog](https://developers.googleblog.com/conductor-introducing-context-driven-development-for-gemini-cli/)

---

*Dokument wygenerowany: 2026-02-22*
*Aktualizuj regularnie — ekosystem AI CLI agentów rozwija się dynamicznie.*
