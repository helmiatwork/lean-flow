---
name: update-codemap
description: Tier 2 incremental codemap refresh for changed folders (cheap, lean-flow:explorer).
---

# /lean-flow:update-codemap

Tier 2 incremental codebase map update. Scans recent git changes, dispatches `lean-flow:explorer` to fill `codemap.md` for affected folders only (cheap, haiku). Commits and prepares for push.

## Step 1 — Detect changed files

Run:
```bash
git diff --name-only HEAD~1 HEAD
```

Capture stdout (list of changed files).

If no output (e.g., first commit, no prior commits), skip to Step 5 (nothing to update).

## Step 2 — Extract unique parent folders

From the file list, extract unique top-level parent folders (up to depth 2):

Example:
```
plugin/agents/fixer.md       → plugin
plugin/workflows/flow.md     → plugin
docs/CODEBASE_MAP.md         → docs
README.md                    → (root)
```

Store unique folder list (exclude `.` root; focus on module/package folders).

## Step 3 — Dispatch lean-flow:explorer (parallel per folder)

For each unique folder, dispatch `lean-flow:explorer` in parallel (batch in single Agent call):

```
Context: "Folder codemap refresh (Tier 2)

For each folder below, fill or update the folder's codemap.md:

Folders changed:
  - plugin/
  - docs/

For each folder:
  1. Read [folder]/codemap.md if exists (to preserve structure).
  2. Scan changed files in that folder (from: git diff --name-only HEAD~1 HEAD).
  3. Extract key changes: new files, deleted files, significant logic shifts.
  4. Summarize in bullet points (≤100 chars per bullet, max 10 bullets per folder).
  5. Return structured data:
     {
       \"folder\": \"plugin\",
       \"summary\": \"<brief change summary>\",
       \"bullets\": [\"...\", \"...\"],
       \"new_files\": [...],
       \"deleted_files\": [...]
     }
"
```

Wait for explorer results (parallel batch, single response).

## Step 4 — Orchestrator writes updated codemaps

Parse explorer's structured output. For each folder, generate/update `<folder>/codemap.md`:

**Template:**
```markdown
---
updated: <ISO-8601 timestamp>
folder: <folder-path>
---

# [Folder] Codemap

## Summary
<summary-from-explorer>

## Recent Changes
<explorer bullets, formatted as markdown list>

## Structure
<preserve or extend existing structure from prior codemap.md>

## Key Files
<list new files, modified files with 1-line purpose>
```

Write each `<folder>/codemap.md` to disk.

## Step 5 — Atomic commit

If any codemaps were written:

```bash
git add <folder>/codemap.md ... (all updated files)
git commit -m "chore: update folder codemaps (Tier 2)"
```

Render summary:
```
✅ Folder codemaps updated (Tier 2)
   Folders: <list>
   Files: <count> codemap.md files updated
   Commit: <short-sha>

Next step: git push
(Push is manual; use: git push origin <branch>)
```

If no codemaps were updated:
```
ℹ️ No codemap updates needed. Changed files do not require cartography refresh.
```

## Hard rules

- **No push.** Commit only; user runs `git push` manually.
- **Explorer only (haiku, cheap).** Orchestrator writes; no sonnet agents.
- **Tier 2 scope:** incremental only. For full refresh, use `/lean-flow:generate-codemap` (Tier 1).
- **Preserve prior structure.** Explorer reads existing codemap.md before updating (maintain human annotations, cross-references).
- **Idempotent.** Running twice in a row should produce same commit (no cascading changes).
- **Max 10 bullets per folder.** Explorer should distill, not exhaustively list every change.
