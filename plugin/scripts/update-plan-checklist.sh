#!/usr/bin/env bash
# PostToolUse:Bash hook (git commit gate) — auto-update plan checklist boxes based on recent commit messages.
# Disabled by default; user must explicitly opt in via LEAN_FLOW_AUTOSYNC=1
set -uo pipefail

# Disabled by default; user must explicitly opt in
[ "${LEAN_FLOW_AUTOSYNC:-0}" != "1" ] && exit 0

# Find git repo root; abort silently if not in a repo
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

# Idempotency: only process each commit once
CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null) || exit 0
REPO_HASH=$(printf '%s' "$REPO_ROOT" | shasum 2>/dev/null | cut -c1-12)
CACHE_FILE="/tmp/lean-flow-autosync-${REPO_HASH}.sha"
[ -f "$CACHE_FILE" ] && [ "$(cat "$CACHE_FILE")" = "$CURRENT_SHA" ] && exit 0
echo "$CURRENT_SHA" > "$CACHE_FILE"

# Locate plan files in known conventions
PLAN_FILES=()
if [ -d ".plans" ]; then
  while IFS= read -r f; do
    PLAN_FILES+=("$f")
  done < <(find .plans -maxdepth 3 -name "plan-full.md" -type f 2>/dev/null || true)
fi
if [ -d ".planning" ]; then
  while IFS= read -r f; do
    PLAN_FILES+=("$f")
  done < <(find .planning -maxdepth 4 -name "PLAN.md" -type f 2>/dev/null || true)
fi
if [ -d ".planning/phases" ]; then
  while IFS= read -r f; do
    PLAN_FILES+=("$f")
  done < <(find .planning/phases -maxdepth 3 -name "PLAN.md" -type f 2>/dev/null || true)
fi
[ ${#PLAN_FILES[@]} -eq 0 ] && exit 0

# Get the most recent commit subject
COMMIT_MSG=$(git log -1 --format=%s 2>/dev/null) || exit 0
[ -z "$COMMIT_MSG" ] && exit 0

# Extract step number from commit msg via structured marker
STEP_NUM=""
case "$COMMIT_MSG" in
  *"[step:"*"]"*)
    STEP_NUM=$(printf '%s' "$COMMIT_MSG" | sed -n 's/.*\[step:\([0-9][0-9]*\)\].*/\1/p')
    ;;
  *"closes step-"*)
    STEP_NUM=$(printf '%s' "$COMMIT_MSG" | sed -n 's/.*closes step-\([0-9][0-9]*\).*/\1/p')
    ;;
esac
[ -z "$STEP_NUM" ] && exit 0

MARKED=0
for plan in "${PLAN_FILES[@]}"; do
  # Find all unchecked lines (starting from 1)
  line_count=0
  while IFS= read -r line_num; do
    [ -z "$line_num" ] && continue
    line_count=$((line_count+1))
    # Mark the Nth unchecked line where N matches STEP_NUM
    if [ "$line_count" -eq "$STEP_NUM" ]; then
      tmp=$(mktemp)
      awk -v ln="$line_num" 'NR==ln {sub(/- \[ \]/, "- [x]")} 1' "$plan" > "$tmp" && mv "$tmp" "$plan"
      echo "[plan-checklist] MARK: $plan:$line_num (step $STEP_NUM) from commit \"$COMMIT_MSG\"" >&2
      MARKED=$((MARKED+1))
      break
    fi
  done < <(grep -n '^- \[ \]' "$plan" 2>/dev/null | cut -d: -f1 || true)
done

[ "$MARKED" -gt 0 ] && echo "[plan-checklist] auto-marked $MARKED checkbox(es) via [step:N] marker" >&2
exit 0
