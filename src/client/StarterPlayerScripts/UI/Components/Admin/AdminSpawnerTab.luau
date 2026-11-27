--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))

local AdminItemSpawnCard = require(script.Parent.Parent:WaitForChild("AdminItemSpawnCard"))

local e = React.createElement

export type AdminSpawnerTabProps = {
	TargetUserId: number,
	TargetDisplayName: string,
	MissingStudioItems: { [string]: boolean },
	OnGiveItemToSelf: (string, number) -> (),
	OnGiveItemToTarget: (number, string, number) -> (),
}

local SPAWN_AMOUNTS = { 1, 5, 10, 25 }
local ITEM_CATEGORIES = { "All", "Weapon", "Armor", "Special", "Consumable", "Resource" }

local function AdminSpawnerTab(props: AdminSpawnerTabProps)
	local searchText, setSearchText = React.useState("")
	local spawnAmount, setSpawnAmount = React.useState(1)
	local categoryFilter, setCategoryFilter = React.useState("All")

	local sortedItemIds = React.useMemo(function(): { string }
		local ids: { string } = {}
		for itemId in ToolConfig.Items do
			table.insert(ids, itemId)
		end
		table.sort(ids)
		return ids
	end, {})

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

	local categoryButtons: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for idx, category in ITEM_CATEGORIES do
		local active = categoryFilter == category
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
				setCategoryFilter(category)
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

		local categoryMatch = categoryFilter == "All" or itemType == categoryFilter
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
				TargetDisplayName = props.TargetDisplayName,
				IsMissingInStudio = props.MissingStudioItems[capturedItemId] == true,
				LayoutOrder = matchCount,
				OnGiveSelf = function()
					props.OnGiveItemToSelf(capturedItemId, spawnAmount)
				end,
				OnGiveTarget = function()
					props.OnGiveItemToTarget(props.TargetUserId, capturedItemId, spawnAmount)
				end,
			})
		end
	end

	return e("Frame", {
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
					Text = `เป้าหมายปัจจุบัน: {props.TargetDisplayName}`,
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
end

return React.memo(AdminSpawnerTab)
