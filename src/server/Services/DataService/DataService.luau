local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
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
	Pets = {
		MaxPetCapacity = 20,
		MaxEquippedCombat = 3,
		Instances = {},
		Incubators = {},
		BreedingPens = {},
	},
	LogInTimes = 0,
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)

local Profiles = {}
local LoadingPlayers = {}
local BeforeProfileRelease = {}

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

function DataService.GetProfile(player: Player)
	return Profiles[player]
end

function DataService.WaitForProfile(player: Player)
	while player.Parent and not Profiles[player] do
		task.wait()
	end
	return Profiles[player]
end

function DataService.OnBeforeProfileRelease(callback: (Player, any) -> ())
	table.insert(BeforeProfileRelease, callback)
end

function DataService.Client:GetData(player: Player)
	local profile = Profiles[player]
	if not profile then
		return nil
	end

	return {
		CurrentLevel = profile.Data.CurrentLevel,
		CurrentExp = profile.Data.CurrentExp,
		ExpForNextLevel = profile.Data.ExpForNextLevel,
		Cash = profile.Data.Cash,
	}
end

local function GiveCash(profile, amount: number)
	if profile.Data.Cash == nil then
		profile.Data.Cash = 0
	end
	profile.Data.Cash = profile.Data.Cash + amount
end

local function DoSomethingWithALoadedProfile(player: Player, profile)
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

function DataService.AddExp(player: Player, exp: number)
	local profile = Profiles[player]
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

local function PlayerAdd(player: Player)
	if Profiles[player] or LoadingPlayers[player] then
		return
	end
	LoadingPlayers[player] = true

	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	LoadingPlayers[player] = nil

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

function DataService:KnitInit() end

function DataService:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerAdd, player)
	end
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

DataService.Start = DataService.KnitStart

return DataService
