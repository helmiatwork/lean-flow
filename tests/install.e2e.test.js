import { test } from 'node:test'
import assert from 'node:assert'
import { mkdtempSync, readFileSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { install, uninstall } from '../src/install.js'

test('install copies hooks + writes settings + backup; uninstall reverts', () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-'))
  install({ home: HOME, skipDeps: true })            // skipDeps avoids real brew calls

  assert.ok(existsSync(join(HOME, '.gemini/hooks/leanflow-fix.sh')), 'hook copied')
  const s = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.ok(s.hooks.SessionStart.some(g => g.hooks[0].command.includes('leanflow-fix.sh')))

  install({ home: HOME, skipDeps: true })            // idempotent
  const s2 = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.equal(
    s2.hooks.SessionStart.filter(g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 1)

  uninstall({ home: HOME })
  const s3 = JSON.parse(readFileSync(join(HOME, '.gemini/settings.json'), 'utf8'))
  assert.equal((s3.hooks.SessionStart ?? []).filter(
    g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 0)
})

test('install with target=opencode writes opencode settings', () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-oc-'))
  install({ home: HOME, skipDeps: true, target: 'opencode' })
  assert.ok(existsSync(join(HOME, '.config/opencode/hooks/leanflow-fix.sh')))
  assert.ok(existsSync(join(HOME, '.config/opencode/opencode.json')))
})

test('install runs executor for missing deps when not skipping', async () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-dep-'))
  const ran = []
  install({
    home: HOME, target: 'claude', yes: true,
    deps: { redis: { brew: 'redis', service: true } },
    present: () => false,
    manager: 'brew',
    run: (bin, args) => ran.push([bin, ...args])
  })
  assert.ok(ran.some(c => c[0] === 'brew' && c[1] === 'install'))
})
