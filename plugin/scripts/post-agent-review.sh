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

# Extract agent name, transcript, and PR number
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

# Scan ALL assistant messages in the transcript to find the LAST verdict line
# This handles cases where the final message is a tool acknowledgment rather than the verdict
VERDICT_LINE=""
if [[ "$AGENT_NAME" == "code-reviewer" ]]; then
  VERDICT_LINE=$(printf '%s' "$TRANSCRIPT" | jq -r '.[] | select(.role=="assistant") | .content // "" | select(. != "")' 2>/dev/null | grep -E '^CODE_REVIEWER_AGENT: (✅ APPROVED|⚠️ CHANGES_REQUESTED)' | tail -1)
elif [[ "$AGENT_NAME" == "oracle" ]]; then
  VERDICT_LINE=$(printf '%s' "$TRANSCRIPT" | jq -r '.[] | select(.role=="assistant") | .content // "" | select(. != "")' 2>/dev/null | grep -E '^ORACLE_AGENT: (✅ APPROVED|⚠️ CHANGES_REQUESTED)' | tail -1)
fi

# If no verdict found, silently exit
if [[ -z "$VERDICT_LINE" ]]; then
  exit 0
fi

# Check if verdict comment already posted on this PR
# Match only exact verdict lines (one of the four valid verdicts) to avoid false positives from inline comments
EXISTING=$(gh pr view "$PR_NUMBER" --json comments --jq '.comments[].body' 2>/dev/null | grep -F -x "$VERDICT_LINE" || true)

# If comment already exists, silently exit (idempotent)
if [[ -n "$EXISTING" ]]; then
  exit 0
fi

# Post the verdict line as a summary comment
# Use HEREDOC to safely pass multiline content
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

printf '%s\n' "$VERDICT_LINE" > "$TMPFILE"

gh pr comment "$PR_NUMBER" -F "$TMPFILE" 2>/dev/null || true
