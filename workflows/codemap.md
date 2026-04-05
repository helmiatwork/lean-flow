# workflows/

## Responsibility

Development workflow documentation. Contains the standard development flow as a mermaid diagram and prose, describing how the orchestrator routes tasks (simple/complex/greenfield/hotfix) through agents, branches, and PRs.

## Design

Single primary document `standard-development-flow.md` with a mermaid flowchart as the canonical reference. The diagram covers all decision branches: triage, simple fix, complex multi-step, greenfield, and hotfix paths. Prose sections elaborate on each node.

## Flow

Statically read by the orchestrator at planning time to understand the expected process. Not executed — serves as the authoritative workflow spec that CLAUDE.md summarizes and enforces.

## Integration

Referenced by CLAUDE.md (Standard Development Flow section). Agents may be pointed to this file for workflow context. No code dependencies — documentation only.
