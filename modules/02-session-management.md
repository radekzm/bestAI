# Module 02: Session Management & Context Lifecycle

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
| 2 | **Max 2 corrections** | After 2 failed fixes → `/clear` + better prompt |
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
| 2 | Correction Loop | 3+ fixes of same thing | Max 2, then `/clear` + better prompt |
| 3 | Overloaded CLAUDE.md | >100 lines, agent ignores | Trim, move to Skills/Rules |
| 4 | Trust-then-verify gap | Looks correct, fails edge cases | Always provide tests |
| 5 | Unbounded exploration | "Investigate how this works" without scope | Scope narrowly OR use subagent |
| 6 | Too many MCP servers | 15 servers = 50%+ context on schemas | Max 3-4, rest via CLI |
| 7 | Copying configs | Someone else's CLAUDE.md | Build iteratively, test effectiveness |
| 8 | Over-engineering | Complex orchestrations > benefit | Simple Claude Code > excessive automation |

---

*See [03-persistence](03-persistence.md) for memory systems, [05-cs-algorithms](05-cs-algorithms.md) for circuit breaker patterns.*
