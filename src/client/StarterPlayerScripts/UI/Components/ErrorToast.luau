local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local e = React.createElement

type Props = {
	message: string?,
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

	return e("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = Color3.fromRGB(180, 50, 50),
		TextColor3 = Color3.new(1, 1, 1),
		Text = props.message,
		TextWrapped = true,
		ZIndex = 10,
	})
end

return ErrorToast
