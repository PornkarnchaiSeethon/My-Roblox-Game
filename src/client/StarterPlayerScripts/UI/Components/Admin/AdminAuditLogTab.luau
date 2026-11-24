--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

export type AdminAuditLogTabProps = {
	AuditLogs: { Types.AdminAuditEntry },
}

local function formatTimestamp(ts: number): string
	if ts <= 0 then
		return "--:--:--"
	end
	local formatted = os.date("%H:%M:%S", ts)
	return if typeof(formatted) == "string" then formatted else tostring(ts)
end

local function AdminAuditLogTab(props: AdminAuditLogTabProps)
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

	local maxEntries = (AdminConfig.MaxAuditLogEntries or 50) + (AdminConfig.MaxCriticalAuditLogEntries or 0)

	return e("Frame", {
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
			Text = `ประวัติคำสั่ง Admin ({#props.AuditLogs}/{maxEntries})`,
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

return React.memo(AdminAuditLogTab)
