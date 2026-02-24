# Scenario 02: Memory Lifecycle & GC

## Category: memory-compiler

## Tasks

### 02a: Session counter persistence
- **Setup**: Run memory-compiler 5 times
- **Expected**: .session-counter = 5
- **Pass criteria**: Counter increments correctly

### 02b: Context index generation
- **Setup**: 5 memory files with varying content
- **Expected**: context-index.md with scores and topic clusters
- **Pass criteria**: All files indexed, scores reflect content + usage

### 02c: 200-line MEMORY.md cap
- **Setup**: MEMORY.md with 250 lines
- **Expected**: Truncated to 200, overflow in memory-overflow.md
- **Pass criteria**: MEMORY.md <= 200 lines, overflow preserved

### 02d: Generational GC — old AUTO archived
- **Setup**: AUTO entry from 25 sessions ago, 1 use
- **Expected**: Entry moved to gc-archive.md
- **Pass criteria**: gc-archive.md contains the entry

### 02e: Generational GC — USER protected
- **Setup**: USER entry from 50 sessions ago, 0 uses
- **Expected**: Entry NOT archived
- **Pass criteria**: Entry remains in original file

## Measurement
- All assertions pass/fail
- GC correctness: no false positives (USER) or false negatives (stale AUTO)
