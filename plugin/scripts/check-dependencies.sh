#!/usr/bin/env bash
# check-dependencies.sh — SessionStart dependency audit.
#
# Runs after the ensure-* bootstrap chain. Detects missing or misconfigured
# companion plugins / tools the workflow routes to, and emits a single
# actionable systemMessage with install instructions.
#
# Categories:
#   REQUIRED     workflow routes through this; missing = broken behavior
#   RECOMMENDED  optional; missing = degraded experience (token cost,
#                  fewer features) but workflow still works
#   DEPRECATED   should NOT be installed/enabled; conflicts with current
#                  workflow direction
#
# Caching: hashes the set of missing-dep keys and skips emission when
# unchanged from last session — same pattern as session-briefing.sh.
# Cache file: ~/.lean-flow-dep-check.<hash>

set -uo pipefail

source "$(dirname "$0")/load-config.sh" 2>/dev/null

SETTINGS="${HOME}/.claude/settings.json"
CLAUDE_JSON="${HOME}/.claude.json"

# Collect findings as "BUCKET|key|hint" lines
findings=()

add_finding() {
  findings+=("$1|$2|$3")
}

# ── REQUIRED ─────────────────────────────────────────────────────────
# superpowers plugin — claude-rules.md routes to its skills (writing-plans,
# executing-plans, systematic-debugging, test-driven-development,
# verification-before-completion). Without it, the planning/TDD path breaks.
found_superpowers=0
for d in "${HOME}/.claude/plugins/cache/claude-plugins-official/superpowers/"*/skills/writing-plans; do
  [ -d "$d" ] && { found_superpowers=1; break; }
done
if [ "$found_superpowers" -eq 0 ]; then
  add_finding "REQUIRED" "superpowers" \
    "Plugin: superpowers (anthropic). Required for writing-plans, executing-plans, systematic-debugging skills.
       Install: enable superpowers@claude-plugins-official in ~/.claude/settings.json
       Or visit: https://github.com/anthropics/claude-code-plugins"
fi

# jq — every ensure-* script depends on it for settings.json mutation
if ! command -v jq &>/dev/null; then
  add_finding "REQUIRED" "jq" \
    "CLI: jq. Required by every ensure-* bootstrap and most lean-flow hooks.
       Install: brew install jq"
fi

# ── RECOMMENDED ──────────────────────────────────────────────────────
# OMNI — bash output distiller (~93% token savings on noisy commands)
if ! command -v omni &>/dev/null; then
  add_finding "RECOMMENDED" "omni" \
    "CLI: omni. Distills Bash tool output (~93% token savings on noisy commands).
       Install: brew install omni
       Then: omni init --all"
elif command -v jq &>/dev/null && [ -f "$SETTINGS" ]; then
  # Installed but not wired into hooks
  if ! jq -e '.. | objects | select(.command? // "" | test("omni"))' "$SETTINGS" &>/dev/null; then
    add_finding "RECOMMENDED" "omni-hooks" \
      "OMNI installed but hooks not registered in ~/.claude/settings.json.
       Fix: omni init --all"
  fi
fi

# GitNexus — repo knowledge graph MCP
if [ -f "$CLAUDE_JSON" ] && command -v jq &>/dev/null; then
  if ! jq -e '.mcpServers // {} | to_entries[] | select(.key | test("gitnexus"; "i"))' "$CLAUDE_JSON" &>/dev/null \
     && ! ([ -f "$SETTINGS" ] && jq -e '.. | objects | select(.command? // "" | test("gitnexus"; "i"))' "$SETTINGS" &>/dev/null); then
    add_finding "RECOMMENDED" "gitnexus" \
      "MCP: gitnexus. Codebase knowledge graph for fast structural queries.
       Install: ensure-gitnexus.sh registers it automatically on next SessionStart.
       Or manually: npx gitnexus mcp (then add to ~/.claude.json mcpServers)"
  fi
fi

# RTK — Bash command rewriter (60-90% savings on dev ops)
if ! command -v rtk &>/dev/null; then
  add_finding "RECOMMENDED" "rtk" \
    "CLI: rtk. Rewrites Bash commands to faster Rust equivalents (60-90% token savings on dev ops).
       Install: brew install rtk
       Then: rtk init --global"
fi

# Knowledge MCP database — pattern memory
if [ ! -f "${HOME}/.claude/knowledge/patterns.db" ]; then
  add_finding "RECOMMENDED" "knowledge-mcp" \
    "Pattern memory DB missing at ~/.claude/knowledge/patterns.db.
       Fix: ensure-knowledge-mcp.sh creates it on next SessionStart.
       Without it, pattern_search / pattern_store have no backing store."
fi

# Node (required for plan-server / plan-viewer)
if ! command -v node &>/dev/null; then
  add_finding "RECOMMENDED" "node" \
    "Runtime: node. Required for plan-server.mjs (localhost:3456 plan dashboard) and plan-viewer.mjs.
       Install: brew install node (or use nvm/nodenv)"
fi

# ── DEPRECATED ───────────────────────────────────────────────────────
# plan-plus plugin — replaced by superpowers:writing-plans + executing-plans
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  if jq -e '.enabledPlugins["plan-plus@plan-plus"] == true' "$SETTINGS" &>/dev/null; then
    add_finding "DEPRECATED" "plan-plus" \
      "Plugin: plan-plus is enabled but deprecated as of PR #20.
       It has been replaced by superpowers:writing-plans + superpowers:executing-plans.
       Disable: jq 'del(.enabledPlugins[\"plan-plus@plan-plus\"])' ~/.claude/settings.json"
  fi
fi

# plan-plus enforcement hook (old, blocks Task dispatches)
if [ -f "${HOME}/.claude/hooks/enforce-plan-plus.sh" ]; then
  add_finding "DEPRECATED" "plan-plus-hook" \
    "Hook: ~/.claude/hooks/enforce-plan-plus.sh exists.
       This is the old PreToolUse Task hook from the plan-plus era. It will block agent dispatches.
       Remove: mv ~/.claude/hooks/enforce-plan-plus.sh ~/.claude/hooks/.archive/"
fi

# ── Cache + emit ─────────────────────────────────────────────────────
# Build a stable signature from finding keys (column 2) so we can detect
# whether the missing-dep set changed since last session.
if [ "${#findings[@]}" -eq 0 ]; then
  exit 0
fi

# Compute hash from sorted finding keys
# md5 is BSD-specific (macOS); Linux ships md5sum. Use whichever is available.
if command -v md5 &>/dev/null; then
  hash_cmd="md5"
elif command -v md5sum &>/dev/null; then
  hash_cmd="md5sum"
else
  # Last-resort fallback: use a non-cryptographic but stable digest.
  hash_cmd="cksum"
fi
SIG=$(printf '%s\n' "${findings[@]}" | awk -F'|' '{print $1"|"$2}' | sort | $hash_cmd | awk '{print $1}')
CACHE_FILE="${HOME}/.lean-flow-dep-check.${SIG}"

# Already warned about this exact set in a previous session — stay silent
[ -f "$CACHE_FILE" ] && exit 0

# Mark as warned and clean up old caches (keep last 5)
touch "$CACHE_FILE"
ls -1t "${HOME}/.lean-flow-dep-check."* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

# Format message grouped by bucket
required=""
recommended=""
deprecated=""
for f in "${findings[@]}"; do
  bucket="${f%%|*}"
  rest="${f#*|}"
  key="${rest%%|*}"
  hint="${rest#*|}"
  case "$bucket" in
    REQUIRED)    required="${required}\n  • ${key}: ${hint}\n" ;;
    RECOMMENDED) recommended="${recommended}\n  • ${key}: ${hint}\n" ;;
    DEPRECATED)  deprecated="${deprecated}\n  • ${key}: ${hint}\n" ;;
  esac
done

MSG="[lean-flow] dependency audit — ${#findings[@]} item(s) need attention:"
[ -n "$required" ]    && MSG="${MSG}\n\n[REQUIRED] (workflow routes here, missing = broken):${required}"
[ -n "$recommended" ] && MSG="${MSG}\n\n[RECOMMENDED] (degraded experience without):${recommended}"
[ -n "$deprecated" ]  && MSG="${MSG}\n\n[DEPRECATED] (remove or disable):${deprecated}"
MSG="${MSG}\n\nThis warning fires once per missing-set change. Re-run the relevant ensure-* script or follow the install hint above."

# Convert literal \n into real newlines for jq, then emit as systemMessage
printf '%b' "$MSG" | jq -Rs '{systemMessage: .}' 2>/dev/null

exit 0
