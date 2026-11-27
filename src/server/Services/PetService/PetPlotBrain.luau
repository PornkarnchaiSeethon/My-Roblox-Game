--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementValidator = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlacementValidator"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local PetPlotBrain = {}

type ActivePlotPet = {
	Model: Model,
	ModelKey: string,
	NextMoveAt: number,
	CurrentCF: CFrame,
	TargetCF: CFrame,
	IsMoving: boolean,
}

local playerPlotPets: { [Player]: { [string]: ActivePlotPet } } = {}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(110, 210, 130),
	Rare = Color3.fromRGB(85, 165, 250),
	Epic = Color3.fromRGB(185, 110, 245),
	Legendary = Color3.fromRGB(255, 195, 70),
}

local STAGE_SCALES: { [string]: Vector3 } = {
	Baby = Vector3.new(2.0, 1.8, 2.0),
	Juvenile = Vector3.new(2.6, 2.3, 2.6),
	Adult = Vector3.new(3.2, 2.8, 3.2),
	Evolved = Vector3.new(3.8, 3.4, 3.8),
}

local function prepareAnchoredModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
		elseif descendant:IsA("Humanoid") then
			descendant:Destroy()
		end
	end

	if not model:FindFirstChildOfClass("AnimationController") then
		local animController = Instance.new("AnimationController")
		animController.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = animController
	end
end

function PetPlotBrain.CreatePetModel(player: Player, petData: any): (Model, string)
	local species = PetConfig.Species[petData.SpeciesId]
	local stage = (petData.Stage or "Baby") :: PetConfig.PetStage
	local modelName = if species then (species.ModelByStage[stage] or petData.SpeciesId) else petData.SpeciesId

	local petModelsFolder = ReplicatedStorage:FindFirstChild("PetModels")
	local template = petModelsFolder and petModelsFolder:FindFirstChild(modelName)

	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Block
		body.Size = STAGE_SCALES[stage] or Vector3.new(2.5, 2.2, 2.5)
		body.Material = Enum.Material.SmoothPlastic
		body.Color = if species then (RARITY_COLORS[species.Rarity] or Color3.fromRGB(120, 200, 140)) else Color3.fromRGB(120, 200, 140)
		body.TopSurface = Enum.SurfaceType.Smooth
		body.BottomSurface = Enum.SurfaceType.Smooth
		body.Parent = model
		model.PrimaryPart = body
	end

	if not model.PrimaryPart then
		local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			model.PrimaryPart = firstPart
		end
	end

	prepareAnchoredModel(model)

	model.Name = `Pet_{petData.UID}`
	model:SetAttribute("PetUID", petData.UID)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SpeciesId", petData.SpeciesId)
	model:SetAttribute("Nickname", petData.Nickname)
	model:SetAttribute("Stage", petData.Stage)
	model:SetAttribute("Level", petData.Level)
	model:SetAttribute("Hunger", petData.Hunger)
	model:SetAttribute("State", petData.State)
	model:SetAttribute("WalkSpeed", if species then species.WalkSpeed else 10)
	model:SetAttribute("PivotHeightOffset", PetPlotBrain.GetPivotHeightAboveBottom(model))

	return model, modelName
end

function PetPlotBrain.UpdateModelAttributes(model: Model, petData: any)
	local species = PetConfig.Species[petData.SpeciesId]
	model:SetAttribute("SpeciesId", petData.SpeciesId)
	model:SetAttribute("Nickname", petData.Nickname)
	model:SetAttribute("Stage", petData.Stage)
	model:SetAttribute("Level", petData.Level)
	model:SetAttribute("Hunger", petData.Hunger)
	model:SetAttribute("State", petData.State)
	model:SetAttribute("WalkSpeed", if species then species.WalkSpeed else 10)
end

function PetPlotBrain.GetPivotHeightAboveBottom(petModel: Model): number
	local pivotY = petModel:GetPivot().Position.Y
	local lowestY = math.huge

	for _, descendant in petModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local cf = descendant.CFrame
			local half = descendant.Size * 0.5
			local extentY = math.abs(cf.XVector.Y) * half.X
				+ math.abs(cf.YVector.Y) * half.Y
				+ math.abs(cf.ZVector.Y) * half.Z
			local partBottomY = cf.Position.Y - extentY
			if partBottomY < lowestY then
				lowestY = partBottomY
			end
		end
	end

	if lowestY == math.huge then
		local bboxCF, bboxSize = petModel:GetBoundingBox()
		lowestY = bboxCF.Position.Y - (bboxSize.Y * 0.5)
	end

	return pivotY - lowestY
end

function PetPlotBrain.PickRandomPointInPlot(plotModel: Model, petModel: Model): CFrame
	local primary = plotModel.PrimaryPart
	if not primary then
		return plotModel:GetPivot()
	end

	local _, petSize = petModel:GetBoundingBox()
	local halfX = math.max(1, (primary.Size.X * 0.5) - math.max(4, petSize.X))
	local halfZ = math.max(1, (primary.Size.Z * 0.5) - math.max(4, petSize.Z))
	local yOffset = (primary.Size.Y * 0.5) + PetPlotBrain.GetPivotHeightAboveBottom(petModel)

	for _ = 1, 8 do
		local offsetX = (math.random() * 2 - 1) * halfX
		local offsetZ = (math.random() * 2 - 1) * halfZ
		local candidateCF = primary.CFrame * CFrame.new(offsetX, yOffset, offsetZ)
		if PlacementValidator.withinBounds(plotModel, petSize, candidateCF) then
			return candidateCF
		end
	end

	return primary.CFrame * CFrame.new(0, yOffset, 0)
end

function PetPlotBrain.SyncPlayerPlotPets(player: Player, plotModel: Model?, petsInstances: { [string]: any })
	local activeMap = playerPlotPets[player]
	if not activeMap then
		activeMap = {}
		playerPlotPets[player] = activeMap
	end

	if not plotModel or not plotModel.Parent then
		PetPlotBrain.ClearPlayer(player)
		return
	end

	local petsFolder = plotModel:FindFirstChild("Pets")
	if not petsFolder then
		local folder = Instance.new("Folder")
		folder.Name = "Pets"
		folder.Parent = plotModel
		petsFolder = folder
	end

	for uid, entry in activeMap do
		local petData = petsInstances[uid]
		if not petData or petData.State ~= "InPlot" or not entry.Model.Parent then
			if entry.Model and entry.Model.Parent then
				entry.Model:Destroy()
			end
			activeMap[uid] = nil
		end
	end

	for uid, petData in petsInstances do
		if petData.State ~= "InPlot" then
			continue
		end

		local species = PetConfig.Species[petData.SpeciesId]
		local stage = (petData.Stage or "Baby") :: PetConfig.PetStage
		local expectedKey = if species then (species.ModelByStage[stage] or petData.SpeciesId) else petData.SpeciesId

		local existing = activeMap[uid]
		if existing and existing.ModelKey ~= expectedKey then
			local prevCF = existing.CurrentCF
			local prevTargetCF = existing.TargetCF
			local prevNextMoveAt = existing.NextMoveAt
			local prevIsMoving = existing.IsMoving
			existing.Model:Destroy()
			activeMap[uid] = nil
			existing = nil

			local swappedModel, key = PetPlotBrain.CreatePetModel(player, petData)
			local primary = plotModel.PrimaryPart
			if primary then
				local groundY = primary.Position.Y + (primary.Size.Y * 0.5) + PetPlotBrain.GetPivotHeightAboveBottom(swappedModel)
				prevCF = CFrame.new(prevCF.Position.X, groundY, prevCF.Position.Z) * prevCF.Rotation
				prevTargetCF = CFrame.new(prevTargetCF.Position.X, groundY, prevTargetCF.Position.Z) * prevTargetCF.Rotation
			end
			swappedModel:PivotTo(prevCF)
			swappedModel:SetAttribute("MoveTarget", prevTargetCF.Position)
			swappedModel.Parent = petsFolder
			activeMap[uid] = {
				Model = swappedModel,
				ModelKey = key,
				NextMoveAt = prevNextMoveAt,
				CurrentCF = prevCF,
				TargetCF = prevTargetCF,
				IsMoving = prevIsMoving,
			}
			continue
		end

		if not existing then
			local model, key = PetPlotBrain.CreatePetModel(player, petData)
			local spawnCF = PetPlotBrain.PickRandomPointInPlot(plotModel, model)
			model:PivotTo(spawnCF)
			model:SetAttribute("MoveTarget", spawnCF.Position)
			model.Parent = petsFolder
			activeMap[uid] = {
				Model = model,
				ModelKey = key,
				NextMoveAt = os.clock() + math.random(2, 6),
				CurrentCF = spawnCF,
				TargetCF = spawnCF,
				IsMoving = false,
			}
		else
			PetPlotBrain.UpdateModelAttributes(existing.Model, petData)
		end
	end
end

function PetPlotBrain.StepWandering(player: Player, plotModel: Model?, petsInstances: { [string]: any }, dt: number)
	local activeMap = playerPlotPets[player]
	if not activeMap or not plotModel or not plotModel.Parent then
		return
	end

	local now = os.clock()
	for uid, entry in activeMap do
		local petData = petsInstances[uid]
		if not petData or petData.State ~= "InPlot" or not entry.Model.Parent then
			continue
		end

		local currentCF = entry.CurrentCF
		local delta = entry.TargetCF.Position - currentCF.Position
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		local dist = flatDelta.Magnitude

		local species = PetConfig.Species[petData.SpeciesId]
		local speed = if species then species.WalkSpeed else 10

		if dist > 0.6 then
			local stepDist = math.min(dist, speed * dt)
			local nextPos = currentCF.Position + (flatDelta.Unit * stepDist)
			local targetLook = Vector3.new(entry.TargetCF.Position.X, nextPos.Y, entry.TargetCF.Position.Z)
			local nextCF = if (targetLook - nextPos).Magnitude > 0.01
				then CFrame.lookAt(nextPos, targetLook)
				else CFrame.new(nextPos)
			entry.CurrentCF = nextCF
			entry.IsMoving = true
		elseif entry.IsMoving then
			entry.CurrentCF = entry.TargetCF
			entry.IsMoving = false
			entry.NextMoveAt = now + math.random(2, 6)
		elseif now >= entry.NextMoveAt then
			entry.TargetCF = PetPlotBrain.PickRandomPointInPlot(plotModel, entry.Model)
			entry.IsMoving = true
			entry.Model:SetAttribute("WalkSpeed", speed)
			entry.Model:SetAttribute("MoveTarget", entry.TargetCF.Position)
		end
	end
end

function PetPlotBrain.ClearPlayer(player: Player)
	local activeMap = playerPlotPets[player]
	if not activeMap then
		return
	end
	for _, entry in activeMap do
		if entry.Model and entry.Model.Parent then
			entry.Model:Destroy()
		end
	end
	playerPlotPets[player] = nil
end

return PetPlotBrain
