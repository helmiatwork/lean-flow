#!/usr/bin/env bash
# PostToolUse:Task hook — auto-update plan checklist boxes based on recent commit messages.
# Aggressive: marks all matches and prints warning per match for audit.
set -uo pipefail

# Find git repo root; abort silently if not in a repo
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

# Locate plan files in known conventions
PLAN_FILES=()
if [ -d ".plans" ]; then
  while IFS= read -r f; do
    PLAN_FILES+=("$f")
  done < <(find .plans -maxdepth 3 -name "plan-full.md" -type f 2>/dev/null)
fi
if [ -d ".planning" ]; then
  while IFS= read -r f; do
    PLAN_FILES+=("$f")
  done < <(find .planning -maxdepth 4 -name "PLAN.md" -type f 2>/dev/null)
fi
[ ${#PLAN_FILES[@]} -eq 0 ] && exit 0

# Get the most recent commit subject
COMMIT_MSG=$(git log -1 --format=%s 2>/dev/null) || exit 0
[ -z "$COMMIT_MSG" ] && exit 0

# Lowercase for matching
LOWER_MSG=$(printf '%s' "$COMMIT_MSG" | tr '[:upper:]' '[:lower:]')

MARKED=0
for plan in "${PLAN_FILES[@]}"; do
  # Read each unchecked line, extract the heading text after "- [ ]"
  while IFS= read -r line_num; do
    [ -z "$line_num" ] && continue
    heading=$(sed -n "${line_num}p" "$plan" | sed -E 's/^- \[ \] //; s/^[[:space:]]*//')
    [ -z "$heading" ] && continue
    # Take first 4 significant words from heading, lowercase
    keywords=$(printf '%s' "$heading" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | awk '{for(i=1;i<=NF && i<=4;i++) printf "%s ", $i; print ""}')
    matched=0
    for kw in $keywords; do
      [ ${#kw} -lt 4 ] && continue
      case "$LOWER_MSG" in
        *"$kw"*) matched=$((matched+1)) ;;
      esac
    done
    # If 2+ keywords match, flip the checkbox
    if [ "$matched" -ge 2 ]; then
      # Use a tmp file for portable in-place edit (BSD sed compat)
      tmp=$(mktemp)
      awk -v ln="$line_num" 'NR==ln {sub(/- \[ \]/, "- [x]")} 1' "$plan" > "$tmp" && mv "$tmp" "$plan"
      echo "[plan-checklist] WARN: marked $plan:$line_num — \"$heading\" (matched $matched kw vs commit \"$COMMIT_MSG\")" >&2
      MARKED=$((MARKED+1))
    fi
  done < <(grep -n '^- \[ \]' "$plan" | cut -d: -f1)
done

[ "$MARKED" -gt 0 ] && echo "[plan-checklist] auto-marked $MARKED checkbox(es); audit the warnings above" >&2
exit 0
