--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

export type AdminPlayersTabProps = {
	PlayersList: { Types.AdminPlayerSummary },
	SelectedUserId: number,
	SelectedDetail: Types.AdminPlayerDetail?,
	LocalUserId: number,
	OnSelectPlayer: (number) -> (),
	OnOpenSpawner: () -> (),
}

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

local function AdminPlayersTab(props: AdminPlayersTabProps)
	local localUserId = props.LocalUserId

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
					[React.Event.Activated] = props.OnOpenSpawner,
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

	return e("Frame", {
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
end

return React.memo(AdminPlayersTab)
