#!/usr/bin/env bash
# Block Claude identity markers in git commits and PR creation

CMD=$(jq -r '.tool_input.command // ""')

# Block Co-Authored-By: Claude or similar in commit messages
if echo "$CMD" | grep -qiE 'git\s+commit.*(-m|--message)'; then
  if echo "$CMD" | grep -qiE 'Co-Authored-By.*Claude|Generated.*Claude|authored.*by.*Claude|AI.*generated'; then
    echo "Blocked: Never include Claude identity in commits. Remove Co-Authored-By or AI attribution lines." >&2
    exit 2
  fi
fi

# Block Claude identity in PR body
if echo "$CMD" | grep -qE 'gh\s+pr\s+create'; then
  if echo "$CMD" | grep -qiE 'Generated.*with.*Claude|Co-Authored-By.*Claude|Claude.*Code'; then
    echo "Blocked: Never include Claude identity in PRs. Remove Claude attribution from the PR body." >&2
    exit 2
  fi
fi
