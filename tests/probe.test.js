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
