import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadHooks, loadDeps } from './manifest.js'
import { detectPkgManager, hasBinary } from './probe.js'
import { computeMissing, renderPlan } from './plan.js'
import { mergeHooks, removeHooks } from './settings.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

function readSettings(path) {
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : {}
}

export function install({ home = homedir(), skipDeps = false } = {}) {
  const hooksDir = join(home, '.claude/hooks')
  const settingsPath = join(home, '.claude/settings.json')
  mkdirSync(hooksDir, { recursive: true })

  if (!skipDeps) {
    const deps = loadDeps()
    const missing = computeMissing(deps, hasBinary)
    console.log(renderPlan(missing))
    // NOTE: real dep execution (brew/apt) lands in Task 7 of a follow-up plan.
  }

  cpSync(join(ROOT, 'hooks'), hooksDir, { recursive: true })

  const current = readSettings(settingsPath)
  if (existsSync(settingsPath)) copyFileSync(settingsPath, settingsPath + '.bak')
  const merged = mergeHooks(current, loadHooks(), home)
  writeFileSync(settingsPath, JSON.stringify(merged, null, 2))
  console.log('lean-flow hooks installed → ' + hooksDir)
}

export function uninstall({ home = homedir() } = {}) {
  const settingsPath = join(home, '.claude/settings.json')
  const current = readSettings(settingsPath)
  const cleaned = removeHooks(current, home)
  writeFileSync(settingsPath, JSON.stringify(cleaned, null, 2))
  console.log('lean-flow hooks removed')
}
