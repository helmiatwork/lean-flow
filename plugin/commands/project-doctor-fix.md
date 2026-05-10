---
name: project-doctor-fix
description: Auto-generate ALL missing context artefacts in one pass. Asks 4W1H questions per item, then writes files. Dispatches lean-flow:fixer for execution.
---

# /project-doctor-fix

Single-shot fix: scan, ask 4W1H questions for every missing item, generate all files, commit atomically.

## Step 1 — Dispatch model

This plugin (lean-flow) ships with the `lean-flow:fixer` haiku agent. Step 4 dispatches the fixer for file writes. The fallback to direct `Write` tool is purely a resilience safety net for transient dispatch errors (not a soft-detect mechanism). Note: dispatch-to-fixer is for consistency with lean-flow's code-writing pattern, not for token-cost savings — orchestrator runs in the same session.

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

**Note on advisory items (26, 27):** These are informational checks for optional CLI tools (RTK, omni) and do NOT appear in `--missing-only` output. Skip them entirely in the fix flow — they have no auto-generated remediation.

## Step 3 — Gather context (explicit 4W1H clusters)

Group missing items into these clusters and ask 4W1H per cluster (one AskUserQuestion call per cluster, ≤4 questions each):

- **docs cluster** (items 1, 2, 9, 10, 12): project overview, tech stack, conventions, commands cheatsheet, onboarding.
- **architecture cluster** (items 3, 4, 5, 6): domain model, architecture diagram, codebase map, per-folder codemap.
- **data cluster** (items 7, 8): ERD, API contract.
- **adr cluster** (item 11): past architectural decisions worth recording.
- **memory cluster** (items 14, 15): agent memory, symbol graph tool choice.
- **tooling cluster** (items 13, 16, 17, 19, 20, 23, 24): SessionStart hook, coverage gate, pre-commit, hooks declared, CI, companion plugins, pre-commit gates.
- **rules cluster** (items 18, 21, 22, 25): per-folder CLAUDE.md targets, STAR enforcement, orchestrator binding, pattern memory usage.
- **advisory cluster** (items 26, 27): RTK + omni CLI tools — informational only, skip in this flow.

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
- **STAR enforcement (#21)**: check if `CLAUDE.md` (root or global fallback) contains STAR PROTOCOL or Tier Routing sections. If missing, do not auto-generate — instead instruct user to run `/init` or manually add the relevant section to CLAUDE.md. This is a rules item, not auto-fillable content.
- **Orchestrator binding (#22)**: check if `CLAUDE.md` (root or global fallback) contains explicit orchestrator governance (phrases like "orchestrator never edits" and "orchestrator never pushes"). If missing, do not auto-generate — instruct user to add via `/init` or manual CLAUDE.md edit. This is a rules item.
- **Companion plugins (#23)**: when missing, guide user to enable superpowers and caveman plugins via `/plugin enable superpowers@claude-plugins-official` and `/plugin enable caveman@caveman` in the Claude Code session. Document this in the fix output; do not attempt to modify settings.json directly.
- **Pre-commit gates (#24)**: check if `.claude/settings.json` or the lean-flow plugin's `hooks.json` declares the gate hooks. If missing, instruct user that gates are auto-declared by lean-flow plugin on install; if gates are actually absent, recommend running `gh extension install cli/gh-extension-preinstall` and re-initializing hooks. Do not auto-generate.
- **Pattern memory (#25)**: check if `CLAUDE.md` (root or global fallback) mentions pattern_search or pattern_store. If missing, instruct user to add a "Knowledge MCP" or "Pattern Memory" section to CLAUDE.md as part of their team/project rules. Do not auto-generate content.
- **RTK CLI (#26)** and **omni CLI (#27)**: These are advisory items. Do NOT auto-generate. Instead, print install hints if missing:
  - RTK: `cargo install rtk` or https://github.com/yourusername/rtk
  - omni: `brew install omni` or https://github.com/yourusername/omni

## Step 5 — Re-scan + delta report

Run scanner again. Print before/after score: `X/25 → Y/25 (+Z items)`. List remaining missing items if any.

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
