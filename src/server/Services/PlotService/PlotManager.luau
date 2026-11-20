local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotSpawnPool = require(script.Parent.PlotSpawnPool)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)
local PlacementValidator = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlacementValidator"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local PlotManager = {}
local plots: { [number]: Model } = {}
local deleteValidators: { (Player, Model) -> (boolean, string?) } = {}

local function requiresInventoryItem(itemName: string): boolean
	local allItems = ServerStorage:FindFirstChild("AllItems")
	local template = allItems and allItems:FindFirstChild(itemName)
	return template ~= nil and template:IsA("Tool")
end

function PlotManager.registerDeleteValidator(validator: (Player, Model) -> (boolean, string?))
	table.insert(deleteValidators, validator)
end

-- ตั้งค่า Attribute ObjectId และ ProximityPrompt สำหรับ Functional Plot Objects (Incubator / BreedingPen)
function PlotManager.setupObject(player: Player, objectModel: Model, savedObjectId: string?)
	local modalType = PetConfig.FunctionalPlotObjects[objectModel.Name]
	if not modalType then
		return
	end

	local objectId = if type(savedObjectId) == "string" and #savedObjectId > 0
		then savedObjectId
		else HttpService:GenerateGUID(false)

	objectModel:SetAttribute("ObjectId", objectId)
	objectModel:SetAttribute("OwnerUserId", player.UserId)

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

-- สร้าง Plot ประจำตัวผู้เล่น
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

	plot.Parent = plotsFolder

	plots[player.UserId] = plot
	return plot
end

function PlotManager.getPlot(player: Player): Model?
	return plots[player.UserId]
end

-- ลบ Plot และคืนพื้นที่เมื่อผู้เล่นออก
function PlotManager.removePlot(player: Player)
	local plot = plots[player.UserId]
	if plot then
		plot:Destroy()
		plots[player.UserId] = nil
	end
	PlotSpawnPool.returnPlot(player)
end

-- วางวัตถุลงใน Plot หลังผ่านการตรวจสอบความถูกต้อง
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
	if not PlacementValidator.withinBounds(plot, objectSize, targetCF) then
		return false
	end
	if not PlacementValidator.noCollisions(plot, objectSize, targetCF) then
		return false
	end

	if requiresInventoryItem(name) then
		if not InventoryService.HasItem(player, name) or not InventoryService.ConsumeItem(player, name) then
			Network.Inventory.Error.sendTo("You don't have this item!", player)
			return false
		end
	end

	local newObject = object:Clone()
	newObject:PivotTo(targetCF)
	newObject.Parent = objectsFolder
	PlotManager.setupObject(player, newObject, nil)
	return true
end

-- ลบวัตถุออกจาก Plot ของผู้เล่น
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
				Network.PetNetwork.NotifyToast.sendTo({
					IsError = true,
					Message = reason or "ไม่สามารถลบอุปกรณ์นี้ได้ในขณะนี้",
				}, player)
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
