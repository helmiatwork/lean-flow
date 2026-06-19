export function injectRules(body, rules) {
  const out = structuredClone(body)
  out.system = out.system ? `${rules}\n\n${out.system}` : rules
  return out
}

export function redactSecrets(body) {
  const out = structuredClone(body)
  const mask = s => typeof s === 'string'
    ? s.replace(/sk-[A-Za-z0-9_-]{10,}/g, '[REDACTED]')
    : s
  for (const m of out.messages ?? []) {
    if (typeof m.content === 'string') m.content = mask(m.content)
    else if (Array.isArray(m.content)) {
      for (const part of m.content) if (part.type === 'text') part.text = mask(part.text)
    }
  }
  return out
}
