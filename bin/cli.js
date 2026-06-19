#!/usr/bin/env node
import { shouldProceed } from '../src/confirm.js'
import { loadDeps } from '../src/manifest.js'
import { detectPkgManager, hasBinary } from '../src/probe.js'
import { computeMissing } from '../src/plan.js'

const argv = process.argv.slice(2)
const cmd = argv[0]
const flags = {
  yes: argv.includes('--yes'),
  noBootstrap: argv.includes('--no-bootstrap'),
  target: (argv.find(a => a.startsWith('--target=')) ?? '--target=claude').split('=')[1]
}

if (cmd === 'install') {
  const { install } = await import('../src/install.js')
  // TTY gate: confirm once before side effects
  let yes = flags.yes
  if (!yes && !flags.noBootstrap) {
    const missing = computeMissing(loadDeps(), hasBinary).map(d => d.name)
    yes = await shouldProceed(missing, {})
  }
  install({ target: flags.target, yes, noBootstrap: flags.noBootstrap })
} else if (cmd === 'uninstall') {
  const { uninstall } = await import('../src/install.js')
  uninstall({ target: flags.target })
} else if (cmd === 'update') {
  const { install } = await import('../src/install.js')
  install({ target: flags.target, yes: true })
} else {
  console.log('usage: lean-flow <install|uninstall|update> [--target=claude|opencode] [--yes] [--no-bootstrap]')
}
