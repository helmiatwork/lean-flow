# skills/

## Responsibility

Reusable prompt skill files invoked via Claude Code's `/skill` command or the Skill tool. Each file is a standalone prompt document that guides a specific task (e.g., how to write a plan, how to update config).

## Design

Plain markdown files. No code — pure prompt content. Skills are invoked by name and their content is injected into the current context as instructions. Kept minimal to avoid token bloat.

## Flow

User or orchestrator calls `Skill tool` with a skill name. Claude Code locates the `.md` file, reads it, and follows the embedded instructions within the current conversation turn. Skills do not persist state.

## Integration

Registered in Claude Code via the skills discovery path. Referenced in CLAUDE.md instructions (e.g., "use writing-plans skill for plan quality guidance"). No dependencies on other lean-flow components.
