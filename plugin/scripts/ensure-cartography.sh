#!/usr/bin/env bash
# Hybrid cartography session check.
# Tier 1: docs/CODEBASE_MAP.md (high-level atlas via git log)
# Tier 2: per-folder codemap.md (module detail via cartographer.py changes)
# Runs on SessionStart — idempotent.

HAS_UV=false
HAS_PYTHON=false
command -v uv &>/dev/null && HAS_UV=true
command -v python3 &>/dev/null && HAS_PYTHON=true

if [ "$HAS_UV" = false ] && [ "$HAS_PYTHON" = false ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Cartographer requires python3 or uv but neither is installed."
}
EOF
  exit 0
fi

# Must be in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0

MSGS=""

# --- Tier 1: docs/CODEBASE_MAP.md ---
if [ -f "${REPO_ROOT}/docs/CODEBASE_MAP.md" ]; then
  LAST_MAPPED=$(grep -m1 'last_mapped:' "${REPO_ROOT}/docs/CODEBASE_MAP.md" 2>/dev/null | sed 's/last_mapped: *//')
  if [ -n "$LAST_MAPPED" ]; then
    T1_COUNT=$(git log --oneline --since="$LAST_MAPPED" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$T1_COUNT" -gt 0 ] 2>/dev/null; then
      MSGS="${MSGS}Tier 1: ${T1_COUNT} commits since last CODEBASE_MAP.md mapping. "
    fi
  fi
else
  MSGS="${MSGS}Tier 1: No docs/CODEBASE_MAP.md found. "
fi

# --- Tier 2: per-folder codemap.md ---
CARTOGRAPHER="${CLAUDE_PLUGIN_ROOT}/scripts/cartographer.py"
if [ -f "${REPO_ROOT}/.slim/cartography.json" ] && [ -f "$CARTOGRAPHER" ]; then
  if [ "$HAS_PYTHON" = true ]; then
    T2_OUTPUT=$(python3 "$CARTOGRAPHER" changes --root "$REPO_ROOT" 2>/dev/null)
  fi
  if [ -n "$T2_OUTPUT" ] && ! echo "$T2_OUTPUT" | grep -q "No changes detected"; then
    T2_FOLDERS=$(echo "$T2_OUTPUT" | grep "folders affected" | grep -o "[0-9]*")
    [ -n "$T2_FOLDERS" ] && MSGS="${MSGS}Tier 2: ${T2_FOLDERS} folders have changed codemaps. "
  fi
elif [ -f "$CARTOGRAPHER" ] && [ ! -f "${REPO_ROOT}/.slim/cartography.json" ]; then
  MSGS="${MSGS}Tier 2: No .slim/cartography.json — per-folder codemaps not initialized. "
fi

# --- Emit combined message ---
if [ -z "$MSGS" ]; then
  exit 0
fi

if command -v jq &>/dev/null; then
  jq -n --arg msg "[lean-flow] Cartographer: ${MSGS}Run /cartographer to update." \
    '{"systemMessage": $msg}'
else
  printf '{"systemMessage":"[lean-flow] Cartographer: %s Run /cartographer to update."}\n' "$MSGS"
fi

exit 0
