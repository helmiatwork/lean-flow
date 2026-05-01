#!/usr/bin/env bash
# Markdown cross-reference linter
#
# Walks every *.md under plugin/skills/ and plugin/workflows/, extracts
# inline references like `some-file.md` and `@some-file.md`, and asserts
# that each referenced .md exists in the same directory or is a known
# external skill (lean-flow:* or superpowers:*).
#
# Catches the bug class fixed in PR #20 (root-cause-tracing.md,
# defense-in-depth.md, condition-based-waiting.md, testing-anti-patterns.md
# were all referenced but didn't exist).
#
# Allowed forms — these do NOT need to resolve to a local file:
#   - `superpowers:<skill-name>`
#   - `lean-flow:<skill-name>`
#   - retirement notes that explicitly say "was retired" or "in favor of"
#
# Anything else like \`some-name.md\` (file extension, no namespace prefix)
# must resolve to an actual file.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/plugin/skills"
WORKFLOWS_DIR="${REPO_ROOT}/plugin/workflows"

PASS=0
FAIL=0
DANGLING=()

# Known retired filenames — referenced ONLY in retirement-context notes
# (e.g. "the local foo.md was retired"). These are allowed to appear.
RETIRED=(
  "root-cause-tracing.md"
  "defense-in-depth.md"
  "condition-based-waiting.md"
  "testing-anti-patterns.md"
)

is_retired() {
  local name="$1"
  for r in "${RETIRED[@]}"; do
    [ "$name" = "$r" ] && return 0
  done
  return 1
}

scan_file() {
  local md="$1"
  local md_dir
  md_dir=$(dirname "$md")
  local rel="${md#$REPO_ROOT/}"

  # Only flag refs that appear in clear "go read this file" patterns:
  #   - "See `foo.md`"
  #   - "read `foo.md`"
  #   - "@foo.md"
  #   - "(see `foo.md`)" or "(`foo.md`)"
  # Output filenames mentioned descriptively (e.g. "Generates STRUCTURE.md")
  # are NOT flagged — they're produced artifacts, not broken pointers.
  local refs
  refs=$(grep -ohiE '(see|read|invoke|in this directory.*) ?[`@][a-zA-Z0-9_/-]+\.md|@[a-zA-Z0-9_/-]+\.md' "$md" 2>/dev/null \
    | grep -ohE '[`@][a-zA-Z0-9_/-]+\.md' \
    | sed -e 's/^`//' -e 's/`$//' -e 's/^@//' \
    | sort -u)

  [ -z "$refs" ] && return 0

  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    local basename
    basename=$(basename "$ref")

    # Skip retired files when the line they appear on contains a retirement
    # marker. We grep the file for the ref; if every line containing the ref
    # also has "retired" or "was folded" or "deprecated", treat as resolved.
    if is_retired "$basename"; then
      local non_retirement_lines
      non_retirement_lines=$(grep -F "$basename" "$md" 2>/dev/null \
        | grep -v -iE 'retired|was folded|deprecated|in favor of' \
        | wc -l | tr -d ' ')
      if [ "$non_retirement_lines" -eq 0 ]; then
        continue
      fi
    fi

    # Resolve in this order:
    #   1. Reference contains a path separator → resolve from repo root
    #   2. Same directory as the referencing file
    #   3. plugin/skills/ or plugin/workflows/
    #   4. Repo root (README.md, CHANGELOG.md, LICENSE, etc.)
    if [[ "$ref" == */* ]]; then
      [ -f "$REPO_ROOT/$ref" ] && continue
    fi
    if [ -f "$md_dir/$basename" ] \
       || [ -f "$SKILLS_DIR/$basename" ] \
       || [ -f "$WORKFLOWS_DIR/$basename" ] \
       || [ -f "$REPO_ROOT/$basename" ]; then
      continue
    fi

    DANGLING+=("$rel → $ref")
  done <<< "$refs"
}

# Walk plugin/skills and plugin/workflows
echo "=== Scanning plugin/skills + plugin/workflows for dangling .md references ==="
while IFS= read -r f; do
  scan_file "$f"
done < <(find "$SKILLS_DIR" "$WORKFLOWS_DIR" -type f -name "*.md" 2>/dev/null)

if [ "${#DANGLING[@]}" -eq 0 ]; then
  echo "✓ no dangling .md references found"
  PASS=$((PASS+1))
else
  echo "✗ ${#DANGLING[@]} dangling reference(s) found:"
  for d in "${DANGLING[@]}"; do
    echo "    - $d"
  done
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Verifying retired files do NOT exist (they should be redirects, not real files) ==="
for r in "${RETIRED[@]}"; do
  if [ -f "$SKILLS_DIR/$r" ]; then
    echo "✗ retired file still exists: plugin/skills/$r — should have been removed"
    FAIL=$((FAIL+1))
  else
    echo "✓ retired file absent: $r (redirect-only)"
    PASS=$((PASS+1))
  fi
done

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
