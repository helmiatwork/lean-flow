import http from 'node:http'
import { handleAnthropic } from './anthropic.js'

export function createServer({ rules, fetchImpl = fetch }) {
  return http.createServer((req, res) => {
    if (req.method !== 'POST') { res.writeHead(405).end('method not allowed'); return }
    let raw = ''
    req.on('data', c => (raw += c))
    req.on('end', async () => {
      try {
        const body = JSON.parse(raw)
        const upstream = await handleAnthropic({
          path: req.url, body, headers: req.headers, rules, fetchImpl
        })
        res.writeHead(upstream.status, { 'content-type': upstream.headers.get('content-type') ?? 'application/json' })
        // stream the body through (works for both JSON and SSE)
        if (upstream.body) {
          const reader = upstream.body.getReader()
          for (;;) {
            const { done, value } = await reader.read()
            if (done) break
            res.write(Buffer.from(value))
          }
        }
        res.end()
      } catch (e) {
        res.writeHead(502).end(JSON.stringify({ error: String(e) }))
      }
    })
  })
}
