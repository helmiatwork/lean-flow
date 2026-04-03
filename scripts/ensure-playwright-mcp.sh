#!/usr/bin/env bash
# Ensure Playwright is installed locally and MCP server is registered.
# Runs on SessionStart — idempotent.

# Skip if claude CLI not available
if ! command -v claude &>/dev/null; then
  exit 0
fi

# Step 1: Install Playwright globally if not present
if ! command -v npx &>/dev/null; then
  exit 0
fi

# Check if @playwright/mcp is available (cached by npx)
if ! npx --yes @playwright/mcp@latest --help &>/dev/null 2>&1; then
  # Pre-cache the package so first MCP call doesn't hang
  npm install -g @playwright/mcp@latest 2>/dev/null
fi

# Step 2: Install Playwright browsers if not present
if ! npx playwright install --check &>/dev/null 2>&1; then
  # Install chromium only (smaller than all browsers)
  npx playwright install chromium 2>/dev/null
fi

# Step 3: Register MCP server if not already registered
if claude mcp list 2>/dev/null | grep -q "^playwright:"; then
  exit 0
fi

claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] Playwright installed and MCP server registered. Chromium browser available for E2E testing."
}
EOF

exit 0
