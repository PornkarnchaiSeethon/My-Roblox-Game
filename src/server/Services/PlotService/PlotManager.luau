local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotSpawnPool = require(script.Parent.PlotSpawnPool)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)
local PlacementValidator = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlacementValidator"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local PlotManager = {}
local plots: { [number]: Model } = {}
local plotPlayerSpawns: { [number]: SpawnLocation } = {}
local deleteValidators: { (Player, Model) -> (boolean, string?) } = {}

local function requiresInventoryItem(itemName: string): boolean
	local allItems = ServerStorage:FindFirstChild("AllItems")
	local template = allItems and allItems:FindFirstChild(itemName)
	return template ~= nil and template:IsA("Tool")
end

function PlotManager.registerDeleteValidator(validator: (Player, Model) -> (boolean, string?))
	table.insert(deleteValidators, validator)
end

function PlotManager.setupObject(player: Player, objectModel: Model, savedObjectId: string?)
	local modalType = PetConfig.FunctionalPlotObjects[objectModel.Name]
	local isFarmingObject = PlantConfig.IsFarmingObject(objectModel.Name)
	if not modalType and not isFarmingObject then
		return
	end

	local objectId = if type(savedObjectId) == "string" and #savedObjectId > 0
		then savedObjectId
		else HttpService:GenerateGUID(false)

	objectModel:SetAttribute("ObjectId", objectId)
	objectModel:SetAttribute("OwnerUserId", player.UserId)

	if not modalType then
		return
	end

	local promptParent: Instance? = objectModel.PrimaryPart or objectModel:FindFirstChildWhichIsA("BasePart", true)
	if not promptParent then
		return
	end

	local existingPrompt = promptParent:FindFirstChild("FunctionalObjectPrompt")
	if existingPrompt then
		existingPrompt:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FunctionalObjectPrompt"
	prompt.ObjectText = if modalType == "Incubator" then "Egg Incubator" else "Breeding Pen"
	prompt.ActionText = if modalType == "Incubator" then "Manage Incubator" else "Manage Breeding"
	prompt.MaxActivationDistance = 16
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptParent

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer.UserId ~= player.UserId then
			Network.PetNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "คุณสามารถใช้งานอุปกรณ์ในพื้นที่ของตัวเองเท่านั้น",
			}, triggeringPlayer)
			return
		end

		Network.PetNetwork.OpenModal.sendTo({
			ModalType = modalType,
			ObjectId = objectId,
		}, triggeringPlayer)
	end)
end

local function createPlotPlayerSpawn(plot: Model, plotSpawn: BasePart): SpawnLocation
	local existing = plot:FindFirstChild("PlotPlayerSpawn")
	if existing and existing:IsA("SpawnLocation") then
		existing:Destroy()
	end

	local primaryPart = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
	local plotCenter = if primaryPart then primaryPart.Position else plot:GetPivot().Position
	local plotTopY = if primaryPart then (primaryPart.Position.Y + primaryPart.Size.Y * 0.5) else (plotCenter.Y + 0.5)

	local spawnOffsetAttr = plotSpawn:GetAttribute("PlayerSpawnOffset")
	local offset = if typeof(spawnOffsetAttr) == "Vector3" then spawnOffsetAttr else Vector3.zero
	local spawnPos = Vector3.new(plotCenter.X + offset.X, plotTopY + 0.5, plotCenter.Z + offset.Z)
	local lookTarget = Vector3.new(plotCenter.X, spawnPos.Y, plotCenter.Z)
	local spawnCF = if (lookTarget - spawnPos).Magnitude > 0.5
		then CFrame.lookAt(spawnPos, lookTarget)
		else CFrame.new(spawnPos)

	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "PlotPlayerSpawn"
	spawnLoc.Size = Vector3.new(8, 1, 8)
	spawnLoc.CFrame = spawnCF
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = false
	spawnLoc.Transparency = 1
	spawnLoc.CastShadow = false
	spawnLoc.Enabled = true
	spawnLoc.Neutral = false
	spawnLoc.AllowTeamChangeOnTouch = false
	spawnLoc.Duration = 0
	spawnLoc.TopSurface = Enum.SurfaceType.Smooth
	spawnLoc.BottomSurface = Enum.SurfaceType.Smooth
	for _, child in spawnLoc:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	spawnLoc.Parent = plot

	return spawnLoc
end

function PlotManager.getPlotSpawnCFrame(player: Player): CFrame?
	local spawnLoc = plotPlayerSpawns[player.UserId]
	if spawnLoc and spawnLoc.Parent then
		return spawnLoc.CFrame * CFrame.new(0, 3.5, 0)
	end

	local plot = plots[player.UserId]
	if not plot then
		return nil
	end

	local primaryPart = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
	if primaryPart then
		return CFrame.new(primaryPart.Position + Vector3.new(0, primaryPart.Size.Y * 0.5 + 4, 0))
	end
	return plot:GetPivot() * CFrame.new(0, 4, 0)
end

function PlotManager.teleportToPlot(player: Player, characterOverride: Model?)
	local spawnCF = PlotManager.getPlotSpawnCFrame(player)
	if not spawnCF then
		return
	end

	local character = characterOverride or player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not hrp or not hrp:IsA("BasePart") or not character.Parent or not player:IsDescendantOf(Players) then
		return
	end

	character:PivotTo(spawnCF)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
end

function PlotManager.spawnPlot(player: Player): Model
	local existingPlot = plots[player.UserId]
	if existingPlot then
		return existingPlot
	end

	local plotTemplate = ServerStorage:FindFirstChild("Plot")
	local plotsFolder = workspace:FindFirstChild("Plots")
	assert(plotTemplate and plotTemplate:IsA("Model"), "ServerStorage.Plot is missing or is not a Model")
	assert(plotsFolder and plotsFolder:IsA("Folder"), "Workspace.Plots is missing or is not a Folder")
	local plot = plotTemplate:Clone()
	local plotSpawn = PlotSpawnPool.get(player)

	plot.Name = `{player.Name}_Plot`
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:PivotTo(plotSpawn.CFrame)

	if not plot:FindFirstChild("Pets") then
		local petsFolder = Instance.new("Folder")
		petsFolder.Name = "Pets"
		petsFolder.Parent = plot
	end
	if not plot:FindFirstChild("Plants") then
		local plantsFolder = Instance.new("Folder")
		plantsFolder.Name = "Plants"
		plantsFolder.Parent = plot
	end

	local plotPlayerSpawn = createPlotPlayerSpawn(plot, plotSpawn)
	plot.Parent = plotsFolder

	plots[player.UserId] = plot
	plotPlayerSpawns[player.UserId] = plotPlayerSpawn
	player.RespawnLocation = plotPlayerSpawn

	if player.Character then
		task.spawn(function()
			task.wait()
			PlotManager.teleportToPlot(player, player.Character)
		end)
	end

	return plot
end

function PlotManager.getPlot(player: Player): Model?
	return plots[player.UserId]
end

function PlotManager.removePlot(player: Player)
	if player.RespawnLocation == plotPlayerSpawns[player.UserId] then
		player.RespawnLocation = nil
	end
	plotPlayerSpawns[player.UserId] = nil

	local plot = plots[player.UserId]
	if plot then
		plot:Destroy()
		plots[player.UserId] = nil
	end
	PlotSpawnPool.returnPlot(player)
end

function PlotManager.place(player: Player, name: string, targetCF: CFrame): boolean
	if typeof(name) ~= "string" then
		return false
	end

	local placeableObjects = ReplicatedStorage:FindFirstChild("PlaceableObjects")
	local object = placeableObjects and placeableObjects:FindFirstChild(name)
	local plot = plots[player.UserId]
	if not object or not plot or typeof(targetCF) ~= "CFrame" then
		return false
	end
	if not object:IsA("Model") then
		return false
	end

	local objectsFolder = plot:FindFirstChild("Objects")
	if not objectsFolder then
		return false
	end

	local _, objectSize = object:GetBoundingBox()
	local snappedCF = PlacementValidator.snapCFrameToGrid(
		plot,
		objectSize,
		targetCF,
		PlacementValidator.SERVER_GRID_SIZE
	)
	if not PlacementValidator.withinBounds(plot, objectSize, snappedCF) then
		return false
	end
	if not PlacementValidator.noCollisions(plot, objectSize, snappedCF) then
		return false
	end

	if requiresInventoryItem(name) then
		if not InventoryService.HasItem(player, name) or not InventoryService.ConsumeItem(player, name) then
			Network.Inventory.Error.sendTo("You don't have this item!", player)
			return false
		end
	end

	local newObject = object:Clone()
	for _, desc in newObject:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
	newObject:PivotTo(snappedCF)
	newObject.Parent = objectsFolder
	PlotManager.setupObject(player, newObject, nil)
	return true
end

function PlotManager.delete(player: Player, targetInstance: Instance): boolean
	local plot = plots[player.UserId]
	local objectsFolder = plot and plot:FindFirstChild("Objects")
	if not plot or not objectsFolder or typeof(targetInstance) ~= "Instance" then
		return false
	end

	local actualObject = if targetInstance:IsA("Model") and targetInstance.Parent == objectsFolder
		then targetInstance
		else targetInstance:FindFirstAncestorWhichIsA("Model")

	if actualObject and actualObject.Parent == objectsFolder then
		for _, validator in deleteValidators do
			local allowed, reason = validator(player, actualObject)
			if not allowed then
				local message = reason or "ไม่สามารถลบอุปกรณ์นี้ได้ในขณะนี้"
				if PlantConfig.IsFarmingObject(actualObject.Name) and Network.PlantNetwork then
					Network.PlantNetwork.NotifyToast.sendTo({
						IsError = true,
						Message = message,
					}, player)
				else
					Network.PetNetwork.NotifyToast.sendTo({
						IsError = true,
						Message = message,
					}, player)
				end
				return false
			end
		end

		if requiresInventoryItem(actualObject.Name) then
			if not InventoryService.GiveItem(player, actualObject.Name) then
				Network.Inventory.Error.sendTo("Inventory is full!", player)
				return false
			end
		end

		actualObject:Destroy()
		return true
	end

	return false
end

return PlotManager
