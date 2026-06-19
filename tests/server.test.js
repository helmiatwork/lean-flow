import { test } from 'node:test'
import assert from 'node:assert'
import { once } from 'node:events'
import { createServer } from '../proxy/server.js'

test('server forwards POST body through adapter and returns upstream status', async () => {
  // stub adapter via fetchImpl that echoes a 200
  const fakeFetch = async () => new Response('{"echo":true}', {
    status: 200, headers: { 'content-type': 'application/json' }
  })
  const srv = createServer({ rules: 'RULES', fetchImpl: fakeFetch })
  srv.listen(0, '127.0.0.1')
  await once(srv, 'listening')
  const { port } = srv.address()

  const res = await fetch(`http://127.0.0.1:${port}/v1/messages`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-api-key': 'k' },
    body: JSON.stringify({ messages: [{ role: 'user', content: 'hi' }] })
  })
  assert.equal(res.status, 200)
  const json = await res.json()
  assert.equal(json.echo, true)
  srv.close()
})

test('server binds to 127.0.0.1 only', async () => {
  const srv = createServer({ rules: 'R', fetchImpl: async () => new Response('{}') })
  srv.listen(0, '127.0.0.1')
  await once(srv, 'listening')
  assert.equal(srv.address().address, '127.0.0.1')
  srv.close()
})
