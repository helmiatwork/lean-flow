# plugin/skills/

# plugin/skills/ Codemap

## Responsibility

This directory houses 15 **skill definitions** that orchestrate Claude's behavior across planning, codebase analysis, code modification, and project documentation tasks. Each `.md` file is a structured skill spec—not implementation, but behavioral contract defining when a skill triggers, what it does step-by-step, and what it outputs. Skills are invoked by the orchestrator or user via slash commands; they coordinate sub-agent dispatch (explorer, fixer, librarian) and gate complex workflows.

## Design

- **Skill = behavioral spec + process flow.** Each file contains: trigger conditions, step-by-step process (often with numbered phases), output format/examples, rules/constraints, and anti-patterns.
- **Two skill types:** Read-only (map-codebase, phase-researcher, project-doctor) dispatch explorers; write-capable (brainstorming, finishing-a-development-branch, simplify) dispatch fixers.
- **Gating patterns:** Skills like `brainstorming` enforce hard gates (no code until design approved); `plan-checker` validates completeness before execution; `nyquist-auditor` enforces test-only writes.
- **Precedence:** Skills reference each other (brainstorming → writing-plans; assumptions-analyzer → spike if blockers found; ingest-docs → plan-checker).

## Flow

1. **User request** → Orchestrator determines skill(s) needed
2. **Skill execution:** Read spec → Execute steps → Dispatch sub-agents (explorer/fixer/librarian) → Collect results → Format output
3. **Decision gates:** Skills like `discuss` and `brainstorming` pause for user confirmation before proceeding
4. **Chaining:** Skills hand off to next (e.g., brainstorming → writing-plans → plan-checker → fixer execution)
5. **Cleanup:** Skills like `finishing-a-development-branch` and `spike` manage artifact lifecycle (merge/delete)

## Integration

- **Orchestrator entry points:** Slash commands (project-doctor, cartographer) map to skill files
- **Precedent files:** Skills reference `CLAUDE.md`, `AGENTS.md`, project docs (ADRs, SPECs)
- **Sub-agent dispatch:** Skills define haiku/sonnet agent prompts; delegate-to-haiku governs when NOT to run commands directly in orchestrator
- **Output artifacts:** Skills write to `docs/` (CODEBASE_MAP.md, design specs) or commit via fixer (git, files)
- **Cross-skill dependencies:** assumptions-analyzer may invoke spike; brainstorming hands to writing-plans; plan-checker gates fixer dispatch
