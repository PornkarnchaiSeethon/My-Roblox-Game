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
		NextStackId = 3,
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
				Name = "oak_wood",
				DisplayName = "Oak Wood",
				Description = "Basic building material",
				Image = "",
				ItemType = "Resource",
				IsDroppable = true,
				Count = 10,
				StackId = 2,
			},
		},
	},
	SelectedStackId = nil,
	IsOpen = true,
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

return {
	react = React,
	reactRoblox = ReactRoblox,
	renderer = "deferred",
	story = function()
		return React.createElement(MainFrame, { client = storyClient })
	end,
}
