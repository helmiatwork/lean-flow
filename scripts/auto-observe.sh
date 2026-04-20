#!/usr/bin/env bash
# Auto-observe: silently capture session activity to patterns.db on Stop
# Zero tokens — no output, no API call

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] || [ -z "$CWD" ] && exit 0

LOG_FILE="/tmp/claude-sessions/${SESSION_ID}.log"
[ ! -f "$LOG_FILE" ] && exit 0

KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
[ ! -f "$KNOWLEDGE_DB" ] && exit 0

cd "$CWD" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree &>/dev/null 2>&1 || exit 0
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

python3 - "$LOG_FILE" "$KNOWLEDGE_DB" "$SESSION_ID" "$REPO" "$BRANCH" <<'PYEOF'
import json, sys, collections, sqlite3
from pathlib import Path

log_file, db_path, session_id, repo, branch = sys.argv[1:6]

lines = Path(log_file).read_text(errors='replace').splitlines()
events = []
for line in lines:
    try:
        events.append(json.loads(line))
    except Exception:
        pass

pre_tool = [e for e in events if e.get('event') == 'PreToolUse']
if len(pre_tool) < 3:
    sys.exit(0)

tool_counts = collections.Counter(e['tool'] for e in pre_tool if e.get('tool'))
tool_summary = ', '.join(f"{t}×{c}" for t, c in tool_counts.most_common(4))

key_words = ('git commit', 'npm', 'python', 'cargo', 'make', 'test', 'pytest', 'jest')
key_cmds = [
    e['summary'][:50] for e in pre_tool
    if e.get('tool') == 'Bash' and e.get('summary')
    and any(k in e['summary'] for k in key_words)
][:2]

ts_vals = [e['ts'] for e in events if 'ts' in e]
if len(ts_vals) >= 2:
    secs = ts_vals[-1] - ts_vals[0]
    duration = f"{secs//60}m" if secs >= 60 else f"{secs}s"
else:
    duration = '?'

parts = [tool_summary]
if key_cmds:
    parts.append(' · '.join(key_cmds))
observation = f"{repo} | {branch} | {', '.join(parts)} [{duration}]"

tags = ','.join(t for t, _ in tool_counts.most_common(4))
obs_key = f"obs-{session_id[:8]}"

try:
    con = sqlite3.connect(db_path)
    con.execute("""
        INSERT OR IGNORE INTO patterns
            (project, category, key, solution, context, tags)
        VALUES (?, 'session-observation', ?, ?, ?, ?)
    """, (repo, obs_key, observation, branch, tags))
    con.commit()
    con.close()
except Exception:
    pass
PYEOF

exit 0
