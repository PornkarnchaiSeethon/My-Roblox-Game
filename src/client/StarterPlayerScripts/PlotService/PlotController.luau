local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
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
local manualPlacementOpen = false
local equippedPlaceableToolName: string? = nil

local function isPlaceableModel(name: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("PlaceableObjects")
	local model = folder and folder:FindFirstChild(name)
	return model ~= nil and model:IsA("Model")
end

local function closePlacer()
	if PlotController.Placer then
		PlotController.Placer:destroy()
		PlotController.Placer = nil
	end
end

local function openPlacer(initialObjectName: string?)
	if not PlotController.Plot then
		return
	end
	if PlotController.Placer then
		if initialObjectName then
			PlotController.Placer:selectObjectByName(initialObjectName)
		end
		return
	end

	local ok, placerOrErr = pcall(ClientPlacer.new, PlotController.Plot, initialObjectName)
	if ok then
		PlotController.Placer = placerOrErr
	else
		warn("[PlotController] Failed to open placement mode:", placerOrErr)
	end
end

local function syncPlacementWithEquippedTool(character: Model?)
	local heldTool = if character then character:FindFirstChildOfClass("Tool") else nil
	if heldTool and isPlaceableModel(heldTool.Name) then
		equippedPlaceableToolName = heldTool.Name
		openPlacer(heldTool.Name)
	else
		local wasToolMode = equippedPlaceableToolName ~= nil
		equippedPlaceableToolName = nil
		if wasToolMode and not manualPlacementOpen then
			closePlacer()
		end
	end
end

local function watchCharacterTools(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			syncPlacementWithEquippedTool(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(syncPlacementWithEquippedTool, character)
		end
	end)
	syncPlacementWithEquippedTool(character)
end

local function setPlacementActive(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not PlotController.Plot then
		return Enum.ContextActionResult.Pass
	end

	if not PlotController.Placer then
		manualPlacementOpen = true
		openPlacer(equippedPlaceableToolName)
	else
		manualPlacementOpen = false
		closePlacer()
	end
	return Enum.ContextActionResult.Sink
end

function PlotController.Start()
	if started then
		return
	end
	started = true

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		if localPlayer.Character then
			watchCharacterTools(localPlayer.Character)
		end
		localPlayer.CharacterAdded:Connect(watchCharacterTools)
	end

	Network.Plot.Ready.listen(function(data)
		if data.plot and data.plot:IsA("Model") then
			PlotController.Plot = data.plot
			if localPlayer and localPlayer.Character then
				syncPlacementWithEquippedTool(localPlayer.Character)
			end
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
