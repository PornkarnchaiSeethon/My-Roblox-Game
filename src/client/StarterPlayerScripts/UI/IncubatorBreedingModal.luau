--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

type Props = {
	modal: Types.PetModalInfo,
	pets: { Types.PetInstanceData },
	incubators: { Types.IncubatorClientData },
	breedingPens: { Types.BreedingPenClientData },
	inventoryData: Types.ClientInventory?,
	onStartIncubation: (string, string) -> (),
	onClaimHatchedPet: (string) -> (),
	onStartBreeding: (string, string, string) -> (),
	onClaimBreedingEgg: (string) -> (),
	onClose: () -> (),
}

local function formatSeconds(sec: number): string
	local clamped = math.max(0, math.floor(sec))
	local m = math.floor(clamped / 60)
	local s = clamped % 60
	return string.format("%02d:%02d", m, s)
end

local function findPetName(pets: { Types.PetInstanceData }, uid: string): string
	for _, pet in pets do
		if pet.UID == uid then
			return pet.Nickname
		end
	end
	return uid
end

local function IncubatorBreedingModal(props: Props)
	local nowTime, setNowTime = React.useState(os.time())
	local parentA, setParentA = React.useState(nil :: string?)
	local parentB, setParentB = React.useState(nil :: string?)

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

	local modal = props.modal
	local titleText = if modal.Type == "Incubator" then "EGG INCUBATOR" else "BREEDING PEN"
	local bodyElement: any

	if modal.Type == "Incubator" then
		local activeInc: Types.IncubatorClientData? = nil
		for _, inc in props.incubators do
			if inc.ObjectId == modal.ObjectId then
				activeInc = inc
				break
			end
		end

		if activeInc then
			local remaining = math.max(0, activeInc.HatchAt - nowTime)
			local isReady = remaining == 0
			local totalDuration = math.max(1, activeInc.HatchAt - activeInc.StartedAt)
			local progress = math.clamp(1 - (remaining / totalDuration), 0, 1)
			local eggInfo = ToolConfig.Get(activeInc.EggItemId)

			bodyElement = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 14),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				EggName = e("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, -24, 0, 28),
					BackgroundTransparency = 1,
					Text = `กำลังฟัก: {eggInfo.DisplayName}`,
					Font = Enum.Font.GothamBlack,
					TextSize = 18,
					TextColor3 = Color3.fromRGB(245, 247, 255),
				}),
				Timer = e("TextLabel", {
					LayoutOrder = 2,
					Size = UDim2.new(1, -24, 0, 24),
					BackgroundTransparency = 1,
					Text = if isReady then "ฟักเสร็จสมบูรณ์! พร้อมรับสัตว์เลี้ยง" else `เหลือเวลา {formatSeconds(remaining)}`,
					Font = Enum.Font.GothamBold,
					TextSize = 15,
					TextColor3 = if isReady then Color3.fromRGB(95, 225, 140) else Color3.fromRGB(255, 210, 95),
				}),
				Track = e("Frame", {
					LayoutOrder = 3,
					Size = UDim2.new(0.85, 0, 0, 14),
					BackgroundColor3 = Color3.fromRGB(16, 18, 26),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = e("Frame", {
						Size = UDim2.fromScale(progress, 1),
						BackgroundColor3 = if isReady then Color3.fromRGB(80, 215, 130) else Color3.fromRGB(95, 165, 255),
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
				ClaimBtn = e("TextButton", {
					LayoutOrder = 4,
					Size = UDim2.fromOffset(220, 42),
					BackgroundColor3 = if isReady then Color3.fromRGB(48, 175, 100) else Color3.fromRGB(45, 50, 66),
					TextColor3 = if isReady then Color3.new(1, 1, 1) else Color3.fromRGB(140, 150, 175),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					Text = if isReady then "Claim Pet" else "Incubating...",
					AutoButtonColor = isReady,
					[React.Event.Activated] = function()
						if isReady then
							props.onClaimHatchedPet(modal.ObjectId)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				}),
			})
		else
			local eggButtons: { [string]: any } = {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			local eggCounts: { [string]: number } = {}
			if props.inventoryData then
				for _, stack in props.inventoryData.Stacks do
					if PetConfig.Eggs[stack.Name] then
						eggCounts[stack.Name] = (eggCounts[stack.Name] or 0) + stack.Count
					end
				end
			end

			local foundEggs = 0
			for eggId, count in eggCounts do
				if count > 0 then
					foundEggs += 1
					local eggDef = PetConfig.Eggs[eggId]
					local toolInfo = ToolConfig.Get(eggId)
					eggButtons["Egg_" .. eggId] = e("TextButton", {
						LayoutOrder = foundEggs,
						Size = UDim2.new(1, 0, 0, 52),
						BackgroundColor3 = Color3.fromRGB(32, 37, 50),
						TextColor3 = Color3.fromRGB(240, 244, 255),
						Font = Enum.Font.GothamBold,
						TextSize = 13,
						Text = `{toolInfo.DisplayName} (x{count})  •  ใช้เวลาฟัก {formatSeconds(eggDef.HatchTimeSeconds)}`,
						AutoButtonColor = true,
						[React.Event.Activated] = function()
							props.onStartIncubation(modal.ObjectId, eggId)
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
						Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(70, 130, 235) }),
					})
				end
			end

			bodyElement = if foundEggs > 0
				then e("ScrollingFrame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				}, eggButtons)
				else e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "ไม่พบไข่สัตว์เลี้ยงในกระเป๋าของคุณ",
					Font = Enum.Font.GothamMedium,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(145, 155, 180),
				})
		end
	else
		local activePen: Types.BreedingPenClientData? = nil
		for _, pen in props.breedingPens do
			if pen.ObjectId == modal.ObjectId then
				activePen = pen
				break
			end
		end

		if activePen then
			local remaining = math.max(0, activePen.FinishAt - nowTime)
			local isReady = remaining == 0 or activePen.HasReadyEgg
			local totalDuration = math.max(1, activePen.FinishAt - activePen.StartedAt)
			local progress = math.clamp(1 - (remaining / totalDuration), 0, 1)
			local nameA = findPetName(props.pets, activePen.ParentA_UID)
			local nameB = findPetName(props.pets, activePen.ParentB_UID)

			bodyElement = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 14),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				PairLabel = e("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, -24, 0, 28),
					BackgroundTransparency = 1,
					Text = `{nameA}  ♥  {nameB}`,
					Font = Enum.Font.GothamBlack,
					TextSize = 18,
					TextColor3 = Color3.fromRGB(245, 175, 220),
				}),
				Timer = e("TextLabel", {
					LayoutOrder = 2,
					Size = UDim2.new(1, -24, 0, 24),
					BackgroundTransparency = 1,
					Text = if isReady then "ผสมพันธุ์สำเร็จ! รับไข่เข้ากระเป๋าได้เลย" else `เหลือเวลา {formatSeconds(remaining)}`,
					Font = Enum.Font.GothamBold,
					TextSize = 15,
					TextColor3 = if isReady then Color3.fromRGB(95, 225, 140) else Color3.fromRGB(255, 210, 95),
				}),
				Track = e("Frame", {
					LayoutOrder = 3,
					Size = UDim2.new(0.85, 0, 0, 14),
					BackgroundColor3 = Color3.fromRGB(16, 18, 26),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fill = e("Frame", {
						Size = UDim2.fromScale(progress, 1),
						BackgroundColor3 = if isReady then Color3.fromRGB(80, 215, 130) else Color3.fromRGB(235, 130, 195),
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					}),
				}),
				ClaimBtn = e("TextButton", {
					LayoutOrder = 4,
					Size = UDim2.fromOffset(220, 42),
					BackgroundColor3 = if isReady then Color3.fromRGB(48, 175, 100) else Color3.fromRGB(45, 50, 66),
					TextColor3 = if isReady then Color3.new(1, 1, 1) else Color3.fromRGB(140, 150, 175),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					Text = if isReady then "Claim Egg" else "Breeding...",
					AutoButtonColor = isReady,
					[React.Event.Activated] = function()
						if isReady then
							props.onClaimBreedingEgg(modal.ObjectId)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				}),
			})
		else
			local eligiblePets: { Types.PetInstanceData } = {}
			for _, pet in props.pets do
				local isAdult = pet.Stage == "Adult" or pet.Stage == "Evolved"
				local offCooldown = nowTime >= (pet.BreedCooldownUntil or 0)
				if isAdult and pet.State == "InPlot" and offCooldown then
					table.insert(eligiblePets, pet)
				end
			end

			local petListChildren: { [string]: any } = {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}

			for i, pet in eligiblePets do
				local selectedSlot = if parentA == pet.UID then " [1]" elseif parentB == pet.UID then " [2]" else ""
				local isPicked = selectedSlot ~= ""
				petListChildren["Eligible_" .. pet.UID] = e("TextButton", {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 42),
					BackgroundColor3 = if isPicked then Color3.fromRGB(95, 55, 115) else Color3.fromRGB(30, 34, 46),
					TextColor3 = Color3.fromRGB(240, 244, 255),
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					Text = `{pet.Nickname} ({pet.Stage} Lv.{pet.Level}){selectedSlot}`,
					AutoButtonColor = true,
					[React.Event.Activated] = function()
						if parentA == pet.UID then
							setParentA(nil)
						elseif parentB == pet.UID then
							setParentB(nil)
						elseif parentA == nil then
							setParentA(pet.UID)
						elseif parentB == nil then
							setParentB(pet.UID)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = e("UIStroke", {
						Thickness = 1,
						Color = if isPicked then Color3.fromRGB(240, 145, 205) else Color3.fromRGB(50, 56, 74),
					}),
				})
			end

			local canStart = parentA ~= nil and parentB ~= nil and parentA ~= parentB

			bodyElement = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				Hint = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Text = "เลือกสัตว์เลี้ยงโตเต็มวัย (Adult/Evolved) ใน Plot จำนวน 2 ตัว",
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(185, 195, 220),
				}),
				List = if #eligiblePets > 0
					then e("ScrollingFrame", {
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 1, -80),
						BackgroundColor3 = Color3.fromRGB(14, 16, 22),
						BorderSizePixel = 0,
						ScrollBarThickness = 4,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
					}, petListChildren)
					else e("TextLabel", {
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 1, -80),
						BackgroundTransparency = 1,
						Text = "ยังไม่มีสัตว์เลี้ยงโตเต็มวัยที่พร้อมผสมพันธุ์ใน Plot",
						Font = Enum.Font.GothamMedium,
						TextSize = 13,
						TextColor3 = Color3.fromRGB(140, 150, 175),
					}),
				StartBtn = e("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 42),
					BackgroundColor3 = if canStart then Color3.fromRGB(215, 95, 165) else Color3.fromRGB(45, 50, 66),
					TextColor3 = if canStart then Color3.new(1, 1, 1) else Color3.fromRGB(140, 150, 175),
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					Text = "Start Breeding",
					AutoButtonColor = canStart,
					[React.Event.Activated] = function()
						if canStart and parentA and parentB then
							props.onStartBreeding(modal.ObjectId, parentA, parentB)
							setParentA(nil)
							setParentB(nil)
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				}),
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 18,
	}, {
		ModalPanel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromOffset(480, 360),
			BackgroundColor3 = Color3.fromRGB(22, 24, 32),
			BackgroundTransparency = 0.04,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.fromRGB(68, 76, 98) }),

			Header = e("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
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
				Title = e("TextLabel", {
					Position = UDim2.fromOffset(18, 0),
					Size = UDim2.new(1, -64, 1, 0),
					BackgroundTransparency = 1,
					Text = titleText,
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
					[React.Event.Activated] = props.onClose,
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

return IncubatorBreedingModal
