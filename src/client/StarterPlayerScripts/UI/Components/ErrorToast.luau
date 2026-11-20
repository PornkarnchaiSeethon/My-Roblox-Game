local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

type Props = {
	message: string?,
	isError: boolean?,
	onDismiss: () -> (),
}

local function ErrorToast(props: Props)
	React.useEffect(function()
		if not props.message then
			return
		end

		local active = true
		task.delay(3, function()
			if active then
				props.onDismiss()
			end
		end)

		return function()
			active = false
		end
	end, { props.message })

	if not props.message then
		return nil
	end

	local isError = props.isError ~= false
	local bgColor = if isError then Color3.fromRGB(40, 20, 24) else Color3.fromRGB(20, 38, 28)
	local strokeColor = if isError then Color3.fromRGB(225, 75, 85) else Color3.fromRGB(70, 200, 120)
	local accentColor = if isError then Color3.fromRGB(235, 85, 95) else Color3.fromRGB(85, 220, 135)
	local textColor = if isError then Color3.fromRGB(255, 220, 225) else Color3.fromRGB(215, 255, 230)

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromOffset(400, 42),
		BackgroundColor3 = bgColor,
		ZIndex = 30,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1.5,
			Color = strokeColor,
		}),
		Accent = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(4, 22),
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Label = e("TextLabel", {
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -32, 1, 0),
			BackgroundTransparency = 1,
			Text = props.message,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = textColor,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return ErrorToast
