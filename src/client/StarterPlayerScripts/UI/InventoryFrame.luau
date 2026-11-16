local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local Components = script.Parent.Components
local DetailPanel = require(Components.DetailPanel)
local ItemGrid = require(Components.ItemGrid)
local TabBar = require(Components.TabBar)

local e = React.createElement

type Props = {
	data: Types.ClientInventory?,
	selectedStackId: number?,
	tabs: { string },
	onClose: () -> (),
	onSelectStack: (number?) -> (),
	onDrop: (stackId: number) -> (),
	onEquip: (stackId: number, slotNum: number) -> (),
	onUnequip: (stackId: number) -> (),
}

local function findStack(data: Types.ClientInventory?, stackId: number?): Types.ClientStackData?
	if not data or not stackId then
		return nil
	end

	for _, stackData in data.Stacks do
		if stackData.StackId == stackId then
			return stackData
		end
	end

	return nil
end

local function isEquipped(data: Types.ClientInventory?, stackId: number?): boolean
	if not data or not stackId then
		return false
	end

	for _, equippedStackId in data.Hotbar do
		if equippedStackId == stackId then
			return true
		end
	end

	return false
end

local function findEmptySlot(data: Types.ClientInventory?): number?
	for slotNum = 1, 10 do
		if not data or not data.Hotbar["Slot" .. slotNum] then
			return slotNum
		end
	end

	return nil
end

local function InventoryFrame(props: Props)
	local selectedTab, setSelectedTab = React.useState(props.tabs[1] or "All")
	local selectedStack = findStack(props.data, props.selectedStackId)
	local equipped = isEquipped(props.data, props.selectedStackId)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
	}, {
		Panel = e("Frame", {
			Size = UDim2.fromScale(0.72, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.43),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }),
			SizeLimit = e("UISizeConstraint", {
				MinSize = Vector2.new(620, 340),
				MaxSize = Vector2.new(1100, 700),
			}),

			Title = e("TextLabel", {
				Size = UDim2.fromOffset(190, 46),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.04),
				Rotation = -3,
				BackgroundTransparency = 1,
				Text = "Inventory",
				TextScaled = true,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 2,
			}, {
				Stroke = e("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }),
			}),

			Close = e("TextButton", {
				Size = UDim2.fromOffset(40, 40),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				Text = "X",
				TextScaled = true,
				FontFace = Font.fromEnum(Enum.Font.FredokaOne),
				TextColor3 = Color3.new(1, 1, 1),
				ZIndex = 3,
				[React.Event.Activated] = props.onClose,
			}),

			Tabs = e(TabBar, {
				position = UDim2.new(0, 12, 0, 64),
				size = UDim2.new(0.17, -16, 1, -76),
				tabs = props.tabs,
				selected = selectedTab,
				onSelect = setSelectedTab,
			}),

			Items = e(ItemGrid, {
				position = UDim2.new(0.18, 0, 0, 64),
				size = UDim2.new(0.49, -8, 1, -76),
				data = props.data,
				selectedTab = selectedTab,
				selectedStackId = props.selectedStackId,
				onSelectStack = props.onSelectStack,
			}),

			Details = e(DetailPanel, {
				position = UDim2.new(0.69, 0, 0, 64),
				size = UDim2.new(0.29, -12, 1, -76),
				stackData = selectedStack,
				isEquipped = equipped,
				equipSlot = if equipped then nil else findEmptySlot(props.data),
				onDrop = props.onDrop,
				onEquip = props.onEquip,
				onUnequip = props.onUnequip,
			}),
		}),
	})
end

return InventoryFrame
