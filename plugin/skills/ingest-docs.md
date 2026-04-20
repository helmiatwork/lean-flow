---
name: ingest-docs
description: Bootstrap project context from existing documentation — ADRs, PRDs, SPECs, READMEs. Reads and synthesizes scattered docs into a structured context summary before planning begins.
---

# lean-flow: ingest-docs

Turn scattered existing docs into a grounded planning context. Use before planning work on projects that already have documentation.

## When to invoke
When starting work on an existing project (brownfield) that has ADRs, PRDs, SPECs, or design docs. Prevents plans that contradict locked decisions.

## Process

### Step 1 — Discover docs
Explorer scans the repo for:
- `docs/adr/`, `docs/prd/`, `docs/specs/`, `docs/rfc/`
- Root-level `ADR-*.md`, `PRD-*.md`, `SPEC-*.md`, `RFC-*.md`
- `README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`
- Any file with "decision", "spec", "requirements", "architecture" in name

### Step 2 — Classify each doc
For each found doc, classify as:
- **ADR** (Architecture Decision Record) — locked decisions, highest precedence
- **SPEC** (Technical specification) — implementation contracts
- **PRD** (Product requirements) — feature goals and user stories
- **DOC** (General documentation) — context, guides, references

Precedence order if conflicts: `ADR > SPEC > PRD > DOC`

### Step 3 — Extract key decisions
From ADRs and SPECs, extract:
- Locked architecture decisions (what was chosen and why)
- Technology constraints (what must/must not be used)
- Data model decisions
- API contracts

### Step 4 — Detect conflicts
Compare decisions across docs. Flag when:
- Two docs specify different approaches for the same concern
- A PRD requirement contradicts an ADR decision
- Specs reference components that don't exist in codebase

Conflicts are surfaced — NOT auto-resolved. User must confirm which takes precedence.

### Step 5 — Output context summary

```
## Ingested Context

### Locked decisions (from ADRs)
- [decision]: [rationale] — Source: [file]

### Architecture constraints
- [constraint] — Source: [file]

### Active requirements
- [requirement] — Source: [file]

### ⚠️ Conflicts requiring resolution
- [doc A] says X, [doc B] says Y — which takes precedence?

### Docs processed: [N]
### Docs skipped (unreadable/irrelevant): [N]
```

### Step 6 — Confirm before planning
Present summary to user. Ask: "Does this match the current state of the project? Any outdated docs to disregard?"

Only proceed to planning after user confirms.

## Rules
- Never auto-resolve conflicts — always surface to user
- ADR decisions are treated as locked unless user explicitly overrides
- Outdated docs should be flagged, not silently ignored
- Max 50 docs per invocation
