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
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function setupPlayerSpawnAtPlot(player: Player)
	if characterConnections[player] then
		characterConnections[player]:Disconnect()
	end

	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		task.defer(function()
			local plot = PlotManager.getPlot(player)
			if not plot then
				return
			end
			local spawnCF = PlotManager.getPlotSpawnCFrame(player)
			if not spawnCF then
				return
			end
			local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
			if hrp and hrp:IsA("BasePart") then
				task.wait()
				if character.Parent and (hrp.Position - spawnCF.Position).Magnitude > 12 then
					PlotManager.teleportToPlot(player, character)
				end
			end
		end)
	end)
end

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

function PlotService:GetPlayerPlotModel(player: Player): Model?
	return PlotManager.getPlot(player)
end

function PlotService:RegisterDeleteValidator(validator: (Player, Model) -> (boolean, string?))
	PlotManager.registerDeleteValidator(validator)
end

function PlotService:OnPlotLoaded(callback: (Player, Model) -> ())
	PlotStorage.onPlotLoaded(callback)
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

	local function onPlayerAdded(player: Player)
		setupPlayerSpawnAtPlot(player)
		task.spawn(PlotStorage.load, player)
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		actionCooldowns[player] = nil
		if characterConnections[player] then
			characterConnections[player]:Disconnect()
			characterConnections[player] = nil
		end
		task.defer(PlotStorage.cleanup, player)
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
