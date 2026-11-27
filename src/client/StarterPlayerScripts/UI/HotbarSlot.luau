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
	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = e("UIStroke", {
			Thickness = 2,
			Color = Color3.fromRGB(58, 64, 84),
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Aspect = e("UIAspectRatioConstraint", { AspectRatio = 10.6 }),
	}

	for i = 1, 10 do
		local stackId = if props.data then props.data.Hotbar["Slot" .. i] else nil
		local stackData = findStack(props.data, stackId)
		local hasItem = stackData ~= nil
		local hasImage = hasItem and stackData.Image ~= nil and stackData.Image ~= ""

		children["Slot" .. i] = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = hasItem,
			BackgroundColor3 = if hasItem
				then Color3.fromRGB(34, 39, 54)
				else Color3.fromRGB(22, 25, 34),
			BackgroundTransparency = if hasItem then 0.05 else 0.25,
			[React.Event.Activated] = function()
				if hasItem then
					props.onHold(i)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if hasItem
					then Color3.fromRGB(82, 94, 128)
					else Color3.fromRGB(42, 47, 62),
			}),

			Icon = hasImage and e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.fromScale(1,1),
				Image = stackData.Image,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
			}),

			Name = (hasItem and not hasImage) and e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.new(1, -10, 0.56, 0),
				BackgroundTransparency = 1,
				Text = stackData.DisplayName or stackData.Name,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(235, 240, 255),
				TextScaled = true,
				TextWrapped = true,
			}),

			CountBadge = hasItem and e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1,0,1,0),
				Size = UDim2.fromOffset(28, 16),
				BackgroundColor3 = Color3.fromRGB(16, 18, 26),
				BackgroundTransparency = 1
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Count = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = `x{stackData.Count}`,
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(255, 255, 255),
				},{e("UIStroke",{Thickness = 1})})
			}),

			NumberBadge = e("Frame", {
				Position = UDim2.fromOffset(0,0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Color3.fromRGB(16, 18, 26),
				BackgroundTransparency = 1,
				ZIndex = 4
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Number = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					Text = tostring(i % 10),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
				},{e("UIStroke",{Thickness = 1})}),
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.new(0.68, 0, 0, 74),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.98, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.5,
	}, children)
end

return HotbarSlot
