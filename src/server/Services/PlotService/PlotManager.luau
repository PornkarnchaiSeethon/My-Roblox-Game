local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotSpawnPool = require(script.Parent.PlotSpawnPool)
local PlacementValidator = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlacementValidator"))

local PlotManager = {}
local plots: { [number]: Model } = {}

-- สร้าง Plot ประจำตัวผู้เล่น
function PlotManager.spawnPlot(player: Player): Model
	local existingPlot = plots[player.UserId]
	if existingPlot then
		return existingPlot
	end

	local plotTemplate = ServerStorage:FindFirstChild("Plot")
	local plotsFolder = workspace:FindFirstChild("Plots")
	assert(plotTemplate and plotTemplate:IsA("Model"), "ServerStorage.Plot is missing or is not a Model")
	assert(plotsFolder and plotsFolder:IsA("Folder"), "Workspace.Plots is missing or is not a Folder")
	local plot = plotTemplate:Clone()
	local plotSpawn = PlotSpawnPool.get(player)
	
	plot.Name = `{player.Name}_Plot`
	plot:PivotTo(plotSpawn.CFrame)
	plot.Parent = plotsFolder
	
	plots[player.UserId] = plot
	return plot
end

function PlotManager.getPlot(player: Player): Model?
	return plots[player.UserId]
end

-- ลบ Plot และคืนพื้นที่เมื่อผู้เล่นออก
function PlotManager.removePlot(player: Player)
	local plot = plots[player.UserId]
	if plot then
		plot:Destroy()
		plots[player.UserId] = nil
	end
	PlotSpawnPool.returnPlot(player)
end

-- วางวัตถุลงใน Plot หลังผ่านการตรวจสอบความถูกต้อง
function PlotManager.place(player: Player, name: string, targetCF: CFrame): boolean
	if typeof(name) ~= "string" then
		return false
	end

	local placeableObjects = ReplicatedStorage:FindFirstChild("PlaceableObjects")
	local object = placeableObjects and placeableObjects:FindFirstChild(name)
	local plot = plots[player.UserId]
	if not object or not plot or typeof(targetCF) ~= "CFrame" then
		return false
	end
	if not object:IsA("Model") then
		return false
	end

	local objectsFolder = plot:FindFirstChild("Objects")
	if not objectsFolder then
		return false
	end
	
	local _, objectSize = object:GetBoundingBox()
	if not PlacementValidator.withinBounds(plot, objectSize, targetCF) then
		return false
	end
	if not PlacementValidator.noCollisions(plot, objectSize, targetCF) then
		return false
	end
	
	local newObject = object:Clone()
	newObject:PivotTo(targetCF)
	newObject.Parent = objectsFolder
	return true
end

-- ลบวัตถุออกจาก Plot ของผู้เล่น
function PlotManager.delete(player: Player, targetInstance: Instance): boolean
	local plot = plots[player.UserId]
	local objectsFolder = plot and plot:FindFirstChild("Objects")
	if not plot or not objectsFolder or typeof(targetInstance) ~= "Instance" then
		return false
	end
	
	local actualObject = if targetInstance:IsA("Model") and targetInstance.Parent == objectsFolder
		then targetInstance
		else targetInstance:FindFirstAncestorWhichIsA("Model")
		
	if actualObject and actualObject.Parent == objectsFolder then
		actualObject:Destroy()
		return true
	end
	
	return false
end

return PlotManager
