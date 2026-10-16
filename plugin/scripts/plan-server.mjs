#!/usr/bin/env node
/**
 * plan-server.mjs — Live plan viewer with file watching
 *
 * Serves the plan viewer on localhost:3456 and auto-refreshes
 * when any plan file changes via Server-Sent Events (SSE).
 *
 * Usage: node plan-server.mjs [port]
 */

import http from 'http';
import fs from 'fs';
import path from 'path';

const PORT = parseInt(process.argv[2] || '3456', 10);
const PLANS_DIR = path.join(process.env.HOME, '.claude', 'plans');

// Track SSE clients for live reload
const clients = new Set();

// ── Plan parsing (same logic as plan-viewer.mjs) ──────────────────────────

function readSafe(p) { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } }
function listSafe(p) { try { return fs.readdirSync(p); } catch { return []; } }

function extractPlanName(md) {
  const m = md.match(/^#\s+plan-plus:\s*(.+)$/m);
  return m ? m[1].trim() : null;
}

function extractProjectName(md) {
  const m = md.match(/full plan:\s*(.+)/m);
  if (!m) return 'unknown';
  const parts = m[1].trim().split('/.claude/');
  return parts.length >= 2 ? path.basename(parts[0]) : 'unknown';
}

function extractSteps(md) {
  const steps = [];
  const lines = md.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(/^[\s]*(?:\d+\.|\-|\*)\s+\[([ xX])\]\s+(.+)$/);
    if (!match) continue;
    const done = match[1].toLowerCase() === 'x';
    let text = match[2].trim();
    let file = null;
    const dm = text.match(/details:\s*(\S+\.md)/);
    if (dm) file = dm[1];
    if (!file) { const pm = text.match(/\(([^)]+\.md)\)/); if (pm) file = pm[1]; }
    if (!file && i + 1 < lines.length) {
      const nm = lines[i + 1].trim().match(/(?:Step|details):\s*(\S+\.md)/i);
      if (nm) file = nm[1];
    }
    text = text.replace(/\s*—?\s*details:\s*\S+/g, '').replace(/\s*\([^)]+\.md\)\s*/g, '').replace(/\s*Step requires using agent:.*$/i, '').trim();
    steps.push({ done, text, file: file ? path.basename(file) : null });
  }
  return steps;
}

function loadPlans() {
  const scanDirs = [PLANS_DIR];
  const plans = [];

  for (const dir of scanDirs) {
    const files = listSafe(dir).filter(f => f.endsWith('.md'));
    for (const file of files) {
      const fp = path.join(dir, file);
      const md = readSafe(fp);
      if (!md) continue;
      const baseName = path.basename(file, '.md');
      let mtime = 0;
      try { mtime = fs.statSync(fp).mtimeMs; } catch {}
      plans.push({
        name: extractPlanName(md) || baseName,
        project: extractProjectName(md),
        file,
        mtime,
        hasPlanPlus: fs.existsSync(path.join(dir, `plan-plus--${baseName}`)),
        steps: extractSteps(md),
      });
    }
  }
  return plans;
}

// ── HTML template ─────────────────────────────────────────────────────────

function buildHTML() {
  const plans = loadPlans();
  const plansJSON = JSON.stringify(plans);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>lean-flow Plans</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0d1117; color: #c9d1d9; display: flex; height: 100vh; overflow: hidden; }
    .sidebar { width: 280px; background: #161b22; border-right: 1px solid #30363d; overflow-y: auto; padding: 16px 0; flex-shrink: 0; }
    .sidebar-header { padding: 0 16px 12px; border-bottom: 1px solid #21262d; margin-bottom: 8px; }
    .sidebar-header h1 { color: #58a6ff; font-size: 18px; margin-bottom: 2px; }
    .sidebar-header .stats { color: #8b949e; font-size: 12px; }
    .sidebar-header .live { color: #3fb950; font-size: 11px; margin-top: 4px; }
    .repo-header { display: flex; align-items: center; gap: 8px; padding: 8px 16px; cursor: pointer; color: #f0f6fc; font-size: 14px; font-weight: 600; user-select: none; }
    .repo-header:hover { background: #1c2128; }
    .repo-header .arrow { color: #484f58; font-size: 10px; transition: transform 0.15s; }
    .repo-header .arrow.open { transform: rotate(90deg); }
    .repo-badge { font-size: 10px; padding: 1px 6px; border-radius: 10px; font-weight: 600; }
    .plan-item { display: flex; align-items: center; gap: 8px; padding: 6px 16px 6px 32px; cursor: pointer; font-size: 13px; color: #c9d1d9; }
    .plan-item:hover { background: #1c2128; }
    .plan-item.active { background: #1c2128; border-left: 2px solid #58a6ff; }
    .plan-item .dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
    .plan-item .plan-label { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .plan-item .plan-pct { color: #8b949e; font-size: 11px; }
    .show-more { color: #58a6ff; justify-content: center; font-size: 12px; }
    .main { flex: 1; overflow-y: auto; padding: 24px 32px; }
    .main-empty { display: flex; align-items: center; justify-content: center; height: 100%; color: #484f58; font-size: 16px; flex-direction: column; gap: 8px; }
    .plan-title { color: #f0f6fc; font-size: 22px; font-weight: 600; margin-bottom: 4px; }
    .plan-meta { color: #8b949e; font-size: 12px; margin-bottom: 16px; font-family: 'SF Mono', monospace; }
    .progress-bar { background: #21262d; border-radius: 4px; height: 8px; margin-bottom: 20px; overflow: hidden; }
    .progress-fill { height: 100%; border-radius: 4px; transition: width 0.3s; }
    .section-label { color: #8b949e; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; margin: 20px 0 8px; }
    .step { display: flex; align-items: flex-start; padding: 10px 12px; border-radius: 6px; margin-bottom: 2px; }
    .step:hover { background: #161b22; }
    .step-icon { width: 20px; margin-right: 12px; margin-top: 1px; flex-shrink: 0; text-align: center; font-size: 14px; }
    .step-done .step-text { color: #8b949e; text-decoration: line-through; }
    .step-text { font-size: 14px; line-height: 1.5; }
    .step-file { color: #484f58; font-size: 11px; font-family: monospace; margin-left: 8px; }
    .timestamp { color: #484f58; font-size: 11px; margin-top: 32px; text-align: right; }
    .refresh-flash { animation: flash 0.5s ease-out; }
    @keyframes flash { 0% { background: #1c3a1c; } 100% { background: transparent; } }
  </style>
</head>
<body>
  <div class="sidebar">
    <div class="sidebar-header">
      <h1>lean-flow</h1>
      <div class="stats" id="stats"></div>
      <div class="live" id="live-indicator">● Live</div>
    </div>
    <div id="repo-list"></div>
  </div>
  <div class="main" id="main">
    <div class="main-empty">
      <div style="font-size:40px">📋</div>
      <div>Select a plan from the sidebar</div>
    </div>
  </div>

  <script>
    let rawPlans = ${plansJSON};
    let activeKey = null;

    function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    function process(plans) {
      plans.forEach(p => {
        p.doneCount = p.steps.filter(s => s.done).length;
        p.totalCount = p.steps.length;
        p.pct = p.totalCount > 0 ? Math.round((p.doneCount / p.totalCount) * 100) : 0;
        p.isComplete = p.doneCount === p.totalCount && p.totalCount > 0;
      });
      // Group by project
      const groups = {};
      plans.forEach(p => { if (!groups[p.project]) groups[p.project] = []; groups[p.project].push(p); });
      // Sort within groups
      Object.values(groups).forEach(arr => arr.sort((a, b) => {
        if (a.isComplete !== b.isComplete) return a.isComplete ? 1 : -1;
        if (!a.isComplete) return a.pct - b.pct;
        return b.mtime - a.mtime;
      }));
      // Sort groups
      return Object.entries(groups).sort((a, b) => {
        const ai = a[1].some(p => !p.isComplete), bi = b[1].some(p => !p.isComplete);
        if (ai !== bi) return ai ? -1 : 1;
        return a[0].localeCompare(b[0]);
      });
    }

    function renderSidebar(groups) {
      const el = document.getElementById('repo-list');
      el.innerHTML = '';
      let totalS = 0, totalD = 0, totalP = 0;
      groups.forEach(([,plans]) => plans.forEach(p => { totalP++; totalS += p.totalCount; totalD += p.doneCount; }));
      document.getElementById('stats').textContent = totalP + ' plans · ' + totalD + '/' + totalS + ' steps';

      const LIMIT = 20;
      groups.forEach(([project, plans]) => {
        const hasInc = plans.some(p => !p.isComplete);
        const gDone = plans.reduce((a,p) => a + p.doneCount, 0);
        const gTotal = plans.reduce((a,p) => a + p.totalCount, 0);
        const wrap = document.createElement('div');

        let hdr = document.createElement('div');
        hdr.className = 'repo-header';
        hdr.innerHTML = '<span class="arrow open">▶</span> 📁 ' + esc(project)
          + ' <span class="repo-badge" style="background:' + (hasInc?'#30363d':'#238636') + ';color:' + (hasInc?'#8b949e':'#fff') + '">' + gDone + '/' + gTotal + '</span>';

        const list = document.createElement('div');
        plans.forEach((p, i) => {
          const dot = p.isComplete ? '#238636' : (p.pct > 0 ? '#d29922' : '#484f58');
          const it = document.createElement('div');
          it.className = 'plan-item' + (activeKey === project+'/'+p.file ? ' active' : '');
          if (i >= LIMIT) it.style.display = 'none';
          it.innerHTML = '<span class="dot" style="background:'+dot+'"></span><span class="plan-label">'+esc(p.name)+'</span><span class="plan-pct">'+p.pct+'%</span>';
          it.onclick = () => { activeKey = project+'/'+p.file; renderAll(); renderPlan(p, project); };
          list.appendChild(it);
        });
        if (plans.length > LIMIT) {
          const more = document.createElement('div');
          more.className = 'plan-item show-more';
          more.textContent = 'Show ' + (plans.length - LIMIT) + ' more...';
          more.onclick = () => { list.querySelectorAll('[style*="display: none"]').forEach(e => e.style.display = ''); more.remove(); };
          list.appendChild(more);
        }

        hdr.onclick = () => {
          const a = hdr.querySelector('.arrow');
          a.classList.toggle('open');
          list.style.display = a.classList.contains('open') ? '' : 'none';
        };
        wrap.appendChild(hdr);
        wrap.appendChild(list);
        el.appendChild(wrap);
      });
    }

    function renderPlan(plan, project) {
      const m = document.getElementById('main');
      const bar = plan.isComplete ? '#238636' : '#d29922';
      const date = plan.mtime ? new Date(plan.mtime).toLocaleString() : '?';
      const pending = plan.steps.filter(s => !s.done);
      const done = plan.steps.filter(s => s.done);

      let h = '<div class="plan-title">' + esc(plan.name) + '</div>'
        + '<div class="plan-meta">' + esc(project) + ' · ' + esc(plan.file) + (plan.hasPlanPlus ? ' · <span style="color:#58a6ff">plan-plus</span>' : '') + ' · ' + date + '</div>'
        + '<div class="progress-bar"><div class="progress-fill" style="width:'+plan.pct+'%;background:'+bar+'"></div></div>';

      if (pending.length) {
        h += '<div class="section-label">Pending (' + pending.length + ')</div>';
        pending.forEach(s => h += stepHTML(s, false));
      }
      if (done.length) {
        h += '<div class="section-label">Completed (' + done.length + ')</div>';
        done.forEach(s => h += stepHTML(s, true));
      }
      if (!plan.steps.length) h += '<div style="color:#484f58;padding:24px;text-align:center">No steps</div>';
      h += '<div class="timestamp">Last modified: ' + date + '</div>';
      m.innerHTML = h;
      m.classList.add('refresh-flash');
      setTimeout(() => m.classList.remove('refresh-flash'), 500);
    }

    function stepHTML(s, done) {
      const icon = done ? '<span style="color:#3fb950">✓</span>' : '<span style="color:#d29922">○</span>';
      const f = s.file ? '<span class="step-file">' + esc(s.file) + '</span>' : '';
      return '<div class="step' + (done?' step-done':'') + '"><div class="step-icon">' + icon + '</div><div style="flex:1"><div class="step-text">' + esc(s.text) + f + '</div></div></div>';
    }

    function renderAll() {
      const groups = process(rawPlans);
      renderSidebar(groups);
      // Re-render active plan if any
      if (activeKey) {
        for (const [proj, plans] of groups) {
          const p = plans.find(p => proj+'/'+p.file === activeKey);
          if (p) { renderPlan(p, proj); return; }
        }
      }
    }

    // SSE live reload
    const es = new EventSource('/events');
    es.onmessage = (e) => {
      try {
        rawPlans = JSON.parse(e.data);
        renderAll();
        document.getElementById('live-indicator').textContent = '● Live — updated ' + new Date().toLocaleTimeString();
      } catch {}
    };
    es.onerror = () => {
      document.getElementById('live-indicator').textContent = '○ Disconnected';
      document.getElementById('live-indicator').style.color = '#d29922';
    };

    renderAll();
    // Auto-select first incomplete
    const first = document.querySelector('.plan-item:not(.show-more)');
    if (first) first.click();
  </script>
</body>
</html>`;
}

// ── HTTP Server ───────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  if (req.url === '/events') {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('data: ' + JSON.stringify(loadPlans()) + '\n\n');
    clients.add(res);
    req.on('close', () => clients.delete(res));
    return;
  }

  // Serve HTML
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(buildHTML());
});

// ── File Watcher ──────────────────────────────────────────────────────────

function notifyClients() {
  const data = JSON.stringify(loadPlans());
  for (const client of clients) {
    try { client.write('data: ' + data + '\n\n'); } catch { clients.delete(client); }
  }
}

// Watch plans directory
if (fs.existsSync(PLANS_DIR)) {
  fs.watch(PLANS_DIR, { recursive: true }, (_event, _filename) => {
    // Debounce — wait 500ms before notifying
    clearTimeout(notifyClients._timer);
    notifyClients._timer = setTimeout(notifyClients, 500);
  });
}

// Also watch CWD .claude/plans if it exists
const cwdPlans = path.join(process.cwd(), '.claude', 'plans');
if (fs.existsSync(cwdPlans) && cwdPlans !== PLANS_DIR) {
  fs.watch(cwdPlans, { recursive: true }, () => {
    clearTimeout(notifyClients._timer);
    notifyClients._timer = setTimeout(notifyClients, 500);
  });
}

server.listen(PORT, () => {
  console.log(`lean-flow plan viewer running at http://localhost:${PORT}`);
  console.log(`Watching: ${PLANS_DIR}`);
  if (fs.existsSync(cwdPlans) && cwdPlans !== PLANS_DIR) console.log(`Watching: ${cwdPlans}`);
});
