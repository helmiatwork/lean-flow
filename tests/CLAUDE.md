# tests/

Bash smoke + integration tests for lean-flow plugin internals.

## Conventions

- **Test runner: `tests/run-all.sh`** — explicit list, not auto-discovered. Register new test files there.
- **Bash 3.2 compat** — same rule as plugin/. No `[[`, no associative arrays.
- **Fixture isolation** — tests that read project files use `HOME=/nonexistent` or `mktemp -d` to avoid polluting the real environment.
- **Variable naming** — use `TEST_TMPDIR` not `TMPDIR` (TMPDIR is a system var on macOS).

## Adding a new test

1. Create `tests/shell/test-<name>.sh` with `set -euo pipefail` header.
2. Use the `assert` helper pattern from `test-project-doctor.sh`.
3. Register in `tests/run-all.sh`.
4. Run `bash tests/run-all.sh` locally; must pass before commit.
