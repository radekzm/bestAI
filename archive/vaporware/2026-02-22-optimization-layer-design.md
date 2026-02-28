# Design: Automatyczna optymalizacja zadań CC CLI

**Data**: 2026-02-22
**Status**: Zatwierdzony
**Plik docelowy**: `preBestCliAI.md` (rozdział 16)

## Problem

Optymalizacja kodu w pracy z AI CLI agentem jest domyślnie opt-in — programista musi pamiętać o stosowaniu dobrych praktyk. To prowadzi do niespójnej jakości kodu.

## Rozwiązanie

Wbudowanie reguł optymalizacji w CLAUDE.md jako "optimization layer", który działa na KAŻDYM zapytaniu automatycznie.

## Decyzje

1. **Podejście A wybrane**: Nowy rozdział 17 (przesunięty na 16, Źródła → 17)
2. **Odrzucone**: Rozproszenie po istniejących rozdziałach (B), Quick Start + rozdział (C)
3. **Uzasadnienie**: Czysta struktura, nie burzy istniejącego layoutu, łatwy do znalezienia

## Zawartość rozdziału

- Koncepcja "optimization by default"
- Gotowy szablon CLAUDE.md (pre/during/post checklist)
- Hierarchia optymalizacji (3 poziomy: global → projekt → katalog)
- Reguły per język (.claude/rules/ z glob scoping): Ruby, TypeScript, Python
- Wzorce kodu: early returns, batchowanie I/O, struktury danych
- Hooks jako enforcement vs CLAUDE.md jako guidance

## Metryki

- Dodano 224 linii do preBestCliAI.md (720 → 944)
- 6 podsekcji w nowym rozdziale
- 3 przykłady reguł per-język
- 1 gotowy szablon do skopiowania
