"""Offline test runner for NewbieNudge.

Runs every tests/test_*.lua file inside a fresh LuaJIT runtime (via lupa),
after loading tests/wow_stub.lua (fake WoW API) and tests/helpers.lua.
Also checks that the enUS and esES locale files define the same keys.

Usage: python tests/run.py [substring-filter]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "pylib"))

try:
    import lupa.luajit21 as lupa  # Lua 5.1 semantics, same as the game client
except ImportError:  # pragma: no cover
    try:
        import lupa.lua51 as lupa
    except ImportError:
        sys.exit("lupa is not installed: python -m pip install --target tools/pylib -r tools/requirements.txt")

TESTS_DIR = os.path.join(ROOT, "tests").replace("\\", "/")
ADDON_DIR = os.path.join(ROOT, "NewbieNudge").replace("\\", "/")
STUB = TESTS_DIR + "/wow_stub.lua"
HELPERS = TESTS_DIR + "/helpers.lua"


def new_runtime():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ADDON_DIR = ADDON_DIR
    g.TESTS_DIR = TESTS_DIR
    lua.execute('assert(loadfile("%s"))()' % STUB)
    lua.execute('assert(loadfile("%s"))()' % HELPERS)
    return lua


def test_names(path):
    lua = new_runtime()
    tbl = lua.execute('return assert(loadfile("%s"))()' % path)
    return sorted(str(k) for k in tbl.keys())


def run_test(path, name):
    lua = new_runtime()
    try:
        lua.execute('local t = assert(loadfile("%s"))(); t["%s"]()' % (path, name))
        return None
    except Exception as exc:  # LuaError or Python error from inside Lua
        return str(exc).strip().splitlines()[0] if str(exc).strip() else repr(exc)


def locale_parity():
    en = os.path.join(ADDON_DIR, "Locales", "enUS.lua")
    es = os.path.join(ADDON_DIR, "Locales", "esES.lua")
    if not (os.path.exists(en) and os.path.exists(es)):
        return None
    key_re = re.compile(r"^\s*([A-Z][A-Z0-9_]+)\s*=", re.M)
    with open(en, encoding="utf-8") as f:
        en_keys = set(key_re.findall(f.read()))
    with open(es, encoding="utf-8") as f:
        es_keys = set(key_re.findall(f.read()))
    missing_es = sorted(en_keys - es_keys)
    missing_en = sorted(es_keys - en_keys)
    if missing_es or missing_en:
        return "missing in esES: %s; missing in enUS: %s" % (missing_es, missing_en)
    return ""


def main(argv):
    pattern = argv[1] if len(argv) > 1 else ""
    passed = failed = 0
    files = sorted(f for f in os.listdir(TESTS_DIR) if f.startswith("test_") and f.endswith(".lua"))
    for fname in files:
        if pattern and pattern not in fname:
            continue
        path = TESTS_DIR + "/" + fname
        try:
            names = test_names(path)
        except Exception as exc:
            print("FAIL %s::<load>: %s" % (fname, str(exc).strip().splitlines()[0]))
            failed += 1
            continue
        for name in names:
            err = run_test(path, name)
            if err is None:
                print("PASS %s::%s" % (fname, name))
                passed += 1
            else:
                print("FAIL %s::%s: %s" % (fname, name, err))
                failed += 1
    if not pattern or "locale" in pattern:
        parity = locale_parity()
        if parity is None:
            pass
        elif parity == "":
            print("PASS locales::parity")
            passed += 1
        else:
            print("FAIL locales::parity: " + parity)
            failed += 1
    print("%d passed, %d failed" % (passed, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
