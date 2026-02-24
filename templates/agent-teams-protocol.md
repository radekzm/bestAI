# Agent Teams Protocol

> Multi-agent decision-making for critical-path decisions.
> Derived from AION Constitution Section 10.

## When to Trigger

- System CONFIDENCE < 0.70
- User explicitly requests team review
- Critical-path decision (architecture, data model, security)
- Deployment to production

## Roles

| Role | Perspective | Focus |
|------|-------------|-------|
| **OPTIMIST** | Best-case analysis | Benefits, speed, opportunities |
| **CRITIC** | Worst-case analysis | Risks, edge cases, failure modes |
| **PRAGMATIST** | Balanced analysis | Trade-offs, feasibility, timeline |

## Protocol

```
1. LEAD presents the decision/proposal
2. OPTIMIST argues FOR (max 3 points)
3. CRITIC argues AGAINST (max 3 points)
4. PRAGMATIST synthesizes (recommendation + conditions)
5. LEAD produces structured verdict
```

## Output Format

```markdown
## Team Decision: [topic]

### Proposal
[1-2 sentence description]

### OPTIMIST
1. [benefit]
2. [benefit]
3. [benefit]

### CRITIC
1. [risk]
2. [risk]
3. [risk]

### PRAGMATIST
Recommendation: [PROCEED / PROCEED WITH CONDITIONS / HOLD / REJECT]
Conditions: [if applicable]
Confidence: [X.XX]

### Verdict
[Final decision with rationale]
```

## Setup in Claude Code

Create agent definitions in `.claude/agents/`:

```markdown
# .claude/agents/team-optimist.md
---
name: team-optimist
description: Argues FOR the proposed approach
tools: Read, Grep, Glob
model: sonnet
---
You are the OPTIMIST in a team review. Analyze the proposal and argue FOR it.
Focus on: benefits, speed gains, opportunities, positive outcomes.
Present exactly 3 points. Be specific, reference code/files.
```

```markdown
# .claude/agents/team-critic.md
---
name: team-critic
description: Argues AGAINST the proposed approach
tools: Read, Grep, Glob
model: sonnet
---
You are the CRITIC in a team review. Analyze the proposal and argue AGAINST it.
Focus on: risks, edge cases, failure modes, security concerns.
Present exactly 3 points. Be specific, reference code/files.
```

```markdown
# .claude/agents/team-pragmatist.md
---
name: team-pragmatist
description: Synthesizes optimist and critic perspectives
tools: Read, Grep, Glob
model: sonnet
---
You are the PRAGMATIST. Given optimist and critic arguments, provide a balanced recommendation.
Output: PROCEED / PROCEED WITH CONDITIONS / HOLD / REJECT
Include conditions if applicable and a confidence score (0.00-1.00).
```

## Orchestration

```bash
# Run as fan-out pattern:
PROPOSAL="Should we migrate from REST to GraphQL?"

OPT=$(claude -p "Review as OPTIMIST: $PROPOSAL" --agent team-optimist)
CRIT=$(claude -p "Review as CRITIC: $PROPOSAL" --agent team-critic)
PRAG=$(claude -p "OPTIMIST: $OPT --- CRITIC: $CRIT --- Synthesize." --agent team-pragmatist)

echo "## Team Decision"
echo "### OPTIMIST"; echo "$OPT"
echo "### CRITIC"; echo "$CRIT"
echo "### PRAGMATIST"; echo "$PRAG"
```

## Integration with Confidence Gate

When `hooks/confidence-gate.sh` blocks an operation (CONF < 0.70):

1. Run agent team review on the blocked operation
2. If PRAGMATIST says PROCEED WITH CONDITIONS → update state with conditions met
3. If PRAGMATIST says REJECT → present alternatives to user
4. Update `state-of-system-now.md` with new CONFIDENCE score
