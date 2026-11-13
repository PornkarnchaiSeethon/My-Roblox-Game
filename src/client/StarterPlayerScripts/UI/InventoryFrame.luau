local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

type Props = {
	tabs: { string },
	onClose: () -> (),
}

local function InventoryFrame(props: Props)
	local selected, setSelected = React.useState(props.tabs[1])

	local tabChildren = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	
	for i, name in props.tabs do
		tabChildren[name] = e("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 40),
			Text = name,
			BackgroundColor3 = if name == selected
				then Color3.fromRGB(255, 255, 255)
				else Color3.fromRGB(70, 70, 70),
			[React.Event.Activated] = function()
				setSelected(name)
			end,
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Panel = e("Frame", {
			Size = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }),
			SizeLimit = e("UISizeConstraint", {
				MinSize = Vector2.new(360, 260),
				MaxSize = Vector2.new(900, 600),
			}),

			Tabs = e("Frame", {
				Size = UDim2.new(0.2, 0, 0.8, 0),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(0, -4, 1, 0),
				BackgroundTransparency = 1,
				ZIndex = 1,
			}, tabChildren),

			Items = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScrollBarThickness = 2,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ZIndex = 1,
			}, {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				Grid = e("UIGridLayout", {
					CellSize = UDim2.fromOffset(64, 64),
					CellPadding = UDim2.fromOffset(6, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}),

			Title = e("TextLabel", {
				Size = UDim2.fromOffset(150, 60),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -40,
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
		}),
	})
end

return InventoryFrame