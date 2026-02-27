# AGENTS.md — Multi-Tool Compatibility Template

<!-- bestai-template: agents-md v5.0 -->
<!-- Compatible with: Claude Code, OpenAI Codex, Sourcegraph Amp, Cursor, Windsurf -->
<!-- Spec: https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions -->

## Project Overview

- **Name**: [project name]
- **Description**: [one-line description]
- **Stack**: [your stack]
- **Language**: [primary language]

## Coding Standards

- [Rule 1: e.g., "Use TypeScript strict mode"]
- [Rule 2: e.g., "All functions must have JSDoc comments"]
- [Rule 3: e.g., "Prefer immutable data structures"]
- [Rule 4: e.g., "No console.log in production code"]

## Testing

- **Framework**: [e.g., Vitest, Jest, pytest, RSpec]
- **Command**: `[e.g., npm test]`
- **Coverage**: [e.g., "Minimum 80% for new code"]
- **Pattern**: [e.g., "Co-located `__tests__/` directories"]

## Architecture

- [Key architectural decision 1]
- [Key architectural decision 2]
- [Key architectural decision 3]

## File Structure

```
src/
├── components/     # UI components
├── lib/            # Shared utilities
├── services/       # Business logic
└── types/          # TypeScript types
```

## Do NOT

- Edit files listed as frozen (see frozen-fragments.md)
- Commit secrets, credentials, or API keys
- Skip tests before committing
- Make breaking changes without discussion
- Use deprecated APIs or libraries

## Conventions

- **Branch naming**: `feature/`, `fix/`, `chore/`
- **Commit format**: Conventional Commits (`feat:`, `fix:`, `chore:`)
- **PR size**: Keep under 400 lines changed
- **Documentation**: Update README for public API changes
