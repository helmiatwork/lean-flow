---
name: generate-codemap
description: Tier 1 full refresh of docs/CODEBASE_MAP.md via cartographer script.
---

# /lean-flow:generate-codemap

Tier 1 full codebase map regeneration. Rewrites entire `docs/CODEBASE_MAP.md` from scratch via cartographer script. User confirmation required.

## Step 1 — User confirmation gate

Ask user via AskUserQuestion:

```
Regenerate full codebase map (docs/CODEBASE_MAP.md)?

Options:
  Y  — Proceed with full regeneration
  N  — Cancel
  preview — Show diff vs current map (no write)
```

Store user choice.

## Step 2A — If "preview" selected

Run:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py update
```

Capture full stdout output (new map content).

Read current `docs/CODEBASE_MAP.md` (if exists).

Render diff using markdown fence:
```
--- Current (docs/CODEBASE_MAP.md)
+++ New (cartographer output)
@@ changes @@
```

Do NOT write to disk. Show diff to user, ask again: "Proceed? (Y/N)"

If user says N, stop. If Y, proceed to Step 2B.

## Step 2B — If "Y" selected (initial or after preview)

Run cartographer:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py update > /tmp/codemap-new.md 2>&1
CARTO_EXIT=$?
```

Check exit code:
- `0` — success, continue to Step 3
- non-zero — error. Capture stderr, render error block:
  ```
  ⚠️ Cartographer error (exit code X):
  <stderr content>
  
  Next steps:
  - Check for syntax errors in config files
  - Verify file permissions on docs/ directory
  - Manually run: python3 ${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py update
  ```
  Stop.

## Step 3 — Capture and compare

Read `/tmp/codemap-new.md` (just generated).

Read current `docs/CODEBASE_MAP.md` (if exists) for comparison.

Compute line count delta and timestamp.

## Step 4 — Commit if changes detected

Check if content differs from current:

**If NO changes:**
```
✅ Codebase map up to date. No changes detected.
```
Stop.

**If changes:**
Write new map to `docs/CODEBASE_MAP.md`:
```bash
cp /tmp/codemap-new.md docs/CODEBASE_MAP.md
```

Commit atomically:
```bash
git add docs/CODEBASE_MAP.md
git commit -m "docs: refresh codebase map (Tier 1)"
```

Render summary:
```
✅ Codebase map regenerated (Tier 1)
   Files: docs/CODEBASE_MAP.md
   Lines: <old-count> → <new-count>
   Commit: <short-sha>

Next step: git push
(Push is manual; use: git push origin <branch>)
```

## Hard rules

- **User confirmation required.** Do NOT auto-regenerate without explicit Y.
- **No automatic push.** User runs `git push` manually after reviewing changes.
- **Cartographer must succeed** (exit 0). If failure, report error + next steps, stop.
- **Atomic commit only.** Single `docs: refresh` commit per run.
- **No rollback.** If user wants to revert, they use git history manually.
- **Tier 1 refresh:** Full map from scratch. Use for major codebase restructuring only. For incremental updates, use `/lean-flow:update-codemap` (Tier 2, cheaper).
