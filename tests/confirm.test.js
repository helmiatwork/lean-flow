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
