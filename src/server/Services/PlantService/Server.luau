--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local DataService = require(script.Parent.Parent.DataService.DataService)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)
local PlotService = require(script.Parent.Parent.PlotService.Server)

local PlantGrowthManager = require(script.Parent.PlantGrowthManager)
local PlantPlotManager = require(script.Parent.PlantPlotManager)

local PlantService = Knit.CreateService({
	Name = "PlantService",
	Client = {}, -- ใช้ ByteNet (PlantNetwork) เป็นช่องทางสื่อสารเดียวตามมาตรฐานสถาปัตยกรรม
})

local lastPacketAt: { [Player]: number } = {}
local activeLocks: { [Player]: boolean } = {}
local plotObjectConns: { [Player]: RBXScriptConnection } = {}
local PACKET_COOLDOWN = 0.18
local SIM_STEP = 1.0
local ACCESS_DENIED_MESSAGE = "กรุณาเข้าใกล้กระบะปลูกใน Plot ของคุณ (ระยะไม่เกิน 24 Studs)"

local function checkRateLimit(player: Player): boolean
	local now = os.clock()
	if lastPacketAt[player] and (now - lastPacketAt[player]) < PACKET_COOLDOWN then
		return false
	end
	lastPacketAt[player] = now
	return true
end

local function withPlayerLock(player: Player, fn: () -> ())
	if activeLocks[player] then
		return
	end
	activeLocks[player] = true
	local ok, err = pcall(fn)
	activeLocks[player] = nil
	if not ok then
		warn("[PlantService] Action error for", player.Name, err)
	end
end

local function ensurePlantsProfile(profile: any)
	if type(profile.Data.Plants) ~= "table" then
		profile.Data.Plants = {}
	end
	local plants = profile.Data.Plants
	if type(plants.MaxActivePlanters) ~= "number" then
		plants.MaxActivePlanters = 24
	end
	if type(plants.Planters) ~= "table" then
		plants.Planters = {}
	end
	if type(plants.HarvestStats) ~= "table" then
		plants.HarvestStats = {}
	end
	return plants
end

local function serializePlanter(pData: any)
	return {
		ObjectId = tostring(pData.ObjectId or ""),
		PlanterType = tostring(pData.PlanterType or "wooden_planter"),
		CropId = tostring(pData.CropId or ""),
		Stage = tostring(pData.Stage or "Seed"),
		GrowthProgress = math.clamp(tonumber(pData.GrowthProgress) or 0, 0, 1),
		MoistureUntil = math.max(0, math.floor(tonumber(pData.MoistureUntil) or 0)),
		FertilizerId = tostring(pData.FertilizerId or ""),
		HarvestsRemaining = math.clamp(math.floor(tonumber(pData.HarvestsRemaining) or 0), 0, 255),
	}
end

function PlantService:IsObjectBusy(player: Player, objectId: string?): (boolean, string?)
	if type(objectId) ~= "string" or objectId == "" then
		return false, nil
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, nil
	end
	local plantsData = ensurePlantsProfile(profile)
	if plantsData.Planters[objectId] ~= nil then
		return true, "ไม่สามารถลบกระบะปลูกได้ขณะมีพืชอยู่ กรุณาเก็บเกี่ยวหรือถอนต้นไม้ก่อน"
	end
	return false, nil
end

function PlantService:HasNaturePetInPlot(player: Player): boolean
	local profile = DataService.GetProfile(player)
	if not profile or type(profile.Data.Pets) ~= "table" or type(profile.Data.Pets.Instances) ~= "table" then
		return false
	end
	for _, pet in profile.Data.Pets.Instances do
		if pet.State == "InPlot" and (pet.SpeciesId == "sprout_slime" or pet.SpeciesId == "flora_guardian") then
			return true
		end
	end
	return false
end

function PlantService:ValidatePlanterAccess(player: Player, objectId: string): (Model?, Model?)
	if typeof(objectId) ~= "string" or objectId == "" or #objectId > 64 then
		return nil, nil
	end
	local plotModel = PlotService:GetPlayerPlotModel(player)
	local planterModel = PlantPlotManager.FindPlanterInstance(plotModel, objectId)
	if not plotModel or not planterModel then
		return nil, nil
	end
	if not PlantConfig.Planters[planterModel.Name] then
		return nil, nil
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - planterModel:GetPivot().Position).Magnitude > PlantConfig.InteractDistanceStuds then
		return nil, nil
	end
	return plotModel, planterModel
end

function PlantService:SendFullSync(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local plantsData = ensurePlantsProfile(profile)
	local plantersList = {}
	local statsList = {}
	for _, pData in plantsData.Planters do
		table.insert(plantersList, serializePlanter(pData))
	end
	for seedId, total in plantsData.HarvestStats do
		table.insert(statsList, {
			SeedId = tostring(seedId),
			TotalCount = math.max(0, math.floor(tonumber(total) or 0)),
		})
	end
	Network.PlantNetwork.SyncState.sendTo({
		Planters = plantersList,
		HarvestStats = statsList,
	}, player)
end

function PlantService:SendDeltaSync(player: Player, objectId: string, updatedSeedId: string?)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local plantsData = ensurePlantsProfile(profile)
	local planterData = plantsData.Planters[objectId]
	local statPayload = nil
	if updatedSeedId then
		statPayload = {
			SeedId = updatedSeedId,
			TotalCount = math.max(0, math.floor(tonumber(plantsData.HarvestStats[updatedSeedId]) or 0)),
		}
	end
	Network.PlantNetwork.SyncSinglePlanter.sendTo({
		ObjectId = objectId,
		IsEmpty = planterData == nil,
		Planter = if planterData then serializePlanter(planterData) else nil,
		UpdatedStat = statPayload,
	}, player)
end

function PlantService:RegisterPlanterInstance(player: Player, planterModel: Model)
	if not PlantConfig.Planters[planterModel.Name] then
		return
	end
	local profile = DataService.GetProfile(player)
	local objectId = planterModel:GetAttribute("ObjectId")
	PlantPlotManager.BindPlanterPrompt(planterModel, player, function(triggerPlayer, triggeredId, planterType)
		self:SendDeltaSync(triggerPlayer, triggeredId, nil)
		Network.PlantNetwork.OpenPlantModal.sendTo({
			ObjectId = triggeredId,
			PlanterType = planterType,
		}, triggerPlayer)
	end)
	if profile and typeof(objectId) == "string" then
		local plantsData = ensurePlantsProfile(profile)
		PlantPlotManager.ApplyVisualAttributes(planterModel, plantsData.Planters[objectId], os.time())
	end
end

local function syncPlotAndCatchUp(player: Player, plotModel: Model)
	local profile = DataService.GetProfile(player)
	if not profile or not player:IsDescendantOf(Players) then
		return
	end

	local plantsData = ensurePlantsProfile(profile)
	local now = os.time()
	local hasNatureAura = PlantService:HasNaturePetInPlot(player)

	for objectId, planterData in plantsData.Planters do
		local planterModel = PlantPlotManager.FindPlanterInstance(plotModel, objectId)
		local sprinklerNear = planterModel ~= nil
			and PlantPlotManager.HasSprinklerInRange(plotModel, planterModel:GetPivot().Position)
		PlantGrowthManager.StepPlanterGrowth(planterData, now, sprinklerNear, hasNatureAura)
	end

	local objectsFolder = plotModel:FindFirstChild("Objects")
	if objectsFolder then
		for _, obj in objectsFolder:GetChildren() do
			if obj:IsA("Model") and PlantConfig.Planters[obj.Name] then
				PlantService:RegisterPlanterInstance(player, obj)
			end
		end

		if plotObjectConns[player] then
			plotObjectConns[player]:Disconnect()
		end
		plotObjectConns[player] = objectsFolder.ChildAdded:Connect(function(child)
			if child:IsA("Model") and PlantConfig.Planters[child.Name] then
				task.defer(function()
					if child.Parent and player:IsDescendantOf(Players) then
						PlantService:RegisterPlanterInstance(player, child)
					end
				end)
			end
		end)
	end

	PlantService:SendFullSync(player)
end

local function onPlayerLoaded(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player:IsDescendantOf(Players) then
		return
	end

	ensurePlantsProfile(profile)
	local plotModel = PlotService:GetPlayerPlotModel(player)
	if plotModel then
		syncPlotAndCatchUp(player, plotModel)
	else
		PlantService:SendFullSync(player)
	end
end

function PlantService:KnitInit()
	PlotService:RegisterDeleteValidator(function(player: Player, objectModel: Model)
		local objectId = objectModel:GetAttribute("ObjectId")
		if type(objectId) == "string" then
			local busy, reason = PlantService:IsObjectBusy(player, objectId)
			if busy then
				return false, reason
			end
		end
		return true, nil
	end)

	PlotService:OnPlotLoaded(function(player: Player, plotModel: Model)
		syncPlotAndCatchUp(player, plotModel)
	end)

	DataService.OnBeforeProfileRelease(function(_player: Player, profile: any)
		if profile and profile.Data and type(profile.Data.Plants) == "table" and type(profile.Data.Plants.Planters) == "table" then
			local now = os.time()
			for _, planterData in profile.Data.Plants.Planters do
				planterData.LastSimulatedAt = now
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPacketAt[player] = nil
		activeLocks[player] = nil
		if plotObjectConns[player] then
			plotObjectConns[player]:Disconnect()
			plotObjectConns[player] = nil
		end
	end)
end

function PlantService:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerLoaded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerLoaded, player)
	end)

	Network.PlantNetwork.RequestSync.listen(function(_, player)
		if checkRateLimit(player) then
			self:SendFullSync(player)
		end
	end)

	Network.PlantNetwork.PlantSeed.listen(function(data, player)
		if not checkRateLimit(player) then
			return
		end
		withPlayerLock(player, function()
			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end
			local _, planterModel = self:ValidatePlanterAccess(player, data.ObjectId)
			if not planterModel then
				Network.PlantNetwork.NotifyToast.sendTo({ IsError = true, Message = ACCESS_DENIED_MESSAGE }, player)
				return
			end
			local plantsData = ensurePlantsProfile(profile)

			local ok, msg = PlantGrowthManager.PlantSeed(
				player,
				plantsData,
				data.ObjectId,
				planterModel.Name,
				data.SeedItemId,
				InventoryService
			)
			Network.PlantNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
			if ok then
				PlantPlotManager.ApplyVisualAttributes(planterModel, plantsData.Planters[data.ObjectId], os.time())
				Network.PlantNetwork.PlantVisualEvent.sendToAll({
					ObjectId = data.ObjectId,
					EventType = "Plant",
					WorldPos = planterModel:GetPivot().Position,
				})
				self:SendDeltaSync(player, data.ObjectId, nil)
			end
		end)
	end)

	Network.PlantNetwork.WaterPlant.listen(function(data, player)
		if not checkRateLimit(player) then
			return
		end
		withPlayerLock(player, function()
			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end
			local _, planterModel = self:ValidatePlanterAccess(player, data.ObjectId)
			if not planterModel then
				Network.PlantNetwork.NotifyToast.sendTo({ IsError = true, Message = ACCESS_DENIED_MESSAGE }, player)
				return
			end
			local plantsData = ensurePlantsProfile(profile)
			local planterData = plantsData.Planters[data.ObjectId]

			local ok, msg = PlantGrowthManager.WaterPlant(player, planterData, InventoryService)
			Network.PlantNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
			if ok then
				PlantPlotManager.ApplyVisualAttributes(planterModel, planterData, os.time())
				Network.PlantNetwork.PlantVisualEvent.sendToAll({
					ObjectId = data.ObjectId,
					EventType = "Water",
					WorldPos = planterModel:GetPivot().Position,
				})
				self:SendDeltaSync(player, data.ObjectId, nil)
			end
		end)
	end)

	Network.PlantNetwork.ApplyFertilizer.listen(function(data, player)
		if not checkRateLimit(player) then
			return
		end
		withPlayerLock(player, function()
			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end
			local _, planterModel = self:ValidatePlanterAccess(player, data.ObjectId)
			if not planterModel then
				Network.PlantNetwork.NotifyToast.sendTo({ IsError = true, Message = ACCESS_DENIED_MESSAGE }, player)
				return
			end
			local plantsData = ensurePlantsProfile(profile)
			local planterData = plantsData.Planters[data.ObjectId]

			local ok, msg = PlantGrowthManager.ApplyFertilizer(
				player,
				planterData,
				data.FertilizerItemId,
				InventoryService
			)
			Network.PlantNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
			if ok then
				Network.PlantNetwork.PlantVisualEvent.sendToAll({
					ObjectId = data.ObjectId,
					EventType = "Fertilize",
					WorldPos = planterModel:GetPivot().Position,
				})
				self:SendDeltaSync(player, data.ObjectId, nil)
			end
		end)
	end)

	Network.PlantNetwork.HarvestCrop.listen(function(data, player)
		if not checkRateLimit(player) then
			return
		end
		withPlayerLock(player, function()
			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end
			local _, planterModel = self:ValidatePlanterAccess(player, data.ObjectId)
			if not planterModel then
				Network.PlantNetwork.NotifyToast.sendTo({ IsError = true, Message = ACCESS_DENIED_MESSAGE }, player)
				return
			end
			local plantsData = ensurePlantsProfile(profile)

			local existingCrop = plantsData.Planters[data.ObjectId]
			local seedId = if existingCrop then existingCrop.CropId else nil
			local ok, msg = PlantGrowthManager.HarvestCrop(player, profile.Data, data.ObjectId, InventoryService)
			Network.PlantNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
			if ok then
				PlantPlotManager.ApplyVisualAttributes(planterModel, plantsData.Planters[data.ObjectId], os.time())
				Network.PlantNetwork.PlantVisualEvent.sendToAll({
					ObjectId = data.ObjectId,
					EventType = "Harvest",
					WorldPos = planterModel:GetPivot().Position,
				})
				self:SendDeltaSync(player, data.ObjectId, seedId)
			end
		end)
	end)

	Network.PlantNetwork.UprootPlant.listen(function(data, player)
		if not checkRateLimit(player) then
			return
		end
		withPlayerLock(player, function()
			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end
			local _, planterModel = self:ValidatePlanterAccess(player, data.ObjectId)
			if not planterModel then
				Network.PlantNetwork.NotifyToast.sendTo({ IsError = true, Message = ACCESS_DENIED_MESSAGE }, player)
				return
			end
			local plantsData = ensurePlantsProfile(profile)
			if not plantsData.Planters[data.ObjectId] then
				return
			end

			plantsData.Planters[data.ObjectId] = nil
			PlantPlotManager.ApplyVisualAttributes(planterModel, nil, os.time())
			Network.PlantNetwork.NotifyToast.sendTo({
				IsError = false,
				Message = "ถอนต้นไม้ออกจากแปลงเรียบร้อยแล้ว",
			}, player)
			self:SendDeltaSync(player, data.ObjectId, nil)
		end)
	end)

	-- ลูปจำลองการเติบโตและสปริงเกลอร์ทุก 1.0 วินาที
	task.spawn(function()
		while true do
			task.wait(SIM_STEP)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = DataService.GetProfile(player)
				local plotModel = PlotService:GetPlayerPlotModel(player)
				if profile and plotModel then
					local plantsData = ensurePlantsProfile(profile)
					local objectsFolder = plotModel:FindFirstChild("Objects")
					if objectsFolder then
						for _, obj in objectsFolder:GetChildren() do
							if obj:IsA("Model") and PlantConfig.Planters[obj.Name] then
								self:RegisterPlanterInstance(player, obj)
							end
						end
					end

					local hasNatureAura = self:HasNaturePetInPlot(player)
					for objectId, planterData in plantsData.Planters do
						local planterModel = PlantPlotManager.FindPlanterInstance(plotModel, objectId)
						local sprinklerNear = planterModel ~= nil
							and PlantPlotManager.HasSprinklerInRange(plotModel, planterModel:GetPivot().Position)
						local oldStage = planterData.Stage
						local oldMoistureUntil = planterData.MoistureUntil or 0
						local oldProgressBucket = math.floor((planterData.GrowthProgress or 0) * 20)
						local changed, becameMature = PlantGrowthManager.StepPlanterGrowth(
							planterData,
							now,
							sprinklerNear,
							hasNatureAura
						)
						if planterModel then
							PlantPlotManager.ApplyVisualAttributes(planterModel, planterData, now)
						end
						local stageChanged = oldStage ~= planterData.Stage
						local moistureRefilled = (planterData.MoistureUntil or 0) > oldMoistureUntil
						local progressBucketChanged = math.floor((planterData.GrowthProgress or 0) * 20) ~= oldProgressBucket
						if changed and (stageChanged or moistureRefilled or progressBucketChanged) then
							self:SendDeltaSync(player, objectId, nil)
							if becameMature and planterModel then
								Network.PlantNetwork.PlantVisualEvent.sendToAll({
									ObjectId = objectId,
									EventType = "Mature",
									WorldPos = planterModel:GetPivot().Position,
								})
							end
						end
					end
				end
			end
		end
	end)
end

return PlantService
