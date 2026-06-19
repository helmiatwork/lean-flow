import { test } from 'node:test'
import assert from 'node:assert'
import { handleAnthropic } from '../proxy/anthropic.js'

test('handleAnthropic injects rules then forwards transformed body', async () => {
  let forwarded = null
  const fakeFetch = async (url, opts) => {
    forwarded = { url, body: JSON.parse(opts.body), headers: opts.headers }
    return new Response('{"ok":true}', { status: 200 })
  }
  const req = { system: 'orig', messages: [{ role: 'user', content: 'hi sk-secret0123456789' }] }
  const res = await handleAnthropic({
    path: '/v1/messages', body: req, headers: { 'x-api-key': 'k' },
    rules: 'RULES', fetchImpl: fakeFetch
  })
  assert.equal(res.status, 200)
  assert.match(forwarded.url, /api\.anthropic\.com\/v1\/messages$/)
  assert.match(forwarded.body.system, /^RULES/)
  assert.match(forwarded.body.messages[0].content, /\[REDACTED\]/)
})
