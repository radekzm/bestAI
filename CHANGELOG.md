# Changelog

## v7.0.1 (2026-02-28)

### Fixed
- Normalize `package.json` bin path from `./bin/bestai.js` to `bin/bestai.js` to remove npm publish auto-correction warning.

## v7.0.0 (2026-02-27)

### Added
- **Multi-Vendor Swarm architecture**: Heterogeneous agent orchestration across Claude Code, Gemini CLI, and OpenAI Codex with shared GPS context
- **Swarm dispatch** (`tools/swarm-dispatch.sh`): Role-based task routing to vendor-specific agents (Architect→Claude, Investigator→Gemini, Tester→Codex)
- **Budget monitor** (`tools/budget-monitor.sh`): Token/cost tracking across multi-vendor swarm sessions
- **Blueprint template** (`templates/blueprint-multivendor.md`): Multi-vendor task assignment blueprint with context rules
- **CLI swarm command**: `npx @radekzm/bestai@latest swarm` for orchestrating multi-vendor sessions

### Fixed
- **CRITICAL: `compliance.sh` completely broken** — was reading `"type":"BLOCK"` but hooks write `"action":"BLOCK"`; was reading wrong log path. Complete rewrite with correct field names and `~/.cache/bestai/events.jsonl` path
- **`project_hash()` inconsistency** — 5 duplicate implementations producing different hashes. Unified to canonical `_bestai_project_hash()` in `hook-event.sh` using `printf '%s'` (no trailing newline)
- **Stale cross-references** in `02-operations.md` pointing to pre-consolidation module files
- **Test numbering collisions** — tests 15/18/19 renumbered to avoid conflicts
- **Version references** unified to v7.0 across CLAUDE.md, templates, AGENTS.md

### Changed
- **Circuit-breaker gate** (`hooks/circuit-breaker-gate.sh`): Line-based state files, HALF-OPEN auto-transition, cooldown tracking, legacy JSON fallback
- **Hook lint** (`tools/hook-lint.sh`): Dual-mode operation (repo vs installed project), improved manifest parsing
- **Module numbering**: Normalized from legacy 00/04/05/06/07… to hierarchical 01-A…H, 02-A…C, 03-A…E scheme
- **Frozen file messages**: Now include remediation hints ("remove entry from frozen-fragments.md")
- **Reflector.sh**: Added to `manifest.json` — was working but missing from the manifest

### Security
- **Symlink detection** in `check-frozen.sh`: Resolves symlinks before path matching to prevent bypass
- **Interpreter script scanning**: Detects `python script.py` / `ruby script.rb` invocations that target frozen files

## v6.0.0 (2026-02-27)

### Added
- **Professional README overhaul**: Architecture diagrams, feature matrix, ecosystem positioning
- **Enhanced circuit-breaker gate**: Line-based state tracking, HALF-OPEN transitions

### Changed
- **README**: Complete rewrite with modern documentation structure and visual hierarchy
- **AGENTS.md**: Updated hook documentation and compatibility notes
- **Migration guide**: Expanded with v6.0 upgrade path

## v5.0.0 (2026-02-27)

### Added
- **Compliance measurement** (`compliance.sh`): Automated reporting from hook events with `--json` and `--since` flags
- **Hook composition framework**: `hooks/manifest.json` declares dependencies, conflicts, priorities, latency budgets; `tools/hook-lint.sh` validates
- **Cross-tool rule generation** (`tools/generate-rules.sh`): Export bestAI rules to `.cursorrules`, `.windsurfrules`, `codex.md`
- **Observability dashboard** (`stats.sh`): Hook latency tracking with `elapsed_ms`, per-hook avg/max/count stats
- **WAL logging** (`hooks/wal-logger.sh`): Write-ahead log for destructive actions
- **Backup enforcement** (`hooks/backup-enforcement.sh`): Require validated backup manifest before deploy/migrate
- **npm distribution**: `npx @radekzm/bestai@latest setup`, `npx @radekzm/bestai@latest doctor`, `npx @radekzm/bestai@latest stats`
- **CI integration**: Hook composition lint step in `.github/workflows/ci.yml`
- **Template versioning**: `<!-- bestai-template: name v5.0 -->` headers + doctor.sh version checking
- **Maturity labels**: Stable (tested, has hooks+tests) vs Preview (documented, partial implementation)

### Security
- Extended Bash bypass detection: heredoc (`<<`), `exec`, interpreter invocations (`python -c`, `ruby -e`, `node -e`), `xargs`
- UserPromptSubmit injection threat model documented in Module 01
- Nuconic 6% compliance methodology with limitations and confidence intervals

### Changed
- **Memory compiler scoring**: Capped `usage_count` at 20, gradual age penalty replacing binary -5
- **Hook event logging**: Nanosecond-precision timing with `elapsed_ms` field in all events
- **`jq -r` → `jq -c`** in JSONL pipelines to preserve one-object-per-line format
- **`grep` pipefail safety**: All `grep | wc -l` patterns replaced with `grep -c ... || echo 0`

### Fixed
- `compliance.sh` triple bug: pipefail+grep exit code, jq multiline output, post-filter empty check
- `generate-rules.sh` crash when `CLAUDE.md` lacks stack/tech/framework keywords
- Hook latency incorrectly reported as 0ms on systems without nanosecond `date`

## v4.0.0

### Added
- Global Project State (GPS) via `.bestai/GPS.json`
- Distributed Agent Orchestration (Developer, Reviewer, Tester roles)
- RAG-Native Context with sqlite-vec integration
- Invisible Limit hierarchical summarization for T3 context
- Project Blueprints for complex stacks
- Circuit Breaker pattern (attempt tracking + HARD STOP)
- Memory Weight & Source (`[USER]`/`[AUTO]` tags)

## v3.0.0

### Changed
- Consolidated legacy guidelines into modular architecture (01-core, 02-operations, 03-advanced)
- Progressive Disclosure pattern (CLAUDE.md → Skills → Rules → Hooks)
