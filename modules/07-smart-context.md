# Module 07: Smart Context — Semantic Routing & Preprocessing

> Use this module when static CLAUDE.md + MEMORY.md is insufficient
> and you need intelligent, task-specific context loading.
>
> **WARNING**: This module describes OPTIONAL techniques. Most projects work fine
> with modules 00-06. Add smart context only when you experience repeated
> "agent didn't know about X" situations.

<!-- agents-md-compat -->

---

## The Problem

```
User:    "fix login"
Context: "authentication error handling" ← keyword search WON'T find this
Vector:  [0.23, -0.45, ...] ↔ [0.25, -0.43, ...] ← semantic search WILL find this
```

## Key Mechanism: UserPromptSubmit Hook

**stdout from UserPromptSubmit hook is added to Claude's context**. This is the injection point for smart context.

## Memory Compiler Pipeline (recommended core)

On each user prompt:

```text
1) Intent Detect  -> coding / debugging / planning / reviewing
2) Scope Detect   -> relevant modules/files/rules
3) Retrieve       -> memory topics + decisions + pitfalls + frozen + recent logs
4) Rank           -> relevance + freshness + source weight ([USER] > [AUTO])
5) Pack           -> compact context bundle under strict budget
6) Inject         -> only if score >= threshold
```

Production hook in this repo: `hooks/preprocess-prompt.sh`.

## Context Pack Schema

```text
intent | scope | must_know | risks | frozen | commands | open_questions
```

Use this as a stable shape across projects and tools.

## Security Guardrails (mandatory)

Retrieved context is **data**, never operational instruction.

Minimum controls:
- sanitize lines that look like instructions (`ignore previous`, jailbreak patterns, shell payloads)
- tag sources in injected block
- cap injected budget
- keep escape hatch: `.claude/DISABLE_SMART_CONTEXT`

## Progressive Retrieval Strategy

The 4 approaches below form a **progressive retrieval** escalation — start with the simplest (grep) and only add complexity when results are insufficient:

```
Level 1: Keyword (grep)     — fast, literal matching, handles 60% of cases
Level 2: Trigram + Intent   — fuzzy matching, catches morphological variants
Level 3: Subagent (Haiku)   — semantic understanding, handles "different words" problem
Level 4: Vector DB          — full semantic search, for large codebases (100+ files)
```

**This is NOT "semantic > literal"** (Module 00, Principle #5 applies to agent *understanding*, not retrieval). For retrieval, grep is the correct first step — it's fast, deterministic, and sufficient for most queries. Semantic layers add value only when keyword matching fails.

The production hook (`hooks/preprocess-prompt.sh`) operates at Level 2: keyword + trigram + intent routing. Level 3 is available via `hooks/smart-preprocess-v2.sh`.

## 4 Approaches (simplest first)

### A: Hook + grep (10 min setup)

```bash
#!/bin/bash
# .claude/hooks/preprocess-prompt.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0
[ -f ".claude/DISABLE_SMART_CONTEXT" ] && exit 0

MEMORY_DIR="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory"
[ ! -d "$MEMORY_DIR" ] && exit 0

KEYWORDS=$(echo "$PROMPT" | tr ' ' '\n' | sort -u | tr '\n' '|' | sed 's/|$//')
FOUND=$(grep -liE "$KEYWORDS" "$MEMORY_DIR"/*.md 2>/dev/null | head -3)

if [ -n "$FOUND" ]; then
    echo "[CONTEXT] Relevant memory:"
    for f in $FOUND; do
        echo "--- $(basename $f) ---"
        grep -i -C 1 "$KEYWORDS" "$f" 2>/dev/null | head -15
    done
fi
exit 0
```

### B: Subagent Selector (PRODUCTION, 20 min)

**Status: Production** — implemented in `hooks/smart-preprocess-v2.sh` with automatic fallback to keyword matching. Install via `--profile smart-v2`.

Uses fast model (Haiku) to intelligently select context:

```bash
#!/bin/bash
# .claude/hooks/smart-preprocess.sh
PROMPT=$(cat | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

CONTEXT_INDEX="$HOME/.claude/projects/$(echo $CLAUDE_PROJECT_DIR | tr '/' '-')/memory/context-index.md"
[ ! -f "$CONTEXT_INDEX" ] && exit 0

SELECTED=$(claude -p --model haiku "
Task: '$PROMPT'
Available contexts:
$(cat "$CONTEXT_INDEX")
Return ONLY 1-3 most relevant file paths." 2>/dev/null)

if [ -n "$SELECTED" ]; then
    echo "[CONTEXT] Smart selection:"
    echo "$SELECTED" | while read f; do [ -f "$f" ] && head -30 "$f"; done
fi
exit 0
```

**Cost**: ~$0.001/query. **Latency**: 500ms-2s.

### C: Vector DB (most accurate, 1-2h setup)

For large projects (100+ files):

```python
# Embed: rules, memory, code, commits, issues
# Query: embedding of user prompt → cosine similarity → top 5
# Return: snippets with relevance score > 70%
```

### D: Agent Hook (native, 2026)

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "agent",
        "prompt": "Analyze this task and find relevant context files in docs/ and memory/. $ARGUMENTS",
        "model": "haiku",
        "timeout": 60
      }]
    }]
  }
}
```

## Comparison

| Feature | A: grep | B: Subagent | C: Vector DB | D: Agent Hook |
|---------|---------|-------------|--------------|---------------|
| Accuracy | 60% | 85% | 95% | 85% |
| Latency | <100ms | 500ms-2s | 200ms-1s | 1-3s |
| "Different words" | NO | YES | YES | YES |
| Setup | 10 min | 20 min | 1-2h | 5 min |
| **Recommendation** | MVP | **Best balance** | Large projects | Native option |

## Context Budget Rule

```
NEVER inject more than 15% of context window.
At 200k tokens: max 30,000 tokens from preprocessor (~15%)
```

## Escape Hatch

Always maintain ability to disable:

```bash
# Disable: touch .claude/DISABLE_SMART_CONTEXT
# Enable:  rm .claude/DISABLE_SMART_CONTEXT
```

## Important Caveat: Anthropic's Decision

> Anthropic tested RAG with local vector DB in early Claude Code versions and
> **deliberately dropped it** in favor of "agentic search" (grep + glob + read).
> — [Anthropic Engineering Blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

Community filled this gap with open-source projects (claude-mem 4700+ stars, claude-context 4000+ stars). The pragmatic consensus: **agentic as backbone, semantic index only where needed**.

## Security Reference

- OWASP GenAI Top 10 (prompt injection risk model): https://genai.owasp.org/llm-top-10/
- Anthropic Hooks docs (UserPromptSubmit behavior): https://docs.anthropic.com/en/docs/claude-code/hooks

## Evidence Register

| Claim | Status | Evidence |
|------|--------|----------|
| UserPromptSubmit stdout is injected into model context | external | Anthropic hooks docs |
| Guardrails are required for retrieval safety | external | OWASP GenAI Top 10 |
| Lightweight retrieval + ranking is sufficient for many repos | validated locally | `hooks/preprocess-prompt.sh` + tests |
| Semantic/vector layer improves large-codebase recall | heuristic | community benchmarks and practice |

## When Smart Context IS vs ISN'T Worth It

| Project Size | Smart Context? | Why |
|-------------|---------------|-----|
| < 20 files | **NO** | CLAUDE.md + MEMORY.md sufficient |
| 20-100 files | **MAYBE** | If many rules/decisions/memory files |
| 100-500 files | **YES** | Keyword search can't keep up |
| 500+ files | **ESSENTIAL** | Without semantic search, agent drowns |

---

*See [08-advanced](08-advanced.md) for vector DB details and [11-prompt-caching](11-prompt-caching.md) for cache-aware runtime optimization.*
