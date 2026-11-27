--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local PetVisualRenderer = require(script.Parent:WaitForChild("PetVisualRenderer"))

local PetController = Knit.CreateController({
	Name = "PetController",
})

PetController.State = {
	IsBarnOpen = false,
	SelectedPetUID = nil :: string?,
	ActiveModal = nil :: Types.PetModalInfo?,
	MaxPetCapacity = PetConfig.DefaultMaxPetCapacity,
	MaxEquippedCombat = PetConfig.DefaultMaxEquippedCombat,
	Pets = {} :: { Types.PetInstanceData },
	Incubators = {} :: { Types.IncubatorClientData },
	BreedingPens = {} :: { Types.BreedingPenClientData },
	Toast = nil :: Types.PetToastInfo?,
}

local started = false
local hasSynced = false
local listeners: { () -> () } = {}

function PetController.Subscribe(callback: () -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

function PetController.Notify()
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function PetController.ToggleBarn()
	PetController.State.IsBarnOpen = not PetController.State.IsBarnOpen
	if PetController.State.IsBarnOpen then
		PetController.State.ActiveModal = nil
	end
	PetController.Notify()
end

function PetController.SetBarnOpen(isOpen: boolean)
	if PetController.State.IsBarnOpen == isOpen then
		return
	end
	PetController.State.IsBarnOpen = isOpen
	if isOpen then
		PetController.State.ActiveModal = nil
	end
	PetController.Notify()
end

function PetController.SelectPet(petUID: string?)
	PetController.State.SelectedPetUID = petUID
	PetController.Notify()
end

function PetController.OpenModal(modalType: "Incubator" | "Breeding", objectId: string)
	PetController.State.IsBarnOpen = false
	PetController.State.ActiveModal = {
		Type = modalType,
		ObjectId = objectId,
	}
	PetController.Notify()
end

function PetController.CloseModal()
	if PetController.State.ActiveModal == nil then
		return
	end
	PetController.State.ActiveModal = nil
	PetController.Notify()
end

function PetController.ClearToast()
	if PetController.State.Toast == nil then
		return
	end
	PetController.State.Toast = nil
	PetController.Notify()
end

function PetController.FeedPet(petUID: string, foodItemId: string)
	Network.PetNetwork.FeedPet.send({
		PetUID = petUID,
		FoodItemId = foodItemId,
	})
end

function PetController.TriggerEvolve(petUID: string, catalystItemId: string?)
	Network.PetNetwork.TriggerEvolve.send({
		PetUID = petUID,
		CatalystItemId = catalystItemId,
	})
end

function PetController.SetPetState(petUID: string, targetState: string)
	Network.PetNetwork.SetPetState.send({
		PetUID = petUID,
		TargetState = targetState,
	})
end

function PetController.StartIncubation(objectId: string, eggItemId: string)
	Network.PetNetwork.StartIncubation.send({
		ObjectId = objectId,
		EggItemId = eggItemId,
	})
end

function PetController.ClaimHatchedPet(objectId: string)
	Network.PetNetwork.ClaimHatchedPet.send({
		ObjectId = objectId,
	})
end

function PetController.StartBreeding(objectId: string, parentA_UID: string, parentB_UID: string)
	Network.PetNetwork.StartBreeding.send({
		ObjectId = objectId,
		ParentA_UID = parentA_UID,
		ParentB_UID = parentB_UID,
	})
end

function PetController.ClaimBreedingEgg(objectId: string)
	Network.PetNetwork.ClaimBreedingEgg.send({
		ObjectId = objectId,
	})
end

function PetController.Start()
	if started then
		return
	end
	started = true

	PetVisualRenderer.Start()

	Network.PetNetwork.SyncState.listen(function(payload)
		hasSynced = true
		PetController.State.MaxPetCapacity = payload.MaxPetCapacity
		PetController.State.MaxEquippedCombat = payload.MaxEquippedCombat
		PetController.State.Pets = payload.Pets
		PetController.State.Incubators = payload.Incubators
		PetController.State.BreedingPens = payload.BreedingPens

		if PetController.State.SelectedPetUID then
			local found = false
			for _, pet in payload.Pets do
				if pet.UID == PetController.State.SelectedPetUID then
					found = true
					break
				end
			end
			if not found then
				PetController.State.SelectedPetUID = nil
			end
		end

		PetController.Notify()
	end)

	Network.PetNetwork.OpenModal.listen(function(payload)
		if payload.ModalType == "Incubator" or payload.ModalType == "Breeding" then
			PetController.OpenModal(payload.ModalType :: "Incubator" | "Breeding", payload.ObjectId)
		end
	end)

	Network.PetNetwork.NotifyToast.listen(function(payload)
		PetController.State.Toast = {
			IsError = payload.IsError,
			Message = payload.Message,
		}
		PetController.Notify()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			PetController.ToggleBarn()
		end
	end)

	task.spawn(function()
		for _ = 1, 10 do
			if hasSynced then
				break
			end
			Network.PetNetwork.RequestSync.send(nil)
			task.wait(0.5)
		end
	end)
end

function PetController:KnitInit() end

function PetController:KnitStart()
	PetController.Start()
end

return PetController
