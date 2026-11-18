local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local PlotController = require(script.Parent:WaitForChild("PlotController"))

Knit.OnStart()
	:andThen(function()
		PlotController.Start()
	end)
	:catch(warn)
