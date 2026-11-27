--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local AdminPetSpawnCard = require(script.Parent.Parent:WaitForChild("AdminPetSpawnCard"))

local e = React.createElement

export type AdminPetSpawnerTabProps = {
	TargetUserId: number,
	TargetDisplayName: string,
	OnSpawnPetToSelf: (string, string, number, string) -> (),
	OnSpawnPetToTarget: (number, string, string, number, string) -> (),
}

type SortedSpeciesEntry = {
	SpeciesId: string,
	Definition: PetConfig.SpeciesDefinition,
}

local SPAWN_AMOUNTS = { 1, 3, 5 }
local RARITY_FILTERS = { "All", "Common", "Rare", "Epic", "Legendary" }
local STAGE_OPTIONS = { "Baby", "Juvenile", "Adult", "Evolved" }

local RARITY_ORDER: { [string]: number } = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
}

local function getPreviewExpForStage(speciesDef: PetConfig.SpeciesDefinition, stage: string): number
	if stage == "Juvenile" then
		return speciesDef.StageThresholds.Juvenile or 100
	elseif stage == "Adult" then
		return speciesDef.StageThresholds.Adult or 350
	elseif stage == "Evolved" then
		return speciesDef.StageThresholds.Evolved or 800
	end
	return 0
end

local function AdminPetSpawnerTab(props: AdminPetSpawnerTabProps)
	local searchText, setSearchText = React.useState("")
	local rarityFilter, setRarityFilter = React.useState("All")
	local selectedStage, setSelectedStage = React.useState("Baby")
	local spawnAmount, setSpawnAmount = React.useState(1)
	local initialState, setInitialState = React.useState("InPlot")

	local sortedSpecies = React.useMemo(function(): { SortedSpeciesEntry }
		local list: { SortedSpeciesEntry } = {}
		for speciesId, def in PetConfig.Species do
			table.insert(list, {
				SpeciesId = speciesId,
				Definition = def,
			})
		end
		table.sort(list, function(a, b)
			local orderA = RARITY_ORDER[a.Definition.Rarity] or 99
			local orderB = RARITY_ORDER[b.Definition.Rarity] or 99
			if orderA ~= orderB then
				return orderA < orderB
			end
			if a.Definition.DisplayName ~= b.Definition.DisplayName then
				return a.Definition.DisplayName < b.Definition.DisplayName
			end
			return a.SpeciesId < b.SpeciesId
		end)
		return list
	end, {})

	local maxPerAction = AdminConfig.MaxPetSpawnAmountPerAction or 10

	-- แถวปุ่มเลือกจำนวนเสก (x1, x3, x5)
	local amountButtons: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for idx, amount in SPAWN_AMOUNTS do
		local capped = math.min(amount, maxPerAction)
		local active = spawnAmount == capped
		amountButtons["Amt_" .. tostring(capped)] = e("TextButton", {
			LayoutOrder = idx,
			Size = UDim2.fromOffset(48, 30),
			BackgroundColor3 = if active
				then Color3.fromRGB(58, 165, 105)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(180, 190, 212),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = `x{capped}`,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				setSpawnAmount(capped)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if active
					then Color3.fromRGB(120, 230, 160)
					else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	-- แถวปุ่มกรอง Rarity
	local rarityButtons: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for idx, rarity in RARITY_FILTERS do
		local active = rarityFilter == rarity
		rarityButtons["Rarity_" .. rarity] = e("TextButton", {
			LayoutOrder = idx,
			Size = UDim2.fromOffset(88, 26),
			BackgroundColor3 = if active
				then Color3.fromRGB(68, 125, 235)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(175, 185, 208),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			Text = rarity,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				setRarityFilter(rarity)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if active
					then Color3.fromRGB(130, 180, 255)
					else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	-- แถวเลือก Stage (Baby / Juvenile / Adult / Evolved)
	local stagePills: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Label = e("TextLabel", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(52, 26),
			BackgroundTransparency = 1,
			Text = "Stage:",
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(185, 196, 220),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}
	for idx, stage in STAGE_OPTIONS do
		local active = selectedStage == stage
		stagePills["Stage_" .. stage] = e("TextButton", {
			LayoutOrder = idx,
			Size = UDim2.fromOffset(92, 26),
			BackgroundColor3 = if active
				then Color3.fromRGB(150, 82, 220)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(175, 185, 208),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			Text = stage,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				setSelectedStage(stage)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if active
					then Color3.fromRGB(205, 150, 255)
					else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	local query = string.lower(searchText)
	local petCards: { [string]: any } = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local matchCount = 0
	for _, entry in sortedSpecies do
		local speciesId = entry.SpeciesId
		local def = entry.Definition
		local displayName = def.DisplayName or speciesId
		local rarity = def.Rarity or "Common"

		local rarityMatch = rarityFilter == "All" or rarity == rarityFilter
		local searchMatch = query == ""
			or string.find(string.lower(speciesId), query, 1, true) ~= nil
			or string.find(string.lower(displayName), query, 1, true) ~= nil

		if rarityMatch and searchMatch then
			matchCount += 1
			local previewExp = getPreviewExpForStage(def, selectedStage)
			local previewLevel = math.clamp(1 + math.floor(math.sqrt(previewExp / 25)), 1, 100)
			local previewHP, previewATK = PetConfig.CalculateStats(speciesId, previewLevel, 1.0)
			local capturedSpeciesId = speciesId

			petCards["Pet_" .. speciesId] = e(AdminPetSpawnCard, {
				SpeciesId = capturedSpeciesId,
				DisplayName = displayName,
				Rarity = rarity,
				Stage = selectedStage,
				PreviewLevel = previewLevel,
				PreviewHP = previewHP,
				PreviewATK = previewATK,
				FavoriteFood = def.FavoriteFood or "-",
				SpawnAmount = spawnAmount,
				InitialState = initialState,
				TargetDisplayName = props.TargetDisplayName,
				LayoutOrder = matchCount,
				OnSpawnSelf = function()
					props.OnSpawnPetToSelf(capturedSpeciesId, selectedStage, spawnAmount, initialState)
				end,
				OnSpawnTarget = function()
					props.OnSpawnPetToTarget(props.TargetUserId, capturedSpeciesId, selectedStage, spawnAmount, initialState)
				end,
			})
		end
	end

	local isInPlot = initialState == "InPlot"

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(17, 19, 26),
		BackgroundTransparency = 0.12,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),

		Row1 = e("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 30),
			BackgroundTransparency = 1,
		}, {
			TargetBadge = e("Frame", {
				Size = UDim2.fromOffset(216, 30),
				BackgroundColor3 = Color3.fromRGB(24, 30, 46),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(80, 140, 235) }),
				Label = e("TextLabel", {
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -16, 1, 0),
					BackgroundTransparency = 1,
					Text = `เป้าหมายปัจจุบัน: {props.TargetDisplayName}`,
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = Color3.fromRGB(165, 208, 255),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),

			SearchBox = e("TextBox", {
				Position = UDim2.fromOffset(224, 0),
				Size = UDim2.new(1, -392, 0, 30),
				BackgroundColor3 = Color3.fromRGB(24, 27, 36),
				TextColor3 = Color3.fromRGB(240, 245, 255),
				PlaceholderColor3 = Color3.fromRGB(120, 130, 155),
				PlaceholderText = "ค้นหาชื่อสัตว์เลี้ยง หรือ SpeciesId...",
				Text = searchText,
				ClearTextOnFocus = false,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				[React.Change.Text] = function(rbx: TextBox)
					setSearchText(rbx.Text)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(54, 62, 82) }),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
			}),

			AmountRow = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(160, 30),
				BackgroundTransparency = 1,
			}, amountButtons),
		}),

		Row2 = e("Frame", {
			Position = UDim2.fromOffset(10, 46),
			Size = UDim2.new(1, -20, 0, 26),
			BackgroundTransparency = 1,
		}, {
			RarityRow = e("Frame", {
				Size = UDim2.new(1, -148, 1, 0),
				BackgroundTransparency = 1,
			}, rarityButtons),

			StateToggleBtn = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(138, 26),
				BackgroundColor3 = if isInPlot
					then Color3.fromRGB(46, 138, 92)
					else Color3.fromRGB(84, 92, 118),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				Text = if isInPlot then "โหมด: ลง Plot" else "โหมด: เก็บคลัง",
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					setInitialState(if isInPlot then "Stored" else "InPlot")
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Thickness = 1,
					Color = if isInPlot
						then Color3.fromRGB(115, 225, 160)
						else Color3.fromRGB(135, 145, 175),
				}),
			}),
		}),

		Row3 = e("Frame", {
			Position = UDim2.fromOffset(10, 78),
			Size = UDim2.new(1, -20, 0, 26),
			BackgroundTransparency = 1,
		}, stagePills),

		PetListContainer = e("Frame", {
			Position = UDim2.fromOffset(10, 112),
			Size = UDim2.new(1, -20, 1, -122),
			BackgroundColor3 = Color3.fromRGB(14, 16, 22),
			BackgroundTransparency = 0.2,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(40, 45, 60) }),
			Scroll = (matchCount > 0) and e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, petCards),
			Empty = (matchCount == 0) and e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "ไม่พบสายพันธุ์สัตว์เลี้ยงที่ตรงกับคำค้นหาหรือระดับความหายากที่เลือก",
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(140, 150, 175),
			}),
		}),
	})
end

return React.memo(AdminPetSpawnerTab)
