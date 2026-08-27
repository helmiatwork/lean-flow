#!/usr/bin/env node
// Integration test for plan-viewer.mjs
//
// plan-viewer.mjs is a CLI: `node plan-viewer.mjs <plansDir> <outputPath>`.
// It scans a plans directory for skeleton .md files, parses them, and
// emits a single-page HTML viewer.
//
// This test creates a fixture plans directory, runs the script, and asserts
// the generated HTML contains the expected plan/step content.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const SCRIPT = path.join(REPO_ROOT, 'plugin/scripts/plan-viewer.mjs');

function setupFixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'plan-viewer-test-'));
  const skeleton = `# plan-plus: example-feature

> full plan: ${dir}/.gemini/plans/example-feature.md

- [ ] Step 1: scaffold the module
- [x] Step 2: write failing test
- [ ] Step 3: implement
`;
  fs.writeFileSync(path.join(dir, 'example-feature.md'), skeleton);
  return dir;
}

function runViewer(plansDir) {
  const outputPath = path.join(plansDir, 'viewer.html');
  execFileSync('node', [SCRIPT, plansDir, outputPath], { stdio: 'pipe' });
  return fs.readFileSync(outputPath, 'utf8');
}

test('plan-viewer.mjs produces HTML with plan content', () => {
  const dir = setupFixture();
  try {
    const html = runViewer(dir);
    assert.match(html, /<html/i, 'output is HTML');
    assert.match(html, /example-feature/, 'plan name appears in output');
    assert.match(html, /scaffold the module/, 'step text appears');
    assert.match(html, /write failing test/, 'completed step text appears');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('plan-viewer.mjs handles empty plans dir without crashing', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'plan-viewer-empty-'));
  try {
    const html = runViewer(dir);
    assert.match(html, /<html/i, 'still emits HTML even with no plans');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('plan-viewer.mjs encodes step done/pending state in HTML payload', () => {
  const dir = setupFixture();
  try {
    const html = runViewer(dir);
    // Pct is computed client-side; assert the data it would consume is present.
    assert.match(html, /"done":true/, 'at least one done step encoded');
    assert.match(html, /"done":false/, 'at least one pending step encoded');
    // Three steps in the fixture → three step text entries.
    const stepMatches = html.match(/Step \d:/g) || [];
    assert.equal(stepMatches.length >= 3, true, `expected ≥3 step refs, got ${stepMatches.length}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('plan-viewer.mjs exits with usage error when args missing', () => {
  let exitCode = 0;
  try {
    execFileSync('node', [SCRIPT], { stdio: 'pipe' });
  } catch (e) {
    exitCode = e.status;
  }
  assert.notEqual(exitCode, 0, 'script exits non-zero when args missing');
});
