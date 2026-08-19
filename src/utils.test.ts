import test from 'node:test'
import assert from 'node:assert/strict'
import { clamp, sleep } from './utils.ts'

test('sleep: should resolve after specified milliseconds', async () => {
  const start = Date.now()
  await sleep(10)
  const elapsed = Date.now() - start
  assert.ok(elapsed >= 9, `Expected elapsed >= 9, got ${elapsed}`)
})

test('sleep: should return a promise', () => {
  const result = sleep(1)
  assert.ok(result instanceof Promise, 'sleep should return a Promise')
})

test('clamp: should return value when between min and max', () => {
  assert.equal(clamp(5, 0, 10), 5)
  assert.equal(clamp(0, 0, 10), 0)
  assert.equal(clamp(10, 0, 10), 10)
})

test('clamp: should return min when value is below min', () => {
  assert.equal(clamp(-5, 0, 10), 0)
  assert.equal(clamp(-100, -50, 50), -50)
})

test('clamp: should return max when value is above max', () => {
  assert.equal(clamp(15, 0, 10), 10)
  assert.equal(clamp(100, -50, 50), 50)
})

test('clamp: should handle negative ranges', () => {
  assert.equal(clamp(-5, -10, -1), -5)
  assert.equal(clamp(-15, -10, -1), -10)
  assert.equal(clamp(0, -10, -1), -1)
})

test('clamp: should handle floating point numbers', () => {
  assert.equal(clamp(5.5, 0, 10), 5.5)
  assert.equal(clamp(-0.5, 0, 10), 0)
  assert.equal(clamp(10.1, 0, 10), 10)
})

test('clamp: should throw when min > max', () => {
  assert.throws(
    () => clamp(5, 10, 0),
    /min \(10\) cannot be greater than max \(0\)/
  )
})

test('clamp: should work with equal min and max', () => {
  assert.equal(clamp(5, 10, 10), 10)
  assert.equal(clamp(10, 10, 10), 10)
  assert.equal(clamp(15, 10, 10), 10)
})
