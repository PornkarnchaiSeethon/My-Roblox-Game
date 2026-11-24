--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))

local e = React.createElement

export type AdminSelfSpeedTabProps = {
	SelfWalkSpeed: number,
	OnSetSelfWalkSpeed: (number) -> (),
}

local function AdminSelfSpeedTab(props: AdminSelfSpeedTabProps)
	local customSpeedText, setCustomSpeedText = React.useState(tostring(math.floor(props.SelfWalkSpeed + 0.5)))

	React.useEffect(function()
		setCustomSpeedText(tostring(math.floor(props.SelfWalkSpeed + 0.5)))
	end, { props.SelfWalkSpeed })

	local presetButtons: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(108, 42),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for idx, speed in AdminConfig.SpeedPresets do
		local isActive = math.abs(props.SelfWalkSpeed - speed) < 0.05
		local label = if speed == AdminConfig.DefaultWalkSpeed
			then `{speed} (ปกติ)`
			else tostring(speed)
		presetButtons["Preset_" .. tostring(speed)] = e("TextButton", {
			LayoutOrder = idx,
			BackgroundColor3 = if isActive
				then Color3.fromRGB(58, 165, 105)
				else Color3.fromRGB(30, 34, 48),
			TextColor3 = if isActive then Color3.new(1, 1, 1) else Color3.fromRGB(215, 224, 245),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = label,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.OnSetSelfWalkSpeed(speed)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = if isActive then 1.5 else 1,
				Color = if isActive
					then Color3.fromRGB(120, 230, 160)
					else Color3.fromRGB(52, 58, 76),
			}),
		})
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(17, 19, 26),
		BackgroundTransparency = 0.12,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		CurrentSpeedCard = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = Color3.fromRGB(26, 30, 42),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(64, 125, 225) }),
			Title = e("TextLabel", {
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, -32, 0, 18),
				BackgroundTransparency = 1,
				Text = "ความเร็วเดินปัจจุบันของคุณ (Self WalkSpeed)",
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(170, 185, 215),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Value = e("TextLabel", {
				Position = UDim2.fromOffset(16, 30),
				Size = UDim2.new(1, -32, 0, 30),
				BackgroundTransparency = 1,
				Text = `{string.format("%.1f", props.SelfWalkSpeed)}  (ช่วงที่อนุญาต: {AdminConfig.MinWalkSpeed} - {AdminConfig.MaxWalkSpeed})`,
				Font = Enum.Font.GothamBlack,
				TextSize = 20,
				TextColor3 = Color3.fromRGB(125, 220, 165),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		PresetsTitle = e("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "เลือกความเร็วลัด (Speed Presets)",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(220, 230, 248),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		PresetsGrid = e("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
		}, presetButtons),

		CustomTitle = e("TextLabel", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = `กำหนดความเร็วเอง ({AdminConfig.MinWalkSpeed} - {AdminConfig.MaxWalkSpeed})`,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(220, 230, 248),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CustomRow = e("Frame", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			InputBox = e("TextBox", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(180, 40),
				BackgroundColor3 = Color3.fromRGB(24, 27, 36),
				TextColor3 = Color3.fromRGB(245, 247, 255),
				PlaceholderColor3 = Color3.fromRGB(120, 130, 155),
				PlaceholderText = tostring(AdminConfig.DefaultWalkSpeed),
				Text = customSpeedText,
				ClearTextOnFocus = false,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				[React.Change.Text] = function(rbx: TextBox)
					setCustomSpeedText(rbx.Text)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(58, 66, 88) }),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
			}),
			ApplyBtn = e("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(160, 40),
				BackgroundColor3 = Color3.fromRGB(54, 120, 224),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Text = "บันทึกความเร็ว",
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					local parsed = tonumber(customSpeedText)
					if parsed and parsed == parsed and math.abs(parsed) ~= math.huge then
						local clamped = math.clamp(parsed, AdminConfig.MinWalkSpeed, AdminConfig.MaxWalkSpeed)
						setCustomSpeedText(tostring(clamped))
						props.OnSetSelfWalkSpeed(clamped)
					else
						setCustomSpeedText(tostring(math.floor(props.SelfWalkSpeed + 0.5)))
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			ResetBtn = e("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(156, 40),
				BackgroundColor3 = Color3.fromRGB(46, 52, 70),
				TextColor3 = Color3.fromRGB(225, 232, 248),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = `รีเซ็ต ({AdminConfig.DefaultWalkSpeed})`,
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					props.OnSetSelfWalkSpeed(AdminConfig.DefaultWalkSpeed)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),
	})
end

return React.memo(AdminSelfSpeedTab)
