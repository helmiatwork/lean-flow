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
