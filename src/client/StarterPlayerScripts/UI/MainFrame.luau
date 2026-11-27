local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local React = require(ReplicatedStorage.Packages.react)
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local Components = script.Parent.Components
local ErrorToast = require(Components.ErrorToast)
local LevelBar = require(Components.LevelBar)
local NPCBossBar = require(Components.NPCBossBar)
local InventoryFrame = require(script.Parent.InventoryFrame)
local HotbarSlot = require(script.Parent.HotbarSlot)
local PetBarnFrame = require(script.Parent.PetBarnFrame)
local IncubatorBreedingModal = require(script.Parent.IncubatorBreedingModal)
local CropAlmanacFrame = require(script.Parent.CropAlmanacFrame)
local PlantModal = require(script.Parent.PlantModal)
local AdminPanelFrame = require(script.Parent.AdminPanelFrame)
local NPCDialogueModal = require(script.Parent.NPCDialogueModal)

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

export type PlantControllerLike = {
	State: {
		IsAlmanacOpen: boolean,
		ActiveModal: { ObjectId: string, PlanterType: string }?,
		PlantersById: { [string]: any },
		HarvestStats: { [string]: number },
		Toast: { IsError: boolean, Message: string }?,
	},
	Subscribe: (callback: () -> ()) -> (() -> ()),
	ToggleAlmanac: () -> (),
	SetAlmanacOpen: (isOpen: boolean) -> (),
	CloseModal: () -> (),
	ClearToast: () -> (),
	PlantSeed: (objectId: string, seedItemId: string) -> (),
	WaterPlant: (objectId: string) -> (),
	ApplyFertilizer: (objectId: string, fertilizerItemId: string) -> (),
	HarvestCrop: (objectId: string) -> (),
	UprootPlant: (objectId: string) -> (),
}

export type AdminControllerLike = {
	State: {
		IsAdmin: boolean,
		IsOpen: boolean,
		ActiveTab: AdminPanelFrame.AdminTab,
		PlayersList: { any },
		SelectedUserId: number,
		SelectedPlayerDetail: any?,
		SelfWalkSpeed: number,
		MissingStudioItems: { [string]: boolean },
		AuditLogs: { any },
		LastToast: { IsError: boolean, Message: string, Timestamp: number? }?,
	},
	Subscribe: (callback: () -> ()) -> (() -> ()),
	TogglePanel: () -> (),
	SetPanelOpen: (isOpen: boolean) -> (),
	SetTab: (tab: AdminPanelFrame.AdminTab) -> (),
	SelectAndInspectPlayer: (targetUserId: number) -> (),
	RefreshPlayers: () -> (),
	GiveItemToTarget: (targetUserId: number, itemId: string, amount: number) -> (),
	GiveItemToSelf: (itemId: string, amount: number) -> (),
	SpawnPetToTarget: (targetUserId: number, speciesId: string, stage: string, amount: number, initialState: string?) -> (),
	SpawnPetToSelf: (speciesId: string, stage: string, amount: number, initialState: string?) -> (),
	SetSelfWalkSpeed: (walkSpeed: number) -> (),
	ClearToast: () -> (),
}

export type NPCControllerLike = {
	State: {
		ActiveBosses: { any },
		ActiveDialogue: any?,
		LastToast: { IsError: boolean, Message: string, Timestamp: number? }?,
	},
	Subscribe: (callback: () -> ()) -> (() -> ()),
	SubscribeBosses: ((callback: () -> ()) -> (() -> ()))?,
	SubscribeDialogue: ((callback: () -> ()) -> (() -> ()))?,
	SubscribeToast: ((callback: () -> ()) -> (() -> ()))?,
	CloseDialogue: () -> (),
	ClearToast: () -> (),
	GetNearbyBoss: () -> any?,
}

type Props = {
	client: InventoryController?,
	petClient: PetControllerLike?,
	plantClient: PlantControllerLike?,
	adminClient: AdminControllerLike?,
	npcClient: NPCControllerLike?,
}

local runtimeClient: InventoryController? = nil
local runtimePetClient: PetControllerLike? = nil
local runtimePlantClient: PlantControllerLike? = nil
local runtimeAdminClient: AdminControllerLike? = nil
local runtimeNPCClient: NPCControllerLike? = nil

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

local function tryGetRuntimePlantClient(): PlantControllerLike?
	if runtimePlantClient then
		return runtimePlantClient
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local plantFolder = playerScripts and playerScripts:FindFirstChild("PlantService")
	local targetModule = plantFolder and plantFolder:FindFirstChild("PlantController")
	if targetModule and targetModule:IsA("ModuleScript") then
		local loaded = (require :: any)(targetModule) :: PlantControllerLike
		runtimePlantClient = loaded
		return loaded
	end

	return nil
end

local function tryGetRuntimeAdminClient(): AdminControllerLike?
	if runtimeAdminClient then
		return runtimeAdminClient
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local adminFolder = playerScripts and playerScripts:FindFirstChild("AdminService")
	local targetModule = adminFolder and adminFolder:FindFirstChild("AdminController")
	if targetModule and targetModule:IsA("ModuleScript") then
		local loaded = (require :: any)(targetModule) :: AdminControllerLike
		runtimeAdminClient = loaded
		return loaded
	end

	return nil
end

local function tryGetRuntimeNPCClient(): NPCControllerLike?
	if runtimeNPCClient then
		return runtimeNPCClient
	end

	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local npcFolder = playerScripts and playerScripts:FindFirstChild("NPCService")
	local targetModule = npcFolder and npcFolder:FindFirstChild("NPCController")
	if targetModule and targetModule:IsA("ModuleScript") then
		local loaded = (require :: any)(targetModule) :: NPCControllerLike
		runtimeNPCClient = loaded
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

	local plantClient, setPlantClient = React.useState(function(): PlantControllerLike?
		if props and props.plantClient then
			return props.plantClient
		end
		return tryGetRuntimePlantClient()
	end)

	local adminClient, setAdminClient = React.useState(function(): AdminControllerLike?
		if props and props.adminClient then
			return props.adminClient
		end
		return tryGetRuntimeAdminClient()
	end)

	local npcClient, setNpcClient = React.useState(function(): NPCControllerLike?
		if props and props.npcClient then
			return props.npcClient
		end
		return tryGetRuntimeNPCClient()
	end)

	local inventoryOpen, setInventoryOpen = React.useState(if client then client.IsOpen else false)
	local inventoryData, setInventoryData = React.useState(if client then client.Data else nil)
	local selectedStackId, setSelectedStackId = React.useState(if client then client.SelectedStackId else nil)
	local lastError, setLastError = React.useState(if client then client.LastError else nil)

	local _, setPetRevision = React.useState(0)
	local _, setPlantRevision = React.useState(0)
	local _, setAdminRevision = React.useState(0)
	local npcToast, setNpcToast = React.useState(if npcClient and npcClient.State then npcClient.State.LastToast else nil)

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

	React.useEffect(function()
		if props and props.plantClient then
			setPlantClient(props.plantClient)
			return
		end
		if plantClient then
			return
		end

		local thread = task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				return
			end
			local playerScripts = player:WaitForChild("PlayerScripts")
			local plantFolder = playerScripts:WaitForChild("PlantService")
			local targetModule = plantFolder:WaitForChild("PlantController")
			if targetModule:IsA("ModuleScript") then
				local loaded = (require :: any)(targetModule) :: PlantControllerLike
				runtimePlantClient = loaded
				setPlantClient(loaded)
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { props and props.plantClient })

	React.useEffect(function()
		if props and props.adminClient then
			setAdminClient(props.adminClient)
			return
		end
		if adminClient then
			return
		end

		local thread = task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				return
			end
			local playerScripts = player:WaitForChild("PlayerScripts")
			local adminFolder = playerScripts:WaitForChild("AdminService")
			local targetModule = adminFolder:WaitForChild("AdminController")
			if targetModule:IsA("ModuleScript") then
				local loaded = (require :: any)(targetModule) :: AdminControllerLike
				runtimeAdminClient = loaded
				setAdminClient(loaded)
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { props and props.adminClient })

	React.useEffect(function()
		if props and props.npcClient then
			setNpcClient(props.npcClient)
			return
		end
		if npcClient then
			return
		end

		local thread = task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				return
			end
			local playerScripts = player:WaitForChild("PlayerScripts")
			local npcFolder = playerScripts:WaitForChild("NPCService")
			local targetModule = npcFolder:WaitForChild("NPCController")
			if targetModule:IsA("ModuleScript") then
				local loaded = (require :: any)(targetModule) :: NPCControllerLike
				runtimeNPCClient = loaded
				setNpcClient(loaded)
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { props and props.npcClient })

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

	React.useEffect(function()
		if not plantClient then
			return
		end

		return plantClient.Subscribe(function()
			setPlantRevision(function(prev)
				return prev + 1
			end)
		end)
	end, { plantClient })

	React.useEffect(function()
		if not adminClient then
			return
		end

		return adminClient.Subscribe(function()
			setAdminRevision(function(prev)
				return prev + 1
			end)
		end)
	end, { adminClient })

	React.useEffect(function()
		if not npcClient then
			setNpcToast(nil)
			return
		end

		setNpcToast(npcClient.State.LastToast)
		local sub = npcClient.SubscribeToast or npcClient.Subscribe
		return sub(function()
			setNpcToast(npcClient.State.LastToast)
		end)
	end, { npcClient })

	local adminState = if adminClient then adminClient.State else nil
	local adminIsAdmin = if adminState then adminState.IsAdmin else false
	local adminOpen = if adminState and adminIsAdmin then adminState.IsOpen else false
	local adminToast = if adminState then adminState.LastToast else nil

	local handleCloseAdminPanel = React.useCallback(function()
		if adminClient then
			adminClient.SetPanelOpen(false)
		end
	end, { adminClient })

	React.useEffect(function()
		if not adminOpen then
			return
		end
		if client and client.IsOpen then
			setInventoryOpen(false)
			client.SetWindowOpen(false)
		end
		if petClient then
			petClient.SetBarnOpen(false)
			petClient.CloseModal()
		end
		if plantClient then
			plantClient.SetAlmanacOpen(false)
			plantClient.CloseModal()
		end
		if npcClient then
			npcClient.CloseDialogue()
		end
	end, { adminOpen })

	if not client then
		return nil
	end

	local petState = if petClient then petClient.State else nil
	local petBarnOpen = if petState then petState.IsBarnOpen else false
	local petModal = if petState then petState.ActiveModal else nil
	local petToast = if petState then petState.Toast else nil

	local plantState = if plantClient then plantClient.State else nil
	local plantAlmanacOpen = if plantState then plantState.IsAlmanacOpen else false
	local plantModal = if plantState then plantState.ActiveModal else nil
	local plantToast = if plantState then plantState.Toast else nil

	local seedCounts: { [string]: number } = {}
	local fertilizerCounts: { [string]: number } = {}
	local hasWateringCan = false
	if inventoryData and inventoryData.Stacks then
		for _, stack in inventoryData.Stacks do
			local itemName = stack.Name
			if PlantConfig.Crops[itemName] then
				seedCounts[itemName] = (seedCounts[itemName] or 0) + stack.Count
			elseif PlantConfig.Fertilizers[itemName] then
				fertilizerCounts[itemName] = (fertilizerCounts[itemName] or 0) + stack.Count
			elseif itemName == "watering_can" and stack.Count > 0 then
				hasWateringCan = true
			end
		end
	end

	local toastMessage: string? = if adminToast
		then adminToast.Message
		elseif npcToast then npcToast.Message
		elseif plantToast then plantToast.Message
		elseif petToast then petToast.Message
		else lastError
	local toastIsError: boolean = if adminToast
		then adminToast.IsError
		elseif npcToast then npcToast.IsError
		elseif plantToast then plantToast.IsError
		elseif petToast then petToast.IsError
		else true

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
				if nextOpen then
					if petClient then
						petClient.SetBarnOpen(false)
						petClient.CloseModal()
					end
					if plantClient then
						plantClient.SetAlmanacOpen(false)
						plantClient.CloseModal()
					end
					if adminClient then
						adminClient.SetPanelOpen(false)
					end
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
				if not petBarnOpen then
					if inventoryOpen then
						setInventoryOpen(false)
						client.SetWindowOpen(false)
					end
					if plantClient then
						plantClient.SetAlmanacOpen(false)
						plantClient.CloseModal()
					end
					if adminClient then
						adminClient.SetPanelOpen(false)
					end
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

		ToggleFarm = plantClient and e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.46, 104),
			Size = UDim2.fromOffset(118, 42),
			BackgroundColor3 = if plantAlmanacOpen
				then Color3.fromRGB(205, 145, 42)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = Color3.fromRGB(245, 247, 255),
			Text = if plantAlmanacOpen then "Close [H]" else "Farm [H]",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = false,
			AutoButtonColor = true,
			ZIndex = 20,
			[React.Event.Activated] = function()
				if not plantAlmanacOpen then
					if inventoryOpen then
						setInventoryOpen(false)
						client.SetWindowOpen(false)
					end
					if petClient then
						petClient.SetBarnOpen(false)
						petClient.CloseModal()
					end
					if adminClient then
						adminClient.SetPanelOpen(false)
					end
				end
				plantClient.ToggleAlmanac()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if plantAlmanacOpen
					then Color3.fromRGB(250, 210, 110)
					else Color3.fromRGB(62, 70, 92),
			}),
		}),

		ToggleAdmin = (adminClient and adminState and adminState.IsAdmin) and e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.46, 156),
			Size = UDim2.fromOffset(118, 42),
			BackgroundColor3 = if adminOpen
				then Color3.fromRGB(185, 58, 86)
				else Color3.fromRGB(28, 32, 44),
			TextColor3 = Color3.fromRGB(245, 247, 255),
			Text = if adminOpen then "Close [M]" else "Admin [M]",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = false,
			AutoButtonColor = true,
			ZIndex = 20,
			[React.Event.Activated] = function()
				if not adminOpen then
					if inventoryOpen then
						setInventoryOpen(false)
						client.SetWindowOpen(false)
					end
					if petClient then
						petClient.SetBarnOpen(false)
						petClient.CloseModal()
					end
					if plantClient then
						plantClient.SetAlmanacOpen(false)
						plantClient.CloseModal()
					end
				end
				adminClient.TogglePanel()
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = e("UIStroke", {
				Thickness = 1.5,
				Color = if adminOpen
					then Color3.fromRGB(245, 130, 155)
					else Color3.fromRGB(125, 56, 74),
			}),
		}),

		LevelBar = e(LevelBar),
		NPCBossBar = npcClient and e(NPCBossBar, {
			npcClient = npcClient,
		}),
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
		CropAlmanac = (plantClient and plantState and plantAlmanacOpen) and e(CropAlmanacFrame, {
			plantersById = plantState.PlantersById,
			harvestStats = plantState.HarvestStats,
			seedCounts = seedCounts,
			hasWateringCan = hasWateringCan,
			onWater = plantClient.WaterPlant,
			onHarvest = plantClient.HarvestCrop,
			onClose = function()
				plantClient.SetAlmanacOpen(false)
			end,
		}),
		PlantModal = (plantClient and plantState and plantModal) and e(PlantModal, {
			ModalInfo = plantModal,
			PlanterState = plantState.PlantersById[plantModal.ObjectId],
			SeedCounts = seedCounts,
			HasWateringCan = hasWateringCan,
			FertilizerCounts = fertilizerCounts,
			OnPlantSeed = plantClient.PlantSeed,
			OnWater = plantClient.WaterPlant,
			OnFertilize = plantClient.ApplyFertilizer,
			OnHarvest = plantClient.HarvestCrop,
			OnUproot = plantClient.UprootPlant,
			OnClose = plantClient.CloseModal,
		}),
		AdminPanel = (adminClient and adminState and adminState.IsAdmin and adminOpen) and e(AdminPanelFrame, {
			ActiveTab = adminState.ActiveTab,
			PlayersList = adminState.PlayersList,
			SelectedUserId = adminState.SelectedUserId,
			SelectedDetail = adminState.SelectedPlayerDetail,
			SelfWalkSpeed = adminState.SelfWalkSpeed,
			MissingStudioItems = adminState.MissingStudioItems,
			AuditLogs = adminState.AuditLogs,
			OnSelectTab = adminClient.SetTab,
			OnSelectPlayer = adminClient.SelectAndInspectPlayer,
			OnRefreshPlayers = adminClient.RefreshPlayers,
			OnGiveItemToSelf = adminClient.GiveItemToSelf,
			OnGiveItemToTarget = adminClient.GiveItemToTarget,
			OnSpawnPetToSelf = adminClient.SpawnPetToSelf,
			OnSpawnPetToTarget = adminClient.SpawnPetToTarget,
			OnSetSelfWalkSpeed = adminClient.SetSelfWalkSpeed,
			OnClose = handleCloseAdminPanel,
		}),
		NPCDialogue = npcClient and e(NPCDialogueModal, {
			npcClient = npcClient,
		}),
		Error = e(ErrorToast, {
			message = toastMessage,
			isError = toastIsError,
			onDismiss = function()
				if adminToast and adminClient then
					adminClient.ClearToast()
				elseif npcToast and npcClient then
					npcClient.ClearToast()
				elseif plantToast and plantClient then
					plantClient.ClearToast()
				elseif petToast and petClient then
					petClient.ClearToast()
				else
					client.ClearError()
				end
			end,
		}),
	})
end

return MainFrame
