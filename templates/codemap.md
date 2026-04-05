# templates/

## Responsibility

Shared document templates for the lean-flow workflow: PR templates (step PRs and main PRs), commit convention guide, and cartography documentation. These enforce consistent structure across all repos using lean-flow.

## Design

Two PR templates with different scopes: `PULL_REQUEST_TEMPLATE.md` for step-to-parent PRs (lightweight: what/changes/test), `PULL_REQUEST_TEMPLATE_MAIN.md` for parent-to-main PRs (full: overview/changes/test/release notes). `COMMIT_CONVENTION.md` documents the conventional commits standard. `cartography.md` explains the codemap system.

## Flow

Templates are static — used as starting points when creating PRs. The orchestrator references them when instructed to follow the repo's PR template. No automation hooks into these files directly.

## Integration

Referenced by CLAUDE.md ("Always follow the repo's PR template"). Installed into target repos by copying or linking during lean-flow setup. `cartography.md` is read by agents to understand the codemap convention.
