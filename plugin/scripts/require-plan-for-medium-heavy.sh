#!/usr/bin/env bash
# require-plan-for-medium-heavy.sh
# PreToolUse hook for Write|Edit — enforces the rule from CLAUDE.md:
#   "Medium/heavy tasks must invoke superpowers:writing-plans before code changes."
#
# State files (managed by Claude during the session):
#   ${CLAUDE_STATE_DIR:-~/.claude/state}/current-task.classification   contents: simple|medium|heavy|hotfix|bug
#   ${CLAUDE_STATE_DIR:-~/.claude/state}/current-task.plan             contents: path or marker (presence = plan exists)
#
# Behavior:
#   - LEAN_FLOW_REQUIRE_PLAN_ENABLED != "true"  -> allow (opt-in disabled by default)
#   - No classification file present  -> allow (unclassified / simple-by-default)
#   - classification = medium|heavy   -> REQUIRE plan marker, else BLOCK (exit 2)
#   - any other classification        -> allow
#
# Opt-in: LEAN_FLOW_REQUIRE_PLAN_ENABLED=true

set -uo pipefail

[[ "${LEAN_FLOW_REQUIRE_PLAN_ENABLED:-}" != "true" ]] && exit 0

STATE_DIR="${CLAUDE_STATE_DIR:-${HOME}/.claude/state}"
CLASSIFICATION_FILE="${STATE_DIR}/current-task.classification"
PLAN_MARKER="${STATE_DIR}/current-task.plan"

# No classification recorded -> don't block. The orchestrator is responsible for
# writing the classification when STAR fires for medium/heavy work.
[[ -f "$CLASSIFICATION_FILE" ]] || exit 0

CLASSIFICATION="$(tr -d '[:space:]' < "$CLASSIFICATION_FILE" | tr '[:upper:]' '[:lower:]')"

case "$CLASSIFICATION" in
  medium|heavy)
    if [[ ! -f "$PLAN_MARKER" ]]; then
      cat >&2 <<EOF
[require-plan hook] BLOCKED: task classified as '${CLASSIFICATION}' but no plan exists.

Global CLAUDE.md rule: medium/heavy tasks require superpowers:writing-plans
BEFORE any Edit/Write tool call.

Required next steps:
  1. Invoke the superpowers:writing-plans skill and produce a plan.
  2. After the plan is written, record it:
       echo "<plan-path>" > ${PLAN_MARKER}
  3. Retry the Edit/Write.

Escape hatches:
  - Reclassify as simple:   echo "simple" > ${CLASSIFICATION_FILE}
  - Clear task state:       rm ${CLASSIFICATION_FILE} ${PLAN_MARKER} 2>/dev/null
EOF
      exit 2
    fi
    ;;
  *)
    : # simple|hotfix|bug|unknown -> allow
    ;;
esac

exit 0
