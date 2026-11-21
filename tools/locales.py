"""Locale tools for NewbieNudge.

    python tools/locales.py check              parity of every Locales/*.lua against enUS
    python tools/locales.py new <code> [Name]  write Locales/<code>.lua as a template to translate
    python tools/locales.py sort <code>        reorder Locales/<code>.lua to enUS's sections and key order

Locale files are pure data: `NN.RegisterLocale("<code>", { KEY = "text", ... })`
with `-- Section` comments. English (enUS) is the reference; every other file
must define exactly the same keys. `check` exits 1 on any difference and is
also run by tests/run.py.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = os.path.join(ROOT, "NewbieNudge", "Locales")
BASE = "enUS"

KEY_RE = re.compile(r'^\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*"((?:[^"\\]|\\.)*)"\s*,\s*$')
SECTION_RE = re.compile(r"^\s*--\s*(.+?)\s*$")
HEADER_END_RE = re.compile(r"^\s*NN\.RegisterLocale\(")

LANGUAGE_NAMES = {
    "enUS": "English", "esES": "Spanish (Spain)", "esMX": "Spanish (Latin America)", "frFR": "French",
    "deDE": "German", "itIT": "Italian", "ptBR": "Portuguese (Brazil)", "ruRU": "Russian",
    "koKR": "Korean", "zhCN": "Chinese (Simplified)", "zhTW": "Chinese (Traditional)",
}


def parse(path):
    """Returns (sections, entries): sections = [(name, [key, ...])], entries = {key: raw_value}."""
    sections, entries = [], {}
    current = ("(no section)", [])
    sections.append(current)
    in_table = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not in_table:
                if HEADER_END_RE.match(line):
                    in_table = True
                continue
            m = KEY_RE.match(line)
            if m:
                key, value = m.group(1), m.group(2)
                entries[key] = value
                current[1].append(key)
                continue
            s = SECTION_RE.match(line)
            if s and not line.strip().startswith("--[["):
                current = (s.group(1), [])
                sections.append(current)
    sections = [sec for sec in sections if sec[1]]
    return sections, entries


def locale_files():
    return sorted(f[:-4] for f in os.listdir(LOCALES) if f.endswith(".lua") and f != "Loader.lua")


def render(code, sections, values, name=None, template_from=None):
    """Writes a locale file from sections (enUS order) and a values dict."""
    name = name or LANGUAGE_NAMES.get(code, code)
    lines = []
    if code == BASE:
        lines.append("-- English (enUS). The reference language: every other Locales file must")
        lines.append("-- define exactly the same keys, in the same sections. Loads for every client")
        lines.append("-- and is the fallback for untranslated keys.")
    else:
        lines.append("-- %s (%s). Pure data: translate the values, keep the keys." % (name, code))
        lines.append("-- Missing keys fall back to English. Check with: python tools/locales.py check")
    lines.append("local _, NN = ...")
    lines.append("")
    lines.append('NN.RegisterLocale("%s", {' % code)
    for section, keys in sections:
        lines.append("  -- " + section)
        for key in keys:
            if key in values:
                lines.append('  %s = "%s",' % (key, values[key]))
            elif template_from is not None:
                lines.append('  %s = "%s", -- TODO translate' % (key, template_from[key]))
        lines.append("")
    if lines[-1] == "":
        lines.pop()
    lines.append("})")
    return "\n".join(lines) + "\n"


def check(argv):
    base_sections, base = parse(os.path.join(LOCALES, BASE + ".lua"))
    ok = True
    print("%s: %d keys in %d sections" % (BASE, len(base), len(base_sections)))
    for code in locale_files():
        if code == BASE:
            continue
        _, entries = parse(os.path.join(LOCALES, code + ".lua"))
        missing = sorted(set(base) - set(entries))
        extra = sorted(set(entries) - set(base))
        todo = sorted(k for k, v in entries.items() if k in base and v == base[k] and len(v) > 12)
        status = "OK" if not (missing or extra) else "MISMATCH"
        print("%s: %d keys, %s%s" % (code, len(entries), status, (", %d still English" % len(todo)) if todo else ""))
        for k in missing:
            print("  missing: " + k)
        for k in extra:
            print("  extra:   " + k)
        if missing or extra:
            ok = False
    return 0 if ok else 1


def new(argv):
    if not argv:
        print("usage: locales.py new <code> [Language name]")
        return 2
    code = argv[0]
    name = " ".join(argv[1:]) or LANGUAGE_NAMES.get(code, code)
    path = os.path.join(LOCALES, code + ".lua")
    if os.path.exists(path):
        print("exists: " + path)
        return 1
    sections, base = parse(os.path.join(LOCALES, BASE + ".lua"))
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(code, sections, {}, name, template_from=base))
    print("wrote %s (%d keys to translate). Add 'Locales\\%s.lua' to NewbieNudge.toc after enUS.lua." % (path, len(base), code))
    return 0


def sort_file(argv):
    if not argv:
        print("usage: locales.py sort <code>")
        return 2
    code = argv[0]
    path = os.path.join(LOCALES, code + ".lua")
    sections, base = parse(os.path.join(LOCALES, BASE + ".lua"))
    _, entries = parse(path)
    extra = sorted(set(entries) - set(base))
    if extra:
        sections = sections + [("Not in enUS (remove or add to enUS)", extra)]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(code, sections, entries))
    print("sorted " + path)
    return 0


def main(argv):
    if not argv or argv[0] not in ("check", "new", "sort"):
        print(__doc__)
        return 2
    return {"check": check, "new": new, "sort": sort_file}[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
