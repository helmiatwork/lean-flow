# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
This directory contains **specialized AI agent definitions** for the content production and analysis pipeline. Each `.md` file defines a single-purpose agent (clip finder, script writer, QC gate, etc.) with its model choice, tools, workflow, and output contract. Agents are invoked by an orchestrator to handle specific stages of short-form video creation — from sourcing moments to publishing.

## Design
- **Agent-per-stage pattern:** Each agent owns one focused task (e.g., `auto-clip-finder` finds viral moments; `auto-script-writer` writes hooks and beat sheets; `auto-qc-gate` validates before posting). No agent does two things.
- **Model selection by task:** Lighter agents use Sonnet (cost/speed); heavier strategic work uses Opus (e.g., `auto-content-analyze-senior` for deep viral breakdowns). `code-reviewer`, `designer`, `fixer`, `explorer` are auxiliary for the coding system.
- **Contract-first:** Each agent file opens with a YAML header (name, model, tools, description) followed by role definition and exact input/output shape. Downstream callers know precisely what to send and what to expect.
- **Tools are explicit:** Most agents declare a fixed tool set (`Read`, `Bash`, `Grep`, `Glob`; some add `WebSearch`, `yt-dlp`, `ffmpeg`, `whisper`). No hidden capabilities.
- **Language-agnostic:** Many agents note "input may be informal Indonesian/English — do NOT grammar-check" and reply in user's language, but keep JSON keys stable.

## Flow
1. **User gives a task** (e.g., "find clip-worthy moments in this video") → **orchestrator routes to the right agent**.
2. **Agent ingests** (fetch metadata, download/sample, extract frames/audio) → **applies domain logic** (clip scoring, script structuring, QC rules) → **outputs a deliverable** (clip ranges with timecodes, beat sheets, PASS/FAIL verdict).
3. **Handoff pattern:** Strategic agents like `content-analyze-senior` read factual layers from cheaper agents (`content-analyze`) to avoid re-downloading/re-reading frames — cost/accuracy optimization.
4. **Multi-stage pipelines:** e.g., `auto-clip-finder` → `auto-script-writer` → `auto-editor` (builds EDL) → `auto-qc-gate` → `content-producer` (outputs human checklist).

## Integration
- **Upstream:** Receives user prompts + optional file paths (videos, scripts, JSON handoffs from prior agents).
- **Downstream:** Outputs are consumed by humans (run sheets, scripts, captions) or fed into the next agent stage (e.g., `auto-editor` consumes `auto-clip-finder` clip ranges + `auto-script-writer` VO script).
- **Auxiliary agents** (`fixer`, `designer`, `code-reviewer`, `explorer`, `discuss`) support the broader **lean-flow** code-automation system; they are included in this directory but operate on *software development*, not content production. They are framework agents for the plugin infrastructure.
- **Common dependencies:** `yt-dlp`, `ffmpeg`, `ffprobe`, `whisper` for media; `python3` for JSON parsing; `Read`/`Bash`/`Grep`/`Glob` for file
