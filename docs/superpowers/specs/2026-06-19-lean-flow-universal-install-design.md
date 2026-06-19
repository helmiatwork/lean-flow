# lean-flow Universal Install + Proxy — Design

**Date:** 2026-06-19
**Status:** Approved (brainstorm)
**Author:** helmiatwork

## Problem

lean-flow today is a Claude Code marketplace plugin. Its real value — agents, skills,
and especially the **hooks** (grammar/English check, STAR classifier, workflow-enforce,
block-* guards) plus their backing services — lives as hand-wired entries in
`~/.claude/settings.json` with hardcoded machine-local paths. Putting it on a teammate's
machine means hand-copying scripts, hand-editing settings, and manually installing every
external dependency (omni binary, node runtime, redis, gsd/caveman plugins).

**Goal:** one command — `bunx lean-flow@latest install` — installs lean-flow *and its
full dependency tree*, the way bundling Sidekiq pulls in Redis. It must also work beyond
Claude Code: any editor, via a request proxy.

## Goals

- Single-command install that resolves and installs **transitive dependencies** (package-manager UX).
- Cross-editor: Claude Code + OpenCode via native hooks; all other editors via a request proxy.
- Idempotent, non-destructive `install` / `update` / `uninstall`.
- One shared ruleset (`core/`) so behavior is identical whether enforced by a hook or the proxy.

## Non-goals

- MITM TLS interception. Proxy uses base-URL redirect only; cert-pinned tools are out of scope.
- Per-repo artifacts (gitnexus index) — referenced, never bundled.
- Full parity of hook *enforcement* on editors with no hook system (degrades to proxy-injected rules).

## Decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Hook scope | **Whole personal kit** (lean-flow + gsd + caveman + omni + gitnexus) |
| First target | **Both in parallel** (hooks adapter + proxy), sequenced behind a shared core |
| Distribution | **npm `bunx` installer** |
| Uninstall marker | **Path-prefix detection** (entries pointing at `~/.claude/hooks/` lean-flow scripts) |
| Missing deps | **Auto-bootstrap** (manifest-driven resolver) |
| 3rd-party scripts | **Bundle everything** + `NOTICE` with licenses/attribution |

## Architecture — 4 units + shared core

```
lean-flow/
  core/                      SOURCE OF TRUTH
    rules/                   grammar rules, STAR classifier, workflow rules
    hook-manifest.json       every hook: event, script, external dep, bootstrap cmd
    deps.toml                declarative system-dependency manifest (Gemfile equivalent)
  hooks/                     bundled scripts (lean-flow's own + third-party, per decision)
  proxy/                     Unit B runtime
  adapters/{claude,opencode} Unit A emitters
  resolver/                  Unit C: dependency resolver + executor
  bin/cli.js                 bunx entrypoint
  NOTICE                     third-party licenses + attribution
```

### Unit A — npm installer (Claude Code + OpenCode hooks)
`bunx lean-flow@latest install`. Copies bundled scripts → `~/.claude/hooks/`, **resolves
binaries on the target** (`command -v node`; never the author's `.nodenv` path),
**idempotently merges** into `settings.json`.

### Unit B — request proxy (all other editors)
Local server bound to `127.0.0.1`, base-URL redirect (`ANTHROPIC_BASE_URL` /
`OPENAI_BASE_URL`), per-provider adapters (Anthropic Messages first, then OpenAI Chat),
SSE passthrough, middleware that injects the same `core/` rules on the wire.

### Unit C — dependency resolver (the core feature)
Manifest-driven, OS-aware. Reads `deps.toml`, probes the target, computes the missing set,
shows one plan, installs missing deps (brew/apt/dnf/plugin), and starts daemon services
(e.g. `brew services start redis`).

### core/ — one brain, two delivery mechanisms
```
Claude Code / OpenCode ──► native hook ──┐
                                          ├─► core/ rules (grammar, STAR, workflow)
Cursor / Aider / Copilot ──► proxy ───────┘
```

## Dependency manifest (deps.toml) — example

```toml
[redis]  brew = "redis"               apt = "redis-server"   service = true   role = "pattern-memory backing store"
[omni]   brew = "fajarhide/tap/omni"                                          role = "context-distiller hook"
[node]   runtime = ">=18"                                                     role = "js hooks + proxy"
[gsd]    plugin = "gsd"                                                       role = "gsd-* hooks"
```

## Installer flow (Unit A + C)

```
bunx lean-flow install
  1. read core/deps.toml + core/hook-manifest.json
  2. probe target: command -v redis/omni/node; detect brew|apt|dnf
  3. compute MISSING dependency set
  4. show ONE plan:  "Will install: redis, omni  (node ✓)"  → [Y/n]   (--yes to skip)
  5. install missing (brew/apt/plugin); start daemon services
  6. copy hooks/* → ~/.claude/hooks/
  7. for each manifest entry:
       resolve binary; cmd = `bash ${TARGET_HOME}/.claude/hooks/<script>`   (rewritten)
       merge into settings.hooks[event] IF absent (dedupe by command)
  8. backup settings.json → settings.json.bak; write
  9. report what is live
```

`uninstall` / `update`: **path-prefix detection** — operate only on entries whose command
points at lean-flow scripts under `~/.claude/hooks/`. The teammate's other hooks are untouched.

## Build order ("both parallel", sequenced safely)

- **Phase 0:** `core/` + `hook-manifest.json` + `deps.toml` + package skeleton. *Blocks everything.*
- **Phase 1a (parallel):** Unit A installer + idempotent merge + uninstall.
- **Phase 1b (parallel):** Unit B proxy (Anthropic adapter, streaming, middleware).
- **Phase 1c (parallel):** Unit C resolver (probe, plan, install, services).
- **Phase 2:** wire C into A; cross-editor verification.

## Error handling & risks

| Risk | Mitigation |
|---|---|
| settings.json clobber | read-merge-write + `.bak` backup + dedupe by command |
| Literal author paths leak | always recompute from target `$HOME` + `command -v` |
| Auto-bootstrap invasive | one plan-confirmation (package-manager style); `--yes`, `--no-bootstrap`; never root |
| Bundle-everything licensing | `NOTICE` + attribution; gsd/caveman license = open follow-up risk |
| Proxy leaks secrets | bind `127.0.0.1` only; never log keys; document plaintext handling |
| Cert-pinned tools | out of scope; documented limitation |

## Testing

- **Installer:** shell tests in a throwaway `$HOME` — fresh install, **idempotency**
  (run twice = no dupes), uninstall removes *only* lean-flow entries, path-rewrite correctness.
- **Resolver:** unit tests with mocked `command -v` / package managers — missing-set
  computation, plan rendering, OS detection.
- **Proxy:** node tests against a mock provider — request mutation, SSE passthrough
  byte-for-byte, header preservation.

## Open follow-ups

- Audit gsd/caveman licenses; switch from "bundle" to "reference" if redistribution is disallowed.
- Linux package-manager coverage beyond apt (dnf/pacman).
- OpenAI / Gemini proxy adapters after Anthropic ships.
