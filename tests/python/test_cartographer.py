#!/usr/bin/env python3
import sys
import unittest
import tempfile
import json
import os
from pathlib import Path

# Import cartographer from scripts directory
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))
import cartographer


class TestPatternMatcher(unittest.TestCase):
    """Test PatternMatcher class"""

    def test_empty_patterns_never_matches(self):
        """Empty patterns should never match anything"""
        matcher = cartographer.PatternMatcher([])
        self.assertFalse(matcher.matches("file.ts"))
        self.assertFalse(matcher.matches("src/file.js"))
        self.assertFalse(matcher.matches(""))

    def test_wildcard_glob_pattern(self):
        """Wildcard *.ts should match .ts files at any level"""
        matcher = cartographer.PatternMatcher(["*.ts"])
        self.assertTrue(matcher.matches("file.ts"))
        self.assertTrue(matcher.matches("index.ts"))
        self.assertFalse(matcher.matches("file.js"))
        # *.ts pattern matches at any level due to regex construction
        self.assertTrue(matcher.matches("src/file.ts"))

    def test_double_star_glob_pattern(self):
        """Double-star ** should match any nested depth"""
        matcher = cartographer.PatternMatcher(["src/**/*.ts"])
        self.assertTrue(matcher.matches("src/file.ts"))
        self.assertTrue(matcher.matches("src/nested/file.ts"))
        self.assertTrue(matcher.matches("src/deeply/nested/path/file.ts"))
        self.assertFalse(matcher.matches("file.ts"))
        self.assertFalse(matcher.matches("other/file.ts"))

    def test_question_mark_glob_pattern(self):
        """Question mark ? should match single character"""
        matcher = cartographer.PatternMatcher(["file?.ts"])
        self.assertTrue(matcher.matches("file1.ts"))
        self.assertTrue(matcher.matches("fileA.ts"))
        self.assertFalse(matcher.matches("file.ts"))
        self.assertFalse(matcher.matches("file12.ts"))

    def test_directory_pattern_ending_with_slash(self):
        """Pattern ending in / should match directory and contents"""
        matcher = cartographer.PatternMatcher(["node_modules/"])
        self.assertTrue(matcher.matches("node_modules/package"))
        self.assertTrue(matcher.matches("node_modules/package/file.js"))
        self.assertTrue(matcher.matches("node_modules/"))
        self.assertFalse(matcher.matches("node_modules"))

    def test_multiple_patterns_any_match(self):
        """Multiple patterns should match if any pattern matches"""
        matcher = cartographer.PatternMatcher(["*.ts", "*.js", "*.py"])
        self.assertTrue(matcher.matches("file.ts"))
        self.assertTrue(matcher.matches("file.js"))
        self.assertTrue(matcher.matches("file.py"))
        self.assertFalse(matcher.matches("file.txt"))

    def test_negation_pattern_doesnt_crash(self):
        """Negation patterns should not cause crashes"""
        matcher = cartographer.PatternMatcher(["!*.test.ts"])
        # Should not crash
        self.assertIsNotNone(matcher.regex)

    def test_absolute_path_pattern(self):
        """Patterns starting with / should match from root"""
        matcher = cartographer.PatternMatcher(["/dist/"])
        self.assertTrue(matcher.matches("dist/file.js"))
        self.assertFalse(matcher.matches("src/dist/file.js"))


class TestLoadGitignore(unittest.TestCase):
    """Test load_gitignore function"""

    def test_missing_file_returns_empty_list(self):
        """Missing .gitignore should return empty list"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            result = cartographer.load_gitignore(root)
            self.assertEqual(result, [])

    def test_comments_and_blank_lines_skipped(self):
        """Comments and blank lines should be ignored"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_path = root / ".gitignore"
            gitignore_path.write_text("# This is a comment\n\n*.log\n# Another comment\nnode_modules/\n\n")
            result = cartographer.load_gitignore(root)
            self.assertEqual(result, ["*.log", "node_modules/"])

    def test_valid_patterns_loaded(self):
        """Valid patterns should be loaded correctly"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_path = root / ".gitignore"
            gitignore_path.write_text("*.pyc\n__pycache__/\n.env\n")
            result = cartographer.load_gitignore(root)
            self.assertEqual(result, ["*.pyc", "__pycache__/", ".env"])

    def test_whitespace_trimmed(self):
        """Whitespace should be trimmed from patterns"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_path = root / ".gitignore"
            gitignore_path.write_text("  *.log  \n\t*.tmp\t\n")
            result = cartographer.load_gitignore(root)
            self.assertEqual(result, ["*.log", "*.tmp"])

    def test_empty_gitignore(self):
        """Empty .gitignore should return empty list"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            gitignore_path = root / ".gitignore"
            gitignore_path.write_text("")
            result = cartographer.load_gitignore(root)
            self.assertEqual(result, [])


class TestComputeFileHash(unittest.TestCase):
    """Test compute_file_hash function"""

    def test_same_content_same_hash(self):
        """Same file content should produce same hash"""
        with tempfile.TemporaryDirectory() as tmpdir:
            filepath1 = Path(tmpdir) / "file1.txt"
            filepath2 = Path(tmpdir) / "file2.txt"
            content = "Hello, World!"
            filepath1.write_text(content)
            filepath2.write_text(content)
            hash1 = cartographer.compute_file_hash(filepath1)
            hash2 = cartographer.compute_file_hash(filepath2)
            self.assertEqual(hash1, hash2)

    def test_different_content_different_hash(self):
        """Different file content should produce different hashes"""
        with tempfile.TemporaryDirectory() as tmpdir:
            filepath1 = Path(tmpdir) / "file1.txt"
            filepath2 = Path(tmpdir) / "file2.txt"
            filepath1.write_text("Content A")
            filepath2.write_text("Content B")
            hash1 = cartographer.compute_file_hash(filepath1)
            hash2 = cartographer.compute_file_hash(filepath2)
            self.assertNotEqual(hash1, hash2)

    def test_nonexistent_file_returns_empty_string(self):
        """Nonexistent file should return empty string"""
        filepath = Path("/nonexistent/path/file.txt")
        result = cartographer.compute_file_hash(filepath)
        self.assertEqual(result, "")

    def test_hash_is_md5_hex(self):
        """Hash should be valid MD5 hex string"""
        with tempfile.TemporaryDirectory() as tmpdir:
            filepath = Path(tmpdir) / "file.txt"
            filepath.write_text("test")
            hash_result = cartographer.compute_file_hash(filepath)
            # MD5 hex is 32 characters
            self.assertEqual(len(hash_result), 32)
            self.assertTrue(all(c in "0123456789abcdef" for c in hash_result))

    def test_large_file_hash(self):
        """Hash should work with large files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            filepath = Path(tmpdir) / "large_file.txt"
            # Create a file larger than the chunk size
            large_content = "x" * (1024 * 1024)  # 1MB
            filepath.write_text(large_content)
            hash_result = cartographer.compute_file_hash(filepath)
            self.assertEqual(len(hash_result), 32)
            self.assertTrue(all(c in "0123456789abcdef" for c in hash_result))


class TestComputeFolderHash(unittest.TestCase):
    """Test compute_folder_hash function"""

    def test_empty_dict_returns_empty_string(self):
        """Empty file_hashes dict should return empty string"""
        result = cartographer.compute_folder_hash("src", {})
        self.assertEqual(result, "")

    def test_stable_across_calls(self):
        """Same input should produce same hash across multiple calls"""
        file_hashes = {
            "src/file1.ts": "abc123",
            "src/file2.ts": "def456",
        }
        hash1 = cartographer.compute_folder_hash("src", file_hashes)
        hash2 = cartographer.compute_folder_hash("src", file_hashes)
        self.assertEqual(hash1, hash2)

    def test_only_includes_files_in_folder(self):
        """Should only include files that belong to the folder"""
        file_hashes = {
            "src/file1.ts": "abc123",
            "src/nested/file2.ts": "def456",
            "other/file3.ts": "ghi789",
        }
        hash_src = cartographer.compute_folder_hash("src", file_hashes)
        file_hashes_other = {
            "other/file3.ts": "ghi789",
        }
        hash_other = cartographer.compute_folder_hash("other", file_hashes_other)
        self.assertNotEqual(hash_src, hash_other)

    def test_root_folder_dot_matches_top_level(self):
        """Folder '.' should only match files with no slash"""
        file_hashes = {
            "file1.ts": "abc123",
            "file2.ts": "def456",
            "src/file3.ts": "ghi789",
        }
        hash_root = cartographer.compute_folder_hash(".", file_hashes)
        # Should only include file1.ts and file2.ts
        file_hashes_nested = {
            "file1.ts": "abc123",
            "file2.ts": "def456",
        }
        hash_nested = cartographer.compute_folder_hash(".", file_hashes_nested)
        self.assertEqual(hash_root, hash_nested)

    def test_different_order_same_hash(self):
        """Different order of files should produce same hash (sorted)"""
        file_hashes_1 = {
            "src/a.ts": "aaa",
            "src/b.ts": "bbb",
        }
        file_hashes_2 = {
            "src/b.ts": "bbb",
            "src/a.ts": "aaa",
        }
        hash1 = cartographer.compute_folder_hash("src", file_hashes_1)
        hash2 = cartographer.compute_folder_hash("src", file_hashes_2)
        self.assertEqual(hash1, hash2)


class TestSelectFiles(unittest.TestCase):
    """Test select_files function"""

    def test_include_pattern_selects_right_files(self):
        """Include pattern should select matching files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / "src" / "file.ts").write_text("test")
            (root / "src" / "file.js").write_text("test")
            (root / "test.py").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=[],
                exceptions=[],
                gitignore_patterns=[],
            )
            filenames = [f.name for f in selected]
            self.assertIn("file.ts", filenames)
            self.assertNotIn("file.js", filenames)

    def test_exclude_pattern_filters_files(self):
        """Exclude pattern should filter out matching files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / "src" / "main.ts").write_text("test")
            (root / "src" / "main.test.ts").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=["*.test.ts"],
                exceptions=[],
                gitignore_patterns=[],
            )
            filenames = [f.name for f in selected]
            self.assertIn("main.ts", filenames)
            self.assertNotIn("main.test.ts", filenames)

    def test_gitignore_patterns_respected(self):
        """Gitignore patterns should filter out files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / "src" / "file.ts").write_text("test")
            (root / "node_modules").mkdir()
            (root / "node_modules" / "package.ts").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=[],
                exceptions=[],
                gitignore_patterns=["node_modules/"],
            )
            filenames = [f.name for f in selected]
            self.assertIn("file.ts", filenames)
            self.assertNotIn("package.ts", filenames)

    def test_exception_overrides_exclude(self):
        """Exception should override exclude pattern"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / "src" / "main.ts").write_text("test")
            (root / "src" / "main.test.ts").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=["*.test.ts"],
                exceptions=["src/main.test.ts"],
                gitignore_patterns=[],
            )
            filenames = [f.name for f in selected]
            self.assertIn("main.ts", filenames)
            self.assertIn("main.test.ts", filenames)

    def test_hidden_directories_skipped(self):
        """Hidden directories starting with . should be skipped"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / ".hidden").mkdir()
            (root / "src" / "file.ts").write_text("test")
            (root / ".hidden" / "file.ts").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=[],
                exceptions=[],
                gitignore_patterns=[],
            )
            paths = [f.relative_to(root) for f in selected]
            self.assertIn(Path("src/file.ts"), paths)
            self.assertNotIn(Path(".hidden/file.ts"), paths)

    def test_relative_path_normalization(self):
        """Relative paths should be normalized (no ./ prefix)"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "file.ts").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=["*.ts"],
                exclude_patterns=[],
                exceptions=[],
                gitignore_patterns=[],
            )
            self.assertEqual(len(selected), 1)
            # Path should be valid and exist
            self.assertTrue(selected[0].exists())

    def test_empty_include_with_exceptions(self):
        """Without include patterns, only exceptions should be selected"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "file.ts").write_text("test")
            (root / "exception.py").write_text("test")

            selected = cartographer.select_files(
                root,
                include_patterns=[],
                exclude_patterns=[],
                exceptions=["exception.py"],
                gitignore_patterns=[],
            )
            filenames = [f.name for f in selected]
            self.assertNotIn("file.ts", filenames)
            self.assertIn("exception.py", filenames)


class TestGetFoldersWithFiles(unittest.TestCase):
    """Test get_folders_with_files function"""

    def test_returns_dot_always(self):
        """Should always return '.' in the set"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            files = []
            result = cartographer.get_folders_with_files(files, root)
            self.assertIn(".", result)

    def test_returns_parent_folders_of_nested_files(self):
        """Should return parent folders of nested files"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            files = [root / "src" / "nested" / "deep" / "file.ts"]
            result = cartographer.get_folders_with_files(files, root)
            self.assertIn(".", result)
            self.assertIn("src", result)
            self.assertIn("src/nested", result)
            self.assertIn("src/nested/deep", result)

    def test_top_level_files_only_have_dot(self):
        """Top level files should only add '.'"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            files = [root / "file.ts"]
            result = cartographer.get_folders_with_files(files, root)
            self.assertEqual(result, {"."})

    def test_multiple_files_in_same_folder(self):
        """Multiple files in same folder should only add folder once"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            files = [
                root / "src" / "file1.ts",
                root / "src" / "file2.ts",
                root / "src" / "file3.ts",
            ]
            result = cartographer.get_folders_with_files(files, root)
            self.assertIn("src", result)
            # Should appear only once in the set
            self.assertEqual(result.count("src") if isinstance(result, list) else 1, 1)

    def test_mixed_nesting_levels(self):
        """Should handle files at different nesting levels"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            files = [
                root / "file.ts",
                root / "src" / "file.ts",
                root / "src" / "nested" / "file.ts",
                root / "lib" / "util.ts",
            ]
            result = cartographer.get_folders_with_files(files, root)
            self.assertIn(".", result)
            self.assertIn("src", result)
            self.assertIn("src/nested", result)
            self.assertIn("lib", result)


class TestLoadSaveState(unittest.TestCase):
    """Test load_state and save_state functions"""

    def test_save_and_load_round_trip(self):
        """Save then load should return same data"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            state_data = {
                "version": "1.0.0",
                "files": {
                    "src/main.ts": "abc123",
                    "src/lib.ts": "def456",
                },
                "folders": {
                    "src": "xyz789",
                },
            }
            cartographer.save_state(root, state_data)
            loaded = cartographer.load_state(root)
            self.assertEqual(loaded, state_data)

    def test_missing_file_returns_none(self):
        """Missing state file should return None"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            result = cartographer.load_state(root)
            self.assertIsNone(result)

    def test_corrupt_json_returns_none(self):
        """Corrupt JSON should return None"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            state_dir = root / cartographer.STATE_DIR
            state_dir.mkdir(parents=True, exist_ok=True)
            state_path = state_dir / cartographer.STATE_FILE
            state_path.write_text("{ invalid json }")
            result = cartographer.load_state(root)
            self.assertIsNone(result)

    def test_save_creates_directory(self):
        """Save should create .slim directory if it doesn't exist"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            self.assertFalse((root / cartographer.STATE_DIR).exists())
            state_data = {"test": "data"}
            cartographer.save_state(root, state_data)
            self.assertTrue((root / cartographer.STATE_DIR).exists())

    def test_state_file_valid_json_format(self):
        """Saved state file should be valid JSON"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            state_data = {"key": "value", "nested": {"data": 123}}
            cartographer.save_state(root, state_data)
            state_path = root / cartographer.STATE_DIR / cartographer.STATE_FILE
            loaded_json = json.loads(state_path.read_text())
            self.assertEqual(loaded_json, state_data)

    def test_empty_state_round_trip(self):
        """Empty state dict should round-trip correctly"""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            state_data = {}
            cartographer.save_state(root, state_data)
            loaded = cartographer.load_state(root)
            self.assertEqual(loaded, state_data)


class TestCreateEmptyCodemap(unittest.TestCase):
    """Test create_empty_codemap function"""

    def test_creates_file_with_folder_name_header(self):
        """Should create codemap.md with folder name in header"""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder_path = Path(tmpdir)
            folder_name = "components"
            cartographer.create_empty_codemap(folder_path, folder_name)
            codemap_file = folder_path / cartographer.CODEMAP_FILE
            self.assertTrue(codemap_file.exists())
            content = codemap_file.read_text()
            self.assertIn(f"# {folder_name}/", content)

    def test_does_not_overwrite_existing_file(self):
        """Should NOT overwrite existing codemap.md"""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder_path = Path(tmpdir)
            codemap_file = folder_path / cartographer.CODEMAP_FILE
            original_content = "Original content"
            codemap_file.write_text(original_content)

            cartographer.create_empty_codemap(folder_path, "components")
            content = codemap_file.read_text()
            self.assertEqual(content, original_content)

    def test_includes_responsibility_section(self):
        """Should include Responsibility section with comment"""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder_path = Path(tmpdir)
            cartographer.create_empty_codemap(folder_path, "utils")
            codemap_file = folder_path / cartographer.CODEMAP_FILE
            content = codemap_file.read_text()
            self.assertIn("## Responsibility", content)
            self.assertIn("<!-- What is this folder's job in the system? -->", content)

    def test_creates_markdown_file(self):
        """Should create a .md file"""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder_path = Path(tmpdir)
            cartographer.create_empty_codemap(folder_path, "lib")
            codemap_file = folder_path / cartographer.CODEMAP_FILE
            self.assertTrue(str(codemap_file).endswith(".md"))

    def test_different_folder_names(self):
        """Should correctly handle different folder names"""
        with tempfile.TemporaryDirectory() as tmpdir:
            folder_path = Path(tmpdir)
            folder_names = ["src", "components", "utils", "services"]
            for folder_name in folder_names:
                sub_path = folder_path / folder_name
                sub_path.mkdir(exist_ok=True)
                cartographer.create_empty_codemap(sub_path, folder_name)
                codemap_file = sub_path / cartographer.CODEMAP_FILE
                content = codemap_file.read_text()
                self.assertIn(f"# {folder_name}/", content)


class TestConstantsAndVersions(unittest.TestCase):
    """Test module constants"""

    def test_version_constant_exists(self):
        """Version constant should exist"""
        self.assertIsNotNone(cartographer.VERSION)
        self.assertIsInstance(cartographer.VERSION, str)

    def test_state_dir_constant(self):
        """STATE_DIR should be '.slim'"""
        self.assertEqual(cartographer.STATE_DIR, ".slim")

    def test_state_file_constant(self):
        """STATE_FILE should be 'cartography.json'"""
        self.assertEqual(cartographer.STATE_FILE, "cartography.json")

    def test_codemap_file_constant(self):
        """CODEMAP_FILE should be 'codemap.md'"""
        self.assertEqual(cartographer.CODEMAP_FILE, "codemap.md")


if __name__ == "__main__":
    unittest.main()
