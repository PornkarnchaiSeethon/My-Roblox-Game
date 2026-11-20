local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local MainFrame = require(script.Parent.UI.MainFrame)

local storyClient = {
	Data = {
		Hotbar = {
			Slot1 = 1,
			Slot2 = 2,
		},
		NextStackId = 4,
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
		},
	},
	SelectedStackId = nil,
	IsOpen = false,
	LastError = nil,
	Subscribe = function()
		return function() end
	end,
	HoldItem = function() end,
	SelectStack = function() end,
	SetWindowOpen = function() end,
	DropItem = function() end,
	EquipToHotbar = function() end,
	UnequipFromHotbar = function() end,
	ClearError = function() end,
}

local storyPetClient = {
	State = {
		IsBarnOpen = true,
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
	Subscribe = function()
		return function() end
	end,
	ToggleBarn = function() end,
	SetBarnOpen = function() end,
	SelectPet = function() end,
	CloseModal = function() end,
	ClearToast = function() end,
	FeedPet = function() end,
	TriggerEvolve = function() end,
	SetPetState = function() end,
	StartIncubation = function() end,
	ClaimHatchedPet = function() end,
	StartBreeding = function() end,
	ClaimBreedingEgg = function() end,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	renderer = "deferred",
	story = function()
		return React.createElement(MainFrame, {
			client = storyClient,
			petClient = storyPetClient,
		})
	end,
}
