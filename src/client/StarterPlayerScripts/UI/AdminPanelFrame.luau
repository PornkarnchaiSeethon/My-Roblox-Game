--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local AdminItemSpawnCard = require(script.Parent.Components.AdminItemSpawnCard)

local e = React.createElement

export type AdminTab = "Players" | "Spawner" | "SelfSpeed" | "AuditLog"

export type AdminPanelProps = {
	ActiveTab: AdminTab,
	PlayersList: { Types.AdminPlayerSummary },
	SelectedUserId: number,
	SelectedDetail: Types.AdminPlayerDetail?,
	SelfWalkSpeed: number,
	MissingStudioItems: { [string]: boolean },
	AuditLogs: { Types.AdminAuditEntry },
	OnSelectTab: (AdminTab) -> (),
	OnSelectPlayer: (number) -> (),
	OnRefreshPlayers: () -> (),
	OnGiveItemToSelf: (string, number) -> (),
	OnGiveItemToTarget: (number, string, number) -> (),
	OnSetSelfWalkSpeed: (number) -> (),
	OnClose: () -> (),
}

local TABS: { { Id: AdminTab, Label: string } } = {
	{ Id = "Players", Label = "ข้อมูลผู้เล่น (Players)" },
	{ Id = "Spawner", Label = "เสกไอเทม (Item Spawner)" },
	{ Id = "SelfSpeed", Label = "ความเร็วตัวเอง (Speed)" },
	{ Id = "AuditLog", Label = "ประวัติ (Audit Log)" },
}

local SPAWN_AMOUNTS = { 1, 5, 10, 25 }
local ITEM_CATEGORIES = { "All", "Weapon", "Armor", "Special", "Consumable", "Resource" }

local function formatTimestamp(ts: number): string
	if ts <= 0 then
		return "--:--:--"
	end
	local formatted = os.date("%H:%M:%S", ts)
	return if typeof(formatted) == "string" then formatted else tostring(ts)
end

local function createStatCard(label: string, value: string, layoutOrder: number)
	return e("Frame", {
		LayoutOrder = layoutOrder,
		BackgroundColor3 = Color3.fromRGB(26, 30, 42),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(48, 54, 72),
		}),
		Label = e("TextLabel", {
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -20, 0, 14),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(150, 162, 188),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = e("TextLabel", {
			Position = UDim2.fromOffset(10, 21),
			Size = UDim2.new(1, -20, 0, 18),
			BackgroundTransparency = 1,
			Text = value,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(240, 245, 255),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function AdminPanelFrame(props: AdminPanelProps)
	local searchText, setSearchText = React.useState("")
	local spawnAmount, setSpawnAmount = React.useState(1)
	local selectedCategory, setSelectedCategory = React.useState("All")
	local speedInput, setSpeedInput = React.useState(tostring(math.floor(props.SelfWalkSpeed + 0.5)))

	React.useEffect(function()
		setSpeedInput(tostring(math.floor(props.SelfWalkSpeed + 0.5)))
	end, { props.SelfWalkSpeed })

	local localPlayer = Players.LocalPlayer
	local localUserId = if localPlayer then localPlayer.UserId else 0

	-- หาชื่อเป้าหมายปัจจุบันสำหรับแสดงใน Badge และหน้า Spawner
	local targetUserId = props.SelectedUserId
	local targetDisplayName = ""
	if props.SelectedDetail and props.SelectedDetail.UserId == targetUserId then
		targetDisplayName = props.SelectedDetail.DisplayName
	else
		for _, summary in props.PlayersList do
			if summary.UserId == targetUserId then
				targetDisplayName = summary.DisplayName
				break
			end
		end
	end
	if targetDisplayName == "" then
		if localPlayer and (targetUserId == 0 or targetUserId == localUserId) then
			targetUserId = localUserId
			targetDisplayName = localPlayer.DisplayName
		elseif #props.PlayersList > 0 then
			targetUserId = props.PlayersList[1].UserId
			targetDisplayName = props.PlayersList[1].DisplayName
		else
			targetDisplayName = "ยังไม่เลือกผู้เล่น"
		end
	end

	-- แถบปุ่มสลับ 4 แท็บ
	local tabBarChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
	}
	for index, tab in TABS do
		local isSelected = props.ActiveTab == tab.Id
		tabBarChildren["Tab_" .. tab.Id] = e("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(185, 58, 86)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = if isSelected
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(178, 188, 210),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = tab.Label,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.OnSelectTab(tab.Id)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if isSelected
					then Color3.fromRGB(245, 130, 155)
					else Color3.fromRGB(48, 54, 72),
			}),
		})
	end

	-- เนื้อหาตามแท็บที่เลือก
	local bodyContent: any

	if props.ActiveTab == "Players" then
		-- รายชื่อผู้เล่นฝั่งซ้าย
		local playerListChildren: { [string]: any } = {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for idx, summary in props.PlayersList do
			local isSelected = summary.UserId == props.SelectedUserId
			local isSelf = localUserId ~= 0 and summary.UserId == localUserId
			playerListChildren["Player_" .. tostring(summary.UserId)] = e("TextButton", {
				LayoutOrder = idx,
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = if isSelected
					then Color3.fromRGB(54, 88, 156)
					else Color3.fromRGB(28, 32, 44),
				Text = "",
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					props.OnSelectPlayer(summary.UserId)
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", {
					Thickness = if isSelected then 1.5 else 1,
					Color = if isSelected
						then Color3.fromRGB(125, 175, 255)
						else Color3.fromRGB(48, 54, 72),
				}),
				NameLabel = e("TextLabel", {
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -20, 0, 18),
					BackgroundTransparency = 1,
					Text = `{summary.DisplayName}{if isSelf then " (คุณ)" else ""}`,
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(245, 247, 255),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				SubLabel = e("TextLabel", {
					Position = UDim2.fromOffset(10, 24),
					Size = UDim2.new(1, -20, 0, 14),
					BackgroundTransparency = 1,
					Text = `@{summary.Name}  •  Lv.{summary.Level}`,
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(185, 198, 222),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				StatLabel = e("TextLabel", {
					Position = UDim2.fromOffset(10, 38),
					Size = UDim2.new(1, -20, 0, 14),
					BackgroundTransparency = 1,
					Text = `Cash: ${math.floor(summary.Cash)}  •  WS: {string.format("%.0f", summary.WalkSpeed)}`,
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(140, 215, 165),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
		end

		-- รายละเอียดผู้เล่นฝั่งขวา
		local detailElement: any
		local detail = props.SelectedDetail
		if not detail then
			detailElement = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "กำลังโหลดข้อมูลผู้เล่น...\nเลือกผู้เล่นจากรายชื่อทางซ้าย หรือกดปุ่ม Refresh ด้านบน",
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(145, 155, 180),
				TextWrapped = true,
			})
		else
			local stackRows: { [string]: any } = {
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			for idx, item in detail.Items do
				local hotbarTag = if item.HotbarSlot > 0 then `  [Hotbar #{item.HotbarSlot}]` else ""
				stackRows["Stack_" .. tostring(item.StackId) .. "_" .. tostring(idx)] = e("Frame", {
					LayoutOrder = idx,
					Size = UDim2.new(1, 0, 0, 42),
					BackgroundColor3 = Color3.fromRGB(26, 30, 42),
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Stroke = e("UIStroke", {
						Thickness = 1,
						Color = if item.HotbarSlot > 0
							then Color3.fromRGB(85, 145, 235)
							else Color3.fromRGB(48, 54, 72),
					}),
					Title = e("TextLabel", {
						Position = UDim2.fromOffset(10, 4),
						Size = UDim2.new(1, -80, 0, 18),
						BackgroundTransparency = 1,
						Text = `{item.DisplayName}{hotbarTag}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = if item.HotbarSlot > 0
							then Color3.fromRGB(150, 200, 255)
							else Color3.fromRGB(240, 245, 255),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Sub = e("TextLabel", {
						Position = UDim2.fromOffset(10, 22),
						Size = UDim2.new(1, -80, 0, 14),
						BackgroundTransparency = 1,
						Text = `ID: {item.ItemId}  •  {item.ItemType}  •  Stack #{item.StackId}`,
						Font = Enum.Font.GothamMedium,
						TextSize = 10,
						TextColor3 = Color3.fromRGB(155, 168, 195),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					CountBadge = e("TextLabel", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(60, 24),
						BackgroundColor3 = Color3.fromRGB(18, 20, 28),
						Text = `x{item.Count}`,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(130, 230, 165),
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),
				})
			end

			detailElement = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
				Layout = e("UIListLayout", {
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				ProfileHeader = e("Frame", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
				}, {
					Title = e("TextLabel", {
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.new(1, -210, 0, 22),
						BackgroundTransparency = 1,
						Text = detail.DisplayName,
						Font = Enum.Font.GothamBlack,
						TextSize = 16,
						TextColor3 = Color3.fromRGB(245, 247, 255),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Sub = e("TextLabel", {
						Position = UDim2.fromOffset(0, 23),
						Size = UDim2.new(1, -210, 0, 16),
						BackgroundTransparency = 1,
						Text = `@{detail.Name}  •  UserId: {detail.UserId}`,
						Font = Enum.Font.GothamMedium,
						TextSize = 11,
						TextColor3 = Color3.fromRGB(160, 174, 200),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					QuickSpawnBtn = e("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, 0),
						Size = UDim2.fromOffset(202, 34),
						BackgroundColor3 = Color3.fromRGB(54, 120, 224),
						TextColor3 = Color3.new(1, 1, 1),
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						Text = `ไปหน้าเสกไอเทมให้ {detail.DisplayName}`,
						TextTruncate = Enum.TextTruncate.AtEnd,
						AutoButtonColor = true,
						[React.Event.Activated] = function()
							props.OnSelectTab("Spawner")
						end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
					}),
				}),

				StatsGrid = e("Frame", {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 196),
					BackgroundTransparency = 1,
				}, {
					Grid = e("UIGridLayout", {
						CellSize = UDim2.new(0.333, -6, 0, 44),
						CellPadding = UDim2.fromOffset(6, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					StatUserId = createStatCard("UserId", tostring(detail.UserId), 1),
					StatAccountAge = createStatCard("AccountAge", `{detail.AccountAge} วัน`, 2),
					StatLevel = createStatCard("Level", `Lv.{detail.Level}`, 3),
					StatExp = createStatCard("EXP", `{math.floor(detail.CurrentExp)} / {math.floor(detail.ExpForNextLevel)}`, 4),
					StatCash = createStatCard("Cash", `${math.floor(detail.Cash)}`, 5),
					StatLogInTimes = createStatCard("LogInTimes", `{detail.LogInTimes} ครั้ง`, 6),
					StatHealth = createStatCard("HP", `{math.floor(detail.Health)} / {math.floor(detail.MaxHealth)}`, 7),
					StatWalkSpeed = createStatCard("WalkSpeed", string.format("%.1f", detail.WalkSpeed), 8),
					StatBagStacks = createStatCard("Bag Stacks", `{detail.StackCount} / {detail.MaxStacks}`, 9),
					StatPets = createStatCard("Pets", tostring(detail.PetCount), 10),
					StatPlanters = createStatCard("ActivePlanters", tostring(detail.ActivePlanters), 11),
					StatPlotObjects = createStatCard("PlotObjects", tostring(detail.PlotObjectCount), 12),
				}),

				InventoryTitle = e("TextLabel", {
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					Text = `รายการไอเทมในกระเป๋า ({#detail.Items} Stacks)`,
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(220, 230, 248),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				InventoryList = if #detail.Items == 0
					then e("TextLabel", {
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						Text = "ผู้เล่นนี้ยังไม่มีไอเทมในกระเป๋า",
						Font = Enum.Font.GothamMedium,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(135, 145, 170),
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					else e("Frame", {
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
					}, stackRows),
			})
		end

		bodyContent = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			LeftPane = e("Frame", {
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(0, 232, 1, 0),
				BackgroundColor3 = Color3.fromRGB(17, 19, 26),
				BackgroundTransparency = 0.12,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
				Header = e("TextLabel", {
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -20, 0, 20),
					BackgroundTransparency = 1,
					Text = `ผู้เล่นออนไลน์ ({#props.PlayersList})`,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(200, 210, 232),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				List = if #props.PlayersList == 0
					then e("TextLabel", {
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 1, -28),
						BackgroundTransparency = 1,
						Text = "ไม่พบรายชื่อผู้เล่น",
						Font = Enum.Font.GothamMedium,
						TextSize = 12,
						TextColor3 = Color3.fromRGB(135, 145, 170),
					})
					else e("ScrollingFrame", {
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 1, -28),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
					}, playerListChildren),
			}),

			RightPane = e("Frame", {
				Position = UDim2.fromOffset(242, 0),
				Size = UDim2.new(1, -242, 1, 0),
				BackgroundColor3 = Color3.fromRGB(17, 19, 26),
				BackgroundTransparency = 0.12,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
				Content = detailElement,
			}),
		})
	elseif props.ActiveTab == "Spawner" then
		-- ปุ่มเลือกจำนวนเสก
		local amountButtons: { [string]: any } = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for idx, amount in SPAWN_AMOUNTS do
			local capped = math.min(amount, AdminConfig.MaxSpawnAmountPerAction)
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

		-- ปุ่มกรองหมวดหมู่
		local categoryButtons: { [string]: any } = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for idx, category in ITEM_CATEGORIES do
			local active = selectedCategory == category
			categoryButtons["Cat_" .. category] = e("TextButton", {
				LayoutOrder = idx,
				Size = UDim2.fromOffset(92, 26),
				BackgroundColor3 = if active
					then Color3.fromRGB(68, 125, 235)
					else Color3.fromRGB(28, 32, 44),
				TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(175, 185, 208),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				Text = category,
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					setSelectedCategory(category)
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

		-- ดึงไอเทมทั้งหมดจาก ToolConfig.Items เรียงตาม ID
		local sortedItemIds: { string } = {}
		for itemId in ToolConfig.Items do
			table.insert(sortedItemIds, itemId)
		end
		table.sort(sortedItemIds)

		local query = string.lower(searchText)
		local itemCards: { [string]: any } = {
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
		for _, itemId in sortedItemIds do
			local toolInfo = ToolConfig.Get(itemId)
			local displayName = toolInfo.DisplayName or itemId
			local itemType = toolInfo.ItemType or "Resource"
			local maxStack = toolInfo.MaxStack or 1

			local categoryMatch = selectedCategory == "All" or itemType == selectedCategory
			local searchMatch = query == ""
				or string.find(string.lower(itemId), query, 1, true) ~= nil
				or string.find(string.lower(displayName), query, 1, true) ~= nil

			if categoryMatch and searchMatch then
				matchCount += 1
				local capturedItemId = itemId
				itemCards["Item_" .. itemId] = e(AdminItemSpawnCard, {
					ItemId = capturedItemId,
					DisplayName = displayName,
					ItemType = itemType,
					MaxStack = maxStack,
					SpawnAmount = spawnAmount,
					TargetDisplayName = targetDisplayName,
					IsMissingInStudio = props.MissingStudioItems[capturedItemId] == true,
					LayoutOrder = matchCount,
					OnGiveSelf = function()
						props.OnGiveItemToSelf(capturedItemId, spawnAmount)
					end,
					OnGiveTarget = function()
						props.OnGiveItemToTarget(targetUserId, capturedItemId, spawnAmount)
					end,
				})
			end
		end

		bodyContent = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(17, 19, 26),
			BackgroundTransparency = 0.12,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),

			TopRow = e("Frame", {
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(1, -20, 0, 30),
				BackgroundTransparency = 1,
			}, {
				TargetBadge = e("Frame", {
					Size = UDim2.fromOffset(220, 30),
					BackgroundColor3 = Color3.fromRGB(24, 30, 46),
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(80, 140, 235) }),
					Label = e("TextLabel", {
						Position = UDim2.fromOffset(8, 0),
						Size = UDim2.new(1, -16, 1, 0),
						BackgroundTransparency = 1,
						Text = `เป้าหมายปัจจุบัน: {targetDisplayName}`,
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						TextColor3 = Color3.fromRGB(165, 208, 255),
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				SearchBox = e("TextBox", {
					Position = UDim2.fromOffset(228, 0),
					Size = UDim2.new(1, -448, 0, 30),
					BackgroundColor3 = Color3.fromRGB(24, 27, 36),
					TextColor3 = Color3.fromRGB(240, 245, 255),
					PlaceholderColor3 = Color3.fromRGB(120, 130, 155),
					PlaceholderText = "ค้นหาชื่อไอเทม หรือ ItemId...",
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
					Size = UDim2.fromOffset(210, 30),
					BackgroundTransparency = 1,
				}, amountButtons),
			}),

			CategoryRow = e("Frame", {
				Position = UDim2.fromOffset(10, 48),
				Size = UDim2.new(1, -20, 0, 26),
				BackgroundTransparency = 1,
			}, categoryButtons),

			ItemListContainer = e("Frame", {
				Position = UDim2.fromOffset(10, 82),
				Size = UDim2.new(1, -20, 1, -92),
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
				}, itemCards),
				Empty = (matchCount == 0) and e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "ไม่พบไอเทมที่ตรงกับคำค้นหาหรือหมวดหมู่ที่เลือก",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(140, 150, 175),
				}),
			}),
		})
	elseif props.ActiveTab == "SelfSpeed" then
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

		bodyContent = e("Frame", {
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
					Text = speedInput,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamBold,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					[React.Change.Text] = function(rbx: TextBox)
						setSpeedInput(rbx.Text)
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
						local parsed = tonumber(speedInput)
						if parsed and parsed == parsed and math.abs(parsed) ~= math.huge then
							local clamped = math.clamp(parsed, AdminConfig.MinWalkSpeed, AdminConfig.MaxWalkSpeed)
							setSpeedInput(tostring(clamped))
							props.OnSetSelfWalkSpeed(clamped)
						else
							setSpeedInput(tostring(math.floor(props.SelfWalkSpeed + 0.5)))
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
	else
		-- AuditLog Tab
		local logRows: { [string]: any } = {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			Layout = e("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for idx, entry in props.AuditLogs do
			logRows["Log_" .. tostring(idx) .. "_" .. tostring(entry.Timestamp)] = e("Frame", {
				LayoutOrder = idx,
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Color3.fromRGB(26, 30, 42),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(48, 54, 72) }),
				TopLine = e("TextLabel", {
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.new(1, -20, 0, 18),
					BackgroundTransparency = 1,
					Text = `[{formatTimestamp(entry.Timestamp)}]  [{entry.Action}]  {entry.AdminName}  →  {entry.TargetName}`,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(235, 242, 255),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				DetailLine = e("TextLabel", {
					Position = UDim2.fromOffset(10, 26),
					Size = UDim2.new(1, -20, 0, 16),
					BackgroundTransparency = 1,
					Text = entry.Detail,
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextColor3 = Color3.fromRGB(165, 178, 205),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
		end

		bodyContent = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(17, 19, 26),
			BackgroundTransparency = 0.12,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(45, 50, 66) }),
			Header = e("TextLabel", {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -24, 0, 20),
				BackgroundTransparency = 1,
				Text = `ประวัติคำสั่ง Admin ({#props.AuditLogs}/{AdminConfig.MaxAuditLogEntries})`,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(205, 215, 235),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			List = if #props.AuditLogs == 0
				then e("TextLabel", {
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(1, 0, 1, -30),
					BackgroundTransparency = 1,
					Text = "ยังไม่มีประวัติการใช้งานคำสั่ง Admin ในเซสชันนี้",
					Font = Enum.Font.GothamMedium,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(140, 150, 175),
				})
				else e("ScrollingFrame", {
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(1, 0, 1, -30),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(95, 105, 135),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				}, logRows),
		})
	end

	return e("Frame", {
		Size = UDim2.fromOffset(760, 480),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BackgroundTransparency = 0.04,
		ZIndex = 25,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Stroke = e("UIStroke", {
			Thickness = 2,
			Color = Color3.fromRGB(72, 78, 102),
		}),

		Header = e("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
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
				Position = UDim2.fromOffset(18, 0),
				Size = UDim2.new(0.55, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "ADMIN CONTROL PANEL [M]",
				Font = Enum.Font.GothamBlack,
				TextSize = 18,
				TextColor3 = Color3.fromRGB(245, 247, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			RefreshBtn = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -104, 0.5, 0),
				Size = UDim2.fromOffset(88, 32),
				BackgroundColor3 = Color3.fromRGB(46, 115, 210),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = "Refresh",
				AutoButtonColor = true,
				[React.Event.Activated] = props.OnRefreshPlayers,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			CloseBtn = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = Color3.fromRGB(210, 65, 75),
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = "ปิด [M]",
				AutoButtonColor = true,
				[React.Event.Activated] = props.OnClose,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),

		TabBar = e("Frame", {
			Position = UDim2.fromOffset(14, 62),
			Size = UDim2.new(1, -28, 0, 34),
			BackgroundTransparency = 1,
		}, tabBarChildren),

		Body = e("Frame", {
			Position = UDim2.fromOffset(14, 104),
			Size = UDim2.new(1, -28, 1, -118),
			BackgroundTransparency = 1,
		}, {
			Content = bodyContent,
		}),
	})
end

return AdminPanelFrame
