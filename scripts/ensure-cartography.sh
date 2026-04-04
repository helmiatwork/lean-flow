#!/usr/bin/env bash
# Ensure cartographer.py is available and python3 exists.
# Runs on SessionStart — idempotent.
# Emits a system message reminding the agent to use cartography for new repos.

# Check if python3 is available
if ! command -v python3 &>/dev/null; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Cartography requires python3 but it's not installed. Install python3 to enable repository mapping."
}
EOF
  exit 0
fi

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0

CARTOGRAPHER="${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py"
[ ! -f "$CARTOGRAPHER" ] && exit 0

# If codemap.md exists at repo root, cartography is already initialized — check for changes
if [ -f "${REPO_ROOT}/codemap.md" ] && [ -f "${REPO_ROOT}/.slim/cartography.json" ]; then
  # Run changes detection silently
  CHANGES=$(python3 "$CARTOGRAPHER" changes --root "$REPO_ROOT" 2>/dev/null)
  if echo "$CHANGES" | grep -q "No changes detected"; then
    exit 0
  fi

  # Changes found — notify the agent
  if command -v jq &>/dev/null; then
    jq -n --arg msg "[lean-flow] Cartography: Repository files changed since last mapping. Run /cartography to update affected codemaps. Changes:\n${CHANGES}" \
      '{"systemMessage": $msg}'
  fi
  exit 0
fi

# No codemap exists — remind the agent about cartography
if [ ! -f "${REPO_ROOT}/codemap.md" ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Cartography available: This repo has no codemap.md. Run /cartography to generate a repository map for fast agent orientation (saves ~3K tokens vs explorer scanning)."
}
EOF
fi

exit 0
