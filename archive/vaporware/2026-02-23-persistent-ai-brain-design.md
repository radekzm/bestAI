# Design: Persistent AI Brain — System trwałej pamięci agenta

**Data**: 2026-02-23
**Status**: Zatwierdzony
**Plik docelowy**: `bestPersistentAI.md`

## Problem

Agent AI CLI zapomina ustalenia po `/new`/`/clear`, traktuje swoje domysły jak fakty użytkownika, i "poprawia" działający kod.

## 3 systemy rozwiązujące problem

### 1. Auto-Persistence (3 warstwy)
- L1: Session Memory (wbudowane, zero-config)
- L2: Auto Memory (MEMORY.md + topic files)
- L3: Stop Hook Pipeline (opcjonalny, dla zaawansowanych)

### 2. Weight & Source (2 tagi)
- `[USER]` = instrukcja użytkownika, wysoka waga, chroniona
- `[AUTO]` = auto-odkrycie, niższa waga, podlega rewizji
- Reguły eskalacji: zmiana [USER] wymaga pytania usera

### 3. Fragment Freeze (3 stany)
- DRAFT → REVIEWED → FROZEN
- Hook PreToolUse blokuje edycję FROZEN plików
- Odmrożenie tylko na explicit żądanie usera

## Decyzje projektowe

- **Podejście A wybrane**: Jeden plik-manifest z 3 systemami
- **Uniwersalny** (nie specyficzny pod Nuconic)
- Gotowe szablony CLAUDE.md, hooks, skrypty do skopiowania

## Źródła researchu

- Oficjalna dokumentacja Claude Code (memory, hooks)
- 7 pluginów community (claude-memory, claude-mem, auto-memory, etc.)
- Session Memory API documentation
- 5 artykułów o persistence patterns
