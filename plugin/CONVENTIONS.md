# Plugin Asset Conventions

## File layout

- **`commands/<name>.md`** — slash command entry points (`/<name>` invocations). Top-level user-facing commands.
- **`skills/<name>.md`** — composable skill modules invoked via the Skill tool. Flat layout, no sub-folders.
- **`scripts/<sub>/<name>.sh`** OR **`scripts/<name>.sh`** — bash scripts. Use a sub-folder when a feature ships multiple scripts (e.g., `scripts/project-doctor/`, `scripts/claude-monitor/`). Top-level for single-file utilities.
- **`hooks/hooks.json`** — single hooks declaration file. Hook bodies live in `scripts/`, NOT `hooks/`.
- **`agents/<name>.md`** — subagent contracts (fixer, oracle, etc.).

## Bundled features (multiple assets for one feature)

When importing a feature with multiple asset types (e.g., project-doctor):
- Sub-folder for scripts: `scripts/<feature>/`.
- Flat skills with feature name prefix: `skills/<feature>.md`, `skills/<feature>-fix.md`.
- Flat commands: `commands/<feature>.md`.
- Hooks (if any): scripts go in `scripts/`, registration in `hooks/hooks.json`.

This keeps asset types discoverable while preventing top-level `scripts/` clutter.
