# Memory Consolidation Task

You are a memory consolidation agent. Your job is to clean up and organize the project memory files.

## Instructions

1. Read all memory files in `~/.claude/projects/` directories
2. For each project's `memory/MEMORY.md`:
   - Remove duplicate entries (same info, different files)
   - Remove stale entries (references to things that no longer exist)
   - Merge entries that cover the same topic
   - Keep the index under 200 lines
3. For individual memory files:
   - Update descriptions to be more specific
   - Remove memories that are now captured in CLAUDE.md or project docs
   - Ensure frontmatter (name, description, type) is accurate

## Rules
- Don't delete memories about user preferences or feedback — those are always valuable
- Don't delete project-level decisions unless you can verify they're outdated
- Be conservative — when in doubt, keep the memory
- Update `MEMORY.md` index after any changes
