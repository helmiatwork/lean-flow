import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadHooks, loadDeps } from './manifest.js'
import { detectPkgManager, hasBinary } from './probe.js'
import { computeMissing } from './plan.js'
import { mergeHooks, removeHooks } from './settings.js'
import { installAll } from './executor.js'
import { targetPaths } from './targets.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const readSettings = p => (existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : {})

export function install({
  home = homedir(), target = 'claude', skipDeps = false, yes = false, noBootstrap = false,
  deps = null, present = hasBinary, manager = null, run = undefined
} = {}) {
  const { hooksDir, settings } = targetPaths(target, home)
  mkdirSync(hooksDir, { recursive: true })

  if (!skipDeps && !noBootstrap) {
    const depSpecs = deps ?? loadDeps()
    const missing = computeMissing(depSpecs, present)
    if (missing.length) {
      const mgr = manager ?? detectPkgManager()
      if (mgr && (yes /* one-shot gate handled by caller for TTY */ )) {
        installAll(mgr, missing, run ? { run } : {})
      }
    }
  }

  cpSync(join(ROOT, 'hooks'), hooksDir, { recursive: true })
  const current = readSettings(settings)
  if (existsSync(settings)) copyFileSync(settings, settings + '.bak')
  writeFileSync(settings, JSON.stringify(mergeHooks(current, loadHooks(), home, hooksDir), null, 2))
  console.log(`lean-flow hooks installed → ${hooksDir}`)
}

export function uninstall({ home = homedir(), target = 'claude' } = {}) {
  const { settings } = targetPaths(target, home)
  const cleaned = removeHooks(readSettings(settings), home)
  writeFileSync(settings, JSON.stringify(cleaned, null, 2))
  console.log('lean-flow hooks removed')
}
