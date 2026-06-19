import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import TOML from '@iarna/toml'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

export function loadDeps() {
  return TOML.parse(readFileSync(join(ROOT, 'core/deps.toml'), 'utf8'))
}
export function loadHooks() {
  return JSON.parse(readFileSync(join(ROOT, 'core/hook-manifest.json'), 'utf8'))
}
