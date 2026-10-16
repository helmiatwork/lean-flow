import { test } from 'node:test'
import assert from 'node:assert'
import { mergeHooks, removeHooks } from '../src/settings.js'

const hooks = [{ event: 'SessionStart', script: 'leanflow-fix.sh', runner: 'bash' }]
const HOME = '/home/teammate'

test('mergeHooks rewrites path to target HOME', () => {
  const out = mergeHooks({}, hooks, HOME)
  const cmd = out.hooks.SessionStart[0].hooks[0].command
  assert.equal(cmd, 'bash /home/teammate/.claude/hooks/leanflow-fix.sh')
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
