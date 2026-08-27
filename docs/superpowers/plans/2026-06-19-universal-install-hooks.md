# Universal Install — Hooks Installer + Dependency Resolver (Plan 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `bunx lean-flow install` that resolves+installs system dependencies and idempotently wires lean-flow hooks into a teammate's `~/.gemini/settings.json`.

**Architecture:** A Node CLI (`bin/cli.js`) reads two declarative sources of truth (`core/deps.toml`, `core/hook-manifest.json`), probes the target machine, installs missing deps via the OS package manager, copies bundled hook scripts, and merges hook registrations into `settings.json` — all idempotent, with a `.bak` backup and path-prefix-based uninstall.

**Tech Stack:** Node ≥18 (ESM), `node:test` + `node:assert`, `@iarna/toml` for deps.toml, no other runtime deps.

---

## File Structure

- `package.json` — npm package, `bin` entry, `files` allowlist
- `bin/cli.js` — CLI dispatch (`install` / `uninstall` / `update`)
- `src/manifest.js` — load + validate `core/deps.toml` and `core/hook-manifest.json`
- `src/probe.js` — detect binaries (`command -v`) and OS package manager
- `src/plan.js` — compute missing-dep set + render the install plan
- `src/settings.js` — idempotent settings.json merge / removal (path-prefix)
- `src/install.js` — orchestrates probe → plan → copy → merge
- `core/deps.toml`, `core/hook-manifest.json` — data
- `tests/*.test.js` — one per src module + an end-to-end test in a throwaway `$HOME`

---

## Task 1: Package skeleton

**Files:**
- Create: `package.json`
- Create: `bin/cli.js`

- [ ] **Step 1: Write the failing test**

`tests/cli.test.js`:
```js
import { test } from 'node:test'
import assert from 'node:assert'
import { execFileSync } from 'node:child_process'

test('cli prints usage when no subcommand', () => {
  const out = execFileSync('node', ['bin/cli.js'], { encoding: 'utf8' })
  assert.match(out, /usage: lean-flow <install\|uninstall\|update>/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/cli.test.js`
Expected: FAIL — `Cannot find module 'bin/cli.js'`

- [ ] **Step 3: Write package.json + cli.js**

`package.json`:
```json
{
  "name": "lean-flow",
  "version": "3.0.0",
  "type": "module",
  "bin": { "lean-flow": "./bin/cli.js" },
  "files": ["bin", "src", "core", "hooks", "NOTICE"],
  "engines": { "node": ">=18" },
  "dependencies": { "@iarna/toml": "^2.2.5" },
  "scripts": { "test": "node --test" }
}
```

`bin/cli.js`:
```js
#!/usr/bin/env node
const cmd = process.argv[2]
const cmds = {
  install: async () => (await import('../src/install.js')).install(),
  uninstall: async () => (await import('../src/install.js')).uninstall(),
  update: async () => (await import('../src/install.js')).install()
}
if (cmds[cmd]) await cmds[cmd]()
else console.log('usage: lean-flow <install|uninstall|update>')
```

- [ ] **Step 4: Run test, verify it passes**

Run: `npm install && node --test tests/cli.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add package.json bin/cli.js tests/cli.test.js
git commit -m "feat: add lean-flow cli skeleton"
```

---

## Task 2: Manifest loader

**Files:**
- Create: `core/deps.toml`
- Create: `core/hook-manifest.json`
- Create: `src/manifest.js`
- Test: `tests/manifest.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { loadDeps, loadHooks } from '../src/manifest.js'

test('loadDeps returns redis with brew formula', () => {
  const deps = loadDeps()
  assert.equal(deps.redis.brew, 'redis')
  assert.equal(deps.redis.service, true)
})

test('loadHooks returns entries with event + script', () => {
  const hooks = loadHooks()
  assert.ok(hooks.length > 0)
  for (const h of hooks) {
    assert.ok(h.event, 'has event')
    assert.ok(h.script, 'has script')
  }
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/manifest.test.js`
Expected: FAIL — `Cannot find module '../src/manifest.js'`

- [ ] **Step 3: Write data + loader**

`core/deps.toml`:
```toml
[redis]
brew = "redis"
apt = "redis-server"
service = true
role = "pattern-memory backing store"

[node]
runtime = ">=18"
role = "js hooks + proxy"
```

`core/hook-manifest.json`:
```json
[
  { "event": "UserPromptSubmit", "script": "leanflow-grammar-check.sh", "runner": "bash" },
  { "event": "SessionStart", "script": "leanflow-fix.sh", "runner": "bash" }
]
```

`src/manifest.js`:
```js
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import TOML from '@iarna/toml'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

export function loadDeps() {
  return TOML.parse(readFileSync(join(ROOT, 'core/deps.toml'), 'utf8'))
}
export function loadHooks() {
  return JSON.parse(readFileSync(join(ROOT, 'core/hook-manifest.json'), 'utf8'))
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/manifest.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add core/deps.toml core/hook-manifest.json src/manifest.js tests/manifest.test.js
git commit -m "feat: add deps + hook manifest loaders"
```

---

## Task 3: Binary + package-manager probe

**Files:**
- Create: `src/probe.js`
- Test: `tests/probe.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { hasBinary, detectPkgManager } from '../src/probe.js'

test('hasBinary true for node', () => {
  assert.equal(hasBinary('node'), true)
})
test('hasBinary false for nonsense binary', () => {
  assert.equal(hasBinary('definitely-not-a-real-binary-xyz'), false)
})
test('detectPkgManager returns a known manager or null', () => {
  assert.ok(['brew', 'apt', 'dnf', null].includes(detectPkgManager()))
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/probe.test.js`
Expected: FAIL — `Cannot find module '../src/probe.js'`

- [ ] **Step 3: Write probe**

`src/probe.js`:
```js
import { execFileSync } from 'node:child_process'

export function hasBinary(name) {
  try {
    execFileSync('command', ['-v', name], { stdio: 'ignore', shell: '/bin/bash' })
    return true
  } catch {
    return false
  }
}

export function detectPkgManager() {
  for (const m of ['brew', 'apt', 'dnf']) {
    if (hasBinary(m)) return m
  }
  return null
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/probe.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/probe.js tests/probe.test.js
git commit -m "feat: add binary + package-manager probe"
```

---

## Task 4: Missing-dep set + plan rendering

**Files:**
- Create: `src/plan.js`
- Test: `tests/plan.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { computeMissing, renderPlan } from '../src/plan.js'

const deps = {
  redis: { brew: 'redis', role: 'store' },
  node: { runtime: '>=18', role: 'runtime' }
}

test('computeMissing flags deps whose binary is absent', () => {
  const missing = computeMissing(deps, name => name === 'node') // only node present
  assert.deepEqual(missing.map(d => d.name), ['redis'])
})

test('renderPlan lists names to install', () => {
  const missing = [{ name: 'redis', spec: deps.redis }]
  const txt = renderPlan(missing)
  assert.match(txt, /Will install: redis/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/plan.test.js`
Expected: FAIL — `Cannot find module '../src/plan.js'`

- [ ] **Step 3: Write plan module**

`src/plan.js`:
```js
export function computeMissing(deps, present) {
  // `present(name)` returns true if the dependency is already installed.
  // runtime-only deps (no install target) are checked but never "installed" by us.
  return Object.entries(deps)
    .filter(([name]) => !present(name))
    .map(([name, spec]) => ({ name, spec }))
}

export function renderPlan(missing) {
  if (missing.length === 0) return 'All dependencies present.'
  return `Will install: ${missing.map(d => d.name).join(', ')}`
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/plan.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/plan.js tests/plan.test.js
git commit -m "feat: add missing-dep computation + plan rendering"
```

---

## Task 5: Idempotent settings.json merge (with path rewrite)

**Files:**
- Create: `src/settings.js`
- Test: `tests/settings.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { mergeHooks, removeHooks } from '../src/settings.js'

const hooks = [{ event: 'SessionStart', script: 'leanflow-fix.sh', runner: 'bash' }]
const HOME = '/home/teammate'

test('mergeHooks rewrites path to target HOME', () => {
  const out = mergeHooks({}, hooks, HOME)
  const cmd = out.hooks.SessionStart[0].hooks[0].command
  assert.equal(cmd, 'bash /home/teammate/.gemini/hooks/leanflow-fix.sh')
})

test('mergeHooks is idempotent — no duplicate on second run', () => {
  let out = mergeHooks({}, hooks, HOME)
  out = mergeHooks(out, hooks, HOME)
  assert.equal(out.hooks.SessionStart.length, 1)
})

test('mergeHooks preserves unrelated existing hooks', () => {
  const existing = { hooks: { SessionStart: [{ hooks: [{ command: 'bash /other.sh' }] }] } }
  const out = mergeHooks(existing, hooks, HOME)
  assert.equal(out.hooks.SessionStart.length, 2)
})

test('removeHooks deletes only lean-flow entries by path prefix', () => {
  let out = mergeHooks({ hooks: { SessionStart: [{ hooks: [{ command: 'bash /other.sh' }] }] } }, hooks, HOME)
  out = removeHooks(out, HOME)
  assert.equal(out.hooks.SessionStart.length, 1)
  assert.equal(out.hooks.SessionStart[0].hooks[0].command, 'bash /other.sh')
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/settings.test.js`
Expected: FAIL — `Cannot find module '../src/settings.js'`

- [ ] **Step 3: Write settings module**

`src/settings.js`:
```js
const PREFIX = home => `${home}/.gemini/hooks/`

function commandFor(hook, home) {
  return `${hook.runner} ${PREFIX(home)}${hook.script}`
}

export function mergeHooks(settings, hooks, home) {
  const out = structuredClone(settings)
  out.hooks ??= {}
  for (const h of hooks) {
    out.hooks[h.event] ??= []
    const command = commandFor(h, home)
    const already = out.hooks[h.event].some(group =>
      (group.hooks ?? []).some(e => e.command === command))
    if (!already) {
      out.hooks[h.event].push({ hooks: [{ type: 'command', command }] })
    }
  }
  return out
}

export function removeHooks(settings, home) {
  const out = structuredClone(settings)
  const prefix = PREFIX(home)
  for (const event of Object.keys(out.hooks ?? {})) {
    out.hooks[event] = out.hooks[event].filter(group =>
      !(group.hooks ?? []).some(e => (e.command ?? '').includes(prefix)))
  }
  return out
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/settings.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/settings.js tests/settings.test.js
git commit -m "feat: idempotent settings.json hook merge with path-prefix removal"
```

---

## Task 6: Install orchestration + hook copy (end-to-end in throwaway HOME)

**Files:**
- Create: `src/install.js`
- Create: `hooks/leanflow-fix.sh`, `hooks/leanflow-grammar-check.sh`
- Test: `tests/install.e2e.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { mkdtempSync, readFileSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { install, uninstall } from '../src/install.js'

test('install copies hooks + writes settings + backup; uninstall reverts', () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-'))
  install({ home: HOME, skipDeps: true })            // skipDeps avoids real brew calls

  assert.ok(existsSync(join(HOME, '.gemini/hooks/leanflow-fix.sh')), 'hook copied')
  const s = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.ok(s.hooks.SessionStart.some(g => g.hooks[0].command.includes('leanflow-fix.sh')))

  install({ home: HOME, skipDeps: true })            // idempotent
  const s2 = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.equal(
    s2.hooks.SessionStart.filter(g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 1)

  uninstall({ home: HOME })
  const s3 = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.equal((s3.hooks.SessionStart ?? []).filter(
    g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 0)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/install.e2e.test.js`
Expected: FAIL — `Cannot find module '../src/install.js'`

- [ ] **Step 3: Write hooks + install orchestration**

`hooks/leanflow-fix.sh`:
```bash
#!/usr/bin/env bash
# lean-flow session-start injector (placeholder body; real logic ported separately)
echo '{"continue": true}'
```
`hooks/leanflow-grammar-check.sh`:
```bash
#!/usr/bin/env bash
# lean-flow grammar/English check (placeholder body; real logic ported separately)
echo '{"continue": true}'
```

`src/install.js`:
```js
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadHooks, loadDeps } from './manifest.js'
import { detectPkgManager, hasBinary } from './probe.js'
import { computeMissing, renderPlan } from './plan.js'
import { mergeHooks, removeHooks } from './settings.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

function readSettings(path) {
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : {}
}

export function install({ home = homedir(), skipDeps = false } = {}) {
  const hooksDir = join(home, '.gemini/hooks')
  const settingsPath = join(home, '.gemini/settings.json')
  mkdirSync(hooksDir, { recursive: true })

  if (!skipDeps) {
    const deps = loadDeps()
    const missing = computeMissing(deps, hasBinary)
    console.log(renderPlan(missing))
    // NOTE: real dep execution (brew/apt) lands in Task 7 of a follow-up plan.
  }

  cpSync(join(ROOT, 'hooks'), hooksDir, { recursive: true })

  const current = readSettings(settingsPath)
  if (existsSync(settingsPath)) copyFileSync(settingsPath, settingsPath + '.bak')
  const merged = mergeHooks(current, loadHooks(), home)
  writeFileSync(settingsPath, JSON.stringify(merged, null, 2))
  console.log('lean-flow hooks installed → ' + hooksDir)
}

export function uninstall({ home = homedir() } = {}) {
  const settingsPath = join(home, '.gemini/settings.json')
  const current = readSettings(settingsPath)
  const cleaned = removeHooks(current, home)
  writeFileSync(settingsPath, JSON.stringify(cleaned, null, 2))
  console.log('lean-flow hooks removed')
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/install.e2e.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/install.js hooks/ tests/install.e2e.test.js
git commit -m "feat: end-to-end hook install/uninstall with settings backup"
```

---

## Task 7: Full suite + NOTICE

**Files:**
- Create: `NOTICE`
- Test: run all

- [ ] **Step 1: Write NOTICE**

`NOTICE`:
```
lean-flow bundles third-party hook scripts. Each retains its original license:
- omni — MIT (github.com/fajarhide/omni)
- gsd, caveman — license pending audit; see docs/superpowers/specs follow-ups
```

- [ ] **Step 2: Run the full suite**

Run: `node --test`
Expected: PASS — all test files green

- [ ] **Step 3: Commit**

```bash
git add NOTICE
git commit -m "docs: add NOTICE for bundled third-party hooks"
```

---

## Out of scope for this plan (follow-ups)

- **Real dependency execution** (`brew install` / `apt install` + `brew services start redis`) with the one-shot plan confirmation and `--yes` / `--no-bootstrap` flags. Stubbed here behind `renderPlan`; lands in its own plan because it needs OS-matrix testing.
- **OpenCode adapter** (second delivery target).
- **The request proxy** — Plan 2.
- **Porting real hook bodies** (grammar-check, lean-flow-fix logic) — current scripts are passthrough placeholders so the wiring is testable independently of the logic.
