local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local MainFrame = require(script.Parent.UI.MainFrame)

local invListeners: { () -> () } = {}
local petListeners: { () -> () } = {}
local plantListeners: { () -> () } = {}

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

return {
	react = React,
	reactRoblox = ReactRoblox,
	renderer = "deferred",
	story = function()
		return React.createElement(MainFrame, {
			client = storyClient,
			petClient = storyPetClient,
			plantClient = storyPlantClient,
		})
	end,
}
