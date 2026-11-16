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

local function DetailPanel(props: Props)
	local stackData = props.stackData
	if not stackData then
		return e("Frame", {
			Position = props.position or UDim2.new(),
			Size = props.size or UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BackgroundTransparency = 0.2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Empty = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "Select an item",
				TextColor3 = Color3.fromRGB(220, 220, 220),
				TextSize = 20,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		})
	end

	local displayName = stackData.DisplayName or stackData.Name
	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 120) }),
		Name = e("TextLabel", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, 34),
			BackgroundTransparency = 1,
			Text = displayName,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.FredokaOne),
		}),
		Description = e("TextLabel", {
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(1, -24, 0, 60),
			BackgroundTransparency = 1,
			Text = stackData.Description ~= "" and stackData.Description or "No description",
			TextColor3 = Color3.fromRGB(210, 210, 210),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		Count = e("TextLabel", {
			Position = UDim2.fromOffset(12, 120),
			Size = UDim2.new(1, -24, 0, 24),
			BackgroundTransparency = 1,
			Text = `Count: {stackData.Count}`,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}

	if stackData.Image ~= "" then
		children.Image = e("ImageLabel", {
			Image = stackData.Image,
			Position = UDim2.new(1, -92, 0, 12),
			Size = UDim2.fromOffset(80, 80),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
		})
	end

	if props.isEquipped then
		children.Unequip = e("TextButton", {
			Position = UDim2.new(0, 12, 1, -52),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundColor3 = Color3.fromRGB(90, 90, 90),
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Unequip",
			[React.Event.Activated] = function()
				props.onUnequip(stackData.StackId)
			end,
		})
	elseif props.equipSlot then
		children.Equip = e("TextButton", {
			Position = UDim2.new(0, 12, 1, -52),
			Size = UDim2.new(0.5, -16, 0, 40),
			BackgroundColor3 = Color3.fromRGB(60, 140, 80),
			TextColor3 = Color3.new(1, 1, 1),
			Text = `Equip (slot {props.equipSlot})`,
			[React.Event.Activated] = function()
				props.onEquip(stackData.StackId, props.equipSlot :: number)
			end,
		})
	end

	if stackData.IsDroppable then
		children.Drop = e("TextButton", {
			Position = if props.isEquipped or not props.equipSlot
				then UDim2.new(0, 12, 1, -52)
				else UDim2.new(0.5, 4, 1, -52),
			Size = if props.isEquipped or not props.equipSlot
				then UDim2.new(1, -24, 0, 40)
				else UDim2.new(0.5, -16, 0, 40),
			BackgroundColor3 = Color3.fromRGB(160, 60, 60),
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Drop",
			[React.Event.Activated] = function()
				props.onDrop(stackData.StackId)
			end,
		})
	end

	return e("Frame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0.2,
	}, children)
end

return DetailPanel
