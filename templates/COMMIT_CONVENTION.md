# Commit & PR Convention

## Commit Messages

```
<type>: <what changed>
```

| Type | When |
|------|------|
| `feat` | New feature or screen |
| `fix` | Bug fix |
| `test` | Adding or fixing tests |
| `docs` | Documentation only |
| `chore` | Dependencies, config, CI |
| `refactor` | Code change that doesn't fix a bug or add a feature |
| `perf` | Performance improvement |
| `security` | Security fix |

**Rules:**
- Lowercase, no period at end
- Under 72 characters
- Describe WHAT, not HOW
- Good: `feat: add bulk score screen for teachers`
- Bad: `updated files`, `fix bug`, `WIP`

## PR Titles

Same format as commits: `<type>: <what changed>`

- Under 70 characters
- Describes the outcome, not the process
- Good: `feat: add teacher student detail with radar chart`
- Bad: `Feature/student-detail`, `Update index.tsx`

## PR Descriptions

Use the template. Key rules:

- **What**: One sentence. A reviewer should understand the PR from this alone.
- **Why**: Business reason or technical motivation. Not "because it was requested."
- **Changes**: Bullet points. Each bullet = one logical change. Scannable in 10 seconds.
- **How to test**: Real steps. `cd mobile && npx jest` not "run tests."

**Don't:**
- Write paragraphs — use bullets
- Repeat the diff — the reviewer can read code
- Use vague language — "improve", "update", "fix things"
- Include AI attribution — no co-authored-by, no "generated with"
