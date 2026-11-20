-- Test fixture: a rule that ships disabled, registered before PLAYER_LOGIN.
local _, NN = ...
NN:RegisterRule({
  name = "optional_rule", title = "Optional", help = "H", events = {}, default = false,
  applies = function() return true end,
  check = function() return { text = "opt" } end,
})
