#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { createServer } from '../proxy/server.js'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const rules = readFileSync(join(ROOT, 'core/rules/system.md'), 'utf8')
const portArg = process.argv.find(a => a.startsWith('--port='))
const port = portArg ? Number(portArg.split('=')[1]) : 8787

createServer({ rules }).listen(port, '127.0.0.1', () => {
  console.log(`lean-flow proxy on http://127.0.0.1:${port}`)
  console.log(`point your editor: export ANTHROPIC_BASE_URL=http://127.0.0.1:${port}`)
})
