--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local PetPlotBrain = require(script.Parent.PetPlotBrain)

local PetCombatController = {}

type ActiveCombatPet = {
	Model: Model,
	ModelKey: string,
}

local playerCombatPets: { [Player]: { [string]: ActiveCombatPet } } = {}
local lastAttackMap: { [string]: number } = {}

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

	-- ลบโมเดลที่ไม่ได้อยู่ในสถานะ Equipped แล้ว
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

	-- สร้างหรืออัปเดตโมเดลสัตว์เลี้ยงที่อยู่ในทีมต่อสู้
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
			local prevCF = existing.Model:GetPivot()
			existing.Model:Destroy()
			activeMap[uid] = nil
			existing = nil

			local swappedModel, key = PetPlotBrain.CreatePetModel(player, petData)
			swappedModel:PivotTo(prevCF)
			swappedModel.Parent = combatFolder
			activeMap[uid] = { Model = swappedModel, ModelKey = key }
			continue
		end

		if not existing then
			local model, key = PetPlotBrain.CreatePetModel(player, petData)
			if rootPart then
				local angle = math.rad(135 + (slotIndex - 1) * 45)
				local offset = Vector3.new(math.cos(angle) * 4.5, 1.5, math.sin(angle) * 4.5)
				model:PivotTo(rootPart.CFrame * CFrame.new(offset))
			end
			model.Parent = combatFolder
			activeMap[uid] = { Model = model, ModelKey = key }
		else
			PetPlotBrain.UpdateModelAttributes(existing.Model, petData)
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

	-- เรียง UID เพื่อตำแหน่ง Formation ที่คงที่
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

		local targetEnemy = enemyController and enemyController.GetNearestEnemy(rootPart.Position, species.AttackRange)
		local enemyPart: BasePart? = if targetEnemy
			then (targetEnemy.PrimaryPart or targetEnemy:FindFirstChild("HumanoidRootPart") :: BasePart?)
			else nil

		if targetEnemy and enemyPart then
			local enemyPos = enemyPart.Position
			local angle = math.rad((slotIndex - 1) * 120)
			local attackPos = enemyPos + Vector3.new(math.cos(angle) * 3.5, 1.5, math.sin(angle) * 3.5)
			entry.Model:PivotTo(CFrame.lookAt(attackPos, enemyPos))

			local prevAttack = lastAttackMap[uid] or 0
			if (now - prevAttack) >= species.AttackCooldown then
				lastAttackMap[uid] = now
				local _, finalDamage = PetConfig.CalculateStats(petData.SpeciesId, petData.Level or 1, petData.PotentialBonus or 1.0)
				enemyController.ApplyPetDamage(player, targetEnemy, finalDamage)
				onAttackVisual(uid, enemyPos)
			end
		else
			local angle = math.rad(135 + (slotIndex - 1) * 45)
			local followOffset = Vector3.new(math.cos(angle) * 4.5, 1.5, math.sin(angle) * 4.5)
			local goalPos = (rootPart.CFrame * CFrame.new(followOffset)).Position
			local lookTarget = goalPos + rootPart.CFrame.LookVector
			entry.Model:PivotTo(CFrame.lookAt(goalPos, lookTarget))
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
