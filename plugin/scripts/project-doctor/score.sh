#!/usr/bin/env bash
# Fast project-doctor scanner. Checks 25 checklist items.
# Default: prints markdown table + score.
# --score-only:    prints just the number of passing checks (0-25, integer).
# --missing-only:  prints pipe-separated lines for [MISSING] and [STALE] items
#                  format: <num>|<label>|<file>|<severity>
#                  consumed by /project-doctor-fix command.

set -uo pipefail

ROOT="$(pwd)"

MODE="default"
case "${1:-}" in
  "") MODE="default" ;;
  --score-only) MODE="score-only" ;;
  --missing-only) MODE="missing-only" ;;
  -h|--help)
    echo "Usage: score.sh [--score-only|--missing-only]"
    exit 0
    ;;
  *)
    echo "Unknown flag: $1" >&2
    echo "Usage: score.sh [--score-only|--missing-only]" >&2
    exit 64
    ;;
esac

# Helper: check file exists and non-empty
has_file() {
  [ -s "$1" ] 2>/dev/null
  return $?
}

# Helper: check CLAUDE.md has a heading/section
claude_has_section() {
  if [ ! -f "$ROOT/CLAUDE.md" ]; then
    return 1
  fi
  grep -qiE "^#+\s*$1" "$ROOT/CLAUDE.md" 2>/dev/null
  return $?
}

# Helper: check stale (modified > 90 days ago)
is_stale() {
  [ -f "$1" ] || return 1
  local mtime
  mtime=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0)
  local now=$(date +%s)
  local diff=$(( (now - mtime) / 86400 ))
  [ "$diff" -gt 90 ]
}

declare -a RESULTS=()
declare -a ADVISORY=()
PRESENT=0
TOTAL=25

check() {
  local num="$1" label="$2" file="$3" severity="$4" status="$5"
  RESULTS+=("$num|$label|$file|$severity|$status")
  if [ "$status" = "[OK]" ]; then
    PRESENT=$((PRESENT + 1))
  fi
}

# Helper: advisory check (informational, no score impact)
advisory() {
  local num="$1" label="$2" file="$3" severity="$4" status="$5"
  ADVISORY+=("$num|$label|$file|$severity|$status")
}

# 1. Project overview — require explicit "Overview"/"About" section, OR
#    a non-trivial paragraph (>=40 chars) below H1 (descriptive lead).
overview_present() {
  [ -f "$ROOT/CLAUDE.md" ] || return 1
  if grep -qiE "^#+\s*(overview|about|description)" "$ROOT/CLAUDE.md" 2>/dev/null; then
    return 0
  fi
  awk '
    /^# / { found_h1=1; next }
    found_h1 && /^##/ { exit }
    found_h1 && NF > 0 { line = $0; gsub(/[ \t]/, "", line); if (length(line) >= 40) { print "yes"; exit } }
  ' "$ROOT/CLAUDE.md" 2>/dev/null | grep -q yes
}
if overview_present; then
  check 1 "Project overview" "CLAUDE.md" P0 "[OK]"
else
  check 1 "Project overview" "CLAUDE.md" P0 "[MISSING]"
fi

# 2. Tech stack
if claude_has_section "tech.stack"; then
  check 2 "Tech stack" "CLAUDE.md" P0 "[OK]"
else
  check 2 "Tech stack" "CLAUDE.md" P0 "[MISSING]"
fi

# 3. Domain model
if claude_has_section "(domain|data.hierarchy|model)" || has_file "$ROOT/docs/DOMAIN.md"; then
  check 3 "Domain model" "CLAUDE.md or docs/DOMAIN.md" P1 "[OK]"
else
  check 3 "Domain model" "CLAUDE.md or docs/DOMAIN.md" P1 "[MISSING]"
fi

# 4. Architecture diagram
if has_file "$ROOT/docs/ARCHITECTURE.md"; then
  if is_stale "$ROOT/docs/ARCHITECTURE.md"; then
    check 4 "Architecture diagram" "docs/ARCHITECTURE.md" P1 "[STALE]"
  else
    check 4 "Architecture diagram" "docs/ARCHITECTURE.md" P1 "[OK]"
  fi
else
  check 4 "Architecture diagram" "docs/ARCHITECTURE.md" P1 "[MISSING]"
fi

# 5. Codebase map
if has_file "$ROOT/docs/CODEBASE_MAP.md"; then
  check 5 "Codebase map" "docs/CODEBASE_MAP.md" P0 "[OK]"
else
  check 5 "Codebase map" "docs/CODEBASE_MAP.md" P0 "[MISSING]"
fi

# 6. Per-folder codemap
HAS_CODEMAP=false
if find "$ROOT" -maxdepth 3 -name "codemap.md" 2>/dev/null | grep -q . 2>/dev/null; then
  HAS_CODEMAP=true
fi
if $HAS_CODEMAP; then
  check 6 "Per-folder codemap" "<folder>/codemap.md" P2 "[OK]"
else
  check 6 "Per-folder codemap" "<folder>/codemap.md" P2 "[MISSING]"
fi

# 7. ERD (only if DB schema present)
HAS_DB=false
if [ -f "$ROOT/db/schema.rb" ] || [ -f "$ROOT/prisma/schema.prisma" ]; then
  HAS_DB=true
elif [ -d "$ROOT/db/migrate" ]; then
  MIGRATE_COUNT=$(find "$ROOT/db/migrate" -name "*.rb" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$MIGRATE_COUNT" -gt 0 ]; then
    HAS_DB=true
  fi
fi

if $HAS_DB; then
  if has_file "$ROOT/docs/ERD.md"; then
    check 7 "Data model / ERD" "docs/ERD.md" P1 "[OK]"
  else
    check 7 "Data model / ERD" "docs/ERD.md" P1 "[MISSING]"
  fi
else
  check 7 "Data model / ERD" "(N/A — no DB)" P1 "[OK]"
fi

# 8. API contract (only if API present)
HAS_API=false
if [ -d "$ROOT/app/controllers/api" ] || [ -f "$ROOT/openapi.yaml" ]; then
  HAS_API=true
elif [ -f "$ROOT/config/routes.rb" ] && grep -q "Rails.application.routes" "$ROOT/config/routes.rb" 2>/dev/null; then
  HAS_API=true
fi

if $HAS_API; then
  if has_file "$ROOT/docs/API.md" || has_file "$ROOT/openapi.yaml"; then
    check 8 "API contract" "docs/API.md" P1 "[OK]"
  else
    check 8 "API contract" "docs/API.md" P1 "[MISSING]"
  fi
else
  check 8 "API contract" "(N/A)" P1 "[OK]"
fi

# 9. Conventions — match heading containing "convention" anywhere
if claude_has_section ".*convention"; then
  check 9 "Conventions" "CLAUDE.md" P1 "[OK]"
else
  check 9 "Conventions" "CLAUDE.md" P1 "[MISSING]"
fi

# 10. Commands cheatsheet — match any heading mentioning command/build/test
if claude_has_section ".*(command|build|test)"; then
  check 10 "Commands cheatsheet" "CLAUDE.md" P2 "[OK]"
else
  check 10 "Commands cheatsheet" "CLAUDE.md" P2 "[MISSING]"
fi

# 11. ADR folder
HAS_ADR=false
if [ -d "$ROOT/docs/adr" ]; then
  ADR_COUNT=$(find "$ROOT/docs/adr" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ADR_COUNT" -gt 0 ]; then
    HAS_ADR=true
  fi
fi

if $HAS_ADR; then
  check 11 "ADR folder" "docs/adr/" P2 "[OK]"
else
  check 11 "ADR folder" "docs/adr/" P2 "[MISSING]"
fi

# 12. Onboarding (README with setup section)
if has_file "$ROOT/README.md"; then
  if grep -qiE "^#+\s*(setup|install|getting.started)" "$ROOT/README.md" 2>/dev/null; then
    check 12 "Onboarding" "README.md" P1 "[OK]"
  else
    check 12 "Onboarding" "README.md" P1 "[MISSING]"
  fi
else
  check 12 "Onboarding" "README.md" P1 "[MISSING]"
fi

# 13. SessionStart hook
HAS_SESSION_HOOK=false
# Path A: dedicated hook script in standard location
if [ -f "$ROOT/.gemini/hooks/session-start.sh" ] && [ -x "$ROOT/.gemini/hooks/session-start.sh" ]; then
  HAS_SESSION_HOOK=true
fi
# Path B: SessionStart declared in settings (regardless of script location)
if [ "$HAS_SESSION_HOOK" = "false" ]; then
  for SETTINGS in "$ROOT/.gemini/settings.json" "$ROOT/.gemini/settings.local.json"; do
    if [ -f "$SETTINGS" ] && grep -q "\"SessionStart\"" "$SETTINGS" 2>/dev/null; then
      HAS_SESSION_HOOK=true
      break
    fi
  done
fi
if $HAS_SESSION_HOOK; then
  check 13 "SessionStart hook" ".gemini/hooks/session-start.sh" P1 "[OK]"
else
  check 13 "SessionStart hook" ".gemini/hooks/session-start.sh" P1 "[MISSING]"
fi

# 14. Agent memory file (MEMORY.md)
HAS_MEMORY=false
MEMORY_NOTE=""
# Primary: project-scoped (preferred, git-trackable, reproducible)
if has_file "$ROOT/.gemini/MEMORY.md"; then
  HAS_MEMORY=true
elif has_file "$ROOT/.gemini/memory/MEMORY.md"; then
  HAS_MEMORY=true
else
  # Fallback: per-user (machine-local; not reproducible across team/CI)
  ENCODED=$(echo "$ROOT" | sed 's|^/||; s|/|-|g')
  if has_file "$HOME/.gemini/projects/${ENCODED}/memory/MEMORY.md"; then
    HAS_MEMORY=true
    MEMORY_NOTE=" (machine-local)"
  fi
fi
if $HAS_MEMORY; then
  check 14 "Agent memory${MEMORY_NOTE}" ".gemini/MEMORY.md (preferred)" P1 "[OK]"
else
  check 14 "Agent memory" ".gemini/MEMORY.md (preferred)" P1 "[MISSING]"
fi

# 15. Symbol/call graph index
HAS_SYMBOL_GRAPH=false
if [ -d "$ROOT/.gitnexus" ] || [ -f "$ROOT/tags" ] || [ -f "$ROOT/.ctags" ] || [ -f "$ROOT/TAGS" ]; then
  HAS_SYMBOL_GRAPH=true
fi
if $HAS_SYMBOL_GRAPH; then
  check 15 "Symbol/call graph" ".gitnexus/ or tags" P1 "[OK]"
else
  check 15 "Symbol/call graph" ".gitnexus/ or tags" P1 "[MISSING]"
fi

# 16. Coverage gate
HAS_COVERAGE=false
if [ -f "$ROOT/Gemfile" ] && grep -qE "(simplecov|coverage)" "$ROOT/Gemfile" 2>/dev/null; then
  HAS_COVERAGE=true
elif [ -f "$ROOT/package.json" ] && grep -qE "(c8|jest.*coverage|nyc|vitest.*coverage)" "$ROOT/package.json" 2>/dev/null; then
  HAS_COVERAGE=true
elif [ -f "$ROOT/.coveragerc" ]; then
  HAS_COVERAGE=true
elif [ -f "$ROOT/pyproject.toml" ] && grep -q "coverage" "$ROOT/pyproject.toml" 2>/dev/null; then
  HAS_COVERAGE=true
fi
if $HAS_COVERAGE; then
  check 16 "Coverage gate" "Gemfile/package.json (coverage tool)" P1 "[OK]"
else
  check 16 "Coverage gate" "Gemfile/package.json (coverage tool)" P1 "[MISSING]"
fi

# 17. Pre-commit hook
HAS_PRECOMMIT=false
if [ -f "$ROOT/lefthook.yml" ] || [ -f "$ROOT/.lefthook.yml" ]; then
  HAS_PRECOMMIT=true
elif [ -d "$ROOT/.husky" ]; then
  HAS_PRECOMMIT=true
elif [ -f "$ROOT/.pre-commit-config.yaml" ]; then
  HAS_PRECOMMIT=true
elif [ -s "$ROOT/.git/hooks/pre-commit" ]; then
  HAS_PRECOMMIT=true
fi
if $HAS_PRECOMMIT; then
  check 17 "Pre-commit hook" "lefthook.yml / .husky / .pre-commit-config.yaml" P1 "[OK]"
else
  check 17 "Pre-commit hook" "lefthook.yml / .husky / .pre-commit-config.yaml" P1 "[MISSING]"
fi

# 18. Per-folder CLAUDE.md (sub-folder, not just root)
SUB_CLAUDE_COUNT=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SUB_CLAUDE_COUNT=$(git -C "$ROOT" ls-files '**/CLAUDE.md' 2>/dev/null | grep -v '^CLAUDE\.md$' | wc -l | tr -d ' ')
else
  # Fallback: filesystem scan with explicit excludes
  SUB_CLAUDE_COUNT=$(find "$ROOT" -maxdepth 4 -name "CLAUDE.md" \
    -not -path "$ROOT/CLAUDE.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" \
    -not -path "*/tmp/*" \
    -not -path "*/.bundle/*" \
    2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$SUB_CLAUDE_COUNT" -gt 0 ]; then
  check 18 "Per-folder CLAUDE.md" "<sub-folder>/CLAUDE.md" P2 "[OK]"
else
  check 18 "Per-folder CLAUDE.md" "<sub-folder>/CLAUDE.md" P2 "[MISSING]"
fi

# 19. Hooks declared in settings
HAS_HOOKS_CONFIG=false
if [ -f "$ROOT/.gemini/settings.json" ] && grep -q '"hooks"' "$ROOT/.gemini/settings.json" 2>/dev/null; then
  HAS_HOOKS_CONFIG=true
elif [ -f "$ROOT/.gemini/settings.local.json" ] && grep -q '"hooks"' "$ROOT/.gemini/settings.local.json" 2>/dev/null; then
  HAS_HOOKS_CONFIG=true
fi
if $HAS_HOOKS_CONFIG; then
  check 19 "Hooks declared" ".gemini/settings.json (hooks)" P2 "[OK]"
else
  check 19 "Hooks declared" ".gemini/settings.json (hooks)" P2 "[MISSING]"
fi

# 20. CI gate
HAS_CI=false
if [ -d "$ROOT/.github/workflows" ]; then
  CI_COUNT=$(find "$ROOT/.github/workflows" \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CI_COUNT" -gt 0 ]; then
    HAS_CI=true
  fi
fi
if [ "$HAS_CI" = "false" ] && [ -f "$ROOT/.gitlab-ci.yml" ]; then
  HAS_CI=true
fi
if [ "$HAS_CI" = "false" ] && [ -f "$ROOT/.circleci/config.yml" ]; then
  HAS_CI=true
fi
if $HAS_CI; then
  check 20 "CI gate" ".github/workflows/*.yml" P2 "[OK]"
else
  check 20 "CI gate" ".github/workflows/*.yml" P2 "[MISSING]"
fi

# 21. STAR enforcement
HAS_STAR=false
if [ -f "$ROOT/CLAUDE.md" ]; then
  if grep -qE 'STAR PROTOCOL|Tier Routing' "$ROOT/CLAUDE.md" 2>/dev/null; then
    HAS_STAR=true
  fi
fi
if [ "$HAS_STAR" = "false" ] && [ -f "$HOME/.gemini/CLAUDE.md" ]; then
  if grep -qE 'STAR PROTOCOL|Tier Routing' "$HOME/.gemini/CLAUDE.md" 2>/dev/null; then
    HAS_STAR=true
  fi
fi
if $HAS_STAR; then
  check 21 "STAR enforcement" "CLAUDE.md" P1 "[OK]"
else
  check 21 "STAR enforcement" "CLAUDE.md" P1 "[MISSING]"
fi

# 22. Orchestrator binding
HAS_ORCHESTRATOR=false
if [ -f "$ROOT/CLAUDE.md" ]; then
  if grep -qiE 'orchestrator.{0,60}(never.{0,30}(edit|push|write|code))' "$ROOT/CLAUDE.md" 2>/dev/null; then
    HAS_ORCHESTRATOR=true
  fi
fi
if [ "$HAS_ORCHESTRATOR" = "false" ] && [ -f "$HOME/.gemini/CLAUDE.md" ]; then
  if grep -qiE 'orchestrator.{0,60}(never.{0,30}(edit|push|write|code))' "$HOME/.gemini/CLAUDE.md" 2>/dev/null; then
    HAS_ORCHESTRATOR=true
  fi
fi
if $HAS_ORCHESTRATOR; then
  check 22 "Orchestrator binding" "CLAUDE.md" P1 "[OK]"
else
  check 22 "Orchestrator binding" "CLAUDE.md" P1 "[MISSING]"
fi

# 23. Companion plugins active
HAS_PLUGINS=false
HAS_SUPERPOWERS=0
HAS_CAVEMAN=0
if [ -f "$HOME/.gemini/settings.json" ]; then
  grep -q '"superpowers@claude-plugins-official"' "$HOME/.gemini/settings.json" 2>/dev/null && HAS_SUPERPOWERS=1
  grep -q '"caveman@caveman"' "$HOME/.gemini/settings.json" 2>/dev/null && HAS_CAVEMAN=1
fi
[ "$HAS_SUPERPOWERS" = "1" ] && [ "$HAS_CAVEMAN" = "1" ] && HAS_PLUGINS=true
if $HAS_PLUGINS; then
  check 23 "Companion plugins" "~/.gemini/settings.json" P2 "[OK]"
else
  check 23 "Companion plugins" "~/.gemini/settings.json" P2 "[MISSING]"
fi

# 24. Pre-commit gates declared
HAS_GATES=false
# Check project .gemini/settings.json
if [ -f "$ROOT/.gemini/settings.json" ]; then
  if grep -qE 'bash-guard|block-wrong-plan-dir' "$ROOT/.gemini/settings.json" 2>/dev/null; then
    HAS_GATES=true
  fi
fi
# Check lean-flow plugin hooks.json (vendored) — only when plugin is explicitly set
if [ "$HAS_GATES" = "false" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  PLUGIN_HOOKS="$CLAUDE_PLUGIN_ROOT/hooks/hooks.json"
  if [ -f "$PLUGIN_HOOKS" ]; then
    if grep -qE 'bash-guard|block-wrong-plan-dir' "$PLUGIN_HOOKS" 2>/dev/null; then
      HAS_GATES=true
    fi
  fi
fi
if $HAS_GATES; then
  check 24 "Pre-commit gates" ".gemini/settings.json or hooks.json" P1 "[OK]"
else
  check 24 "Pre-commit gates" ".gemini/settings.json or hooks.json" P1 "[MISSING]"
fi

# 25. Pattern memory usage
HAS_PATTERN_MEM=false
if [ -f "$ROOT/CLAUDE.md" ]; then
  if grep -qE 'pattern_search|pattern_store' "$ROOT/CLAUDE.md" 2>/dev/null; then
    HAS_PATTERN_MEM=true
  fi
fi
if [ "$HAS_PATTERN_MEM" = "false" ] && [ -f "$HOME/.gemini/CLAUDE.md" ]; then
  if grep -qE 'pattern_search|pattern_store' "$HOME/.gemini/CLAUDE.md" 2>/dev/null; then
    HAS_PATTERN_MEM=true
  fi
fi
if $HAS_PATTERN_MEM; then
  check 25 "Pattern memory" "CLAUDE.md" P2 "[OK]"
else
  check 25 "Pattern memory" "CLAUDE.md" P2 "[MISSING]"
fi

# 26. RTK CLI installed (advisory, no score impact)
if command -v rtk >/dev/null 2>&1; then
  advisory 26 "RTK CLI installed" "\$PATH" P3 "[OK]"
else
  advisory 26 "RTK CLI installed" "\$PATH" P3 "[ADVISORY]"
fi

# 27. omni CLI installed (advisory, no score impact)
if command -v omni >/dev/null 2>&1; then
  advisory 27 "omni CLI installed" "\$PATH" P3 "[OK]"
else
  advisory 27 "omni CLI installed" "\$PATH" P3 "[ADVISORY]"
fi

# Output
PERCENT=$(( PRESENT * 100 / TOTAL ))

if [ "$MODE" = "score-only" ]; then
  echo "$PRESENT"
  exit 0
fi

if [ "$MODE" = "missing-only" ]; then
  # Advisory rows EXCLUDED from --missing-only (they are informational, not actionable)
  printf '%s\n' "${RESULTS[@]}" | awk -F'|' '$5=="[MISSING]" || $5=="[STALE]" { print $1 "|" $2 "|" $3 "|" $4 }'
  exit 0
fi

echo "# Project Doctor Report"
echo ""
echo "| # | Item | File | Severity | Status |"
echo "|---|------|------|----------|--------|"
for row in "${RESULTS[@]}"; do
  IFS='|' read -r n l f s st <<< "$row"
  printf "| %-2s | %s | %s | %s | %s |\n" "$n" "$l" "$f" "$s" "$st"
done
# Append advisory rows (no score impact, informational only)
for row in "${ADVISORY[@]}"; do
  IFS='|' read -r n l f s st <<< "$row"
  printf "| %-2s | %s | %s | %s | %s |\n" "$n" "$l" "$f" "$s" "$st"
done
echo ""
echo "**Score: $PRESENT/$TOTAL ($PERCENT%)**"

P0_MISSING=$(printf '%s\n' "${RESULTS[@]}" | awk -F'|' '$4=="P0" && $5=="[MISSING]"' | wc -l | tr -d ' ')
echo ""
echo "P0 missing: $P0_MISSING"
echo ""
echo "_Legend: [OK] = check passes; [MISSING] = scored item to fix; [ADVISORY] = informational only, no score impact (rows >25)._"
