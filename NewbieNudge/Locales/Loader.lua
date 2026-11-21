-- Locale loader. Loads first among the Locales files.
--
-- Every language file is pure data: it calls NN.RegisterLocale(code, table).
-- English (enUS) is the base and always applies; the file for the game
-- client's language applies on top of it, so a missing translation shows the
-- English text and a missing key shows its own name instead of erroring.
--
-- Adding a language: run  python tools/locales.py new <code>  (or copy
-- enUS.lua), translate the values, add the file to NewbieNudge.toc after
-- enUS.lua, and run  python tools/locales.py check . See Locales/README.md.
local _, NN = ...

NN.L = setmetatable({}, { __index = function(_, key) return key end })
NN.Locales = { registered = {}, order = {} }

-- Client locales that share another language's file.
NN.Locales.FALLBACK = {
  enGB = "enUS",
  esMX = "esES",
  ptPT = "ptBR",
}

local client = (GetLocale and GetLocale()) or "enUS"
NN.Locales.client = client
NN.Locales.active = NN.Locales.FALLBACK[client] or client

-- Registers one language. English always merges into NN.L; the active
-- language merges on top of it. Order of registration follows the TOC, where
-- enUS.lua comes first.
function NN.RegisterLocale(code, strings)
  NN.Locales.registered[code] = strings
  NN.Locales.order[#NN.Locales.order + 1] = code
  if code == "enUS" or code == NN.Locales.active then
    for key, value in pairs(strings) do NN.L[key] = value end
  end
end
