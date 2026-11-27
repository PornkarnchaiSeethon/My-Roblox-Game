--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local AdminConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("AdminConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

export type AdminTab = "Players" | "Spawner" | "PetSpawner" | "SelfSpeed" | "AuditLog"

local function getLocalUserId(): number
	local player = Players.LocalPlayer
	return if player then player.UserId else 0
end

local AdminController = Knit.CreateController({
	Name = "AdminController",
})

AdminController.State = {
	IsAdmin = false,
	IsOpen = false,
	ActiveTab = "Players" :: AdminTab,
	PlayersList = {} :: { Types.AdminPlayerSummary },
	SelectedUserId = getLocalUserId(),
	SelectedPlayerDetail = nil :: Types.AdminPlayerDetail?,
	SelfWalkSpeed = AdminConfig.DefaultWalkSpeed,
	MissingStudioItems = {} :: { [string]: boolean },
	AuditLogs = {} :: { Types.AdminAuditEntry },
	LastToast = nil :: Types.AdminToastInfo?,
}

local started = false
local hasSyncedAccess = false
local listeners: { () -> () } = {}

function AdminController.Subscribe(callback: () -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function AdminController.Notify()
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function AdminController.RefreshPlayers()
	if not AdminController.State.IsAdmin then
		return
	end
	Network.AdminNetwork.RequestPlayerList.send(nil)
	if AdminController.State.SelectedUserId ~= 0 then
		Network.AdminNetwork.InspectPlayer.send({
			TargetUserId = AdminController.State.SelectedUserId,
		})
	end
	if AdminController.State.ActiveTab == "AuditLog" then
		Network.AdminNetwork.RequestAuditLogs.send(nil)
	end
end

function AdminController.SetPanelOpen(isOpen: boolean)
	if isOpen and not AdminController.State.IsAdmin then
		return
	end
	if AdminController.State.IsOpen == isOpen then
		return
	end

	AdminController.State.IsOpen = isOpen
	if isOpen then
		if AdminController.State.SelectedUserId == 0 then
			AdminController.State.SelectedUserId = getLocalUserId()
		end
		Network.AdminNetwork.RequestPlayerList.send(nil)
		if AdminController.State.SelectedUserId ~= 0 then
			Network.AdminNetwork.InspectPlayer.send({
				TargetUserId = AdminController.State.SelectedUserId,
			})
		end
		if AdminController.State.ActiveTab == "AuditLog" then
			Network.AdminNetwork.RequestAuditLogs.send(nil)
		end
	end

	AdminController.Notify()
end

function AdminController.TogglePanel()
	if not AdminController.State.IsAdmin then
		return
	end
	AdminController.SetPanelOpen(not AdminController.State.IsOpen)
end

function AdminController.SetTab(tab: AdminTab)
	if AdminController.State.ActiveTab == tab then
		return
	end
	AdminController.State.ActiveTab = tab
	if tab == "AuditLog" and AdminController.State.IsAdmin then
		Network.AdminNetwork.RequestAuditLogs.send(nil)
	end
	AdminController.Notify()
end

function AdminController.SelectAndInspectPlayer(targetUserId: number)
	if not AdminController.State.IsAdmin then
		return
	end
	AdminController.State.SelectedUserId = targetUserId
	if AdminController.State.SelectedPlayerDetail and AdminController.State.SelectedPlayerDetail.UserId ~= targetUserId then
		AdminController.State.SelectedPlayerDetail = nil
	end
	AdminController.Notify()

	Network.AdminNetwork.InspectPlayer.send({
		TargetUserId = targetUserId,
	})
end

function AdminController.GiveItemToTarget(targetUserId: number, itemId: string, amount: number)
	if not AdminController.State.IsAdmin then
		return
	end
	if amount ~= amount or math.abs(amount) == math.huge then
		return
	end
	local clampedAmount = math.clamp(math.floor(amount), 1, AdminConfig.MaxSpawnAmountPerAction)
	Network.AdminNetwork.GiveItem.send({
		TargetUserId = targetUserId,
		ItemId = itemId,
		Amount = clampedAmount,
	})
end

function AdminController.GiveItemToSelf(itemId: string, amount: number)
	local localUserId = getLocalUserId()
	if localUserId == 0 then
		return
	end
	AdminController.GiveItemToTarget(localUserId, itemId, amount)
end

function AdminController.SpawnPetToTarget(
	targetUserId: number,
	speciesId: string,
	stage: string,
	amount: number,
	initialState: string?
)
	if not AdminController.State.IsAdmin then
		return
	end
	if targetUserId ~= targetUserId or math.abs(targetUserId) == math.huge then
		return
	end
	if amount ~= amount or math.abs(amount) == math.huge then
		return
	end
	local maxPerAction = AdminConfig.MaxPetSpawnAmountPerAction or 10
	local clampedAmount = math.clamp(math.floor(amount), 1, maxPerAction)
	local resolvedState = if initialState and initialState ~= "" then initialState else "InPlot"

	Network.AdminNetwork.SpawnPet.send({
		TargetUserId = targetUserId,
		SpeciesId = speciesId,
		Stage = stage,
		Amount = clampedAmount,
		InitialState = resolvedState,
	})
end

function AdminController.SpawnPetToSelf(speciesId: string, stage: string, amount: number, initialState: string?)
	local localUserId = getLocalUserId()
	if localUserId == 0 then
		return
	end
	AdminController.SpawnPetToTarget(localUserId, speciesId, stage, amount, initialState)
end

function AdminController.SetSelfWalkSpeed(walkSpeed: number)
	if not AdminController.State.IsAdmin then
		return
	end
	if walkSpeed ~= walkSpeed or math.abs(walkSpeed) == math.huge then
		return
	end
	local clamped = math.clamp(walkSpeed, AdminConfig.MinWalkSpeed, AdminConfig.MaxWalkSpeed)
	AdminController.State.SelfWalkSpeed = clamped
	AdminController.Notify()

	Network.AdminNetwork.SetSelfWalkSpeed.send({
		WalkSpeed = clamped,
	})
end

function AdminController.ClearToast()
	if AdminController.State.LastToast == nil then
		return
	end
	AdminController.State.LastToast = nil
	AdminController.Notify()
end

function AdminController.Start()
	if started then
		return
	end
	started = true

	Network.AdminNetwork.SyncAccess.listen(function(payload)
		hasSyncedAccess = true
		AdminController.State.IsAdmin = payload.IsAdmin
		AdminController.State.SelfWalkSpeed = payload.CurrentWalkSpeed

		local missingMap: { [string]: boolean } = {}
		for _, itemId in payload.MissingStudioItems do
			missingMap[itemId] = true
		end
		AdminController.State.MissingStudioItems = missingMap

		if not payload.IsAdmin then
			AdminController.State.IsOpen = false
			AdminController.State.PlayersList = {}
			AdminController.State.SelectedPlayerDetail = nil
			AdminController.State.AuditLogs = {}
		end
		AdminController.Notify()
	end)

	Network.AdminNetwork.SyncPlayerList.listen(function(payload)
		AdminController.State.PlayersList = payload.Players

		local localUserId = getLocalUserId()
		local selectedStillOnline = false
		local foundSelf = false

		for _, summary in payload.Players do
			if summary.UserId == AdminController.State.SelectedUserId then
				selectedStillOnline = true
			end
			if summary.UserId == localUserId then
				foundSelf = true
				AdminController.State.SelfWalkSpeed = summary.WalkSpeed
			end
		end

		if not selectedStillOnline and #payload.Players > 0 then
			local nextSelected = if foundSelf then localUserId else payload.Players[1].UserId
			AdminController.State.SelectedUserId = nextSelected
			AdminController.State.SelectedPlayerDetail = nil
			if AdminController.State.IsOpen then
				Network.AdminNetwork.InspectPlayer.send({
					TargetUserId = nextSelected,
				})
			end
		elseif #payload.Players == 0 then
			AdminController.State.SelectedPlayerDetail = nil
		end

		AdminController.Notify()
	end)

	Network.AdminNetwork.SyncAuditLogs.listen(function(payload)
		AdminController.State.AuditLogs = payload.AuditLogs
		AdminController.Notify()
	end)

	Network.AdminNetwork.SyncPlayerDetail.listen(function(payload)
		local detail = payload.Detail
		local updated = false

		if detail and (AdminController.State.SelectedUserId == 0 or detail.UserId == AdminController.State.SelectedUserId) then
			AdminController.State.SelectedPlayerDetail = detail
			updated = true
		end
		if detail and detail.UserId == getLocalUserId() then
			AdminController.State.SelfWalkSpeed = detail.WalkSpeed
			updated = true
		end
		if updated then
			AdminController.Notify()
		end
	end)

	Network.AdminNetwork.NotifyToast.listen(function(payload)
		AdminController.State.LastToast = {
			IsError = payload.IsError,
			Message = payload.Message,
			Timestamp = os.time(),
		}
		AdminController.Notify()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M and AdminController.State.IsAdmin then
			AdminController.TogglePanel()
		end
	end)

	task.spawn(function()
		for _ = 1, 10 do
			if hasSyncedAccess then
				break
			end
			Network.AdminNetwork.RequestAccess.send(nil)
			task.wait(0.5)
		end
	end)
end

function AdminController:KnitInit() end

function AdminController:KnitStart()
	AdminController.Start()
end

return AdminController
