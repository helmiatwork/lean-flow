#!/usr/bin/env bash
# Load lean-flow configuration.
# Source this file to get all LEAN_FLOW_* variables.
# Usage: source "$(dirname "$0")/load-config.sh"

# --- Defaults ---
LEAN_FLOW_PROTECTED_BRANCHES="main master staging"
LEAN_FLOW_FIXER_MODEL="sonnet"
LEAN_FLOW_ORACLE_MODEL="opus"
LEAN_FLOW_EXPLORER_MODEL="haiku"
LEAN_FLOW_DREAM_SESSIONS=5
LEAN_FLOW_DREAM_HOURS=24
LEAN_FLOW_ENABLE_PLAYWRIGHT=true
LEAN_FLOW_ENABLE_MONITOR=true
LEAN_FLOW_ENABLE_KNOWLEDGE=true
LEAN_FLOW_ENABLE_RTK=true
LEAN_FLOW_BRANCH_PREFIXES="feature fix improvement security test docs chore hotfix"

# --- User overrides ---
CONFIG_FILE="${HOME}/.claude/lean-flow.json"

if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
  _val() { jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null; }

  val=$(_val '.protectedBranches | if type == "array" then join(" ") else . end')
  [ -n "$val" ] && LEAN_FLOW_PROTECTED_BRANCHES="$val"

  val=$(_val '.models.fixer')
  [ -n "$val" ] && LEAN_FLOW_FIXER_MODEL="$val"

  val=$(_val '.models.oracle')
  [ -n "$val" ] && LEAN_FLOW_ORACLE_MODEL="$val"

  val=$(_val '.models.explorer')
  [ -n "$val" ] && LEAN_FLOW_EXPLORER_MODEL="$val"

  val=$(_val '.dream.sessions')
  [ -n "$val" ] && LEAN_FLOW_DREAM_SESSIONS="$val"

  val=$(_val '.dream.hours')
  [ -n "$val" ] && LEAN_FLOW_DREAM_HOURS="$val"

  val=$(_val '.enable.playwright')
  [ -n "$val" ] && LEAN_FLOW_ENABLE_PLAYWRIGHT="$val"

  val=$(_val '.enable.monitor')
  [ -n "$val" ] && LEAN_FLOW_ENABLE_MONITOR="$val"

  val=$(_val '.enable.knowledge')
  [ -n "$val" ] && LEAN_FLOW_ENABLE_KNOWLEDGE="$val"

  val=$(_val '.enable.rtk')
  [ -n "$val" ] && LEAN_FLOW_ENABLE_RTK="$val"

  val=$(_val '.branchPrefixes | if type == "array" then join(" ") else . end')
  [ -n "$val" ] && LEAN_FLOW_BRANCH_PREFIXES="$val"

  unset -f _val
fi

export LEAN_FLOW_PROTECTED_BRANCHES
export LEAN_FLOW_FIXER_MODEL
export LEAN_FLOW_ORACLE_MODEL
export LEAN_FLOW_EXPLORER_MODEL
export LEAN_FLOW_DREAM_SESSIONS
export LEAN_FLOW_DREAM_HOURS
export LEAN_FLOW_ENABLE_PLAYWRIGHT
export LEAN_FLOW_ENABLE_MONITOR
export LEAN_FLOW_ENABLE_KNOWLEDGE
export LEAN_FLOW_ENABLE_RTK
export LEAN_FLOW_BRANCH_PREFIXES
