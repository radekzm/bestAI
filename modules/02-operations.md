# Module 02-A: Session Management & Context Lifecycle

> Use this module when managing sessions, dealing with compaction,
> or deciding when to use subagents and parallel workflows.

<!-- agents-md-compat -->

---

## Session Commands

| Command | Action |
|---------|--------|
| `/clear` | Context reset — between unrelated tasks |
| `/compact <instructions>` | Manual compaction with directed preservation |
| `/context` | Check current context state |
| `/cost` | Check token usage |
| `/rewind` or `Esc+Esc` | Revert to checkpoint (conversation, code, or both) |
| `Esc` | Interrupt current action (context preserved) |

## 6 Session Rules

| # | Rule | How |
|---|------|-----|
| 1 | **`/clear` between tasks** | Each new task = fresh context |
| 2 | **Max 3 batches** | After 3 failed approach batches → STOP + ROOT_CAUSE_TABLE + user escalation |
| 3 | **Commit after each subtask** | Checkpoint = safety + clean context |
| 4 | **Compact at 50%** | Don't wait for auto-compaction (75%) |
| 5 | **Subagent for exploration** | grep/search in subagent = clean main window |
| 6 | **Max 3-4 MCP servers** | Each MCP eats ~5-15% context on schema |

## Compaction Strategy

Configure in CLAUDE.md:
```markdown
When compacting, always preserve:
- Full list of modified files
- Test commands and their results
- Key architectural decisions made in this session
```

## Research → Plan → Implement Pattern

```
Phase 1: RESEARCH (subagent)     → save findings to file
Phase 2: PLAN (plan mode)        → concrete steps, files, verification
Phase 3: IMPLEMENT (step by step) → commit after each step
```

### Review Leverage Hierarchy

```
Research quality  ████████████████████  (1 wrong finding → thousands of bad lines)
Plan correctness  ██████████████████    (1 plan error → hundreds of bad lines)
Individual lines  ████                  (lowest impact per review)
```

### Skip Planning When
- Scope clear, change small (typo, log line, rename)
- You can describe the diff in one sentence
- Not modifying multiple files

## Subagents — Context Isolation

> "Subagents are one of the most powerful tools because context is the fundamental constraint."

Subagents operate in **separate context windows** and report summaries.

| Use Case | Why Subagent |
|----------|-------------|
| Code exploration | Dozens of files don't pollute main context |
| Code review | Fresh context = no bias toward own code |
| Search/grep | Results reported as concise summary |
| Security review | Specialization + isolation |

### Example Definition

```markdown
# .claude/agents/explorer.md
---
name: codebase-explorer
description: Explores codebase structure and returns summaries
tools: Read, Grep, Glob, Bash
model: haiku
---
Explore the codebase and return a concise summary of findings.
Do NOT include full file contents — only key observations.
```

## Parallel Work Patterns

### Headless Mode

```bash
claude -p "Explain what this project does"
claude -p "List all API endpoints" --output-format json
```

### Fan-out

```bash
for file in $(cat files.txt); do
  claude -p "Migrate $file to new API. Return OK or FAIL." \
    --allowedTools "Edit,Bash(git commit *)" &
done
wait
```

### Writer/Reviewer Pattern

Two sessions with separate contexts:
- **Session A** implements
- **Session B** reviews (fresh context = no bias)

## Anti-Patterns

| # | Problem | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Kitchen Sink Session | Mixed tasks in one session | `/clear` between tasks |
| 2 | Correction Loop | 3+ failed approach batches | Max 3 batches, then STOP + ROOT_CAUSE_TABLE |
| 3 | Overloaded CLAUDE.md | >100 lines, agent ignores | Trim, move to Skills/Rules |
| 4 | Trust-then-verify gap | Looks correct, fails edge cases | Always provide tests |
| 5 | Unbounded exploration | "Investigate how this works" without scope | Scope narrowly OR use subagent |
| 6 | Too many MCP servers | 15 servers = 50%+ context on schemas | Max 3-4, rest via CLI |
| 7 | Copying configs | Someone else's CLAUDE.md | Build iteratively, test effectiveness |
| 8 | Over-engineering | Complex orchestrations > benefit | Simple Claude Code > excessive automation |

---

*See [03-persistence](03-persistence.md) for memory systems, [05-cs-algorithms](05-cs-algorithms.md) for circuit breaker patterns.*
# Module 02-B: Operational Patterns — Discipline & Anti-Loop

> Use this module when you need structured operational discipline for AI agents.
> Patterns derived from AION-NEOVERSE Constitution v3 and production experience.

<!-- agents-md-compat -->

---

## REHYDRATE — Cold Start Recovery

When starting a new session or after `/clear`, the agent must recover context immediately.

### Pattern

```
SessionStart:
  1. Read memory index (max 8 lines with file pointers)
  2. Direct read only listed files (target: 4 files, zero globs)
     - Constitution / core rules
     - State_Of_System_Now
     - Checklist_Now
     - Avatar / role profile
  3. Confirm loaded context in one short status block
  → Deterministic bootstrap, no file discovery overhead.
```

### Implementation (SessionStart hook)

```bash
#!/bin/bash
# hooks/rehydrate.sh — minimal implementation (reads 2 core files)
# Extend with session-log.md and WAL reads for full REHYDRATE
MEMORY_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory"
WAL_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')"
[ ! -d "$MEMORY_DIR" ] && exit 0

echo "=== SESSION REHYDRATE ==="
# Step 1: MEMORY.md (always)
[ -f "$MEMORY_DIR/MEMORY.md" ] && head -50 "$MEMORY_DIR/MEMORY.md"
# Step 2: Frozen files (always)
[ -f "$MEMORY_DIR/frozen-fragments.md" ] && {
  echo "--- FROZEN FILES (do not edit) ---"
  grep -E '^\s*-\s*`' "$MEMORY_DIR/frozen-fragments.md" | head -10
}
# Step 3: Session log (optional — uncomment to enable)
# [ -f "$MEMORY_DIR/session-log.md" ] && tail -20 "$MEMORY_DIR/session-log.md"
# Step 4: WAL recovery (optional — uncomment to enable)
# [ -f "$WAL_DIR/wal.log" ] && { echo "--- WAL (last 10) ---"; tail -10 "$WAL_DIR/wal.log"; }
echo "=== END REHYDRATE ==="
exit 0
```

## Anti-Loop Escalation

### The Problem

Agent retries the same failing approach endlessly ("digital punding" — GH #6549). Data: 150 identical rails runner errors across 40 sessions.

### Pattern: 3 Batches → STOP → ROOT_CAUSE_TABLE

```
Batch 1: Execute task normally
  └─ Failure? → Minor adjustment, retry
Batch 2: Adjusted approach
  └─ Failure? → Different strategy
Batch 3: Alternative strategy
  └─ Failure? → HARD STOP

ROOT_CAUSE_TABLE:
| What I Tried          | Why It Failed           | What To Try Next       |
|-----------------------|-------------------------|------------------------|
| inline rails runner   | bash quoting breaks     | write to /tmp/script.rb|
| direct SQL query      | permission denied       | use rails console      |
| API call              | timeout at 30s          | increase timeout/batch |
```

**Agent must NEVER continue past 3 failed batches without user approval.**

## SYNC_STATE — End-of-Task Synchronization

After completing a task or before ending a session:

```
1. Update State (TOP-10 FACTS / TOP-5 PROOFS / TOP-3 BLOCKERS)
2. Update MEMORY.md + session-log.md
3. Replace `LAST SESSION DELTA` (5-10 lines max)
4. Move overflow evidence to `/docs/PROOFS/<AREA>_<YYYYMMDD>.md`
5. Commit if stable and report status
```

## Blocker Taxonomy (canonical names)

| Group | Canonical blockers |
|------|---------------------|
| DATA | `STALE_DATA`, `NEED_DATA` |
| TECH | `BUILD_ERROR`, `DEPLOY_FAIL`, `API_REJECT` |
| PRODUCT | `UX_UNCLEAR`, `SCOPE_CREEP`, `VALUE_UNPROVEN` |
| EXTERNAL | `BLOCKED_EXTERNAL` |
| BUSINESS | `PRICING_UNVALIDATED`, `MARKET_FIT_UNKNOWN` |

## Checklist-Driven Work

### Pattern

One active checklist at a time. Each item has:
- Clear scope (what files, what change)
- Verification method (how to test)
- NEXT GOAL clearly stated

```markdown
## Current Checklist

- [x] Fix authentication token expiry
- [x] Add tests for token refresh
- [ ] **NEXT: Deploy to staging** ← clearly marked
- [ ] Verify on staging
- [ ] Merge to main
```

### Rule: Scope Before Action

Before starting any task:
1. State the scope (which files, which changes)
2. State the verification (how to test success)
3. State the rollback plan (if it fails)

## CONF Scoring (Confidence)

**WARNING**: LLM self-assessed confidence is NOT calibrated. Use CONF as a communication signal, NOT as a reliable metric.

| CONF Range | Meaning | Action |
|------------|---------|--------|
| 0.9-1.0 | Very high confidence | Proceed, but verify |
| 0.7-0.9 | Good confidence | Proceed with extra testing |
| 0.5-0.7 | Moderate confidence | Present options to user |
| < 0.5 | Low confidence | **STOP — ask user for guidance** |

**Best practice**: Combine CONF with evidence. "CONF: 0.85 — tested with 3 cases" is useful. "CONF: 0.85" alone is not.

## DEVIL'S ADVOCATE Pattern

For critical decisions (architecture, data model, security):

```
1. Agent proposes solution
2. Agent MUST argue AGAINST own proposal (find 3 weaknesses)
3. Present both sides to user
4. User decides
```

This prevents confirmation bias and groupthink in agent teams.

## Operational Rules Summary

| Rule | From | Enforcement |
|------|------|-------------|
| REHYDRATE on session start | AION | SessionStart hook |
| Max 3 failed batches → STOP | AION | Circuit Breaker hook |
| SYNC_STATE at task end | AION | Stop hook / manual |
| 1 active checklist | AION | CLAUDE.md rule |
| Scope before action | Best practice | CLAUDE.md rule |
| CONF < 0.5 → ask user | AION | CLAUDE.md rule (advisory) |
| DEVIL'S ADVOCATE for critical | AION | CLAUDE.md rule (advisory) |
| [USER] never overridden | bestAI | CLAUDE.md rule + hook |

## Integration with CS Algorithms

| Pattern | CS Algorithm | Module |
|---------|-------------|--------|
| Anti-loop 3 batches | Circuit Breaker | [05-cs-algorithms](05-cs-algorithms.md) |
| REHYDRATE 4 files | Bootstrap/Cold Start | This module |
| SYNC_STATE commit | WAL checkpoint | [05-cs-algorithms](05-cs-algorithms.md) |
| CONF scoring | Feature Flags | [05-cs-algorithms](05-cs-algorithms.md) |
| DEVIL'S ADVOCATE | Adversarial validation | This module |

---

*See [04-enforcement](04-enforcement.md) for hook implementations, [05-cs-algorithms](05-cs-algorithms.md) for formal algorithms.*
# Module 02-C: Prompt Caching Playbook

> Use this module to optimize Claude API costs through prompt caching.
> Stable prefixes + predictable structure = lower costs and faster responses.

<!-- agents-md-compat -->

---

## How Prompt Caching Works

Claude caches the **prefix** of the prompt. If the next request starts with the same prefix, cached tokens are reused at reduced cost.

```
Request 1: [system prompt] [CLAUDE.md] [memory] [user message 1]
                    ↑ cached prefix ↑
Request 2: [system prompt] [CLAUDE.md] [memory] [user message 2]
                    ↑ cache HIT ↑         ↑ new computation
```

**Key metric**: `cached_tokens` — tokens reused from cache (visible in API response).

## Designing a Stable Prefix

### DO (cache-friendly)

1. **Put stable content first**: system prompt → CLAUDE.md → memory → dynamic content
2. **Keep CLAUDE.md structure consistent**: same sections, same order across sessions
3. **Use deterministic hook output**: rehydrate.sh always loads files in the same order
4. **Freeze rarely-changing content**: frozen-fragments.md entries are perfect cache candidates

### DON'T (cache busters)

1. **Timestamps at start**: `Updated: 2026-02-24T...` at top of CLAUDE.md busts cache on every call
2. **Random content in prefix**: session-specific data before stable content
3. **Reordering sections**: changing the order of CLAUDE.md sections between sessions
4. **Dynamic lists that change length**: variable-length lists in always-loaded content

## Prefix Design Template

```markdown
# CLAUDE.md (stable prefix — optimize for caching)

## Project [name]                    ← stable
- Stack: [stack]                     ← stable
- Test: [command]                    ← stable

## Rules                             ← stable
1. [rule 1]                          ← stable
2. [rule 2]                          ← stable

## Session Context                   ← dynamic (put LAST)
- Current task: ...                  ← changes each session
- Last modified: ...                 ← changes each session
```

## Measuring Cache Efficiency

### From API Logs

```bash
# Parse Claude Code JSONL logs for cache metrics
# Adjust path to your log directory
LOG_DIR="$HOME/.claude/projects/*/logs"

# Extract cached_tokens from response metadata
awk -F'"' '/cached_tokens/ {
    for(i=1;i<=NF;i++) {
        if($i=="cached_tokens") print $(i+2)
    }
}' "$LOG_DIR"/*.jsonl 2>/dev/null | \
awk '{sum+=$1; count++} END {
    if(count>0) printf "Avg cached tokens: %.0f (across %d requests)\n", sum/count, count
    else print "No cache data found"
}'
```

### Cache Hit Rate

```bash
# Estimate cache hit rate from token usage
awk -F'"' '
/input_tokens/ { input+=$(NF-1) }
/cached_tokens/ { cached+=$(NF-1) }
END {
    if(input>0) printf "Cache hit rate: %.1f%% (%d cached / %d input)\n",
        cached/input*100, cached, input
    else print "No data"
}' "$LOG_DIR"/*.jsonl 2>/dev/null
```

## Cost Impact

| Token Type | Cost (Sonnet 4) | Relative |
|------------|-----------------|----------|
| Input (uncached) | $3/M tokens | 1.0x |
| Input (cached) | $0.30/M tokens | 0.1x |
| Output | $15/M tokens | 5.0x |

**Example**: A 50k token stable prefix cached across 100 requests saves ~$14.85.

## Integration with Context OS

The 5-tier architecture (module 10) naturally supports caching:

| Tier | Cache Behavior |
|------|---------------|
| T0 (HOT) | Stable structure → high cache rate |
| T1 (WARM) | MEMORY.md index → medium cache rate (changes between sessions) |
| T2 (COOL) | Per-prompt routing → low cache rate (different each prompt) |
| T3 (COLD) | Never injected → no cache impact |
| T4 (FROZEN) | Immutable → perfect cache candidate |

## Provider-Specific Token Mapping

| Provider | Field | Meaning |
|----------|-------|---------|
| OpenAI | `usage.prompt_tokens_details.cached_tokens` | Input tokens served from cache |
| OpenAI | `usage.prompt_tokens`, `completion_tokens`, `total_tokens` | Input / output / total |
| Anthropic | `usage.cache_read_input_tokens` | Input tokens read from cache |
| Anthropic | `usage.cache_creation_input_tokens` | Tokens used to create cache entry |
| Anthropic | `usage.input_tokens`, `output_tokens` | Non-cached input / output |

## Normalized JSONL Format

Log each request in a JSONL file with consistent schema:

```json
{"timestamp":"...","provider":"openai","model":"gpt-5","run_id":"R-123","usage":{"prompt_tokens":3200,"completion_tokens":420,"total_tokens":3620,"prompt_tokens_details":{"cached_tokens":2400}}}
{"timestamp":"...","provider":"anthropic","model":"claude-sonnet-4-5","run_id":"R-123","usage":{"input_tokens":260,"output_tokens":390,"cache_read_input_tokens":2940,"cache_creation_input_tokens":0}}
```

Generate a report with:

```bash
bash evals/cache-usage-report.sh --input evals/data/cache-usage-sample.jsonl
```

## Trend Interpretation Thresholds

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Weighted cache hit ratio | >= 60% | 30-59% | < 30% |
| Cold large prompt rate | < 20% | 20-40% | > 40% |
| Cache key churn | < 30% unique keys | 30-60% | > 60% |

## Common Cache Busters

| Anti-pattern | Effect | Fix |
|---|---|---|
| Timestamp/UUID in stable prefix | Every call creates new cache key | Move to TAIL or logs |
| Reordering sections between runs | Low hit ratio despite similar content | Maintain fixed template |
| Overwriting full CLAUDE.md for small change | Permanent cache busting | Isolate changes to small topic files |
| Mixing session data with stable rules | Unpredictable hit rate | Separate HEAD/TAIL |

## Runbook: Sudden Cache Hit Ratio Drop

1. Compare last 24h vs previous 7 days (`weighted_hit_ratio`).
2. Check diffs in CLAUDE.md, modules, and preprocess hooks.
3. Detect cache key variability (`cache_key`, `prefix_hash`) if available.
4. Revert last change to HEAD or separate dynamic part to TAIL.
5. Confirm improvement over next 50+ requests.

## Best Practices

1. **Audit your prefix monthly**: check what's before the first dynamic content
2. **Move timestamps to end**: don't bust cache with date stamps at the top
3. **Use `context-index.md` as routing table**: it changes less often than full file contents
4. **Monitor `cached_tokens` trend**: declining cache rate means something destabilized the prefix
5. **Freeze stable instructions**: use frozen-fragments.md for perfect cache candidates
6. **Deterministic ordering**: fixed section order, no random IDs, no generated-at timestamps in cacheable blocks

---

*See [10-context-os](10-context-os.md) for tier architecture, [00-fundamentals](00-fundamentals.md) for token budgets.*
