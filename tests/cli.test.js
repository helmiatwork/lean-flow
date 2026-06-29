import { test } from 'node:test'
import assert from 'node:assert'
import { execFileSync } from 'node:child_process'

test('cli prints help when no subcommand (defaults to init)', () => {
  const out = execFileSync('node', ['bin/cli.js'], { encoding: 'utf8' })
  assert.match(out, /lean-flow plugin installed/)
})
