#!/usr/bin/env python3
"""
CI codemap updater — runs on push to main.
Detects changed directories, calls Claude API to fill in codemap.md
for each affected folder. Only touches folders that actually changed.
"""

import os
import subprocess
import sys
from pathlib import Path

import anthropic

REPO_ROOT = Path(subprocess.run(
    ["git", "rev-parse", "--show-toplevel"],
    capture_output=True, text=True
).stdout.strip())

SKIP_DIRS = {
    ".git", "node_modules", "__pycache__", ".venv", "venv",
    "dist", "build", ".next", ".nuxt", "coverage", ".slim",
}
SKIP_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff",
    ".woff2", ".ttf", ".eot", ".pdf", ".zip", ".tar", ".gz",
    ".db", ".sqlite", ".lock", ".pyc",
}
MAX_FILE_LINES = 120
MAX_FILES_PER_DIR = 20

CODEMAP_TEMPLATE = """\
# {folder}/

## Responsibility

{responsibility}

## Design

{design}

## Flow

{flow}

## Integration

{integration}
"""

SYSTEM_PROMPT = """\
You are a senior engineer maintaining codebase documentation.
You write concise, accurate codemap.md files for directories.
Each section should be 2-5 bullet points or a short paragraph.
Be specific — name actual files, functions, patterns. No filler.
"""


def get_changed_dirs() -> set[str]:
    """Get directories affected by commits since last push."""
    result = subprocess.run(
        ["git", "diff", "--name-only", "HEAD~1", "HEAD"],
        capture_output=True, text=True
    )
    if result.returncode != 0 or not result.stdout.strip():
        return set()

    dirs: set[str] = set()
    for file_path in result.stdout.strip().splitlines():
        p = Path(file_path)
        # Add every ancestor directory up to repo root
        for parent in [p.parent] + list(p.parents):
            rel = str(parent)
            if rel == ".":
                break
            dirs.add(rel)
    return dirs


def should_skip(path: Path) -> bool:
    return any(part in SKIP_DIRS for part in path.parts)


def read_dir_contents(dir_path: Path) -> str:
    """Read files in a directory, truncated for token budget."""
    entries = []
    files = sorted(
        f for f in dir_path.iterdir()
        if f.is_file()
        and f.suffix not in SKIP_EXTENSIONS
        and f.name != "codemap.md"
    )[:MAX_FILES_PER_DIR]

    for f in files:
        try:
            lines = f.read_text(errors="replace").splitlines()
            preview = "\n".join(lines[:MAX_FILE_LINES])
            truncated = len(lines) > MAX_FILE_LINES
            entries.append(
                f"### {f.name}{' (truncated)' if truncated else ''}\n```\n{preview}\n```"
            )
        except Exception:
            entries.append(f"### {f.name}\n(binary or unreadable)")

    subdirs = [d.name + "/" for d in sorted(dir_path.iterdir()) if d.is_dir() and d.name not in SKIP_DIRS]
    header = f"Files: {', '.join(f.name for f in files)}"
    if subdirs:
        header += f"\nSubdirectories: {', '.join(subdirs)}"

    return header + "\n\n" + "\n\n".join(entries)


def generate_codemap(client: anthropic.Anthropic, folder: str, contents: str) -> str:
    """Call Claude to generate codemap.md content for a directory."""
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=[{
            "type": "text",
            "text": SYSTEM_PROMPT,
            "cache_control": {"type": "ephemeral"},
        }],
        messages=[{
            "role": "user",
            "content": f"""\
Write a codemap.md for the `{folder}/` directory.

Directory contents:
{contents}

Return ONLY the four sections below, filled in. No preamble.

## Responsibility
(what this folder's job is in the system)

## Design
(key patterns, abstractions, architectural decisions)

## Flow
(how data/control flows through this module)

## Integration
(how it connects to other parts of the system)
"""
        }],
    )

    body = response.content[0].text.strip()

    # Wrap in the standard template header
    return f"# {folder}/\n\n{body}\n"


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY not set", file=sys.stderr)
        return 1

    changed_dirs = get_changed_dirs()
    if not changed_dirs:
        print("No changed directories detected.")
        return 0

    print(f"Changed directories: {sorted(changed_dirs)}")

    client = anthropic.Anthropic(api_key=api_key)
    updated = []

    for rel_dir in sorted(changed_dirs):
        dir_path = REPO_ROOT / rel_dir

        if not dir_path.is_dir() or should_skip(dir_path):
            continue

        codemap_path = dir_path / "codemap.md"
        if not codemap_path.exists():
            continue  # only update existing codemaps, don't create new ones

        print(f"  Updating {rel_dir}/codemap.md ...")
        try:
            contents = read_dir_contents(dir_path)
            new_content = generate_codemap(client, rel_dir, contents)
            codemap_path.write_text(new_content)
            updated.append(rel_dir)
        except Exception as e:
            print(f"  WARN: failed for {rel_dir}: {e}", file=sys.stderr)

    print(f"\nUpdated {len(updated)} codemaps: {updated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
