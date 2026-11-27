--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local PetCard = require(script.Parent.Components.PetCard)
local e = React.createElement

type Props = {
	pets: { Types.PetInstanceData },
	maxPetCapacity: number,
	maxEquippedCombat: number,
	selectedPetUID: string?,
	inventoryData: Types.ClientInventory?,
	onSelectPet: (string?) -> (),
	onFeedPet: (string, string) -> (),
	onTriggerEvolve: (string, string?) -> (),
	onSetPetState: (string, string) -> (),
	onClose: () -> (),
}

local FILTER_TABS = { "All", "Equipped", "InPlot", "Breeding", "Stored" }

local function countInventoryItem(inv: Types.ClientInventory?, itemName: string): number
	if not inv then
		return 0
	end
	local total = 0
	for _, stack in inv.Stacks do
		if stack.Name == itemName then
			total += stack.Count
		end
	end
	return total
end

local function formatSeconds(sec: number): string
	local clamped = math.max(0, math.floor(sec))
	local m = math.floor(clamped / 60)
	local s = clamped % 60
	return string.format("%02d:%02d", m, s)
end

local function PetBarnFrame(props: Props)
	local filterTab, setFilterTab = React.useState("All")

	local equippedCount = 0
	local selectedPet: Types.PetInstanceData? = nil
	for _, pet in props.pets do
		if pet.State == "Equipped" then
			equippedCount += 1
		end
		if pet.UID == props.selectedPetUID then
			selectedPet = pet
		end
	end

	local filterChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, tab in FILTER_TABS do
		local active = tab == filterTab
		filterChildren["Filter" .. i] = e("TextButton", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(82, 30),
			BackgroundColor3 = if active then Color3.fromRGB(68, 125, 235) else Color3.fromRGB(28, 32, 44),
			TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(175, 185, 205),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = tab,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				setFilterTab(tab)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if active then Color3.fromRGB(130, 175, 255) else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	local gridChildren: { [string]: any } = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(176, 86),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local visibleCount = 0
	for index, pet in props.pets do
		if filterTab == "All" or pet.State == filterTab then
			visibleCount += 1
			local isSelected = props.selectedPetUID == pet.UID
			gridChildren["Pet_" .. pet.UID] = e(PetCard, {
				pet = pet,
				isSelected = isSelected,
				layoutOrder = index,
				onSelect = function()
					props.onSelectPet(if isSelected then nil else pet.UID)
				end,
			})
		end
	end

	local detailContent: any
	if not selectedPet then
		detailContent = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "เลือกสัตว์เลี้ยงเพื่อดูสเตตัส ให้อาหาร วิวัฒนาการ หรือจัดทีมต่อสู้",
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(135, 145, 170),
			TextWrapped = true,
		})
	else
		local pet = selectedPet
		local species = PetConfig.Species[pet.SpeciesId]
		local hp, atk = PetConfig.CalculateStats(pet.SpeciesId, pet.Level, pet.PotentialBonus)
		local nextThreshold = 0
		local nextStageLabel = "Max Stage"
		if species then
			if pet.Stage == "Baby" then
				nextThreshold = species.StageThresholds.Juvenile
				nextStageLabel = "Juvenile"
			elseif pet.Stage == "Juvenile" then
				nextThreshold = species.StageThresholds.Adult
				nextStageLabel = "Adult"
			elseif pet.Stage == "Adult" and species.EvolutionTarget then
				nextThreshold = species.StageThresholds.Evolved
				nextStageLabel = "Evolve Ready"
			end
		end

		local growthRatio = if nextThreshold > 0
			then math.clamp(pet.GrowthExp / nextThreshold, 0, 1)
			else 1

		local canEvolve = species ~= nil
			and species.EvolutionTarget ~= nil
			and pet.Stage == "Adult"
			and pet.GrowthExp >= species.StageThresholds.Evolved

		local requiredCatalyst = if species then species.EvolutionItem else nil
		local catalystCount = if requiredCatalyst then countInventoryItem(props.inventoryData, requiredCatalyst) else 1
		local breedCooldownLeft = math.max(0, (pet.BreedCooldownUntil or 0) - os.time())

		local foodButtons: { [string]: any } = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		local foodOrder = 0
		for foodId in PetConfig.Foods do
			foodOrder += 1
			local qty = countInventoryItem(props.inventoryData, foodId)
			local toolInfo = ToolConfig.Get(foodId)
			local isFav = species ~= nil and species.FavoriteFood == foodId
			foodButtons["Food_" .. foodId] = e("TextButton", {
				LayoutOrder = foodOrder,
				Size = UDim2.fromOffset(92, 42),
				BackgroundColor3 = if qty > 0
					then (if isFav then Color3.fromRGB(62, 130, 88) else Color3.fromRGB(38, 44, 60))
					else Color3.fromRGB(24, 27, 36),
				TextColor3 = if qty > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(110, 118, 140),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextWrapped = true,
				Text = `{if isFav then "★ " else ""}{toolInfo.DisplayName}\nx{qty}`,
				AutoButtonColor = qty > 0,
				[React.Event.Activated] = function()
					if qty > 0 then
						props.onFeedPet(pet.UID, foodId)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", {
					Thickness = 1,
					Color = if isFav and qty > 0
						then Color3.fromRGB(115, 225, 145)
						else Color3.fromRGB(52, 58, 76),
				}),
			})
		end

		local isBreeding = pet.State == "Breeding"

		detailContent = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Title = e("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = `{pet.Nickname}  (Lv.{pet.Level})`,
				Font = Enum.Font.GothamBlack,
				TextSize = 17,
				TextColor3 = Color3.fromRGB(245, 247, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Meta = e("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = `{if species then species.DisplayName else pet.SpeciesId} • {pet.Stage} • Bonus x{string.format("%.2f", pet.PotentialBonus)}`,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(165, 180, 210),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			StatsBox = e("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Color3.fromRGB(24, 27, 38),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Text = e("TextLabel", {
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -20, 1, -12),
					BackgroundTransparency = 1,
					Text = `HP: {hp}   |   ATK: {atk}\nHunger: {pet.Hunger}/{PetConfig.MaxHunger}   |   State: {pet.State}`,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(220, 228, 245),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}),

			GrowthBox = e("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
			}, {
				Label = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Text = if nextThreshold > 0
						then `Growth ({nextStageLabel}): {pet.GrowthExp} / {nextThreshold}`
						else `Growth EXP: {pet.GrowthExp} (MAX)`,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(190, 200, 225),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Track = e("Frame", {
					Position = UDim2.fromOffset(0, 22),
					Size = UDim2.new(1, 0, 0, 10),
					BackgroundColor3 = Color3.fromRGB(14, 16, 22),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = e("Frame", {
						Size = UDim2.fromScale(growthRatio, 1),
						BackgroundColor3 = Color3.fromRGB(100, 165, 255),
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
			}),

			CooldownLabel = (breedCooldownLeft > 0) and e("TextLabel", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = `Breed Cooldown: {formatSeconds(breedCooldownLeft)}`,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(240, 165, 110),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			FeedTitle = e("TextLabel", {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = "ให้อาหาร (★ = อาหารโปรด +25% EXP)",
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(215, 225, 245),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			FeedRow = e("Frame", {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
			}, foodButtons),

			EvolveButton = (species ~= nil and species.EvolutionTarget ~= nil) and e("TextButton", {
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = if canEvolve and catalystCount > 0
					then Color3.fromRGB(165, 90, 235)
					else Color3.fromRGB(40, 44, 58),
				TextColor3 = if canEvolve and catalystCount > 0 then Color3.new(1, 1, 1) else Color3.fromRGB(130, 140, 165),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Text = if canEvolve
					then `Evolve → {PetConfig.Species[species.EvolutionTarget].DisplayName}`
					else `Evolve (ต้องถึง Adult & {species.StageThresholds.Evolved} EXP)`,
				AutoButtonColor = canEvolve and catalystCount > 0,
				[React.Event.Activated] = function()
					if canEvolve then
						props.onTriggerEvolve(pet.UID, requiredCatalyst)
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),

			StateRow = e("Frame", {
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				}),
				EquipBtn = e("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = if pet.State == "Equipped"
						then Color3.fromRGB(195, 70, 75)
						else Color3.fromRGB(55, 130, 230),
					TextColor3 = Color3.new(1, 1, 1),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					Text = if pet.State == "Equipped" then "Unequip" else "Equip Combat",
					AutoButtonColor = not isBreeding,
					[React.Event.Activated] = function()
						if isBreeding then return end
						props.onSetPetState(pet.UID, if pet.State == "Equipped" then "InPlot" else "Equipped")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
				PlotBtn = e("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = if pet.State == "InPlot"
						then Color3.fromRGB(48, 165, 95)
						else Color3.fromRGB(52, 60, 80),
					TextColor3 = Color3.new(1, 1, 1),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					Text = "In Plot",
					AutoButtonColor = not isBreeding,
					[React.Event.Activated] = function()
						if isBreeding then return end
						props.onSetPetState(pet.UID, "InPlot")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
				StoreBtn = e("TextButton", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = if pet.State == "Stored"
						then Color3.fromRGB(95, 105, 125)
						else Color3.fromRGB(42, 46, 60),
					TextColor3 = Color3.new(1, 1, 1),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					Text = "Store",
					AutoButtonColor = not isBreeding,
					[React.Event.Activated] = function()
						if isBreeding then return end
						props.onSetPetState(pet.UID, "Stored")
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),
		})
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
				MinSize = Vector2.new(700, 420),
				MaxSize = Vector2.new(1120, 680),
			}),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 54),
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
					Position = UDim2.fromOffset(20, 0),
					Size = UDim2.new(0.4, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = "PET BARN",
					Font = Enum.Font.GothamBlack,
					TextSize = 20,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CombatBadge = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -160, 0.5, 0),
					Size = UDim2.fromOffset(105, 28),
					BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(220, 90, 95) }),
					Label = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `Combat {equippedCount}/{props.maxEquippedCombat}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(245, 165, 170),
					}),
				}),
				CapacityBadge = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -60, 0.5, 0),
					Size = UDim2.fromOffset(90, 28),
					BackgroundColor3 = Color3.fromRGB(18, 20, 28),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(52, 58, 76) }),
					Label = e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = `Pets {#props.pets}/{props.maxPetCapacity}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(180, 190, 215),
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

			FilterBar = e("Frame", {
				Position = UDim2.fromOffset(14, 64),
				Size = UDim2.new(0.58, -14, 0, 32),
				BackgroundTransparency = 1,
			}, filterChildren),

			GridContainer = e("Frame", {
				Position = UDim2.fromOffset(14, 102),
				Size = UDim2.new(0.58, -18, 1, -116),
				BackgroundColor3 = Color3.fromRGB(17, 19, 26),
				BackgroundTransparency = 0.15,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
				Scroll = (visibleCount > 0) and e("ScrollingFrame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				}, gridChildren),
				Empty = (visibleCount == 0) and e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "ยังไม่มีสัตว์เลี้ยงในหมวดนี้",
					Font = Enum.Font.GothamMedium,
					TextColor3 = Color3.fromRGB(130, 140, 165),
					TextSize = 14,
				}),
			}),

			DetailContainer = e("Frame", {
				Position = UDim2.new(0.58, 6, 0, 64),
				Size = UDim2.new(0.42, -20, 1, -78),
				BackgroundColor3 = Color3.fromRGB(17, 19, 26),
				BackgroundTransparency = 0.15,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
				Content = detailContent,
			}),
		}),
	})
end

return PetBarnFrame
