#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync, statSync, readdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const PKG_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const PKG_VERSION = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8')).version

const argv = process.argv.slice(2)
const cmd = argv[0]
const flags = {
  dryRun: argv.includes('--dry-run'),
  help: argv.includes('--help') || argv.includes('-h'),
  version: argv.includes('--version') || argv.includes('-v'),
  marketplace: argv.includes('--marketplace'),
}

if (flags.help) {
  console.log(`
lean-flow — lightweight dev workflow plugin for Claude Code

USAGE:
  npx lean-flow init [options]        Initialize lean-flow in ~/.claude
  npx lean-flow --version              Show version
  npx lean-flow --help                 Show this help

OPTIONS:
  --dry-run                           Show what would be copied without making changes
  --marketplace                       Also register the marketplace entry
  --help, -h                          Show this help
  --version, -v                       Show version

INSTALL:
  npx lean-flow init                  Copy plugin to ~/.claude and register hooks

For more info, see: https://github.com/helmiatwork/lean-flow
  `)
  process.exit(0)
}

if (flags.version) {
  console.log(`lean-flow ${PKG_VERSION}`)
  process.exit(0)
}

if (cmd === 'init' || !cmd) {
  initPlugin()
} else {
  console.error(`Unknown command: ${cmd}`)
  console.error(`Run 'npx lean-flow --help' for usage`)
  process.exit(1)
}

async function initPlugin() {
  const home = homedir()
  const claudeDir = join(home, '.claude')
  const targetsDir = join(claudeDir, 'agents')

  mkdirSync(claudeDir, { recursive: true })
  mkdirSync(targetsDir, { recursive: true })

  const sourcePlugin = join(PKG_ROOT, 'plugin')
  const sourceDirs = [
    { src: 'agents', dest: 'agents' },
    { src: 'commands', dest: 'skills/commands' },
    { src: 'skills', dest: 'skills' },
    { src: 'hooks', dest: 'hooks' },
    { src: 'workflows', dest: 'skills/workflows' },
    { src: 'mcp-servers', dest: 'mcp-servers' },
    { src: 'scripts', dest: 'skills/lean-flow' },
  ]

  const copied = []
  const backedUp = []

  for (const dir of sourceDirs) {
    const srcPath = join(sourcePlugin, dir.src)
    const destPath = join(claudeDir, dir.dest)

    if (!existsSync(srcPath)) {
      console.warn(`⚠ Skipping missing source: ${dir.src}`)
      continue
    }

    // Backup if exists and differs
    if (existsSync(destPath)) {
      const srcHash = dirHash(srcPath)
      const destHash = dirHash(destPath)
      if (srcHash !== destHash) {
        const bakPath = destPath + '.bak'
        if (!flags.dryRun) {
          cpSync(destPath, bakPath, { recursive: true, force: true })
        }
        backedUp.push(`${dir.dest} → ${bakPath}`)
      }
    }

    if (!flags.dryRun) {
      mkdirSync(destPath, { recursive: true })
      cpSync(srcPath, destPath, { recursive: true, force: true })
    }
    copied.push(dir.dest)
  }

  if (flags.dryRun) {
    console.log('DRY RUN (no changes made)')
  } else {
    console.log('✓ lean-flow plugin installed to ~/.claude')
  }

  if (copied.length) {
    console.log(`\nCopied:`)
    copied.forEach(f => console.log(`  ✓ ${f}`))
  }

  if (backedUp.length) {
    console.log(`\nBacked up (because they differed):`)
    backedUp.forEach(f => console.log(`  ! ${f}`))
  }

  if (flags.marketplace) {
    console.log('\nRegistering marketplace entry...')
    try {
      // Try to register via claude CLI if available
      const { execFile } = await import('node:child_process')
      try {
        await new Promise((resolve, reject) => {
          execFile('claude', ['plugin', 'marketplace', 'add', 'helmiatwork/lean-flow'],
            { stdio: 'inherit' },
            (error) => {
              if (error) reject(error)
              else resolve()
            }
          )
        })
        console.log('✓ Marketplace registered')
      } catch (e) {
        console.log('ℹ Marketplace registration skipped (claude CLI not found)')
        console.log('  You can register manually later or via Claude Code settings')
      }
    } catch (e) {
      // Silently skip if exec not available
    }
  }

  console.log(`\nNext steps:`)
  console.log(`  1. Restart your Claude Code session`)
  console.log(`  2. The plugin will auto-initialize on first load`)
  console.log(`  3. Run /project-doctor in Claude to audit your project`)
}

function dirHash(dirPath) {
  const hash = createHash('md5')
  function walk(dir) {
    if (!existsSync(dir)) return
    const entries = readdirSync(dir, { withFileTypes: true }).sort()
    for (const entry of entries) {
      if (entry.name.startsWith('.')) continue
      const fullPath = join(dir, entry.name)
      if (entry.isDirectory()) {
        walk(fullPath)
      } else {
        const content = readFileSync(fullPath, 'utf8')
        hash.update(content)
      }
    }
  }
  walk(dirPath)
  return hash.digest('hex')
}
