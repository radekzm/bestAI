# Module 11: Prompt Caching Playbook

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

## Best Practices

1. **Audit your prefix monthly**: check what's before the first dynamic content
2. **Move timestamps to end**: don't bust cache with date stamps at the top
3. **Use `context-index.md` as routing table**: it changes less often than full file contents
4. **Monitor `cached_tokens` trend**: declining cache rate means something destabilized the prefix

---

*See [10-context-os](10-context-os.md) for tier architecture, [00-fundamentals](00-fundamentals.md) for token budgets.*
