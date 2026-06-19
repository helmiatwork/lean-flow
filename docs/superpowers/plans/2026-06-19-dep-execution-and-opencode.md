# Dependency Execution Engine + OpenCode Adapter + Real Hook Bodies (Plan 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make `bunx lean-flow install` actually install missing system dependencies (brew/apt) and start daemon services, support OpenCode as a second target, and ship the real hook bodies.

**Architecture:** A new `src/executor.js` turns a missing-dep list into real package-manager calls behind a one-shot confirmation gate (`--yes`, `--no-bootstrap`). `src/install.js` is extended to call it. `src/targets.js` abstracts per-editor settings paths (Claude Code, OpenCode). Real hook scripts replace the placeholders.

**Tech Stack:** Node ≥18 ESM, `node:test`. Builds on Plan 1 modules (`manifest`, `probe`, `plan`, `settings`).

**Depends on:** Plan 1 merged into this branch (`feature/universal-install`).

---

## File Structure

- `src/executor.js` — install a dep via the detected package manager; start services
- `src/confirm.js` — one-shot plan confirmation (TTY prompt; bypass with `--yes`)
- `src/targets.js` — per-editor settings path resolver (Claude Code, OpenCode)
- `src/install.js` — MODIFY: call executor; accept flags
- `bin/cli.js` — MODIFY: parse `--yes` / `--no-bootstrap` / `--target`
- `hooks/leanflow-grammar-check.sh`, `hooks/leanflow-fix.sh` — REPLACE placeholders with real bodies
- `tests/executor.test.js`, `tests/targets.test.js`, `tests/confirm.test.js`

---

## Task 1: Dep→command mapping

**Files:**
- Create: `src/executor.js`
- Test: `tests/executor.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { installCommand, serviceCommand } from '../src/executor.js'

test('installCommand builds brew install for a brew dep', () => {
  const cmd = installCommand('brew', { brew: 'redis' })
  assert.deepEqual(cmd, ['brew', ['install', 'redis']])
})
test('installCommand builds apt-get install for an apt dep', () => {
  const cmd = installCommand('apt', { apt: 'redis-server' })
  assert.deepEqual(cmd, ['sudo', ['apt-get', 'install', '-y', 'redis-server']])
})
test('installCommand returns null when manager has no mapping', () => {
  assert.equal(installCommand('apt', { brew: 'redis' }), null)
})
test('serviceCommand starts a brew service when service=true', () => {
  assert.deepEqual(serviceCommand('brew', 'redis', { service: true, brew: 'redis' }),
    ['brew', ['services', 'start', 'redis']])
})
test('serviceCommand returns null when not a service', () => {
  assert.equal(serviceCommand('brew', 'node', { service: false }), null)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/executor.test.js`
Expected: FAIL — `Cannot find module '../src/executor.js'`

- [ ] **Step 3: Write executor mapping (pure functions, no side effects yet)**

`src/executor.js`:
```js
export function installCommand(manager, spec) {
  if (manager === 'brew' && spec.brew) return ['brew', ['install', spec.brew]]
  if (manager === 'apt' && spec.apt) return ['sudo', ['apt-get', 'install', '-y', spec.apt]]
  if (manager === 'dnf' && spec.dnf) return ['sudo', ['dnf', 'install', '-y', spec.dnf]]
  return null
}

export function serviceCommand(manager, name, spec) {
  if (!spec.service) return null
  if (manager === 'brew') return ['brew', ['services', 'start', spec.brew ?? name]]
  return ['sudo', ['systemctl', 'enable', '--now', spec.apt ?? spec.dnf ?? name]]
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/executor.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/executor.js tests/executor.test.js
git commit -m "feat: map dependencies to package-manager install/service commands"
```

---

## Task 2: Executor runner (side-effecting, with injected spawn for testability)

**Files:**
- Modify: `src/executor.js`
- Test: `tests/executor.test.js`

- [ ] **Step 1: Add failing test**

Append to `tests/executor.test.js`:
```js
import { installAll } from '../src/executor.js'

test('installAll runs install then service for each missing dep via injected runner', () => {
  const calls = []
  const runner = (bin, args) => calls.push([bin, ...args])
  const missing = [{ name: 'redis', spec: { brew: 'redis', service: true } }]
  installAll('brew', missing, { run: runner })
  assert.deepEqual(calls, [
    ['brew', 'install', 'redis'],
    ['brew', 'services', 'start', 'redis']
  ])
})

test('installAll throws when no install command can be built', () => {
  const missing = [{ name: 'x', spec: {} }]
  assert.throws(() => installAll('brew', missing, { run: () => {} }), /no install command/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/executor.test.js`
Expected: FAIL — `installAll is not a function`

- [ ] **Step 3: Implement installAll**

Append to `src/executor.js`:
```js
import { execFileSync } from 'node:child_process'

const defaultRun = (bin, args) => execFileSync(bin, args, { stdio: 'inherit' })

export function installAll(manager, missing, { run = defaultRun } = {}) {
  for (const { name, spec } of missing) {
    const inst = installCommand(manager, spec)
    if (!inst) throw new Error(`no install command for ${name} on ${manager}`)
    run(inst[0], inst[1])
    const svc = serviceCommand(manager, name, spec)
    if (svc) run(svc[0], svc[1])
  }
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/executor.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/executor.js tests/executor.test.js
git commit -m "feat: execute dependency installs + service starts with injectable runner"
```

---

## Task 3: One-shot confirmation gate

**Files:**
- Create: `src/confirm.js`
- Test: `tests/confirm.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { shouldProceed } from '../src/confirm.js'

test('shouldProceed true immediately when yes flag set', async () => {
  assert.equal(await shouldProceed(['redis'], { yes: true, ask: async () => 'n' }), true)
})
test('shouldProceed false when nothing missing', async () => {
  assert.equal(await shouldProceed([], { ask: async () => 'n' }), false)
})
test('shouldProceed reflects user answer y', async () => {
  assert.equal(await shouldProceed(['redis'], { ask: async () => 'y' }), true)
})
test('shouldProceed reflects user answer n', async () => {
  assert.equal(await shouldProceed(['redis'], { ask: async () => 'n' }), false)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/confirm.test.js`
Expected: FAIL — `Cannot find module '../src/confirm.js'`

- [ ] **Step 3: Write confirm**

`src/confirm.js`:
```js
import { createInterface } from 'node:readline/promises'
import { stdin, stdout } from 'node:process'

async function ttyAsk(question) {
  const rl = createInterface({ input: stdin, output: stdout })
  const answer = await rl.question(question)
  rl.close()
  return answer.trim().toLowerCase()
}

export async function shouldProceed(missingNames, { yes = false, ask = ttyAsk } = {}) {
  if (missingNames.length === 0) return false
  if (yes) return true
  const answer = await ask(`Will install: ${missingNames.join(', ')}. Proceed? [Y/n] `)
  return answer === '' || answer === 'y' || answer === 'yes'
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/confirm.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/confirm.js tests/confirm.test.js
git commit -m "feat: add one-shot dependency install confirmation gate"
```

---

## Task 4: Per-editor target resolver

**Files:**
- Create: `src/targets.js`
- Test: `tests/targets.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { targetPaths } from '../src/targets.js'

test('claude target points at ~/.claude', () => {
  const p = targetPaths('claude', '/home/x')
  assert.equal(p.hooksDir, '/home/x/.claude/hooks')
  assert.equal(p.settings, '/home/x/.claude/settings.json')
})
test('opencode target points at ~/.config/opencode', () => {
  const p = targetPaths('opencode', '/home/x')
  assert.equal(p.hooksDir, '/home/x/.config/opencode/hooks')
  assert.equal(p.settings, '/home/x/.config/opencode/opencode.json')
})
test('unknown target throws', () => {
  assert.throws(() => targetPaths('vim', '/home/x'), /unknown target/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/targets.test.js`
Expected: FAIL — `Cannot find module '../src/targets.js'`

- [ ] **Step 3: Write targets**

`src/targets.js`:
```js
import { join } from 'node:path'

const TARGETS = {
  claude: home => ({
    hooksDir: join(home, '.claude/hooks'),
    settings: join(home, '.claude/settings.json')
  }),
  opencode: home => ({
    hooksDir: join(home, '.config/opencode/hooks'),
    settings: join(home, '.config/opencode/opencode.json')
  })
}

export function targetPaths(target, home) {
  const fn = TARGETS[target]
  if (!fn) throw new Error(`unknown target: ${target}`)
  return fn(home)
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/targets.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/targets.js tests/targets.test.js
git commit -m "feat: add per-editor target path resolver (claude, opencode)"
```

---

## Task 5: Wire executor + targets + flags into install

**Files:**
- Modify: `src/install.js`
- Modify: `bin/cli.js`
- Test: `tests/install.e2e.test.js` (extend)

- [ ] **Step 1: Add failing test**

Append to `tests/install.e2e.test.js`:
```js
import { test } from 'node:test'
import assert from 'node:assert'
import { mkdtempSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { install } from '../src/install.js'

test('install with target=opencode writes opencode settings', () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-oc-'))
  install({ home: HOME, skipDeps: true, target: 'opencode' })
  assert.ok(existsSync(join(HOME, '.config/opencode/hooks/leanflow-fix.sh')))
  assert.ok(existsSync(join(HOME, '.config/opencode/opencode.json')))
})

test('install runs executor for missing deps when not skipping', async () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-dep-'))
  const ran = []
  install({
    home: HOME, target: 'claude', yes: true,
    deps: { redis: { brew: 'redis', service: true } },
    present: () => false,
    manager: 'brew',
    run: (bin, args) => ran.push([bin, ...args])
  })
  assert.ok(ran.some(c => c[0] === 'brew' && c[1] === 'install'))
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/install.e2e.test.js`
Expected: FAIL — opencode path missing / executor not invoked

- [ ] **Step 3: Modify install.js**

Replace the body of `src/install.js` `install()` with (keep imports, add new ones):
```js
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadHooks, loadDeps } from './manifest.js'
import { detectPkgManager, hasBinary } from './probe.js'
import { computeMissing } from './plan.js'
import { mergeHooks, removeHooks } from './settings.js'
import { installAll } from './executor.js'
import { targetPaths } from './targets.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const readSettings = p => (existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : {})

export function install({
  home = homedir(), target = 'claude', skipDeps = false, yes = false, noBootstrap = false,
  deps = null, present = hasBinary, manager = null, run = undefined
} = {}) {
  const { hooksDir, settings } = targetPaths(target, home)
  mkdirSync(hooksDir, { recursive: true })

  if (!skipDeps && !noBootstrap) {
    const depSpecs = deps ?? loadDeps()
    const missing = computeMissing(depSpecs, present)
    if (missing.length) {
      const mgr = manager ?? detectPkgManager()
      if (mgr && (yes /* one-shot gate handled by caller for TTY */ )) {
        installAll(mgr, missing, run ? { run } : {})
      }
    }
  }

  cpSync(join(ROOT, 'hooks'), hooksDir, { recursive: true })
  const current = readSettings(settings)
  if (existsSync(settings)) copyFileSync(settings, settings + '.bak')
  writeFileSync(settings, JSON.stringify(mergeHooks(current, loadHooks(), home, hooksDir), null, 2))
  console.log(`lean-flow hooks installed → ${hooksDir}`)
}

export function uninstall({ home = homedir(), target = 'claude' } = {}) {
  const { settings } = targetPaths(target, home)
  const cleaned = removeHooks(readSettings(settings), home)
  writeFileSync(settings, JSON.stringify(cleaned, null, 2))
  console.log('lean-flow hooks removed')
}
```

NOTE: `mergeHooks` gains a 4th arg `hooksDir` so the command path matches the target's hooks dir (Claude vs OpenCode). Update `src/settings.js` accordingly:
```js
function commandFor(hook, hooksDir) {
  return `${hook.runner} ${hooksDir}/${hook.script}`
}
export function mergeHooks(settings, hooks, home, hooksDir = `${home}/.claude/hooks`) {
  const out = structuredClone(settings)
  out.hooks ??= {}
  for (const h of hooks) {
    out.hooks[h.event] ??= []
    const command = commandFor(h, hooksDir)
    const already = out.hooks[h.event].some(g => (g.hooks ?? []).some(e => e.command === command))
    if (!already) out.hooks[h.event].push({ hooks: [{ type: 'command', command }] })
  }
  return out
}
```
`removeHooks` already matches by the `/hooks/` path substring — extend its prefix check to match both `.claude/hooks/` and `.config/opencode/hooks/` by testing for `/hooks/leanflow-`:
```js
export function removeHooks(settings, home) {
  const out = structuredClone(settings)
  for (const event of Object.keys(out.hooks ?? {})) {
    out.hooks[event] = out.hooks[event].filter(g =>
      !(g.hooks ?? []).some(e => (e.command ?? '').includes('/hooks/leanflow-')))
  }
  return out
}
```
Update Plan 1's settings tests if their expected command strings change (they used `~/.claude/hooks/`; still valid for default target).

- [ ] **Step 4: Modify bin/cli.js to parse flags**

`bin/cli.js`:
```js
#!/usr/bin/env node
import { shouldProceed } from '../src/confirm.js'
import { loadDeps } from '../src/manifest.js'
import { detectPkgManager, hasBinary } from '../src/probe.js'
import { computeMissing } from '../src/plan.js'

const argv = process.argv.slice(2)
const cmd = argv[0]
const flags = {
  yes: argv.includes('--yes'),
  noBootstrap: argv.includes('--no-bootstrap'),
  target: (argv.find(a => a.startsWith('--target=')) ?? '--target=claude').split('=')[1]
}

if (cmd === 'install') {
  const { install } = await import('../src/install.js')
  // TTY gate: confirm once before side effects
  let yes = flags.yes
  if (!yes && !flags.noBootstrap) {
    const missing = computeMissing(loadDeps(), hasBinary).map(d => d.name)
    yes = await shouldProceed(missing, {})
  }
  install({ target: flags.target, yes, noBootstrap: flags.noBootstrap })
} else if (cmd === 'uninstall') {
  const { uninstall } = await import('../src/install.js')
  uninstall({ target: flags.target })
} else if (cmd === 'update') {
  const { install } = await import('../src/install.js')
  install({ target: flags.target, yes: true })
} else {
  console.log('usage: lean-flow <install|uninstall|update> [--target=claude|opencode] [--yes] [--no-bootstrap]')
}
```

- [ ] **Step 5: Run tests, verify pass**

Run: `node --test tests/*.test.js`
Expected: PASS (all). Fix any Plan 1 settings test whose expected command string changed.

- [ ] **Step 6: Commit**

```bash
git add src/install.js src/settings.js bin/cli.js tests/install.e2e.test.js tests/settings.test.js
git commit -m "feat: wire dependency executor, opencode target, and cli flags"
```

---

## Task 6: Port real hook bodies

**Files:**
- Replace: `hooks/leanflow-grammar-check.sh`, `hooks/leanflow-fix.sh`
- Reference (read-only): `~/.claude/hooks/grammar-check.sh`, `~/.claude/scripts/lean-flow-fix.sh`

- [ ] **Step 1: Copy the real script bodies**

Run:
```bash
cp ~/.claude/hooks/grammar-check.sh hooks/leanflow-grammar-check.sh
cp ~/.claude/scripts/lean-flow-fix.sh hooks/leanflow-fix.sh
chmod +x hooks/leanflow-*.sh
```

- [ ] **Step 2: Scrub machine-specific absolute paths**

Open both files. Replace any hardcoded `/Users/ichigo/...` with `${HOME}/...` or `$(dirname "$0")` relative references. Verify no `/Users/` remains:
```bash
grep -n "/Users/" hooks/leanflow-*.sh || echo "clean"
```
Expected: `clean`

- [ ] **Step 3: Verify the e2e install test still passes with the real bodies**

Run: `node --test tests/install.e2e.test.js`
Expected: PASS (the test only checks the files copy + wire, not their internal logic)

- [ ] **Step 4: Commit**

```bash
git add hooks/leanflow-grammar-check.sh hooks/leanflow-fix.sh
git commit -m "feat: ship real grammar-check + session-fix hook bodies (paths scrubbed)"
```

---

## Task 7: Full suite green

- [ ] **Step 1: Run everything**

Run: `node --test tests/*.test.js`
Expected: PASS — all green.

- [ ] **Step 2: Commit any test fixes**

```bash
git add -A tests/
git commit -m "test: align expectations after executor + target wiring" || echo "nothing to commit"
```

---

## Out of scope (Plan 2 covers it)

- The request proxy for non-hook editors.
