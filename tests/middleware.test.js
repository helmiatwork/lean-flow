import { test } from 'node:test'
import assert from 'node:assert'
import { injectRules, redactSecrets } from '../proxy/middleware.js'

test('injectRules prepends rules to existing system string', () => {
  const out = injectRules({ system: 'You are X.' }, 'RULES')
  assert.match(out.system, /^RULES/)
  assert.match(out.system, /You are X\.$/)
})
test('injectRules sets system when absent', () => {
  const out = injectRules({}, 'RULES')
  assert.equal(out.system, 'RULES')
})
test('injectRules does not mutate the input', () => {
  const input = { system: 'X' }
  injectRules(input, 'RULES')
  assert.equal(input.system, 'X')
})
test('redactSecrets masks sk- API keys in message text', () => {
  const out = redactSecrets({ messages: [{ role: 'user', content: 'key sk-abc123DEF456ghi789 here' }] })
  assert.match(out.messages[0].content, /\[REDACTED\]/)
  assert.doesNotMatch(out.messages[0].content, /sk-abc123/)
})
