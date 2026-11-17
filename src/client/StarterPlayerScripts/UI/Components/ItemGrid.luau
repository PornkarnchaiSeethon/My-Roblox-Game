local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local ItemCard = require(script.Parent.ItemCard)
local e = React.createElement

type Props = {
	data: Types.ClientInventory?,
	selectedTab: string,
	selectedStackId: number?,
	onSelectStack: (stackId: number?) -> (),
	position: UDim2?,
	size: UDim2?,
}

local function isVisible(stackData: Types.ClientStackData, selectedTab: string): boolean
	return selectedTab == "All"
		or (selectedTab == "Tools" and (stackData.ItemType == "Special" or stackData.ItemType == "Consumable"))
		or (selectedTab == "Resources" and stackData.ItemType == "Resource")
		or (selectedTab == "Weapons" and stackData.ItemType == "Weapon")
		or (selectedTab == "Misc" and stackData.ItemType == "Armor")
end

local function ItemGrid(props: Props)
	local scrollChildren = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(152, 74),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local visibleCount = 0
	if props.data then
		for _, stackData in props.data.Stacks do
			if isVisible(stackData, props.selectedTab) then
				visibleCount += 1
				local isSelected = props.selectedStackId == stackData.StackId
				scrollChildren["Stack" .. stackData.StackId] = e(ItemCard, {
					stackData = stackData,
					isSelected = isSelected,
					onSelect = function()
						props.onSelectStack(if isSelected then nil else stackData.StackId)
					end,
				})
			end
		end
	end

	return e("Frame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(17, 19, 26),
		BackgroundTransparency = 0.15,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),

		Scroll = (visibleCount > 0) and e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, scrollChildren),

		Empty = (visibleCount == 0) and e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "No items in this category",
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(130, 140, 165),
			TextSize = 15,
		}),
	})
end

return ItemGrid
