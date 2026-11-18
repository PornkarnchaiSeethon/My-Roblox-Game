local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local ClientPlacer = require(script.Parent:WaitForChild("ClientPlacer"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local PlotController = Knit.CreateController({
	Name = "PlotController",
})

PlotController.Plot = nil :: Model?
PlotController.Placer = nil :: any

local started = false

local function setPlacementActive(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return
	end
	if not PlotController.Plot then
		return
	end

	if not PlotController.Placer then
		PlotController.Placer = ClientPlacer.new(PlotController.Plot)
	else
		PlotController.Placer:destroy()
		PlotController.Placer = nil
	end
end

function PlotController.Start()
	if started then
		return
	end
	started = true

	Network.Plot.Ready.listen(function(data)
		if data.plot and data.plot:IsA("Model") then
			PlotController.Plot = data.plot
		end
	end)

	task.spawn(function()
		for _ = 1, 60 do
			if PlotController.Plot then
				break
			end
			Network.Plot.Request.send(nil)
			task.wait(0.5)
		end

		if not PlotController.Plot then
			warn("Plot was not created by the server")
			return
		end

		ContextActionService:BindAction("ActivatePlacement", setPlacementActive, false, Enum.KeyCode.F)
	end)
end

function PlotController:KnitInit() end

function PlotController:KnitStart()
	PlotController.Start()
end

return PlotController
