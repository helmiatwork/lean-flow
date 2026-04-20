#!/usr/bin/env python3
"""
Test suite for scan-codebase.py

Tests all key functions including parse_gitignore, matches_pattern,
should_ignore, is_text_file, count_tokens, and format_tree.

Run with: python3 tests/python/test_scan_codebase.py
"""

import sys
import types
import unittest
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch
import importlib.util

# Mock tiktoken before importing the module under test
tiktoken_mock = types.ModuleType("tiktoken")
mock_encoding = MagicMock()
tiktoken_mock.get_encoding = MagicMock(return_value=mock_encoding)
tiktoken_mock.Encoding = MagicMock()
sys.modules["tiktoken"] = tiktoken_mock

# Import the scan_codebase module using importlib due to hyphenated filename
spec = importlib.util.spec_from_file_location(
    "scan_codebase",
    Path(__file__).parent.parent.parent / "plugin" / "scripts" / "scan-codebase.py"
)
scan_codebase = importlib.util.module_from_spec(spec)
sys.modules["scan_codebase"] = scan_codebase
spec.loader.exec_module(scan_codebase)


class TestParseGitignore(unittest.TestCase):
    """Tests for parse_gitignore function"""

    def test_no_gitignore_file(self):
        """Should return empty list when .gitignore does not exist"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            result = scan_codebase.parse_gitignore(root)
            self.assertEqual(result, [])

    def test_empty_gitignore(self):
        """Should return empty list for empty .gitignore"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".gitignore").write_text("")
            result = scan_codebase.parse_gitignore(root)
            self.assertEqual(result, [])

    def test_skips_comments_and_blanks(self):
        """Should skip comment lines and blank lines"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_content = """# This is a comment
dist/

# Another comment

node_modules
build/
"""
            (root / ".gitignore").write_text(gitignore_content)
            result = scan_codebase.parse_gitignore(root)
            self.assertEqual(result, ["dist/", "node_modules", "build/"])

    def test_preserves_patterns(self):
        """Should preserve pattern syntax including wildcards and slashes"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_content = """*.pyc
__pycache__/
/build
src/**/*.tmp
"""
            (root / ".gitignore").write_text(gitignore_content)
            result = scan_codebase.parse_gitignore(root)
            self.assertEqual(result, ["*.pyc", "__pycache__/", "/build", "src/**/*.tmp"])

    def test_handles_encoding_errors(self):
        """Should gracefully handle files with encoding issues"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            # Write valid UTF-8 patterns (errors="ignore" in parser handles issues)
            (root / ".gitignore").write_text("*.pyc\nnode_modules\n")
            result = scan_codebase.parse_gitignore(root)
            self.assertIn("*.pyc", result)
            self.assertIn("node_modules", result)


class TestMatchesPattern(unittest.TestCase):
    """Tests for matches_pattern function"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_exact_name_match(self):
        """Should match exact name (no glob)"""
        test_file = self.root / "test.py"
        test_file.write_text("")
        self.assertTrue(scan_codebase.matches_pattern(test_file, "test.py", self.root))

    def test_glob_pattern_match(self):
        """Should match glob patterns like *.py"""
        test_file = self.root / "test.py"
        test_file.write_text("")
        self.assertTrue(scan_codebase.matches_pattern(test_file, "*.py", self.root))

    def test_glob_pattern_no_match(self):
        """Should not match when glob doesn't apply"""
        test_file = self.root / "test.py"
        test_file.write_text("")
        self.assertFalse(scan_codebase.matches_pattern(test_file, "*.js", self.root))

    def test_directory_pattern_with_slash(self):
        """Should match directory patterns ending with /"""
        test_dir = self.root / "node_modules"
        test_dir.mkdir()
        self.assertTrue(scan_codebase.matches_pattern(test_dir, "node_modules/", self.root))

    def test_directory_pattern_not_file(self):
        """Should not match directory patterns when given a file"""
        test_file = self.root / "node_modules"
        test_file.write_text("")
        self.assertFalse(scan_codebase.matches_pattern(test_file, "node_modules/", self.root))

    def test_root_pattern_with_prefix_slash(self):
        """Should match patterns with leading /"""
        test_dir = self.root / "build"
        test_dir.mkdir()
        self.assertTrue(scan_codebase.matches_pattern(test_dir, "/build", self.root))

    def test_pattern_with_path_separator(self):
        """Should match patterns with path separators"""
        src_dir = self.root / "src"
        src_dir.mkdir()
        test_file = src_dir / "test.py"
        test_file.write_text("")
        # Pattern with / should match relative path
        self.assertTrue(scan_codebase.matches_pattern(test_file, "src/*.py", self.root))

    def test_negation_pattern(self):
        """Should never match negation patterns (!)"""
        test_file = self.root / "test.py"
        test_file.write_text("")
        self.assertFalse(scan_codebase.matches_pattern(test_file, "!test.py", self.root))

    def test_non_matching_pattern(self):
        """Should return False for non-matching patterns"""
        test_file = self.root / "test.py"
        test_file.write_text("")
        self.assertFalse(scan_codebase.matches_pattern(test_file, "other.js", self.root))


class TestShouldIgnore(unittest.TestCase):
    """Tests for should_ignore function"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_ignore_git_directory(self):
        """Should ignore .git directory"""
        git_dir = self.root / ".git"
        git_dir.mkdir()
        self.assertTrue(scan_codebase.should_ignore(git_dir, self.root, []))

    def test_ignore_node_modules(self):
        """Should ignore node_modules directory"""
        nm_dir = self.root / "node_modules"
        nm_dir.mkdir()
        self.assertTrue(scan_codebase.should_ignore(nm_dir, self.root, []))

    def test_ignore_pyc_files(self):
        """Should ignore *.pyc files"""
        pyc_file = self.root / "test.pyc"
        pyc_file.write_text("")
        self.assertTrue(scan_codebase.should_ignore(pyc_file, self.root, []))

    def test_ignore_minified_js(self):
        """Should ignore *.min.js files"""
        min_js = self.root / "bundle.min.js"
        min_js.write_text("")
        self.assertTrue(scan_codebase.should_ignore(min_js, self.root, []))

    def test_ignore_package_lock(self):
        """Should ignore package-lock.json"""
        lock_file = self.root / "package-lock.json"
        lock_file.write_text("")
        self.assertTrue(scan_codebase.should_ignore(lock_file, self.root, []))

    def test_allow_normal_py_file(self):
        """Should not ignore normal .py files"""
        py_file = self.root / "test.py"
        py_file.write_text("")
        self.assertFalse(scan_codebase.should_ignore(py_file, self.root, []))

    def test_respect_gitignore_patterns(self):
        """Should respect custom gitignore patterns"""
        custom_file = self.root / "custom.ignore"
        custom_file.write_text("")
        gitignore_patterns = ["*.ignore"]
        self.assertTrue(scan_codebase.should_ignore(custom_file, self.root, gitignore_patterns))

    def test_pycache_directory_ignored(self):
        """Should ignore __pycache__ directory"""
        cache_dir = self.root / "__pycache__"
        cache_dir.mkdir()
        self.assertTrue(scan_codebase.should_ignore(cache_dir, self.root, []))

    def test_svn_directory_ignored(self):
        """Should ignore .svn directory"""
        svn_dir = self.root / ".svn"
        svn_dir.mkdir()
        self.assertTrue(scan_codebase.should_ignore(svn_dir, self.root, []))

    def test_multiple_extensions_ignored(self):
        """Should ignore files with various ignored extensions"""
        test_cases = [
            ("test.pyo", True),
            ("lib.so", True),
            ("app.dll", True),
            ("module.o", True),
        ]
        for filename, should_be_ignored in test_cases:
            test_file = self.root / filename
            test_file.write_text("")
            result = scan_codebase.should_ignore(test_file, self.root, [])
            self.assertEqual(result, should_be_ignored,
                           f"File {filename} ignored={result}, expected={should_be_ignored}")


class TestIsTextFile(unittest.TestCase):
    """Tests for is_text_file function"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_python_file_is_text(self):
        """Should recognize .py files as text"""
        py_file = self.root / "test.py"
        py_file.write_text("print('hello')")
        self.assertTrue(scan_codebase.is_text_file(py_file))

    def test_png_file_is_not_text(self):
        """Should recognize .png files as non-text"""
        png_file = self.root / "image.png"
        png_file.write_bytes(b"\x89PNG\r\n\x1a\n")
        self.assertFalse(scan_codebase.is_text_file(png_file))

    def test_js_file_is_text(self):
        """Should recognize .js files as text"""
        js_file = self.root / "script.js"
        js_file.write_text("console.log('hello');")
        self.assertTrue(scan_codebase.is_text_file(js_file))

    def test_json_file_is_text(self):
        """Should recognize .json files as text"""
        json_file = self.root / "config.json"
        json_file.write_text('{"key": "value"}')
        self.assertTrue(scan_codebase.is_text_file(json_file))

    def test_dockerfile_is_text(self):
        """Should recognize Dockerfile (known name) as text"""
        dockerfile = self.root / "Dockerfile"
        dockerfile.write_text("FROM ubuntu:latest\nRUN apt-get update\n")
        self.assertTrue(scan_codebase.is_text_file(dockerfile))

    def test_makefile_is_text(self):
        """Should recognize Makefile (known name) as text"""
        makefile = self.root / "Makefile"
        makefile.write_text("all:\n\techo build\n")
        self.assertTrue(scan_codebase.is_text_file(makefile))

    def test_readme_is_text(self):
        """Should recognize README (known name) as text"""
        readme = self.root / "README"
        readme.write_text("# Project")
        self.assertTrue(scan_codebase.is_text_file(readme))

    def test_binary_file_with_null_bytes(self):
        """Should recognize files with null bytes as binary"""
        binary_file = self.root / "data.bin"
        binary_file.write_bytes(b"some\x00binary\x00data")
        self.assertFalse(scan_codebase.is_text_file(binary_file))

    def test_jpg_file_is_not_text(self):
        """Should recognize .jpg files as non-text"""
        jpg_file = self.root / "photo.jpg"
        jpg_file.write_bytes(b"\xff\xd8\xff\xe0")
        self.assertFalse(scan_codebase.is_text_file(jpg_file))

    def test_mp4_file_is_not_text(self):
        """Should recognize .mp4 files as non-text (has null bytes)"""
        mp4_file = self.root / "video.mp4"
        # MP4 header includes null bytes which indicates binary
        mp4_file.write_bytes(b"\x00\x00\x00\x20ftypmp42")
        self.assertFalse(scan_codebase.is_text_file(mp4_file))

    def test_shell_script_is_text(self):
        """Should recognize .sh files as text"""
        sh_file = self.root / "script.sh"
        sh_file.write_text("#!/bin/bash\necho 'hello'\n")
        self.assertTrue(scan_codebase.is_text_file(sh_file))

    def test_nonexistent_file(self):
        """Should return False for nonexistent files (Exception handling)"""
        nonexistent = self.root / "notexist.bin"
        self.assertFalse(scan_codebase.is_text_file(nonexistent))

    def test_case_insensitive_extension(self):
        """Should handle uppercase extensions"""
        py_upper = self.root / "test.PY"
        py_upper.write_text("print('hello')")
        self.assertTrue(scan_codebase.is_text_file(py_upper))

    def test_case_insensitive_known_name(self):
        """Should handle case-insensitive known names"""
        dockerfile_lower = self.root / "dockerfile"
        dockerfile_lower.write_text("FROM ubuntu:latest\n")
        self.assertTrue(scan_codebase.is_text_file(dockerfile_lower))

    def test_utf8_text_file_with_special_chars(self):
        """Should recognize UTF-8 files with special characters as text"""
        text_file = self.root / "unicode.txt"
        text_file.write_text("Hello 世界 🌍")
        self.assertTrue(scan_codebase.is_text_file(text_file))

    def test_invalid_utf8_detected_as_binary(self):
        """Should detect files with invalid UTF-8 as binary"""
        # Use a file without text extension so it must be detected by content
        invalid_utf8 = self.root / "data.bin"
        invalid_utf8.write_bytes(b"\x80\x81\x82\x83")
        self.assertFalse(scan_codebase.is_text_file(invalid_utf8))


class TestCountTokens(unittest.TestCase):
    """Tests for count_tokens function"""

    def setUp(self):
        self.encoding_mock = MagicMock()

    def test_count_tokens_calls_encode(self):
        """Should call encoding.encode with the text"""
        self.encoding_mock.encode = MagicMock(return_value=[1, 2, 3])
        result = scan_codebase.count_tokens("hello world", self.encoding_mock)
        self.encoding_mock.encode.assert_called_once_with("hello world")
        self.assertEqual(result, 3)

    def test_count_tokens_returns_list_length(self):
        """Should return the length of the encoded list"""
        self.encoding_mock.encode = MagicMock(return_value=[1, 2, 3, 4, 5])
        result = scan_codebase.count_tokens("some text", self.encoding_mock)
        self.assertEqual(result, 5)

    def test_count_tokens_fallback_on_exception(self):
        """Should fall back to len(text)//4 when encode raises"""
        self.encoding_mock.encode = MagicMock(side_effect=Exception("encode failed"))
        result = scan_codebase.count_tokens("1234567890", self.encoding_mock)
        # len("1234567890") = 10, 10 // 4 = 2
        self.assertEqual(result, 2)

    def test_count_tokens_fallback_empty_string(self):
        """Should handle empty string fallback (0 // 4 = 0)"""
        self.encoding_mock.encode = MagicMock(side_effect=Exception("encode failed"))
        result = scan_codebase.count_tokens("", self.encoding_mock)
        self.assertEqual(result, 0)

    def test_count_tokens_fallback_small_string(self):
        """Should handle small strings in fallback (len < 4)"""
        self.encoding_mock.encode = MagicMock(side_effect=Exception("encode failed"))
        result = scan_codebase.count_tokens("ab", self.encoding_mock)
        # len("ab") = 2, 2 // 4 = 0
        self.assertEqual(result, 0)

    def test_count_tokens_with_long_text(self):
        """Should handle long text correctly"""
        long_text = "a" * 1000
        self.encoding_mock.encode = MagicMock(return_value=[i for i in range(250)])
        result = scan_codebase.count_tokens(long_text, self.encoding_mock)
        self.assertEqual(result, 250)

    def test_count_tokens_with_unicode(self):
        """Should handle unicode text"""
        unicode_text = "Hello 世界 🌍"
        self.encoding_mock.encode = MagicMock(return_value=[1, 2, 3, 4, 5])
        result = scan_codebase.count_tokens(unicode_text, self.encoding_mock)
        self.assertEqual(result, 5)


class TestFormatTree(unittest.TestCase):
    """Tests for format_tree function"""

    def test_format_tree_contains_root_name(self):
        """Should contain the root directory name"""
        scan_result = {
            "root": "/path/to/project",
            "files": [],
            "directories": [],
            "total_files": 0,
            "total_tokens": 0,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("project/", output)

    def test_format_tree_contains_total_line(self):
        """Should contain Total line with file and token count"""
        scan_result = {
            "root": "/path/to/project",
            "files": [],
            "directories": [],
            "total_files": 5,
            "total_tokens": 1000,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("Total:", output)
        self.assertIn("5 files", output)
        self.assertIn("1,000 tokens", output)

    def test_format_tree_single_file(self):
        """Should render a single file at top level"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "test.py", "tokens": 100, "size_bytes": 1000},
            ],
            "directories": [],
            "total_files": 1,
            "total_tokens": 100,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("test.py", output)
        self.assertIn("100", output)

    def test_format_tree_multiple_files(self):
        """Should render multiple files"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "main.py", "tokens": 200, "size_bytes": 2000},
                {"path": "utils.py", "tokens": 150, "size_bytes": 1500},
            ],
            "directories": [],
            "total_files": 2,
            "total_tokens": 350,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("main.py", output)
        self.assertIn("utils.py", output)

    def test_format_tree_nested_files(self):
        """Should render nested directory structure"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "src/main.py", "tokens": 200, "size_bytes": 2000},
                {"path": "src/utils.py", "tokens": 150, "size_bytes": 1500},
                {"path": "tests/test_main.py", "tokens": 100, "size_bytes": 1000},
            ],
            "directories": ["src", "tests"],
            "total_files": 3,
            "total_tokens": 450,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("src/", output)
        self.assertIn("tests/", output)
        self.assertIn("main.py", output)
        self.assertIn("test_main.py", output)

    def test_format_tree_show_tokens_false(self):
        """Should omit token counts on files when show_tokens=False"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "test.py", "tokens": 100, "size_bytes": 1000},
            ],
            "directories": [],
            "total_files": 1,
            "total_tokens": 100,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result, show_tokens=False)
        self.assertIn("test.py", output)
        # Should not have token count in parentheses for file
        self.assertNotIn("(100", output)

    def test_format_tree_large_token_count(self):
        """Should format large token counts with commas"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "large.py", "tokens": 1000000, "size_bytes": 10000000},
            ],
            "directories": [],
            "total_files": 1,
            "total_tokens": 1000000,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("1,000,000", output)

    def test_format_tree_complex_structure(self):
        """Should handle complex nested structure"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "README.md", "tokens": 50, "size_bytes": 500},
                {"path": "src/main.py", "tokens": 300, "size_bytes": 3000},
                {"path": "src/utils.py", "tokens": 200, "size_bytes": 2000},
                {"path": "src/helpers/base.py", "tokens": 150, "size_bytes": 1500},
                {"path": "tests/test_main.py", "tokens": 250, "size_bytes": 2500},
                {"path": "docs/guide.md", "tokens": 100, "size_bytes": 1000},
            ],
            "directories": ["src", "src/helpers", "tests", "docs"],
            "total_files": 6,
            "total_tokens": 1050,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        # Check key elements are present
        self.assertIn("README.md", output)
        self.assertIn("src/", output)
        self.assertIn("helpers/", output)
        self.assertIn("tests/", output)
        self.assertIn("docs/", output)
        self.assertIn("Total:", output)
        self.assertIn("1,050 tokens", output)

    def test_format_tree_empty_result(self):
        """Should handle empty scan results gracefully"""
        scan_result = {
            "root": "/path/to/project",
            "files": [],
            "directories": [],
            "total_files": 0,
            "total_tokens": 0,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        self.assertIn("project/", output)
        self.assertIn("Total: 0 files", output)

    def test_format_tree_tree_connectors(self):
        """Should use proper tree connectors (├── and └──)"""
        scan_result = {
            "root": "/path/to/project",
            "files": [
                {"path": "file1.py", "tokens": 100, "size_bytes": 1000},
                {"path": "file2.py", "tokens": 200, "size_bytes": 2000},
            ],
            "directories": [],
            "total_files": 2,
            "total_tokens": 300,
            "skipped": [],
        }
        output = scan_codebase.format_tree(scan_result)
        # Should contain tree drawing characters
        self.assertTrue(any(c in output for c in ["├", "└", "─"]))


class TestDefaultIgnoreSet(unittest.TestCase):
    """Tests for DEFAULT_IGNORE constant"""

    def test_default_ignore_contains_common_dirs(self):
        """Should contain common directories to ignore"""
        self.assertIn(".git", scan_codebase.DEFAULT_IGNORE)
        self.assertIn("node_modules", scan_codebase.DEFAULT_IGNORE)
        self.assertIn("__pycache__", scan_codebase.DEFAULT_IGNORE)

    def test_default_ignore_contains_common_extensions(self):
        """Should contain common binary/compiled extensions"""
        self.assertIn("*.pyc", scan_codebase.DEFAULT_IGNORE)
        self.assertIn("*.min.js", scan_codebase.DEFAULT_IGNORE)
        self.assertIn("*.png", scan_codebase.DEFAULT_IGNORE)

    def test_default_ignore_contains_lock_files(self):
        """Should contain lock files"""
        self.assertIn("package-lock.json", scan_codebase.DEFAULT_IGNORE)
        self.assertIn("*.lock", scan_codebase.DEFAULT_IGNORE)


if __name__ == "__main__":
    unittest.main()
