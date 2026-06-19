export function computeMissing(deps, present) {
  // `present(name)` returns true if the dependency is already installed.
  // runtime-only deps (no install target) are checked but never "installed" by us.
  return Object.entries(deps)
    .filter(([name]) => !present(name))
    .map(([name, spec]) => ({ name, spec }))
}

export function renderPlan(missing) {
  if (missing.length === 0) return 'All dependencies present.'
  return `Will install: ${missing.map(d => d.name).join(', ')}`
}
