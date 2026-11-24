--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local DataService = require(script.Parent.Parent.DataService.DataService)
local InventoryService = require(script.Parent.Parent.DataService.InventoryService)

local AdminAuthManager = require(script.Parent.AdminAuthManager)
local AdminActionExecutor = require(script.Parent.AdminActionExecutor)

local AdminService = Knit.CreateService({
	Name = "AdminService",
	Client = {},
})

type MutationBucket = {
	Tokens: number,
	LastRefill: number,
}

local READ_RATE_LIMIT = 0.40
local BUCKET_CAPACITY = 6
local BUCKET_REFILL_PER_SEC = 3

local lastReadPacketAt: { [Player]: { [string]: number } } = {}
local mutationBuckets: { [Player]: MutationBucket } = {}
local activeAdminLocks: { [Player]: boolean } = {}
local customWalkSpeeds: { [Player]: number } = {}
local boundSpeedConns: { [Player]: RBXScriptConnection } = {}

local function checkReadRateLimit(player: Player, actionName: string): boolean
	local now = os.clock()
	local playerReads = lastReadPacketAt[player]
	if not playerReads then
		playerReads = {}
		lastReadPacketAt[player] = playerReads
	end
	local lastAt = playerReads[actionName]
	if lastAt and (now - lastAt) < READ_RATE_LIMIT then
		return false
	end
	playerReads[actionName] = now
	return true
end

local function consumeMutationToken(player: Player): boolean
	local now = os.clock()
	local bucket = mutationBuckets[player]
	if not bucket then
		bucket = {
			Tokens = BUCKET_CAPACITY,
			LastRefill = now,
		}
		mutationBuckets[player] = bucket
	else
		local elapsed = math.max(0, now - bucket.LastRefill)
		bucket.Tokens = math.min(BUCKET_CAPACITY, bucket.Tokens + elapsed * BUCKET_REFILL_PER_SEC)
		bucket.LastRefill = now
	end

	if bucket.Tokens < 1 then
		return false
	end

	bucket.Tokens -= 1
	return true
end

local function withAdminLock(player: Player, fn: () -> ())
	if activeAdminLocks[player] then
		return
	end
	activeAdminLocks[player] = true
	local ok, err = pcall(fn)
	activeAdminLocks[player] = nil
	if not ok then
		warn("[AdminService] Action error for", player.Name, err)
	end
end

local function getCurrentWalkSpeed(player: Player): number
	local customSpeed = customWalkSpeeds[player]
	if customSpeed ~= nil then
		return customSpeed
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		return humanoid.WalkSpeed
	end
	return AdminConfig.DefaultWalkSpeed
end

function AdminService:BindCharacterSpeedPersistence(player: Player)
	if boundSpeedConns[player] or not player:IsDescendantOf(Players) then
		return
	end

	local function applySavedSpeed(character: Model)
		local speed = customWalkSpeeds[player]
		if speed == nil then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") and player:IsDescendantOf(Players) then
			local latestSpeed = customWalkSpeeds[player]
			if latestSpeed ~= nil then
				character:SetAttribute("BaseWalkSpeed", latestSpeed)
				local activeSlowMult = character:GetAttribute("ActiveSlowMultiplier")
				if type(activeSlowMult) == "number" and activeSlowMult > 0 and activeSlowMult < 1 then
					humanoid.WalkSpeed = math.max(2, latestSpeed * activeSlowMult)
				else
					humanoid.WalkSpeed = latestSpeed
				end
			end
		end
	end

	boundSpeedConns[player] = player.CharacterAdded:Connect(function(character)
		task.spawn(applySavedSpeed, character)
	end)

	if player.Character and customWalkSpeeds[player] ~= nil then
		task.spawn(applySavedSpeed, player.Character)
	end
end

function AdminService:SendAccessToPlayer(player: Player, isAdmin: boolean)
	local missingItems: { string } = if isAdmin then AdminActionExecutor.GetMissingStudioItems() else {}
	Network.AdminNetwork.SyncAccess.sendTo({
		IsAdmin = isAdmin,
		CurrentWalkSpeed = getCurrentWalkSpeed(player),
		MissingStudioItems = missingItems,
	}, player)
end

function AdminService:BuildAllPlayerSummaries(): { Types.AdminPlayerSummary }
	local summaries: { Types.AdminPlayerSummary } = {}
	for _, player in Players:GetPlayers() do
		table.insert(summaries, AdminActionExecutor.BuildPlayerSummary(player, DataService))
	end
	table.sort(summaries, function(a: Types.AdminPlayerSummary, b: Types.AdminPlayerSummary)
		return a.Name < b.Name
	end)
	return summaries
end

function AdminService:SendPlayerListToAdmin(adminPlayer: Player)
	Network.AdminNetwork.SyncPlayerList.sendTo({
		Players = self:BuildAllPlayerSummaries(),
	}, adminPlayer)
end

function AdminService:BroadcastPlayerListToAdmins()
	local payload = {
		Players = self:BuildAllPlayerSummaries(),
	}
	for _, player in Players:GetPlayers() do
		if AdminAuthManager.IsAdmin(player) then
			Network.AdminNetwork.SyncPlayerList.sendTo(payload, player)
		end
	end
end

function AdminService:SendAuditLogsToAdmin(adminPlayer: Player)
	Network.AdminNetwork.SyncAuditLogs.sendTo({
		AuditLogs = AdminActionExecutor.GetAuditLogs(),
	}, adminPlayer)
end

function AdminService:BroadcastAuditLogsToAdmins()
	local payload = {
		AuditLogs = AdminActionExecutor.GetAuditLogs(),
	}
	for _, player in Players:GetPlayers() do
		if AdminAuthManager.IsAdmin(player) then
			Network.AdminNetwork.SyncAuditLogs.sendTo(payload, player)
		end
	end
end

local function verifyAdminAccess(player: Player, actionName: string): boolean
	if AdminAuthManager.IsAdmin(player) then
		return true
	end
	warn("[AdminService] Unauthorized " .. actionName .. " from", player.Name, player.UserId)
	customWalkSpeeds[player] = nil
	if boundSpeedConns[player] then
		boundSpeedConns[player]:Disconnect()
		boundSpeedConns[player] = nil
	end
	if player:IsDescendantOf(Players) then
		AdminService:SendAccessToPlayer(player, false)
	end
	return false
end

function AdminService:SendPlayerDetailToAdmin(adminPlayer: Player, targetPlayer: Player): boolean
	local detail = AdminActionExecutor.BuildPlayerDetail(targetPlayer, DataService, InventoryService.MaxStacks)
	if not detail then
		return false
	end
	Network.AdminNetwork.SyncPlayerDetail.sendTo({
		Detail = detail,
	}, adminPlayer)
	return true
end

function AdminService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		lastReadPacketAt[player] = nil
		mutationBuckets[player] = nil
		activeAdminLocks[player] = nil
		customWalkSpeeds[player] = nil
		if boundSpeedConns[player] then
			boundSpeedConns[player]:Disconnect()
			boundSpeedConns[player] = nil
		end
		AdminAuthManager.ClearCache(player)
	end)
end

function AdminService:KnitStart()
	if RunService:IsStudio() and AdminConfig.AutoCreateStudioDummyTools == true then
		local createdCount = AdminActionExecutor.EnsureStudioDummyTools()
		if createdCount > 0 then
			print("[AdminService] Created", createdCount, "Studio dummy Tool template(s) in ServerStorage.AllItems")
		end
	end

	local missingItems = AdminActionExecutor.GetMissingStudioItems()
	if #missingItems > 0 then
		warn("[AdminService] Missing Tool templates in ServerStorage.AllItems:", table.concat(missingItems, ", "))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if AdminAuthManager.EvaluateAdminStatus(player) then
				self:BindCharacterSpeedPersistence(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if AdminAuthManager.EvaluateAdminStatus(player) then
				self:BindCharacterSpeedPersistence(player)
			end
		end)
	end)

	Network.AdminNetwork.RequestAccess.listen(function(_, player)
		if not checkReadRateLimit(player, "RequestAccess") then
			return
		end
		local isAdmin = AdminAuthManager.EvaluateAdminStatus(player)
		if not player:IsDescendantOf(Players) then
			return
		end
		if isAdmin then
			self:BindCharacterSpeedPersistence(player)
		else
			customWalkSpeeds[player] = nil
			if boundSpeedConns[player] then
				boundSpeedConns[player]:Disconnect()
				boundSpeedConns[player] = nil
			end
		end
		self:SendAccessToPlayer(player, isAdmin)
		if isAdmin then
			self:SendPlayerListToAdmin(player)
		end
	end)

	Network.AdminNetwork.RequestPlayerList.listen(function(_, player)
		if not verifyAdminAccess(player, "RequestPlayerList") then
			return
		end
		if not checkReadRateLimit(player, "RequestPlayerList") then
			return
		end
		self:SendPlayerListToAdmin(player)
	end)

	Network.AdminNetwork.RequestAuditLogs.listen(function(_, player)
		if not verifyAdminAccess(player, "RequestAuditLogs") then
			return
		end
		if not checkReadRateLimit(player, "RequestAuditLogs") then
			return
		end
		self:SendAuditLogsToAdmin(player)
	end)

	Network.AdminNetwork.InspectPlayer.listen(function(data, player)
		if not verifyAdminAccess(player, "InspectPlayer") then
			return
		end
		if not checkReadRateLimit(player, "InspectPlayer") then
			return
		end

		local targetUserId = if type(data) == "table" then data.TargetUserId else nil
		if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId or math.abs(targetUserId) == math.huge then
			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "รหัสผู้เล่นเป้าหมายไม่ถูกต้อง",
			}, player)
			return
		end

		local targetPlayer = Players:GetPlayerByUserId(math.floor(targetUserId))
		if not targetPlayer then
			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "ไม่พบผู้เล่นเป้าหมายในเซิร์ฟเวอร์",
			}, player)
			return
		end

		if not self:SendPlayerDetailToAdmin(player, targetPlayer) then
			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "ข้อมูลโปรไฟล์ของ " .. targetPlayer.DisplayName .. " ยังไม่พร้อมใช้งาน",
			}, player)
		end
	end)

	Network.AdminNetwork.GiveItem.listen(function(data, player)
		if not verifyAdminAccess(player, "GiveItem") then
			return
		end
		if not consumeMutationToken(player) then
			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "ส่งคำสั่งเร็วเกินไป กรุณารอสักครู่",
			}, player)
			return
		end

		withAdminLock(player, function()
			local targetUserId = if type(data) == "table" then data.TargetUserId else nil
			local itemId = if type(data) == "table" then data.ItemId else nil
			local amount = if type(data) == "table" then data.Amount else nil

			local ok, msg, targetPlayer = AdminActionExecutor.SpawnItems(
				player,
				targetUserId,
				itemId,
				amount,
				InventoryService,
				DataService
			)

			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = not ok,
				Message = msg,
			}, player)

			if ok and targetPlayer and targetPlayer ~= player and targetPlayer:IsDescendantOf(Players) then
				Network.AdminNetwork.NotifyToast.sendTo({
					IsError = false,
					Message = "ผู้ดูแลระบบ " .. player.DisplayName .. " ได้มอบไอเทมเข้ากระเป๋าของคุณแล้ว",
				}, targetPlayer)
			end

			if targetPlayer and targetPlayer:IsDescendantOf(Players) then
				self:SendPlayerDetailToAdmin(player, targetPlayer)
			end
			self:BroadcastPlayerListToAdmins()
			if ok then
				self:BroadcastAuditLogsToAdmins()
			end
		end)
	end)

	Network.AdminNetwork.SetSelfWalkSpeed.listen(function(data, player)
		if not verifyAdminAccess(player, "SetSelfWalkSpeed") then
			return
		end
		if not consumeMutationToken(player) then
			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = true,
				Message = "ส่งคำสั่งเร็วเกินไป กรุณารอสักครู่",
			}, player)
			return
		end

		withAdminLock(player, function()
			local rawSpeed = if type(data) == "table" then data.WalkSpeed else nil
			local ok, msg = AdminActionExecutor.SetOwnWalkSpeed(player, rawSpeed, customWalkSpeeds)

			Network.AdminNetwork.NotifyToast.sendTo({
				IsError = not ok,
				Message = msg,
			}, player)

			if ok then
				self:BindCharacterSpeedPersistence(player)
				self:SendAccessToPlayer(player, true)
				self:SendPlayerDetailToAdmin(player, player)
				self:BroadcastPlayerListToAdmins()
				self:BroadcastAuditLogsToAdmins()
			end
		end)
	end)
end

return AdminService
