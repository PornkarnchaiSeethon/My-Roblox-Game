--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))

local AdminAuthManager = {}

local cachedAuth: { [Player]: boolean } = {}

local function setCachedAuth(player: Player, isAdmin: boolean): boolean
	if player:IsDescendantOf(Players) then
		cachedAuth[player] = isAdmin
	else
		cachedAuth[player] = nil
	end
	return isAdmin
end

function AdminAuthManager.EvaluateAdminStatus(player: Player): boolean
	if AdminConfig.AllowStudioAccess and RunService:IsStudio() then
		return setCachedAuth(player, true)
	end

	if AdminConfig.AllowCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return setCachedAuth(player, true)
	end

	if AdminConfig.AdminUserIds[player.UserId] == true then
		return setCachedAuth(player, true)
	end

	local checkedCreatorGroup = false
	local groupConfig = AdminConfig.GroupConfig
	if groupConfig and groupConfig.GroupId > 0 then
		if game.CreatorType == Enum.CreatorType.Group and game.CreatorId == groupConfig.GroupId then
			checkedCreatorGroup = true
		end

		local ok, rank = pcall(function()
			return player:GetRankInGroup(groupConfig.GroupId)
		end)
		if ok and type(rank) == "number" then
			if rank >= groupConfig.MinAdminRank then
				return setCachedAuth(player, true)
			end
			if AdminConfig.AllowCreator and checkedCreatorGroup and rank == 255 then
				return setCachedAuth(player, true)
			end
		end
	end

	if AdminConfig.AllowCreator and game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 and not checkedCreatorGroup then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and type(rank) == "number" and rank == 255 then
			return setCachedAuth(player, true)
		end
	end

	return setCachedAuth(player, false)
end

function AdminAuthManager.IsAdmin(player: Player): boolean
	local cached = cachedAuth[player]
	if cached ~= nil then
		return cached
	end
	return AdminAuthManager.EvaluateAdminStatus(player)
end

function AdminAuthManager.ClearCache(player: Player)
	cachedAuth[player] = nil
end

return AdminAuthManager
