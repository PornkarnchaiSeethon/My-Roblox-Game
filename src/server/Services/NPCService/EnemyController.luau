--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local DataService = require(script.Parent.Parent.DataService.DataService)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)
local AnimController = require(script.Parent.AnimController)
local NPCSpawnManager = require(script.Parent.NPCSpawnManager)
local NPCSkillManager = require(script.Parent.NPCSkillManager)

local EnemyController = {}

export type EnemyRecord = {
	UID: string,
	Model: Model,
	Definition: Types.NPCDefinition,
	SpawnPos: Vector3,
	ZoneId: string,
	PatrolRadius: number,
	HalfHeight: number,
	HP: number,
	IsDead: boolean,
	State: Types.NPCAIState,
	TargetPlayer: Player?,
	PatrolTarget: Vector3?,
	NextPatrolAt: number,
	LastBasicAttackAt: number,
	BusyUntil: number,
	ActiveSkillId: string,
	Contributors: { [Player]: number },
}

export type BossSyncEntry = {
	Summary: Types.NPCBossSummary,
	Position: Vector3,
}

local enemiesByUID: { [string]: EnemyRecord } = {}
local enemiesByModel: { [Model]: EnemyRecord } = {}
local registeredEnemies: { [Model]: boolean } = {}
local onEnemyDiedCallback: ((string, string) -> ())? = nil

local function isAliveLegacyEnemy(enemy: Model): boolean
	if not enemy.Parent then
		return false
	end
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health > 0
	end
	local hp = enemy:GetAttribute("HP")
	if type(hp) == "number" then
		return hp > 0
	end
	return false
end

local function getEnemyPosition(enemy: Model): Vector3?
	if enemy.PrimaryPart then
		return enemy.PrimaryPart.Position
	end
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return enemy:GetPivot().Position
end

local function getAlivePlayerRoot(player: Player): (Humanoid?, BasePart?)
	if not player.Parent then
		return nil, nil
	end
	local char = player.Character
	if not char or not char.Parent then
		return nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, hrp
end

local function buildGroundRaycastParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, folderName in { "Enemies", "NPCs", "NPCSpawns", "ActiveCombatPets" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function sampleGroundY(pos: Vector3, halfHeight: number, fallbackY: number): number
	local params = buildGroundRaycastParams()
	local hit = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 12, pos.Z), Vector3.new(0, -32, 0), params)
	if hit then
		return hit.Position.Y + math.max(1.5, halfHeight)
	end
	return fallbackY
end

local function findNearestAggroPlayer(originPos: Vector3, aggroRange: number): Player?
	local bestPlayer: Player? = nil
	local bestDist = aggroRange

	for _, player in Players:GetPlayers() do
		local _, hrp = getAlivePlayerRoot(player)
		if not hrp then
			continue
		end
		if NPCSpawnManager.IsInsideAnyPlayerPlot(hrp.Position) then
			continue
		end
		local dist = (hrp.Position - originPos).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestPlayer = player
		end
	end

	return bestPlayer
end

local function moveTowards(rec: EnemyRecord, goalPos: Vector3, dt: number): boolean
	local currentPos = rec.Model:GetPivot().Position
	local toTarget = Vector3.new(goalPos.X - currentPos.X, 0, goalPos.Z - currentPos.Z)
	if toTarget.Magnitude > 0.01 then
		local stepDist = math.min(toTarget.Magnitude, rec.Definition.WalkSpeed * dt)
		local dir = toTarget.Unit
		local nextXZ = currentPos + dir * stepDist
		if NPCSpawnManager.IsInsideAnyPlayerPlot(nextXZ) then
			return false
		end
		local nextY = sampleGroundY(nextXZ, rec.HalfHeight, currentPos.Y)
		local nextPos = Vector3.new(nextXZ.X, nextY, nextXZ.Z)
		rec.Model:PivotTo(CFrame.lookAt(nextPos, nextPos + dir))
		AnimController.PlayState(rec.Model, "Walk", rec.Definition.Animations, 0.18, 1.0)
		return true
	end
	return false
end

local function grantDefeatRewards(rec: EnemyRecord)
	local allItems = ServerStorage:FindFirstChild("AllItems")
	local deathPos = rec.Model:GetPivot().Position
	local minDamage = math.max(1, rec.Definition.MaxHP * NPCConfig.MinContributionRatio)

	for contributor, damageDealt in rec.Contributors do
		if contributor.Parent ~= Players or damageDealt < minDamage then
			continue
		end

		local char = contributor.Character
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if hrp and hrp:IsA("BasePart") and (hrp.Position - deathPos).Magnitude > NPCConfig.RewardMaxDistance then
			continue
		end

		DataService.AddExp(contributor, rec.Definition.ExpReward)
		local profile = DataService.GetProfile(contributor)
		if profile then
			profile.Data.Cash = (profile.Data.Cash or 0) + rec.Definition.CashReward
		end

		local lootSummary: { string } = {}
		local hadFullInventory = false

		for _, entry in rec.Definition.LootTable do
			if math.random() <= entry.Chance then
				local amount = math.random(entry.MinAmount, entry.MaxAmount)
				local granted = 0
				for _ = 1, amount do
					local ok = InventoryService.GiveItem(contributor, entry.ItemId)
					if ok then
						granted += 1
					else
						local sample = if allItems then allItems:FindFirstChild(entry.ItemId) else nil
						if sample and sample:IsA("Tool") and InventoryService.CheckInventoryFull(contributor, sample) then
							hadFullInventory = true
						end
						break
					end
				end
				if granted > 0 then
					table.insert(lootSummary, string.format("%s x%d", entry.ItemId, granted))
				end
			end
		end

		local message = string.format(
			"ปราบ %s สำเร็จ! +%d EXP, +%d Cash",
			rec.Definition.DisplayName,
			rec.Definition.ExpReward,
			rec.Definition.CashReward
		)
		if #lootSummary > 0 then
			message ..= " | ได้รับ: " .. table.concat(lootSummary, ", ")
		end
		if hadFullInventory then
			message ..= " (กระเป๋าเต็มบางรายการ)"
		end

		Network.NPCNetwork.NotifyToast.sendTo({
			IsError = false,
			Message = message,
		}, contributor)
	end
end

local function handleEnemyDeath(rec: EnemyRecord)
	if rec.IsDead then
		return
	end

	rec.IsDead = true
	rec.State = "Dead"
	rec.ActiveSkillId = ""
	rec.Model:SetAttribute("HP", 0)
	rec.Model:SetAttribute("ActiveSkillId", "")

	local zoneId = rec.ZoneId
	local npcUID = rec.UID
	local model = rec.Model

	enemiesByUID[npcUID] = nil
	enemiesByModel[model] = nil
	registeredEnemies[model] = nil
	NPCSkillManager.ClearNPCCooldowns(npcUID)

	AnimController.PlayState(model, "Death", rec.Definition.Animations, 0.12, 1.0, 2.0)
	Network.NPCNetwork.NPCVisualEvent.sendToAll({
		NPCUID = npcUID,
		EventType = "Death",
		WorldPos = model:GetPivot().Position,
		Amount = 0,
	})

	grantDefeatRewards(rec)

	task.delay(1.1, function()
		if model.Parent then
			model:Destroy()
		end
		if onEnemyDiedCallback then
			onEnemyDiedCallback(zoneId, npcUID)
		end
	end)
end

function EnemyController.SetOnEnemyDiedCallback(callback: (string, string) -> ())
	onEnemyDiedCallback = callback
end

function EnemyController.RegisterEnemy(enemy: Model)
	if not enemy:IsA("Model") or registeredEnemies[enemy] then
		return
	end
	registeredEnemies[enemy] = true
	enemy.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			registeredEnemies[enemy] = nil
		end
	end)
end

function EnemyController.UnregisterEnemy(enemy: Model)
	registeredEnemies[enemy] = nil
end

function EnemyController.RegisterSpawnedEnemy(
	npcUID: string,
	model: Model,
	def: Types.NPCDefinition,
	spawnPos: Vector3,
	zone: NPCSpawnManager.SpawnZoneRuntime
)
	local _, bboxSize = model:GetBoundingBox()
	local halfHeight = if bboxSize.Y > 0.1 then bboxSize.Y * 0.5 else def.PlaceholderScale.Y * 0.5

	local rec: EnemyRecord = {
		UID = npcUID,
		Model = model,
		Definition = def,
		SpawnPos = spawnPos,
		ZoneId = zone.ZoneId,
		PatrolRadius = zone.PatrolRadius,
		HalfHeight = halfHeight,
		HP = def.MaxHP,
		IsDead = false,
		State = "Idle",
		TargetPlayer = nil,
		PatrolTarget = nil,
		NextPatrolAt = os.clock() + math.random(2, 5),
		LastBasicAttackAt = 0,
		BusyUntil = 0,
		ActiveSkillId = "",
		Contributors = {},
	}

	enemiesByUID[npcUID] = rec
	enemiesByModel[model] = rec
	registeredEnemies[model] = true

	model.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			enemiesByUID[npcUID] = nil
			enemiesByModel[model] = nil
			registeredEnemies[model] = nil
			NPCSkillManager.ClearNPCCooldowns(npcUID)
		end
	end)

	Network.NPCNetwork.NPCVisualEvent.sendToAll({
		NPCUID = npcUID,
		EventType = "Spawn",
		WorldPos = spawnPos,
		Amount = 0,
	})
end

function EnemyController.GetEnemyByUID(npcUID: string): EnemyRecord?
	return enemiesByUID[npcUID]
end

function EnemyController.GetActiveBossEntries(): { BossSyncEntry }
	local entries: { BossSyncEntry } = {}
	for _, rec in enemiesByUID do
		if rec.Definition.IsBoss and not rec.IsDead and rec.HP > 0 and rec.Model.Parent then
			local castingName = ""
			local skillId = rec.ActiveSkillId
			if skillId == "" then
				local attrSkill = rec.Model:GetAttribute("ActiveSkillId")
				if type(attrSkill) == "string" then
					skillId = attrSkill
				end
			end
			if skillId ~= "" and NPCConfig.Skills[skillId] then
				castingName = NPCConfig.Skills[skillId].DisplayName
			end

			table.insert(entries, {
				Summary = {
					NPCUID = rec.UID,
					DisplayName = rec.Definition.DisplayName,
					Level = math.clamp(rec.Definition.Level, 1, 65535),
					HP = rec.HP,
					MaxHP = rec.Definition.MaxHP,
					CastingSkillName = castingName,
				},
				Position = rec.Model:GetPivot().Position,
			})
		end
	end

	table.sort(entries, function(a: BossSyncEntry, b: BossSyncEntry)
		return a.Summary.NPCUID < b.Summary.NPCUID
	end)

	return entries
end

function EnemyController.GetActiveBossSummaries(): { Types.NPCBossSummary }
	local entries = EnemyController.GetActiveBossEntries()
	local summaries: { Types.NPCBossSummary } = {}
	for _, entry in entries do
		table.insert(summaries, entry.Summary)
	end
	return summaries
end

local function collectCandidates(): { Model }
	local seen: { [Model]: boolean } = {}
	local list: { Model } = {}

	for _, rec in enemiesByUID do
		if not rec.IsDead and not seen[rec.Model] then
			seen[rec.Model] = true
			table.insert(list, rec.Model)
		end
	end

	for enemy in registeredEnemies do
		if not seen[enemy] then
			seen[enemy] = true
			table.insert(list, enemy)
		end
	end

	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, child in enemiesFolder:GetChildren() do
			if child:IsA("Model") and not seen[child] then
				seen[child] = true
				table.insert(list, child)
			end
		end
	end

	for _, tagged in CollectionService:GetTagged("Enemy") do
		if tagged:IsA("Model") and not seen[tagged] then
			seen[tagged] = true
			table.insert(list, tagged)
		end
	end

	return list
end

function EnemyController.GetNearestEnemy(originPos: Vector3, maxRange: number): Model?
	local bestEnemy: Model? = nil
	local bestDist = maxRange

	for _, enemy in collectCandidates() do
		local rec = enemiesByModel[enemy]
		if rec then
			if rec.IsDead or rec.HP <= 0 or not enemy.Parent then
				continue
			end
		elseif not isAliveLegacyEnemy(enemy) then
			continue
		end

		local pos = getEnemyPosition(enemy)
		if not pos then
			continue
		end
		local dist = (pos - originPos).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestEnemy = enemy
		end
	end

	return bestEnemy
end

function EnemyController.ApplyDamage(attackerPlayer: Player?, target: Model | string, damage: number): boolean
	if typeof(damage) ~= "number" or damage <= 0 or damage ~= damage or math.abs(damage) == math.huge then
		return false
	end

	local rec: EnemyRecord? = nil
	local targetModel: Model? = nil

	if type(target) == "string" then
		rec = enemiesByUID[target]
		targetModel = if rec then rec.Model else nil
	elseif typeof(target) == "Instance" and target:IsA("Model") then
		targetModel = target
		rec = enemiesByModel[target]
		if not rec then
			local uidAttr = target:GetAttribute("NPCUID")
			if type(uidAttr) == "string" then
				rec = enemiesByUID[uidAttr]
			end
		end
	end

	if rec then
		if rec.IsDead or not rec.Model.Parent or rec.HP <= 0 or rec.State == "ReturnToSpawn" then
			return false
		end

		rec.HP = math.max(0, rec.HP - damage)
		rec.Model:SetAttribute("HP", rec.HP)

		if attackerPlayer and attackerPlayer.Parent then
			rec.Contributors[attackerPlayer] = (rec.Contributors[attackerPlayer] or 0) + damage
			if not rec.TargetPlayer then
				rec.TargetPlayer = attackerPlayer
				if rec.State == "Idle" or rec.State == "Patrol" then
					rec.State = "Chase"
				end
			end
		end

		Network.NPCNetwork.NPCVisualEvent.sendToAll({
			NPCUID = rec.UID,
			EventType = "Damage",
			WorldPos = rec.Model:GetPivot().Position,
			Amount = math.floor(damage + 0.5),
		})

		if rec.HP <= 0 then
			handleEnemyDeath(rec)
		elseif rec.State ~= "SkillWindup" and rec.State ~= "SkillCast" then
			AnimController.PlayState(rec.Model, "Hit", rec.Definition.Animations, 0.08, 1.0, 0.22)
		end

		return true
	end

	if not targetModel or not isAliveLegacyEnemy(targetModel) then
		return false
	end

	local defeated = false
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
		defeated = humanoid.Health <= 0
	else
		local hp = targetModel:GetAttribute("HP")
		if type(hp) == "number" then
			local nextHp = math.max(0, hp - damage)
			targetModel:SetAttribute("HP", nextHp)
			defeated = nextHp <= 0
		else
			return false
		end
	end

	if defeated then
		local expReward = targetModel:GetAttribute("ExpReward")
		if attackerPlayer and type(expReward) == "number" and expReward > 0 then
			DataService.AddExp(attackerPlayer, expReward)
		end
		if not humanoid then
			targetModel:Destroy()
		end
	end

	return true
end

function EnemyController.ApplyPetDamage(player: Player, enemyModel: Model, damage: number): boolean
	return EnemyController.ApplyDamage(player, enemyModel, damage)
end

function EnemyController.PurgePlayerReferences(player: Player)
	for _, rec in enemiesByUID do
		rec.Contributors[player] = nil
		if rec.TargetPlayer == player then
			rec.TargetPlayer = nil
		end
	end
end

function EnemyController.StepAllEnemies(dt: number)
	local now = os.clock()

	for _, rec in enemiesByUID do
		if rec.IsDead or not rec.Model.Parent then
			continue
		end

		if now < rec.BusyUntil then
			continue
		end

		local currentPos = rec.Model:GetPivot().Position
		local flatSpawnDist = Vector3.new(currentPos.X - rec.SpawnPos.X, 0, currentPos.Z - rec.SpawnPos.Z).Magnitude

		local currentState: Types.NPCAIState = rec.State
		if currentState == "ReturnToSpawn" then
			if flatSpawnDist <= 2.0 then
				rec.State = "Idle"
				rec.HP = rec.Definition.MaxHP
				rec.Model:SetAttribute("HP", rec.HP)
				table.clear(rec.Contributors)
				rec.NextPatrolAt = now + math.random(2, 5)
				AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.2, 1.0)
			else
				local moved = moveTowards(rec, rec.SpawnPos, dt)
				if not moved then
					rec.Model:PivotTo(CFrame.new(rec.SpawnPos))
				end
			end
			continue
		end

		if flatSpawnDist > rec.Definition.LeashDistance then
			table.clear(rec.Contributors)
			rec.TargetPlayer = nil
			rec.PatrolTarget = nil
			rec.State = "ReturnToSpawn"
			moveTowards(rec, rec.SpawnPos, dt)
			continue
		end

		if rec.TargetPlayer then
			local _, targetRoot = getAlivePlayerRoot(rec.TargetPlayer)
			if not targetRoot or NPCSpawnManager.IsInsideAnyPlayerPlot(targetRoot.Position) then
				rec.TargetPlayer = nil
			else
				local targetFromSpawn = Vector3.new(
					targetRoot.Position.X - rec.SpawnPos.X,
					0,
					targetRoot.Position.Z - rec.SpawnPos.Z
				).Magnitude
				if targetFromSpawn > (rec.Definition.LeashDistance * 1.15) then
					rec.TargetPlayer = nil
				end
			end
		end

		if not rec.TargetPlayer then
			local found = findNearestAggroPlayer(currentPos, rec.Definition.AggroRange)
			if found then
				rec.TargetPlayer = found
				rec.State = "Chase"
			end
		end

		if rec.TargetPlayer then
			local targetHum, targetRoot = getAlivePlayerRoot(rec.TargetPlayer)
			if targetHum and targetRoot then
				local toTarget = targetRoot.Position - currentPos
				local targetDist = toTarget.Magnitude

				local readySkill = NPCSkillManager.SelectReadySkill(rec.UID, rec.Definition, rec.HP, targetDist)
				if readySkill then
					NPCSkillManager.BeginSkillCast(rec, readySkill, targetRoot)
					continue
				end

				if targetDist <= rec.Definition.AttackRange then
					rec.State = "Attack"
					local flatToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
					if flatToTarget.Magnitude > 0.01 then
						rec.Model:PivotTo(CFrame.lookAt(currentPos, currentPos + flatToTarget.Unit))
					end

					if (now - rec.LastBasicAttackAt) >= rec.Definition.BasicAttackCooldown then
						rec.LastBasicAttackAt = now
						AnimController.PlayState(rec.Model, "Attack", rec.Definition.Animations, 0.1, 1.0, 0.35)
						targetHum:TakeDamage(rec.Definition.BasicAttackDamage)
						Network.NPCNetwork.NPCVisualEvent.sendToAll({
							NPCUID = rec.UID,
							EventType = "BasicAttack",
							WorldPos = targetRoot.Position,
							Amount = math.floor(rec.Definition.BasicAttackDamage + 0.5),
						})
					else
						AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.18, 1.0)
					end
				else
					rec.State = "Chase"
					local moved = moveTowards(rec, targetRoot.Position, dt)
					if not moved then
						AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.18, 1.0)
					end
				end
				continue
			else
				rec.TargetPlayer = nil
			end
		end

		if rec.PatrolRadius > 0.5 then
			if rec.State == "Patrol" and rec.PatrolTarget then
				local flatDelta = Vector3.new(rec.PatrolTarget.X - currentPos.X, 0, rec.PatrolTarget.Z - currentPos.Z)
				if flatDelta.Magnitude <= 1.2 then
					rec.PatrolTarget = nil
					rec.State = "Idle"
					rec.NextPatrolAt = now + math.random(3, 6)
					AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.2, 1.0)
				else
					local moved = moveTowards(rec, rec.PatrolTarget, dt)
					if not moved then
						rec.PatrolTarget = nil
						rec.State = "Idle"
						rec.NextPatrolAt = now + math.random(3, 6)
						AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.2, 1.0)
					end
				end
			elseif now >= rec.NextPatrolAt then
				local theta = math.random() * math.pi * 2
				local dist = math.sqrt(math.random()) * rec.PatrolRadius
				local candidate = Vector3.new(
					rec.SpawnPos.X + math.cos(theta) * dist,
					rec.SpawnPos.Y,
					rec.SpawnPos.Z + math.sin(theta) * dist
				)
				if not NPCSpawnManager.IsInsideAnyPlayerPlot(candidate) then
					rec.PatrolTarget = candidate
					rec.State = "Patrol"
				else
					rec.NextPatrolAt = now + 2
				end
			else
				AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.2, 1.0)
			end
		else
			rec.State = "Idle"
			AnimController.PlayState(rec.Model, "Idle", rec.Definition.Animations, 0.2, 1.0)
		end
	end
end

return EnemyController
