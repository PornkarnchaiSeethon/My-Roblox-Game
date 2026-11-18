local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local App = require(script.Parent:WaitForChild("UI"):WaitForChild("App"))

require(script.Parent:WaitForChild("InventoryClient"))
require(script.Parent:WaitForChild("PlotService"):WaitForChild("PlotController"))

Knit.Start()
	:andThen(function()
		App()
	end)
	:catch(function(err)
		warn(`[Bootstrap] KnitClient Start failed:\n{err}`)
	end)
