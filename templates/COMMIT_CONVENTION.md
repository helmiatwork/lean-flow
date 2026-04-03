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

## PR Descriptions — Two Templates

### Step PR (child → parent branch)

Use `PULL_REQUEST_TEMPLATE.md`. Keep it short:

- **What**: One sentence — what this step implements
- **Changes**: Bullet points — scannable in 10 seconds
- **How to test**: Real commands

This is a technical PR for the developer reviewing the step.

### Feature PR (parent → main/master)

Use `PULL_REQUEST_TEMPLATE_MAIN.md`. More descriptive:

- **Overview**: What it does + why, 3-4 sentences, no jargon
- **Step PRs**: Links to ALL child PRs that were merged into parent
- **How to test**: End-to-end verification of the complete feature
- **Security audit**: Passed or issues found
- **Release Notes**: REQUIRED — written for end users, not developers

### Release Notes Rules

**Every PR to main/master MUST have release notes.** This includes:
- Features (`feature/`)
- Hotfixes (`hotfix/`)
- Improvements (`improvement/`)
- Security fixes (`security/`)

Release notes are for **end users and stakeholders**, not developers:
- Good: "Teachers can now score all students in a classroom at once"
- Bad: "Added bulkCreateDailyScores mutation with classroomId parameter"
- Good: "Fixed an issue where the calendar would show events from the wrong month"
- Bad: "Fixed off-by-one error in date range query for ClassroomEventsDocument"

**Don't:**
- Write paragraphs — use bullets
- Repeat the diff — the reviewer can read code
- Use vague language — "improve", "update", "fix things"
- Include AI attribution — no co-authored-by, no "generated with"
- Use technical jargon in release notes — no model names, no query names
