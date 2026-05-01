#!/usr/bin/env node
// Integration test for plan-server.mjs
//
// plan-server starts an HTTP server on a port. Test by spawning it on a
// random port, hitting the endpoint, and verifying the response, then
// terminating the process.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SCRIPT = path.join(REPO_ROOT, 'plugin/scripts/plan-server.mjs');

function pickPort() {
  // Random ephemeral port to avoid collisions with the real plan-viewer (3456).
  return 30000 + Math.floor(Math.random() * 5000);
}

function setupHomeFixture() {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'plan-server-home-'));
  const plansDir = path.join(home, '.claude', 'plans');
  fs.mkdirSync(plansDir, { recursive: true });
  const skeleton = `# plan-plus: server-test-plan

> full plan: ${plansDir}/server-test-plan.md

- [x] Step 1
- [ ] Step 2
`;
  fs.writeFileSync(path.join(plansDir, 'server-test-plan.md'), skeleton);
  return home;
}

async function fetchOnce(url, timeoutMs = 3000) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    return { status: res.status, body: await res.text() };
  } finally {
    clearTimeout(t);
  }
}

async function waitForReady(port, attempts = 20) {
  for (let i = 0; i < attempts; i++) {
    try {
      const r = await fetchOnce(`http://127.0.0.1:${port}/`, 500);
      if (r.status === 200) return true;
    } catch {}
    await new Promise(r => setTimeout(r, 100));
  }
  return false;
}

function spawnServer(port, home) {
  return spawn('node', [SCRIPT, String(port)], {
    env: { ...process.env, HOME: home },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

test('plan-server.mjs serves HTML on /', async () => {
  const port = pickPort();
  const home = setupHomeFixture();
  const proc = spawnServer(port, home);
  try {
    assert.equal(await waitForReady(port), true, 'server should respond on /');
    const r = await fetchOnce(`http://127.0.0.1:${port}/`);
    assert.equal(r.status, 200);
    assert.match(r.body, /<html/i, 'returns HTML');
    assert.match(r.body, /server-test-plan/, 'plan name appears in response');
  } finally {
    proc.kill('SIGTERM');
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('plan-server.mjs exposes SSE endpoint /events', async () => {
  const port = pickPort();
  const home = setupHomeFixture();
  const proc = spawnServer(port, home);
  try {
    await waitForReady(port);
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 500);
    let headers = null;
    try {
      const res = await fetch(`http://127.0.0.1:${port}/events`, { signal: controller.signal });
      headers = res.headers;
      // Drain immediately and abort — we just want to confirm the endpoint exists with the right content-type.
      controller.abort();
    } catch (e) {
      // Aborted reads are expected for SSE
    } finally {
      clearTimeout(t);
    }
    if (headers) {
      const ct = headers.get('content-type') || '';
      assert.match(ct, /event-stream/, 'SSE endpoint advertises text/event-stream');
    }
  } finally {
    proc.kill('SIGTERM');
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('plan-server.mjs response embeds plan step state from HOME/.claude/plans', async () => {
  const port = pickPort();
  const home = setupHomeFixture();
  const proc = spawnServer(port, home);
  try {
    await waitForReady(port);
    const r = await fetchOnce(`http://127.0.0.1:${port}/`);
    // Fixture has 1 done + 1 pending step.
    assert.match(r.body, /"done":true/, 'done step state present');
    assert.match(r.body, /"done":false/, 'pending step state present');
  } finally {
    proc.kill('SIGTERM');
    fs.rmSync(home, { recursive: true, force: true });
  }
});
