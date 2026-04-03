#!/usr/bin/env bash
# Ensure the knowledge MCP server is installed and registered.
# Runs on SessionStart — idempotent (skips if already set up).

KNOWLEDGE_DIR="${HOME}/.claude/mcp-servers/knowledge"
KNOWLEDGE_SRC="${CLAUDE_PLUGIN_ROOT}/mcp-servers/knowledge"
KNOWLEDGE_ENTRY="index.mjs"
DB_DIR="${HOME}/.claude/knowledge"

# Skip if plugin root is not set
if [ -z "$CLAUDE_PLUGIN_ROOT" ]; then
  exit 0
fi

# Step 1: Copy MCP server files if not present
if [ ! -f "${KNOWLEDGE_DIR}/${KNOWLEDGE_ENTRY}" ]; then
  mkdir -p "$KNOWLEDGE_DIR"
  cp "${KNOWLEDGE_SRC}/index.mjs" "$KNOWLEDGE_DIR/"
  cp "${KNOWLEDGE_SRC}/package.json" "$KNOWLEDGE_DIR/"
fi

# Step 2: Install npm dependencies if node_modules missing
if [ ! -d "${KNOWLEDGE_DIR}/node_modules" ]; then
  (cd "$KNOWLEDGE_DIR" && npm install --silent 2>/dev/null)
fi

# Step 3: Ensure DB directory exists (DB auto-creates on first run)
mkdir -p "$DB_DIR"

# Step 4: Register MCP server if not already registered
# Check if 'knowledge' is in the claude MCP list
if command -v claude &>/dev/null; then
  if ! claude mcp list 2>/dev/null | grep -q "^knowledge:"; then
    claude mcp add knowledge -- node "${KNOWLEDGE_DIR}/${KNOWLEDGE_ENTRY}" 2>/dev/null

    # Notify the user
    cat <<EOF
{
  "systemMessage": "[lean-flow] Knowledge MCP server installed and registered. 3 tools available: pattern_search, pattern_store, project_context. Data stored at ~/.claude/knowledge/patterns.db"
}
EOF
    exit 0
  fi
fi

exit 0
