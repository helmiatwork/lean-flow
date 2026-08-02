#!/usr/bin/env bash
# Unified Bash PreToolUse guard — combines all git/gh blockers.
# Opt-out individual checks via env vars: LEAN_FLOW_<CHECK>_DISABLED=true
# Includes: no-verify, no-gpg-sign, protected-branch, secret-files, Claude identity, PR comments, merge-gate.

[[ "${LEAN_FLOW_BASH_GUARD_DISABLED:-}" == "true" ]] && exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# --- BLOCK: --no-verify / --no-gpg-sign ---
if [[ "${LEAN_FLOW_NO_VERIFY_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE 'git\s+(commit|push|merge|rebase).*--no-verify'; then
    echo "Blocked: --no-verify is not allowed. Fix the underlying hook issue instead." >&2
    exit 2
  fi
fi

if [[ "${LEAN_FLOW_NO_GPG_SIGN_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE 'git\s+commit.*--no-gpg-sign'; then
    echo "Blocked: --no-gpg-sign is not allowed." >&2
    exit 2
  fi
fi

# --- BLOCK: push to protected branches ---
if [[ "${LEAN_FLOW_PROTECTED_BRANCH_CHECK_DISABLED:-}" != "true" ]]; then
  _branches_pattern=$(echo "${LEAN_FLOW_PROTECTED_BRANCHES:-main master staging}" | tr ' ' '|')
  if echo "$CMD" | grep -qE "git\s+push\s+\S+\s+(${_branches_pattern})\s*\$"; then
    echo "{\"decision\":\"block\",\"reason\":\"Blocked: never push directly to protected branches. Create a feature branch and open a PR instead.\"}"
    exit 0
  fi
fi

# --- BLOCK: remote branch delete via push ---
if [[ "${LEAN_FLOW_BRANCH_DELETE_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE "git\s+push\s+\S+\s+--delete"; then
    echo "{\"decision\":\"block\",\"reason\":\"Blocked: never delete remote branches. This closes any associated PRs. Use --force-with-lease to update branch history instead.\"}"
    exit 0
  fi
fi

# --- BLOCK/ASK: staging secret files ---
if [[ "${LEAN_FLOW_SECRET_FILES_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE 'git\s+add.*(\s|/)\.env(\s|$|\.)|git\s+add.*credentials|git\s+add.*\.secret'; then
    echo "Blocked: Cannot stage secret/credential files (.env, credentials, .secret). Use .env.example instead." >&2
    exit 2
  fi
  if echo "$CMD" | grep -qE 'git\s+add\s+(-A|\.\s*$)'; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"git add -A/. may stage .env or credential files. Stage specific files instead."}}'
    exit 0
  fi
fi

# --- BLOCK: Claude identity in commits / PRs ---
if [[ "${LEAN_FLOW_CLAUDE_IDENTITY_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qiE 'git\s+commit.*(-m|--message)'; then
    if echo "$CMD" | grep -qiE 'Co-Authored-By.*Claude|Generated.*Claude|authored.*by.*Claude|AI.*generated'; then
      echo "Blocked: Never include Claude identity in commits. Remove Co-Authored-By or AI attribution lines." >&2
      exit 2
    fi
  fi
  if echo "$CMD" | grep -qE 'gh\s+pr\s+create'; then
    if echo "$CMD" | grep -qiE 'Generated.*with.*Claude|Co-Authored-By.*Claude|Claude.*Code'; then
      echo "Blocked: Never include Claude identity in PRs. Remove Claude attribution from the PR body." >&2
      exit 2
    fi
  fi
fi

# --- BLOCK: PR comments / reviews ---
if [[ "${LEAN_FLOW_PR_COMMENTS_CHECK_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE 'gh (pr review|pr comment|api .*/comments|api .*/reviews)'; then
    echo '{"decision":"block","reason":"BLOCKED: Never create PR comments or reviews. Push code changes directly to the branch instead."}'
    exit 0
  fi
fi

# --- ASK: merge to a protected branch without confirmed review (Hard Rule #14) ---
# Review-before-merge is keyed to the DESTINATION (any merge to main/master/staging),
# not the task tier — a "simple" change still crosses the gate. Forces a conscious
# checkpoint instead of a silently-skippable prose rule. Fail-open if gh/base unknown.
if [[ "${LEAN_FLOW_MERGE_GATE_DISABLED:-}" != "true" ]]; then
  if echo "$CMD" | grep -qE 'gh\s+pr\s+merge'; then
    # tail -1: the PR number is the LAST digit run on the merge command, so a
    # numeric --repo (org123/repo456) can't hijack extraction. ponytail: good
    # enough — a stray trailing number in an inline --body would still mislead,
    # but that mis-resolves to a wrong PR and fails open, never a false block.
    _pr=$(echo "$CMD" | grep -oE 'pr\s+merge[^|;&]*' | grep -oE '[0-9]+' | tail -1)
    if [[ -n "$_pr" ]]; then
      _base=$(gh pr view "$_pr" --json baseRefName -q .baseRefName 2>/dev/null)
    else
      _base=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null)
    fi
    _protected=$(echo "${LEAN_FLOW_PROTECTED_BRANCHES:-main master staging}" | tr ' ' '|')
    if echo "$_base" | grep -qE "^(${_protected})$"; then
      echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Merging to a protected branch. Hard Rule #14: both lean-flow:oracle AND lean-flow:code-reviewer must return APPROVED (including Oracle DoD verdict) before merge — regardless of tier. Confirm both reviews passed, or set LEAN_FLOW_MERGE_GATE_DISABLED=true to skip."}}'
      exit 0
    fi
  fi
fi

echo "$INPUT"
exit 0
