--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

export type Props = {
	Dialogue: Types.NPCDialoguePayload?,
	OnClose: (() -> ())?,
	npcClient: any?,
}

local function NPCDialogueModalInner(props: Props)
	local _, setRevision = React.useState(0)
	local pageIdx, setPageIdx = React.useState(1)

	React.useEffect(function()
		local npcClient = props.npcClient
		if not npcClient then
			return
		end
		local sub = npcClient.SubscribeDialogue or npcClient.Subscribe
		if not sub then
			return
		end
		return sub(function()
			setRevision(function(prev)
				return prev + 1
			end)
		end)
	end, { props.npcClient })

	local dialogue: Types.NPCDialoguePayload? = if props.Dialogue ~= nil
		then props.Dialogue
		elseif props.npcClient and props.npcClient.State then props.npcClient.State.ActiveDialogue
		else nil
	local dialogueUID = if dialogue then dialogue.NPCUID else ""

	React.useEffect(function()
		setPageIdx(1)
	end, { dialogueUID })

	if not dialogue then
		return nil
	end

	local onClose: (() -> ())? = props.OnClose or (if props.npcClient then props.npcClient.CloseDialogue else nil)
	local total = math.max(1, #dialogue.Lines)
	local clampedPage = math.clamp(pageIdx, 1, total)
	local currentLine = dialogue.Lines[clampedPage] or ""
	local isLastPage = clampedPage >= total

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(560, 176),
		BackgroundColor3 = Color3.fromRGB(22, 24, 32),
		BackgroundTransparency = 0.04,
		ZIndex = 25,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", {
			Thickness = 1.5,
			Color = Color3.fromRGB(80, 155, 235),
		}),

		Header = e("Frame", {
			Position = UDim2.fromOffset(16, 12),
			Size = UDim2.new(1, -32, 0, 26),
			BackgroundTransparency = 1,
			ZIndex = 26,
		}, {
			SpeakerName = e("TextLabel", {
				Size = UDim2.new(1, -90, 1, 0),
				BackgroundTransparency = 1,
				Text = dialogue.DisplayName,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				TextColor3 = Color3.fromRGB(145, 205, 255),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 26,
			}),
			PageCounter = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -32, 0, 0),
				Size = UDim2.fromOffset(54, 26),
				BackgroundTransparency = 1,
				Text = string.format("%d / %d", clampedPage, total),
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(180, 190, 215),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 26,
			}),
			CloseIcon = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = Color3.fromRGB(36, 40, 54),
				Text = "X",
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(220, 225, 240),
				AutoButtonColor = true,
				ZIndex = 26,
				[React.Event.Activated] = function()
					if onClose then
						onClose()
					end
				end,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		Divider = e("Frame", {
			Position = UDim2.fromOffset(16, 44),
			Size = UDim2.new(1, -32, 0, 1),
			BackgroundColor3 = Color3.fromRGB(58, 64, 84),
			BorderSizePixel = 0,
			ZIndex = 26,
		}),

		BodyText = e("TextLabel", {
			Position = UDim2.fromOffset(16, 54),
			Size = UDim2.new(1, -32, 1, -110),
			BackgroundTransparency = 1,
			Text = currentLine,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(238, 242, 252),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 26,
		}),

		ActionButton = e("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -14),
			Size = UDim2.fromOffset(128, 34),
			BackgroundColor3 = if isLastPage
				then Color3.fromRGB(185, 65, 82)
				else Color3.fromRGB(68, 125, 235),
			Text = if isLastPage then "ปิดหน้าต่าง" else "ถัดไป ->",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = Color3.fromRGB(250, 252, 255),
			AutoButtonColor = true,
			ZIndex = 26,
			[React.Event.Activated] = function()
				if isLastPage then
					if onClose then
						onClose()
					end
				else
					setPageIdx(clampedPage + 1)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = e("UIStroke", {
				Thickness = 1,
				Color = if isLastPage
					then Color3.fromRGB(240, 130, 145)
					else Color3.fromRGB(130, 180, 255),
			}),
		}),
	})
end

return React.memo(NPCDialogueModalInner)
