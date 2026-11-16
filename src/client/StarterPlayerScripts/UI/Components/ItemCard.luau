local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local e = React.createElement

type Props = {
	stackData: Types.ClientStackData,
	isSelected: boolean,
	onSelect: () -> (),
}

local function ItemCard(props: Props)
	local stackData = props.stackData
	local displayName = stackData.DisplayName or stackData.Name
	local hasImage = stackData.Image ~= nil and stackData.Image ~= ""

	local children = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
	}

	if hasImage then
		children.Image = e("ImageLabel", {
			Image = stackData.Image,
			Size = UDim2.fromOffset(42, 42),
			Position = UDim2.fromOffset(6, 6),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
		})
	end

	return e("TextButton", {
		Size = UDim2.fromOffset(150, 72),
		BackgroundColor3 = if props.isSelected
			then Color3.fromRGB(255, 220, 100)
			else Color3.fromRGB(60, 60, 60),
		TextColor3 = Color3.new(1, 1, 1),
		Text = `{displayName}\n x{stackData.Count}`,
		TextWrapped = true,
		TextXAlignment = if hasImage then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		[React.Event.Activated] = props.onSelect,
	}, children)
end

return ItemCard
