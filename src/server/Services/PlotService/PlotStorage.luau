local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Parent.DataService.DataService)
local PlotManager = require(script.Parent.PlotManager)

local PlotStorage = {}
local playersRemaining = Instance.new("NumberValue")
local loadedPlayers: { [number]: boolean } = {}

type ObjectInfo = {
	name: string,
	cf: { number },
}

local function finishPlayer(player: Player)
	if loadedPlayers[player.UserId] then
		loadedPlayers[player.UserId] = nil
		playersRemaining.Value -= 1
	end
end

function PlotStorage.load(player: Player)
	playersRemaining.Value += 1

	local profile = DataService.WaitForProfile(player)
	if not profile then
		playersRemaining.Value -= 1
		return
	end

	local success, plot = pcall(function()
		return PlotManager.spawnPlot(player)
	end)
	if not success or not plot then
		warn("Unable to create plot for " .. player.Name .. ": " .. tostring(plot))
		playersRemaining.Value -= 1
		return
	end

	loadedPlayers[player.UserId] = true
	local savedObjects = profile.Data.Plot
	if type(savedObjects) ~= "table" then
		savedObjects = {}
	end

	local objectsFolder = plot:FindFirstChild("Objects")
	if not objectsFolder then
		warn("Plot is missing its Objects folder for " .. player.Name)
		PlotManager.removePlot(player)
		finishPlayer(player)
		return
	end
	local placeableObjects = ReplicatedStorage:FindFirstChild("PlaceableObjects")
	if not placeableObjects then
		warn("ReplicatedStorage.PlaceableObjects is missing")
		PlotManager.removePlot(player)
		finishPlayer(player)
		return
	end

	for _, info in savedObjects do
		if type(info) ~= "table" or type(info.name) ~= "string" or type(info.cf) ~= "table" then
			continue
		end

		local template = placeableObjects:FindFirstChild(info.name)
		if template and template:IsA("Model") and #info.cf == 12 then
			local ok, relativeCF = pcall(function()
				return CFrame.new(table.unpack(info.cf))
			end)
			if ok and relativeCF then
				local newObject = template:Clone()
				newObject:PivotTo(plot:GetPivot():ToWorldSpace(relativeCF))
				newObject.Parent = objectsFolder
			end
		end
	end
end

function PlotStorage.save(player: Player, profileOverride)
	if not loadedPlayers[player.UserId] then
		return
	end

	local profile = profileOverride or DataService.GetProfile(player)
	local plot = PlotManager.getPlot(player)
	if not profile or not plot then
		PlotManager.removePlot(player)
		finishPlayer(player)
		return
	end

	local data: { ObjectInfo } = {}
	local objectsFolder = plot:FindFirstChild("Objects")
	if objectsFolder then
		for _, object in objectsFolder:GetChildren() do
			if object:IsA("Model") then
				local relativeCF = plot:GetPivot():ToObjectSpace(object:GetPivot())
				table.insert(data, {
					name = object.Name,
					cf = { relativeCF:GetComponents() },
				})
			end
		end
	end

	profile.Data.Plot = data
	PlotManager.removePlot(player)
	finishPlayer(player)
end

function PlotStorage.waitForSave()
	while playersRemaining.Value > 0 do
		playersRemaining.Changed:Wait()
	end
end

return PlotStorage
