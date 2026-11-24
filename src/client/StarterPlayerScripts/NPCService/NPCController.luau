--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local NPCVisualRenderer = require(script.Parent:WaitForChild("NPCVisualRenderer"))

type WeaponAttackSpec = {
	Cooldown: number,
	Range: number,
}

local NPCController = Knit.CreateController({
	Name = "NPCController",
})

NPCController.State = {
	ActiveBosses = {} :: { Types.NPCBossSummary },
	ActiveDialogue = nil :: Types.NPCDialoguePayload?,
	LastToast = nil :: Types.NPCToastInfo?,
}

local started = false
local lastSwingAt = 0
local listeners: { () -> () } = {}
local bossListeners: { () -> () } = {}
local dialogueListeners: { () -> () } = {}
local toastListeners: { () -> () } = {}

local function subscribeTo(list: { () -> () }, callback: () -> ()): () -> ()
	table.insert(list, callback)
	return function()
		local idx = table.find(list, callback)
		if idx then
			table.remove(list, idx)
		end
	end
end

local function fireList(list: { () -> () })
	for _, fn in list do
		task.spawn(fn)
	end
end

local function notifyBosses()
	fireList(bossListeners)
	fireList(listeners)
end

local function notifyDialogue()
	fireList(dialogueListeners)
	fireList(listeners)
end

local function notifyToast()
	fireList(toastListeners)
	fireList(listeners)
end

local function resolveEquippedWeaponSpec(tool: Tool): WeaponAttackSpec?
	local configStats = NPCConfig.WeaponStats[tool.Name]
	if configStats then
		return {
			Cooldown = configStats.Cooldown,
			Range = configStats.Range,
		}
	end

	local toolData = ToolConfig.Get(tool)
	if toolData.WeaponStats then
		return {
			Cooldown = toolData.WeaponStats.Cooldown,
			Range = toolData.WeaponStats.Range,
		}
	end

	if toolData.ItemType == "Weapon" then
		return {
			Cooldown = NPCConfig.PlayerBaseAttackCooldown,
			Range = NPCConfig.PlayerBaseAttackRange,
		}
	end

	return nil
end

function NPCController.Subscribe(callback: () -> ()): () -> ()
	return subscribeTo(listeners, callback)
end

function NPCController.SubscribeBosses(callback: () -> ()): () -> ()
	return subscribeTo(bossListeners, callback)
end

function NPCController.SubscribeDialogue(callback: () -> ()): () -> ()
	return subscribeTo(dialogueListeners, callback)
end

function NPCController.SubscribeToast(callback: () -> ()): () -> ()
	return subscribeTo(toastListeners, callback)
end

function NPCController.Notify()
	fireList(bossListeners)
	fireList(dialogueListeners)
	fireList(toastListeners)
	fireList(listeners)
end

function NPCController.InteractWithNPC(npcUID: string)
	if type(npcUID) ~= "string" or npcUID == "" then
		return
	end
	Network.NPCNetwork.InteractNPC.send({
		NPCUID = npcUID,
	})
end

function NPCController.CloseDialogue()
	if NPCController.State.ActiveDialogue == nil then
		return
	end
	NPCController.State.ActiveDialogue = nil
	notifyDialogue()
end

function NPCController.ClearToast()
	if NPCController.State.LastToast == nil then
		return
	end
	NPCController.State.LastToast = nil
	notifyToast()
end

function NPCController.GetNearbyBoss(): Types.NPCBossSummary?
	local activeBosses = NPCController.State.ActiveBosses
	if #activeBosses == 0 then
		return nil
	end

	local localPlayer = Players.LocalPlayer
	local char = if localPlayer then localPlayer.Character else nil
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local enemiesFolder = Workspace:FindFirstChild("Enemies")

	if not hrp or not hrp:IsA("BasePart") or not enemiesFolder then
		for _, boss in activeBosses do
			if boss.HP > 0 then
				return boss
			end
		end
		return activeBosses[1]
	end

	local enemyByUID: { [string]: Model } = {}
	for _, child in enemiesFolder:GetChildren() do
		if child:IsA("Model") then
			local uid = child:GetAttribute("NPCUID")
			if typeof(uid) == "string" and uid ~= "" then
				enemyByUID[uid] = child
			end
		end
	end

	local bestBoss: Types.NPCBossSummary? = nil
	local bestDist = NPCConfig.BossBarMaxDistance

	for _, boss in activeBosses do
		if boss.HP > 0 then
			local model = enemyByUID[boss.NPCUID]
			if model then
				local dist = (hrp.Position - model:GetPivot().Position).Magnitude
				if dist <= bestDist then
					bestDist = dist
					bestBoss = boss
				end
			end
		end
	end

	return bestBoss
end

function NPCController.TryBasicWeaponAttack()
	local localPlayer = Players.LocalPlayer
	local char = if localPlayer then localPlayer.Character else nil
	if not char then
		return
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return
	end

	local equippedTool = char:FindFirstChildOfClass("Tool")
	if not equippedTool then
		return
	end

	local spec = resolveEquippedWeaponSpec(equippedTool)
	if not spec then
		return
	end

	local now = os.clock()
	if now - lastSwingAt < spec.Cooldown then
		return
	end

	local targetUID = NPCVisualRenderer.FindClosestEnemyUID(hrp.Position, spec.Range)
	if not targetUID then
		return
	end

	lastSwingAt = now
	Network.NPCNetwork.PlayerAttackNPC.send({
		NPCUID = targetUID,
	})
end

function NPCController.Start()
	if started then
		return
	end
	started = true

	NPCVisualRenderer.Init()

	Network.NPCNetwork.SyncBosses.listen(function(payload)
		NPCController.State.ActiveBosses = payload.Bosses
		notifyBosses()
	end)

	Network.NPCNetwork.OpenNPCDialogue.listen(function(payload)
		NPCController.State.ActiveDialogue = payload
		notifyDialogue()
	end)

	Network.NPCNetwork.NPCTelegraphEvent.listen(function(payload)
		NPCVisualRenderer.RenderTelegraph(payload)
	end)

	Network.NPCNetwork.NPCVisualEvent.listen(function(payload)
		NPCVisualRenderer.PlayVisualEvent(payload)
	end)

	Network.NPCNetwork.NotifyToast.listen(function(payload)
		NPCController.State.LastToast = {
			IsError = payload.IsError,
			Message = payload.Message,
			Timestamp = os.time(),
		}
		notifyToast()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			NPCController.TryBasicWeaponAttack()
		end
	end)
end

function NPCController:KnitInit() end

function NPCController:KnitStart()
	NPCController.Start()
end

return NPCController
