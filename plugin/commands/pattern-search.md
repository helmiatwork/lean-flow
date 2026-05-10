---
name: pattern-search
description: Search knowledge MCP patterns (FTS5) with compact preview. View full or store new.
---

# /lean-flow:pattern-search

Search lean-flow pattern memory (SQLite + FTS5). Compact index retrieval with option to view full patterns or save new ones.

## Step 1 — Ask user: search query

Display AskUserQuestion:

```
Search patterns:

What problem or pattern are you looking for?
(Free text, e.g., "state management in React", "error handling", "database migration")

Enter query (or 'cancel'):
```

Store user's query string.

## Step 2 — Invoke pattern_search tool

Call `mcp__knowledge__pattern_search` tool with query:

```
Tool: pattern_search
Parameters:
  query: <user-query>
  project: <current-project-name-from-context>
```

Capture response (compact index, ~50 tokens).

## Step 3 — Parse and render results

Response should contain top 5 matches, each with:
- pattern ID (or index)
- pattern key (title/name)
- score (relevance 0–1)
- category (e.g., "architecture", "testing", "frontend")
- preview (1-line summary, ≤80 chars)
- file path (where stored)

Render markdown table:

```markdown
# Pattern Search Results

**Query:** "$USER_QUERY"  
**Matches:** N found (showing top 5)

| # | Pattern | Category | Score | Preview |
|---|---------|----------|-------|---------|
| 1 | <key> | <category> | <score> | <preview> |
| 2 | <key> | <category> | <score> | <preview> |
| ... | ... | ... | ... | ... |

---

## Options

[1–5] View full pattern (enter number)
[N]   Store new pattern (enters new pattern mode)
[X]   Cancel (exit)

Choose [1–5], [N], or [X]:
```

## Step 4A — If user selects [1–5]

Call `mcp__knowledge__pattern_get` tool:

```
Tool: pattern_get
Parameters:
  pattern_id: <selected-pattern-id>
```

Capture full response (solution + context, ~200+ tokens).

Render markdown:

```markdown
# Pattern: <pattern-key>

**Category:** <category>  
**Score:** <score>  
**Created:** <timestamp>  
**Last used:** <timestamp>  
**File:** <path>

## Summary
<pattern-summary>

## Problem
<problem-statement>

## Solution
<solution-code-or-steps>

## Context
<context-notes>

## Related patterns
<list-of-related-patterns-or-ids>

---

## Options

[R] Return to search results
[S] Store variation (fork this pattern)
[X] Exit

Choose [R], [S], or [X]:
```

**If [R]:** Return to Step 3 results table

**If [S]:** Go to Step 4B (new pattern mode with template pre-filled from current pattern)

**If [X]:** Exit cleanly

## Step 4B — If user selects [N] (store new pattern)

Display template form:

```
Store New Pattern

Pattern key (title, e.g., "react-context-state"):
$ <prompt>

Category (e.g., architecture, testing, frontend, api, database, performance):
$ <prompt>

Problem statement (what problem does this solve?):
$ <multiline-prompt>

Solution (code, steps, guidance):
$ <multiline-prompt>

Context (when to use this? gotchas? alternatives?):
$ <multiline-prompt>

---

Confirm? (Y/N):
```

Collect fields from user.

**If Y:**
Call `mcp__knowledge__pattern_store` tool:

```
Tool: pattern_store
Parameters:
  key: <pattern-key>
  category: <category>
  problem: <problem-statement>
  solution: <solution>
  context: <context>
  project: <current-project>
```

Render confirmation:

```markdown
✅ Pattern stored

| Field | Value |
|-------|-------|
| Key | <key> |
| Category | <category> |
| Project | <project> |
| File | <returned-path> |

Pattern is now searchable and shareable.
```

**If N:** Cancel, return to Step 3

## Step 5 — Loop or exit

After each action, ask user:

```
Continue searching? (Y/N)
```

**If Y:** Return to Step 1 (new search)

**If N:** Exit cleanly

## Hard rules

- **Read-only by default.** Searching is read-only; no writes unless user explicitly stores.
- **Compact index only on search.** First 50 tokens with preview; full pattern fetched on [1–5] selection (lazy loading, saves tokens).
- **No auto-suggestions.** Only return patterns that match query; don't suggest unrelated patterns.
- **Project-scoped.** Search and store are filtered by current project (from `project_context` MCP call).
- **Free-text format.** User can search however they want; FTS5 engine handles tokenization.
- **No questions on loop-back.** If user loops back to search, don't re-confirm; go straight to query prompt.
- **Graceful empty results.** If no matches, explain and offer to store a new pattern immediately.
