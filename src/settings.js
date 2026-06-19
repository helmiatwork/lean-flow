const PREFIX = home => `${home}/.claude/hooks/`

function commandFor(hook, home) {
  return `${hook.runner} ${PREFIX(home)}${hook.script}`
}

export function mergeHooks(settings, hooks, home) {
  const out = structuredClone(settings)
  out.hooks ??= {}
  for (const h of hooks) {
    out.hooks[h.event] ??= []
    const command = commandFor(h, home)
    const already = out.hooks[h.event].some(group =>
      (group.hooks ?? []).some(e => e.command === command))
    if (!already) {
      out.hooks[h.event].push({ hooks: [{ type: 'command', command }] })
    }
  }
  return out
}

export function removeHooks(settings, home) {
  const out = structuredClone(settings)
  const prefix = PREFIX(home)
  for (const event of Object.keys(out.hooks ?? {})) {
    out.hooks[event] = out.hooks[event].filter(group =>
      !(group.hooks ?? []).some(e => (e.command ?? '').includes(prefix)))
  }
  return out
}
