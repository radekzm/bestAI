# bestAI v7.0 Migration & Onboarding Guide

Welcome to the **bestAI v7.0 (Omni-Vendor)** migration guide! If you have an existing project and want to onboard it into the deterministic, multi-vendor ecosystem, follow these steps.

## Step 1: Baseline Assessment

Before adding bestAI, analyze your current setup:
- Do you already have a `CLAUDE.md`, `.cursorrules`, or `windsurf.json`? 
- Is your agent frequently hitting the context limit or getting stuck in loops?
- **Action:** Run the interactive setup script. It will **not** overwrite your existing instructions unless you tell it to.

```bash
bash setup.sh /path/to/your/project
```

## Step 2: Consolidating Legacy Instructions

If you have a massive `CLAUDE.md` (e.g., >150 lines), bestAI v7.0 requires you to embrace **Progressive Disclosure**:
1. Move specific architectural rules to `.bestai/blueprint.md` or topic files in `/memory`.
2. Keep your `CLAUDE.md` under 100 lines. Focus on "What this project is" and "How to run tests".
3. The newly installed hook `preprocess-prompt.sh` will dynamically load your detailed rules only when the agent asks relevant questions.

## Step 3: Enabling Deterministic Hooks (The "Force Field")

The biggest change in v7.0 is the **Fail-Closed Hook System** with composition validation.
1. Look in `.claude/hooks/`. You will see files like `check-frozen.sh` and `backup-enforcement.sh`.
2. **Crucial:** You must define your "frozen" files. Open `memory/frozen-fragments.md` and list files that the agent should **never** edit directly (like core config files or `.env` templates).
3. Try asking your agent to edit a frozen file. You should see it get blocked (`Exit 2`). This means the force field is working!

## Step 4: Upgrading to v7.0 Multi-Agent Orchestration (Optional)

If your project is large enough to require multiple agents (e.g., Frontend Agent + Backend Agent):
1. Run `bash setup.sh` again and choose the **Agent Swarm Blueprint** (or use `--blueprint swarm` in non-interactive mode).
2. This creates `.bestai/GPS.json` (Global Project State).
3. The `sync-gps.sh` hook will now trigger at the end of every session, ensuring all agents share the same "brain" regarding milestones and blockers.

## Step 5: Validating the Migration

Run the diagnostic doctor to ensure your migration is 100% compliant:
```bash
bash doctor.sh --strict .
```
If you see all green `OK` messages, your project is officially running bestAI v7.0!
