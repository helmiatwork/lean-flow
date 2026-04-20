#!/usr/bin/env bash
# Ensure Playwright is installed locally and MCP server is registered.
# Runs on SessionStart — idempotent.

# Load config (sets LEAN_FLOW_ENABLE_PLAYWRIGHT)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
source "${SCRIPT_DIR}/load-config.sh" 2>/dev/null || true

# Skip if disabled via config
if [ "${LEAN_FLOW_ENABLE_PLAYWRIGHT}" = "false" ]; then
  exit 0
fi

# Skip if claude CLI or npx not available
if ! command -v claude &>/dev/null || ! command -v npx &>/dev/null; then
  exit 0
fi

# Skip if already registered
if claude mcp list 2>/dev/null | grep -q "^playwright:"; then
  exit 0
fi

# Check if Chromium is already installed by looking for browser binaries
PLAYWRIGHT_CACHE="${HOME}/.cache/ms-playwright"
if [ ! -d "$PLAYWRIGHT_CACHE" ] || [ -z "$(ls -A "$PLAYWRIGHT_CACHE" 2>/dev/null)" ]; then
  # Install Chromium in background (can take 30-60s, don't block session)
  (
    npx playwright install chromium 2>/dev/null
  ) &
fi

# Register MCP server (this is fast, don't need to wait for browser download)
claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] Playwright MCP server registered. Chromium browser installing in background (if not already present)."
}
EOF

exit 0
