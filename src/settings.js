function commandFor(hook, hooksDir) {
  return `${hook.runner} ${hooksDir}/${hook.script}`
}

export function mergeHooks(settings, hooks, home, hooksDir = `${home}/.gemini/hooks`) {
  const out = structuredClone(settings)
  out.hooks ??= {}
  for (const h of hooks) {
    out.hooks[h.event] ??= []
    const command = commandFor(h, hooksDir)
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
  for (const event of Object.keys(out.hooks ?? {})) {
    out.hooks[event] = out.hooks[event].filter(group =>
      !(group.hooks ?? []).some(e => (e.command ?? '').includes('/hooks/leanflow-')))
  }
  return out
}
