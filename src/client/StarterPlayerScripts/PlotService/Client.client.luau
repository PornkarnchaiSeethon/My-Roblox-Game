local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local ClientPlacer = require(script.Parent:WaitForChild("ClientPlacer"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local plot: Model?
Network.Plot.Ready.listen(function(data)
	if data.plot and data.plot:IsA("Model") then
		plot = data.plot
	end
end)

for _ = 1, 60 do
	if plot then break end
	Network.Plot.Request.send(nil)
	task.wait(0.5)
end

if not plot then
	warn("Plot was not created by the server")
	return
end

local placer: any = nil

local function setPlacementActive(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return
	end

	if not placer then
		placer = ClientPlacer.new(plot)
	else
		placer:destroy()
		placer = nil
	end
end

ContextActionService:BindAction("ActivatePlacement", setPlacementActive, false, Enum.KeyCode.B)
