# Memory Consolidation Task

You are a memory consolidation agent. Your job is to clean up, organize, and optimize the project memory system for token efficiency.

## Phase 1: Memory File Cleanup

1. Read all memory files in `~/.claude/projects/` directories
2. For each project's `memory/MEMORY.md`:
   - Remove duplicate entries (same info, different files)
   - Remove stale entries (references to things that no longer exist)
   - Merge entries that cover the same topic
   - Keep the index under 200 lines
3. For individual memory files:
   - Update descriptions to be more specific and searchable
   - Remove memories now captured in CLAUDE.md or project docs
   - Ensure frontmatter (name, description, type) is accurate
4. Estimate total tokens across all memory files (chars / 4)
   - If total exceeds 5000 tokens, aggressively merge and prune
   - Priority: keep feedback > user > project > reference

## Phase 2: Pattern Database Optimization

If `~/.claude/knowledge/patterns.db` exists:

### Pruning Rules
1. Delete patterns with `used_count = 0` AND `score < 0.5` AND older than 30 days
2. Delete patterns with `used_count = 0` AND older than 90 days (regardless of score)
3. Delete duplicate patterns (same problem description, different projects) — keep highest scored

### Relevance Decay
4. Reduce score by 0.1 for patterns not used in 60+ days (minimum score: 0.1)
5. Flag patterns used in 3+ projects as "universal" (add tag if schema supports it)

### Token Metrics
6. Count total patterns and estimate total token cost
7. Report: patterns pruned, patterns decayed, estimated tokens saved

## Rules
- Don't delete memories about user preferences or feedback — those are always valuable
- Don't delete project-level decisions unless you can verify they're outdated
- Be conservative — when in doubt, keep the memory
- Update `MEMORY.md` index after any changes
- Report a summary of all changes made
