--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))

local NPCSpawnManager = require(script.Parent.NPCSpawnManager)
local NPCSkillManager = require(script.Parent.NPCSkillManager)
local EnemyController = require(script.Parent.EnemyController)

local NPCService = Knit.CreateService({
	Name = "NPCService",
	Client = {},
})

type FriendlyRecord = {
	UID: string,
	Model: Model,
	Definition: Types.NPCDefinition,
}

type WeaponSpec = {
	Damage: number,
	Cooldown: number,
	Range: number,
}

local friendlyNPCsByUID: { [string]: FriendlyRecord } = {}
local nextAttackTimestamp: { [Player]: number } = {}
local lastPlayerInteractAt: { [Player]: number } = {}
local lastBossSignatureByPlayer: { [Player]: string } = {}

local function isValidNPCUID(uid: any): boolean
	return typeof(uid) == "string" and #uid > 0 and #uid <= 64 and string.match(uid, "^[%w_%-]+$") ~= nil
end

local function ensureFallbackAllItemsTools()
	local existingFolder = ServerStorage:FindFirstChild("AllItems")
	local allItems: Folder
	if existingFolder and existingFolder:IsA("Folder") then
		allItems = existingFolder
	else
		local folder = Instance.new("Folder")
		folder.Name = "AllItems"
		folder.Parent = ServerStorage
		allItems = folder
	end

	local createdNames: { string } = {}
	for _, itemId in { "normal_Sword" } do
		local existing = allItems:FindFirstChild(itemId)
		if not existing or not existing:IsA("Tool") then
			local tool = Instance.new("Tool")
			tool.Name = itemId
			tool.RequiresHandle = true

			local toolData = ToolConfig.Get(itemId)
			if toolData.ItemType then
				tool:SetAttribute("ItemType", toolData.ItemType)
			end

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1, 1, 3)
			handle.CanCollide = false
			handle.Parent = tool

			tool.Parent = allItems
			table.insert(createdNames, itemId)
		end
	end

	if #createdNames > 0 then
		warn("[NPCService] Created fallback Tool templates in ServerStorage.AllItems:", table.concat(createdNames, ", "))
	end
end

local function syncBossesForPlayer(player: Player, bossEntries: { EnemyController.BossSyncEntry })
	if not player.Parent then
		return
	end

	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local filtered: { Types.NPCBossSummary } = {}
	local sigParts: { string } = {}

	if hrp and hrp:IsA("BasePart") then
		local playerPos = hrp.Position
		for _, entry in bossEntries do
			if (entry.Position - playerPos).Magnitude <= NPCConfig.BossSyncRadius then
				local summary = entry.Summary
				table.insert(filtered, summary)
				table.insert(
					sigParts,
					string.format(
						"%s:%d:%d:%s",
						summary.NPCUID,
						math.floor(summary.HP),
						math.floor(summary.MaxHP),
						summary.CastingSkillName
					)
				)
			end
		end
	end

	local signature = table.concat(sigParts, ";")
	if lastBossSignatureByPlayer[player] ~= signature then
		lastBossSignatureByPlayer[player] = signature
		Network.NPCNetwork.SyncBosses.sendTo({
			Bosses = filtered,
		}, player)
	end
end

local function resolveEquippedWeaponStats(player: Player): WeaponSpec
	local char = player.Character
	local heldTool = if char then char:FindFirstChildOfClass("Tool") else nil
	if heldTool then
		local npcWeapon = NPCConfig.WeaponStats[heldTool.Name]
		if npcWeapon then
			return npcWeapon
		end
		local toolData = ToolConfig.Get(heldTool)
		if toolData.WeaponStats then
			return toolData.WeaponStats
		end
		if toolData.ItemType == "Weapon" then
			return {
				Damage = NPCConfig.PlayerBaseFistDamage,
				Cooldown = NPCConfig.PlayerBaseAttackCooldown,
				Range = NPCConfig.PlayerBaseAttackRange,
			}
		end
	end

	return {
		Damage = NPCConfig.PlayerBaseFistDamage,
		Cooldown = NPCConfig.PlayerBaseAttackCooldown,
		Range = NPCConfig.PlayerBaseAttackRange,
	}
end

local function hasClearLineOfSight(originPos: Vector3, targetModel: Model, attackerChar: Model): boolean
	local targetPos = targetModel:GetPivot().Position
	local delta = targetPos - originPos
	if delta.Magnitude < 0.5 then
		return true
	end

	local exclude: { Instance } = { attackerChar, targetModel }
	for _, folderName in { "Enemies", "NPCs", "NPCSpawns", "ActiveCombatPets" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			table.insert(exclude, folder)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local hit = Workspace:Raycast(originPos, delta, params)
	return hit == nil
end

local function openDialogueForPlayer(player: Player, npcUID: string)
	local now = os.clock()
	if lastPlayerInteractAt[player] and (now - lastPlayerInteractAt[player]) < 0.25 then
		return
	end

	local friendly = friendlyNPCsByUID[npcUID]
	if not friendly or not friendly.Model.Parent then
		return
	end

	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not hum or hum.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return
	end

	local npcPos = friendly.Model:GetPivot().Position
	if (npcPos - hrp.Position).Magnitude > (NPCConfig.DefaultInteractDistance + 4) then
		return
	end

	lastPlayerInteractAt[player] = now
	Network.NPCNetwork.OpenNPCDialogue.sendTo({
		NPCUID = npcUID,
		DisplayName = friendly.Definition.DisplayName,
		Lines = friendly.Definition.DialogueLines or {},
	}, player)
end

local function handleSpawnedCallback(
	npcUID: string,
	model: Model,
	def: Types.NPCDefinition,
	spawnPos: Vector3,
	zone: NPCSpawnManager.SpawnZoneRuntime
)
	if def.Category == "Enemy" then
		EnemyController.RegisterSpawnedEnemy(npcUID, model, def, spawnPos, zone)
	else
		friendlyNPCsByUID[npcUID] = {
			UID = npcUID,
			Model = model,
			Definition = def,
		}

		model.AncestryChanged:Connect(function(_, newParent)
			if newParent == nil then
				friendlyNPCsByUID[npcUID] = nil
			end
		end)

		local prompt = model:FindFirstChild("NPCTalkPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player: Player)
				openDialogueForPlayer(player, npcUID)
			end)
		end
	end
end

function NPCService:KnitInit()
	ensureFallbackAllItemsTools()

	Players.PlayerRemoving:Connect(function(player: Player)
		nextAttackTimestamp[player] = nil
		lastPlayerInteractAt[player] = nil
		lastBossSignatureByPlayer[player] = nil
		EnemyController.PurgePlayerReferences(player)
		NPCSkillManager.PurgePlayerReferences(player)
	end)
end

function NPCService:KnitStart()
	EnemyController.SetOnEnemyDiedCallback(function(zoneId: string, npcUID: string)
		NPCSpawnManager.NotifyNPCRemoved(zoneId, npcUID, handleSpawnedCallback)
	end)

	NPCSpawnManager.DiscoverZones()
	NPCSpawnManager.PopulateAllZones(handleSpawnedCallback)

	local initialBossEntries = EnemyController.GetActiveBossEntries()
	for _, player in Players:GetPlayers() do
		syncBossesForPlayer(player, initialBossEntries)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		-- Defer so ByteNet's PlayerAdded handler initializes per-player channels first (LIFO signal order)
		task.defer(function()
			if player.Parent then
				syncBossesForPlayer(player, EnemyController.GetActiveBossEntries())
			end
		end)
	end)

	Network.NPCNetwork.PlayerAttackNPC.listen(function(data, player)
		if not player or type(data) ~= "table" or not isValidNPCUID(data.NPCUID) then
			return
		end
		local npcUID = data.NPCUID :: string

		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if not char or not hum or hum.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
			return
		end

		local weaponStats = resolveEquippedWeaponStats(player)
		local now = os.clock()
		local nextAllowed = nextAttackTimestamp[player] or 0
		if now + NPCConfig.AttackJitterAllowance < nextAllowed then
			return
		end

		local enemyRec = EnemyController.GetEnemyByUID(npcUID)
		if not enemyRec or enemyRec.IsDead or not enemyRec.Model.Parent or enemyRec.HP <= 0 then
			return
		end

		local enemyPos = enemyRec.Model:GetPivot().Position
		if (enemyPos - hrp.Position).Magnitude > (weaponStats.Range + 3.0) then
			return
		end

		if not hasClearLineOfSight(hrp.Position, enemyRec.Model, char) then
			return
		end

		nextAttackTimestamp[player] = math.max(now, nextAllowed) + weaponStats.Cooldown
		EnemyController.ApplyDamage(player, enemyRec.Model, weaponStats.Damage)
	end)

	Network.NPCNetwork.InteractNPC.listen(function(data, player)
		if not player or type(data) ~= "table" or not isValidNPCUID(data.NPCUID) then
			return
		end
		local npcUID = data.NPCUID :: string
		openDialogueForPlayer(player, npcUID)
	end)

	task.spawn(function()
		local bossSyncAccum = 0
		while true do
			local dt = task.wait(NPCConfig.AITickInterval)
			EnemyController.StepAllEnemies(dt)
			bossSyncAccum += dt
			if bossSyncAccum >= 0.45 then
				bossSyncAccum = 0
				local bossEntries = EnemyController.GetActiveBossEntries()
				for _, player in Players:GetPlayers() do
					syncBossesForPlayer(player, bossEntries)
				end
			end
		end
	end)
end

return NPCService
