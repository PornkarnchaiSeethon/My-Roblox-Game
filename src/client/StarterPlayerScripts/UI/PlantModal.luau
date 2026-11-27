--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))

local CropCard = require(script.Parent.Components.CropCard)

local e = React.createElement

export type PlantModalProps = {
	ModalInfo: { ObjectId: string, PlanterType: string }?,
	PlanterState: any?,
	SeedCounts: { [string]: number },
	HasWateringCan: boolean,
	FertilizerCounts: { [string]: number },
	OnPlantSeed: (string, string) -> (),
	OnWater: (string) -> (),
	OnFertilize: (string, string) -> (),
	OnHarvest: (string) -> (),
	OnUproot: (string) -> (),
	OnClose: () -> (),
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(100, 200, 125),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(255, 195, 70),
}

local function formatSeconds(sec: number): string
	local clamped = math.max(0, math.floor(sec))
	local m = math.floor(clamped / 60)
	local s = clamped % 60
	return string.format("%02d:%02d", m, s)
end

local function getSortedCrops(): { PlantConfig.CropDefinition }
	local list: { PlantConfig.CropDefinition } = {}
	for _, cropDef in PlantConfig.Crops do
		table.insert(list, cropDef)
	end
	table.sort(list, function(a, b)
		if a.GrowthDurationSeconds ~= b.GrowthDurationSeconds then
			return a.GrowthDurationSeconds < b.GrowthDurationSeconds
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

local function getSortedFertilizerIds(): { string }
	local ids: { string } = {}
	for fertId in PlantConfig.Fertilizers do
		table.insert(ids, fertId)
	end
	table.sort(ids)
	return ids
end

local function PlantModal(props: PlantModalProps)
	local nowTime, setNowTime = React.useState(os.time())

	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if running then
					setNowTime(os.time())
				end
			end
		end)
		return function()
			running = false
		end
	end, {})

	if not props.ModalInfo then
		return nil
	end

	local modalInfo = props.ModalInfo
	local objectId = modalInfo.ObjectId
	local planterDef = PlantConfig.Planters[modalInfo.PlanterType]
	local planterTitle = string.upper(if planterDef then planterDef.DisplayName else "GARDEN PLANTER")
	local planterState = props.PlanterState

	local bodyElement: any

	if not planterState then
		local sortedCrops = getSortedCrops()
		local listChildren: { [string]: any } = {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 6),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for idx, cropDef in sortedCrops do
			local count = props.SeedCounts[cropDef.SeedId] or 0
			listChildren["Seed_" .. cropDef.SeedId] = e(CropCard, {
				crop = cropDef,
				layoutOrder = idx,
				seedCount = count,
				actionLabel = if count > 0 then "Plant" else "No Seeds",
				actionEnabled = count > 0,
				onAction = function()
					if count > 0 then
						props.OnPlantSeed(objectId, cropDef.SeedId)
						props.OnClose()
					end
				end,
			})
		end

		local bonusText = if planterDef
			then `ความเร็วโต x{string.format("%.2f", planterDef.GrowthSpeedMultiplier)}  •  เก็บความชื้น x{string.format("%.2f", planterDef.MoistureRetentionMultiplier)}  •  เลือกเมล็ดเพื่อลงปลูก`
			else "เลือกเมล็ดพันธุ์จากกระเป๋าเพื่อลงปลูกในแปลงนี้"

		bodyElement = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Hint = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = bonusText,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(175, 190, 215),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			SeedScroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, 0, 1, -28),
				BackgroundColor3 = Color3.fromRGB(16, 18, 25),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, listChildren),
		})
	else
		local cropDef = PlantConfig.Crops[planterState.CropId]
		local cropName = if cropDef then cropDef.DisplayName else tostring(planterState.CropId)
		local rarity = if cropDef then cropDef.Rarity else "Common"
		local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(140, 150, 175)
		local harvestInfo = if cropDef then ToolConfig.Get(cropDef.HarvestItemId) else nil
		local harvestName = if harvestInfo and harvestInfo.DisplayName then harvestInfo.DisplayName else "-"

		local isMature = planterState.Stage == "Mature"
		local progress = math.clamp(tonumber(planterState.GrowthProgress) or 0, 0, 1)
		local pct = math.floor(progress * 100)
		local moistureRemaining = math.max(0, (tonumber(planterState.MoistureUntil) or 0) - nowTime)
		local isWet = moistureRemaining > 0
		local maxCycles = if cropDef then cropDef.MaxHarvestCycles else 1
		local harvestsRemaining = tonumber(planterState.HarvestsRemaining) or 1
		local activeFertId = if typeof(planterState.FertilizerId) == "string" then planterState.FertilizerId else ""
		local activeFertDef = if activeFertId ~= "" then PlantConfig.Fertilizers[activeFertId] else nil

		local scrollChildren: { [string]: any } = {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 6),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		scrollChildren.StatusCard = e("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 124),
			BackgroundColor3 = Color3.fromRGB(30, 34, 46),
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if isMature then Color3.fromRGB(245, 195, 65) else Color3.fromRGB(58, 66, 88),
			}),
			RarityStripe = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0, 4, 0.78, 0),
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			CropTitle = e("TextLabel", {
				Position = UDim2.fromOffset(14, 10),
				Size = UDim2.new(1, -110, 0, 22),
				BackgroundTransparency = 1,
				Text = cropName,
				Font = Enum.Font.GothamBlack,
				TextSize = 17,
				TextColor3 = Color3.fromRGB(245, 247, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			StageBadge = e("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 10),
				Size = UDim2.fromOffset(88, 22),
				BackgroundColor3 = Color3.fromRGB(18, 20, 28),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Stroke = e("UIStroke", {
					Thickness = 1,
					Color = if isMature then Color3.fromRGB(245, 195, 65) else Color3.fromRGB(85, 200, 125),
				}),
				Label = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = string.upper(tostring(planterState.Stage)),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					TextColor3 = if isMature then Color3.fromRGB(255, 220, 95) else Color3.fromRGB(120, 230, 155),
				}),
			}),
			SubInfo = e("TextLabel", {
				Position = UDim2.fromOffset(14, 34),
				Size = UDim2.new(1, -28, 0, 18),
				BackgroundTransparency = 1,
				Text = `ผลผลิต: {harvestName}  •  รอบเก็บคงเหลือ: {harvestsRemaining}/{maxCycles}{if activeFertDef then `  •  ปุ๋ย: {activeFertDef.DisplayName}` else ""}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(175, 190, 215),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			ProgressLabel = e("TextLabel", {
				Position = UDim2.fromOffset(14, 58),
				Size = UDim2.new(0.5, -14, 0, 16),
				BackgroundTransparency = 1,
				Text = if isMature then "เติบโตเต็มที่แล้ว (100%)" else `ความคืบหน้า: {pct}%`,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = if isMature then Color3.fromRGB(255, 220, 95) else Color3.fromRGB(215, 225, 245),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			MoistureLabel = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 58),
				Size = UDim2.new(0.5, -14, 0, 16),
				BackgroundTransparency = 1,
				Text = if isWet then `ชุ่มชื้น ({formatSeconds(moistureRemaining)})` else "ดินแห้ง (โตช้าลง)",
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = if isWet then Color3.fromRGB(105, 200, 255) else Color3.fromRGB(245, 165, 95),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			ProgressTrack = e("Frame", {
				Position = UDim2.fromOffset(14, 80),
				Size = UDim2.new(1, -28, 0, 12),
				BackgroundColor3 = Color3.fromRGB(14, 16, 22),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Fill = e("Frame", {
					Size = UDim2.fromScale(if isMature then 1 else progress, 1),
					BackgroundColor3 = if isMature
						then Color3.fromRGB(245, 195, 65)
						else Color3.fromRGB(75, 205, 125),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}),
			}),
			MoistureHint = e("TextLabel", {
				Position = UDim2.fromOffset(14, 98),
				Size = UDim2.new(1, -28, 0, 16),
				BackgroundTransparency = 1,
				Text = if isWet
					then "ดินมีความชุ่มชื้นเต็มประสิทธิภาพ พืชกำลังเติบโตในอัตราปกติ"
					else "รดน้ำด้วย Watering Can หรือวาง Hydro Sprinkler เพื่อเร่งการเติบโต",
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(140, 152, 178),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		})

		if isMature then
			scrollChildren.HarvestBtn = e("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Color3.fromRGB(235, 180, 45),
				TextColor3 = Color3.fromRGB(22, 24, 30),
				Font = Enum.Font.GothamBlack,
				TextSize = 15,
				Text = `เก็บเกี่ยว {harvestName}!`,
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					props.OnHarvest(objectId)
					props.OnClose()
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(255, 232, 145) }),
			})
		end

		scrollChildren.WaterBtn = e("TextButton", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if props.HasWateringCan
				then Color3.fromRGB(45, 130, 210)
				else Color3.fromRGB(40, 44, 58),
			TextColor3 = if props.HasWateringCan
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(130, 140, 165),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = if props.HasWateringCan
				then "รดน้ำแปลงปลูก (Watering Can)"
				else "ต้องมีบัวรดน้ำ (Watering Can) ในกระเป๋า",
			AutoButtonColor = props.HasWateringCan,
			[React.Event.Activated] = function()
				if props.HasWateringCan then
					props.OnWater(objectId)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if props.HasWateringCan
					then Color3.fromRGB(110, 195, 255)
					else Color3.fromRGB(56, 62, 80),
			}),
		})

		if not isMature and activeFertId == "" then
			local fertIds = getSortedFertilizerIds()
			for idx, fertId in fertIds do
				local fertDef = PlantConfig.Fertilizers[fertId]
				local count = props.FertilizerCounts[fertId] or 0
				local canApply = count > 0
				local speedPct = math.floor(fertDef.GrowthSpeedBonus * 100)
				local bonusYieldText = if fertDef.BonusYieldMax > 0
					then `ผลผลิต +{fertDef.BonusYieldMin}-{fertDef.BonusYieldMax}`
					else ""
				local effectSummary = if bonusYieldText ~= ""
					then `โตไว +{speedPct}%, {bonusYieldText}`
					else `โตไว +{speedPct}%`

				local btnColor = if not canApply
					then Color3.fromRGB(40, 44, 58)
					else Color3.fromRGB(130, 96, 48)

				local strokeColor = if not canApply
					then Color3.fromRGB(56, 62, 80)
					else Color3.fromRGB(205, 165, 95)

				scrollChildren["Fert_" .. fertId] = e("TextButton", {
					LayoutOrder = 10 + idx,
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundColor3 = btnColor,
					TextColor3 = if canApply then Color3.new(1, 1, 1) else Color3.fromRGB(130, 140, 165),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					Text = `ใส่ {fertDef.DisplayName} ({effectSummary})  •  x{count}`,
					AutoButtonColor = canApply,
					[React.Event.Activated] = function()
						if canApply then
							props.OnFertilize(objectId, fertId)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = strokeColor }),
				})
			end
		end

		scrollChildren.UprootBtn = e("TextButton", {
			LayoutOrder = 50,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Color3.fromRGB(180, 52, 62),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = "ถอนต้นไม้ออกจากแปลง (Uproot)",
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.OnUproot(objectId)
				props.OnClose()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(235, 105, 115) }),
		})

		bodyElement = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, scrollChildren)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 18,
	}, {
		ModalPanel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromOffset(500, 420),
			BackgroundColor3 = Color3.fromRGB(22, 24, 32),
			BackgroundTransparency = 0.04,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.fromRGB(62, 68, 88) }),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Color3.fromRGB(28, 31, 42),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				Divider = e("Frame", {
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(50, 56, 74),
					BorderSizePixel = 0,
				}),
				Title = e("TextLabel", {
					Position = UDim2.fromOffset(18, 0),
					Size = UDim2.new(1, -64, 1, 0),
					BackgroundTransparency = 1,
					Text = planterTitle,
					Font = Enum.Font.GothamBlack,
					TextSize = 18,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Close = e("TextButton", {
					Size = UDim2.fromOffset(32, 32),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					BackgroundColor3 = Color3.fromRGB(210, 65, 75),
					Text = "X",
					Font = Enum.Font.GothamBlack,
					TextSize = 14,
					TextColor3 = Color3.new(1, 1, 1),
					AutoButtonColor = true,
					[React.Event.Activated] = props.OnClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			Body = e("Frame", {
				Position = UDim2.fromOffset(16, 62),
				Size = UDim2.new(1, -32, 1, -78),
				BackgroundTransparency = 1,
			}, {
				Content = bodyElement,
			}),
		}),
	})
end

return PlantModal
