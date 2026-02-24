# Scenario 01: Context Routing Accuracy

## Category: smart-context

## Tasks

### 01a: Keyword match — direct keyword in memory
- **Prompt**: "Fix the authentication token expiry bug"
- **Expected**: pitfalls.md or decisions.md loaded (contains "token", "auth")
- **Pass criteria**: SMART_CONTEXT output contains relevant auth content

### 01b: Trigram match — morphological variant
- **Prompt**: "napraw logowanie uzytkownika" (Polish: "fix user login")
- **Expected**: pitfalls.md loaded via trigram matching ("log" trigram)
- **Pass criteria**: SMART_CONTEXT output present despite no keyword match

### 01c: Intent routing — debug vs deploy
- **Prompt**: "debug the connection timeout" → should be "debugging" intent
- **Prompt**: "deploy to production" → should be "operations" intent
- **Pass criteria**: Correct intent detected, correct priority files loaded

### 01d: Semantic routing (Haiku)
- **Prompt**: "Why does the API return 401 after 30 minutes?"
- **Expected**: Haiku selects auth-related files without keyword "auth" in prompt
- **Pass criteria**: smart-preprocess-v2 returns relevant files

## Measurement
- Relevance score (0-1): manual review of injected context vs expected
- Token efficiency: injected tokens / useful tokens ratio
