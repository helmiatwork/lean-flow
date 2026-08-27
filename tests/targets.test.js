import { test } from 'node:test'
import assert from 'node:assert'
import { targetPaths } from '../src/targets.js'

test('claude target points at ~/.gemini', () => {
  const p = targetPaths('claude', '/home/x')
  assert.equal(p.hooksDir, '/home/x/.gemini/hooks')
  assert.equal(p.settings, '/home/x/.gemini/settings.json')
})
test('opencode target points at ~/.config/opencode', () => {
  const p = targetPaths('opencode', '/home/x')
  assert.equal(p.hooksDir, '/home/x/.config/opencode/hooks')
  assert.equal(p.settings, '/home/x/.config/opencode/opencode.json')
})
test('unknown target throws', () => {
  assert.throws(() => targetPaths('vim', '/home/x'), /unknown target/)
})
