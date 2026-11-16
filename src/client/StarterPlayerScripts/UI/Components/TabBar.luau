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
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for index, name in props.tabs do
		children["Tab" .. index] = e("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 40),
			Text = name,
			TextColor3 = if name == props.selected then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
			BackgroundColor3 = if name == props.selected
				then Color3.fromRGB(255, 255, 255)
				else Color3.fromRGB(70, 70, 70),
			[React.Event.Activated] = function()
				props.onSelect(name)
			end,
		})
	end

	return e("Frame", {
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return TabBar
