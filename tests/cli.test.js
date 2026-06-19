import { test } from 'node:test'
import assert from 'node:assert'
import { execFileSync } from 'node:child_process'

test('cli prints usage when no subcommand', () => {
  const out = execFileSync('node', ['bin/cli.js'], { encoding: 'utf8' })
  assert.match(out, /usage: lean-flow <install\|uninstall\|update>/)
})
