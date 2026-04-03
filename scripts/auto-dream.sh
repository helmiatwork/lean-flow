#!/bin/bash
# Auto Dream — Memory consolidation on session stop
# Dual-gated: runs only after 5+ sessions AND 24+ hours since last dream

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
DREAM_STATE_DIR="${HOME}/.claude/dream-state"
DREAM_PROMPT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")}/scripts/auto-dream-prompt.md"

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
  if [ "$elapsed" -lt 86400 ]; then
    exit 0
  fi
fi

# Gate 2: 5+ sessions since last consolidation
if [ "$count" -lt 5 ]; then
  exit 0
fi

# Check lock (prevent concurrent runs)
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
  if [ "$lock_age" -lt 600 ]; then
    exit 0
  fi
  rm -f "$LOCK_FILE"
fi

# Both gates passed — consolidate in background
touch "$LOCK_FILE"

(
  "$CLAUDE_BIN" --print --model claude-haiku-4-5-20251001 \
    --allowedTools "Read,Write,Edit,Glob,Grep" \
    --max-turns 20 \
    < "$DREAM_PROMPT" 2>/dev/null

  date +%s > "$LAST_DREAM_FILE"
  echo "0" > "$SESSION_COUNT_FILE"
  rm -f "$LOCK_FILE"
) &

exit 0
