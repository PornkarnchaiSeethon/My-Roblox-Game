--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))

local e = React.createElement

export type CropCardProps = {
	crop: PlantConfig.CropDefinition,
	layoutOrder: number,
	seedCount: number?,
	harvestedCount: number?,
	actionLabel: string?,
	actionEnabled: boolean?,
	onAction: (() -> ())?,
	size: UDim2?,
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(100, 200, 125),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(255, 195, 70),
}

local function formatDuration(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	local m = math.floor(clamped / 60)
	local s = clamped % 60
	if m > 0 and s > 0 then
		return `{m}m {s}s`
	elseif m > 0 then
		return `{m}m`
	end
	return `{s}s`
end

local function CropCard(props: CropCardProps)
	local crop = props.crop
	local rarityColor = RARITY_COLORS[crop.Rarity] or Color3.fromRGB(140, 150, 175)
	local harvestInfo = ToolConfig.Get(crop.HarvestItemId)
	local harvestName = harvestInfo.DisplayName or crop.HarvestItemId
	local shortCode = string.upper(string.sub(crop.DisplayName, 1, 2))
	local hasAction = props.onAction ~= nil
	local actionEnabled = props.actionEnabled ~= false
	local rightReserve = if hasAction then 118 else 14

	local cycleText = if crop.MaxHarvestCycles > 1
		then `เก็บซ้ำ {crop.MaxHarvestCycles} รอบ`
		else "เก็บ 1 รอบ"

	local metaLine = `โต {formatDuration(crop.GrowthDurationSeconds)} • ผลผลิต {harvestName} ({crop.BaseYieldMin}-{crop.BaseYieldMax}) • {cycleText}`

	local statsParts: { string } = {}
	if props.seedCount ~= nil then
		table.insert(statsParts, `เมล็ดในกระเป๋า: x{props.seedCount}`)
	end
	if props.harvestedCount ~= nil then
		table.insert(statsParts, `เก็บเกี่ยวแล้ว: {props.harvestedCount} ชิ้น`)
	end
	local statsLine = table.concat(statsParts, "   •   ")

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = props.size or UDim2.new(1, 0, 0, 82),
		BackgroundColor3 = Color3.fromRGB(30, 34, 46),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1,
			Color = if hasAction and actionEnabled
				then Color3.fromRGB(68, 92, 82)
				else Color3.fromRGB(52, 58, 76),
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

		IconBox = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = Color3.fromRGB(20, 23, 32),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Thickness = 1.5, Color = crop.PlaceholderColor }),
			Code = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = shortCode,
				Font = Enum.Font.GothamBlack,
				TextSize = 18,
				TextColor3 = crop.PlaceholderColor,
			}),
		}),

		NameRow = e("Frame", {
			Position = UDim2.fromOffset(72, 8),
			Size = UDim2.new(1, -(72 + rightReserve), 0, 20),
			BackgroundTransparency = 1,
		}, {
			NameLabel = e("TextLabel", {
				Size = UDim2.new(1, -62, 1, 0),
				BackgroundTransparency = 1,
				Text = crop.DisplayName,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(245, 247, 255),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			RarityBadge = e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(56, 17),
				BackgroundColor3 = Color3.fromRGB(18, 20, 28),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = rarityColor }),
				Label = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = string.upper(crop.Rarity),
					Font = Enum.Font.GothamBold,
					TextSize = 9,
					TextColor3 = rarityColor,
				}),
			}),
		}),

		MetaLabel = e("TextLabel", {
			Position = UDim2.fromOffset(72, 31),
			Size = UDim2.new(1, -(72 + rightReserve), 0, 18),
			BackgroundTransparency = 1,
			Text = metaLine,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(175, 188, 212),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		StatsLabel = (statsLine ~= "") and e("TextLabel", {
			Position = UDim2.fromOffset(72, 53),
			Size = UDim2.new(1, -(72 + rightReserve), 0, 18),
			BackgroundTransparency = 1,
			Text = statsLine,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = if props.seedCount ~= nil and props.seedCount > 0
				then Color3.fromRGB(120, 225, 155)
				elseif props.harvestedCount ~= nil and props.harvestedCount > 0 then Color3.fromRGB(245, 205, 95)
				else Color3.fromRGB(130, 140, 165),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		ActionBtn = hasAction and e("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(96, 38),
			BackgroundColor3 = if actionEnabled
				then Color3.fromRGB(48, 165, 95)
				else Color3.fromRGB(40, 44, 58),
			TextColor3 = if actionEnabled
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(125, 135, 160),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = props.actionLabel or "Plant",
			AutoButtonColor = actionEnabled,
			[React.Event.Activated] = function()
				if actionEnabled and props.onAction then
					props.onAction()
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if actionEnabled
					then Color3.fromRGB(115, 225, 155)
					else Color3.fromRGB(56, 62, 80),
			}),
		}),
	})
end

return CropCard
