local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

type Props = {
	tabs: { string },
	selected: string,
	onSelect: (tabName: string) -> (),
	position: UDim2?,
	size: UDim2?,
}

local function TabBar(props: Props)
	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}

	for index, name in props.tabs do
		local isSelected = name == props.selected
		children["Tab" .. index] = e("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 38),
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(68, 125, 235)
				else Color3.fromRGB(30, 34, 46),
			[React.Event.Activated] = function()
				props.onSelect(name)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if isSelected
					then Color3.fromRGB(130, 175, 255)
					else Color3.fromRGB(48, 54, 72),
			}),
			Indicator = isSelected and e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(4, 18),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Label = e("TextLabel", {
				Position = UDim2.fromOffset(if isSelected then 18 else 12, 0),
				Size = UDim2.new(1, -20, 1, 0),
				BackgroundTransparency = 1,
				Text = name,
				Font = if isSelected then Enum.Font.GothamBold else Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = if isSelected
					then Color3.fromRGB(255, 255, 255)
					else Color3.fromRGB(175, 185, 205),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end

	return e("Frame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(17, 19, 26),
		BackgroundTransparency = 0.15,
	}, children)
end

return TabBar
