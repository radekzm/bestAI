# Changelog

## v5.0.0 (2026-02-27)

### Added
- **Compliance measurement** (`compliance.sh`): Automated reporting from hook events with `--json` and `--since` flags
- **Hook composition framework**: `hooks/manifest.json` declares dependencies, conflicts, priorities, latency budgets; `tools/hook-lint.sh` validates
- **Cross-tool rule generation** (`tools/generate-rules.sh`): Export bestAI rules to `.cursorrules`, `.windsurfrules`, `codex.md`
- **Observability dashboard** (`stats.sh`): Hook latency tracking with `elapsed_ms`, per-hook avg/max/count stats
- **WAL logging** (`hooks/wal-logger.sh`): Write-ahead log for destructive actions
- **Backup enforcement** (`hooks/backup-enforcement.sh`): Require validated backup manifest before deploy/migrate
- **npm distribution**: `npx bestai setup`, `npx bestai doctor`, `npx bestai stats`
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
