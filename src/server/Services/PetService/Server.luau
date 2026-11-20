--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local DataService = require(script.Parent.Parent.DataService.DataService)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)
local PlotService = require(script.Parent.Parent.PlotService.Server)
local EnemyController = require(script.Parent.Parent.NPCService.EnemyController)

local PetGrowthManager = require(script.Parent.PetGrowthManager)
local PetEggBreedingManager = require(script.Parent.PetEggBreedingManager)
local PetPlotBrain = require(script.Parent.PetPlotBrain)
local PetCombatController = require(script.Parent.PetCombatController)

local PetService = Knit.CreateService({
	Name = "PetService",
	Client = {},
})

local lastPacketAt: { [Player]: number } = {}
local PACKET_COOLDOWN = 0.2
local SIM_STEP = 0.25

local function checkRateLimit(player: Player): boolean
	local now = os.clock()
	if lastPacketAt[player] and (now - lastPacketAt[player]) < PACKET_COOLDOWN then
		return false
	end
	lastPacketAt[player] = now
	return true
end

local function ensurePetsProfile(profile: any)
	if type(profile.Data.Pets) ~= "table" then
		profile.Data.Pets = {}
	end
	local pets = profile.Data.Pets
	if type(pets.MaxPetCapacity) ~= "number" then
		pets.MaxPetCapacity = PetConfig.DefaultMaxPetCapacity
	end
	if type(pets.MaxEquippedCombat) ~= "number" then
		pets.MaxEquippedCombat = PetConfig.DefaultMaxEquippedCombat
	end
	if type(pets.Instances) ~= "table" then
		pets.Instances = {}
	end
	if type(pets.Incubators) ~= "table" then
		pets.Incubators = {}
	end
	if type(pets.BreedingPens) ~= "table" then
		pets.BreedingPens = {}
	end
	return pets
end

local function buildClientPayload(petsData: any)
	local now = os.time()
	local petList, incList, penList = {}, {}, {}

	for _, pet in petsData.Instances do
		table.insert(petList, {
			UID = pet.UID,
			SpeciesId = pet.SpeciesId,
			Nickname = pet.Nickname or pet.SpeciesId,
			Stage = pet.Stage or "Baby",
			Level = math.clamp(pet.Level or 1, 1, 65535),
			GrowthExp = math.max(0, pet.GrowthExp or 0),
			Hunger = math.clamp(math.floor(pet.Hunger or 100), 0, 100),
			PotentialBonus = pet.PotentialBonus or 1.0,
			State = pet.State or "InPlot",
			BreedCooldownUntil = math.max(0, pet.BreedCooldownUntil or 0),
		})
	end

	for objectId, inc in petsData.Incubators do
		table.insert(incList, {
			ObjectId = objectId,
			EggItemId = inc.EggItemId,
			StartedAt = math.max(0, inc.StartedAt or 0),
			HatchAt = math.max(0, inc.HatchAt or 0),
		})
	end

	for objectId, pen in petsData.BreedingPens do
		table.insert(penList, {
			ObjectId = objectId,
			ParentA_UID = pen.ParentA_UID,
			ParentB_UID = pen.ParentB_UID,
			StartedAt = math.max(0, pen.StartedAt or 0),
			FinishAt = math.max(0, pen.FinishAt or 0),
			HasReadyEgg = now >= (pen.FinishAt or 0),
		})
	end

	return {
		MaxPetCapacity = petsData.MaxPetCapacity or PetConfig.DefaultMaxPetCapacity,
		MaxEquippedCombat = petsData.MaxEquippedCombat or PetConfig.DefaultMaxEquippedCombat,
		Pets = petList,
		Incubators = incList,
		BreedingPens = penList,
	}
end

function PetService:IsObjectBusy(player: Player, objectId: string?): (boolean, string?)
	if type(objectId) ~= "string" or objectId == "" then
		return false, nil
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, nil
	end
	local petsData = ensurePetsProfile(profile)
	if petsData.Incubators[objectId] ~= nil then
		return true, "ไม่สามารถลบเครื่องฟักไข่ขณะมีไข่กำลังฟักอยู่ได้"
	end
	if petsData.BreedingPens[objectId] ~= nil then
		return true, "ไม่สามารถลบคอกผสมพันธุ์ขณะกำลังผสมพันธุ์หรือมีไข่รอรับอยู่ได้"
	end
	return false, nil
end

function PetService:ValidatePlotObject(player: Player, objectId: string, expectedName: string): boolean
	local plotModel = PlotService:GetPlayerPlotModel(player)
	if not plotModel then
		return false
	end
	local objectsFolder = plotModel:FindFirstChild("Objects")
	if not objectsFolder then
		return false
	end
	for _, obj in objectsFolder:GetChildren() do
		if obj:GetAttribute("ObjectId") == objectId and obj.Name == expectedName then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - obj:GetPivot().Position).Magnitude <= 24 then
				return true
			end
		end
	end
	return false
end

function PetService:SyncPlayerModels(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local petsData = ensurePetsProfile(profile)
	local plotModel = PlotService:GetPlayerPlotModel(player)

	PetPlotBrain.SyncPlayerPlotPets(player, plotModel, petsData.Instances)
	PetCombatController.SyncPlayerCombatPets(player, petsData.Instances)
end

function PetService:SyncToClient(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local petsData = ensurePetsProfile(profile)
	Network.PetNetwork.SyncState.sendTo(buildClientPayload(petsData), player)
end

function PetService.Client:GetPetsState(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	return buildClientPayload(ensurePetsProfile(profile))
end

local function onPlayerLoaded(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player:IsDescendantOf(Players) then
		return
	end

	local petsData = ensurePetsProfile(profile)
	local now = os.time()
	for _, pet in petsData.Instances do
		PetGrowthManager.ApplyHungerDecay(pet, now)
	end

	PetService:SyncPlayerModels(player)
	PetService:SyncToClient(player)
end

function PetService:KnitInit()
	PlotService:RegisterDeleteValidator(function(player: Player, objectModel: Model)
		local objectId = objectModel:GetAttribute("ObjectId")
		if type(objectId) == "string" then
			local busy, reason = PetService:IsObjectBusy(player, objectId)
			if busy then
				return false, reason
			end
		end
		return true, nil
	end)

	PlotService:OnPlotLoaded(function(player: Player)
		PetService:SyncPlayerModels(player)
		PetService:SyncToClient(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPacketAt[player] = nil
		PetPlotBrain.ClearPlayer(player)
		PetCombatController.ClearPlayer(player)
	end)
end

function PetService:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerLoaded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerLoaded, player)
	end)

	Network.PetNetwork.RequestSync.listen(function(_, player)
		if not checkRateLimit(player) then return end
		PetService:SyncPlayerModels(player)
		PetService:SyncToClient(player)
	end)

	Network.PetNetwork.FeedPet.listen(function(data, player)
		if not checkRateLimit(player) then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)
		local pet = petsData.Instances[data.PetUID]
		if not pet then return end

		local ok, msg = PetGrowthManager.FeedPet(player, pet, data.FoodItemId, InventoryService)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			Network.PetNetwork.PetVisualEvent.sendToAll({
				PetUID = data.PetUID,
				EventType = "Eat",
				TargetPos = nil,
			})
			PetService:SyncPlayerModels(player)
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.TriggerEvolve.listen(function(data, player)
		if not checkRateLimit(player) then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)
		local pet = petsData.Instances[data.PetUID]
		if not pet then return end

		local ok, msg = PetGrowthManager.TryEvolve(player, pet, data.CatalystItemId, InventoryService)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			Network.PetNetwork.PetVisualEvent.sendToAll({
				PetUID = data.PetUID,
				EventType = "Evolve",
				TargetPos = nil,
			})
			PetService:SyncPlayerModels(player)
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.SetPetState.listen(function(data, player)
		if not checkRateLimit(player) then return end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local pets = ensurePetsProfile(profile)
		local pet = pets.Instances[data.PetUID]
		if not pet or pet.State == "Breeding" then return end

		if data.TargetState == "Equipped" then
			local equippedCount = 0
			for _, p in pets.Instances do
				if p.State == "Equipped" and p.UID ~= pet.UID then
					equippedCount += 1
				end
			end
			if equippedCount >= pets.MaxEquippedCombat then
				Network.PetNetwork.NotifyToast.sendTo({
					IsError = true,
					Message = "เลือกสัตว์เลี้ยงร่วมต่อสู้ได้สูงสุด " .. tostring(pets.MaxEquippedCombat) .. " ตัว",
				}, player)
				return
			end
		end

		if data.TargetState == "InPlot" or data.TargetState == "Equipped" or data.TargetState == "Stored" then
			pet.State = data.TargetState
			PetService:SyncPlayerModels(player)
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.StartIncubation.listen(function(data, player)
		if not checkRateLimit(player) then return end
		if not PetService:ValidatePlotObject(player, data.ObjectId, "pet_incubator") then
			Network.PetNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "กรุณาเข้าใกล้เครื่องฟักไข่ใน Plot ของคุณ",
			}, player)
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)

		local ok, msg = PetEggBreedingManager.StartIncubation(
			player,
			petsData,
			data.ObjectId,
			data.EggItemId,
			InventoryService
		)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.ClaimHatchedPet.listen(function(data, player)
		if not checkRateLimit(player) then return end
		if not PetService:ValidatePlotObject(player, data.ObjectId, "pet_incubator") then
			Network.PetNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "กรุณาเข้าใกล้เครื่องฟักไข่ใน Plot ของคุณ",
			}, player)
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)

		local ok, msg, newPet = PetEggBreedingManager.ClaimHatchedPet(petsData, data.ObjectId)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			PetService:SyncPlayerModels(player)
			if newPet then
				Network.PetNetwork.PetVisualEvent.sendToAll({
					PetUID = newPet.UID,
					EventType = "Hatch",
					TargetPos = nil,
				})
			end
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.StartBreeding.listen(function(data, player)
		if not checkRateLimit(player) then return end
		if not PetService:ValidatePlotObject(player, data.ObjectId, "breeding_pen") then
			Network.PetNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "กรุณาเข้าใกล้คอกผสมพันธุ์ใน Plot ของคุณ",
			}, player)
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)

		local ok, msg = PetEggBreedingManager.StartBreeding(
			petsData,
			data.ObjectId,
			data.ParentA_UID,
			data.ParentB_UID
		)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			PetService:SyncPlayerModels(player)
			PetService:SyncToClient(player)
		end
	end)

	Network.PetNetwork.ClaimBreedingEgg.listen(function(data, player)
		if not checkRateLimit(player) then return end
		if not PetService:ValidatePlotObject(player, data.ObjectId, "breeding_pen") then
			Network.PetNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "กรุณาเข้าใกล้คอกผสมพันธุ์ใน Plot ของคุณ",
			}, player)
			return
		end
		local profile = DataService.GetProfile(player)
		if not profile then return end
		local petsData = ensurePetsProfile(profile)

		local ok, msg = PetEggBreedingManager.ClaimBreedingEgg(player, petsData, data.ObjectId, InventoryService)
		Network.PetNetwork.NotifyToast.sendTo({ IsError = not ok, Message = msg }, player)
		if ok then
			PetService:SyncPlayerModels(player)
			PetService:SyncToClient(player)
		end
	end)

	-- ลูปจำลองพฤติกรรมสัตว์เลี้ยงในฟาร์มและผู้ช่วยต่อสู้แบบประหยัดทรัพยากร
	task.spawn(function()
		local lastHungerCheck = os.time()
		while true do
			task.wait(SIM_STEP)
			local now = os.time()
			local shouldCheckHunger = (now - lastHungerCheck) >= 60
			if shouldCheckHunger then
				lastHungerCheck = now
			end

			for _, player in Players:GetPlayers() do
				local profile = DataService.GetProfile(player)
				if not profile then
					continue
				end
				local petsData = ensurePetsProfile(profile)

				if shouldCheckHunger then
					local decayed = false
					for _, pet in petsData.Instances do
						if PetGrowthManager.ApplyHungerDecay(pet, now) then
							decayed = true
						end
					end
					if decayed then
						PetService:SyncToClient(player)
					end
				end

				local plotModel = PlotService:GetPlayerPlotModel(player)
				PetPlotBrain.StepWandering(player, plotModel, petsData.Instances, SIM_STEP)
				PetCombatController.StepPlayerCompanions(
					player,
					petsData.Instances,
					EnemyController,
					function(petUID: string, targetPos: Vector3)
						Network.PetNetwork.PetVisualEvent.sendToAll({
							PetUID = petUID,
							EventType = "Attack",
							TargetPos = targetPos,
						})
					end
				)
			end
		end
	end)
end

return PetService
