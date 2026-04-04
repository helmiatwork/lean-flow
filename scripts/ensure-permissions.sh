#!/usr/bin/env bash
# Ensure Claude Code permissions allow the full lean-flow workflow
# to run end-to-end without user prompts (except protected branch pushes).
# Runs on SessionStart — idempotent.

SETTINGS_FILE="${HOME}/.claude/settings.json"

# Skip if settings file doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  exit 0
fi

# Skip if jq not available
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Required permissions for the workflow to run without prompts
REQUIRED_ALLOW=(
  "Agent"
  "TaskCreate"
  "TaskUpdate"
  "TaskGet"
  "TaskList"
  "EnterPlanMode"
  "ExitPlanMode"
  "SendMessage"
  "TeamCreate"
  "mcp__knowledge__*"
  "mcp__playwright__*"
  "Edit(~/.claude/plans/*)"
)

# Protected branches — deny direct push
REQUIRED_DENY=(
  "Bash(git push * master)"
  "Bash(git push * main)"
  "Bash(git push * staging)"
  "Bash(git push *--force*)"
  "Bash(git push *-f *)"
)

changed=false

# Add missing allow permissions
for perm in "${REQUIRED_ALLOW[@]}"; do
  if ! jq -e --arg p "$perm" '.permissions.allow // [] | index($p)' "$SETTINGS_FILE" &>/dev/null; then
    # Permission not found — add it
    tmp=$(mktemp)
    jq --arg p "$perm" '.permissions.allow = ((.permissions.allow // []) + [$p] | unique)' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    changed=true
  fi
done

# Add missing deny permissions
for perm in "${REQUIRED_DENY[@]}"; do
  if ! jq -e --arg p "$perm" '.permissions.deny // [] | index($p)' "$SETTINGS_FILE" &>/dev/null; then
    tmp=$(mktemp)
    jq --arg p "$perm" '.permissions.deny = ((.permissions.deny // []) + [$p] | unique)' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    changed=true
  fi
done

if [ "$changed" = true ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Permissions updated. Workflow tools (Agent, Tasks, PlanMode, SendMessage) auto-allowed. Protected branches (main/master/staging) push blocked."
}
EOF
fi

exit 0
