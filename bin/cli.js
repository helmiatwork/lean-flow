#!/usr/bin/env node
const cmd = process.argv[2]
const cmds = {
  install: async () => (await import('../src/install.js')).install(),
  uninstall: async () => (await import('../src/install.js')).uninstall(),
  update: async () => (await import('../src/install.js')).install()
}
if (cmds[cmd]) await cmds[cmd]()
else console.log('usage: lean-flow <install|uninstall|update>')
