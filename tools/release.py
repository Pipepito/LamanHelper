"""Release helper for the GitHub Actions workflow (.github/workflows/release.yml).

The addon lives in the NewbieNudge/ subfolder, so the generic WoW packagers do
not fit; this script does the few things a release needs and nothing else:

  python tools/release.py check v0.3.3          # tag, TOC and changelog agree; prints key=value outputs
  python tools/release.py build                 # dist/NewbieNudge-<version>.zip from NewbieNudge/
  python tools/release.py notes v0.3.3 --out f  # the CHANGELOG.md section for the version
  python tools/release.py cf-metadata v0.3.3 --versions versions.json --out metadata.json

The CurseForge upload itself is two curl calls in the workflow (versions
list, then multipart upload); the game version comes from the TOC's
## Interface number the same way the BigWigs packager derives it.

Version numbers in the TOC are written by hand; the tag has to match them,
which `check` enforces so a mistyped tag never ships a wrongly labelled zip.
"""
import argparse
import json
import os
import re
import sys
import zipfile

ADDON = "NewbieNudge"
# CurseForge gameVersionTypeID per five-digit TOC interface pattern, as the
# BigWigs packager maps them (11??? classic, 16??? forever, 2???? bcc, 3????
# wrath, 380?? titan, 4???? cata, 5???? mists); six digits are retail.
FLAVOR_PATTERNS = (("380", 81212), ("11", 67408), ("16", 88568), ("2", 73246), ("3", 73713), ("4", 77522), ("5", 79434))
RETAIL_TYPE_ID = 517
ZIP_SKIP_DIRS = {"__pycache__"}
ZIP_SKIP_SUFFIXES = (".zip", ".pyc", ".DS_Store")


class ReleaseError(Exception):
    pass


# -- tags ---------------------------------------------------------------------

TAG_RE = re.compile(r"^v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$")


def version_from_tag(tag):
    tag = tag.rsplit("/", 1)[-1]
    m = TAG_RE.match(tag)
    if not m:
        raise ReleaseError("tag %r is not of the form vMAJOR.MINOR.PATCH[-suffix]" % tag)
    return m.group(1)


def release_type(tag):
    version = version_from_tag(tag).lower()
    if "alpha" in version:
        return "alpha"
    if "beta" in version or "rc" in version:
        return "beta"
    return "release"


# -- TOC ----------------------------------------------------------------------

def read_toc(path):
    fields = {}
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            m = re.match(r"^##\s*([^:]+?)\s*:\s*(.*?)\s*$", line)
            if m:
                fields[m.group(1)] = m.group(2)
    return fields


def game_version(interface):
    """TOC interface number -> (CurseForge version name, gameVersionTypeID)."""
    s = str(interface).strip()
    if not s.isdigit() or len(s) < 5:
        raise ReleaseError("interface %r is not a 5+ digit number" % interface)
    name = "%d.%d.%d" % (int(s[:-4]), int(s[-4:-2]), int(s[-2:]))
    type_id = RETAIL_TYPE_ID
    if len(s) == 5:
        for prefix, candidate in FLAVOR_PATTERNS:
            if s.startswith(prefix):
                type_id = candidate
                break
    return name, type_id


def _version_key(name):
    return tuple(int(p) if p.isdigit() else -1 for p in name.split("."))


def pick_game_version_ids(versions, name, type_id):
    """IDs to send: the exact version within the flavor, else the flavor's newest."""
    flavor = [v for v in versions if v.get("gameVersionTypeID") == type_id]
    if not flavor:
        raise ReleaseError("CurseForge lists no game versions for type %s" % type_id)
    exact = [v for v in flavor if v.get("name") == name]
    if exact:
        return [exact[0]["id"]], None
    newest = max(flavor, key=lambda v: _version_key(v.get("name", "")))
    note = "CurseForge does not list %s yet; tagging the newest of its flavor, %s" % (name, newest["name"])
    return [newest["id"]], note


# -- changelog ----------------------------------------------------------------

def changelog_section(text, version):
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        m = re.match(r"^##\s+(\S+)\s*(.*)$", line)
        if m and m.group(1) == version:
            if "unreleased" in m.group(2).lower():
                raise ReleaseError("CHANGELOG.md still marks %s as unreleased" % version)
            start = i + 1
            break
    if start is None:
        raise ReleaseError("CHANGELOG.md has no '## %s' section" % version)
    end = len(lines)
    for j in range(start, len(lines)):
        if lines[j].startswith("## "):
            end = j
            break
    return "\n".join(lines[start:end]).strip()


# -- zip ----------------------------------------------------------------------

def build_zip(root, dest_dir):
    toc = read_toc(os.path.join(root, ADDON, ADDON + ".toc"))
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, "%s-%s.zip" % (ADDON, toc["Version"]))
    src = os.path.join(root, ADDON)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirnames, filenames in os.walk(src):
            dirnames[:] = sorted(d for d in dirnames if d not in ZIP_SKIP_DIRS and not d.startswith("."))
            for name in sorted(filenames):
                if name.endswith(ZIP_SKIP_SUFFIXES) or name.startswith("."):
                    continue
                full = os.path.join(dirpath, name)
                arc = os.path.relpath(full, root).replace(os.sep, "/")
                z.write(full, arc)
    return path


# -- metadata -----------------------------------------------------------------

def curseforge_metadata(tag, changelog, version_ids):
    return {
        "displayName": "%s %s" % (ADDON, version_from_tag(tag)),
        "gameVersions": list(version_ids),
        "releaseType": release_type(tag),
        "changelog": changelog,
        "changelogType": "markdown",
    }


# -- commands -----------------------------------------------------------------

def _context(root, tag):
    version = version_from_tag(tag)
    toc = read_toc(os.path.join(root, ADDON, ADDON + ".toc"))
    if toc.get("Version") != version:
        raise ReleaseError("tag %s says %s but the TOC says ## Version: %s" % (tag, version, toc.get("Version")))
    project_id = toc.get("X-Curse-Project-ID", "")
    if not project_id.isdigit() or int(project_id) == 0:
        raise ReleaseError("the TOC needs a real numeric ## X-Curse-Project-ID line (0 is the placeholder)")
    with open(os.path.join(root, "CHANGELOG.md"), encoding="utf-8") as f:
        notes = changelog_section(f.read(), version)
    name, type_id = game_version(toc.get("Interface", ""))
    return {"version": version, "toc": toc, "notes": notes, "game_version": name, "type_id": type_id}


def cmd_check(args):
    ctx = _context(args.root, args.tag)
    for key, value in (
        ("version", ctx["version"]),
        ("zip_name", "%s-%s.zip" % (ADDON, ctx["version"])),
        ("project_id", ctx["toc"]["X-Curse-Project-ID"]),
        ("game_version", ctx["game_version"]),
        ("game_version_type", ctx["type_id"]),
        ("release_type", release_type(args.tag)),
    ):
        print("%s=%s" % (key, value))
    return 0


def cmd_build(args):
    print(build_zip(args.root, args.dest))
    return 0


def cmd_notes(args):
    ctx = _context(args.root, args.tag)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(ctx["notes"] + "\n")
    return 0


def cmd_cf_metadata(args):
    ctx = _context(args.root, args.tag)
    with open(args.versions, encoding="utf-8") as f:
        versions = json.load(f)
    ids, note = pick_game_version_ids(versions, ctx["game_version"], ctx["type_id"])
    if note:
        print("warning: " + note)
    meta = curseforge_metadata(args.tag, ctx["notes"], ids)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=2)
    print("game version ids %s" % ids)
    return 0


def main(argv):
    default_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("check"); p.add_argument("tag"); p.add_argument("--root", default=default_root); p.set_defaults(fn=cmd_check)
    p = sub.add_parser("build"); p.add_argument("--root", default=default_root); p.add_argument("--dest"); p.set_defaults(fn=cmd_build)
    p = sub.add_parser("notes"); p.add_argument("tag"); p.add_argument("--root", default=default_root); p.add_argument("--out", required=True); p.set_defaults(fn=cmd_notes)
    p = sub.add_parser("cf-metadata"); p.add_argument("tag"); p.add_argument("--root", default=default_root)
    p.add_argument("--versions", required=True); p.add_argument("--out", required=True); p.set_defaults(fn=cmd_cf_metadata)

    args = parser.parse_args(argv)
    if getattr(args, "dest", None) is None and args.command == "build":
        args.dest = os.path.join(args.root, "dist")
    try:
        return args.fn(args)
    except ReleaseError as exc:
        print("release: " + str(exc))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
