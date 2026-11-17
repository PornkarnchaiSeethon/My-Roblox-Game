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
	local totalStacks = if props.data then #props.data.Stacks else 0

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		BackgroundTransparency = 1,
	}, {
		Panel = e("Frame", {
			Size = UDim2.fromScale(0.74, 0.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			BackgroundColor3 = Color3.fromRGB(22, 24, 32),
			BackgroundTransparency = 0.04,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = e("UIStroke", {
				Thickness = 2,
				Color = Color3.fromRGB(62, 68, 88),
			}),
			SizeLimit = e("UISizeConstraint", {
				MinSize = Vector2.new(660, 380),
				MaxSize = Vector2.new(1080, 660),
			}),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundColor3 = Color3.fromRGB(28, 31, 42),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				BottomCover = e("Frame", {
					Position = UDim2.new(0, 0, 1, -14),
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundColor3 = Color3.fromRGB(28, 31, 42),
					BorderSizePixel = 0,
				}),
				Divider = e("Frame", {
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(50, 56, 74),
					BorderSizePixel = 0,
				}),
				Title = e("TextLabel", {
					Position = UDim2.fromOffset(20, 0),
					Size = UDim2.new(0.5, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "INVENTORY",
					Font = Enum.Font.GothamBlack,
					TextSize = 20,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CapacityBadge = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -64, 0.5, 0),
					Size = UDim2.fromOffset(82, 28),
					BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(52, 58, 76) }),
					Label = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `{totalStacks} / 20`,
						Font = Enum.Font.GothamBold,
						TextSize = 13,
						TextColor3 = Color3.fromRGB(180, 190, 215),
					}),
				}),
				Close = e("TextButton", {
					Size = UDim2.fromOffset(34, 34),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					BackgroundColor3 = Color3.fromRGB(210, 65, 75),
					Text = "X",
					Font = Enum.Font.GothamBlack,
					TextSize = 15,
					TextColor3 = Color3.new(1, 1, 1),
					AutoButtonColor = true,
					[React.Event.Activated] = props.onClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			Tabs = e(TabBar, {
				position = UDim2.new(0, 14, 0, 68),
				size = UDim2.new(0.18, -14, 1, -82),
				tabs = props.tabs,
				selected = selectedTab,
				onSelect = setSelectedTab,
			}),

			Items = e(ItemGrid, {
				position = UDim2.new(0.18, 10, 0, 68),
				size = UDim2.new(0.51, -20, 1, -82),
				data = props.data,
				selectedTab = selectedTab,
				selectedStackId = props.selectedStackId,
				onSelectStack = props.onSelectStack,
			}),

			Details = e(DetailPanel, {
				position = UDim2.new(0.69, 0, 0, 68),
				size = UDim2.new(0.31, -14, 1, -82),
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
