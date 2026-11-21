local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local App = require(script.Parent:WaitForChild("UI"):WaitForChild("App"))

require(script.Parent:WaitForChild("InventoryClient"))
require(script.Parent:WaitForChild("PlotService"):WaitForChild("PlotController"))
require(script.Parent:WaitForChild("PetService"):WaitForChild("PetController"))
require(script.Parent:WaitForChild("PlantService"):WaitForChild("PlantController"))

Knit.Start()
	:andThen(function()
		App()
	end)
	:catch(function(err)
		warn(`[Bootstrap] KnitClient Start failed:\n{err}`)
	end)
