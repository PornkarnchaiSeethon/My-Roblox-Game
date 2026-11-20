--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

type Props = {
	pet: Types.PetInstanceData,
	isSelected: boolean,
	layoutOrder: number,
	onSelect: () -> (),
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(100, 200, 125),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(255, 195, 70),
}

local STATE_STYLES: { [string]: { Label: string, Color: Color3 } } = {
	Equipped = { Label = "COMBAT", Color = Color3.fromRGB(235, 95, 95) },
	InPlot = { Label = "FARM", Color = Color3.fromRGB(75, 195, 120) },
	Breeding = { Label = "BREED", Color = Color3.fromRGB(240, 145, 205) },
	Stored = { Label = "STORED", Color = Color3.fromRGB(130, 140, 165) },
}

local function PetCard(props: Props)
	local pet = props.pet
	local species = PetConfig.Species[pet.SpeciesId]
	local rarity = if species then species.Rarity else "Common"
	local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(140, 150, 175)
	local stateStyle = STATE_STYLES[pet.State] or STATE_STYLES.Stored
	local hungerRatio = math.clamp((pet.Hunger or 0) / PetConfig.MaxHunger, 0, 1)
	local shortCode = string.upper(string.sub(pet.Nickname, 1, 2))

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(176, 86),
		BackgroundColor3 = if props.isSelected
			then Color3.fromRGB(44, 52, 74)
			else Color3.fromRGB(30, 34, 46),
		AutoButtonColor = true,
		Text = "",
		[React.Event.Activated] = props.onSelect,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = if props.isSelected then 2 else 1,
			Color = if props.isSelected
				then Color3.fromRGB(255, 200, 75)
				else Color3.fromRGB(52, 58, 76),
		}),

		RarityStripe = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 4, 0.7, 0),
			BackgroundColor3 = rarityColor,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),

		AvatarBox = e("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Color3.fromRGB(20, 23, 32),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Thickness = 1.2, Color = rarityColor }),
			Code = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = shortCode,
				Font = Enum.Font.GothamBlack,
				TextSize = 18,
				TextColor3 = rarityColor,
			}),
		}),

		NameLabel = e("TextLabel", {
			Position = UDim2.fromOffset(66, 8),
			Size = UDim2.new(1, -74, 0, 18),
			BackgroundTransparency = 1,
			Text = pet.Nickname,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = if props.isSelected
				then Color3.fromRGB(255, 235, 165)
				else Color3.fromRGB(240, 244, 255),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		StageLevel = e("TextLabel", {
			Position = UDim2.fromOffset(66, 26),
			Size = UDim2.new(1, -74, 0, 16),
			BackgroundTransparency = 1,
			Text = `{pet.Stage} • Lv.{pet.Level}`,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = rarityColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		StateBadge = e("Frame", {
			Position = UDim2.fromOffset(66, 44),
			Size = UDim2.fromOffset(58, 16),
			BackgroundColor3 = Color3.fromRGB(18, 20, 28),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = stateStyle.Color }),
			Text = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = stateStyle.Label,
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				TextColor3 = stateStyle.Color,
			}),
		}),

		HungerTrack = e("Frame", {
			Position = UDim2.new(0, 10, 1, -13),
			Size = UDim2.new(1, -20, 0, 6),
			BackgroundColor3 = Color3.fromRGB(16, 18, 26),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				Size = UDim2.fromScale(hungerRatio, 1),
				BackgroundColor3 = if hungerRatio > 0.5
					then Color3.fromRGB(75, 200, 120)
					elseif hungerRatio > 0.25 then Color3.fromRGB(240, 185, 65)
					else Color3.fromRGB(225, 75, 85),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

return PetCard
