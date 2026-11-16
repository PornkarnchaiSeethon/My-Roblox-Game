local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local e = React.createElement

type Props = {
	data: Types.ClientInventory?,
	onHold: (number) -> (),
}

local function findStack(data: Types.ClientInventory?, stackId: number?): Types.ClientStackData?
	if not data or not stackId then return nil end
	for _, stackData in data.Stacks do
		if stackData.StackId == stackId then
			return stackData
		end
	end
	return nil
end

local function HotbarSlot(props: Props)
	local slots = {}

	for i = 1, 10 do
		local stackId = if props.data then props.data.Hotbar["Slot" .. i] else nil
		local stackData = findStack(props.data, stackId)
		local hasImage = stackData ~= nil and stackData.Image ~= nil and stackData.Image ~= ""

		slots["Slot" .. i] = e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			BackgroundTransparency = 0.35,
		}, {
			Icon = e("ImageButton", {
				Image = if hasImage then stackData.Image else "",
				Visible = hasImage,
				Size = UDim2.new(0.9, 0, 0.9, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				[React.Event.Activated] = function()
					props.onHold(i)
				end,
			}, {
				Stroke = e("UIStroke", { Thickness = 2 }),
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Count = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 24),
					Text = if stackData then tostring(stackData.Count) .. "X" else "",
					Font = Enum.Font.FredokaOne,
					TextSize = 14,
					TextColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
				}),
			}),
			Name = e("TextLabel", {
				Size = UDim2.new(1, -8, 0.65, 0),
				Position = UDim2.fromOffset(4, 8),
				BackgroundTransparency = 1,
				Text = if stackData and not hasImage then (stackData.DisplayName or stackData.Name) else "",
				Visible = stackData ~= nil and not hasImage,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
			}),
			Number = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 2),
				Size = UDim2.fromOffset(20, 20),
				Text = tostring(i % 10),
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
			}),
		})
	end

	local children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
		}),
		Aspect = e("UIAspectRatioConstraint", { AspectRatio = 10 }),
		Corner = e("UICorner"),
		Stroke = e("UIStroke"),
	}

	for name, slot in slots do
		children[name] = slot
	end

	return e("Frame", {
		Size = UDim2.new(0.8, 0, 0, 80),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.98, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.6,
	}, children)
end

return HotbarSlot
