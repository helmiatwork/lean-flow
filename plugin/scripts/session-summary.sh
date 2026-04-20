#!/usr/bin/env bash
# session-summary.sh
# PostCompact: save compaction summary to ~/.claude/session-summaries/

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hookEventName // empty' 2>/dev/null)
SUMMARY=$(printf '%s' "$INPUT" | jq -r '.summary // empty' 2>/dev/null)

# Fallback: Stop event saves a lightweight marker
if [ "$EVENT" = "Stop" ] || [ -z "$SUMMARY" ]; then
  SUMMARY="Session ended (no compact summary available)."
fi

SAVE_DIR="$HOME/.claude/session-summaries"
mkdir -p "$SAVE_DIR"

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
PROJECT=$(basename "$PWD")
FILENAME="${TIMESTAMP}_${PROJECT}.md"

cat > "$SAVE_DIR/$FILENAME" <<EOF
---
date: $(date '+%Y-%m-%d %H:%M:%S')
project: $PROJECT
session_id: ${SESSION_ID:-unknown}
trigger: ${EVENT:-Stop}
---

$SUMMARY
EOF

# Keep only last 50 summaries
ls -1t "$SAVE_DIR"/*.md 2>/dev/null | tail -n +51 | xargs rm -f 2>/dev/null

exit 0
