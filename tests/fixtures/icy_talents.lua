-- Fixture: a tiny Icy Veins talent table for the stub's default class (MAGE).
local _, NN = ...
NN.IcyTalents = {
  version = "3-c",
  compatible = { ["3-c"] = true, ["2-b"] = true },
  MAGE = {
    ["1"] = { node = 11, spell = 1001, maxRank = 2 },
    ["B"] = { node = 12, spell = 1002, maxRank = 5 },
    ["z"] = { node = 13, spell = 1003, maxRank = 1 },
  },
}
