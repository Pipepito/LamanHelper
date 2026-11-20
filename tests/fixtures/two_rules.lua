-- Test fixture: two rules registered before PLAYER_LOGIN, one not applying.
local _, NN = ...
NN:RegisterRule({
  name = "first_rule", title = "First", help = "Help first", events = { "TEST_EVENT" },
  applies = function() return true end,
  check = function() return { text = "First row", icon = 134400, onClick = function() WOW.record("first_click") end } end,
})
NN:RegisterRule({
  name = "second_rule", title = "Second", help = "Help second", events = {},
  applies = function() return false end,
  check = function() return nil end,
})
