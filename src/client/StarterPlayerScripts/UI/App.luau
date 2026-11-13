local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])

local MainFrame = require(script.Parent.MainFrame)

return function()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local container = Instance.new("ScreenGui")
	container.Name = "App"
	container.ResetOnSpawn = false
	container.IgnoreGuiInset = true
	container.ClipToDeviceSafeArea = false
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.Parent = playerGui

	local root = ReactRoblox.createRoot(container)
	local app = React.createElement(MainFrame)
	root:render(app)
end
