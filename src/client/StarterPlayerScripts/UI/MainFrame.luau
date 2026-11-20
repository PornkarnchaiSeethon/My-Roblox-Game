local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local React = require(ReplicatedStorage.Packages.react)

local Components = script.Parent.Components
local ErrorToast = require(Components.ErrorToast)
local LevelBar = require(Components.LevelBar)
local InventoryFrame = require(script.Parent.InventoryFrame)
local HotbarSlot = require(script.Parent.HotbarSlot)
local PetBarnFrame = require(script.Parent.PetBarnFrame)
local IncubatorBreedingModal = require(script.Parent.IncubatorBreedingModal)

local e = React.createElement

local TABS = { "All", "Tools", "Resources", "Weapons", "Misc" }

export type InventoryController = {
	Data: any?,
	SelectedStackId: number?,
	IsOpen: boolean,
	LastError: string?,
	Subscribe: (callback: () -> ()) -> (() -> ()),
	HoldItem: (slotNum: number) -> (),
	SelectStack: (stackId: number?) -> (),
	SetWindowOpen: (isOpen: boolean) -> (),
	DropItem: (stackId: number) -> (),
	EquipToHotbar: (stackId: number, slotNum: number) -> (),
	UnequipFromHotbar: (stackId: number) -> (),
	ClearError: () -> (),
}

export type PetControllerLike = {
	State: {
		IsBarnOpen: boolean,
		SelectedPetUID: string?,
		ActiveModal: any?,
		MaxPetCapacity: number,
		MaxEquippedCombat: number,
		Pets: { any },
		Incubators: { any },
		BreedingPens: { any },
		Toast: { IsError: boolean, Message: string }?,
	},
	Subscribe: (callback: () -> ()) -> (() -> ()),
	ToggleBarn: () -> (),
	SetBarnOpen: (isOpen: boolean) -> (),
	SelectPet: (petUID: string?) -> (),
	CloseModal: () -> (),
	ClearToast: () -> (),
	FeedPet: (petUID: string, foodItemId: string) -> (),
	TriggerEvolve: (petUID: string, catalystItemId: string?) -> (),
	SetPetState: (petUID: string, targetState: string) -> (),
	StartIncubation: (objectId: string, eggItemId: string) -> (),
	ClaimHatchedPet: (objectId: string) -> (),
	StartBreeding: (objectId: string, parentA_UID: string, parentB_UID: string) -> (),
	ClaimBreedingEgg: (objectId: string) -> (),
}

type Props = {
	client: InventoryController?,
	petClient: PetControllerLike?,
}

local runtimeClient: InventoryController? = nil
local runtimePetClient: PetControllerLike? = nil

-- ดึง Client แบบไม่ Yield (ปลอดภัยสำหรับเรียกตอน Render)
local function tryGetRuntimeClient(): InventoryController?
	if runtimeClient then
		return runtimeClient
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local targetModule = playerScripts and playerScripts:FindFirstChild("InventoryClient")
	if targetModule and targetModule:IsA("ModuleScript") then
		local loaded = (require :: any)(targetModule) :: InventoryController
		runtimeClient = loaded
		return loaded
	end

	return nil
end

local function tryGetRuntimePetClient(): PetControllerLike?
	if runtimePetClient then
		return runtimePetClient
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local petFolder = playerScripts and playerScripts:FindFirstChild("PetService")
	local targetModule = petFolder and petFolder:FindFirstChild("PetController")
	if targetModule and targetModule:IsA("ModuleScript") then
		local loaded = (require :: any)(targetModule) :: PetControllerLike
		runtimePetClient = loaded
		return loaded
	end

	return nil
end

local function MainFrame(props: Props?)
	local client, setClient = React.useState(function(): InventoryController?
		if props and props.client then
			return props.client
		end
		return tryGetRuntimeClient()
	end)

	local petClient, setPetClient = React.useState(function(): PetControllerLike?
		if props and props.petClient then
			return props.petClient
		end
		return tryGetRuntimePetClient()
	end)

	local inventoryOpen, setInventoryOpen = React.useState(if client then client.IsOpen else false)
	local inventoryData, setInventoryData = React.useState(if client then client.Data else nil)
	local selectedStackId, setSelectedStackId = React.useState(if client then client.SelectedStackId else nil)
	local lastError, setLastError = React.useState(if client then client.LastError else nil)

	local _, setPetRevision = React.useState(0)

	-- ถ้ารอบแรกยังหา InventoryClient ไม่เจอ ให้รอโหลดใน useEffect แทนการบล็อก Render
	React.useEffect(function()
		if props and props.client then
			setClient(props.client)
			return
		end
		if client then
			return
		end

		local thread = task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				return
			end
			local playerScripts = player:WaitForChild("PlayerScripts")
			local targetModule = playerScripts:WaitForChild("InventoryClient")
			assert(
				targetModule:IsA("ModuleScript"),
				"InventoryClient ต้องเป็น ModuleScript ไม่ใช่ " .. targetModule.ClassName
			)
			local loaded = (require :: any)(targetModule) :: InventoryController
			runtimeClient = loaded
			setClient(loaded)
		end)

		return function()
			task.cancel(thread)
		end
	end, { props and props.client })

	-- รอโหลด PetController แบบไม่บล็อก Render
	React.useEffect(function()
		if props and props.petClient then
			setPetClient(props.petClient)
			return
		end
		if petClient then
			return
		end

		local thread = task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				return
			end
			local playerScripts = player:WaitForChild("PlayerScripts")
			local petFolder = playerScripts:WaitForChild("PetService")
			local targetModule = petFolder:WaitForChild("PetController")
			if targetModule:IsA("ModuleScript") then
				local loaded = (require :: any)(targetModule) :: PetControllerLike
				runtimePetClient = loaded
				setPetClient(loaded)
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { props and props.petClient })

	-- Sync ข้อมูล Inventory และ Subscribe
	React.useEffect(function()
		if not client then
			return
		end

		setInventoryOpen(client.IsOpen)
		setInventoryData(client.Data)
		setSelectedStackId(client.SelectedStackId)
		setLastError(client.LastError)

		return client.Subscribe(function()
			setInventoryOpen(client.IsOpen)
			setInventoryData(client.Data)
			setSelectedStackId(client.SelectedStackId)
			setLastError(client.LastError)
		end)
	end, { client })

	-- Subscribe ข้อมูลสัตว์เลี้ยงจาก PetController
	React.useEffect(function()
		if not petClient then
			return
		end

		return petClient.Subscribe(function()
			setPetRevision(function(prev)
				return prev + 1
			end)
		end)
	end, { petClient })

	if not client then
		return nil
	end

	local petState = if petClient then petClient.State else nil
	local petBarnOpen = if petState then petState.IsBarnOpen else false
	local petModal = if petState then petState.ActiveModal else nil
	local petToast = if petState then petState.Toast else nil

	local toastMessage: string? = if petToast then petToast.Message else lastError
	local toastIsError: boolean = if petToast then petToast.IsError else true

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		ToggleInventory = e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.46, 0),
			Size = UDim2.fromOffset(118, 42),
			BackgroundColor3 = if inventoryOpen
				then Color3.fromRGB(68, 125, 235)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = Color3.fromRGB(245, 247, 255),
			Text = if inventoryOpen then "Close [B]" else "Bag [B]",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = false,
			AutoButtonColor = true,
			ZIndex = 20,
			[React.Event.Activated] = function()
				local nextOpen = not inventoryOpen
				if nextOpen and petClient then
					petClient.SetBarnOpen(false)
					petClient.CloseModal()
				end
				setInventoryOpen(nextOpen)
				client.SetWindowOpen(nextOpen)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if inventoryOpen
					then Color3.fromRGB(140, 185, 255)
					else Color3.fromRGB(62, 70, 92),
			}),
		}),

		TogglePets = petClient and e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.46, 52),
			Size = UDim2.fromOffset(118, 42),
			BackgroundColor3 = if petBarnOpen
				then Color3.fromRGB(58, 165, 105)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = Color3.fromRGB(245, 247, 255),
			Text = if petBarnOpen then "Close [P]" else "Pets [P]",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = false,
			AutoButtonColor = true,
			ZIndex = 20,
			[React.Event.Activated] = function()
				if not petBarnOpen and inventoryOpen then
					setInventoryOpen(false)
					client.SetWindowOpen(false)
				end
				petClient.ToggleBarn()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if petBarnOpen
					then Color3.fromRGB(120, 230, 160)
					else Color3.fromRGB(62, 70, 92),
			}),
		}),

		LevelBar = e(LevelBar),
		HotbarSlot = e(HotbarSlot, {
			data = inventoryData,
			onHold = client.HoldItem,
		}),
		Inventory = inventoryOpen and e(InventoryFrame, {
			data = inventoryData,
			selectedStackId = selectedStackId,
			onSelectStack = client.SelectStack,
			tabs = TABS,
			onDrop = client.DropItem,
			onEquip = client.EquipToHotbar,
			onUnequip = client.UnequipFromHotbar,
			onClose = function()
				client.SetWindowOpen(false)
			end,
		}),
		PetBarn = (petClient and petState and petBarnOpen) and e(PetBarnFrame, {
			pets = petState.Pets,
			maxPetCapacity = petState.MaxPetCapacity,
			maxEquippedCombat = petState.MaxEquippedCombat,
			selectedPetUID = petState.SelectedPetUID,
			inventoryData = inventoryData,
			onSelectPet = petClient.SelectPet,
			onFeedPet = petClient.FeedPet,
			onTriggerEvolve = petClient.TriggerEvolve,
			onSetPetState = petClient.SetPetState,
			onClose = function()
				petClient.SetBarnOpen(false)
			end,
		}),
		PetModal = (petClient and petState and petModal) and e(IncubatorBreedingModal, {
			modal = petModal,
			pets = petState.Pets,
			incubators = petState.Incubators,
			breedingPens = petState.BreedingPens,
			inventoryData = inventoryData,
			onStartIncubation = petClient.StartIncubation,
			onClaimHatchedPet = petClient.ClaimHatchedPet,
			onStartBreeding = petClient.StartBreeding,
			onClaimBreedingEgg = petClient.ClaimBreedingEgg,
			onClose = petClient.CloseModal,
		}),
		Error = e(ErrorToast, {
			message = toastMessage,
			isError = toastIsError,
			onDismiss = function()
				if petToast and petClient then
					petClient.ClearToast()
				else
					client.ClearError()
				end
			end,
		}),
	})
end

return MainFrame
