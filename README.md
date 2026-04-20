<div align="center">

# lean-flow

**Lightweight dev workflow plugin for Claude Code**

*Same workflow as ruflo/claude-flow. 6 tools instead of 300+. 1/60th the token cost.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://claude.ai/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/helmiatwork/lean-flow/pulls)

</div>

---

## Why lean-flow?

Frameworks like [ruflo](https://github.com/ruvnet/ruflo) and [oh-my-opencode-slim](https://github.com/ruvnet/oh-my-opencode-slim) register **300+ MCP tools** and fire multiple hooks per message. Most tools are never called, but they still consume **~3000 tokens/session** just by existing.

lean-flow extracts the **7 actually useful features** and implements them with native Claude Code capabilities.

| | ruflo | lean-flow |
|:---|:---:|:---:|
| MCP tools registered | 300+ | **6** |
| Tokens/session overhead | ~3,000 | **~100** |
| Tokens/message overhead | ~600 | **~50** |
| Hooks per prompt | 5-8 | **1** |
| Pattern memory | JSON files | **SQLite + FTS5** |
| Agent orchestration | Custom swarm | **Native Agent tool** |

---

## Features

### 🧠 Pattern Memory
SQLite database with FTS5 full-text search. Save solved patterns, retrieve them before re-solving.

| Tool | Purpose |
|:-----|:--------|
| `pattern_search` | Find previously solved patterns by keyword |
| `pattern_store` | Save problem + solution pairs after success |
| `pattern_list` | List all patterns for a project |
| `pattern_delete` | Remove stale or incorrect patterns |
| `pattern_stats` | Show usage statistics across all projects |
| `project_context` | Store/retrieve project summary & conventions |

### 🤖 Parallel Agents

| Agent | Model | Reads? | Writes? | Role |
|:------|:-----:|:------:|:-------:|:-----|
| **Oracle** | Sonnet | **No** | **No** | Think-only: architecture review, code review, synthesis, decisions |
| **Fixer** | Haiku | Yes | Yes | All implementation: features, bug fixes, refactors, tests, mechanical changes |
| **Librarian** | Haiku | Yes | No | Docs lookup, web search, research |
| **Designer** | Sonnet | Yes | Yes | UI/UX, frontend components |
| **Explorer** | Haiku | Yes | No | File discovery, codebase navigation, codebase map scanning, pre-oracle diff reading |

> **Oracle is think-only.** It never reads files or writes code. Explorer reads files/diffs → orchestrator passes summaries → Oracle thinks and decides. This keeps expensive sonnet tokens minimal.

### 🌿 Branch Naming Convention

| Prefix | Use |
|:-------|:----|
| `feature/` | New functionality |
| `fix/` | Bug fixes |
| `improvement/` | Refactors, performance |
| `security/` | Security patches |
| `test/` | Test-only changes |
| `docs/` | Documentation |
| `chore/` | Dependencies, CI, config |
| `hotfix/` | Urgent production fixes |
| `release/` | Release prep, version bumps |
| `experiment/` | Spikes, prototypes (may discard) |
| `revert/` | Reverting a bad merge |

Steps append `/step-N`: `feature/onboarding/step-1`

### 🔒 Safety Hooks
- **Block** direct push to `main` / `master` / `staging`
- **Block** `--no-verify` and `--no-gpg-sign` flags on git commands
- **Block** staging secret files (`.env`, credentials) — warns on `git add .`
- **Block** Claude identity in commits and PRs (Co-Authored-By, attribution)
- **Block** saving plans to wrong directory (`docs/superpowers/plans/`)
- **Auto-allow** workflow tools (Agent, Tasks, PlanMode) — no permission prompts

> These hooks enforce rules at the shell level (exit code 2 = block). Zero token cost — no prompt instructions needed.

### 🪝 Workflow Hook (`workflow-hook.sh`)

All workflow-related hooks are consolidated into a **single entry point**: `workflow-hook.sh`. It routes by event and matcher internally, and merges multiple `additionalContext` outputs before emitting.

| Event | Trigger | What it does |
|:------|:--------|:-------------|
| `SessionStart` | Session opens | **session-briefing**: git state summary (branch, status, recent commits) |
| `UserPromptSubmit` | Every prompt | **pattern-recall**: searches knowledge MCP for matching patterns before re-solving |
| | | **load-workflow**: injects `claude-rules.md` + full workflow into model context (once per session) |
| | | **star-clarify**: detects vague requests and asks clarifying questions before work starts |
| `PostToolUse Write\|Edit` | After any file write | **enforce-tdd**: injects mandatory RED→GREEN→REFACTOR + E2E + coverage ≥80% + oracle escalation after 3 failures |
| `PostToolUse EnterPlanMode` | On entering plan mode | **knowledge-prefilter**: checks knowledge MCP for relevant patterns, injects into plan context |
| `PostToolUse ExitPlanMode` | On exiting plan mode | **generate-plan-viewer**: opens live plan dashboard at `localhost:3456` |
| `PostToolUse Bash` | After `gh pr create` | **PR notify**: dispatches `lean-flow:code-reviewer` + `lean-flow:fixer` to review and fix the new PR |
| `SubagentStop` | After each subagent | **remind-check-step**: reminds to mark the step `[x]` in the plan skeleton |
| `Stop` | Session ends | **auto-dream** (bg): memory consolidation via Haiku |
| | | **auto-observe** (bg): records session observations to memory |
| | | **session-summary** (bg): writes session summary to `.lean-flow/sessions/` |
| `PostCompact` | After context compaction | **session-summary** (bg): checkpoint summary for continuity |

> **Not consolidated** (kept separate): `ensure-*`, `block-*`, `claude-session-track`, `restructure-plan.py`, `auto-compress-output`, `track-test-failures`, `auto-update-codemaps`

### 📊 Usage Monitor *(macOS)*
SwiftBar menu bar plugin showing real-time Claude Code usage:
- Session %, weekly %, sonnet % with reset countdown
- Color-coded: 🟢 <50% · 🟡 50-80% · 🔴 >80%
- **Per-model token breakdown** — reads `~/.claude/projects/**/*.jsonl` locally (no API calls): input/output token counts + % share for each model (Sonnet, Haiku, Opus) over the last 7 days
- Auto-refresh via launchd daemon (every 30s)

> **Note:** The usage monitor requires macOS + SwiftBar. On Linux, you can manually check usage with `claude /usage` or read `/tmp/claude-usage-cache.json` if the fetcher is running.
>
> **macOS permission:** The fetcher daemon runs `node` to access Claude's usage data. If you see a *"node would like to access data from other apps"* dialog, go to **System Settings → Privacy & Security → App Management** and toggle **Allow** for `node`. If `node` isn't listed, click **+** and navigate to `/opt/homebrew/bin/node` (or wherever `which node` points). This is a one-time setup.

### 🗺️ Cartographer (Hybrid Codebase Mapping)
Two-tier documentation system for codebases of any size.

**Tier 1: `docs/CODEBASE_MAP.md`** — high-level architecture atlas
- Mermaid diagrams, directory map, navigation guide
- Generated by parallel Sonnet subagents via `/cartographer`
- Updated rarely (major structural changes only)

**Tier 2: Per-folder `codemap.md`** — module-level detail
- Responsibility, design, flow, integration per directory
- MD5 change detection via `cartographer.py` (`.slim/cartography.json`)
- Updated incrementally after each PR merge (only affected folders)

**Tools:**
- **`/cartographer`** — full mapping (both tiers)
- `cartographer.py init/changes/update` — Tier 2 change detection
- `scan-codebase.py` — token counting for Tier 1 subagent budgeting
- Auto-detects changes on session start (both tiers)

> Tier 1 based on [kingbootoshi/cartographer](https://github.com/kingbootoshi/cartographer). Requires `python3` or `uv`.

### 🎭 E2E Testing
Auto-installs [Playwright MCP](https://github.com/anthropics/anthropic-quickstarts/tree/main/mcp-playwright) for browser automation testing.

### 🎯 Skills (via superpowers plugin)

lean-flow auto-enables the [superpowers](https://github.com/anthropics/claude-code-plugins) plugin which provides these skills used in the workflow:

| Skill | When it's used |
|:------|:---------------|
| `cartographer` | Hybrid codebase mapping — Tier 1: `docs/CODEBASE_MAP.md` (atlas) + Tier 2: per-folder `codemap.md` (detail) |
| `brainstorming` | Before any creative/feature work — explores intent and design |
| `writing-plans` | When creating implementation plans (feeds into plan-plus) |
| `test-driven-development` | Before writing implementation code |
| `systematic-debugging` | When encountering bugs or test failures |
| `verification-before-completion` | Before claiming work is done or creating PRs |
| `receiving-code-review` | When processing oracle's review feedback |
| `finishing-a-development-branch` | When implementation is complete, deciding merge/PR/cleanup |
| `using-git-worktrees` | When feature work needs isolation from main workspace |

> Skills are invoked automatically when their context matches. No manual activation needed.

### 📺 Live Plan Viewer
Auto-opens a browser dashboard at `localhost:3456` when you exit plan mode. Shows all plans grouped by repo with real-time updates.

- **Two-panel layout** — sidebar with repos + plans, main panel with step details
- **Live reload** — file watcher + Server-Sent Events, updates instantly when steps are checked off
- **Sorted** — incomplete plans on top (lowest progress first), completed at bottom
- **20 per repo** — "Show more" button for older plans
- **Status indicators** — 🟢 complete, 🟡 in progress, ⚫ not started

The viewer runs as a background server. Starts automatically on first plan exit, reuses existing server on subsequent exits.

### ⚡ RTK (Rust Token Killer)
Auto-installs [RTK](https://www.rtk-ai.app) — a Rust CLI proxy that rewrites Bash commands to token-optimized equivalents. Typical savings: **40-90% fewer output tokens** on dev operations.

- `git status`, `ls`, `find`, `grep`, `diff` → compact RTK output
- Transparent — no prompt changes needed, works via PreToolUse hook
- Check savings anytime: `rtk gain`

> RTK is auto-installed on first session (via brew or curl fallback). Disable with `"enable": { "rtk": false }` in `~/.claude/lean-flow.json`.

### 💤 Auto-Dream
Background memory consolidation using Haiku. Runs every 5 sessions / 24 hours. Cleans up stale memories, merges duplicates, prunes outdated entries.

---

## Workflow

```mermaid
flowchart TD
    USER(["👤 User prompt"]) --> TRIAGE

    TRIAGE{"🎯 Orchestrator\ntriages complexity"}
    TRIAGE -->|"Simple"| DIRECTFIX
    TRIAGE -->|"Complex"| MEMORY
    TRIAGE -->|"Greenfield 🌱"| GREENFIELD
    TRIAGE -->|"Hotfix 🔥"| HOTFIX

    %% === GREENFIELD PATH ===
    GREENFIELD["🌱 Brainstorm\nproduct concept"] --> GENDOCS
    GENDOCS["📄 Generate docs\n(parallel sonnet agents)\nPRD, HLA, TRD, DB, API"] --> PLANMODE

    %% === SIMPLE PATH ===
    DIRECTFIX["🔧 Fixer\nImplement fix"] --> DIRECTTEST["Run tests"]
    DIRECTTEST -->|"Pass"| DIRECTPR["PR → main\n(with release notes)"]
    DIRECTTEST -->|"Fail"| DIRECTFIX
    DIRECTPR --> DONE(["✅ Done"])

    %% === HOTFIX PATH ===
    HOTFIX["🔥 hotfix/ branch\nfrom main"] --> HOTFIXFIXER["🔧 Fixer\nMinimal fix"]
    HOTFIXFIXER --> HOTFIXTEST["Run tests"]
    HOTFIXTEST -->|"Fail"| HOTFIXFIXER
    HOTFIXTEST -->|"Pass"| HOTFIXPR["PR hotfix → main\n🔮 Oracle inline review\n+ release notes"]
    HOTFIXPR --> HOTFIXMERGE(["✅ Merge + cherry-pick\nto in-flight branches"])

    %% === COMPLEX PATH ===
    MEMORY["🧠 pattern_search\nKnowledge MCP"] --> FOUND

    FOUND{"Match?"}
    FOUND -->|"Yes"| ADAPT["Apply pattern\n🔧 Fixer implements"]
    FOUND -->|"No"| BRAINSTORM

    BRAINSTORM["💡 Brainstorming skill\nExplore requirements"] --> PLANMODE

    PLANMODE["📋 EnterPlanMode"] --> QUALITY

    QUALITY["✍️ writing-plans skill\nQuality guidance\n(file paths, code, TDD)"] --> WRITE

    WRITE["Write plan to\n~/.claude/plans/"] --> REVIEW

    REVIEW{"Approved?"}
    REVIEW -->|"No"| WRITE
    REVIEW -->|"Yes"| EXITPLAN

    EXITPLAN["📋 ExitPlanMode\nplan-plus restructures\ninto skeleton + steps"] --> VIEWER

    VIEWER["📺 Plan viewer\nlocalhost:3456"] --> BRANCH

    ADAPT --> BRANCH

    BRANCH["🌿 Create parent branch"] --> STEP

    STEP{"Next step?"}
    STEP -->|"Yes"| RESEARCH
    STEP -->|"All done"| PLANCOMPLETE["✅ All steps complete!\nProceed to audit"]
    PLANCOMPLETE --> AUDITSCAN
    STEP -->|"Plan invalid"| REPLAN

    REPLAN["📋 Revise remaining\nsteps in plan-plus"] --> STEP

    RESEARCH{"Needs research?"}
    RESEARCH -->|"Unfamiliar code"| EXPLORER["🔍 Explorer\n(haiku)"]
    RESEARCH -->|"Need docs"| LIBRARIAN["📚 Librarian\n(haiku)"]
    RESEARCH -->|"No"| STEPBR

    EXPLORER --> STEPBR
    LIBRARIAN --> STEPBR

    STEPBR["🌿 Step branch\nprefix/name/step-N"] --> TESTFIRST

    TESTFIRST{"TDD?"}
    TESTFIRST -->|"Yes"| TDDTEST["🔧 Fixer writes\nfailing tests"] --> IMPLEMENT
    TESTFIRST -->|"No"| IMPLEMENT

    IMPLEMENT["🔧 Fixer\n(haiku)\nImplement + tests"] --> FIXCHECK

    FIXCHECK["✅ Fixer checklist\n(self-verify)"] --> TEST

    TEST["Run tests"]
    TEST -->|"Fail x3"| ORACLE_SCAN["🔍 Explorer\nreads error context"] --> ORACLE_ESC["🔮 Oracle\n(think-only)\nDiagnosis"]
    ORACLE_ESC --> FIX
    TEST -->|"Pass"| STEPPR

    STEPPR["PR step → parent\n(auto-merge, no oracle)"] --> MERGE_STEP["Merge to parent"]
    MERGE_STEP --> CHECKBOX["☑️ Mark step [x]\nin skeleton"]
    CHECKBOX --> STEP

    AUDITSCAN["🔍 Explorer\n(haiku)\nRead full parent diff\n→ structured summary"] --> AUDIT

    AUDIT["🔮 Oracle\n(think-only)\nSecurity audit\nfrom explorer summary"] --> CLEAN

    CLEAN{"Issues?"}
    CLEAN -->|"Found"| FIXAUDIT["🔧 Fixer implements\n🔍 Explorer re-reads\n🔮 Oracle reviews"]
    CLEAN -->|"Clean"| MAINPR

    FIXAUDIT --> AUDITSCAN

    MAINPR["PR parent → main\n+ release notes"] --> FINALSCAN

    FINALSCAN["🔍 Explorer\n(haiku)\nScan PR diff\n→ summary"] --> FINAL

    FINAL["🔮 Oracle\n(think-only)\nReview checklist\nfrom explorer summary"]
    FINAL -->|"Issues"| FIXFINAL["🔧 Fixer\nfix on parent"]
    FINAL -->|"Approved"| CMAPSCAN

    FIXFINAL --> FINALSCAN

    CMAPSCAN["🔍 Explorer\n(haiku)\nScan touched dirs\n→ structure summary"] --> CODEMAP

    CODEMAP{"🔮 Oracle\n(think-only)\nCodemap decision"}
    CODEMAP -->|"Missing/outdated"| CMAPSYNTH["🔮 Oracle synthesizes\ncodebase map from summary\n→ 🔧 Fixer writes file"]
    CODEMAP -->|"Up to date"| LEARN
    CMAPSYNTH --> LEARN

    LEARN["🧠 pattern_store\nSave patterns"] --> MERGE_MAIN(["✅ Merge to main"])

    style USER fill:#34495E,color:#fff
    style TRIAGE fill:#8E44AD,color:#fff
    style MEMORY fill:#2980B9,color:#fff
    style FOUND fill:#F39C12,color:#fff
    style ADAPT fill:#2980B9,color:#fff
    style BRAINSTORM fill:#E91E63,color:#fff
    style DIRECTFIX fill:#E67E22,color:#fff
    style DIRECTTEST fill:#7B68EE,color:#fff
    style DIRECTPR fill:#2ECC71,color:#fff
    style REVIEW fill:#F39C12,color:#fff
    style PLANMODE fill:#4A90D9,color:#fff
    style QUALITY fill:#E91E63,color:#fff
    style WRITE fill:#4A90D9,color:#fff
    style EXITPLAN fill:#4A90D9,color:#fff
    style VIEWER fill:#2980B9,color:#fff
    style BRANCH fill:#1ABC9C,color:#fff
    style STEP fill:#8E44AD,color:#fff
    style REPLAN fill:#4A90D9,color:#fff
    style STEPBR fill:#1ABC9C,color:#fff
    style TESTFIRST fill:#F39C12,color:#fff
    style IMPLEMENT fill:#3498DB,color:#fff
    style FIXCHECK fill:#2ECC71,color:#fff
    style FIX fill:#E67E22,color:#fff
    style FIXAUDIT fill:#E67E22,color:#fff
    style FIXFINAL fill:#E67E22,color:#fff
    style TEST fill:#7B68EE,color:#fff
    style TDDTEST fill:#3498DB,color:#fff
    style AUDIT fill:#9B59B6,color:#fff
    style AUDITSCAN fill:#3498DB,color:#fff
    style FINALSCAN fill:#3498DB,color:#fff
    style CMAPSCAN fill:#3498DB,color:#fff
    style CMAPSYNTH fill:#9B59B6,color:#fff
    style ORACLE_SCAN fill:#3498DB,color:#fff
    style MAINPR fill:#2ECC71,color:#fff
    style RESEARCH fill:#F39C12,color:#fff
    style EXPLORER fill:#3498DB,color:#fff
    style LIBRARIAN fill:#3498DB,color:#fff
    style ORACLE_ESC fill:#9B59B6,color:#fff
    style FINAL fill:#9B59B6,color:#fff
    style STEPPR fill:#2ECC71,color:#fff
    style MERGE_STEP fill:#27AE60,color:#fff
    style CHECKBOX fill:#2980B9,color:#fff
    style PLANCOMPLETE fill:#27AE60,color:#fff
    style CODEMAP fill:#F39C12,color:#fff
    style LEARN fill:#2980B9,color:#fff
    style MERGE_MAIN fill:#27AE60,color:#fff
    style DONE fill:#27AE60,color:#fff
    style CLEAN fill:#F39C12,color:#fff
    style HOTFIX fill:#E74C3C,color:#fff
    style HOTFIXFIXER fill:#E67E22,color:#fff
    style HOTFIXTEST fill:#7B68EE,color:#fff
    style HOTFIXPR fill:#2ECC71,color:#fff
    style HOTFIXMERGE fill:#27AE60,color:#fff
    style GREENFIELD fill:#16A085,color:#fff
    style GENDOCS fill:#1ABC9C,color:#fff
```

<details>
<summary><strong>Workflow steps explained (18 steps)</strong></summary>

1. **Triage** — Simple → fixer + test + PR. Complex → pattern search. Greenfield → doc-first. Hotfix → fast path.
2. **Pattern Search** — Check knowledge MCP. Match → fixer applies. No match → brainstorm.
3. **Brainstorming** — Explore requirements and design before planning.
3a. **Greenfield: Doc-First** — For new projects: brainstorm → generate docs (PRD, HLA, TRD, DB, API) → plan from docs.
4. **Planning** — plan-plus generates skeleton + step files. User approves.
5. **Branching** — Parent branch from main. Step branches from parent (skip step branches when solo).
6. **Execute Steps** — TDD optional. Fixer implements + writes tests. Parallel independent steps.
6a. **Solo Dev** — Skip step PRs. Commit on parent. Use plan-plus-executor agents per step.
7. **Re-planning** — If a step reveals plan is wrong, revise remaining steps.
8. **Agent Routing** — Explorer/Fixer/Librarian (haiku), Oracle/Designer (sonnet). Oracle is think-only (no file access).
9. **Test + Retry** — 3 failures → explorer reads context → oracle diagnoses. 3 oracle rounds → human intervention.
10. **Security Audit** — Explorer reads full parent diff → Oracle audits from summary. Fixer fixes, explorer re-reads, oracle reviews. Max 3 rounds.
11. **Commit & PR Style** — Two templates: step PR (technical) vs main PR (business + release notes).
12. **Final PR** — Parent → main with release notes. Explorer scans diff → Oracle final review.
12a. **Codebase Map Maintenance** — After approval, Explorer scans touched dirs → Oracle decides → Oracle synthesizes codebase map update → Fixer writes file.
13. **Hotfix** 🔥 — Branch from main, skip planning, inline oracle review, fast merge.
14. **Post-Merge** — Monitor. Rollback via hotfix path if broken.
15. **Learn** — Save patterns for future sessions.
16. **Auto-Dream** — Background memory consolidation.

</details>

---

## Quick Start

### 1. Enable the plugin

Add to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "helmiatwork": {
      "source": {
        "source": "github",
        "repo": "helmiatwork/lean-flow"
      }
    }
  },
  "enabledPlugins": {
    "lean-flow@helmiatwork": true
  }
}
```

### 2. Start a session

Everything else is **automatic**. On first session, lean-flow will:

| Step | What gets installed | Time |
|:-----|:-------------------|:----:|
| 🧠 Knowledge MCP | SQLite + FTS5 pattern memory (6 tools) | ~10s |
| 🔌 Companion Plugins | superpowers + plan-plus (auto-enabled) | ~1s |
| ⚠️ Writing-Plans | Disables superpowers writing-plans skill (conflicts with plan-plus) | ~1s |
| 🔒 Permissions | Auto-allow workflow tools, block protected branches | ~1s |
| 🎭 Playwright | `@playwright/mcp` + Chromium browser | ~30s |
| 📊 Usage Monitor | SwiftBar + launchd fetcher *(macOS only)* | ~15s |
| ⚡ RTK | Rust tool rewrites for faster Bash commands ([rtk-ai.app](https://www.rtk-ai.app)) | ~5s |
| 🗺️ Cartographer | Detect codebase map changes via git, prompt updates | ~2s |
| 📺 Plan Viewer | Live dashboard at localhost:3456 (on ExitPlanMode) | ~1s |
| 📋 Session Briefing | Git state summary | ~1s |

> **Subsequent sessions:** All checks run but skip in <100ms total (idempotent).

### 3. Companion plugins (auto-configured)

lean-flow automatically enables these companion plugins on first session:

| Plugin | Source | Purpose |
|:-------|:-------|:--------|
| **superpowers** | [claude-plugins-official](https://github.com/anthropics/claude-code-plugins) | Skills & workflows (brainstorming, TDD, debugging, etc.) |
| **plan-plus** | [RandyHaylor/plan-plus](https://github.com/RandyHaylor/plan-plus) | Structured planning with skeleton + step files |

> **Important:** lean-flow uses **plan-plus** for planning. The flow is:
> 1. `EnterPlanMode` — opens plan file at `~/.claude/plans/`
> 2. Invoke `writing-plans` skill for quality guidance (how to write good plans)
> 3. Write the plan to the plan mode file (wrong directory blocked by hook)
> 4. `ExitPlanMode` — plan-plus restructures into skeleton + steps, plan viewer opens

> Restart session after first install to activate.

---

## Uninstall

To completely remove lean-flow and all installed components:

```bash
bash /path/to/lean-flow/scripts/uninstall.sh
```

Or if installed as a plugin:
```bash
bash ~/.claude/plugins/cache/lean-flow/*/scripts/uninstall.sh
```

This removes: knowledge MCP, Playwright MCP, SwiftBar monitor, launchd daemon, dream state, and config file. Pattern database deletion requires confirmation.

---

## Configuration

Customize lean-flow by creating `~/.claude/lean-flow.json`:

```json
{
  "protectedBranches": ["main", "master", "staging", "production"],
  "models": {
    "fixer": "sonnet",
    "oracle": "sonnet",
    "explorer": "haiku"
  },
  "dream": {
    "sessions": 5,
    "hours": 24
  },
  "enable": {
    "playwright": true,
    "monitor": true,
    "knowledge": true,
    "rtk": true
  },
  "branchPrefixes": ["feature", "fix", "improvement", "security", "test", "docs", "chore", "hotfix"]
}
```

All fields are optional — defaults are used for any missing field.

---

## Team Usage & CI/CD

**Sharing patterns across a team:**
- Export: `sqlite3 ~/.claude/knowledge/patterns.db ".dump patterns" > patterns.sql`
- Import: `sqlite3 ~/.claude/knowledge/patterns.db < patterns.sql`

**Monorepos:** Use distinct `project` names per service when calling `pattern_store`.

**CI/CD:** lean-flow is designed for interactive Claude Code sessions. For CI, use the workflow doc (`workflows/standard-development-flow.md`) as reference for your pipeline stages.

---

## What's Inside

```
lean-flow/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── agents/
│   ├── oracle.md                # Sonnet — think-only: review, architecture, security (no file access)
│   ├── fixer.md                 # Haiku — all implementation, tests, mechanical changes
│   ├── librarian.md             # Haiku — research, docs
│   ├── designer.md              # Sonnet — UI/UX
│   └── explorer.md              # Haiku — codebase navigation, codebase map scanning, pre-oracle reads
├── skills/
│   └── cartography.md           # Codebase mapping skill (cartographer)
├── hooks/
│   └── hooks.json               # SessionStart, PreToolUse, PostToolUse, Stop
├── scripts/
│   ├── workflow-hook.sh         # ← Single entry point for ALL workflow hooks (routes by event)
│   │                            #   SessionStart → session-briefing
│   │                            #   UserPromptSubmit → pattern-recall + load-workflow + star-clarify
│   │                            #   PostToolUse Write|Edit → enforce-tdd
│   │                            #   PostToolUse EnterPlanMode → knowledge-prefilter
│   │                            #   PostToolUse ExitPlanMode → generate-plan-viewer
│   │                            #   PostToolUse Bash (pr create) → PR notify
│   │                            #   SubagentStop → remind-check-step
│   │                            #   Stop → auto-dream + auto-observe + session-summary (bg)
│   │                            #   PostCompact → session-summary (bg)
│   ├── ensure-knowledge-mcp.sh  # Auto-install SQLite pattern memory
│   ├── ensure-permissions.sh    # Auto-configure workflow permissions
│   ├── ensure-plugins.sh        # Auto-enable superpowers + plan-plus
│   ├── ensure-playwright-mcp.sh # Auto-install Playwright + Chromium
│   ├── ensure-claude-monitor.sh # Auto-install SwiftBar usage monitor
│   ├── ensure-rtk.sh            # Auto-install RTK (Rust tool rewrites)
│   ├── ensure-cartography.sh    # Auto-detect codebase map changes on session start
│   ├── block-protected-push.sh  # Block push to main/master/staging
│   ├── block-no-verify.sh       # Block --no-verify/--no-gpg-sign bypass
│   ├── block-secret-commits.sh  # Block staging .env/credentials files
│   ├── block-claude-identity.sh # Block Claude attribution in commits/PRs
│   ├── block-wrong-plan-dir.sh  # Block plans saved outside ~/.claude/plans/
│   ├── session-briefing.sh      # Git state on session start (called by workflow-hook)
│   ├── pattern-recall.sh        # Knowledge MCP pattern search (called by workflow-hook)
│   ├── load-workflow.sh         # Inject claude-rules.md into context (called by workflow-hook)
│   ├── star-clarify.sh          # Detect vague prompts, ask clarifying questions (called by workflow-hook)
│   ├── enforce-tdd.sh           # Mandatory TDD reminder after file writes (called by workflow-hook)
│   ├── knowledge-prefilter.sh   # Inject patterns into plan context (called by workflow-hook)
│   ├── remind-check-step.sh     # Remind to mark step [x] after subagent (called by workflow-hook)
│   ├── auto-dream.sh            # Memory consolidation via Haiku (background)
│   ├── auto-observe.sh          # Session observations to memory (background)
│   ├── session-summary.sh       # Write session summary (background)
│   ├── auto-compress-output.sh  # Compress high-output Bash commands via Haiku (PreToolUse)
│   ├── auto-update-codemaps.sh  # Update codemaps after git commit (PostToolUse)
│   ├── track-test-failures.sh   # Count test failures, escalate to oracle at 3
│   ├── warn-secret-files.sh     # Warn when writing near secret paths
│   ├── load-config.sh           # Load ~/.claude/lean-flow.json config
│   ├── generate-plan-viewer.sh  # Start/reuse plan server + open browser
│   ├── plan-server.mjs          # Live plan viewer server (SSE + file watch)
│   ├── plan-viewer.mjs          # Static HTML generator (fallback)
│   ├── cartographer.py          # Tier 2: MD5 change detection for per-folder codemaps
│   ├── scan-codebase.py         # Tier 1: codebase scanner with token counts
│   ├── uninstall.sh             # Remove all lean-flow components
│   └── claude-monitor/          # SwiftBar plugin + fetcher daemon
├── templates/
│   ├── PULL_REQUEST_TEMPLATE.md      # Step PR (child → parent)
│   ├── PULL_REQUEST_TEMPLATE_MAIN.md # Feature PR (parent → main) + release notes
│   └── COMMIT_CONVENTION.md          # Commit + PR style guide
├── workflows/
│   └── standard-development-flow.md
├── mcp-servers/
│   └── knowledge/               # SQLite + FTS5 MCP server
│       ├── index.mjs
│       └── package.json
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## Agent Comparison: lean-flow vs ruflo

| Role | ruflo agent | lean-flow agent | Difference |
|:-----|:-----------|:----------------|:-----------|
| Architecture, review & security | `architect.yaml` + `security-architect.yaml` (tags only) | **oracle.md** (sonnet, think-only) | Full instructions, severity levels, PR review, security audit, PII checks. Never reads files — receives summaries from explorer |
| Implementation & testing | `coder.yaml` + `tester.yaml` (tags only) | **fixer.md** (haiku) | All code changes + test writing in one agent, retry behavior |
| Code review | `reviewer.yaml` (tags only) | **oracle.md** (sonnet) | Same agent handles review + architecture + security (saves sonnet calls) |
| Research | *(none)* | **librarian.md** (haiku) | Docs lookup, web search, API reference |
| UI/UX | *(none)* | **designer.md** (sonnet) | Frontend components, accessibility, responsive design |
| Navigation | *(none)* | **explorer.md** (haiku) | Fast file discovery, codebase structure, codebase map scanning, pre-oracle diff reading |

> ruflo agents are YAML stubs (~5 lines each, no instructions). lean-flow agents are full markdown definitions with role, rules, tools, and behavioral constraints.

---

## Inspired By

> lean-flow stands on the shoulders of these projects — taking their best ideas and distilling them into a lightweight plugin.

- **[ruflo](https://github.com/ruvnet/ruflo)** — Enterprise AI agent orchestration with 60+ agent types
- **[oh-my-opencode-slim](https://github.com/ruvnet/oh-my-opencode-slim)** — OpenCode/Claude Code enhancement framework
- **[plan-plus](https://github.com/RandyHaylor/plan-plus)** — Plan mode optimizer (recommended companion)
- **[cartographer](https://github.com/kingbootoshi/cartographer)** — Codebase mapping via parallel AI subagents (Tier 1 atlas)
- **[rtk](https://www.rtk-ai.app)** — Rust token killer — transparent CLI proxy that rewrites dev commands for 60–90% token savings
- **[SwiftBar](https://github.com/swiftbar/SwiftBar)** — macOS menu bar scripting platform powering the usage monitor

---

<div align="center">

**MIT License** · Made by [helmiatwork](https://github.com/helmiatwork)

</div>
