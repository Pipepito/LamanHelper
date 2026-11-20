-- Fixture: an options page whose builder errors.
local _, NN = ...
NN.Options.RegisterPage("boom", "BOOM_PAGE_TITLE", function() error("page boom") end)
NN.L.BOOM_PAGE_TITLE = "Boom page"
