# ADR-0001: commands/ vs skills/ distinction

**Date:** 2026-05-10
**Status:** Accepted
**Deciders:** helmiatwork

## Context

Lean-flow plugin originally shipped with `skills/` only. Importing project-doctor v0.3.0 introduces `commands/` as a new top-level layout. Without a clear rule, future contributors may conflate the two and migrate skills to commands (or vice versa) inconsistently.

## Decision

- **`commands/<name>.md`** — slash-command entry points the user types directly (`/<name>`). Top-level interactive flows.
- **`skills/<name>.md`** — composable skill modules invoked via the Skill tool, often programmatically by other agents/commands. Flat layout, no sub-folders. Trigger phrases route natural language to the skill.

A command MAY internally invoke skills. A skill MAY be standalone-invokable via natural language but is not exposed as `/<name>`.

## Consequences

- ✅ Clear distinction prevents drift.
- ✅ Existing skills (simplify, discuss, brainstorming, etc.) stay in `skills/` — no retroactive migration.
- ✅ New top-level user commands go in `commands/`.
- ⚠️ Some skills (e.g., `simplify`) ARE invoked via `/simplify` slash command today. These remain skills until/unless explicitly promoted to commands. The slash-command resolution layer routes `/<name>` to either, so users see no difference.
- ⚠️ Documentation overhead: future imports must classify each asset.

## Alternatives considered

- **All-in-skills** (no commands/) — rejected: project-doctor's audit/fix flows are clearly user-driven slash entry points, not composable modules.
- **Migrate everything to commands/** — rejected: would break existing skill invocations across many features.
