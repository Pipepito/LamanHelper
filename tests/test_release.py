"""Unit tests for tools/release.py (the release workflow's helper, no network).

Run: python -m unittest tests/test_release.py -v
"""
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import release  # noqa: E402

VERSIONS = [
    {"id": 1, "gameVersionTypeID": 517, "name": "11.0.2", "slug": "11-0-2"},
    {"id": 2, "gameVersionTypeID": 88568, "name": "1.60.0", "slug": "1-60-0"},
    {"id": 3, "gameVersionTypeID": 88568, "name": "1.60.1", "slug": "1-60-1"},
    {"id": 4, "gameVersionTypeID": 88568, "name": "1.60.10", "slug": "1-60-10"},
    {"id": 5, "gameVersionTypeID": 67408, "name": "1.15.8", "slug": "1-15-8"},
]

CHANGELOG = """# Changelog

## 0.3.4 - unreleased

- Something new.

## 0.3.3 - 2026-11-21

- Bank: the bag-full window stays away from the bank.
- Developer mode.

## 0.3.2 - 2026-11-20

- Supplies rule.
"""


class Tags(unittest.TestCase):
    def test_version_from_tag_strips_the_v(self):
        self.assertEqual(release.version_from_tag("v0.3.3"), "0.3.3")
        self.assertEqual(release.version_from_tag("refs/tags/v0.3.3"), "0.3.3")
        self.assertEqual(release.version_from_tag("v0.4.0-beta1"), "0.4.0-beta1")

    def test_version_from_tag_rejects_other_shapes(self):
        for bad in ("0.3.3", "v0.3", "vfoo", "release-1"):
            with self.assertRaises(release.ReleaseError, msg=bad):
                release.version_from_tag(bad)

    def test_release_type_follows_the_tag_suffix(self):
        self.assertEqual(release.release_type("v0.3.3"), "release")
        self.assertEqual(release.release_type("v0.4.0-beta1"), "beta")
        self.assertEqual(release.release_type("v0.4.0-alpha2"), "alpha")
        self.assertEqual(release.release_type("v0.4.0-rc1"), "beta")


class GameVersions(unittest.TestCase):
    def test_interface_number_becomes_a_version_and_a_flavor(self):
        self.assertEqual(release.game_version(16001), ("1.60.1", 88568))
        self.assertEqual(release.game_version(110002), ("11.0.2", 517))
        self.assertEqual(release.game_version(11508), ("1.15.8", 67408))
        self.assertEqual(release.game_version("16001"), ("1.60.1", 88568))

    def test_exact_version_id_is_picked_within_the_flavor(self):
        ids, note = release.pick_game_version_ids(VERSIONS, "1.60.1", 88568)
        self.assertEqual(ids, [3])
        self.assertIsNone(note)

    def test_unknown_version_falls_back_to_the_newest_of_the_flavor(self):
        ids, note = release.pick_game_version_ids(VERSIONS, "1.60.2", 88568)
        self.assertEqual(ids, [4], "1.60.10 is newer than 1.60.1 by version order, not text order")
        self.assertIn("1.60.2", note)
        self.assertIn("1.60.10", note)

    def test_flavor_without_versions_is_an_error(self):
        with self.assertRaises(release.ReleaseError):
            release.pick_game_version_ids(VERSIONS, "1.0.0", 99999)


class Changelog(unittest.TestCase):
    def test_section_for_a_version_is_its_body_only(self):
        body = release.changelog_section(CHANGELOG, "0.3.3")
        self.assertEqual(body, "- Bank: the bag-full window stays away from the bank.\n- Developer mode.")

    def test_missing_section_is_an_error(self):
        with self.assertRaises(release.ReleaseError):
            release.changelog_section(CHANGELOG, "0.9.9")

    def test_unreleased_section_is_an_error(self):
        with self.assertRaises(release.ReleaseError):
            release.changelog_section(CHANGELOG, "0.3.4")


class Metadata(unittest.TestCase):
    def test_curseforge_metadata_shape(self):
        meta = release.curseforge_metadata("v0.3.3", "- notes", [3])
        self.assertEqual(meta, {
            "displayName": "NewbieNudge 0.3.3",
            "gameVersions": [3],
            "releaseType": "release",
            "changelog": "- notes",
            "changelogType": "markdown",
        })


class Repo(unittest.TestCase):
    """A throwaway copy of the repo layout: TOC, changelog and an addon folder."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        addon = os.path.join(self.tmp, "NewbieNudge")
        os.makedirs(os.path.join(addon, "Locales"))
        os.makedirs(os.path.join(addon, "__pycache__"))
        self.toc = os.path.join(addon, "NewbieNudge.toc")
        with open(self.toc, "w", encoding="utf-8") as f:
            f.write("## Interface: 16001\n## Title: NewbieNudge\n## Version: 0.3.3\n## X-Curse-Project-ID: 123456\n\nCore.lua\n")
        with open(os.path.join(addon, "Core.lua"), "w") as f:
            f.write("-- core\n")
        with open(os.path.join(addon, "Locales", "enUS.lua"), "w") as f:
            f.write("-- en\n")
        with open(os.path.join(addon, "__pycache__", "x.pyc"), "wb") as f:
            f.write(b"\0")
        with open(os.path.join(addon, "stray.zip"), "wb") as f:
            f.write(b"\0")
        with open(os.path.join(self.tmp, "CHANGELOG.md"), "w", encoding="utf-8") as f:
            f.write(CHANGELOG)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_read_toc_fields(self):
        toc = release.read_toc(self.toc)
        self.assertEqual(toc["Version"], "0.3.3")
        self.assertEqual(toc["Interface"], "16001")
        self.assertEqual(toc["X-Curse-Project-ID"], "123456")

    def test_build_zip_has_the_addon_folder_at_the_top_and_no_junk(self):
        path = release.build_zip(self.tmp, os.path.join(self.tmp, "dist"))
        self.assertEqual(os.path.basename(path), "NewbieNudge-0.3.3.zip")
        with zipfile.ZipFile(path) as z:
            names = sorted(z.namelist())
        self.assertEqual(names, ["NewbieNudge/Core.lua", "NewbieNudge/Locales/enUS.lua", "NewbieNudge/NewbieNudge.toc"])

    def test_check_prints_outputs_for_a_matching_tag(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = release.main(["check", "v0.3.3", "--root", self.tmp])
        self.assertEqual(code, 0, out.getvalue())
        lines = dict(line.split("=", 1) for line in out.getvalue().strip().splitlines())
        self.assertEqual(lines["version"], "0.3.3")
        self.assertEqual(lines["zip_name"], "NewbieNudge-0.3.3.zip")
        self.assertEqual(lines["project_id"], "123456")
        self.assertEqual(lines["game_version"], "1.60.1")
        self.assertEqual(lines["release_type"], "release")

    def test_check_fails_when_the_toc_version_differs_from_the_tag(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = release.main(["check", "v0.3.4", "--root", self.tmp])
        self.assertNotEqual(code, 0)
        self.assertIn("0.3.4", out.getvalue())
        self.assertIn("0.3.3", out.getvalue())

    def test_check_fails_without_a_project_id(self):
        with open(self.toc, "w", encoding="utf-8") as f:
            f.write("## Interface: 16001\n## Version: 0.3.3\n")
        out = io.StringIO()
        with redirect_stdout(out):
            code = release.main(["check", "v0.3.3", "--root", self.tmp])
        self.assertNotEqual(code, 0)
        self.assertIn("X-Curse-Project-ID", out.getvalue())

    def test_check_fails_on_the_placeholder_project_id(self):
        with open(self.toc, "w", encoding="utf-8") as f:
            f.write("## Interface: 16001\n## Version: 0.3.3\n## X-Curse-Project-ID: 0\n")
        out = io.StringIO()
        with redirect_stdout(out):
            code = release.main(["check", "v0.3.3", "--root", self.tmp])
        self.assertNotEqual(code, 0)
        self.assertIn("X-Curse-Project-ID", out.getvalue())

    def test_notes_writes_the_changelog_section(self):
        dest = os.path.join(self.tmp, "notes.md")
        code = release.main(["notes", "v0.3.3", "--root", self.tmp, "--out", dest])
        self.assertEqual(code, 0)
        with open(dest, encoding="utf-8") as f:
            self.assertEqual(f.read(), "- Bank: the bag-full window stays away from the bank.\n- Developer mode.\n")

    def test_metadata_command_reads_the_versions_file(self):
        versions = os.path.join(self.tmp, "versions.json")
        with open(versions, "w") as f:
            json.dump(VERSIONS, f)
        dest = os.path.join(self.tmp, "metadata.json")
        out = io.StringIO()
        with redirect_stdout(out):
            code = release.main(["cf-metadata", "v0.3.3", "--root", self.tmp, "--versions", versions, "--out", dest])
        self.assertEqual(code, 0, out.getvalue())
        with open(dest, encoding="utf-8") as f:
            meta = json.load(f)
        self.assertEqual(meta["gameVersions"], [3])
        self.assertEqual(meta["displayName"], "NewbieNudge 0.3.3")
        self.assertIn("Developer mode", meta["changelog"])


if __name__ == "__main__":
    unittest.main()
