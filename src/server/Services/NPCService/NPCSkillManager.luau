--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local AnimController = require(script.Parent.AnimController)
local NPCSpawnManager = require(script.Parent.NPCSpawnManager)

local NPCSkillManager = {}

export type SkillCasterEntry = {
	UID: string,
	Model: Model,
	Definition: Types.NPCDefinition,
	HalfHeight: number,
	HP: number,
	IsDead: boolean,
	State: string,
	BusyUntil: number,
	ActiveSkillId: string,
}

type SlowMultiplierEntry = {
	Multiplier: number,
	Token: number,
}

local skillCooldowns: { [string]: { [string]: number } } = {}
local activeSlowMultipliers: { [Player]: { [string]: SlowMultiplierEntry } } = {}
local baseSpeedConns: { [Player]: RBXScriptConnection } = {}
local baseSpeedChars: { [Player]: Model } = {}
local slowTokenCounter = 0

function NPCSkillManager.ClearNPCCooldowns(npcUID: string)
	skillCooldowns[npcUID] = nil
end

function NPCSkillManager.PurgePlayerReferences(player: Player)
	activeSlowMultipliers[player] = nil
	if baseSpeedConns[player] then
		baseSpeedConns[player]:Disconnect()
		baseSpeedConns[player] = nil
	end
	baseSpeedChars[player] = nil
end

local function buildEnvironmentRaycastParams(): RaycastParams
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

local function recomputeCharacterWalkSpeed(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local baseAttr = character:GetAttribute("BaseWalkSpeed")
	local baseSpeed: number
	if type(baseAttr) == "number" then
		baseSpeed = baseAttr
	else
		baseSpeed = humanoid.WalkSpeed
		character:SetAttribute("BaseWalkSpeed", baseSpeed)
	end

	local lowestMultiplier = 1.0
	local playerSlows = activeSlowMultipliers[player]
	if playerSlows then
		for _, entry in playerSlows do
			if entry.Multiplier < lowestMultiplier then
				lowestMultiplier = entry.Multiplier
			end
		end
	end

	character:SetAttribute("ActiveSlowMultiplier", if lowestMultiplier < 1.0 then lowestMultiplier else nil)
	humanoid.WalkSpeed = math.max(2, baseSpeed * lowestMultiplier)
end

local function applySafeSlowDebuff(player: Player, sourceKey: string, magnitude: number, duration: number)
	if not player.Parent then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local playerSlows = activeSlowMultipliers[player]
	if not playerSlows then
		playerSlows = {}
		activeSlowMultipliers[player] = playerSlows
	end

	if character:GetAttribute("BaseWalkSpeed") == nil then
		character:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
	end

	slowTokenCounter += 1
	local token = slowTokenCounter
	playerSlows[sourceKey] = {
		Multiplier = math.clamp(1 - magnitude, 0.1, 1.0),
		Token = token,
	}

	if baseSpeedChars[player] ~= character then
		if baseSpeedConns[player] then
			baseSpeedConns[player]:Disconnect()
			baseSpeedConns[player] = nil
		end
		baseSpeedChars[player] = character
		baseSpeedConns[player] = character:GetAttributeChangedSignal("BaseWalkSpeed"):Connect(function()
			if player.Parent and player.Character == character and character.Parent then
				recomputeCharacterWalkSpeed(player, character)
			end
		end)

		humanoid.Died:Once(function()
			activeSlowMultipliers[player] = nil
			if baseSpeedConns[player] then
				baseSpeedConns[player]:Disconnect()
				baseSpeedConns[player] = nil
			end
			baseSpeedChars[player] = nil
			if character.Parent then
				character:SetAttribute("ActiveSlowMultiplier", nil)
			end
		end)
	end

	recomputeCharacterWalkSpeed(player, character)

	task.delay(duration, function()
		if not player.Parent or not character.Parent or player.Character ~= character then
			return
		end
		local currentSlows = activeSlowMultipliers[player]
		if not currentSlows then
			return
		end
		local currentEntry = currentSlows[sourceKey]
		if not currentEntry or currentEntry.Token ~= token then
			return
		end

		currentSlows[sourceKey] = nil
		if next(currentSlows) == nil then
			activeSlowMultipliers[player] = nil
		end
		recomputeCharacterWalkSpeed(player, character)
	end)
end

function NPCSkillManager.SelectReadySkill(
	npcUID: string,
	def: Types.NPCDefinition,
	currentHP: number,
	distanceToTarget: number
): Types.NPCSkillDefinition?
	if #def.SkillIds == 0 then
		return nil
	end

	local now = os.clock()
	local npcCds = skillCooldowns[npcUID]
	local hpRatio = currentHP / math.max(1, def.MaxHP)

	for _, skillId in def.SkillIds do
		local skill = NPCConfig.Skills[skillId]
		if not skill then
			continue
		end

		local readyAt = if npcCds then npcCds[skillId] else nil
		if readyAt and now < readyAt then
			continue
		end

		if hpRatio < skill.MinHealthPercent or hpRatio > skill.MaxHealthPercent then
			continue
		end

		if distanceToTarget > skill.CastRange then
			continue
		end

		return skill
	end

	return nil
end

function NPCSkillManager.BeginSkillCast(
	npcEntry: SkillCasterEntry,
	skill: Types.NPCSkillDefinition,
	targetRoot: BasePart
)
	local model = npcEntry.Model
	local def = npcEntry.Definition
	local now = os.clock()

	local npcCds = skillCooldowns[npcEntry.UID]
	if not npcCds then
		npcCds = {}
		skillCooldowns[npcEntry.UID] = npcCds
	end
	npcCds[skill.SkillId] = now + skill.WindupTime + skill.ActiveDuration + skill.Cooldown

	local casterPos = model:GetPivot().Position
	local flatDir = Vector3.new(targetRoot.Position.X - casterPos.X, 0, targetRoot.Position.Z - casterPos.Z)
	local safeLook = if flatDir.Magnitude > 0.05
		then flatDir.Unit
		else Vector3.new(model:GetPivot().LookVector.X, 0, model:GetPivot().LookVector.Z)
	if safeLook.Magnitude > 0.05 then
		safeLook = safeLook.Unit
	else
		safeLook = Vector3.new(0, 0, -1)
	end

	model:PivotTo(CFrame.lookAt(casterPos, casterPos + safeLook))

	local rawOrigin: Vector3
	if skill.TargetMode == "TargetPosition" then
		rawOrigin = targetRoot.Position
	elseif skill.TargetMode == "ForwardLine" then
		rawOrigin = casterPos + safeLook * (skill.BoxSize.Z * 0.5)
	else
		rawOrigin = casterPos
	end

	local groundParams = buildEnvironmentRaycastParams()
	local groundHit = Workspace:Raycast(rawOrigin + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), groundParams)
	local telegraphOrigin = if groundHit
		then groundHit.Position
		else Vector3.new(rawOrigin.X, casterPos.Y - npcEntry.HalfHeight, rawOrigin.Z)

	npcEntry.State = "SkillWindup"
	npcEntry.BusyUntil = now + skill.WindupTime + skill.ActiveDuration
	npcEntry.ActiveSkillId = skill.SkillId
	model:SetAttribute("ActiveSkillId", skill.SkillId)

	AnimController.PlayState(model, "SkillWindup", def.Animations, 0.12, 1.0, skill.WindupTime)

	Network.NPCNetwork.NPCTelegraphEvent.sendToAll({
		NPCUID = npcEntry.UID,
		SkillId = skill.SkillId,
		Shape = skill.Shape,
		Origin = telegraphOrigin,
		LookVector = safeLook,
		Radius = skill.Radius,
		BoxSize = skill.BoxSize,
		Duration = skill.WindupTime,
	})

	task.delay(skill.WindupTime, function()
		if npcEntry.IsDead or not model.Parent then
			return
		end

		npcEntry.State = "SkillCast"
		AnimController.PlayState(model, skill.AnimKey, def.Animations, 0.1, 1.0, skill.ActiveDuration)

		if skill.DashForwardDistance and skill.DashForwardDistance > 0 then
			local currentPos = model:GetPivot().Position
			local dashParams = buildEnvironmentRaycastParams()
			local wallHit = Workspace:Raycast(currentPos, safeLook * skill.DashForwardDistance, dashParams)
			local dashDist = if wallHit
				then math.max(0, wallHit.Distance - 2.0)
				else skill.DashForwardDistance

			if dashDist > 0.1 then
				local candidateGoal = currentPos + safeLook * dashDist
				local dashGroundHit = Workspace:Raycast(
					candidateGoal + Vector3.new(0, 15, 0),
					Vector3.new(0, -40, 0),
					dashParams
				)
				local goalY = if dashGroundHit
					then dashGroundHit.Position.Y + math.max(1.5, npcEntry.HalfHeight)
					else currentPos.Y
				local dashGoal = Vector3.new(candidateGoal.X, goalY, candidateGoal.Z)

				if not NPCSpawnManager.IsInsideAnyPlayerPlot(dashGoal) then
					model:PivotTo(CFrame.lookAt(dashGoal, dashGoal + safeLook))
				end
			end
		end

		if skill.HealAmount > 0 then
			local prevHP = npcEntry.HP
			npcEntry.HP = math.min(def.MaxHP, npcEntry.HP + skill.HealAmount)
			local healed = math.max(0, math.floor(npcEntry.HP - prevHP + 0.5))
			model:SetAttribute("HP", npcEntry.HP)
			Network.NPCNetwork.NPCVisualEvent.sendToAll({
				NPCUID = npcEntry.UID,
				EventType = "Heal",
				WorldPos = model:GetPivot().Position,
				Amount = healed,
			})
		end

		if skill.Damage > 0 then
			local charList: { Instance } = {}
			for _, player in Players:GetPlayers() do
				if player.Character then
					table.insert(charList, player.Character)
				end
			end

			if #charList > 0 then
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				overlapParams.FilterDescendantsInstances = charList

				local hitParts: { BasePart }
				if skill.Shape == "Circle" then
					hitParts = Workspace:GetPartBoundsInRadius(telegraphOrigin, skill.Radius, overlapParams)
				else
					local boxCenter = telegraphOrigin + Vector3.new(0, skill.BoxSize.Y * 0.5, 0)
					local boxCF = CFrame.lookAt(boxCenter, boxCenter + safeLook)
					hitParts = Workspace:GetPartBoundsInBox(boxCF, skill.BoxSize, overlapParams)
				end

				local hitPlayers: { [Player]: boolean } = {}
				for _, part in hitParts do
					local char = part:FindFirstAncestorOfClass("Model")
					if not char then
						continue
					end
					local plr = Players:GetPlayerFromCharacter(char)
					if not plr or hitPlayers[plr] then
						continue
					end
					hitPlayers[plr] = true

					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid:TakeDamage(skill.Damage)
						if skill.StatusEffect and skill.StatusEffect.Type == "Slow" then
							applySafeSlowDebuff(
								plr,
								skill.SkillId,
								skill.StatusEffect.Magnitude,
								skill.StatusEffect.Duration
							)
						end
					end
				end
			end

			Network.NPCNetwork.NPCVisualEvent.sendToAll({
				NPCUID = npcEntry.UID,
				EventType = "SkillImpact",
				WorldPos = telegraphOrigin,
				Amount = math.floor(skill.Damage + 0.5),
			})
		end

		task.delay(skill.ActiveDuration, function()
			if npcEntry.IsDead or not model.Parent then
				return
			end
			npcEntry.ActiveSkillId = ""
			model:SetAttribute("ActiveSkillId", "")
			if npcEntry.State == "SkillCast" or npcEntry.State == "SkillWindup" then
				npcEntry.State = "Chase"
			end
		end)
	end)
end

return NPCSkillManager
