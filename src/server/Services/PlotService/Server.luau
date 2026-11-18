local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local DataService = require(script.Parent.Parent.DataService.DataService)
local PlotManager = require(script.Parent.PlotManager)
local PlotStorage = require(script.Parent.PlotStorage)
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local PlotService = Knit.CreateService({
	Name = "PlotService",
	Client = {},
})
local actionCooldowns: { [Player]: { [string]: number } } = {}

local function allowAction(player: Player, actionName: string, cooldown: number): boolean
	local now = os.clock()
	local playerCooldowns = actionCooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		actionCooldowns[player] = playerCooldowns
	end

	local lastAction = playerCooldowns[actionName]
	if lastAction and now - lastAction < cooldown then
		return false
	end

	playerCooldowns[actionName] = now
	return true
end

function PlotService.sendPlot(player: Player)
	local plot = PlotManager.getPlot(player)
	if plot then
		Network.Plot.Ready.sendTo({ plot = plot }, player)
	end
end

function PlotService.Client:GetPlot(player: Player)
	return PlotManager.getPlot(player)
end

function PlotService:KnitInit()
	DataService.OnBeforeProfileRelease(function(player, profile)
		PlotStorage.save(player, profile)
	end)
end

function PlotService:KnitStart()
	Network.Plot.Request.listen(function(_, player)
		if not allowAction(player, "Request", 0.25) then return end
		PlotService.sendPlot(player)
	end)
	Network.Plot.TryPlace.listen(function(data, player)
		if not allowAction(player, "TryPlace", 0.15) then return end
		PlotManager.place(player, data.name, data.targetCF)
	end)
	Network.Plot.TryDelete.listen(function(data, player)
		if not allowAction(player, "TryDelete", 0.15) then return end
		PlotManager.delete(player, data.target)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(PlotStorage.load, player)
	end
	Players.PlayerAdded:Connect(PlotStorage.load)
	Players.PlayerRemoving:Connect(function(player)
		actionCooldowns[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlotStorage.save(player, DataService.GetProfile(player))
		end
		PlotStorage.waitForSave()
	end)
end

PlotService.Start = PlotService.KnitStart

return PlotService
