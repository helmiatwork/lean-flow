# Request Proxy for Non-Hook Editors (Plan 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A local LLM reverse proxy that injects lean-flow's `core/` rules into every request, so editors with no hook system (Cursor, Aider, Copilot) still get grammar/STAR/workflow enforcement.

**Architecture:** A Node HTTP server bound to `127.0.0.1`. Editors point their provider base URL at it. A per-provider adapter parses the request body, runs a middleware chain (inject system rules, redact secrets, log), forwards to the real provider, and streams the response back transparently. Anthropic Messages API is the first adapter.

**Tech Stack:** Node ≥18 ESM, built-in `http` + global `fetch`, `node:test`. No new runtime deps.

**Depends on:** Plan 1 (`core/` exists on `feature/universal-install`). Self-contained otherwise — only adds files under `proxy/` + `bin/proxy.js` + a `package.json` bin entry. Does NOT modify `bin/cli.js`.

---

## File Structure

- `core/rules/system.md` — the injected ruleset text (single source for proxy + hooks)
- `proxy/middleware.js` — pure transforms: `injectRules`, `redactSecrets`
- `proxy/anthropic.js` — Anthropic adapter: transform body + forward (injectable `fetch`)
- `proxy/server.js` — HTTP server wiring, `127.0.0.1` bind, SSE passthrough
- `bin/proxy.js` — entrypoint: `lean-flow-proxy [--port=8787]`
- `tests/middleware.test.js`, `tests/anthropic.test.js`

---

## Task 1: core rules text

**Files:**
- Create: `core/rules/system.md`
- Test: covered indirectly by Task 2

- [ ] **Step 1: Write the rules file**

`core/rules/system.md`:
```markdown
# lean-flow injected rules
- Classify the task (STAR): simple / medium / heavy before acting.
- Prefer existing patterns; do not over-engineer.
- Verify with tests before claiming completion.
```

- [ ] **Step 2: Commit**

```bash
git add core/rules/system.md
git commit -m "feat: add core system rules text for proxy injection"
```

---

## Task 2: Middleware transforms

**Files:**
- Create: `proxy/middleware.js`
- Test: `tests/middleware.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { injectRules, redactSecrets } from '../proxy/middleware.js'

test('injectRules prepends rules to existing system string', () => {
  const out = injectRules({ system: 'You are X.' }, 'RULES')
  assert.match(out.system, /^RULES/)
  assert.match(out.system, /You are X\.$/)
})
test('injectRules sets system when absent', () => {
  const out = injectRules({}, 'RULES')
  assert.equal(out.system, 'RULES')
})
test('injectRules does not mutate the input', () => {
  const input = { system: 'X' }
  injectRules(input, 'RULES')
  assert.equal(input.system, 'X')
})
test('redactSecrets masks sk- API keys in message text', () => {
  const out = redactSecrets({ messages: [{ role: 'user', content: 'key sk-abc123DEF456ghi789 here' }] })
  assert.match(out.messages[0].content, /\[REDACTED\]/)
  assert.doesNotMatch(out.messages[0].content, /sk-abc123/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/middleware.test.js`
Expected: FAIL — `Cannot find module '../proxy/middleware.js'`

- [ ] **Step 3: Write middleware**

`proxy/middleware.js`:
```js
export function injectRules(body, rules) {
  const out = structuredClone(body)
  out.system = out.system ? `${rules}\n\n${out.system}` : rules
  return out
}

export function redactSecrets(body) {
  const out = structuredClone(body)
  const mask = s => typeof s === 'string'
    ? s.replace(/sk-[A-Za-z0-9_-]{10,}/g, '[REDACTED]')
    : s
  for (const m of out.messages ?? []) {
    if (typeof m.content === 'string') m.content = mask(m.content)
    else if (Array.isArray(m.content)) {
      for (const part of m.content) if (part.type === 'text') part.text = mask(part.text)
    }
  }
  return out
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/middleware.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add proxy/middleware.js tests/middleware.test.js
git commit -m "feat: add proxy middleware (rule injection + secret redaction)"
```

---

## Task 3: Anthropic adapter

**Files:**
- Create: `proxy/anthropic.js`
- Test: `tests/anthropic.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { handleAnthropic } from '../proxy/anthropic.js'

test('handleAnthropic injects rules then forwards transformed body', async () => {
  let forwarded = null
  const fakeFetch = async (url, opts) => {
    forwarded = { url, body: JSON.parse(opts.body), headers: opts.headers }
    return new Response('{"ok":true}', { status: 200 })
  }
  const req = { system: 'orig', messages: [{ role: 'user', content: 'hi sk-secret0123456789' }] }
  const res = await handleAnthropic({
    path: '/v1/messages', body: req, headers: { 'x-api-key': 'k' },
    rules: 'RULES', fetchImpl: fakeFetch
  })
  assert.equal(res.status, 200)
  assert.match(forwarded.url, /api\.anthropic\.com\/v1\/messages$/)
  assert.match(forwarded.body.system, /^RULES/)
  assert.match(forwarded.body.messages[0].content, /\[REDACTED\]/)
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/anthropic.test.js`
Expected: FAIL — `Cannot find module '../proxy/anthropic.js'`

- [ ] **Step 3: Write adapter**

`proxy/anthropic.js`:
```js
import { injectRules, redactSecrets } from './middleware.js'

const UPSTREAM = 'https://api.anthropic.com'

export async function handleAnthropic({ path, body, headers, rules, fetchImpl = fetch }) {
  let transformed = injectRules(body, rules)
  transformed = redactSecrets(transformed)
  const fwdHeaders = { ...headers, host: 'api.anthropic.com' }
  return fetchImpl(`${UPSTREAM}${path}`, {
    method: 'POST',
    headers: fwdHeaders,
    body: JSON.stringify(transformed)
  })
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/anthropic.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add proxy/anthropic.js tests/anthropic.test.js
git commit -m "feat: add anthropic proxy adapter with rule injection + redaction"
```

---

## Task 4: HTTP server + SSE passthrough

**Files:**
- Create: `proxy/server.js`
- Test: `tests/server.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { test } from 'node:test'
import assert from 'node:assert'
import { once } from 'node:events'
import { createServer } from '../proxy/server.js'

test('server forwards POST body through adapter and returns upstream status', async () => {
  // stub adapter via fetchImpl that echoes a 200
  const fakeFetch = async () => new Response('{"echo":true}', {
    status: 200, headers: { 'content-type': 'application/json' }
  })
  const srv = createServer({ rules: 'RULES', fetchImpl: fakeFetch })
  srv.listen(0, '127.0.0.1')
  await once(srv, 'listening')
  const { port } = srv.address()

  const res = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-api-key': 'k' },
    body: JSON.stringify({ messages: [{ role: 'user', content: 'hi' }] })
  })
  assert.equal(res.status, 200)
  const json = await res.json()
  assert.equal(json.echo, true)
  srv.close()
})

test('server binds to 127.0.0.1 only', async () => {
  const srv = createServer({ rules: 'R', fetchImpl: async () => new Response('{}') })
  srv.listen(0, '127.0.0.1')
  await once(srv, 'listening')
  assert.equal(srv.address().address, '127.0.0.1')
  srv.close()
})
```

- [ ] **Step 2: Run test, verify it fails**

Run: `node --test tests/server.test.js`
Expected: FAIL — `Cannot find module '../proxy/server.js'`

- [ ] **Step 3: Write server**

`proxy/server.js`:
```js
import http from 'node:http'
import { handleAnthropic } from './anthropic.js'

export function createServer({ rules, fetchImpl = fetch }) {
  return http.createServer((req, res) => {
    if (req.method !== 'POST') { res.writeHead(405).end('method not allowed'); return }
    let raw = ''
    req.on('data', c => (raw += c))
    req.on('end', async () => {
      try {
        const body = JSON.parse(raw)
        const upstream = await handleAnthropic({
          path: req.url, body, headers: req.headers, rules, fetchImpl
        })
        res.writeHead(upstream.status, { 'content-type': upstream.headers.get('content-type') ?? 'application/json' })
        // stream the body through (works for both JSON and SSE)
        if (upstream.body) {
          const reader = upstream.body.getReader()
          for (;;) {
            const { done, value } = await reader.read()
            if (done) break
            res.write(Buffer.from(value))
          }
        }
        res.end()
      } catch (e) {
        res.writeHead(502).end(JSON.stringify({ error: String(e) }))
      }
    })
  })
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `node --test tests/server.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add proxy/server.js tests/server.test.js
git commit -m "feat: add proxy http server with streaming passthrough"
```

---

## Task 5: Entry point + package bin

**Files:**
- Create: `bin/proxy.js`
- Modify: `package.json` (add bin entry)

- [ ] **Step 1: Write entry point**

`bin/proxy.js`:
```js
#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { createServer } from '../proxy/server.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const rules = readFileSync(join(ROOT, 'core/rules/system.md'), 'utf8')
const portArg = process.argv.find(a => a.startsWith('--port='))
const port = portArg ? Number(portArg.split('=')[1]) : 8787

createServer({ rules }).listen(port, '127.0.0.1', () => {
  console.log(`lean-flow proxy on http://127.0.0.1:${port}`)
  console.log(`point your editor: export ANTHROPIC_BASE_URL=http://127.0.0.1:${port}`)
})
```

- [ ] **Step 2: Add bin entry to package.json**

Change the `bin` field to:
```json
"bin": { "lean-flow": "./bin/cli.js", "lean-flow-proxy": "./bin/proxy.js" }
```

- [ ] **Step 3: Smoke-test the entry**

Run: `node bin/proxy.js --port=0 & sleep 1; kill %1`
Expected: prints `lean-flow proxy on http://127.0.0.1:...` (no crash)

- [ ] **Step 4: Commit**

```bash
git add bin/proxy.js package.json
git commit -m "feat: add lean-flow-proxy entry point"
```

---

## Task 6: Full suite green

- [ ] **Step 1: Run everything**

Run: `node --test tests/*.test.js`
Expected: PASS — all green.

- [ ] **Step 2: Commit any fixes**

```bash
git add -A tests/ && git commit -m "test: proxy suite green" || echo "nothing to commit"
```

---

## Known limitations (documented, not bugs)

- Base-URL redirect only; cert-pinned tools cannot be intercepted (by design).
- Anthropic adapter only; OpenAI/Gemini adapters are follow-ups.
- Proxy holds plaintext prompts + keys in memory — local-only bind, never logs keys.
