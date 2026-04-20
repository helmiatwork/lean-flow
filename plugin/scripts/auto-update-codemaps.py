#!/usr/bin/env python3
"""
PostToolUse hook: auto-updates codemap.md files after git commit.
Gets changed dirs from git diff-tree, reads files, calls Claude API to fill in sections.
Uses OAuth token from macOS keychain, falls back to ANTHROPIC_API_KEY env var.
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from pathlib import Path

REPO_ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()

SKIP_DIRS = {
    "node_modules", "__pycache__", ".git", ".venv", "venv",
    "dist", "build", ".slim", ".github",
}
SKIP_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff",
    ".woff2", ".ttf", ".pdf", ".zip", ".tar", ".gz",
    ".db", ".sqlite", ".lock", ".pyc",
}
MAX_FILE_LINES = 100
MAX_FILES_PER_DIR = 15

SYSTEM_PROMPT = """\
You are a senior engineer maintaining codebase documentation.
Write concise, accurate codemap sections for directories.
Each section should be 2-5 bullet points or a short paragraph.
Be specific — name actual files, functions, patterns. No filler."""


def get_oauth_token() -> str:
    """Get OAuth token from keychain, fall back to env var."""
    # Try macOS keychain first
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            creds = json.loads(result.stdout.strip())
            token = creds.get("claudeAiOauth", {}).get("accessToken", "")
            if token:
                return token
    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
        pass

    # Fall back to env var
    token = os.environ.get("ANTHROPIC_API_KEY", "")
    return token


def get_changed_dirs() -> set[str]:
    """Get directories affected by the HEAD commit."""
    try:
        result = subprocess.run(
            ["git", "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode != 0 or not result.stdout.strip():
            return set()

        dirs = set()
        for file_path in result.stdout.strip().splitlines():
            p = Path(file_path)
            # Add every ancestor directory up to repo root
            for parent in [p.parent] + list(p.parents):
                rel = str(parent)
                if rel == ".":
                    break
                dirs.add(rel)
        return dirs
    except Exception:
        return set()


def should_skip(path: Path) -> bool:
    """Check if path should be skipped."""
    return any(part in SKIP_DIRS for part in path.parts)


def read_dir_contents(dir_path: Path) -> str:
    """Read files in a directory, truncated for token budget."""
    entries = []
    try:
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

        subdirs = [
            d.name + "/" for d in sorted(dir_path.iterdir())
            if d.is_dir() and d.name not in SKIP_DIRS
        ]
        header = f"Files: {', '.join(f.name for f in files)}"
        if subdirs:
            header += f"\nSubdirectories: {', '.join(subdirs)}"

        return header + "\n\n" + "\n\n".join(entries)
    except Exception:
        return ""


def generate_codemap(token: str, folder: str, contents: str) -> str:
    """Call Claude API to generate codemap content for a directory."""
    user_message = f"""\
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
(how it connects to other parts of the system)"""

    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 800,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": user_message}],
    }

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
        "anthropic-version": "2023-06-01",
    }

    try:
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode("utf-8"))
            body = result["content"][0]["text"].strip()
            return f"# {folder}/\n\n{body}\n"
    except urllib.error.URLError as e:
        print(f"API error: {e}", file=sys.stderr)
        return ""
    except Exception as e:
        print(f"Error calling API: {e}", file=sys.stderr)
        return ""


def main() -> int:
    # Get OAuth token
    token = get_oauth_token()
    if not token:
        print("ERROR: No OAuth token found (keychain or ANTHROPIC_API_KEY)", file=sys.stderr)
        return 1

    # Get changed directories
    changed_dirs = get_changed_dirs()
    if not changed_dirs:
        return 0

    updated = []

    for rel_dir in sorted(changed_dirs):
        dir_path = REPO_ROOT / rel_dir

        if not dir_path.is_dir() or should_skip(dir_path):
            continue

        codemap_path = dir_path / "codemap.md"
        if not codemap_path.exists():
            continue  # only update existing codemaps

        try:
            contents = read_dir_contents(dir_path)
            if not contents:
                continue

            new_content = generate_codemap(token, rel_dir, contents)
            if not new_content:
                continue

            codemap_path.write_text(new_content)
            updated.append(rel_dir)
        except Exception as e:
            print(f"WARN: failed for {rel_dir}: {e}", file=sys.stderr)

    # Stage updated codemaps
    for rel_dir in updated:
        codemap_path = REPO_ROOT / rel_dir / "codemap.md"
        try:
            subprocess.run(
                ["git", "add", str(codemap_path)],
                cwd=REPO_ROOT,
                capture_output=True,
                timeout=5
            )
        except Exception as e:
            print(f"WARN: failed to stage {rel_dir}/codemap.md: {e}", file=sys.stderr)

    # Commit if we updated anything
    if updated:
        try:
            subprocess.run(
                ["git", "commit", "--no-verify", "-m", "chore: auto-update codemaps [skip ci]"],
                cwd=REPO_ROOT,
                capture_output=True,
                timeout=10
            )
        except Exception as e:
            print(f"WARN: failed to commit codemaps: {e}", file=sys.stderr)

    # Output hookSpecificOutput
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": f"Updated codemaps in: {', '.join(updated)}" if updated else "No codemaps updated"
        }
    }
    print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
