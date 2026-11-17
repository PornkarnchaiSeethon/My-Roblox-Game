local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

local function LevelBar()
	return e("Frame", {
		Size = UDim2.fromOffset(210, 56),
		Position = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BackgroundTransparency = 0.06,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1.5,
			Color = Color3.fromRGB(58, 64, 84),
		}),

		LevelBadge = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = Color3.fromRGB(68, 125, 235),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "1",
				Font = Enum.Font.GothamBlack,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
			}),
		}),

		Title = e("TextLabel", {
			Position = UDim2.fromOffset(56, 10),
			Size = UDim2.new(1, -66, 0, 16),
			BackgroundTransparency = 1,
			Text = "EXP  100 / 100",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(220, 228, 245),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		BarTrack = e("Frame", {
			Position = UDim2.fromOffset(56, 32),
			Size = UDim2.new(1, -68, 0, 10),
			BackgroundColor3 = Color3.fromRGB(14, 16, 22),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(45, 50, 66),
			}),
			Fill = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(75, 200, 120),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

return LevelBar
