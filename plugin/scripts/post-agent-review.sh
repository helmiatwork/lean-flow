#!/usr/bin/env bash
# post-agent-review.sh — Post fallback verdict comments when code-reviewer or oracle finishes
#
# Called by SubagentStop hook after code-reviewer or oracle stops.
# Reads transcript to find verdict line, posts comment to PR if not already posted.
# Idempotent: checks for existing comment with same prefix before posting.
#
# Verdicts detected:
#   CODE_REVIEWER_AGENT: ✅ APPROVED
#   CODE_REVIEWER_AGENT: ⚠️ CHANGES_REQUESTED
#   ORACLE_AGENT: ✅ APPROVED
#   ORACLE_AGENT: ⚠️ CHANGES_REQUESTED

set -o pipefail

INPUT=$(cat)

# Extract agent name and last message
AGENT_NAME=$(printf '%s' "$INPUT" | jq -r '.agent_name // ""' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.messages // []' 2>/dev/null)
PR_NUMBER=$(printf '%s' "$INPUT" | jq -r '.metadata.pr_number // ""' 2>/dev/null)

# Only process code-reviewer and oracle agents
if [[ "$AGENT_NAME" != "code-reviewer" && "$AGENT_NAME" != "oracle" ]]; then
  exit 0
fi

# If no PR context, silently exit (not a PR review session)
if [[ -z "$PR_NUMBER" ]]; then
  exit 0
fi

# Find last assistant message containing verdict
LAST_MSG=$(printf '%s' "$TRANSCRIPT" | jq -r '.[-1].content // ""' 2>/dev/null)
if [[ -z "$LAST_MSG" ]]; then
  exit 0
fi

# Extract verdict line (agent: verdict emoji + status)
VERDICT_LINE=""
if [[ "$AGENT_NAME" == "code-reviewer" ]]; then
  VERDICT_LINE=$(printf '%s' "$LAST_MSG" | grep -m1 '^CODE_REVIEWER_AGENT:' || true)
elif [[ "$AGENT_NAME" == "oracle" ]]; then
  VERDICT_LINE=$(printf '%s' "$LAST_MSG" | grep -m1 '^ORACLE_AGENT:' || true)
fi

# If no verdict found, silently exit
if [[ -z "$VERDICT_LINE" ]]; then
  exit 0
fi

# Check if verdict comment already posted on this PR
# Use gh to fetch existing comments and grep for this agent's prefix
AGENT_PREFIX=$(printf '%s' "$VERDICT_LINE" | cut -d: -f1)
EXISTING=$(gh pr view "$PR_NUMBER" --json comments --jq '.comments[].body' 2>/dev/null | grep "^${AGENT_PREFIX}:" || true)

# If comment already exists, silently exit (idempotent)
if [[ -n "$EXISTING" ]]; then
  exit 0
fi

# Post the verdict line as a summary comment
# Use HEREDOC to safely pass multiline content
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

printf '%s\n' "$VERDICT_LINE" > "$TMPFILE"

gh pr comment "$PR_NUMBER" -F "$TMPFILE" 2>/dev/null || true
