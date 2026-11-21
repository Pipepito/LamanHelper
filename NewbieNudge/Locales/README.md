# Translating NewbieNudge

Every language is one file in this folder. The files are pure data: a list of
`KEY = "text"` pairs grouped under `-- Section` comments, handed to
`NN.RegisterLocale`. `Loader.lua` picks the file for the game client's
language, with English (`enUS.lua`) always underneath, so anything a file
leaves out shows in English rather than breaking.

## Add a language

1. From the repository root:

   ```powershell
   python tools/locales.py new frFR French
   ```

   This writes `Locales/frFR.lua` with every key, each holding the English
   text and a `-- TODO translate` mark.
2. Translate the values. Keep the keys, the quotes and the `%s` / `%d`
   placeholders in the same order; `\"` is a quote inside a text and `|c…|r`
   is a colour code the game understands.
3. Add the file to `NewbieNudge.toc` after `Locales\enUS.lua`.
4. Check it:

   ```powershell
   python tools/locales.py check
   ```

   It lists missing or extra keys and how many values are still English. The
   test suite (`python tests/run.py`) runs the same check.

Client locale codes: `enUS`, `enGB`, `esES`, `esMX`, `frFR`, `deDE`, `itIT`,
`ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`. `Loader.lua` maps `enGB` to English,
`esMX` to Spanish (Spain) and `ptPT` to `ptBR`; add a line to its `FALLBACK`
table if a new language should serve another region too.

## Keep files in step

New strings go into `enUS.lua` first, in the section they belong to, then into
every other file in the same section. `python tools/locales.py sort <code>`
rewrites a file into enUS's section and key order if it drifted.

## Style

Second person, plain words, short sentences, no jargon the game itself does
not use. Spell, item, zone and NPC names never go in these files: the addon
takes them from the game in the player's language.
