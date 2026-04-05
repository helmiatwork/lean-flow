# agents/

## Responsibility

Agent persona definition files. Each file defines a named sub-agent (oracle, coder, fixer, etc.) with its model, tools, role, and behavioral rules. Referenced by the orchestrator when delegating tasks.

## Design

Each `.md` file is a YAML-frontmatter + prose persona: `name`, `model`, `tools` array, then a role description and rules section. Read-only agents (oracle, auditor) are explicitly restricted from editing files. Edit-capable agents (coder, fixer, designer) have tool sets that include Write/Edit.

## Flow

Orchestrator reads the CLAUDE.md routing table, selects the appropriate agent, and invokes it via Claude's native Agent tool passing the persona file path. The agent operates within the tool constraints defined in its frontmatter.

## Integration

Consumed exclusively by the orchestrator (CLAUDE.md). No runtime imports — persona files are prompt context only. Model routing (sonnet vs haiku) is declared per-file and enforced at invocation time.
