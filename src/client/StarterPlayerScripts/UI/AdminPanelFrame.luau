--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local AdminTabs = script.Parent.Components:WaitForChild("Admin")
local AdminPlayersTab = require(AdminTabs:WaitForChild("AdminPlayersTab"))
local AdminSpawnerTab = require(AdminTabs:WaitForChild("AdminSpawnerTab"))
local AdminSelfSpeedTab = require(AdminTabs:WaitForChild("AdminSelfSpeedTab"))
local AdminAuditLogTab = require(AdminTabs:WaitForChild("AdminAuditLogTab"))

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

local function AdminPanelFrame(props: AdminPanelProps)
	local onSelectTab = props.OnSelectTab
	local handleOpenSpawner = React.useCallback(function()
		onSelectTab("Spawner")
	end, { onSelectTab })

	local localPlayer = Players.LocalPlayer
	local localUserId = if localPlayer then localPlayer.UserId else 0

	-- หาชื่อเป้าหมายปัจจุบันสำหรับส่งให้หน้า Spawner
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

	-- Mount เฉพาะแท็บที่เปิดใช้งานอยู่เพื่อลดต้นทุนการ Re-render
	local bodyContent: any
	if props.ActiveTab == "Players" then
		bodyContent = e(AdminPlayersTab, {
			PlayersList = props.PlayersList,
			SelectedUserId = props.SelectedUserId,
			SelectedDetail = props.SelectedDetail,
			LocalUserId = localUserId,
			OnSelectPlayer = props.OnSelectPlayer,
			OnOpenSpawner = handleOpenSpawner,
		})
	elseif props.ActiveTab == "Spawner" then
		bodyContent = e(AdminSpawnerTab, {
			TargetUserId = targetUserId,
			TargetDisplayName = targetDisplayName,
			MissingStudioItems = props.MissingStudioItems,
			OnGiveItemToSelf = props.OnGiveItemToSelf,
			OnGiveItemToTarget = props.OnGiveItemToTarget,
		})
	elseif props.ActiveTab == "SelfSpeed" then
		bodyContent = e(AdminSelfSpeedTab, {
			SelfWalkSpeed = props.SelfWalkSpeed,
			OnSetSelfWalkSpeed = props.OnSetSelfWalkSpeed,
		})
	else
		bodyContent = e(AdminAuditLogTab, {
			AuditLogs = props.AuditLogs,
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

return React.memo(AdminPanelFrame)
