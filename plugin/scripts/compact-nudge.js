#!/usr/bin/env node
// Compact Nudge — PostToolUse hook
// Reminds Claude (and the user) to run /compact once context usage crosses 30%.
// Reads metrics from the statusline bridge file at /tmp/claude-ctx-{session_id}.json.
// Opt-out: LEAN_FLOW_COMPACT_NUDGE_DISABLED=true

const fs = require('fs');
const os = require('os');
const path = require('path');

const USED_THRESHOLD = 30;     // fire when used_pct >= 30%
const STALE_SECONDS = 60;
const DEBOUNCE_CALLS = 10;     // min tool uses between nudges

if (process.env.LEAN_FLOW_COMPACT_NUDGE_DISABLED === 'true') {
  process.exit(0);
}

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 10000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const sessionId = data.session_id;
    if (!sessionId || /[/\\]|\.\./.test(sessionId)) process.exit(0);

    const tmpDir = os.tmpdir();
    const metricsPath = path.join(tmpDir, `claude-ctx-${sessionId}.json`);
    if (!fs.existsSync(metricsPath)) process.exit(0);

    const metrics = JSON.parse(fs.readFileSync(metricsPath, 'utf8'));
    const now = Math.floor(Date.now() / 1000);
    if (metrics.timestamp && (now - metrics.timestamp) > STALE_SECONDS) process.exit(0);

    const usedPct = Number(metrics.used_pct) || 0;
    if (usedPct < USED_THRESHOLD) process.exit(0);

    const nudgePath = path.join(tmpDir, `claude-compact-nudge-${sessionId}.json`);
    let nudgeData = { callsSinceNudge: 0 };
    if (fs.existsSync(nudgePath)) {
      try {
        nudgeData = JSON.parse(fs.readFileSync(nudgePath, 'utf8'));
      } catch {}
    }
    nudgeData.callsSinceNudge = (nudgeData.callsSinceNudge || 0) + 1;

    if (nudgeData.callsSinceNudge < DEBOUNCE_CALLS) {
      fs.writeFileSync(nudgePath, JSON.stringify(nudgeData));
      process.exit(0);
    }
    nudgeData.callsSinceNudge = 0;
    fs.writeFileSync(nudgePath, JSON.stringify(nudgeData));

    // Build the message
    let message =
      `CONTEXT NUDGE: Usage at ${usedPct}%. Recommend running /compact at the next ` +
      `natural stopping point to keep responses sharp and reduce per-turn token cost. ` +
      `Inform the user; do not run /compact autonomously.`;

    const output = {
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: message
      }
    };
    process.stdout.write(JSON.stringify(output));
    process.exit(0);
  } catch {
    process.exit(0);
  }
});
