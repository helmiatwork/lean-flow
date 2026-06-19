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
