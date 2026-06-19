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
