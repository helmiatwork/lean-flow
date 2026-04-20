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

# --- Detect node binary across all common install methods ---
detect_node_bin() {
  # 1. Already in PATH
  local found
  found=$(command -v node 2>/dev/null)
  [ -n "$found" ] && echo "$found" && return

  # 2. nvm
  if [ -d "$HOME/.nvm/versions/node" ]; then
    for v in $(ls -r "$HOME/.nvm/versions/node/" 2>/dev/null); do
      p="$HOME/.nvm/versions/node/$v/bin/node"
      [ -x "$p" ] && echo "$p" && return
    done
  fi

  # 3. nodenv
  if [ -d "$HOME/.nodenv/versions" ]; then
    for v in $(ls -r "$HOME/.nodenv/versions/" 2>/dev/null); do
      p="$HOME/.nodenv/versions/$v/bin/node"
      [ -x "$p" ] && echo "$p" && return
    done
  fi

  # 4. Common direct locations
  for p in "/usr/local/bin/node" "/opt/homebrew/bin/node"; do
    [ -x "$p" ] && echo "$p" && return
  done

  echo ""
}

NODE_BIN=$(detect_node_bin)
NPM_BIN="$(dirname "$NODE_BIN")/npm"

if [ -z "$NODE_BIN" ]; then
  exit 0
fi

# Step 1: Copy MCP server files if not present or outdated
mkdir -p "$KNOWLEDGE_DIR"
if [ ! -f "${KNOWLEDGE_DIR}/${KNOWLEDGE_ENTRY}" ] || ! diff -q "${KNOWLEDGE_SRC}/index.mjs" "${KNOWLEDGE_DIR}/${KNOWLEDGE_ENTRY}" &>/dev/null; then
  cp "${KNOWLEDGE_SRC}/index.mjs" "$KNOWLEDGE_DIR/"
  cp "${KNOWLEDGE_SRC}/package.json" "$KNOWLEDGE_DIR/"
  rm -rf "${KNOWLEDGE_DIR}/node_modules"
fi

# Step 2: Install npm dependencies if node_modules missing
if [ ! -d "${KNOWLEDGE_DIR}/node_modules" ]; then
  if ! (cd "$KNOWLEDGE_DIR" && "$NPM_BIN" install --silent 2>/tmp/lean-flow-npm-install.log); then
    cat <<'EOF'
{"systemMessage": "[lean-flow] Knowledge MCP setup failed: npm install error. Check /tmp/lean-flow-npm-install.log for details."}
EOF
    exit 0
  fi
fi

# Step 3: Ensure DB directory exists
mkdir -p "$DB_DIR"

# Step 4: Register MCP server using full node path (not `node` — may not be in MCP daemon PATH)
if command -v claude &>/dev/null; then
  # Re-register if not present OR if it's registered with plain `node` (wrong PATH at runtime)
  current=$(claude mcp list 2>/dev/null | grep "^knowledge:")
  needs_update=0
  if [ -z "$current" ]; then
    needs_update=1
  elif echo "$current" | grep -q "^knowledge: node "; then
    # Registered with bare `node` — replace with full path
    claude mcp remove knowledge 2>/dev/null || true
    needs_update=1
  fi

  if [ "$needs_update" = "1" ]; then
    claude mcp add knowledge -- "$NODE_BIN" "${KNOWLEDGE_DIR}/${KNOWLEDGE_ENTRY}" 2>/dev/null
    cat <<EOF
{
  "systemMessage": "[lean-flow] Knowledge MCP server installed. 6 tools available: pattern_search, pattern_store, pattern_list, pattern_delete, pattern_stats, project_context."
}
EOF
  fi
fi

exit 0
