import { join } from 'node:path'

const TARGETS = {
  claude: home => ({
    hooksDir: join(home, '.gemini/hooks'),
    settings: join(home, '.gemini/settings.json')
  }),
  opencode: home => ({
    hooksDir: join(home, '.config/opencode/hooks'),
    settings: join(home, '.config/opencode/opencode.json')
  })
}

export function targetPaths(target, home) {
  const fn = TARGETS[target]
  if (!fn) throw new Error(`unknown target: ${target}`)
  return fn(home)
}
