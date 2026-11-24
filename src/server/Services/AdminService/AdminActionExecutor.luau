--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local AdminActionExecutor = {}

local auditLogs: { Types.AdminAuditEntry } = {}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function safeFiniteNumber(value: any, fallback: number): number
	if isFiniteNumber(value) then
		return value
	end
	return fallback
end

local function clampUint8(value: number): number
	return math.clamp(math.floor(value), 0, 255)
end

local function clampUint16(value: number): number
	return math.clamp(math.floor(value), 0, 65535)
end

local function clampUint32(value: number): number
	return math.clamp(math.floor(value), 0, 4294967295)
end

local function countTableEntries(tbl: any): number
	if type(tbl) ~= "table" then
		return 0
	end
	local count = 0
	for _ in tbl do
		count += 1
	end
	return count
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function AdminActionExecutor.RecordAudit(adminName: string, action: string, targetName: string, detail: string)
	local entry: Types.AdminAuditEntry = {
		Timestamp = clampUint32(os.time()),
		AdminName = tostring(adminName),
		Action = tostring(action),
		TargetName = tostring(targetName),
		Detail = tostring(detail),
	}
	table.insert(auditLogs, 1, entry)

	local maxEntries = math.max(1, AdminConfig.MaxAuditLogEntries or 50)
	while #auditLogs > maxEntries do
		table.remove(auditLogs)
	end
end

function AdminActionExecutor.GetAuditLogs(): { Types.AdminAuditEntry }
	return table.clone(auditLogs)
end

function AdminActionExecutor.GetMissingStudioItems(): { string }
	local missing: { string } = {}
	local allItems = ServerStorage:FindFirstChild("AllItems")

	for itemId in ToolConfig.Items do
		local sample = if allItems then allItems:FindFirstChild(itemId) else nil
		if not sample or not sample:IsA("Tool") then
			table.insert(missing, itemId)
		end
	end

	table.sort(missing)
	return missing
end

function AdminActionExecutor.BuildPlayerSummary(player: Player, dataService: any): Types.AdminPlayerSummary
	local profile = dataService.GetProfile(player)
	local data = if profile and type(profile.Data) == "table" then profile.Data else nil

	local level = math.clamp(math.floor(if data then safeFiniteNumber(data.CurrentLevel, 1) else 1), 1, 65535)
	local cash = if data then safeFiniteNumber(data.Cash, 0) else 0
	local humanoid = getHumanoid(player)
	local walkSpeed = if humanoid and isFiniteNumber(humanoid.WalkSpeed)
		then humanoid.WalkSpeed
		else AdminConfig.DefaultWalkSpeed

	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Level = level,
		Cash = cash,
		WalkSpeed = walkSpeed,
	}
end

function AdminActionExecutor.BuildPlayerDetail(
	targetPlayer: Player,
	dataService: any,
	maxStacks: number?
): Types.AdminPlayerDetail?
	local profile = dataService.GetProfile(targetPlayer)
	if not profile or type(profile.Data) ~= "table" then
		return nil
	end

	local data = profile.Data
	local itemsData = if type(data.Items) == "table" then data.Items else nil
	local hotbar = if itemsData and type(itemsData.Hotbar) == "table" then itemsData.Hotbar else nil

	local hotbarSlotByStackId: { [number]: number } = {}
	if hotbar then
		for slotIndex = 1, 10 do
			local stackId = hotbar["Slot" .. tostring(slotIndex)]
			if isFiniteNumber(stackId) then
				hotbarSlotByStackId[math.floor(stackId)] = slotIndex
			end
		end
	end

	local items: { Types.AdminStackItem } = {}
	local rawStacks = if itemsData and type(itemsData.Stacks) == "table" then itemsData.Stacks else nil
	if rawStacks then
		for _, stack in rawStacks do
			if type(stack) ~= "table" or type(stack.Name) ~= "string" then
				continue
			end

			local itemId = stack.Name
			local toolMeta = ToolConfig.Get(itemId)
			local rawStackId = safeFiniteNumber(stack.StackId, 0)
			local stackId = clampUint16(rawStackId)
			local count = clampUint16(safeFiniteNumber(stack.Count, 0))
			local hotbarSlot = clampUint8(hotbarSlotByStackId[math.floor(rawStackId)] or 0)

			table.insert(items, {
				StackId = stackId,
				ItemId = itemId,
				DisplayName = toolMeta.DisplayName or itemId,
				ItemType = toolMeta.ItemType or "Resource",
				Count = count,
				HotbarSlot = hotbarSlot,
			})
		end
	end

	table.sort(items, function(a: Types.AdminStackItem, b: Types.AdminStackItem)
		local aInHotbar = a.HotbarSlot > 0
		local bInHotbar = b.HotbarSlot > 0
		if aInHotbar and bInHotbar then
			if a.HotbarSlot ~= b.HotbarSlot then
				return a.HotbarSlot < b.HotbarSlot
			end
			return a.StackId < b.StackId
		elseif aInHotbar ~= bInHotbar then
			return aInHotbar
		end

		if a.DisplayName ~= b.DisplayName then
			return a.DisplayName < b.DisplayName
		end
		return a.StackId < b.StackId
	end)

	local petsData = if type(data.Pets) == "table" then data.Pets else nil
	local plantsData = if type(data.Plants) == "table" then data.Plants else nil

	local humanoid = getHumanoid(targetPlayer)
	local walkSpeed = if humanoid and isFiniteNumber(humanoid.WalkSpeed)
		then humanoid.WalkSpeed
		else AdminConfig.DefaultWalkSpeed
	local health = if humanoid and isFiniteNumber(humanoid.Health) then math.max(0, humanoid.Health) else 0
	local maxHealth = if humanoid and isFiniteNumber(humanoid.MaxHealth) then math.max(0, humanoid.MaxHealth) else 100

	local resolvedMaxStacks = clampUint8(if isFiniteNumber(maxStacks) then (maxStacks :: number) else 20)

	return {
		UserId = targetPlayer.UserId,
		Name = targetPlayer.Name,
		DisplayName = targetPlayer.DisplayName,
		AccountAge = clampUint32(safeFiniteNumber(targetPlayer.AccountAge, 0)),
		Level = math.clamp(math.floor(safeFiniteNumber(data.CurrentLevel, 1)), 1, 65535),
		CurrentExp = math.max(0, safeFiniteNumber(data.CurrentExp, 0)),
		ExpForNextLevel = math.max(1, safeFiniteNumber(data.ExpForNextLevel, 100)),
		Cash = safeFiniteNumber(data.Cash, 0),
		LogInTimes = clampUint32(safeFiniteNumber(data.LogInTimes, 0)),
		WalkSpeed = walkSpeed,
		Health = health,
		MaxHealth = maxHealth,
		StackCount = clampUint8(#items),
		MaxStacks = resolvedMaxStacks,
		PetCount = clampUint8(countTableEntries(if petsData then petsData.Instances else nil)),
		ActivePlanters = clampUint8(countTableEntries(if plantsData then plantsData.Planters else nil)),
		PlotObjectCount = clampUint16(countTableEntries(data.Plot)),
		Items = items,
	}
end

function AdminActionExecutor.SpawnItems(
	adminPlayer: Player,
	targetUserId: any,
	itemId: any,
	rawAmount: any,
	inventoryService: any,
	dataService: any
): (boolean, string, Player?)
	if typeof(itemId) ~= "string" or itemId == "" or #itemId > 64 then
		return false, "รหัสไอเทมไม่ถูกต้อง", nil
	end
	if not isFiniteNumber(targetUserId) then
		return false, "รหัสผู้เล่นเป้าหมายไม่ถูกต้อง", nil
	end
	if not isFiniteNumber(rawAmount) then
		return false, "จำนวนไอเทมไม่ถูกต้อง", nil
	end

	if not ToolConfig.Items[itemId] then
		return false, "ไม่พบไอเทม " .. itemId .. " ใน ToolConfig", nil
	end

	local allItems = ServerStorage:FindFirstChild("AllItems")
	local sample = if allItems then allItems:FindFirstChild(itemId) else nil
	if not sample or not sample:IsA("Tool") then
		return false, "ไม่พบ Tool '" .. itemId .. "' ใน ServerStorage.AllItems", nil
	end

	local targetPlayer = Players:GetPlayerByUserId(math.floor(targetUserId))
	if not targetPlayer then
		return false, "ไม่พบผู้เล่นเป้าหมายในเซิร์ฟเวอร์", nil
	end

	local targetProfile = dataService.GetProfile(targetPlayer)
	if not targetProfile then
		return false, "ข้อมูลโปรไฟล์ของ " .. targetPlayer.DisplayName .. " ยังไม่พร้อมใช้งาน", targetPlayer
	end

	local amount = math.clamp(math.floor(rawAmount), 1, AdminConfig.MaxSpawnAmountPerAction)
	local granted = 0
	for _ = 1, amount do
		local gave = inventoryService.GiveItem(targetPlayer, itemId)
		if not gave then
			break
		end
		granted += 1
	end

	if granted == 0 then
		return false, "กระเป๋าของ " .. targetPlayer.DisplayName .. " เต็ม (ครบ 20 กอง)", targetPlayer
	end

	local toolMeta = ToolConfig.Get(itemId)
	local displayName = toolMeta.DisplayName or itemId
	local actionName = if adminPlayer == targetPlayer then "SelfGiveItem" else "GiveItem"
	local auditDetail = if granted < amount
		then string.format("%s (%s) x%d/%d", displayName, itemId, granted, amount)
		else string.format("%s (%s) x%d", displayName, itemId, granted)
	AdminActionExecutor.RecordAudit(adminPlayer.Name, actionName, targetPlayer.Name, auditDetail)

	local targetLabel = if adminPlayer == targetPlayer then "ตัวเอง" else targetPlayer.DisplayName
	local msg = string.format("เสก %s x%d ให้ %s สำเร็จ", displayName, granted, targetLabel)
	if granted < amount then
		msg ..= string.format(" (ได้ %d/%d ชิ้น เนื่องจากกระเป๋าเต็ม)", granted, amount)
	end

	return true, msg, targetPlayer
end

function AdminActionExecutor.SetOwnWalkSpeed(
	adminPlayer: Player,
	rawSpeed: any,
	customSpeeds: { [Player]: number }
): (boolean, string, number)
	if not isFiniteNumber(rawSpeed) then
		local currentSpeed = customSpeeds[adminPlayer] or AdminConfig.DefaultWalkSpeed
		return false, "ค่าความเร็วไม่ถูกต้อง", currentSpeed
	end

	local clampedSpeed = math.clamp(math.round(rawSpeed * 10) / 10, AdminConfig.MinWalkSpeed, AdminConfig.MaxWalkSpeed)
	customSpeeds[adminPlayer] = clampedSpeed

	local humanoid = getHumanoid(adminPlayer)
	if humanoid then
		humanoid.WalkSpeed = clampedSpeed
	end

	AdminActionExecutor.RecordAudit(
		adminPlayer.Name,
		"SetWalkSpeed",
		adminPlayer.Name,
		string.format("WalkSpeed -> %.1f", clampedSpeed)
	)

	return true, string.format("ปรับความเร็วเดินเป็น %.1f เรียบร้อยแล้ว", clampedSpeed), clampedSpeed
end

return AdminActionExecutor
