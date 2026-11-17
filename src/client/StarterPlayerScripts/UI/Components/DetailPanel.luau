local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

type Props = {
	stackData: Types.ClientStackData?,
	isEquipped: boolean,
	equipSlot: number?,
	onDrop: (stackId: number) -> (),
	onEquip: (stackId: number, slotNum: number) -> (),
	onUnequip: (stackId: number) -> (),
	position: UDim2?,
	size: UDim2?,
}

local TYPE_COLORS: { [string]: Color3 } = {
	Weapon = Color3.fromRGB(235, 85, 85),
	Resource = Color3.fromRGB(85, 195, 120),
	Armor = Color3.fromRGB(90, 155, 245),
	Consumable = Color3.fromRGB(240, 175, 70),
	Special = Color3.fromRGB(185, 110, 245),
}

local function DetailPanel(props: Props)
	local stackData = props.stackData
	if not stackData then
		return e("Frame", {
			Position = props.position or UDim2.new(),
			Size = props.size or UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(17, 19, 26),
			BackgroundTransparency = 0.15,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
			Empty = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "Select an item to view details",
				Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(130, 140, 165),
				TextSize = 14,
				TextWrapped = true,
			}),
		})
	end

	local displayName = stackData.DisplayName or stackData.Name
	local hasImage = stackData.Image ~= nil and stackData.Image ~= ""
	local typeColor = TYPE_COLORS[stackData.ItemType] or Color3.fromRGB(140, 150, 175)
	local shortCode = string.upper(string.sub(displayName, 1, 2))
	local canEquip = props.equipSlot ~= nil and stackData.ItemType ~= "Armor"
	local hasEquipAction = props.isEquipped or canEquip
	local hasDropAction = stackData.IsDroppable

	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(52, 58, 76) }),

		PreviewBox = e("Frame", {
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Color3.fromRGB(26, 29, 40),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1.5, Color = typeColor }),
			Image = hasImage and e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(50, 50),
				Image = stackData.Image,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
			}),
			Fallback = (not hasImage) and e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = shortCode,
				Font = Enum.Font.GothamBlack,
				TextSize = 22,
				TextColor3 = typeColor,
			}),
		}),

		Name = e("TextLabel", {
			Position = UDim2.fromOffset(88, 14),
			Size = UDim2.new(1, -100, 0, 26),
			BackgroundTransparency = 1,
			Text = displayName,
			Font = Enum.Font.GothamBlack,
			TextSize = 17,
			TextColor3 = Color3.fromRGB(245, 247, 255),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		TypeBadge = e("Frame", {
			Position = UDim2.fromOffset(88, 44),
			Size = UDim2.fromOffset(78, 22),
			BackgroundColor3 = Color3.fromRGB(28, 32, 44),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = typeColor }),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = stackData.ItemType,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = typeColor,
			}),
		}),

		CountBadge = e("Frame", {
			Position = UDim2.fromOffset(172, 44),
			Size = UDim2.fromOffset(56, 22),
			BackgroundColor3 = Color3.fromRGB(28, 32, 44),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(58, 65, 86) }),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = `x{stackData.Count}`,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(220, 228, 245),
			}),
		}),

		Divider = e("Frame", {
			Position = UDim2.fromOffset(14, 90),
			Size = UDim2.new(1, -28, 0, 1),
			BackgroundColor3 = Color3.fromRGB(45, 50, 66),
			BorderSizePixel = 0,
		}),

		DescriptionBox = e("Frame", {
			Position = UDim2.fromOffset(14, 102),
			Size = UDim2.new(1, -28, 1, -166),
			BackgroundColor3 = Color3.fromRGB(22, 25, 35),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			Description = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = stackData.Description ~= "" and stackData.Description or "No description available for this item.",
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(190, 198, 220),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		}),
	}

	if props.isEquipped then
		children.Unequip = e("TextButton", {
			Position = UDim2.new(0, 14, 1, -52),
			Size = if hasDropAction then UDim2.new(0.5, -18, 0, 38) else UDim2.new(1, -28, 0, 38),
			BackgroundColor3 = Color3.fromRGB(75, 82, 102),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = "Unequip",
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.onUnequip(stackData.StackId)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	elseif canEquip then
		children.Equip = e("TextButton", {
			Position = UDim2.new(0, 14, 1, -52),
			Size = if hasDropAction then UDim2.new(0.5, -18, 0, 38) else UDim2.new(1, -28, 0, 38),
			BackgroundColor3 = Color3.fromRGB(48, 165, 95),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = `Equip (#{props.equipSlot})`,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.onEquip(stackData.StackId, props.equipSlot :: number)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	end

	if hasDropAction then
		children.Drop = e("TextButton", {
			Position = if hasEquipAction
				then UDim2.new(0.5, 4, 1, -52)
				else UDim2.new(0, 14, 1, -52),
			Size = if hasEquipAction
				then UDim2.new(0.5, -18, 0, 38)
				else UDim2.new(1, -28, 0, 38),
			BackgroundColor3 = Color3.fromRGB(205, 65, 75),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = "Drop",
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.onDrop(stackData.StackId)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	end

	return e("Frame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(17, 19, 26),
		BackgroundTransparency = 0.15,
	}, children)
end

return DetailPanel
