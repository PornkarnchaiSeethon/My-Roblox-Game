local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

type Props = {
	stackData: Types.ClientStackData,
	isSelected: boolean,
	onSelect: () -> (),
}

local TYPE_COLORS: { [string]: Color3 } = {
	Weapon = Color3.fromRGB(235, 85, 85),
	Resource = Color3.fromRGB(85, 195, 120),
	Armor = Color3.fromRGB(90, 155, 245),
	Consumable = Color3.fromRGB(240, 175, 70),
	Special = Color3.fromRGB(185, 110, 245),
}

local function ItemCard(props: Props)
	local stackData = props.stackData
	local displayName = stackData.DisplayName or stackData.Name
	local hasImage = stackData.Image ~= nil and stackData.Image ~= ""
	local typeColor = TYPE_COLORS[stackData.ItemType] or Color3.fromRGB(140, 150, 175)
	local shortCode = string.upper(string.sub(displayName, 1, 2))

	return e("TextButton", {
		LayoutOrder = stackData.StackId,
		Size = UDim2.fromOffset(152, 74),
		BackgroundColor3 = if props.isSelected
			then Color3.fromRGB(44, 52, 74)
			else Color3.fromRGB(30, 34, 46),
		AutoButtonColor = true,
		Text = "",
		[React.Event.Activated] = props.onSelect,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = if props.isSelected then 2 else 1,
			Color = if props.isSelected
				then Color3.fromRGB(255, 200, 75)
				else Color3.fromRGB(52, 58, 76),
		}),

		TypeStripe = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 0.65, 0),
			BackgroundColor3 = typeColor,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		IconBox = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Color3.fromRGB(20, 23, 32),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(45, 50, 68),
			}),
			Image = hasImage and e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(38, 38),
				Image = stackData.Image,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
			}),
			FallbackText = (not hasImage) and e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = shortCode,
				Font = Enum.Font.GothamBlack,
				TextSize = 16,
				TextColor3 = typeColor,
			}),
		}),

		NameLabel = e("TextLabel", {
			Position = UDim2.fromOffset(66, 8),
			Size = UDim2.new(1, -74, 0, 34),
			BackgroundTransparency = 1,
			Text = displayName,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = if props.isSelected
				then Color3.fromRGB(255, 235, 165)
				else Color3.fromRGB(235, 240, 250),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),

		TypeLabel = e("TextLabel", {
			Position = UDim2.fromOffset(66, 44),
			Size = UDim2.new(1, -110, 0, 18),
			BackgroundTransparency = 1,
			Text = stackData.ItemType,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = typeColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CountBadge = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(36, 20),
			BackgroundColor3 = Color3.fromRGB(18, 20, 28),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(52, 58, 76),
			}),
			Text = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = `x{stackData.Count}`,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(220, 228, 245),
			}),
		}),
	})
end

return ItemCard
