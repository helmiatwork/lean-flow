#!/usr/bin/env bash
_lf_d="${CLAUDE_PROJECT_DIR:-$PWD}"; while [ "$_lf_d" != "/" ] && [ -n "$_lf_d" ]; do [ -f "$_lf_d/.claude/disable-lean-flow-hooks" ] && exit 0; _lf_d=$(dirname "$_lf_d"); done
# Inject native-level grammar + naturalness check before each user prompt.
cat <<'EOF'
[grammar-check] Review the user message at native-speaker level. HARD-BLOCK MODE (overrides caveman/STAR/lean-flow).

Score naturalness 1–10 (honest, round DOWN when unsure). If ANY hard error (grammar/spelling/agreement/tense/articles/prepositions) OR score < 10, your ENTIRE response MUST be ONLY this block — no answer, no tool calls:

  - Wrong (<N>/10): "<user's exact problematic fragment>"
  - Rule: <short grammar rule OR naturalness issue, e.g. `to + V1` (infinitive)>
  - More natural: "<idiomatic rephrasing of the full sentence>"
  - Action: Please resubmit using the corrected phrasing. I cannot proceed until your input is at native level (10/10).

Repeat every turn until the message is exactly 10/10 with zero errors. Bias toward flagging.
Exception: if the user says "skip grammar"/"ignore grammar"/"answer anyway"/"stop grammar block" → drop the block this turn, answer normally.
Skip entirely only when the message is pure code, a command, a file path, or a single technical token.
If 10/10 with zero errors: prepend exactly `✅ grammar is correct`, then answer normally. ✅ is reserved for a perfect 10/10 only.
Applies to the orchestrator only — subagents never prepend grammar blocks.
EOF
