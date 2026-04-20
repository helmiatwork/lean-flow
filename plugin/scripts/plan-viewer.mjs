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

// Build JSON data for client-side rendering
const plansData = JSON.stringify(Object.entries(plansByProject).map(([project, projectPlans]) => ({
  project,
  plans: projectPlans.map(p => ({
    name: p.name,
    file: p.file,
    hasPlanPlus: p.hasPlanPlusDir,
    mtime: (() => { try { return fs.statSync(path.join(p.scanDir, p.file)).mtimeMs; } catch { return 0; } })(),
    steps: p.steps.map(s => ({
      done: s.done,
      text: s.text,
      file: s.file ? path.basename(s.file) : null,
      heading: s.detail?.heading || null,
      paragraph: s.detail?.paragraph || null,
    })),
  })),
})));

const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>lean-flow Plans</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1117; color: #c9d1d9; display: flex; height: 100vh; overflow: hidden; }

    /* Sidebar */
    .sidebar { width: 260px; background: #161b22; border-right: 1px solid #30363d; overflow-y: auto; padding: 16px 0; flex-shrink: 0; }
    .sidebar-header { padding: 0 16px 16px; border-bottom: 1px solid #21262d; margin-bottom: 8px; }
    .sidebar-header h1 { color: #58a6ff; font-size: 18px; margin-bottom: 4px; }
    .sidebar-header .stats { color: #8b949e; font-size: 12px; }
    .repo-group { margin-bottom: 4px; }
    .repo-header { display: flex; align-items: center; gap: 8px; padding: 8px 16px; cursor: pointer; color: #f0f6fc; font-size: 14px; font-weight: 600; }
    .repo-header:hover { background: #1c2128; }
    .repo-header .arrow { color: #484f58; font-size: 10px; transition: transform 0.2s; }
    .repo-header .arrow.open { transform: rotate(90deg); }
    .repo-badge { font-size: 10px; padding: 1px 6px; border-radius: 10px; font-weight: 600; }
    .plan-item { display: flex; align-items: center; gap: 8px; padding: 6px 16px 6px 32px; cursor: pointer; font-size: 13px; color: #c9d1d9; }
    .plan-item:hover { background: #1c2128; }
    .plan-item.active { background: #1c2128; border-left: 2px solid #58a6ff; }
    .plan-item .dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
    .plan-item .plan-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .plan-item .plan-pct { color: #8b949e; font-size: 11px; }

    /* Main */
    .main { flex: 1; overflow-y: auto; padding: 24px 32px; }
    .main-empty { display: flex; align-items: center; justify-content: center; height: 100%; color: #484f58; font-size: 16px; }
    .plan-title { color: #f0f6fc; font-size: 22px; font-weight: 600; margin-bottom: 4px; }
    .plan-meta { color: #8b949e; font-size: 12px; margin-bottom: 16px; font-family: 'SF Mono', monospace; }
    .progress-bar { background: #21262d; border-radius: 4px; height: 8px; margin-bottom: 20px; overflow: hidden; }
    .progress-fill { height: 100%; border-radius: 4px; transition: width 0.3s; }
    .section-label { color: #8b949e; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; margin: 20px 0 8px; }

    .step { display: flex; align-items: flex-start; padding: 10px 12px; border-radius: 6px; margin-bottom: 2px; }
    .step:hover { background: #161b22; }
    .step-icon { width: 20px; height: 20px; margin-right: 12px; margin-top: 1px; flex-shrink: 0; text-align: center; font-size: 14px; }
    .step-done .step-text { color: #8b949e; text-decoration: line-through; }
    .step-text { font-size: 14px; line-height: 1.5; }
    .step-file { color: #484f58; font-size: 11px; font-family: monospace; margin-left: 8px; }
    .step-detail { margin-top: 6px; padding: 8px 12px; background: #0d1117; border-radius: 4px; border: 1px solid #21262d; }
    .step-detail summary { cursor: pointer; color: #58a6ff; font-size: 12px; }
    .step-detail-content { color: #8b949e; font-size: 12px; margin-top: 6px; line-height: 1.5; }
    .timestamp { color: #484f58; font-size: 11px; margin-top: 32px; text-align: right; }
  </style>
</head>
<body>
  <div class="sidebar">
    <div class="sidebar-header">
      <h1>lean-flow</h1>
      <div class="stats" id="global-stats"></div>
    </div>
    <div id="repo-list"></div>
  </div>
  <div class="main" id="main">
    <div class="main-empty">Select a plan from the sidebar</div>
  </div>

  <script>
    const data = ${plansData};
    let activePlan = null;

    function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    // Compute stats
    let totalSteps = 0, totalDone = 0, totalPlans = 0;
    data.forEach(g => g.plans.forEach(p => {
      totalPlans++;
      p.doneCount = p.steps.filter(s => s.done).length;
      p.totalCount = p.steps.length;
      p.pct = p.totalCount > 0 ? Math.round((p.doneCount / p.totalCount) * 100) : 0;
      p.isComplete = p.doneCount === p.totalCount && p.totalCount > 0;
      totalSteps += p.totalCount;
      totalDone += p.doneCount;
    }));

    // Sort plans: incomplete first (by pct asc), then complete (by mtime desc)
    data.forEach(g => {
      g.plans.sort((a, b) => {
        if (a.isComplete !== b.isComplete) return a.isComplete ? 1 : -1;
        if (!a.isComplete && !b.isComplete) return a.pct - b.pct;
        return b.mtime - a.mtime;
      });
      g.doneCount = g.plans.reduce((a, p) => a + p.doneCount, 0);
      g.totalCount = g.plans.reduce((a, p) => a + p.totalCount, 0);
    });

    // Sort repos: those with incomplete plans first
    data.sort((a, b) => {
      const aInc = a.plans.some(p => !p.isComplete);
      const bInc = b.plans.some(p => !p.isComplete);
      if (aInc !== bInc) return aInc ? -1 : 1;
      return a.project.localeCompare(b.project);
    });

    const overallPct = totalSteps > 0 ? Math.round((totalDone / totalSteps) * 100) : 0;
    document.getElementById('global-stats').textContent = totalPlans + ' plans · ' + totalDone + '/' + totalSteps + ' steps · ' + overallPct + '%';

    // Render sidebar
    const repoList = document.getElementById('repo-list');
    data.forEach((group, gi) => {
      const div = document.createElement('div');
      div.className = 'repo-group';
      const hasIncomplete = group.plans.some(p => !p.isComplete);

      div.innerHTML = '<div class="repo-header" data-gi="' + gi + '">'
        + '<span class="arrow open">▶</span>'
        + '📁 ' + esc(group.project)
        + ' <span class="repo-badge" style="background:' + (hasIncomplete ? '#30363d' : '#238636') + ';color:' + (hasIncomplete ? '#8b949e' : '#fff') + '">' + group.doneCount + '/' + group.totalCount + '</span>'
        + '</div>';

      const VISIBLE_LIMIT = 20;
      const plansList = document.createElement('div');
      plansList.className = 'plans-list';

      group.plans.forEach((plan, pi) => {
        const dotColor = plan.isComplete ? '#238636' : (plan.pct > 0 ? '#d29922' : '#484f58');
        const item = document.createElement('div');
        item.className = 'plan-item';
        item.dataset.gi = gi;
        item.dataset.pi = pi;
        if (pi >= VISIBLE_LIMIT) item.style.display = 'none';
        item.dataset.hidden = pi >= VISIBLE_LIMIT ? '1' : '0';
        item.innerHTML = '<span class="dot" style="background:' + dotColor + '"></span>'
          + '<span class="plan-label">' + esc(plan.name) + '</span>'
          + '<span class="plan-pct">' + plan.pct + '%</span>';
        item.onclick = () => selectPlan(gi, pi, item);
        plansList.appendChild(item);
      });

      if (group.plans.length > VISIBLE_LIMIT) {
        const more = document.createElement('div');
        more.className = 'plan-item';
        more.style.color = '#58a6ff';
        more.style.justifyContent = 'center';
        more.innerHTML = 'Show ' + (group.plans.length - VISIBLE_LIMIT) + ' more...';
        more.onclick = () => {
          plansList.querySelectorAll('[data-hidden="1"]').forEach(el => {
            el.style.display = '';
            el.dataset.hidden = '0';
          });
          more.remove();
        };
        plansList.appendChild(more);
      }

      div.appendChild(plansList);
      div.querySelector('.repo-header').onclick = () => {
        const arrow = div.querySelector('.arrow');
        const list = div.querySelector('.plans-list');
        const open = arrow.classList.toggle('open');
        list.style.display = open ? '' : 'none';
      };
      repoList.appendChild(div);
    });

    function selectPlan(gi, pi, el) {
      document.querySelectorAll('.plan-item.active').forEach(e => e.classList.remove('active'));
      el.classList.add('active');
      const plan = data[gi].plans[pi];
      renderPlan(plan, data[gi].project);
    }

    function renderPlan(plan, project) {
      const main = document.getElementById('main');
      const barColor = plan.isComplete ? '#238636' : '#d29922';
      const date = plan.mtime ? new Date(plan.mtime).toLocaleString() : 'unknown';

      const pendingSteps = plan.steps.filter(s => !s.done);
      const doneSteps = plan.steps.filter(s => s.done);

      let html = '<div class="plan-title">' + esc(plan.name) + '</div>'
        + '<div class="plan-meta">' + esc(project) + ' · ' + esc(plan.file) + (plan.hasPlanPlus ? ' · <span style="color:#58a6ff">plan-plus</span>' : '') + ' · ' + esc(date) + '</div>'
        + '<div class="progress-bar"><div class="progress-fill" style="width:' + plan.pct + '%;background:' + barColor + '"></div></div>';

      if (pendingSteps.length > 0) {
        html += '<div class="section-label">Pending (' + pendingSteps.length + ')</div>';
        pendingSteps.forEach(s => { html += renderStep(s, false); });
      }

      if (doneSteps.length > 0) {
        html += '<div class="section-label">Completed (' + doneSteps.length + ')</div>';
        doneSteps.forEach(s => { html += renderStep(s, true); });
      }

      if (plan.steps.length === 0) {
        html += '<div style="color:#484f58;padding:24px 0;text-align:center;">No steps in this plan</div>';
      }

      html += '<div class="timestamp">Last modified: ' + esc(date) + '</div>';
      main.innerHTML = html;
    }

    function renderStep(s, done) {
      const icon = done ? '<span style="color:#3fb950">✓</span>' : '<span style="color:#d29922">○</span>';
      const cls = done ? ' step-done' : '';
      const fileLabel = s.file ? '<span class="step-file">' + esc(s.file) + '</span>' : '';

      let detail = '';
      if (s.heading || s.paragraph) {
        detail = '<details class="step-detail"><summary>Details</summary><div class="step-detail-content">'
          + (s.heading ? '<strong>' + esc(s.heading) + '</strong>' : '')
          + (s.paragraph ? '<div style="margin-top:4px">' + esc(s.paragraph) + '</div>' : '')
          + '</div></details>';
      }

      return '<div class="step' + cls + '">'
        + '<div class="step-icon">' + icon + '</div>'
        + '<div style="flex:1">'
        + '<div class="step-text">' + esc(s.text) + fileLabel + '</div>'
        + detail
        + '</div></div>';
    }

    // Auto-select first incomplete plan
    const firstIncomplete = document.querySelector('.plan-item');
    if (firstIncomplete) firstIncomplete.click();
  </script>
</body>
</html>`;


fs.writeFileSync(outputPath, html, 'utf8');
console.log(`Plan viewer written to ${outputPath}`);
