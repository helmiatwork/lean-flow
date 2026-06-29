#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync, copyFileSync, readdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import { parse, stringify } from '@iarna/toml'
import { mergeRtkExcludeCommands } from './rtk-config.js'

const PKG_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const PKG_VERSION = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8')).version

const argv = process.argv.slice(2)
const cmd = argv[0]
const flags = {
  dryRun: argv.includes('--dry-run'),
  help: argv.includes('--help') || argv.includes('-h'),
  version: argv.includes('--version') || argv.includes('-v'),
  marketplace: argv.includes('--marketplace'),
  installCompanions: argv.includes('--install-companions'),
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
  --install-companions                Install/wire companion tools (rtk, omni, caveman, ponytail)
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
  mkdirSync(claudeDir, { recursive: true })

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

  // Companions detection and installation
  const companionStatus = await detectCompanions(home)

  if (flags.installCompanions) {
    await installCompanions(companionStatus, home, flags.dryRun)
  } else {
    printCompanionRecommendations(companionStatus)
  }

  console.log(`\nNext steps:`)
  console.log(`  1. Restart your Claude Code session`)
  console.log(`  2. The plugin will auto-initialize on first load`)
  console.log(`  3. Run /project-doctor in Claude to audit your project`)
}

async function detectCompanions(home) {
  const { execFile } = await import('node:child_process')
  const companions = { rtk: false, omni: false, claude: false }

  // Check which binaries are available
  return new Promise((resolve) => {
    let checked = 0
    const checkBinary = (name) => {
      execFile('which', [name], (error) => {
        companions[name] = !error
        checked++
        if (checked === 3) resolve(companions)
      })
    }

    checkBinary('rtk')
    checkBinary('omni')
    checkBinary('claude')
  })
}

function printCompanionRecommendations(companionStatus) {
  console.log('\nCompanion tools (optional):')

  if (companionStatus.rtk) {
    console.log('  ✓ rtk found')
  } else {
    console.log('  ○ rtk not found — install: brew install rtk')
  }

  if (companionStatus.omni) {
    console.log('  ✓ omni found')
  } else {
    console.log('  ○ omni not found — install: brew install fajarhide/tap/omni')
  }

  if (companionStatus.claude) {
    console.log('  ○ caveman & ponytail available via marketplace add:')
    console.log('     claude plugin marketplace add JuliusBrussee/caveman')
    console.log('     claude plugin marketplace add DietrichGebert/ponytail')
  } else {
    console.log('  ○ caveman & ponytail require Claude Code CLI')
  }

  console.log('  Use "npx lean-flow init --install-companions" to auto-wire them.')
}

async function installCompanions(companionStatus, home, dryRun) {
  console.log('\nInstalling companions...')

  const { execFile } = await import('node:child_process')

  // Wire RTK config for rspec passthrough
  if (companionStatus.rtk) {
    try {
      await wireRtkConfig(home, dryRun)
      console.log('  ✓ rtk config wired')
    } catch (e) {
      console.log('  ! rtk config skip (may not be configured)')
    }
  }

  // Register Claude plugins
  if (companionStatus.claude) {
    const plugins = [
      { name: 'caveman', repo: 'JuliusBrussee/caveman' },
      { name: 'ponytail', repo: 'DietrichGebert/ponytail' },
    ]

    for (const { name, repo } of plugins) {
      try {
        if (!dryRun) {
          await new Promise((resolve, reject) => {
            execFile('claude', ['plugin', 'marketplace', 'add', repo],
              { stdio: 'ignore' },
              (error) => {
                if (error) reject(error)
                else resolve()
              }
            )
          })
        }
        console.log(`  ✓ ${name} registered`)
      } catch (e) {
        console.log(`  ! ${name} registration failed (may already be installed)`)
      }
    }
  }
}

async function wireRtkConfig(home, dryRun) {
  const rtkConfigDir = join(home, 'Library', 'Application Support', 'rtk')
  const rtkConfigPath = join(rtkConfigDir, 'config.toml')

  mkdirSync(rtkConfigDir, { recursive: true })

  let config = {}
  if (existsSync(rtkConfigPath)) {
    const content = readFileSync(rtkConfigPath, 'utf8')
    config = parse(content) || {}
  }

  // ponytail: idempotent merge, no-clobber — see bin/rtk-config.js
  mergeRtkExcludeCommands(config)

  if (!dryRun) {
    writeFileSync(rtkConfigPath, stringify(config))
  }
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
