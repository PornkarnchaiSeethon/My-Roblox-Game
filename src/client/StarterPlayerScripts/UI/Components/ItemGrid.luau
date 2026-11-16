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
	local children = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 72),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local visibleCount = 0
	if props.data then
		for _, stackData in props.data.Stacks do
			if isVisible(stackData, props.selectedTab) then
				visibleCount += 1
				local isSelected = props.selectedStackId == stackData.StackId
				children["Stack" .. stackData.StackId] = e(ItemCard, {
					stackData = stackData,
					isSelected = isSelected,
					onSelect = function()
						props.onSelectStack(if isSelected then nil else stackData.StackId)
					end,
				})
			end
		end
	end

	if visibleCount == 0 then
		children.Empty = e("TextLabel", {
			Size = UDim2.new(1, -16, 0, 50),
			BackgroundTransparency = 1,
			Text = "No items",
			TextColor3 = Color3.fromRGB(220, 220, 220),
			TextSize = 20,
		})
	end

	return e("ScrollingFrame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, children)
end

return ItemGrid
