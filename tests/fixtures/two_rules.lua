-- Test fixture: two rules registered before PLAYER_LOGIN, one not applying.
local _, NN = ...
NN:RegisterRule({
  name = "first_rule", title = "First", help = "Help first", events = {},
  applies = function() return true end,
  check = function() return nil end,
})
NN:RegisterRule({
  name = "second_rule", title = "Second", help = "Help second", events = {},
  applies = function() return false end,
  check = function() return nil end,
})
