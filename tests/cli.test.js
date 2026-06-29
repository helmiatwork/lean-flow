import { test } from 'node:test'
import assert from 'node:assert'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { mergeRtkExcludeCommands, RSPEC_EXCLUDES } from '../bin/rtk-config.js'

// Run the CLI with an isolated HOME so tests never touch the real ~/.claude.
function runCli(args, env = {}) {
  const home = mkdtempSync(join(tmpdir(), 'lf-test-'))
  try {
    return execFileSync('node', ['bin/cli.js', ...args], {
      encoding: 'utf8',
      env: { ...process.env, HOME: home, ...env },
    })
  } finally {
    rmSync(home, { recursive: true, force: true })
  }
}

test('--help documents init and --install-companions', () => {
  const out = execFileSync('node', ['bin/cli.js', '--help'], { encoding: 'utf8' })
  assert.match(out, /--install-companions/)
  assert.match(out, /npx lean-flow init/)
})

test('init --dry-run makes no changes and shows companion recommendations', () => {
  const out = runCli(['init', '--dry-run'])
  assert.match(out, /DRY RUN/)
  assert.match(out, /Companion tools/)
})

test('mergeRtkExcludeCommands adds rspec entries to empty config', () => {
  const cfg = mergeRtkExcludeCommands({})
  assert.deepStrictEqual(cfg.hooks.exclude_commands, RSPEC_EXCLUDES)
})

test('mergeRtkExcludeCommands is idempotent (no duplicates on repeat)', () => {
  let cfg = mergeRtkExcludeCommands({})
  cfg = mergeRtkExcludeCommands(cfg)
  assert.deepStrictEqual(cfg.hooks.exclude_commands, RSPEC_EXCLUDES)
})

test('mergeRtkExcludeCommands does not clobber other keys/sections', () => {
  const cfg = mergeRtkExcludeCommands({
    telemetry: { enabled: false },
    hooks: { exclude_commands: ['custom'], transparent_prefixes: ['foo'] },
  })
  assert.strictEqual(cfg.telemetry.enabled, false)
  assert.deepStrictEqual(cfg.hooks.transparent_prefixes, ['foo'])
  assert.deepStrictEqual(cfg.hooks.exclude_commands, ['custom', ...RSPEC_EXCLUDES])
})
