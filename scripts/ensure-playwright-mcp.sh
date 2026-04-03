#!/usr/bin/env bash
# Ensure Playwright is installed locally and MCP server is registered.
# Runs on SessionStart — idempotent.

# Skip if claude CLI not available
if ! command -v claude &>/dev/null; then
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
