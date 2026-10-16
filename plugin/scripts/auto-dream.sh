#!/usr/bin/env bash
# Auto Dream — Memory consolidation on session stop
# Dual-gated: runs only after N sessions AND N hours since last dream

# Load config (sets LEAN_FLOW_DREAM_SESSIONS and LEAN_FLOW_DREAM_HOURS)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
source "${SCRIPT_DIR}/load-config.sh" 2>/dev/null || true

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
DREAM_STATE_DIR="${HOME}/.claude/dream-state"
DREAM_PROMPT="${CLAUDE_PLUGIN_ROOT}/scripts/auto-dream-prompt.md"

# Bail if CLAUDE_PLUGIN_ROOT is not set (can't find prompt file)
if [ -z "$CLAUDE_PLUGIN_ROOT" ] || [ ! -f "$DREAM_PROMPT" ]; then
  exit 0
fi

mkdir -p "$DREAM_STATE_DIR"

LAST_DREAM_FILE="$DREAM_STATE_DIR/last-dream"
SESSION_COUNT_FILE="$DREAM_STATE_DIR/session-count"
LOCK_FILE="$DREAM_STATE_DIR/dream.lock"

# Increment session count
count=0
if [ -f "$SESSION_COUNT_FILE" ]; then
  count=$(cat "$SESSION_COUNT_FILE")
fi
count=$((count + 1))
echo "$count" > "$SESSION_COUNT_FILE"

# Gate 1: 24 hours since last consolidation
if [ -f "$LAST_DREAM_FILE" ]; then
  last_dream=$(cat "$LAST_DREAM_FILE")
  now=$(date +%s)
  elapsed=$((now - last_dream))
  _dream_seconds=$(( LEAN_FLOW_DREAM_HOURS * 3600 ))
  if [ "$elapsed" -lt "$_dream_seconds" ]; then
    exit 0
  fi
fi

# Gate 2: N+ sessions since last consolidation
if [ "$count" -lt "$LEAN_FLOW_DREAM_SESSIONS" ]; then
  exit 0
fi

# Check lock (prevent concurrent runs) — portable stat
if [ -f "$LOCK_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    lock_mtime=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
  else
    lock_mtime=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
  fi
  lock_age=$(($(date +%s) - lock_mtime))
  if [ "$lock_age" -lt 600 ]; then
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi

# Both gates passed — consolidate in background
touch "$LOCK_FILE"

(
  # 5 minute timeout to prevent zombie processes
  timeout 300 "$CLAUDE_BIN" --print --model claude-haiku-4-5-20251001 \
    --allowedTools "Read,Write,Edit,Glob,Grep" \
    --max-turns 20 \
    < "$DREAM_PROMPT" 2>/dev/null

  date +%s > "$LAST_DREAM_FILE"
  echo "0" > "$SESSION_COUNT_FILE"
  rm -f "$LOCK_FILE"
) &

exit 0
