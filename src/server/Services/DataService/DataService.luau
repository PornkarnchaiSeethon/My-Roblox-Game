local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)

local ProfileTemplate = {
	CurrentLevel = 0,
	CurrentExp = 0,
	ExpForNextLevel = 0,
	Cash = 0,
	Items = {
		Hotbar = {},
		NextStackId = 0,
		Stacks = {},
	},
	Plot = {},
	LogInTimes = 0,
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)

local Profiles = {}
local BeforeProfileRelease = {}

local module = {}

function module.GetProfile(player)
	return Profiles[player]
end

function module.WaitForProfile(player)
	while player.Parent and not Profiles[player] do
		task.wait()
	end
	return Profiles[player]
end

function module.OnBeforeProfileRelease(callback)
	table.insert(BeforeProfileRelease, callback)
end

local function GiveCash(profile, amount)
	if profile.Data.Cash == nil then
		profile.Data.Cash = 0
	end
	profile.Data.Cash = profile.Data.Cash + amount
end

local function DoSomethingWithALoadedProfile(player, profile)
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(
		player.Name
			.. " has logged in "
			.. tostring(profile.Data.LogInTimes)
			.. " time"
			.. ((profile.Data.LogInTimes > 1) and "s" or "")
	)
	GiveCash(profile, 100)
	print(player.Name .. " owns " .. tostring(profile.Data.Cash) .. " now!")
end

do
	local function AddExp(player, exp)
		local profile = Profiles["Player" .. player.UserId]
		if not profile then
			warn("can't find player profile")
			return
		end
		profile.Data.CurrentExp += exp
		while profile.Data.CurrentExp >= profile.Data.ExpForNextLevel do
			profile.Data.CurrentExp -= profile.Data.ExpForNextLevel
			profile.Data.CurrentLevel += 1
			profile.Data.ExpForNextLevel = profile.Data.CurrentLevel * 100
		end
	end
end

local function PlayerAdd(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick()
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
			DoSomethingWithALoadedProfile(player, profile)
		else
			profile:Release()
		end
	else
		player:Kick()
	end
end

function module.Start()
	Players.PlayerAdded:Connect(PlayerAdd)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			for _, callback in BeforeProfileRelease do
				callback(player, profile)
			end
			profile:Release()
		end
	end)
end

return module
