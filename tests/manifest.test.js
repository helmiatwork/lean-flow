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
