--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local PlantVisualRenderer = require(script.Parent:WaitForChild("PlantVisualRenderer"))

export type PlanterClientData = {
	ObjectId: string,
	PlanterType: string,
	CropId: string,
	Stage: string,
	GrowthProgress: number,
	MoistureUntil: number,
	FertilizerId: string,
	HarvestsRemaining: number,
}

export type PlantModalInfo = {
	ObjectId: string,
	PlanterType: string,
}

export type PlantToastInfo = {
	IsError: boolean,
	Message: string,
}

local PlantController = Knit.CreateController({
	Name = "PlantController",
})

PlantController.State = {
	IsAlmanacOpen = false,
	ActiveModal = nil :: PlantModalInfo?,
	PlantersById = {} :: { [string]: PlanterClientData },
	HarvestStats = {} :: { [string]: number },
	Toast = nil :: PlantToastInfo?,
}

local started = false
local hasSynced = false
local listeners: { () -> () } = {}

function PlantController.Subscribe(callback: () -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function PlantController.Notify()
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function PlantController.ToggleAlmanac()
	PlantController.State.IsAlmanacOpen = not PlantController.State.IsAlmanacOpen
	if PlantController.State.IsAlmanacOpen then
		PlantController.State.ActiveModal = nil
	end
	PlantController.Notify()
end

function PlantController.SetAlmanacOpen(isOpen: boolean)
	if PlantController.State.IsAlmanacOpen == isOpen then
		return
	end
	PlantController.State.IsAlmanacOpen = isOpen
	if isOpen then
		PlantController.State.ActiveModal = nil
	end
	PlantController.Notify()
end

function PlantController.OpenModal(objectId: string, planterType: string)
	PlantController.State.IsAlmanacOpen = false
	PlantController.State.ActiveModal = {
		ObjectId = objectId,
		PlanterType = planterType,
	}
	PlantController.Notify()
end

function PlantController.CloseModal()
	if PlantController.State.ActiveModal == nil then
		return
	end
	PlantController.State.ActiveModal = nil
	PlantController.Notify()
end

function PlantController.ClearToast()
	if PlantController.State.Toast == nil then
		return
	end
	PlantController.State.Toast = nil
	PlantController.Notify()
end

function PlantController.PlantSeed(objectId: string, seedItemId: string)
	Network.PlantNetwork.PlantSeed.send({
		ObjectId = objectId,
		SeedItemId = seedItemId,
	})
end

function PlantController.WaterPlant(objectId: string)
	Network.PlantNetwork.WaterPlant.send({
		ObjectId = objectId,
	})
end

function PlantController.ApplyFertilizer(objectId: string, fertilizerItemId: string)
	Network.PlantNetwork.ApplyFertilizer.send({
		ObjectId = objectId,
		FertilizerItemId = fertilizerItemId,
	})
end

function PlantController.HarvestCrop(objectId: string)
	Network.PlantNetwork.HarvestCrop.send({
		ObjectId = objectId,
	})
end

function PlantController.UprootPlant(objectId: string)
	Network.PlantNetwork.UprootPlant.send({
		ObjectId = objectId,
	})
end

local function getHeldToolName(): string?
	local localPlayer = Players.LocalPlayer
	local char = if localPlayer then localPlayer.Character else nil
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	return if tool then tool.Name else nil
end

function PlantController.Start()
	if started then
		return
	end
	started = true

	PlantVisualRenderer.Start()

	Network.PlantNetwork.SyncState.listen(function(payload)
		hasSynced = true
		local map: { [string]: PlanterClientData } = {}
		for _, planter in payload.Planters do
			map[planter.ObjectId] = planter
		end
		local stats: { [string]: number } = {}
		for _, entry in payload.HarvestStats do
			stats[entry.SeedId] = entry.TotalCount
		end
		PlantController.State.PlantersById = map
		PlantController.State.HarvestStats = stats
		PlantController.Notify()
	end)

	Network.PlantNetwork.SyncSinglePlanter.listen(function(payload)
		hasSynced = true
		local nextPlanters = table.clone(PlantController.State.PlantersById)
		if payload.IsEmpty then
			nextPlanters[payload.ObjectId] = nil
		elseif payload.Planter then
			nextPlanters[payload.ObjectId] = payload.Planter
		end
		PlantController.State.PlantersById = nextPlanters

		if payload.UpdatedStat then
			local nextStats = table.clone(PlantController.State.HarvestStats)
			nextStats[payload.UpdatedStat.SeedId] = payload.UpdatedStat.TotalCount
			PlantController.State.HarvestStats = nextStats
		end

		PlantController.Notify()
	end)

	Network.PlantNetwork.OpenPlantModal.listen(function(payload)
		local heldTool = getHeldToolName()
		local currentPlanter = PlantController.State.PlantersById[payload.ObjectId]

		if not currentPlanter and heldTool and PlantConfig.Crops[heldTool] then
			PlantController.PlantSeed(payload.ObjectId, heldTool)
			return
		elseif currentPlanter and currentPlanter.Stage == "Mature" then
			PlantController.HarvestCrop(payload.ObjectId)
			return
		elseif currentPlanter and heldTool == "watering_can" then
			PlantController.WaterPlant(payload.ObjectId)
			return
		elseif currentPlanter and heldTool and PlantConfig.Fertilizers[heldTool] then
			PlantController.ApplyFertilizer(payload.ObjectId, heldTool)
			return
		end

		PlantController.OpenModal(payload.ObjectId, payload.PlanterType)
	end)

	Network.PlantNetwork.PlantVisualEvent.listen(function(payload)
		PlantVisualRenderer.PlayEffect(payload.EventType, payload.WorldPos)
	end)

	Network.PlantNetwork.NotifyToast.listen(function(payload)
		PlantController.State.Toast = {
			IsError = payload.IsError,
			Message = payload.Message,
		}
		PlantController.Notify()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			PlantController.ToggleAlmanac()
		end
	end)

	task.spawn(function()
		for _ = 1, 10 do
			if hasSynced then
				break
			end
			Network.PlantNetwork.RequestSync.send(nil)
			task.wait(0.5)
		end
	end)
end

function PlantController:KnitInit() end

function PlantController:KnitStart()
	PlantController.Start()
end

return PlantController
