#!/usr/bin/env bash
# Knowledge pre-filter — inject relevant patterns when planning starts
# Fires on EnterPlanMode (PostToolUse) to surface solved patterns before re-solving

KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
[ ! -f "$KNOWLEDGE_DB" ] || ! command -v sqlite3 &>/dev/null && exit 0

REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
[ "$REPO" = "unknown" ] && exit 0

# Try FTS5 search with repo name as seed, fall back to score ordering
PATTERNS=$(python3 - "$KNOWLEDGE_DB" "$REPO" <<'PYEOF'
import sqlite3, sys

db_path, repo = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db_path)

# FTS5 search seeded with repo name — finds patterns tagged/keyed to this project
try:
    rows = con.execute("""
        SELECT p.key, p.solution
        FROM patterns_fts f
        JOIN patterns p ON p.id = f.rowid
        WHERE patterns_fts MATCH ?
          AND p.category != 'session-observation'
        ORDER BY rank
        LIMIT 5
    """, (f'"{repo}"',)).fetchall()
except Exception:
    rows = []

# Fallback: score-based for this project
if not rows:
    rows = con.execute("""
        SELECT key, solution FROM patterns
        WHERE project = ? AND category != 'session-observation'
        ORDER BY score DESC, used_count DESC
        LIMIT 5
    """, (repo,)).fetchall()

for key, solution in rows:
    sol = (solution or '')[:80]
    print(f"• {key}: {sol}")
PYEOF
)

[ -z "$PATTERNS" ] && exit 0

MSG="🧠 Relevant patterns for ${REPO} — check before re-solving:
${PATTERNS}"

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}' 2>/dev/null || \
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
    "$(printf '%s' "$MSG" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n')"
