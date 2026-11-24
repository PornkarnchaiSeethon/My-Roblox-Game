--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

export type Props = {
	Boss: Types.NPCBossSummary?,
	npcClient: any?,
}

local function NPCBossBarInner(props: Props)
	local _, setRevision = React.useState(0)

	React.useEffect(function()
		local npcClient = props.npcClient
		if not npcClient then
			return
		end
		local sub = npcClient.SubscribeBosses or npcClient.Subscribe
		if not sub then
			return
		end
		return sub(function()
			setRevision(function(prev)
				return prev + 1
			end)
		end)
	end, { props.npcClient })

	local boss: Types.NPCBossSummary? = if props.Boss ~= nil
		then props.Boss
		elseif props.npcClient and props.npcClient.GetNearbyBoss then props.npcClient.GetNearbyBoss()
		elseif props.npcClient and props.npcClient.State and props.npcClient.State.ActiveBosses then props.npcClient.State.ActiveBosses[1]
		else nil

	if not boss or boss.HP <= 0 then
		return nil
	end

	local maxHP = math.max(1, boss.MaxHP)
	local ratio = math.clamp(boss.HP / maxHP, 0, 1)
	local isCasting = boss.CastingSkillName ~= ""
	local titleText = string.format("Lv.%d %s", math.floor(boss.Level), boss.DisplayName)
	if isCasting then
		titleText = titleText .. " | กำลังร่าย: " .. boss.CastingSkillName
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(460, 56),
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BackgroundTransparency = 0.06,
		ZIndex = 18,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1.5,
			Color = if isCasting then Color3.fromRGB(245, 130, 85) else Color3.fromRGB(165, 58, 72),
		}),

		Header = e("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 20),
			BackgroundTransparency = 1,
			Text = titleText,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = if isCasting then Color3.fromRGB(255, 210, 130) else Color3.fromRGB(245, 247, 255),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 19,
		}),

		BarTrack = e("Frame", {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 18),
			BackgroundColor3 = Color3.fromRGB(14, 16, 22),
			BorderSizePixel = 0,
			ZIndex = 19,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(58, 64, 84),
			}),
			Fill = e("Frame", {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = Color3.fromRGB(215, 58, 68),
				BorderSizePixel = 0,
				ZIndex = 19,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			HPText = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = string.format("%.0f / %.0f HP", math.max(0, boss.HP), maxHP),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.45,
				ZIndex = 20,
			}),
		}),
	})
end

return React.memo(NPCBossBarInner)
