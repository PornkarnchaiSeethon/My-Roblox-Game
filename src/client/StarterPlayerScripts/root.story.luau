local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local MainFrame = require(script.Parent.UI.MainFrame)

return function(parent)
	local root = ReactRoblox.createRoot(parent)
	local app = React.createElement(MainFrame)
	root:render(app)

	return function()
		root:unmount()
	end
end
