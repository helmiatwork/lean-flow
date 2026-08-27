#!/usr/bin/env bash
# Session briefing — two parts:
#   1. Orchestrator role declaration (always fires, every session start, not cached)
#      Reminds the main session it IS the orchestrator and points to canonical contracts.
#   2. Repo/branch/pattern briefing (cached per unique state, zero tokens on repeat)

# Always-fire role declaration first (independent of git/cache)
ORCHESTRATOR_CTX='🎯 You are the **orchestrator** (main Claude Code session, opus). You are NOT a subagent. Your role contract is `${CLAUDE_PLUGIN_ROOT}/agents/orchestrator.md` — load it when classifying any non-trivial prompt.

Tier routing: simple → edit directly · medium/heavy → plan via `superpowers:writing-plans` then delegate `lean-flow:fixer` (haiku) end-to-end (impl + tests ≥90% + linters + commit + push + PR + code-reviewer + oracle + merge) · greenfield → docs-first · hotfix → fast path.

Hard rules: never edit code for medium/heavy (delegate) · never push to `main` directly · never `--no-verify` · never include Claude/AI/Co-Authored-By attribution · 3 combined code-reviewer+oracle rounds is the hard cap → human escalation.

Canonical workflow + mermaid: `${CLAUDE_PLUGIN_ROOT}/workflows/standard-development-flow.md`.'

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  # Not in a git repo — emit role declaration only
  if command -v jq &>/dev/null; then
    jq -n --arg ctx "$ORCHESTRATOR_CTX" \
      '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}}'
  fi
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
CHANGES=$(git status --short 2>/dev/null | head -20)

# Query patterns to include in state hash for cache invalidation
PATTERN_SIG=""
KNOWLEDGE_DB="${HOME}/.gemini/knowledge/patterns.db"
if [ -f "$KNOWLEDGE_DB" ] && command -v sqlite3 &>/dev/null; then
  PATTERN_SIG=$(sqlite3 "$KNOWLEDGE_DB" \
    "SELECT GROUP_CONCAT(key) FROM (SELECT key FROM patterns WHERE project='${REPO}' AND category != 'session-observation' ORDER BY score DESC, used_count DESC, created_at DESC LIMIT 3);" 2>/dev/null || echo "")

  PATTERNS=$(sqlite3 "$KNOWLEDGE_DB" \
    "SELECT solution FROM patterns WHERE project='${REPO}' AND category != 'session-observation' ORDER BY score DESC, used_count DESC, created_at DESC LIMIT 3;" 2>/dev/null || echo "")
fi

# Cache key: changes only if repo/branch/working-tree/patterns actually changed
STATE_HASH=$(printf '%s\n%s\n%s\n%s' "$REPO" "$BRANCH" "$CHANGES" "$PATTERN_SIG" | md5)
CACHE_FILE="/tmp/claude-briefing-${STATE_HASH}.cache"

# If state-cached, emit role declaration only and skip the briefing payload
if [ -f "$CACHE_FILE" ]; then
  if command -v jq &>/dev/null; then
    jq -n --arg ctx "$ORCHESTRATOR_CTX" \
      '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}}'
  fi
  exit 0
fi

touch "$CACHE_FILE"

# Clean up old briefing caches (keep last 20) — portable across BSD/GNU head
find /tmp -maxdepth 1 -name "claude-briefing-*.cache" 2>/dev/null | \
  sort -t- -k3 | awk 'NR>20' | xargs -r python3 -c "import sys,os; [os.remove(f) for f in sys.argv[1:]]" 2>/dev/null || true

PATTERN_BULLETS=""
if [ -n "$PATTERNS" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && PATTERN_BULLETS="${PATTERN_BULLETS}
💡 ${p:0:80}"
  done <<< "$PATTERNS"
fi

BRIEFING="${REPO} | ${BRANCH}
${CHANGES:-(clean)}${PATTERN_BULLETS}"

if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" --arg ctx "$ORCHESTRATOR_CTX" \
    '{"systemMessage": $msg, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}}'
else
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
