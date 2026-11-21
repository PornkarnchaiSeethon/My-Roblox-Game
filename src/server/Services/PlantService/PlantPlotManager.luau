--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local PlantPlotManager = {}

function PlantPlotManager.FindPlanterInstance(plotModel: Model?, objectId: string): Model?
	if not plotModel then
		return nil
	end
	local objectsFolder = plotModel:FindFirstChild("Objects")
	if not objectsFolder then
		return nil
	end
	for _, child in objectsFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ObjectId") == objectId then
			return child
		end
	end
	return nil
end

function PlantPlotManager.HasSprinklerInRange(plotModel: Model?, targetPos: Vector3): boolean
	if not plotModel then
		return false
	end
	local objectsFolder = plotModel:FindFirstChild("Objects")
	if not objectsFolder then
		return false
	end
	for _, child in objectsFolder:GetChildren() do
		if child:IsA("Model") and child.Name == "hydro_sprinkler" then
			if (child:GetPivot().Position - targetPos).Magnitude <= PlantConfig.SprinklerRadiusStuds then
				return true
			end
		end
	end
	return false
end

function PlantPlotManager.ApplyVisualAttributes(planterModel: Model, planterData: any?, now: number)
	if not planterData then
		planterModel:SetAttribute("CropId", "")
		planterModel:SetAttribute("PlantStage", "")
		planterModel:SetAttribute("IsWet", false)
		planterModel:SetAttribute("MoistureUntil", 0)
		planterModel:SetAttribute("GrowthProgress", 0)
		return
	end

	local moistureUntil = planterData.MoistureUntil or 0
	local progress = planterData.GrowthProgress or 0
	planterModel:SetAttribute("CropId", planterData.CropId or "")
	planterModel:SetAttribute("PlantStage", planterData.Stage or "Seed")
	planterModel:SetAttribute("IsWet", moistureUntil > now)
	planterModel:SetAttribute("MoistureUntil", moistureUntil)
	planterModel:SetAttribute("GrowthProgress", math.round(progress * 100) / 100)
end

function PlantPlotManager.BindPlanterPrompt(
	planterModel: Model,
	ownerPlayer: Player,
	onInteract: (Player, string, string) -> ()
)
	local planterDef = PlantConfig.Planters[planterModel.Name]
	if not planterDef then
		return
	end
	local targetPart = planterModel.PrimaryPart or planterModel:FindFirstChildWhichIsA("BasePart", true)
	if not targetPart or targetPart:FindFirstChild("PlantInteractPrompt") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlantInteractPrompt"
	prompt.ActionText = "จัดการแปลงปลูก"
	prompt.ObjectText = planterDef.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = targetPart

	prompt.Triggered:Connect(function(triggerPlayer: Player)
		if triggerPlayer ~= ownerPlayer then
			return
		end
		local objectId = planterModel:GetAttribute("ObjectId")
		if typeof(objectId) == "string" and objectId ~= "" then
			onInteract(triggerPlayer, objectId, planterModel.Name)
		end
	end)
end

return PlantPlotManager
