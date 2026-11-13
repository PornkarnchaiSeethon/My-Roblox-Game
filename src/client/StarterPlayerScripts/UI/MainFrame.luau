local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Components = script.Parent.Components
local LevelBar = require(Components.LevelBar)
local InventoryFrame = require(script.Parent.InventoryFrame)
local HotbarSlot = require(script.Parent.HotbarSlot)

local e = React.createElement

local TABS = { "All", "Tools", "Resources", "Weapons", "Misc" }

local function MainFrame()
	local inventoryOpen, setInventoryOpen = React.useState(true)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		LevelBar = e(LevelBar),
		HotbarSlot = e(HotbarSlot),
		Inventory = inventoryOpen and e(InventoryFrame, {
			tabs = TABS,
			onClose = function()
				setInventoryOpen(false)
			end,
		}),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 4,
		}),
	})
end

return MainFrame