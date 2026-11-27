--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

export type AdminPetSpawnCardProps = {
	SpeciesId: string,
	DisplayName: string,
	Rarity: string,
	Stage: string,
	PreviewLevel: number,
	PreviewHP: number,
	PreviewATK: number,
	FavoriteFood: string,
	SpawnAmount: number,
	InitialState: string,
	TargetDisplayName: string,
	LayoutOrder: number,
	OnSpawnSelf: () -> (),
	OnSpawnTarget: () -> (),
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(150, 160, 180),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(250, 195, 70),
}

local function AdminPetSpawnCard(props: AdminPetSpawnCardProps)
	local rarityColor = RARITY_COLORS[props.Rarity] or Color3.fromRGB(150, 160, 180)
	local targetHint = if props.TargetDisplayName ~= "" then props.TargetDisplayName else "เป้าหมาย"
	local stateLabel = if props.InitialState == "Stored" then "Stored" else "InPlot"

	return e("Frame", {
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 76),
		BackgroundColor3 = Color3.fromRGB(30, 34, 46),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(52, 58, 76),
		}),

		RarityStripe = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 0.72, 0),
			BackgroundColor3 = rarityColor,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		InfoContainer = e("Frame", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -258, 1, -16),
			BackgroundTransparency = 1,
		}, {
			TitleRow = e("Frame", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				NameLabel = e("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = props.DisplayName,
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				RarityBadge = e("Frame", {
					LayoutOrder = 2,
					Size = UDim2.new(0, 0, 0, 18),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Color3.fromRGB(20, 23, 32),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
					Stroke = e("UIStroke", {
						Thickness = 1,
						Color = rarityColor,
					}),
					Padding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					Label = e("TextLabel", {
						Size = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = `[{props.Rarity}]`,
						Font = Enum.Font.GothamBold,
						TextSize = 10,
						TextColor3 = rarityColor,
					}),
				}),
			}),

			MetaRow = e("TextLabel", {
				Position = UDim2.fromOffset(0, 23),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = `ID: {props.SpeciesId}  •  Stage: {props.Stage} (Lv.{props.PreviewLevel})  •  HP {props.PreviewHP} / ATK {props.PreviewATK}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(175, 188, 212),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			TargetRow = e("TextLabel", {
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = `เป้าหมาย: {targetHint}  •  โหมด: {stateLabel}  •  อาหารโปรด: {props.FavoriteFood}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(130, 175, 235),
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
			SpawnSelfBtn = e("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(110, 36),
				BackgroundColor3 = Color3.fromRGB(44, 154, 92),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = `+ ตัวเอง x{props.SpawnAmount}`,
				AutoButtonColor = true,
				[React.Event.Activated] = props.OnSpawnSelf,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			SpawnTargetBtn = e("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(114, 36),
				BackgroundColor3 = Color3.fromRGB(54, 120, 224),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = `เสกให้เป้า x{props.SpawnAmount}`,
				AutoButtonColor = true,
				[React.Event.Activated] = props.OnSpawnTarget,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),
	})
end

return React.memo(AdminPetSpawnCard)
