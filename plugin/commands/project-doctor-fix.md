---
name: project-doctor-fix
description: Auto-generate ALL missing context artefacts in one pass. Asks 4W1H questions per item, then writes files. Dispatches lean-flow:fixer for execution.
---

# /project-doctor-fix

Single-shot fix: scan, ask 4W1H questions for every missing item, generate all files, commit atomically.

## Step 1 — Dispatch model

This plugin (lean-flow) ships with the `lean-flow:fixer` haiku agent. Step 4 dispatches the fixer for file writes. The fallback to direct `Write` tool is purely a resilience safety net for transient dispatch errors (not a soft-detect mechanism).

**Fallback triggers ONLY on dispatch-layer errors** — when the Agent tool itself rejects the call before fixer execution begins. Examples:
- "subagent_type not recognized" / "unknown agent type" (fixer agent missing — should never happen since fixer ships with this plugin)
- Tool call rejected by permission gate before execution
- Empty result from dispatch with no fixer transcript

**Do NOT trigger fallback** on execution-layer failures from a successfully-dispatched fixer:
- Git conflict during commit
- File system permission denied during write
- Test failure or coverage gate failure inside fixer

Execution-layer failures must surface as errors to the user — silently falling back to direct Write would mask real bugs in the generation flow. If fixer dispatch succeeded but fixer reports an item-level failure, log that item as failed in the Step 5 delta report and continue with remaining items via direct Write.

## Definition: file present

Throughout this command, "file present" means:
- File exists at the target path AND
- File contains at least one non-whitespace character AND
- For markdown files (`.md` extension): contains at least one heading line matching `^#`.

For non-markdown files (`.json`, `.yml`, `.sh`, etc.): only the existence and non-whitespace-content checks apply; no heading check.

An empty `CLAUDE.md` (zero bytes or only whitespace) is treated as MISSING. A `CLAUDE.md` with only `# Project` (10 bytes, has heading) is treated as PRESENT — the heading is the structural signal, not file size.

Apply consistently: each item's file-present check uses the rules above, with the heading sub-rule scoped to markdown extensions only.

## Step 2 — Run scanner

Run `${CLAUDE_PLUGIN_ROOT}/scripts/project-doctor/score.sh --missing-only` to get a machine-readable list of missing items, one per line, format: `<num>|<label>|<file>|<severity>`. Re-validate each item from `--missing-only` output by also checking the file-present criteria above for items the scanner reported as `[OK]` but might be empty.

## Step 3 — Gather context (explicit 4W1H clusters)

Group missing items into these clusters and ask 4W1H per cluster (one AskUserQuestion call per cluster, ≤4 questions each):

- **docs cluster** (items 1, 2, 9, 10, 12): project overview, tech stack, conventions, commands cheatsheet, onboarding.
- **architecture cluster** (items 3, 4, 5, 6): domain model, architecture diagram, codebase map, per-folder codemap.
- **data cluster** (items 7, 8): ERD, API contract.
- **adr cluster** (item 11): past architectural decisions worth recording.
- **memory cluster** (items 14, 15): agent memory, symbol graph tool choice.
- **tooling cluster** (items 13, 16, 17, 19, 20): SessionStart hook, coverage gate, pre-commit, hooks declared, CI.
- **rules cluster** (item 18): per-folder CLAUDE.md targets.

Skip a cluster if no items in it are missing. Combine 1-2 questions per cluster covering all sub-items via concise multi-select prompts.

## Step 3.5 — Confirmation gate

Compute totals:
- N = number of missing items from Step 2.
- M = number of files that will be created or modified (sum of files-per-item; some items create multiple files).
- list of files (paths only, one per line).

Use AskUserQuestion to ask:
"Ready to generate <N> missing artefacts (<M> files)? Proceed?"
- Yes — proceed to Step 4.
- No — abort. Print summary "<N> items left as-is."
- Show file list — print the paths, then re-ask.

Do NOT proceed to Step 4 without explicit Yes.

## Step 4 — Generate files (single dispatch, per-file writes)

Build a SINGLE prompt for `lean-flow:fixer` containing the full ordered list of items + their expected file paths and content.

**The dispatched fixer's execution plan MUST write files using one `Write` tool call per file.** Do NOT instruct the fixer to combine multiple files into a single Write call. Each file is written, then committed atomically with `git add` + `git commit`, before the next file is written. This guarantees partial success: if the fixer halts or truncates mid-batch, all already-written files remain on disk and committed; only the unwritten remainder is lost.

The dispatched fixer pushes ONCE at the end, after all writes (or as many as completed) are committed.

If fixer dispatch fails (resilience fallback): the orchestrator iterates items sequentially with direct `Write` for each file + `Bash` for `git add` + `git commit` per item, then a single `git push` at the end. Same per-file write discipline applies.

NEVER dispatch multiple parallel fixer agents — they cannot coordinate the final push.

Order: P0 → P1 → P2.

For each missing item:
- Construct the file content from user answers and project conventions detected by reading existing files (Gemfile, package.json, README, etc.).

Special-case items:
- **SessionStart hook (#13)** — TWO-STEP write requires this order:
  1. Validate `.claude/settings.json` exists and parses as valid JSON. If file does not exist, create it with `{}`. If exists but invalid JSON, ABORT this item with error message "settings.json is not valid JSON; manual fix required" and continue with other items.
  2. Patch `.claude/settings.json` to add the `hooks.SessionStart` entry. Re-validate the resulting JSON parses. If parse fails, restore from in-memory backup and ABORT this item.
  3. Only after settings.json is successfully patched: write `.claude/hooks/session-start.sh` and `chmod +x` it.

  If step 2 fails, do NOT write the script — leaves repo in clean state.
- **Pre-commit hook (#17)**: write `lefthook.yml` with default jobs (lint, secret-scan).
- **Per-folder CLAUDE.md (#18)**: detect top folders from filesystem with:
  ```bash
  ls -d */ 2>/dev/null | grep -v -E '^(node_modules|vendor|tmp|.git|.bundle|coverage|dist|build|.next|.venv|venv)/$'
  ```
  Ask user which folders need own rules; write one CLAUDE.md per chosen folder.
- **CI gate (#20)**: write `.github/workflows/ci.yml` with default test+lint job (detect language from existing files).
- **MEMORY.md (#14)**: write `.claude/MEMORY.md` with seed structure (Index + sections).
- **Symbol graph (#15)**: don't auto-generate index files; instead write a `docs/SYMBOL_GRAPH.md` documenting which tool the team picked + how to refresh.
- **ADR folder (#11)**: create `docs/adr/template.md` (Nygard format) and `docs/adr/0001-baseline.md` summarizing major existing tech decisions detected from CLAUDE.md / Gemfile / package.json. Commit message MUST be: `docs(adr): add baseline ADR seed — review before finalizing`. The summary is auto-generated and quality is unverified.

## Step 5 — Re-scan + delta report

Run scanner again. Print before/after score: `X/20 → Y/20 (+Z items)`. List remaining missing items if any.

## Step 6 — Push commits

After all generation succeeds (or partially succeeds with reported errors):
- Run `git push origin <current-branch>`.
- Print: "Pushed N commits to origin."

## Hard rules
- Commit each generated file atomically with conventional message.
- NO Claude/AI/Co-Authored-By in commit messages.
- Use the project's own conventions (detected from existing files) when generating new ones.
- Skip items already present (re-scan first to be sure).
- If user answers `<skip>` for an item, do not generate.
- File presence is determined by the rigorous definition above. The scanner emits MISSING/STALE; the fix flow does not separately re-check for "partial" files.
