--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local PetPlotBrain = require(script.Parent.PetPlotBrain)

local PetCombatController = {}

type ActiveCombatPet = {
	Model: Model,
	ModelKey: string,
	CurrentCF: CFrame,
}

local playerCombatPets: { [Player]: { [string]: ActiveCombatPet } } = {}
local lastAttackMap: { [string]: number } = {}

local function getGroundedPosition(x: number, refY: number, z: number, pivotHeight: number, player: Player): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, folderName in { "ActiveCombatPets", "Enemies", "NPCs", "NPCSpawns" } do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			table.insert(exclude, folder)
		end
	end
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude

	local hit = workspace:Raycast(Vector3.new(x, refY + 6, z), Vector3.new(0, -24, 0), params)
	if hit then
		return Vector3.new(x, hit.Position.Y + pivotHeight, z)
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fallbackFloorY = if humanoid and rootPart
		then (rootPart.Position.Y - (if humanoid.HipHeight > 0 then humanoid.HipHeight + rootPart.Size.Y * 0.5 else 3))
		else (refY - 3)
	return Vector3.new(x, fallbackFloorY + pivotHeight, z)
end

local function getCombatPetsFolder(): Folder
	local folder = workspace:FindFirstChild("ActiveCombatPets")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "ActiveCombatPets"
	created.Parent = workspace
	return created
end

function PetCombatController.SyncPlayerCombatPets(player: Player, petsInstances: { [string]: any })
	local activeMap = playerCombatPets[player]
	if not activeMap then
		activeMap = {}
		playerCombatPets[player] = activeMap
	end

	local combatFolder = getCombatPetsFolder()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	for uid, entry in activeMap do
		local petData = petsInstances[uid]
		if not petData or petData.State ~= "Equipped" or not entry.Model.Parent then
			if entry.Model and entry.Model.Parent then
				entry.Model:Destroy()
			end
			activeMap[uid] = nil
			lastAttackMap[uid] = nil
		end
	end

	local slotIndex = 0
	for uid, petData in petsInstances do
		if petData.State ~= "Equipped" then
			continue
		end
		slotIndex += 1

		local species = PetConfig.Species[petData.SpeciesId]
		local stage = (petData.Stage or "Baby") :: PetConfig.PetStage
		local expectedKey = if species then (species.ModelByStage[stage] or petData.SpeciesId) else petData.SpeciesId

		local existing = activeMap[uid]
		if existing and existing.ModelKey ~= expectedKey then
			local prevCF = existing.CurrentCF
			existing.Model:Destroy()
			activeMap[uid] = nil
			existing = nil

			local swappedModel, key = PetPlotBrain.CreatePetModel(player, petData)
			local pivotHeight = PetPlotBrain.GetPivotHeightAboveBottom(swappedModel)
			local groundedPos = getGroundedPosition(prevCF.Position.X, prevCF.Position.Y, prevCF.Position.Z, pivotHeight, player)
			local spawnCF = CFrame.new(groundedPos) * prevCF.Rotation
			swappedModel:SetAttribute("CombatSlot", slotIndex)
			swappedModel:PivotTo(spawnCF)
			swappedModel.Parent = combatFolder
			activeMap[uid] = { Model = swappedModel, ModelKey = key, CurrentCF = spawnCF }
			continue
		end

		if not existing then
			local model, key = PetPlotBrain.CreatePetModel(player, petData)
			local pivotHeight = PetPlotBrain.GetPivotHeightAboveBottom(model)
			local spawnCF = model:GetPivot()
			if rootPart then
				local angle = math.rad(135 + (slotIndex - 1) * 45)
				local flatOffset = Vector3.new(math.cos(angle) * 4.5, 0, math.sin(angle) * 4.5)
				local worldPos = (rootPart.CFrame * CFrame.new(flatOffset)).Position
				local groundedPos = getGroundedPosition(worldPos.X, rootPart.Position.Y, worldPos.Z, pivotHeight, player)
				local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
				spawnCF = if flatLook.Magnitude > 0.01
					then CFrame.lookAt(groundedPos, groundedPos + flatLook)
					else CFrame.new(groundedPos)
				model:PivotTo(spawnCF)
			end
			model:SetAttribute("CombatSlot", slotIndex)
			model.Parent = combatFolder
			activeMap[uid] = { Model = model, ModelKey = key, CurrentCF = spawnCF }
		else
			PetPlotBrain.UpdateModelAttributes(existing.Model, petData)
			existing.Model:SetAttribute("CombatSlot", slotIndex)
		end
	end
end

function PetCombatController.StepPlayerCompanions(
	player: Player,
	petsInstances: { [string]: any },
	enemyController: any,
	onAttackVisual: (string, Vector3) -> ()
)
	local activeMap = playerCombatPets[player]
	if not activeMap then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local equippedUIDs: { string } = {}
	for uid in activeMap do
		table.insert(equippedUIDs, uid)
	end
	table.sort(equippedUIDs)

	local now = os.clock()
	for slotIndex, uid in equippedUIDs do
		local entry = activeMap[uid]
		local petData = petsInstances[uid]
		if not entry or not entry.Model.Parent or not petData or petData.State ~= "Equipped" then
			continue
		end

		local species = PetConfig.Species[petData.SpeciesId]
		if not species then
			continue
		end

		if entry.Model:GetAttribute("CombatSlot") ~= slotIndex then
			entry.Model:SetAttribute("CombatSlot", slotIndex)
		end

		local pivotHeight = tonumber(entry.Model:GetAttribute("PivotHeightOffset")) or 0
		local targetEnemy = enemyController and enemyController.GetNearestEnemy(rootPart.Position, species.AttackRange)
		local enemyPart: BasePart? = if targetEnemy
			then (targetEnemy.PrimaryPart or targetEnemy:FindFirstChild("HumanoidRootPart") :: BasePart?)
			else nil

		if targetEnemy and enemyPart then
			local enemyPos = enemyPart.Position
			local angle = math.rad((slotIndex - 1) * 120)
			local attackX = enemyPos.X + math.cos(angle) * 3.5
			local attackZ = enemyPos.Z + math.sin(angle) * 3.5
			local attackPos = getGroundedPosition(attackX, enemyPos.Y, attackZ, pivotHeight, player)
			local lookPos = Vector3.new(enemyPos.X, attackPos.Y, enemyPos.Z)
			entry.CurrentCF = if (lookPos - attackPos).Magnitude > 0.01
				then CFrame.lookAt(attackPos, lookPos)
				else CFrame.new(attackPos)
			entry.Model:SetAttribute("CombatTargetPos", enemyPos)

			local prevAttack = lastAttackMap[uid] or 0
			if (now - prevAttack) >= species.AttackCooldown then
				lastAttackMap[uid] = now
				local _, finalDamage = PetConfig.CalculateStats(petData.SpeciesId, petData.Level or 1, petData.PotentialBonus or 1.0)
				enemyController.ApplyPetDamage(player, targetEnemy, finalDamage)
				onAttackVisual(uid, enemyPos)
			end
		else
			local angle = math.rad(135 + (slotIndex - 1) * 45)
			local flatOffset = Vector3.new(math.cos(angle) * 4.5, 0, math.sin(angle) * 4.5)
			local worldPos = (rootPart.CFrame * CFrame.new(flatOffset)).Position
			local goalPos = getGroundedPosition(worldPos.X, rootPart.Position.Y, worldPos.Z, pivotHeight, player)
			local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
			entry.CurrentCF = if flatLook.Magnitude > 0.01
				then CFrame.lookAt(goalPos, goalPos + flatLook)
				else CFrame.new(goalPos)
			if entry.Model:GetAttribute("CombatTargetPos") ~= nil then
				entry.Model:SetAttribute("CombatTargetPos", nil)
			end
		end
	end
end

function PetCombatController.ClearPlayer(player: Player)
	local activeMap = playerCombatPets[player]
	if not activeMap then
		return
	end
	for uid, entry in activeMap do
		if entry.Model and entry.Model.Parent then
			entry.Model:Destroy()
		end
		lastAttackMap[uid] = nil
	end
	playerCombatPets[player] = nil
end

return PetCombatController
