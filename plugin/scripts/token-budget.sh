#!/usr/bin/env bash
# Token budget tracker — estimate tokens consumed by lean-flow context injection
# Usage: bash token-budget.sh [--detail]

DETAIL="${1:-}"

count_tokens() {
  local file="$1"
  if [ -f "$file" ]; then
    chars=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
    echo $(( chars / 4 ))
  else
    echo 0
  fi
}

total=0

# Agent prompts
agent_total=0
for agent in ~/Documents/repo/lean-flow/lean-flow/agents/*.md; do
  if [ -f "$agent" ]; then
    t=$(count_tokens "$agent")
    agent_total=$((agent_total + t))
  fi
done
total=$((total + agent_total))

# Memory files
memory_total=0
for memdir in ~/.claude/projects/*/memory/; do
  [ -d "$memdir" ] || continue
  for memfile in "$memdir"*.md; do
    if [ -f "$memfile" ]; then
      t=$(count_tokens "$memfile")
      memory_total=$((memory_total + t))
    fi
  done
done
total=$((total + memory_total))

# Knowledge patterns (estimate from DB)
pattern_total=0
KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
if [ -f "$KNOWLEDGE_DB" ] && command -v sqlite3 &>/dev/null; then
  pattern_chars=$(sqlite3 "$KNOWLEDGE_DB" "SELECT SUM(LENGTH(problem) + LENGTH(solution)) FROM patterns;" 2>/dev/null || echo "0")
  pattern_total=$(( ${pattern_chars:-0} / 4 ))
fi
total=$((total + pattern_total))

# CLAUDE.md files
claude_total=0
if git rev-parse --is-inside-work-tree &>/dev/null 2>/dev/null; then
  root=$(git rev-parse --show-toplevel 2>/dev/null)
  for cf in "$root/CLAUDE.md" "$HOME/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; do
    t=$(count_tokens "$cf")
    claude_total=$((claude_total + t))
  done
fi
total=$((total + claude_total))

echo "=== lean-flow Token Budget ==="
echo "  Agents:     ~${agent_total} tokens"
echo "  Memory:     ~${memory_total} tokens"
echo "  Patterns:   ~${pattern_total} tokens"
echo "  CLAUDE.md:  ~${claude_total} tokens"
echo "  ─────────────────────────"
echo "  TOTAL:      ~${total} tokens"
echo ""

if [ "$DETAIL" = "--detail" ]; then
  echo "--- Memory files ---"
  for memdir in ~/.claude/projects/*/memory/; do
    [ -d "$memdir" ] || continue
    project=$(basename "$(dirname "$memdir")")
    for memfile in "$memdir"*.md; do
      if [ -f "$memfile" ]; then
        t=$(count_tokens "$memfile")
        echo "  ${project}/$(basename "$memfile"): ~${t} tokens"
      fi
    done
  done

  echo ""
  echo "--- Knowledge patterns ---"
  if [ -f "$KNOWLEDGE_DB" ] && command -v sqlite3 &>/dev/null; then
    sqlite3 "$KNOWLEDGE_DB" "
      SELECT project, name, score, used_count,
             (LENGTH(problem) + LENGTH(solution)) / 4 as est_tokens
      FROM patterns
      ORDER BY est_tokens DESC
      LIMIT 10;
    " 2>/dev/null | while IFS='|' read -r proj name score used tokens; do
      echo "  [${proj}] ${name} (score:${score} used:${used}x) ~${tokens} tokens"
    done
  fi
fi

# Output for hook consumption
if [ -n "$LEAN_FLOW_HOOK_MODE" ]; then
  jq -n --arg t "$total" '{"systemMessage": ("Token budget: ~" + $t + " tokens injected by lean-flow")}' 2>/dev/null
fi
