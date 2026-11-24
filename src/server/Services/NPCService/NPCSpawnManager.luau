--!strict

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))

local NPCSpawnManager = {}

export type SpawnZoneRuntime = {
	ZoneId: string,
	NPCId: string,
	Origin: Vector3,
	SpawnRadius: number,
	PatrolRadius: number,
	MaxConcurrent: number,
	RespawnDelay: number,
	ActiveUIDs: { [string]: boolean },
	PendingRespawns: number,
}

export type OnSpawnedCallback = (
	npcUID: string,
	model: Model,
	def: Types.NPCDefinition,
	spawnPos: Vector3,
	zone: SpawnZoneRuntime
) -> ()

local zones: { SpawnZoneRuntime } = {}
local zonesById: { [string]: SpawnZoneRuntime } = {}
local warnedMissingModels: { [string]: boolean } = {}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function NPCSpawnManager.IsInsideAnyPlayerPlot(candidatePos: Vector3): boolean
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return false
	end

	local margin = NPCConfig.PlotSafeMarginStuds
	local marginVec = Vector3.new(margin, margin, margin)

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") then
			local primary = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
			if primary then
				local localPos = primary.CFrame:PointToObjectSpace(candidatePos)
				local half = (primary.Size * 0.5) + marginVec
				if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
					return true
				end
			end
		end
	end

	return false
end

local function buildGroundRaycastParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, folderName in { "Enemies", "NPCs", "NPCSpawns", "ActiveCombatPets" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			table.insert(exclude, folder)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function sampleGroundPosition(origin: Vector3, radius: number, halfHeight: number): Vector3
	local params = buildGroundRaycastParams()
	local verticalOffset = math.max(1.5, halfHeight)

	for _ = 1, 8 do
		local candidate = origin
		if radius > 0 then
			local theta = math.random() * math.pi * 2
			local dist = math.sqrt(math.random()) * radius
			candidate = Vector3.new(
				origin.X + math.cos(theta) * dist,
				origin.Y,
				origin.Z + math.sin(theta) * dist
			)
		end

		if not NPCSpawnManager.IsInsideAnyPlayerPlot(candidate) then
			local hit = Workspace:Raycast(candidate + Vector3.new(0, 35, 0), Vector3.new(0, -80, 0), params)
			if hit then
				return hit.Position + Vector3.new(0, verticalOffset, 0)
			end
			return Vector3.new(candidate.X, origin.Y + verticalOffset, candidate.Z)
		end
	end

	local fallbackHit = Workspace:Raycast(origin + Vector3.new(0, 35, 0), Vector3.new(0, -80, 0), params)
	if fallbackHit then
		return fallbackHit.Position + Vector3.new(0, verticalOffset, 0)
	end
	return Vector3.new(origin.X, origin.Y + verticalOffset, origin.Z)
end

local function resolveRootSize(def: Types.NPCDefinition): Vector3
	local npcModels = ReplicatedStorage:FindFirstChild("NPCModels")
	local template = if npcModels then npcModels:FindFirstChild(def.NPCId) else nil

	if template and template:IsA("Model") then
		local extents = template:GetExtentsSize()
		if extents.Y > 0.1 then
			return extents
		end
		return def.PlaceholderScale
	end

	if not warnedMissingModels[def.NPCId] then
		warnedMissingModels[def.NPCId] = true
		warn(string.format("[NPCSpawnManager] Missing model '%s' in ReplicatedStorage.NPCModels — using PlaceholderScale", def.NPCId))
	end
	return def.PlaceholderScale
end

local function buildLogicalRootModel(def: Types.NPCDefinition, rootSize: Vector3): Model
	local model = Instance.new("Model")
	model.Name = def.NPCId

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = rootSize
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model

	model.PrimaryPart = root
	return model
end

function NPCSpawnManager.DiscoverZones(): { SpawnZoneRuntime }
	table.clear(zones)
	table.clear(zonesById)

	local spawnsFolder = ensureFolder(Workspace, "NPCSpawns")
	ensureFolder(Workspace, "Enemies")
	ensureFolder(Workspace, "NPCs")

	local candidates: { Instance } = {}
	local seen: { [Instance]: boolean } = {}

	for _, desc in spawnsFolder:GetDescendants() do
		if not seen[desc] then
			seen[desc] = true
			table.insert(candidates, desc)
		end
	end

	for _, tagged in CollectionService:GetTagged("NPCSpawnPoint") do
		if not seen[tagged] then
			seen[tagged] = true
			table.insert(candidates, tagged)
		end
	end

	for _, inst in candidates do
		if inst:IsA("BasePart") then
			inst.Transparency = 1
			inst.CanCollide = false
			inst.Anchored = true
		end

		local npcIdAttr = inst:GetAttribute("NPCId")
		if type(npcIdAttr) ~= "string" or not NPCConfig.NPCs[npcIdAttr] then
			continue
		end

		local origin: Vector3? = nil
		if inst:IsA("BasePart") then
			origin = inst.Position
		elseif inst:IsA("Model") then
			origin = inst:GetPivot().Position
		end
		if not origin then
			continue
		end

		local rawZoneId = inst:GetAttribute("SpawnZoneId")
		local zoneId = if type(rawZoneId) == "string" and rawZoneId ~= ""
			then rawZoneId
			else inst.Name .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 6)
		if zonesById[zoneId] then
			zoneId = zoneId .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 4)
		end

		local rawSpawnRadius = inst:GetAttribute("SpawnRadius")
		local spawnRadius = if type(rawSpawnRadius) == "number" then math.max(0, rawSpawnRadius) else 10

		local rawPatrolRadius = inst:GetAttribute("PatrolRadius")
		local patrolRadius = if type(rawPatrolRadius) == "number" then math.max(0, rawPatrolRadius) else 14

		local rawMax = inst:GetAttribute("MaxConcurrent")
		local maxConcurrent = math.clamp(if type(rawMax) == "number" then math.floor(rawMax) else 1, 1, 20)

		local rawDelay = inst:GetAttribute("RespawnDelay")
		local respawnDelay = math.max(1, if type(rawDelay) == "number" then rawDelay else 10)

		local runtime: SpawnZoneRuntime = {
			ZoneId = zoneId,
			NPCId = npcIdAttr,
			Origin = origin,
			SpawnRadius = spawnRadius,
			PatrolRadius = patrolRadius,
			MaxConcurrent = maxConcurrent,
			RespawnDelay = respawnDelay,
			ActiveUIDs = {},
			PendingRespawns = 0,
		}
		table.insert(zones, runtime)
		zonesById[zoneId] = runtime
	end

	if #zones == 0 then
		warn("[NPCSpawnManager] No valid NPCSpawnPoint instances found; falling back to NPCConfig.DefaultSpawnZones")
		for _, cfg in NPCConfig.DefaultSpawnZones do
			if NPCConfig.NPCs[cfg.NPCId] then
				local runtime: SpawnZoneRuntime = {
					ZoneId = cfg.SpawnZoneId,
					NPCId = cfg.NPCId,
					Origin = cfg.DefaultPosition,
					SpawnRadius = math.max(0, cfg.SpawnRadius),
					PatrolRadius = math.max(0, cfg.PatrolRadius),
					MaxConcurrent = math.clamp(math.floor(cfg.MaxConcurrent), 1, 20),
					RespawnDelay = math.max(1, cfg.RespawnDelay),
					ActiveUIDs = {},
					PendingRespawns = 0,
				}
				table.insert(zones, runtime)
				zonesById[cfg.SpawnZoneId] = runtime
			end
		end
	end

	return zones
end

function NPCSpawnManager.SpawnOneInZone(zone: SpawnZoneRuntime, onSpawned: OnSpawnedCallback)
	local def = NPCConfig.NPCs[zone.NPCId]
	if not def then
		return
	end

	local rootSize = resolveRootSize(def)
	local model = buildLogicalRootModel(def, rootSize)
	local halfHeight = if rootSize.Y > 0.1 then rootSize.Y * 0.5 else def.PlaceholderScale.Y * 0.5
	local spawnPos = sampleGroundPosition(zone.Origin, zone.SpawnRadius, halfHeight)
	local npcUID = HttpService:GenerateGUID(false)

	model.Name = def.NPCId .. "_" .. string.sub(npcUID, 1, 8)
	model:SetAttribute("NPCUID", npcUID)
	model:SetAttribute("NPCId", def.NPCId)
	model:SetAttribute("DisplayName", def.DisplayName)
	model:SetAttribute("Level", def.Level)
	model:SetAttribute("HP", def.MaxHP)
	model:SetAttribute("MaxHP", def.MaxHP)
	model:SetAttribute("IsBoss", def.IsBoss)
	model:SetAttribute("AnimState", "Idle")
	model:SetAttribute("ActiveSkillId", "")
	model:SetAttribute("SpawnZoneId", zone.ZoneId)
	model:SetAttribute("IsLogicalRoot", true)

	model:PivotTo(CFrame.new(spawnPos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	if def.Category == "Enemy" then
		CollectionService:AddTag(model, "Enemy")
		CollectionService:AddTag(model, "NPC")
		model.Parent = ensureFolder(Workspace, "Enemies")
	else
		CollectionService:AddTag(model, "FriendlyNPC")
		CollectionService:AddTag(model, "NPC")

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "NPCTalkPrompt"
		prompt.ActionText = "พูดคุย"
		prompt.ObjectText = def.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = NPCConfig.DefaultInteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = model.PrimaryPart or model

		model.Parent = ensureFolder(Workspace, "NPCs")
	end

	zone.ActiveUIDs[npcUID] = true
	onSpawned(npcUID, model, def, spawnPos, zone)
end

local function countActive(zone: SpawnZoneRuntime): number
	local count = 0
	for _ in zone.ActiveUIDs do
		count += 1
	end
	return count
end

function NPCSpawnManager.NotifyNPCRemoved(zoneId: string, npcUID: string, onSpawned: OnSpawnedCallback)
	local zone = zonesById[zoneId]
	if not zone then
		return
	end

	zone.ActiveUIDs[npcUID] = nil
	if countActive(zone) + zone.PendingRespawns >= zone.MaxConcurrent then
		return
	end

	zone.PendingRespawns += 1
	task.delay(zone.RespawnDelay, function()
		zone.PendingRespawns = math.max(0, zone.PendingRespawns - 1)
		if countActive(zone) < zone.MaxConcurrent then
			NPCSpawnManager.SpawnOneInZone(zone, onSpawned)
		end
	end)
end

function NPCSpawnManager.PopulateAllZones(onSpawned: OnSpawnedCallback)
	for _, zone in zones do
		local needed = zone.MaxConcurrent - countActive(zone)
		for _ = 1, needed do
			NPCSpawnManager.SpawnOneInZone(zone, onSpawned)
		end
	end
end

return NPCSpawnManager
