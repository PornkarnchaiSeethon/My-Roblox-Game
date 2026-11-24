--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

export type AdminItemSpawnCardProps = {
	ItemId: string,
	DisplayName: string,
	ItemType: string,
	MaxStack: number,
	SpawnAmount: number,
	TargetDisplayName: string,
	IsMissingInStudio: boolean,
	LayoutOrder: number,
	OnGiveSelf: () -> (),
	OnGiveTarget: () -> (),
}

local function AdminItemSpawnCard(props: AdminItemSpawnCardProps)
	local isMissing = props.IsMissingInStudio
	local bgColor = if isMissing then Color3.fromRGB(48, 22, 26) else Color3.fromRGB(30, 34, 46)
	local strokeColor = if isMissing then Color3.fromRGB(190, 68, 76) else Color3.fromRGB(52, 58, 76)

	local targetHint = if props.TargetDisplayName ~= "" then props.TargetDisplayName else "เป้าหมาย"

	return e("Frame", {
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Thickness = if isMissing then 1.5 else 1,
			Color = strokeColor,
		}),

		InfoContainer = e("Frame", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -256, 1, -16),
			BackgroundTransparency = 1,
		}, {
			TitleRow = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = if isMissing
					then `{props.DisplayName}  [ขาด Tool ใน Studio]`
					else props.DisplayName,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = if isMissing
					then Color3.fromRGB(255, 165, 170)
					else Color3.fromRGB(245, 247, 255),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			MetaRow = e("TextLabel", {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = `ID: {props.ItemId}  •  {props.ItemType}  •  MaxStack: {props.MaxStack}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = if isMissing
					then Color3.fromRGB(235, 145, 150)
					else Color3.fromRGB(170, 182, 206),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			TargetRow = e("TextLabel", {
				Position = UDim2.fromOffset(0, 40),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = if isMissing
					then "ไม่พบโมเดล Tool ใน ServerStorage.AllItems — ไม่สามารถเสกได้"
					else `เป้าหมาย: {targetHint}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = if isMissing
					then Color3.fromRGB(245, 120, 128)
					else Color3.fromRGB(130, 170, 235),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		ActionGroup = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(232, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			GiveSelfBtn = e("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(110, 36),
				BackgroundColor3 = if isMissing
					then Color3.fromRGB(46, 36, 40)
					else Color3.fromRGB(44, 154, 92),
				TextColor3 = if isMissing
					then Color3.fromRGB(140, 115, 120)
					else Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = `+ ตัวเอง x{props.SpawnAmount}`,
				Active = not isMissing,
				AutoButtonColor = not isMissing,
				[React.Event.Activated] = function()
					if not isMissing then
						props.OnGiveSelf()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			GiveTargetBtn = e("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(114, 36),
				BackgroundColor3 = if isMissing
					then Color3.fromRGB(46, 36, 40)
					else Color3.fromRGB(54, 120, 224),
				TextColor3 = if isMissing
					then Color3.fromRGB(140, 115, 120)
					else Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = `เสกให้เป้า x{props.SpawnAmount}`,
				Active = not isMissing,
				AutoButtonColor = not isMissing,
				[React.Event.Activated] = function()
					if not isMissing then
						props.OnGiveTarget()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),
	})
end

return AdminItemSpawnCard
