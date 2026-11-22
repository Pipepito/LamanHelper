"""Import service NPCs (repair, inn, supplies, trainers) from QuestieDB (GPL-3.0).

Downloads QuestieDB's WoW Forever NPC database and its area-to-map
conversion table from https://github.com/Questie/QuestieDB, keeps the NPCs a
new player looks for, and writes NewbieNudge/Data/Services.lua:

    NN.ServiceData = {
      npcs = { [npcID] = { name, title, uiMapID, x, y, faction }, ... },
      kinds = { repair = { npcID, ... }, inn = {...}, supplies = {...},
                weapon = {...}, trainer_MAGE = {...}, prof_182 = {...}, ... },
    }

Usage:
    python tools/import_questie_npcs.py [--ref master] [--out NewbieNudge/Data/Services.lua]

Output is deterministic: re-running against the same upstream commit on the
same day produces no diff.
"""
import argparse
import datetime
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "pylib"))

try:
    import lupa.luajit21 as lupa
except ImportError:  # pragma: no cover
    import lupa.lua51 as lupa

REPO = "Questie/QuestieDB"
SOURCE_URL = "https://github.com/" + REPO
NPC_FILE = "data/Forever/foreverNpcDB.lua"
CONVERSION_FILE = "data/Forever/conversion.json"

# cmangos classic npc flags (confirmed against the Forever data)
FLAG_VENDOR, FLAG_TRAINER, FLAG_INNKEEPER, FLAG_REPAIR = 4, 16, 128, 16384

# QuestieDB npcKeys
NAME, SPAWNS, FRIENDLY, TITLE, FLAGS = 1, 7, 13, 14, 15

SUPPLY_TITLES = {"Food & Drink", "General Goods", "General Supplies", "Baker", "Butcher"}
CLASSES = ["Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"]
# profession skill line -> words that name its trainers ("Journeyman Alchemist", "Herbalist", "Physician")
PROFESSIONS = [
    (171, ("Alchem",)),
    (164, ("Blacksmith",)),
    (333, ("Enchant",)),
    (202, ("Engineer",)),
    (182, ("Herbalis",)),
    (165, ("Leatherwork", "Leathercraft")),
    (186, ("Mining", "Miner")),
    (393, ("Skinn",)),
    (197, ("Tailor",)),
    (185, ("Cook",)),
    (129, ("First Aid", "Physician", "Trauma Surgeon")),
    (356, ("Fish",)),
]
# specialization trainers only teach their speciality
SPECIALIZATIONS = ("Goblin", "Gnome", "Dragonscale", "Elemental", "Tribal", "Shadoweave", "Mooncloth", "Spellfire")


# --------------------------------------------------------------------------
# Parse
# --------------------------------------------------------------------------

def parse_npcs(src):
    """{npcID: row-dict-by-index} from the QuestieDB npcData string.
    Rows are executed in chunks: one chunk of the whole table exceeds
    LuaJIT's 65536-constant limit."""
    start = src.index("[[") + 2
    body = src[start:src.rindex("]]")]
    rows = [line for line in body.split("\n") if line.startswith("[")]
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    npcs = {}
    for i in range(0, len(rows), 1500):
        table = lua.execute("return {" + "\n".join(rows[i:i + 1500]) + "}")
        for npc_id, row in table.items():
            npcs[int(npc_id)] = {k: row[k] for k in (NAME, SPAWNS, FRIENDLY, TITLE, FLAGS)}
    return npcs


def kinds_for(title, flags):
    title = title or ""
    out = []
    if flags & FLAG_REPAIR:
        out.append("repair")
    if flags & FLAG_INNKEEPER and title == "Innkeeper":
        out.append("inn")
    if flags & FLAG_VENDOR and title in SUPPLY_TITLES:
        out.append("supplies")
    if flags & FLAG_TRAINER:
        if title == "Weapon Master":
            out.append("weapon")
        for cls in CLASSES:
            if title == cls + " Trainer":
                out.append("trainer_" + cls.upper())
        if not any(word in title for word in SPECIALIZATIONS):
            for skill_line, words in PROFESSIONS:
                if any(word in title for word in words):
                    out.append("prof_%d" % skill_line)
    return out


def extract(npc_src, conversion):
    """{"npcs": {id: (name, title, map, x, y, faction)}, "kinds": {kind: [ids]}}."""
    area_to_map = {t["area_id"]: t["ui_map_id"] for t in conversion["geometry"]["transforms"]}
    npcs, kinds = {}, {}
    for npc_id, row in sorted(parse_npcs(npc_src).items()):
        faction = row[FRIENDLY]
        if not faction:
            continue
        found = kinds_for(row[TITLE], row[FLAGS] or 0)
        if not found or not row[SPAWNS]:
            continue
        spawn = None
        for area in sorted(int(a) for a in row[SPAWNS].keys()):
            coords = row[SPAWNS][area]
            if area in area_to_map and coords and coords[1]:
                spawn = (area_to_map[area], float(coords[1][1]), float(coords[1][2]))
                break
        if not spawn:
            continue
        npcs[npc_id] = (row[NAME], row[TITLE] or "", spawn[0], spawn[1], spawn[2], faction)
        for kind in found:
            kinds.setdefault(kind, []).append(npc_id)
    return {"npcs": npcs, "kinds": kinds}


# --------------------------------------------------------------------------
# Render
# --------------------------------------------------------------------------

def _lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _num(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def transform(npc_src, conversion, commit="unknown", date=None):
    date = date or datetime.date.today().isoformat()
    data = extract(npc_src, conversion)
    lines = [
        "-- Generated by tools/import_questie_npcs.py on %s. Do not edit by hand." % date,
        "-- Source: %s (%s), file %s" % (SOURCE_URL, commit, NPC_FILE),
        "-- Licence: GPL-3.0, see LICENSE. Data (c) the Questie / QuestieDB authors.",
        "-- npcs[id] = { name, title, uiMapID, x, y, faction (A, H or AH) }",
        "local _, NN = ...",
        "NN.ServiceData = {",
        "  npcs = {",
    ]
    for npc_id, (name, title, ui_map, x, y, faction) in sorted(data["npcs"].items()):
        lines.append("    [%d] = { %s, %s, %d, %s, %s, %s }," % (
            npc_id, _lua_str(name), _lua_str(title), ui_map, _num(x), _num(y), _lua_str(faction)))
    lines += ["  },", "  kinds = {"]
    for kind in sorted(data["kinds"]):
        lines.append("    %s = { %s }," % (kind, ", ".join(str(i) for i in data["kinds"][kind])))
    lines += ["  },", "}"]
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------
# Download and write
# --------------------------------------------------------------------------

def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "NewbieNudge-import/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("utf-8")


def resolve_commit(ref):
    data = json.loads(_get("https://api.github.com/repos/%s/commits/%s" % (REPO, ref)))
    return data["sha"]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ref", default="master", help="branch, tag or commit (default: master)")
    parser.add_argument("--out", default=os.path.join("NewbieNudge", "Data", "Services.lua"), help="output file")
    args = parser.parse_args(argv)

    sha = resolve_commit(args.ref)
    raw = "https://raw.githubusercontent.com/%s/%s/" % (REPO, sha)
    text = transform(_get(raw + NPC_FILE), json.loads(_get(raw + CONVERSION_FILE)), commit=sha)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", args.out)
    print("source commit", sha)
    return 0


if __name__ == "__main__":
    sys.exit(main())
