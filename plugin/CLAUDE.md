# plugin/

Plugin internals. All files here are bundled into the `helmiatwork/lean-flow` distribution.

## Conventions

- **Bash 3.2 macOS-compatible** for all `.sh` files. No `[[`, no associative arrays, no `mapfile`.
- **Hooks bodies live in `scripts/`**, NOT in `hooks/`. The `hooks/hooks.json` registers commands; the actual scripts are under `scripts/`.
- **Agent contracts in `agents/<name>.md`** — name without `lean-flow:` prefix on disk; the prefix is for invocation.
- **Skill files** in `skills/` are auto-discovered; only invoke skills that appear in the system reminder list.
- **Command files** in `commands/<name>.md` map to `/<name>` slash commands. Plugin namespace: `/lean-flow:<name>`.
- All scripts referenced from `hooks.json` must use `${CLAUDE_PLUGIN_ROOT}` for path resolution.

## Key files

- `agents/orchestrator.md` — main session contract.
- `agents/fixer.md` — end-to-end execution contract (12 steps).
- `scripts/project-doctor/score.sh` — 25-item audit + 2 advisory.
- `commands/project-doctor.md` + `commands/project-doctor-fix.md` — bundled audit commands.
