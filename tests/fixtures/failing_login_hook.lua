-- Fixture: the first login hook errors; a later one records that it ran.
-- Loaded after the TOC files, so its hooks come after the real ones; the
-- test checks that the real options build still happened and the later
-- hook still ran.
local _, NN = ...
NN.OnLoginHooks = NN.OnLoginHooks or {}
table.insert(NN.OnLoginHooks, 1, function() error("hook boom") end)
NN:AfterLogin(function() NewbieNudge_LaterHookRan = true end)
