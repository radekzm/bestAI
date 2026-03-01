# Changelog

## Unreleased

### Fixed
- CLI now supports `--help` and `--version`.
- Restored command mappings in `bin/bestai.js` for:
  - `generate-rules`
  - `swarm-lock`
  - `shared-context-merge`
- Added explicit runtime error for orchestrator commands when `orchestrator/dist` is missing.

### Tests
- Added CLI regression checks for:
  - `bestai --help`
  - `bestai swarm-lock --help`
  - required command mapping contract in `bin/bestai.js`

### Docs
- README npm badge now tracks real npm version dynamically.
- README now documents orchestrator build prerequisite for experimental commands.

## v1.0.0 (2026-02-28) — "The Honest Reset"

### Breaking Changes
- **Version reset from v14.1.0 to v1.0.0** — Previous version numbers were inflated.
  All features from v5.0-v7.1 are preserved. Features from v8.0-v14.1.0 that were
  aspirational (Conductor, Guardian, Nexus, Rust core) have been moved to archive/.
- Removed CLI commands at reset point: conductor, retro-onboard, guardian, nexus, serve-dashboard
- Removed Rust core skeleton (core/) — will return when real implementation begins

### What's Included (Stable)
- 21 deterministic enforcement hooks (PreToolUse, PostToolUse, etc.)
- 5-tier Context OS with memory GC
- Circuit breaker with gate integration
- Smart Context v1 (keyword/trigram) and v2 (LLM-scored)
- Session persistence (rehydrate/sync-state)
- JSONL event logging + compliance reporting
- Hook composition framework (manifest.json + lint)
- Multi-vendor dispatch (Preview — manual routing)
- GPS shared state (Preview — limited multi-agent testing)

### Archived (moved to archive/vaporware/)
- Syndicate Conductor (tools/conductor.py) — mock implementation
- Autonomous Guardian (tools/guardian.py) — test stub generator only
- Human-AI Nexus (tools/nexus.py) — logging only
- Rust core (core/) — skeleton with no implementation
- Living Swarm Demo (tools/v10-demo.py) — staged output
- Retro-onboard (tools/retro-onboard.py) — regex heuristics, unvalidated
- Dashboard generator (tools/dashboard-gen.py) — broken HTML

## Previous History

For changelog entries v5.0-v7.1 see archive/CHANGELOG-legacy.md
