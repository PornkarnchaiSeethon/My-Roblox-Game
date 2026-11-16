local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Parent.DataService.DataService)
local PlotManager = require(script.Parent.PlotManager)
local PlotStorage = require(script.Parent.PlotStorage)
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local PlotService = {}

function PlotService.sendPlot(player: Player)
	local plot = PlotManager.getPlot(player)
	if plot then
		Network.Plot.Ready.sendTo({ plot = plot }, player)
	end
end

function PlotService.Start()
	DataService.OnBeforeProfileRelease(function(player, profile)
		PlotStorage.save(player, profile)
	end)

	Network.Plot.Request.listen(function(_, player)
		PlotService.sendPlot(player)
	end)
	Network.Plot.TryPlace.listen(function(data, player)
		PlotManager.place(player, data.name, data.targetCF)
	end)
	Network.Plot.TryDelete.listen(function(data, player)
		PlotManager.delete(player, data.target)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(PlotStorage.load, player)
	end
	Players.PlayerAdded:Connect(PlotStorage.load)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlotStorage.save(player, DataService.GetProfile(player))
		end
		PlotStorage.waitForSave()
	end)
end

return PlotService
