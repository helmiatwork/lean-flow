#!/usr/bin/env python3
import argparse, hashlib, json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set

VERSION = "1.0.0"
STATE_DIR = ".slim"
STATE_FILE = "cartography.json"
CODEMAP_FILE = "codemap.md"

def load_gitignore(root):
    gitignore_path = root / ".gitignore"
    patterns = []
    if gitignore_path.exists():
        with open(gitignore_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    patterns.append(line)
    return patterns

class PatternMatcher:
    def __init__(self, patterns):
        if not patterns:
            self.regex = None
            return
        regex_parts = []
        for pattern in patterns:
            reg = re.escape(pattern)
            reg = reg.replace(r'\*\*/', '(?:.*/)?')
            reg = reg.replace(r'\*\*', '.*')
            reg = reg.replace(r'\*', '[^/]*')
            reg = reg.replace(r'\?', '.')
            if pattern.endswith('/'):
                reg += '.*'
            if pattern.startswith('/'):
                reg = '^' + reg[1:]
            else:
                reg = '(?:^|.*/)' + reg
            regex_parts.append(f'(?:{reg}$)')
        combined_regex = '|'.join(regex_parts)
        self.regex = re.compile(combined_regex)

    def matches(self, path):
        if not self.regex:
            return False
        return bool(self.regex.search(path))

def select_files(root, include_patterns, exclude_patterns, exceptions, gitignore_patterns):
    selected = []
    include_matcher = PatternMatcher(include_patterns)
    exclude_matcher = PatternMatcher(exclude_patterns)
    gitignore_matcher = PatternMatcher(gitignore_patterns)
    exception_set = set(exceptions)
    root_str = str(root)
    for dirpath, dirnames, filenames in os.walk(root_str):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        rel_dir = os.path.relpath(dirpath, root_str)
        if rel_dir == ".":
            rel_dir = ""
        for filename in filenames:
            rel_path = os.path.join(rel_dir, filename).replace("\\", "/")
            if rel_path.startswith("./"):
                rel_path = rel_path[2:]
            if gitignore_matcher.matches(rel_path):
                continue
            if exclude_matcher.matches(rel_path):
                if rel_path not in exception_set:
                    continue
            if include_matcher.matches(rel_path) or rel_path in exception_set:
                selected.append(root / rel_path)
    return sorted(selected)

def compute_file_hash(filepath):
    hasher = hashlib.md5()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                hasher.update(chunk)
        return hasher.hexdigest()
    except (IOError, OSError):
        return ""

def compute_folder_hash(folder, file_hashes):
    folder_files = sorted(
        (path, hash_val)
        for path, hash_val in file_hashes.items()
        if path.startswith(folder + "/") or (folder == "." and "/" not in path)
    )
    if not folder_files:
        return ""
    hasher = hashlib.md5()
    for path, hash_val in folder_files:
        hasher.update(f"{path}:{hash_val}\n".encode())
    return hasher.hexdigest()

def get_folders_with_files(files, root):
    folders = set()
    for f in files:
        rel = f.relative_to(root)
        parts = rel.parts[:-1]
        for i in range(len(parts)):
            folders.add("/".join(parts[:i+1]))
    folders.add(".")
    return folders

def load_state(root):
    state_path = root / STATE_DIR / STATE_FILE
    if state_path.exists():
        try:
            with open(state_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None
    return None

def save_state(root, state):
    state_dir = root / STATE_DIR
    state_dir.mkdir(parents=True, exist_ok=True)
    state_path = state_dir / STATE_FILE
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)

def create_empty_codemap(folder_path, folder_name):
    codemap_path = folder_path / CODEMAP_FILE
    if not codemap_path.exists():
        content = f"# {folder_name}/\n\n## Responsibility\n\n<!-- What is this folder's job in the system? -->\n"
        with open(codemap_path, "w", encoding="utf-8") as f:
            f.write(content)
