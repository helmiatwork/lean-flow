<div align="center">

# lean-flow

**Lightweight dev workflow plugin for Claude Code**

*Same workflow as ruflo/claude-flow. 3 tools instead of 300+. 1/60th the token cost.*

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
| MCP tools registered | 300+ | **3** |
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
| `project_context` | Store/retrieve project summary & conventions |

### 🤖 Parallel Agents

| Agent | Model | Role |
|:------|:-----:|:-----|
| **Oracle** | Opus | Architecture review, code review, stuck diagnosis |
| **Fixer** | Sonnet | Implementation, bug fixes, tests |
| **Auditor** | Sonnet | Security scan, diff risk, vulnerability detection |
| **Tester** | Sonnet | Dedicated test writer, coverage improvement |
| **Librarian** | Sonnet | Docs lookup, web search, research |
| **Designer** | Sonnet | UI/UX, frontend components |
| **Explorer** | Haiku | File discovery, codebase navigation |

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

Steps append `/step-N`: `feature/onboarding/step-1`

### 🔒 Safety Hooks
- **Block** direct push to `main` / `master` / `staging`
- **Block** `--no-verify` flag on git commands
- **Auto-allow** workflow tools (Agent, Tasks, PlanMode) — no permission prompts

### 📊 Usage Monitor *(macOS)*
SwiftBar menu bar plugin showing real-time Claude Code usage:
- Session %, weekly %, sonnet % with reset countdown
- Color-coded: 🟢 <50% · 🟡 50-80% · 🔴 >80%
- Auto-refresh via launchd daemon (every 3 min)

### 🎭 E2E Testing
Auto-installs [Playwright MCP](https://github.com/anthropics/anthropic-quickstarts/tree/main/mcp-playwright) for browser automation testing.

### 🎯 Skills (via superpowers plugin)

lean-flow auto-enables the [superpowers](https://github.com/anthropics/claude-code-plugins) plugin which provides these skills used in the workflow:

| Skill | When it's used |
|:------|:---------------|
| `brainstorming` | Before any creative/feature work — explores intent and design |
| `writing-plans` | When creating implementation plans (feeds into plan-plus) |
| `test-driven-development` | Before writing implementation code |
| `systematic-debugging` | When encountering bugs or test failures |
| `verification-before-completion` | Before claiming work is done or creating PRs |
| `receiving-code-review` | When processing oracle's review feedback |
| `finishing-a-development-branch` | When implementation is complete, deciding merge/PR/cleanup |
| `using-git-worktrees` | When feature work needs isolation from main workspace |

> Skills are invoked automatically when their context matches. No manual activation needed.

### 💤 Auto-Dream
Background memory consolidation using Haiku. Runs every 5 sessions / 24 hours. Cleans up stale memories, merges duplicates, prunes outdated entries.

---

## Workflow

```mermaid
flowchart TD
    USER(["User prompt"]) --> TRIAGE

    TRIAGE{"Orchestrator triages\ncomplexity"}
    TRIAGE -->|"Simple"| DIRECT["Handle directly"]
    TRIAGE -->|"Complex"| MEMORY

    MEMORY["pattern_search"] --> FOUND

    FOUND{"Match?"}
    FOUND -->|"Yes"| ADAPT["Apply pattern"]
    FOUND -->|"No"| PP

    ADAPT --> BRANCH
    DIRECT --> DONE(["Done"])

    PP["plan-plus"] --> REVIEW

    REVIEW{"Approved?"}
    REVIEW -->|"No"| PP
    REVIEW -->|"Yes"| BRANCH

    BRANCH["Create parent branch\nfeature/name"] --> STEP

    STEP{"Next step?"}
    STEP -->|"Yes"| STEPBR["Step branch\nfeature/name/step-N"]
    STEP -->|"All done"| AUDIT

    STEPBR --> FIX["Fixer agents\n(parallel within step)"]
    FIX --> TEST["Run tests"]
    TEST -->|"Fail x3"| ORACLE_ESC["Oracle diagnosis"]
    ORACLE_ESC --> FIX
    TEST -->|"Pass"| STEPPR["PR step → parent"]

    STEPPR --> STEPREV["Oracle reviews step"]
    STEPREV -->|"Issues"| FIX
    STEPREV -->|"Approved"| MERGE_STEP["Merge to parent"]
    MERGE_STEP --> STEP

    AUDIT["Security audit\nfull parent diff"] --> CLEAN

    CLEAN{"Issues?"}
    CLEAN -->|"Found"| FIXAUDIT["Oracle fix PR\n→ parent"]
    CLEAN -->|"Clean"| MAINPR

    FIXAUDIT --> AUDIT

    MAINPR["PR parent → main"] --> FINAL["Oracle final review"]
    FINAL -->|"Issues"| FIXFINAL["Fix on parent"]
    FINAL -->|"Approved"| LEARN

    FIXFINAL --> FINAL
    LEARN["pattern_store"] --> MERGE(["Merge to main"])

    style USER fill:#34495E,color:#fff
    style TRIAGE fill:#8E44AD,color:#fff
    style MEMORY fill:#2980B9,color:#fff
    style FOUND fill:#F39C12,color:#fff
    style ADAPT fill:#2980B9,color:#fff
    style DIRECT fill:#27AE60,color:#fff
    style PP fill:#4A90D9,color:#fff
    style REVIEW fill:#F39C12,color:#fff
    style BRANCH fill:#1ABC9C,color:#fff
    style STEP fill:#8E44AD,color:#fff
    style STEPBR fill:#1ABC9C,color:#fff
    style FIX fill:#E67E22,color:#fff
    style FIXAUDIT fill:#E67E22,color:#fff
    style FIXFINAL fill:#E67E22,color:#fff
    style TEST fill:#7B68EE,color:#fff
    style AUDIT fill:#E74C3C,color:#fff
    style MAINPR fill:#2ECC71,color:#fff
    style ORACLE_ESC fill:#9B59B6,color:#fff
    style FINAL fill:#9B59B6,color:#fff
    style STEPPR fill:#2ECC71,color:#fff
    style STEPREV fill:#9B59B6,color:#fff
    style MERGE_STEP fill:#27AE60,color:#fff
    style LEARN fill:#2980B9,color:#fff
    style MERGE fill:#27AE60,color:#fff
    style DONE fill:#27AE60,color:#fff
    style CLEAN fill:#F39C12,color:#fff
```

<details>
<summary><strong>Workflow steps explained</strong></summary>

1. **Triage** — Simple tasks handled directly. Complex tasks go to pattern search.
2. **Pattern Search** — Check if this problem was solved before. If yes, reuse the pattern.
3. **Plan** — Generate structured plan via [plan-plus](https://github.com/RandyHaylor/plan-plus). User reviews and approves.
4. **Branch** — Create parent branch `feature/name` from main.
5. **Steps** — For each step: create `feature/name/step-N` branch → fixer implements → tests pass → PR into parent → oracle reviews → merge into parent.
6. **Retry** — Failed tests retry twice. Third failure escalates to Oracle for diagnosis.
7. **Audit** — After all steps merged into parent: security scan on full diff. Oracle fixes issues via PR into parent.
8. **Final PR** — PR parent branch → main. Oracle final review on complete feature.
9. **Learn** — Save successful patterns via `pattern_store` for future sessions.

</details>

---

## Quick Start

### 1. Enable the plugin

Add to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "lean-flow": {
      "source": {
        "source": "github",
        "repo": "helmiatwork/lean-flow"
      }
    }
  },
  "enabledPlugins": {
    "lean-flow@lean-flow": true
  }
}
```

### 2. Start a session

Everything else is **automatic**. On first session, lean-flow will:

| Step | What gets installed | Time |
|:-----|:-------------------|:----:|
| 🧠 Knowledge MCP | SQLite + FTS5 pattern memory (3 tools) | ~10s |
| 🔌 Companion Plugins | superpowers + plan-plus (auto-enabled) | ~1s |
| 🔒 Permissions | Auto-allow workflow tools, block protected branches | ~1s |
| 🎭 Playwright | `@playwright/mcp` + Chromium browser | ~30s |
| 📊 Usage Monitor | SwiftBar + launchd fetcher *(macOS only)* | ~15s |
| 📋 Session Briefing | Git state summary | ~1s |

> **Subsequent sessions:** All checks run but skip in <100ms total (idempotent).

### 3. Companion plugins (auto-configured)

lean-flow automatically enables these companion plugins on first session:

| Plugin | Source | Purpose |
|:-------|:-------|:--------|
| **superpowers** | [claude-plugins-official](https://github.com/anthropics/claude-code-plugins) | Skills & workflows (brainstorming, TDD, debugging, etc.) |
| **plan-plus** | [RandyHaylor/plan-plus](https://github.com/RandyHaylor/plan-plus) | Structured planning with skeleton + step files |

> No manual configuration needed. Restart session after first install to activate.

---

## What's Inside

```
lean-flow/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── agents/
│   ├── oracle.md                # Opus — code review, architecture
│   ├── fixer.md                 # Sonnet — implementation
│   ├── auditor.md               # Sonnet — security scan, diff risk
│   ├── tester.md                # Sonnet — dedicated test writer
│   ├── librarian.md             # Sonnet — research, docs
│   ├── designer.md              # Sonnet — UI/UX
│   └── explorer.md              # Haiku — codebase navigation
├── hooks/
│   └── hooks.json               # SessionStart, PreToolUse, PostToolUse, Stop
├── scripts/
│   ├── ensure-knowledge-mcp.sh  # Auto-install SQLite pattern memory
│   ├── ensure-permissions.sh    # Auto-configure workflow permissions
│   ├── ensure-playwright-mcp.sh # Auto-install Playwright + Chromium
│   ├── ensure-claude-monitor.sh # Auto-install SwiftBar usage monitor
│   ├── block-protected-push.sh  # Block push to main/master/staging
│   ├── block-no-verify.sh       # Block --no-verify bypass
│   ├── session-briefing.sh      # Git state on session start
│   ├── auto-dream.sh            # Memory consolidation (background)
│   ├── auto-dream-prompt.md     # Dream agent instructions
│   └── claude-monitor/          # SwiftBar plugin + fetcher daemon
├── workflows/
│   └── standard-development-flow.md
├── mcp-servers/
│   └── knowledge/               # SQLite + FTS5 MCP server
│       ├── index.mjs
│       └── package.json
└── README.md
```

---

## Inspired By

> lean-flow stands on the shoulders of these projects — taking their best ideas and distilling them into a lightweight plugin.

- **[ruflo](https://github.com/ruvnet/ruflo)** — Enterprise AI agent orchestration with 60+ agent types
- **[oh-my-opencode-slim](https://github.com/ruvnet/oh-my-opencode-slim)** — OpenCode/Claude Code enhancement framework
- **[plan-plus](https://github.com/RandyHaylor/plan-plus)** — Plan mode optimizer (recommended companion)

---

<div align="center">

**MIT License** · Made by [helmiatwork](https://github.com/helmiatwork)

</div>
