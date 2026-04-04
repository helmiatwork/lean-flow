---
name: cartography
description: Repository understanding and hierarchical codemap generation. Map a codebase, detect changes, generate per-folder codemaps for fast agent orientation.
user_invocable: true
---

# Cartography Skill

You help users understand and map repositories by creating hierarchical codemaps.

## When to Use

- Starting work on an unfamiliar codebase
- User asks to understand/map a repository
- User wants codebase documentation
- Explorer agent needs orientation (read codemap.md instead of scanning)

## Workflow

### Step 1: Check for Existing State

**First, check if `.slim/cartography.json` exists in the repo root.**

If it **exists**: Skip to Step 3 (Detect Changes) — no need to re-initialize.

If it **doesn't exist**: Continue to Step 2 (Initialize).

### Step 2: Initialize (Only if no state exists)

1. **Analyze the repository structure** — List files, understand directories
2. **Infer patterns** for **core code/config files ONLY** to include:
   - **Include**: `src/**/*.ts`, `package.json`, etc. (adjust per project)
   - **Exclude (MANDATORY)**: Do NOT include tests, documentation, or translations.
     - Tests: `**/*.test.ts`, `**/*.spec.ts`, `tests/**`, `__tests__/**`
     - Docs: `docs/**`, `*.md` (except root `README.md` if needed), `LICENSE`
     - Build/Deps: `node_modules/**`, `dist/**`, `build/**`, `*.min.js`
   - Respect `.gitignore` automatically
3. **Run cartographer.py init**:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py init \
  --root ./ \
  --include "src/**/*.ts" \
  --exclude "**/*.test.ts" --exclude "dist/**" --exclude "node_modules/**"
```

This creates:

- `.slim/cartography.json` — File and folder hashes for change detection
- Empty `codemap.md` files in all relevant subdirectories

4. **Delegate to Explorer agents** — Spawn one explorer per folder to read code and fill in its specific `codemap.md` file.

### Step 3: Detect Changes (If state already exists)

1. **Run cartographer.py changes** to see what changed:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py changes --root ./
```

2. **Review the output** — It shows:
   - Added files
   - Removed files
   - Modified files
   - Affected folders

3. **Only update affected codemaps** — Spawn one explorer per affected folder to update its `codemap.md`.

4. **Run update** to save new state:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py update --root ./
```

### Step 4: Finalize Repository Atlas (Root Codemap)

Once all specific directories are mapped, create or update the root `codemap.md`. This file serves as the **Master Entry Point** for any agent entering the repository.

1. **Map Root Assets**: Document root-level files (e.g., `package.json`, `index.ts`, `plugin.json`) and the project's overall purpose.
2. **Aggregate Sub-Maps**: Create a "Directory Map" section. For every folder that has a `codemap.md`, extract its **Responsibility** summary and include it in a table.
3. **Cross-Reference**: Include relative paths to sub-maps so agents can jump directly to details.

Example root codemap:

```markdown
# Repository Atlas: my-project

## Project Responsibility
Brief description of what this project does.

## System Entry Points
- `src/index.ts`: Main entry point
- `package.json`: Dependencies and scripts

## Directory Map
| Directory | Responsibility | Detailed Map |
|-----------|---------------|--------------|
| `src/agents/` | Agent definitions and model routing | [View](src/agents/codemap.md) |
| `src/features/` | Core business logic | [View](src/features/codemap.md) |
```

### Step 5: Register Codemap in CLAUDE.md

To ensure agents automatically discover and use the codemap, check the project's `CLAUDE.md`:

1. If `CLAUDE.md` already contains a `## Repository Map` section, **skip** — already set up.
2. If `CLAUDE.md` exists but has no `## Repository Map` section, **append** it.
3. If `CLAUDE.md` doesn't exist, **create** it with the section.

```markdown
## Repository Map

A full codemap is available at `codemap.md` in the project root.

Before working on any task, read `codemap.md` to understand:
- Project architecture and entry points
- Directory responsibilities and design patterns
- Data flow and integration points between modules

For deep work on a specific folder, also read that folder's `codemap.md`.
```

## Codemap Content Guidelines

Explorers are granted write permissions for `codemap.md` files during this workflow. Use precise technical terminology:

- **Responsibility** — Define the specific role of this directory (e.g., "Service Layer", "Data Access Object", "Middleware").
- **Design** — Identify patterns used (e.g., "Observer", "Factory", "Strategy"). Detail abstractions and interfaces.
- **Flow** — Trace how data enters and leaves the module. Mention function call sequences and state transitions.
- **Integration** — List dependencies and consumer modules. Use technical names for hooks, events, or API endpoints.

Example:

```markdown
# src/agents/

## Responsibility
Defines agent personalities and manages their configuration lifecycle.

## Design
Each agent is a prompt + permission set. Config system uses:
- Default prompts (orchestrator.ts, explorer.ts, etc.)
- User overrides from config JSON
- Permission wildcards for skill/MCP access control

## Flow
1. Plugin loads → calls getAgentConfigs()
2. Reads user config preset
3. Merges defaults with overrides
4. Returns agent configs

## Integration
- Consumed by: Main plugin (src/index.ts)
- Depends on: Config loader, skills registry
```
