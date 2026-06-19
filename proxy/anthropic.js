import { injectRules, redactSecrets } from './middleware.js'

const UPSTREAM = 'https://api.anthropic.com'

export async function handleAnthropic({ path, body, headers, rules, fetchImpl = fetch }) {
  let transformed = injectRules(body, rules)
  transformed = redactSecrets(transformed)
  const fwdHeaders = { ...headers, host: 'api.anthropic.com' }
  return fetchImpl(`${UPSTREAM}${path}`, {
    method: 'POST',
    headers: fwdHeaders,
    body: JSON.stringify(transformed)
  })
}
