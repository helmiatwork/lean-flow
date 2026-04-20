#!/usr/bin/env bash
# Pattern recall — query FTS5 before Claude starts working
# Fires on UserPromptSubmit to surface relevant solved patterns

KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
[ ! -f "$KNOWLEDGE_DB" ] || ! command -v sqlite3 &>/dev/null && exit 0

# Check DB has patterns worth querying
COUNT=$(sqlite3 "$KNOWLEDGE_DB" "SELECT COUNT(*) FROM patterns WHERE category != 'session-observation';" 2>/dev/null || echo "0")
[ "$COUNT" -lt 1 ] && exit 0

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] || [ "${#PROMPT}" -lt 20 ] && exit 0

REPO=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || echo "")

RESULT=$(python3 - "$KNOWLEDGE_DB" "$REPO" <<PYEOF
import sqlite3, sys, re

db_path = sys.argv[1]
repo = sys.argv[2] if len(sys.argv) > 2 else ''

prompt = """$PROMPT"""

# Extract keywords — remove stop words, take meaningful terms
stop = {'the','a','an','is','are','was','were','be','been','being','have','has','had',
        'do','does','did','will','would','could','should','may','might','must','shall',
        'to','of','in','on','at','by','for','with','about','from','into','through',
        'i','you','we','they','it','this','that','what','how','why','when','where',
        'and','or','but','if','so','because','please','can','need','want','make',
        'get','use','run','add','fix','update','create','write','read','check','just'}

words = re.findall(r'[a-zA-Z]{3,}', prompt.lower())
keywords = [w for w in words if w not in stop][:8]

if not keywords:
    sys.exit(0)

con = sqlite3.connect(db_path)

# Build FTS5 query — quote each term to avoid operator interpretation
fts_query = ' OR '.join(f'"{w}"' for w in keywords)

try:
    # Search project-scoped first
    rows = []
    if repo:
        rows = con.execute("""
            SELECT p.key, p.solution, p.category
            FROM patterns_fts f
            JOIN patterns p ON p.id = f.rowid
            WHERE patterns_fts MATCH ?
              AND p.project = ?
              AND p.category != 'session-observation'
            ORDER BY rank
            LIMIT 3
        """, (fts_query, repo)).fetchall()

    # Fallback: search all projects
    if not rows:
        rows = con.execute("""
            SELECT p.key, p.solution, p.category
            FROM patterns_fts f
            JOIN patterns p ON p.id = f.rowid
            WHERE patterns_fts MATCH ?
              AND p.category != 'session-observation'
            ORDER BY rank
            LIMIT 3
        """, (fts_query,)).fetchall()

    if not rows:
        sys.exit(0)

    for key, solution, category in rows:
        sol = (solution or '')[:100]
        print(f"• [{key}] {sol}")

except Exception:
    sys.exit(0)
PYEOF
)

[ -z "$RESULT" ] && exit 0

MSG="🧠 Matched patterns — apply before re-solving:
${RESULT}"

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}' 2>/dev/null || \
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
    "$(printf '%s' "$MSG" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n')"
