# Scenario 04: Observational Memory

## Category: observational

## Tasks

### 04a: Observer interval gating
- **Setup**: session counter = 3, interval = 5
- **Expected**: Observer skips (no observations written)
- **Pass criteria**: observations.md not created/modified

### 04b: Observer runs at interval
- **Setup**: session counter = 5, interval = 5, session-log with 10 entries
- **Expected**: observations.md created with compressed entries
- **Pass criteria**: File exists with session header

### 04c: Observer fallback (no Haiku)
- **Setup**: claude CLI unavailable
- **Expected**: Raw keyword extraction instead of Haiku compression
- **Pass criteria**: Observations written, contain key terms from log

### 04d: Reflector no-op without Haiku
- **Setup**: claude CLI unavailable
- **Expected**: Graceful exit, no file modifications
- **Pass criteria**: exit 0, existing files unchanged

## Measurement
- Compression ratio: Haiku output / raw input size
- Key information retention: % of decisions/errors preserved
