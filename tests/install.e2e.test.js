import { test } from 'node:test'
import assert from 'node:assert'
import { mkdtempSync, readFileSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { install, uninstall } from '../src/install.js'

test('install copies hooks + writes settings + backup; uninstall reverts', () => {
  const HOME = mkdtempSync(join(tmpdir(), 'lf-'))
  install({ home: HOME, skipDeps: true })            // skipDeps avoids real brew calls

  assert.ok(existsSync(join(HOME, '.claude/hooks/leanflow-fix.sh')), 'hook copied')
  const s = JSON.parse(readFileSync(join(HOME, '.claude/settings.json'), 'utf8'))
  assert.ok(s.hooks.SessionStart.some(g => g.hooks[0].command.includes('leanflow-fix.sh')))

  install({ home: HOME, skipDeps: true })            // idempotent
  const s2 = JSON.parse(readFileSync(join(HOME, '.claude/settings.json'), 'utf8'))
  assert.equal(
    s2.hooks.SessionStart.filter(g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 1)

  uninstall({ home: HOME })
  const s3 = JSON.parse(readFileSync(join(HOME, '.claude/settings.json'), 'utf8'))
  assert.equal((s3.hooks.SessionStart ?? []).filter(
    g => g.hooks[0].command.includes('leanflow-fix.sh')).length, 0)
})
