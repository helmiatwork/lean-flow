# docs/

Architectural and reference documentation for lean-flow.

## Conventions

- **ADR format: Nygard** (Title / Status / Context / Decision / Consequences). Files: `docs/adr/NNNN-<slug>.md`.
- **Diagrams: Mermaid first**, ASCII as fallback for tooling without Mermaid support.
- **Cross-references** — use relative paths (`../plugin/...`) so docs render correctly in GitHub's UI.
- **Codebase map auto-updates** via PostToolUse hook on commits — don't hand-edit folder summaries that tooling owns.

## Files

- `ARCHITECTURE.md` — system design, hook lifecycle.
- `CODEBASE_MAP.md` — repo layout, folder ownership.
- `DOMAIN.md` — entities + relationships.
- `SYMBOL_GRAPH.md` — symbol indexing tooling.
- `adr/` — Architectural Decision Records.
