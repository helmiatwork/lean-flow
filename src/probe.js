import { execFileSync } from 'node:child_process'

export function hasBinary(name) {
  try {
    execFileSync('command', ['-v', name], { stdio: 'ignore', shell: '/bin/bash' })
    return true
  } catch {
    return false
  }
}

export function detectPkgManager() {
  for (const m of ['brew', 'apt', 'dnf']) {
    if (hasBinary(m)) return m
  }
  return null
}
