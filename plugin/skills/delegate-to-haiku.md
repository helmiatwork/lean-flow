---
name: delegate-to-haiku
description: Route mechanical shell commands (git, grep, npm, pytest, etc.) to haiku sub-agents instead of running them in the orchestrator context. Use whenever the task is purely command execution or file reading with no complex reasoning.
---

# Delegate to Haiku

Mechanical tasks do not need an expensive model. When the work is shell commands, file reads, search, or test runs — delegate to a haiku sub-agent and stay out of the main context.

## Rule

**Never run these directly in the orchestrator:**
- Git operations: `git status`, `git log`, `git diff`, `git add`, `git commit`, `git push`, `git pull`, `git branch`, `git checkout`, `git stash`, `git rebase`
- Search: `grep`, `find`, `rg`, `ls`, file reads, glob patterns
- Test runners: `npm test`, `pytest`, `go test`, `cargo test`, `jest`, `rspec`, `make test`
- Build / install: `npm install`, `pip install`, `brew install`, `make`, `cargo build`
- File ops: `cp`, `mv`, `mkdir`, `wc`, `du`, `cat`, `head`, `tail`

**Delegate instead:**

| Task type | Agent | Why |
|-----------|-------|-----|
| Read files, search, git log, diff | `explorer` | Read-only, haiku |
| git commit, file edits, installs, test runs | `fixer` | Write-capable, haiku |

## How to delegate

```
# Instead of: git log --oneline -10
explorer("Run: git log --oneline -10. Return the output.")

# Instead of: grep -r "pattern" src/
explorer("Search for 'pattern' in src/ using grep -r. Return matching lines.")

# Instead of: git add -A && git commit -m "feat: ..."
fixer("Run: git add -A && git commit -m 'feat: ...' Return the exit status and any errors.")

# Instead of: npm test
fixer("Run: npm test. Return pass/fail summary and any failing test names.")

# Instead of: git push origin feature/xyz
fixer("Run: git push origin feature/xyz. Return output.")
```

## When NOT to delegate

- You need the result immediately to decide the next tool call (sequential dependency)
- The command takes under 2 seconds and the output is 1-2 lines (not worth the agent overhead)
- You are already inside a haiku sub-agent

## Token savings

Each delegation keeps that command's output out of the orchestrator's context window. A `git log` returning 50 lines costs ~400 tokens if read by opus directly. Delegated to explorer (haiku), the orchestrator only sees the summary — typically 2-3 lines.

Combined with `rtk` (which compresses output before it hits any context), routine command chains become near-zero cost.
