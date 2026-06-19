export function installCommand(manager, spec) {
  if (manager === 'brew' && spec.brew) return ['brew', ['install', spec.brew]]
  if (manager === 'apt' && spec.apt) return ['sudo', ['apt-get', 'install', '-y', spec.apt]]
  if (manager === 'dnf' && spec.dnf) return ['sudo', ['dnf', 'install', '-y', spec.dnf]]
  return null
}

export function serviceCommand(manager, name, spec) {
  if (!spec.service) return null
  if (manager === 'brew') return ['brew', ['services', 'start', spec.brew ?? name]]
  return ['sudo', ['systemctl', 'enable', '--now', spec.apt ?? spec.dnf ?? name]]
}

import { execFileSync } from 'node:child_process'

const defaultRun = (bin, args) => execFileSync(bin, args, { stdio: 'inherit' })

export function installAll(manager, missing, { run = defaultRun } = {}) {
  for (const { name, spec } of missing) {
    const inst = installCommand(manager, spec)
    if (!inst) throw new Error(`no install command for ${name} on ${manager}`)
    run(inst[0], inst[1])
    const svc = serviceCommand(manager, name, spec)
    if (svc) run(svc[0], svc[1])
  }
}
