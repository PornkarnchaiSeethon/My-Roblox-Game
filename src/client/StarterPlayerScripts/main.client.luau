local StarterPlayer = game:GetService("StarterPlayer")
local App = require(StarterPlayer.StarterPlayerScripts.UI.App)
local InventoryClient = require(script.Parent:WaitForChild("InventoryClient"))

InventoryClient.Start()
App(InventoryClient)
