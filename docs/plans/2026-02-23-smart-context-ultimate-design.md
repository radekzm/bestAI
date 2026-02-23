# Design: Smart Context + Ultimate Guide

**Data**: 2026-02-23
**Status**: Zaimplementowany
**Pliki docelowe**: `bestSmartContext.md`, `bestUltimateGuide.md`

## Problem

Istniejące wytyczne (bestcontext → preBestCliAI → bestPersistentAI) nie adresują:
- Inteligentnego ładowania kontekstu (semantic search, vector DB)
- Preprocessingu promptów przed wykonaniem
- Problemu "różne słowa, ta sama koncepcja"
- Analizy historii sesji
- Observational Memory (nowy wzorzec 2026)

## Badania przeprowadzone

1. **Analiza repozytorium bestAI** — 5 istniejących plików, identyfikacja braków
2. **Analiza historii sesji** — ~150 sesji na task.nuconic.com, wzorce użycia
3. **Research vector DB** — Pinecone, Chroma, pgvector, LanceDB, FAISS
4. **Research Observational Memory** — Mastra Observer+Reflector, 94.87% LongMemEval
5. **Research Context7** — semantic docs on-demand, 4-krokowy workflow
6. **Research hooks** — UserPromptSubmit stdout injection (kluczowe odkrycie)
7. **Research prompt preprocessing** — 3 podejścia (grep/subagent/vectorDB)
8. **Research RAG → Context Engine** — ewolucja 2026, semantic layers

## Nowe pliki

### bestSmartContext.md (1185 linii)
- Semantic Context Router (vector DB + hybrid search)
- Prompt Preprocessor (3 podejścia: grep/subagent/vectorDB)
- Observational Memory (Observer+Reflector, L4)
- Session Intelligence (ekstrakcja wzorców z JSONL)
- Gotowa implementacja krok po kroku (3 poziomy)
- Walidacja na realnym projekcie Nuconic

### bestUltimateGuide.md (819 linii)
- Skonsolidowane best-of-all z 4 dokumentów + nowe badania
- "Skopiuj i wdróż" — 3 tiery (15/30/60 min)
- 28 zweryfikowanych źródeł
- Checklist wdrożenia

## Źródła badań

- 4 równoległych agentów badawczych (vector DB, preprocessing, session history, weak points)
- 6 web searches (Pinecone, Context7, Mastra, hooks, RAG, CLI)
- Analiza 150 sesji Claude Code na serwerze produkcyjnym
- Dokumentacja oficjalna Claude Code (hooks, subagents, memory)

## Metryki

- Łącznie: 5,011 linii w 6 plikach MD + 74 linie design docs
- Nowe pliki: 2,004 linii (bestSmartContext + bestUltimateGuide)
- Źródeł: 28 zweryfikowanych (żadne zmyślone)
- Czas badań: ~30 min deep research + 4 równoległych agentów
