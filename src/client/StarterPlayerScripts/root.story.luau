local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local MainFrame = require(script.Parent.UI.MainFrame)

local invListeners: { () -> () } = {}
local petListeners: { () -> () } = {}
local plantListeners: { () -> () } = {}
local adminListeners: { () -> () } = {}
local npcListeners: { () -> () } = {}
local npcBossListeners: { () -> () } = {}
local npcDialogueListeners: { () -> () } = {}
local npcToastListeners: { () -> () } = {}

local function notifyList(list: { () -> () })
	for _, fn in list do
		fn()
	end
end

local storyClient
storyClient = {
	Data = {
		Hotbar = {
			Slot1 = 1,
			Slot2 = 4,
			Slot3 = 5,
		},
		NextStackId = 11,
		Stacks = {
			{
				Name = "iron_sword",
				DisplayName = "Iron Sword",
				Description = "A sturdy blade",
				Image = "",
				ItemType = "Weapon",
				IsDroppable = true,
				Count = 1,
				StackId = 1,
			},
			{
				Name = "berry_feed",
				DisplayName = "Berry Feed",
				Description = "อาหารผลไม้สำหรับสัตว์เลี้ยงในฟาร์ม",
				Image = "",
				ItemType = "Consumable",
				IsDroppable = true,
				Count = 12,
				StackId = 2,
			},
			{
				Name = "forest_egg",
				DisplayName = "Forest Pet Egg",
				Description = "ไข่สัตว์เลี้ยงป่า นำไปฟักที่เครื่องฟักไข่ใน Plot",
				Image = "",
				ItemType = "Special",
				IsDroppable = false,
				Count = 2,
				StackId = 3,
			},
			{
				Name = "watering_can",
				DisplayName = "Watering Can",
				Description = "บัวรดน้ำประจำฟาร์ม ใช้รดน้ำเพิ่มความชุ่มชื้นให้แปลงผัก",
				Image = "",
				ItemType = "Special",
				IsDroppable = false,
				Count = 1,
				StackId = 4,
			},
			{
				Name = "carrot_seed",
				DisplayName = "Carrot Seed",
				Description = "เมล็ดแครอท โตไว เหมาะสำหรับผู้เริ่มต้นทำฟาร์ม",
				Image = "",
				ItemType = "Resource",
				IsDroppable = true,
				Count = 8,
				StackId = 5,
			},
			{
				Name = "berry_seed",
				DisplayName = "Forest Berry Seed",
				Description = "เมล็ดเบอร์รี่ป่า เก็บเกี่ยวซ้ำได้ 3 รอบ",
				Image = "",
				ItemType = "Resource",
				IsDroppable = true,
				Count = 5,
				StackId = 6,
			},
			{
				Name = "moon_herb_seed",
				DisplayName = "Moonlight Herb Seed",
				Description = "เมล็ดสมุนไพรจันทรา วัตถุดิบสำคัญสำหรับปรุงโพชัน",
				Image = "",
				ItemType = "Resource",
				IsDroppable = true,
				Count = 3,
				StackId = 7,
			},
			{
				Name = "golden_apple_seed",
				DisplayName = "Golden Apple Seed",
				Description = "เมล็ดแอปเปิลทองคำหายาก เก็บเกี่ยวซ้ำได้ 2 รอบ",
				Image = "",
				ItemType = "Special",
				IsDroppable = false,
				Count = 1,
				StackId = 8,
			},
			{
				Name = "compost_fertilizer",
				DisplayName = "Compost Fertilizer",
				Description = "ปุ๋ยหมักอินทรีย์ เร่งความเร็วการเติบโตของพืช 35%",
				Image = "",
				ItemType = "Consumable",
				IsDroppable = true,
				Count = 6,
				StackId = 9,
			},
			{
				Name = "mystic_fertilizer",
				DisplayName = "Mystic Fertilizer",
				Description = "ปุ๋ยเวทมนตร์ เพิ่มจำนวนผลผลิตตอนเก็บเกี่ยว +1 ถึง +2 ชิ้น",
				Image = "",
				ItemType = "Consumable",
				IsDroppable = false,
				Count = 2,
				StackId = 10,
			},
		},
	},
	SelectedStackId = nil,
	IsOpen = false,
	LastError = nil,
	Subscribe = function(callback)
		table.insert(invListeners, callback)
		return function()
			local idx = table.find(invListeners, callback)
			if idx then
				table.remove(invListeners, idx)
			end
		end
	end,
	HoldItem = function() end,
	SelectStack = function(stackId)
		storyClient.SelectedStackId = stackId
		notifyList(invListeners)
	end,
	SetWindowOpen = function(isOpen)
		storyClient.IsOpen = isOpen
		notifyList(invListeners)
	end,
	DropItem = function() end,
	EquipToHotbar = function() end,
	UnequipFromHotbar = function() end,
	ClearError = function()
		storyClient.LastError = nil
		notifyList(invListeners)
	end,
}

local storyPetClient
storyPetClient = {
	State = {
		IsBarnOpen = false,
		SelectedPetUID = "pet_story_1",
		ActiveModal = nil,
		MaxPetCapacity = 20,
		MaxEquippedCombat = 3,
		Pets = {
			{
				UID = "pet_story_1",
				SpeciesId = "sprout_slime",
				Nickname = "Sprouty",
				Stage = "Adult",
				Level = 7,
				GrowthExp = 820,
				Hunger = 82,
				PotentialBonus = 1.12,
				State = "InPlot",
				BreedCooldownUntil = 0,
			},
			{
				UID = "pet_story_2",
				SpeciesId = "moss_wolf",
				Nickname = "Mossy",
				Stage = "Juvenile",
				Level = 4,
				GrowthExp = 240,
				Hunger = 55,
				PotentialBonus = 1.08,
				State = "Equipped",
				BreedCooldownUntil = 0,
			},
		},
		Incubators = {},
		BreedingPens = {},
		Toast = nil,
	},
	Subscribe = function(callback)
		table.insert(petListeners, callback)
		return function()
			local idx = table.find(petListeners, callback)
			if idx then
				table.remove(petListeners, idx)
			end
		end
	end,
	ToggleBarn = function()
		storyPetClient.State.IsBarnOpen = not storyPetClient.State.IsBarnOpen
		notifyList(petListeners)
	end,
	SetBarnOpen = function(isOpen)
		storyPetClient.State.IsBarnOpen = isOpen
		notifyList(petListeners)
	end,
	SelectPet = function(uid)
		storyPetClient.State.SelectedPetUID = uid
		notifyList(petListeners)
	end,
	CloseModal = function()
		storyPetClient.State.ActiveModal = nil
		notifyList(petListeners)
	end,
	ClearToast = function()
		storyPetClient.State.Toast = nil
		notifyList(petListeners)
	end,
	FeedPet = function() end,
	TriggerEvolve = function() end,
	SetPetState = function() end,
	StartIncubation = function() end,
	ClaimHatchedPet = function() end,
	StartBreeding = function() end,
	ClaimBreedingEgg = function() end,
}

local storyNow = os.time()
local storyPlantClient
storyPlantClient = {
	State = {
		IsAlmanacOpen = true,
		ActiveModal = nil,
		PlantersById = {
			planter_story_1 = {
				ObjectId = "planter_story_1",
				PlanterType = "fertile_garden_bed",
				CropId = "berry_seed",
				Stage = "Mature",
				GrowthProgress = 1.0,
				MoistureUntil = storyNow + 75,
				FertilizerId = "mystic_fertilizer",
				HarvestsRemaining = 3,
			},
			planter_story_2 = {
				ObjectId = "planter_story_2",
				PlanterType = "wooden_planter",
				CropId = "carrot_seed",
				Stage = "Growing",
				GrowthProgress = 0.68,
				MoistureUntil = storyNow + 42,
				FertilizerId = "compost_fertilizer",
				HarvestsRemaining = 1,
			},
			planter_story_3 = {
				ObjectId = "planter_story_3",
				PlanterType = "wooden_planter",
				CropId = "moon_herb_seed",
				Stage = "Sprout",
				GrowthProgress = 0.34,
				MoistureUntil = 0,
				FertilizerId = "",
				HarvestsRemaining = 1,
			},
		},
		HarvestStats = {
			carrot_seed = 14,
			berry_seed = 9,
			moon_herb_seed = 3,
			golden_apple_seed = 1,
		},
		Toast = nil,
	},
	Subscribe = function(callback)
		table.insert(plantListeners, callback)
		return function()
			local idx = table.find(plantListeners, callback)
			if idx then
				table.remove(plantListeners, idx)
			end
		end
	end,
	ToggleAlmanac = function()
		storyPlantClient.State.IsAlmanacOpen = not storyPlantClient.State.IsAlmanacOpen
		if storyPlantClient.State.IsAlmanacOpen then
			storyPlantClient.State.ActiveModal = nil
		end
		notifyList(plantListeners)
	end,
	SetAlmanacOpen = function(isOpen)
		storyPlantClient.State.IsAlmanacOpen = isOpen
		if isOpen then
			storyPlantClient.State.ActiveModal = nil
		end
		notifyList(plantListeners)
	end,
	CloseModal = function()
		storyPlantClient.State.ActiveModal = nil
		notifyList(plantListeners)
	end,
	ClearToast = function()
		storyPlantClient.State.Toast = nil
		notifyList(plantListeners)
	end,
	PlantSeed = function() end,
	WaterPlant = function(objectId)
		local planter = storyPlantClient.State.PlantersById[objectId]
		if planter then
			planter.MoistureUntil = os.time() + 90
			storyPlantClient.State.Toast = { IsError = false, Message = "รดน้ำแปลงปลูกเรียบร้อยแล้ว!" }
			notifyList(plantListeners)
		end
	end,
	ApplyFertilizer = function() end,
	HarvestCrop = function(objectId)
		local planter = storyPlantClient.State.PlantersById[objectId]
		if planter then
			storyPlantClient.State.PlantersById[objectId] = nil
			storyPlantClient.State.HarvestStats[planter.CropId] = (storyPlantClient.State.HarvestStats[planter.CropId] or 0) + 1
			storyPlantClient.State.Toast = { IsError = false, Message = "เก็บเกี่ยวผลผลิตสำเร็จ!" }
			notifyList(plantListeners)
		end
	end,
	UprootPlant = function() end,
}

local storyAdminDetailsById = {
	[1001] = {
		UserId = 1001,
		Name = "DevAdmin",
		DisplayName = "DevAdmin",
		AccountAge = 1240,
		Level = 25,
		CurrentExp = 1850,
		ExpForNextLevel = 2500,
		Cash = 48500,
		LogInTimes = 64,
		WalkSpeed = 16,
		Health = 100,
		MaxHealth = 100,
		StackCount = 4,
		MaxStacks = 30,
		PetCount = 2,
		ActivePlanters = 3,
		PlotObjectCount = 12,
		Items = {
			{
				StackId = 1,
				ItemId = "normal_Sword",
				DisplayName = "Normal Sword",
				ItemType = "Weapon",
				Count = 1,
				HotbarSlot = 1,
			},
			{
				StackId = 2,
				ItemId = "watering_can",
				DisplayName = "Watering Can",
				ItemType = "Special",
				Count = 1,
				HotbarSlot = 2,
			},
			{
				StackId = 3,
				ItemId = "carrot_seed",
				DisplayName = "Carrot Seed",
				ItemType = "Resource",
				Count = 8,
				HotbarSlot = 3,
			},
			{
				StackId = 4,
				ItemId = "berry_feed",
				DisplayName = "Berry Feed",
				ItemType = "Consumable",
				Count = 12,
				HotbarSlot = 0,
			},
		},
	},
	[1002] = {
		UserId = 1002,
		Name = "FarmerBob",
		DisplayName = "BobTheFarmer",
		AccountAge = 320,
		Level = 9,
		CurrentExp = 420,
		ExpForNextLevel = 900,
		Cash = 3250,
		LogInTimes = 15,
		WalkSpeed = 16,
		Health = 92,
		MaxHealth = 100,
		StackCount = 2,
		MaxStacks = 30,
		PetCount = 1,
		ActivePlanters = 2,
		PlotObjectCount = 7,
		Items = {
			{
				StackId = 1,
				ItemId = "berry_seed",
				DisplayName = "Forest Berry Seed",
				ItemType = "Resource",
				Count = 5,
				HotbarSlot = 1,
			},
			{
				StackId = 2,
				ItemId = "compost_fertilizer",
				DisplayName = "Compost Fertilizer",
				ItemType = "Consumable",
				Count = 4,
				HotbarSlot = 0,
			},
		},
	},
}

local storyAdminClient
storyAdminClient = {
	State = {
		IsAdmin = true,
		IsOpen = false,
		ActiveTab = "Players",
		PlayersList = {
			{
				UserId = 1001,
				Name = "DevAdmin",
				DisplayName = "DevAdmin",
				Level = 25,
				Cash = 48500,
				WalkSpeed = 16,
			},
			{
				UserId = 1002,
				Name = "FarmerBob",
				DisplayName = "BobTheFarmer",
				Level = 9,
				Cash = 3250,
				WalkSpeed = 16,
			},
		},
		SelectedUserId = 1001,
		SelectedPlayerDetail = storyAdminDetailsById[1001],
		SelfWalkSpeed = 16,
		MissingStudioItems = {},
		AuditLogs = {
			{
				Timestamp = storyNow - 180,
				AdminName = "DevAdmin",
				Action = "GiveItem",
				TargetName = "BobTheFarmer",
				Detail = "เสก normal_Sword x1 สำเร็จ",
			},
			{
				Timestamp = storyNow - 60,
				AdminName = "DevAdmin",
				Action = "SetSelfWalkSpeed",
				TargetName = "DevAdmin",
				Detail = "ปรับความเร็วเป็น 32",
			},
		},
		LastToast = nil,
	},
	Subscribe = function(callback)
		table.insert(adminListeners, callback)
		return function()
			local idx = table.find(adminListeners, callback)
			if idx then
				table.remove(adminListeners, idx)
			end
		end
	end,
	TogglePanel = function()
		storyAdminClient.State.IsOpen = not storyAdminClient.State.IsOpen
		notifyList(adminListeners)
	end,
	SetPanelOpen = function(isOpen)
		storyAdminClient.State.IsOpen = isOpen
		notifyList(adminListeners)
	end,
	SetTab = function(tab)
		storyAdminClient.State.ActiveTab = tab
		notifyList(adminListeners)
	end,
	SelectAndInspectPlayer = function(targetUserId)
		storyAdminClient.State.SelectedUserId = targetUserId
		storyAdminClient.State.SelectedPlayerDetail = storyAdminDetailsById[targetUserId]
		notifyList(adminListeners)
	end,
	RefreshPlayers = function()
		storyAdminClient.State.LastToast = {
			IsError = false,
			Message = "รีเฟรชรายชื่อผู้เล่นแล้ว (Story Mock)",
			Timestamp = os.time(),
		}
		notifyList(adminListeners)
	end,
	GiveItemToTarget = function(targetUserId, itemId, amount)
		local targetDetail = storyAdminDetailsById[targetUserId]
		local targetName = if targetDetail then targetDetail.DisplayName else tostring(targetUserId)
		local nextLogs = table.clone(storyAdminClient.State.AuditLogs)
		table.insert(nextLogs, 1, {
			Timestamp = os.time(),
			AdminName = "DevAdmin",
			Action = "GiveItem",
			TargetName = targetName,
			Detail = `เสก {itemId} x{amount} ให้ {targetName}`,
		})
		storyAdminClient.State.AuditLogs = nextLogs
		storyAdminClient.State.LastToast = {
			IsError = false,
			Message = `เสก {itemId} x{amount} ให้ {targetName} สำเร็จ!`,
			Timestamp = os.time(),
		}
		notifyList(adminListeners)
	end,
	GiveItemToSelf = function(itemId, amount)
		storyAdminClient.GiveItemToTarget(1001, itemId, amount)
	end,
	SetSelfWalkSpeed = function(walkSpeed)
		storyAdminClient.State.SelfWalkSpeed = walkSpeed
		local nextPlayers = table.clone(storyAdminClient.State.PlayersList)
		local updatedSelfSummary = table.clone(nextPlayers[1])
		updatedSelfSummary.WalkSpeed = walkSpeed
		nextPlayers[1] = updatedSelfSummary
		storyAdminClient.State.PlayersList = nextPlayers

		local updatedSelfDetail = table.clone(storyAdminDetailsById[1001])
		updatedSelfDetail.WalkSpeed = walkSpeed
		storyAdminDetailsById[1001] = updatedSelfDetail
		if storyAdminClient.State.SelectedUserId == 1001 then
			storyAdminClient.State.SelectedPlayerDetail = updatedSelfDetail
		end

		local nextLogs = table.clone(storyAdminClient.State.AuditLogs)
		table.insert(nextLogs, 1, {
			Timestamp = os.time(),
			AdminName = "DevAdmin",
			Action = "SetSelfWalkSpeed",
			TargetName = "DevAdmin",
			Detail = `ปรับความเร็วเป็น {walkSpeed}`,
		})
		storyAdminClient.State.AuditLogs = nextLogs
		storyAdminClient.State.LastToast = {
			IsError = false,
			Message = `ปรับความเร็วเดินเป็น {walkSpeed} เรียบร้อยแล้ว`,
			Timestamp = os.time(),
		}
		notifyList(adminListeners)
	end,
	ClearToast = function()
		storyAdminClient.State.LastToast = nil
		notifyList(adminListeners)
	end,
}

local storyNPCClient
storyNPCClient = {
	State = {
		ActiveBosses = {
			{
				NPCUID = "boss_story_1",
				DisplayName = "Ancient Forest Golem [BOSS]",
				Level = 12,
				HP = 840,
				MaxHP = 1250,
				CastingSkillName = "พสุธากัมปนาท (Earthshatter Slam)",
			},
		},
		ActiveDialogue = {
			NPCUID = "npc_story_1",
			DisplayName = "ผู้เฒ่าโรแวน (Elder Rowan)",
			Lines = {
				"ยินดีต้อนรับสู่ดินแดนฟาร์มและผจญภัย! คุณสามารถปลูกพืชใน Plot [H] และฟักไข่สัตว์เลี้ยง [P] เพื่อสร้างทีมต่อสู้ได้",
				"ระวังวงเตือนสีแดงบนพื้นเมื่อต่อสู้กับมอนสเตอร์ป่าและ Ancient Forest Golem เพราะสกิลของพวกมันรุนแรงมาก!",
			},
		},
		LastToast = nil,
	},
	Subscribe = function(callback)
		table.insert(npcListeners, callback)
		return function()
			local idx = table.find(npcListeners, callback)
			if idx then
				table.remove(npcListeners, idx)
			end
		end
	end,
	SubscribeBosses = function(callback)
		table.insert(npcBossListeners, callback)
		return function()
			local idx = table.find(npcBossListeners, callback)
			if idx then
				table.remove(npcBossListeners, idx)
			end
		end
	end,
	SubscribeDialogue = function(callback)
		table.insert(npcDialogueListeners, callback)
		return function()
			local idx = table.find(npcDialogueListeners, callback)
			if idx then
				table.remove(npcDialogueListeners, idx)
			end
		end
	end,
	SubscribeToast = function(callback)
		table.insert(npcToastListeners, callback)
		return function()
			local idx = table.find(npcToastListeners, callback)
			if idx then
				table.remove(npcToastListeners, idx)
			end
		end
	end,
	CloseDialogue = function()
		storyNPCClient.State.ActiveDialogue = nil
		notifyList(npcDialogueListeners)
		notifyList(npcListeners)
	end,
	ClearToast = function()
		storyNPCClient.State.LastToast = nil
		notifyList(npcToastListeners)
		notifyList(npcListeners)
	end,
	GetNearbyBoss = function()
		return storyNPCClient.State.ActiveBosses[1]
	end,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	renderer = "deferred",
	story = function()
		return React.createElement(MainFrame, {
			client = storyClient,
			petClient = storyPetClient,
			plantClient = storyPlantClient,
			adminClient = storyAdminClient,
			npcClient = storyNPCClient,
		})
	end,
}
