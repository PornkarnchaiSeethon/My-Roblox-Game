local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService.ServerPackages.ProfileService)

local ProfileTemplate = {
	CurrentLevel = 0,
	CurrentExp = 0,
	ExpForNextLevel = 0,
	Cash = 0,
	Items = {},
	LogInTimes = 0,
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)

local Profiles = {}

local module = {}

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

function module.Start()
	Players.PlayerAdded:Connect(function(player)
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
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			profile:Release()
		end
	end)
end

return module
