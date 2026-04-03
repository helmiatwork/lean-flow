#!/usr/bin/env node
/**
 * plan-viewer.mjs
 * Generates a single-page HTML viewer from plan-plus skeleton files.
 *
 * Usage: node plan-viewer.mjs <plansDir> <outputPath>
 */

import fs from 'fs';
import path from 'path';

const [,, plansDir, outputPath] = process.argv;

if (!plansDir || !outputPath) {
  console.error('Usage: plan-viewer.mjs <plansDir> <outputPath>');
  process.exit(1);
}

// ── Helpers ────────────────────────────────────────────────────────────────

function readFileSafe(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

function listDirSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch {
    return [];
  }
}

/** Extract plan name from skeleton markdown (# plan-plus: <name>) */
function extractPlanName(markdown) {
  const match = markdown.match(/^#\s+plan-plus:\s*(.+)$/m);
  return match ? match[1].trim() : null;
}

/** Extract project/repo name from skeleton markdown.
 *  Looks for `full plan: /path/to/repo/.claude/plans/...`
 *  and extracts the repo directory name.
 */
function extractProjectName(markdown) {
  const match = markdown.match(/full plan:\s*(.+)/m);
  if (!match) return 'unknown';
  // Extract repo name from path like /Users/x/Documents/repo/grewme/.claude/plans/...
  const fullPath = match[1].trim();
  const parts = fullPath.split('/.claude/');
  if (parts.length >= 2) {
    return path.basename(parts[0]);
  }
  return 'unknown';
}

/** Extract steps from skeleton markdown.
 *  Handles multiple formats:
 *    - `N. [x] Description`  (numbered, plan-plus style)
 *    - `- [x] Description`   (dashed)
 *    - `* [x] Description`   (starred)
 *  File references can be:
 *    - Inline: `(path/to/file.md)` or `details: /abs/path`
 *    - Next line: `   Step: /path/to/file.md` or `   Step requires using agent: ... — details: /path`
 */
function extractSteps(markdown) {
  const steps = [];
  const lines = markdown.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Match: `N. [x] ...`, `- [x] ...`, `* [x] ...`
    const match = line.match(/^[\s]*(?:\d+\.|\-|\*)\s+\[([ xX])\]\s+(.+)$/);
    if (!match) continue;

    const done = match[1].toLowerCase() === 'x';
    let text = match[2].trim();

    // Extract file reference from current line or next line
    let file = null;

    // Pattern 1: inline `details: /path/to/file.md`
    const detailsMatch = text.match(/details:\s*(\S+\.md)/);
    if (detailsMatch) file = detailsMatch[1];

    // Pattern 2: inline `(path/to/file.md)`
    if (!file) {
      const parenMatch = text.match(/\(([^)]+\.md)\)/);
      if (parenMatch) file = parenMatch[1];
    }

    // Pattern 3: next line contains `Step:` or `details:`
    if (!file && i + 1 < lines.length) {
      const nextLine = lines[i + 1].trim();
      const nextMatch = nextLine.match(/(?:Step|details):\s*(\S+\.md)/i);
      if (nextMatch) file = nextMatch[1];
    }

    // Clean display text — remove file references and "Step requires using agent" noise
    text = text
      .replace(/\s*—?\s*details:\s*\S+/g, '')
      .replace(/\s*\([^)]+\.md\)\s*/g, '')
      .replace(/\s*Step requires using agent:.*$/i, '')
      .trim();

    steps.push({ done, text, file });
  }

  return steps;
}

/** Read a step file and return its first heading + first paragraph. */
function extractStepDetail(filePath) {
  const content = readFileSafe(filePath);
  if (!content) return null;

  const headingMatch = content.match(/^#+\s+(.+)$/m);
  const heading = headingMatch ? headingMatch[1].trim() : null;

  // First non-empty, non-heading paragraph
  const lines = content.split('\n');
  let paragraph = '';
  let inParagraph = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('#')) { inParagraph = false; continue; }
    if (trimmed === '') { if (inParagraph) break; continue; }
    inParagraph = true;
    paragraph += (paragraph ? ' ' : '') + trimmed;
    if (paragraph.length > 200) { paragraph = paragraph.slice(0, 200) + '…'; break; }
  }

  return { heading, paragraph: paragraph || null };
}

/** Escape HTML special characters. */
function esc(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Collect plans ──────────────────────────────────────────────────────────

/**
 * Scan directories for skeleton .md files and resolve plan-plus step dirs.
 * We look in:
 *   1. plansDir (~/.claude/plans)
 *   2. <cwd>/.claude/plans  (project-local)
 */
const scanDirs = [plansDir];
const cwdPlans = path.join(process.cwd(), '.claude', 'plans');
if (cwdPlans !== plansDir && fs.existsSync(cwdPlans)) {
  scanDirs.push(cwdPlans);
}

const plans = [];

for (const scanDir of scanDirs) {
  const files = listDirSafe(scanDir).filter(f => f.endsWith('.md'));
  for (const file of files) {
    const skeletonPath = path.join(scanDir, file);
    const skeleton = readFileSafe(skeletonPath);
    if (!skeleton) continue;

    // Derive plan name: prefer # plan-plus: header, else use filename
    const baseName = path.basename(file, '.md');
    const planName = extractPlanName(skeleton) || baseName;

    // Locate plan-plus directory: plan-plus--<baseName> next to skeleton
    const planPlusDir = path.join(scanDir, `plan-plus--${baseName}`);
    const hasPlanPlusDir = fs.existsSync(planPlusDir);

    const steps = extractSteps(skeleton);

    // Enrich steps with detail from plan-plus step files
    for (const step of steps) {
      if (!step.file) continue;
      // Try relative to planPlusDir first, then scanDir
      const candidates = [
        path.join(planPlusDir, step.file),
        path.join(scanDir, step.file),
        path.isAbsolute(step.file) ? step.file : null,
      ].filter(Boolean);

      for (const candidate of candidates) {
        const detail = extractStepDetail(candidate);
        if (detail) { step.detail = detail; break; }
      }
    }

    // Also scan planPlusDir for any .md step files not referenced by skeleton
    if (hasPlanPlusDir) {
      const stepFiles = listDirSafe(planPlusDir).filter(f => f.endsWith('.md'));
      for (const sf of stepFiles) {
        const already = steps.some(s => s.file && path.basename(s.file) === sf);
        if (!already) {
          const detail = extractStepDetail(path.join(planPlusDir, sf));
          steps.push({
            done: false,
            text: path.basename(sf, '.md').replace(/-/g, ' '),
            file: sf,
            detail: detail || undefined,
          });
        }
      }
    }

    const project = extractProjectName(skeleton);
    plans.push({ name: planName, project, file, scanDir, steps, hasPlanPlusDir });
  }
}

// ── Generate HTML ──────────────────────────────────────────────────────────

const totalPlans = plans.length;
const now = new Date().toLocaleString();

function renderStep(step, idx) {
  const doneClass = step.done ? ' step-done' : '';
  const icon = step.done
    ? '<span style="color:#3fb950;font-size:16px;">✓</span>'
    : '<span style="color:#484f58;font-size:16px;">○</span>';

  let detailHtml = '';
  if (step.detail) {
    const heading = step.detail.heading ? `<strong>${esc(step.detail.heading)}</strong>` : '';
    const para = step.detail.paragraph ? `<div style="margin-top:4px">${esc(step.detail.paragraph)}</div>` : '';
    if (heading || para) {
      detailHtml = `<details class="step-detail"><summary style="cursor:pointer;color:#58a6ff;font-size:12px;">Show details</summary><div style="margin-top:6px">${heading}${para}</div></details>`;
    }
  }

  const fileLabel = step.file
    ? `<span style="color:#484f58;font-size:11px;margin-left:8px;font-family:monospace;">${esc(path.basename(step.file))}</span>`
    : '';

  return `
      <div class="step${doneClass}">
        <div class="step-checkbox">${icon}</div>
        <div style="flex:1">
          <div class="step-text">${esc(step.text)}${fileLabel}</div>
          ${detailHtml}
        </div>
      </div>`;
}

function renderPlan(plan) {
  const total = plan.steps.length;
  const done = plan.steps.filter(s => s.done).length;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  const badge = done === total && total > 0
    ? '<span class="badge badge-done">Complete</span>'
    : `<span class="badge badge-pending">${done}/${total} steps</span>`;

  const stepsHtml = total > 0
    ? plan.steps.map((s, i) => renderStep(s, i)).join('')
    : '<div style="color:#484f58;padding:12px 0;font-size:13px;">No steps found in skeleton.</div>';

  const planPlusLabel = plan.hasPlanPlusDir
    ? '<span style="color:#58a6ff;font-size:11px;margin-left:8px;">plan-plus</span>'
    : '';

  return `
    <div class="plan-card">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:4px;">
        <div class="plan-name">${esc(plan.name)}${planPlusLabel}</div>
        ${badge}
      </div>
      <div class="plan-meta">${esc(plan.file)} &middot; ${esc(plan.scanDir)}</div>
      <div class="progress-bar">
        <div class="progress-fill" style="width:${pct}%"></div>
      </div>
      <div class="steps">
        ${stepsHtml}
      </div>
    </div>`;
}

// Group plans by project
const plansByProject = {};
for (const plan of plans) {
  if (!plansByProject[plan.project]) plansByProject[plan.project] = [];
  plansByProject[plan.project].push(plan);
}

const plansHtml = totalPlans > 0
  ? Object.entries(plansByProject).map(([project, projectPlans]) => {
      const projDone = projectPlans.reduce((a, p) => a + p.steps.filter(s => s.done).length, 0);
      const projTotal = projectPlans.reduce((a, p) => a + p.steps.length, 0);
      const projPct = projTotal > 0 ? Math.round((projDone / projTotal) * 100) : 0;
      return `
        <div style="margin-bottom:32px;">
          <div style="display:flex;align-items:center;gap:12px;margin-bottom:12px;">
            <h2 style="color:#f0f6fc;font-size:20px;font-weight:600;">📁 ${esc(project)}</h2>
            <span class="badge ${projDone === projTotal && projTotal > 0 ? 'badge-done' : 'badge-pending'}">${projDone}/${projTotal} steps</span>
          </div>
          ${projectPlans.map(renderPlan).join('')}
        </div>`;
    }).join('')
  : `<div class="empty">
      <div style="font-size:48px;margin-bottom:16px;">📋</div>
      <div style="font-size:18px;margin-bottom:8px;">No plans found</div>
      <div style="font-size:14px;">Plans are read from:<br>${scanDirs.map(d => `<code>${esc(d)}</code>`).join('<br>')}</div>
    </div>`;

const totalDone = plans.reduce((acc, p) => acc + p.steps.filter(s => s.done).length, 0);
const totalSteps = plans.reduce((acc, p) => acc + p.steps.length, 0);
const overallPct = totalSteps > 0 ? Math.round((totalDone / totalSteps) * 100) : 0;

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>lean-flow Plans</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1117; color: #c9d1d9; padding: 24px; }
    .container { max-width: 900px; margin: 0 auto; }
    h1 { color: #58a6ff; font-size: 28px; margin-bottom: 8px; }
    .subtitle { color: #8b949e; font-size: 14px; margin-bottom: 8px; }
    .overall-bar { background: #21262d; border-radius: 4px; height: 6px; margin-bottom: 32px; overflow: hidden; max-width: 300px; }
    .overall-fill { background: #58a6ff; height: 100%; border-radius: 4px; }
    .plan-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; margin-bottom: 16px; }
    .plan-name { color: #f0f6fc; font-size: 18px; font-weight: 600; }
    .plan-meta { color: #8b949e; font-size: 12px; margin-bottom: 12px; font-family: 'SF Mono', 'Fira Code', monospace; }
    .progress-bar { background: #21262d; border-radius: 4px; height: 6px; margin-bottom: 14px; overflow: hidden; }
    .progress-fill { background: #238636; height: 100%; border-radius: 4px; transition: width 0.3s; }
    .step { display: flex; align-items: flex-start; padding: 8px 0; border-bottom: 1px solid #21262d; }
    .step:last-child { border-bottom: none; }
    .step-checkbox { width: 24px; margin-right: 10px; margin-top: 1px; flex-shrink: 0; text-align: center; }
    .step-done .step-text { color: #8b949e; text-decoration: line-through; }
    .step-text { font-size: 14px; line-height: 1.5; }
    .step-detail { color: #8b949e; font-size: 12px; margin-top: 3px; line-height: 1.4; }
    .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; white-space: nowrap; }
    .badge-done { background: #238636; color: #fff; }
    .badge-pending { background: #30363d; color: #8b949e; }
    .empty { text-align: center; padding: 64px 24px; color: #8b949e; }
    .empty code { background: #161b22; padding: 2px 6px; border-radius: 4px; font-family: 'SF Mono', 'Fira Code', monospace; font-size: 12px; }
    .timestamp { color: #484f58; font-size: 12px; text-align: center; margin-top: 32px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>lean-flow Plans</h1>
    <div class="subtitle">${totalPlans} plan${totalPlans !== 1 ? 's' : ''} &middot; ${totalDone}/${totalSteps} steps complete &middot; ${overallPct}% overall</div>
    <div class="overall-bar"><div class="overall-fill" style="width:${overallPct}%"></div></div>
    ${plansHtml}
    <div class="timestamp">Generated ${esc(now)}</div>
  </div>
</body>
</html>`;

fs.writeFileSync(outputPath, html, 'utf8');
console.log(`Plan viewer written to ${outputPath}`);
