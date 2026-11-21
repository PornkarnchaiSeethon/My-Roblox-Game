--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))

local CropCard = require(script.Parent.Components.CropCard)

local e = React.createElement

export type CropAlmanacProps = {
	plantersById: { [string]: any },
	harvestStats: { [string]: number },
	seedCounts: { [string]: number },
	hasWateringCan: boolean,
	onWater: (string) -> (),
	onHarvest: (string) -> (),
	onClose: () -> (),
}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(100, 200, 125),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(255, 195, 70),
}

local TABS: { { Id: string, Label: string } } = {
	{ Id = "ActivePlanters", Label = "Active Planters" },
	{ Id = "Almanac", Label = "Crop Almanac" },
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

local function CropAlmanacFrame(props: CropAlmanacProps)
	local activeTab, setActiveTab = React.useState("ActivePlanters")
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

	-- รวบรวมและจัดเรียงแปลงที่กำลังปลูก (สุกพร้อมเก็บอยู่ด้านบน ตามด้วยความคืบหน้าสูงสุด)
	local activePlanters: { any } = {}
	for _, planter in props.plantersById do
		table.insert(activePlanters, planter)
	end
	table.sort(activePlanters, function(a, b)
		local aMature = a.Stage == "Mature"
		local bMature = b.Stage == "Mature"
		if aMature ~= bMature then
			return aMature
		end
		local aProg = tonumber(a.GrowthProgress) or 0
		local bProg = tonumber(b.GrowthProgress) or 0
		if aProg ~= bProg then
			return aProg > bProg
		end
		return tostring(a.ObjectId) < tostring(b.ObjectId)
	end)

	local totalHarvests = 0
	for _, count in props.harvestStats do
		totalHarvests += count
	end

	-- แถบปุ่มสลับ Tab
	local tabChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, tab in TABS do
		local isSelected = activeTab == tab.Id
		local labelText = if tab.Id == "ActivePlanters"
			then `{tab.Label} ({#activePlanters})`
			else tab.Label

		tabChildren["Tab_" .. tab.Id] = e("TextButton", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(168, 34),
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(58, 165, 105)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = if isSelected then Color3.new(1, 1, 1) else Color3.fromRGB(175, 185, 205),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Text = labelText,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				setActiveTab(tab.Id)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if isSelected
					then Color3.fromRGB(120, 230, 160)
					else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	-- เนื้อหาของแต่ละ Tab
	local contentElement: any

	if activeTab == "ActivePlanters" then
		if #activePlanters == 0 then
			contentElement = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "ยังไม่มีพืชที่กำลังปลูกใน Plot ของคุณ\nวาง Wooden Planter หรือ Fertile Garden Bed แล้วกดโต้ตอบเพื่อเริ่มเพาะปลูก!",
				Font = Enum.Font.GothamMedium,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(140, 150, 175),
				TextWrapped = true,
			})
		else
			local planterCards: { [string]: any } = {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}

			for index, planter in activePlanters do
				local cropDef = PlantConfig.Crops[planter.CropId]
				local planterDef = PlantConfig.Planters[planter.PlanterType]
				local cropName = if cropDef then cropDef.DisplayName else tostring(planter.CropId)
				local planterName = if planterDef then planterDef.DisplayName else tostring(planter.PlanterType)
				local rarity = if cropDef then cropDef.Rarity else "Common"
				local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(140, 150, 175)
				local harvestInfo = if cropDef then ToolConfig.Get(cropDef.HarvestItemId) else nil
				local harvestName = if harvestInfo and harvestInfo.DisplayName then harvestInfo.DisplayName else "-"

				local isMature = planter.Stage == "Mature"
				local progress = math.clamp(tonumber(planter.GrowthProgress) or 0, 0, 1)
				local pct = math.floor(progress * 100)
				local moistureLeft = math.max(0, (tonumber(planter.MoistureUntil) or 0) - nowTime)
				local isWet = moistureLeft > 0
				local fertId = if typeof(planter.FertilizerId) == "string" then planter.FertilizerId else ""
				local fertDef = if fertId ~= "" then PlantConfig.Fertilizers[fertId] else nil
				local maxCycles = if cropDef then cropDef.MaxHarvestCycles else 1
				local harvestsLeft = tonumber(planter.HarvestsRemaining) or 1

				planterCards["Planter_" .. tostring(planter.ObjectId)] = e("Frame", {
					LayoutOrder = index,
					Size = UDim2.new(1, 0, 0, 92),
					BackgroundColor3 = Color3.fromRGB(30, 34, 46),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Stroke = e("UIStroke", {
						Thickness = if isMature then 1.5 else 1,
						Color = if isMature
							then Color3.fromRGB(245, 195, 65)
							else Color3.fromRGB(52, 58, 76),
					}),

					RarityStripe = e("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(0, 4, 0.74, 0),
						BackgroundColor3 = rarityColor,
						BorderSizePixel = 0,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),

					Title = e("TextLabel", {
						Position = UDim2.fromOffset(14, 8),
						Size = UDim2.new(1, -225, 0, 20),
						BackgroundTransparency = 1,
						Text = `{cropName}  ({planterName})`,
						Font = Enum.Font.GothamBold,
						TextSize = 14,
						TextColor3 = Color3.fromRGB(245, 247, 255),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Meta = e("TextLabel", {
						Position = UDim2.fromOffset(14, 30),
						Size = UDim2.new(1, -225, 0, 16),
						BackgroundTransparency = 1,
						Text = `ขั้น: {planter.Stage} ({pct}%)  •  ผลผลิต: {harvestName}  •  รอบเหลือ: {harvestsLeft}/{maxCycles}{if fertDef then `  •  {fertDef.DisplayName}` else ""}`,
						Font = Enum.Font.GothamMedium,
						TextSize = 11,
						TextColor3 = Color3.fromRGB(175, 188, 212),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					WaterBadge = e("Frame", {
						Position = UDim2.fromOffset(14, 52),
						Size = UDim2.fromOffset(118, 20),
						BackgroundColor3 = Color3.fromRGB(18, 20, 28),
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
						Stroke = e("UIStroke", {
							Thickness = 1,
							Color = if isWet
								then Color3.fromRGB(85, 185, 250)
								else Color3.fromRGB(230, 145, 75),
						}),
						Label = e("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = if isWet then `WET {formatSeconds(moistureLeft)}` else "DRY SOIL",
							Font = Enum.Font.GothamBold,
							TextSize = 10,
							TextColor3 = if isWet
								then Color3.fromRGB(115, 205, 255)
								else Color3.fromRGB(245, 170, 100),
						}),
					}),

					ProgressTrack = e("Frame", {
						Position = UDim2.fromOffset(140, 58),
						Size = UDim2.new(1, -356, 0, 9),
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

					ActionGroup = e("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(196, 36),
						BackgroundTransparency = 1,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						WaterBtn = e("TextButton", {
							LayoutOrder = 1,
							Size = UDim2.fromOffset(88, 36),
							BackgroundColor3 = if props.hasWateringCan
								then Color3.fromRGB(45, 130, 210)
								else Color3.fromRGB(40, 44, 58),
							TextColor3 = if props.hasWateringCan
								then Color3.new(1, 1, 1)
								else Color3.fromRGB(125, 135, 160),
							Font = Enum.Font.GothamBold,
							TextSize = 12,
							Text = "Water",
							AutoButtonColor = props.hasWateringCan,
							[React.Event.Activated] = function()
								if props.hasWateringCan then
									props.onWater(planter.ObjectId)
								end
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
						}),
						HarvestBtn = isMature and e("TextButton", {
							LayoutOrder = 2,
							Size = UDim2.fromOffset(96, 36),
							BackgroundColor3 = Color3.fromRGB(235, 180, 45),
							TextColor3 = Color3.fromRGB(22, 24, 30),
							Font = Enum.Font.GothamBlack,
							TextSize = 12,
							Text = "Harvest!",
							AutoButtonColor = true,
							[React.Event.Activated] = function()
								props.onHarvest(planter.ObjectId)
							end,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
						}),
					}),
				})
			end

			contentElement = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, planterCards)
		end
	else
		-- Crop Almanac Tab
		local sortedCrops = getSortedCrops()
		local almanacChildren: { [string]: any } = {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for idx, cropDef in sortedCrops do
			almanacChildren["Almanac_" .. cropDef.SeedId] = e(CropCard, {
				crop = cropDef,
				layoutOrder = idx,
				seedCount = props.seedCounts[cropDef.SeedId] or 0,
				harvestedCount = props.harvestStats[cropDef.SeedId] or 0,
			})
		end

		contentElement = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, almanacChildren)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, {
		Panel = e("Frame", {
			Size = UDim2.fromScale(0.76, 0.64),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			BackgroundColor3 = Color3.fromRGB(22, 24, 32),
			BackgroundTransparency = 0.04,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.fromRGB(62, 68, 88) }),
			SizeLimit = e("UISizeConstraint", {
				MinSize = Vector2.new(680, 420),
				MaxSize = Vector2.new(1120, 680),
			}),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundColor3 = Color3.fromRGB(28, 31, 42),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				BottomCover = e("Frame", {
					Position = UDim2.new(0, 0, 1, -14),
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundColor3 = Color3.fromRGB(28, 31, 42),
					BorderSizePixel = 0,
				}),
				Divider = e("Frame", {
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Color3.fromRGB(50, 56, 74),
					BorderSizePixel = 0,
				}),
				Title = e("TextLabel", {
					Position = UDim2.fromOffset(20, 0),
					Size = UDim2.new(0.45, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "FARM & ALMANAC",
					Font = Enum.Font.GothamBlack,
					TextSize = 20,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				ActiveBadge = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -182, 0.5, 0),
					Size = UDim2.fromOffset(112, 28),
					BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(75, 195, 120) }),
					Label = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `Planters: {#activePlanters}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(130, 230, 165),
					}),
				}),
				HarvestBadge = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -60, 0.5, 0),
					Size = UDim2.fromOffset(112, 28),
					BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(235, 185, 65) }),
					Label = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `Harvested: {totalHarvests}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(250, 215, 115),
					}),
				}),
				Close = e("TextButton", {
					Size = UDim2.fromOffset(34, 34),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -14, 0.5, 0),
					BackgroundColor3 = Color3.fromRGB(210, 65, 75),
					Text = "X",
					Font = Enum.Font.GothamBlack,
					TextSize = 15,
					TextColor3 = Color3.new(1, 1, 1),
					AutoButtonColor = true,
					[React.Event.Activated] = props.onClose,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			TabBar = e("Frame", {
				Position = UDim2.fromOffset(14, 64),
				Size = UDim2.new(1, -28, 0, 36),
				BackgroundTransparency = 1,
			}, tabChildren),

			BodyContainer = e("Frame", {
				Position = UDim2.fromOffset(14, 108),
				Size = UDim2.new(1, -28, 1, -122),
				BackgroundColor3 = Color3.fromRGB(17, 19, 26),
				BackgroundTransparency = 0.15,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
				Content = contentElement,
			}),
		}),
	})
end

return CropAlmanacFrame
