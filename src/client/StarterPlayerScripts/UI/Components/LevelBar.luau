local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

local function LevelBar()
	return e("Frame", {
		Size = UDim2.new(0.2,0,0,80),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.01, 0.2),
		BackgroundColor3 = Color3.fromRGB(56, 41, 175),
		BackgroundTransparency = 1,
	}, {
		e("Frame",{
			Size = UDim2.new(0.9,0,0.3,0),
			AnchorPoint = Vector2.new(0,0),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		},{
			e("UICorner",{
				CornerRadius = UDim.new(.5,0)
			}),
			e("UIStroke",{
				Thickness = 1,
				Color = Color3.new(0, 0, 0)
			})
		}),
		e("TextLabel",{
			Size = UDim2.new(1,0,.3,0),
			Text = "EXP:100/100",
			TextScaled = true,
			BackgroundTransparency = 1,
		}),
		e("UIListLayout",{HorizontalFlex = Enum.UIFlexAlignment.Fill,VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,ItemLineAlignment = Enum.ItemLineAlignment.Center}),
		e("UIStroke",{Thickness = 1,Color = Color3.new(0, 0, 0)}),
		e("UICorner",{CornerRadius = UDim.new(0,4)})
	
	})
end

return LevelBar