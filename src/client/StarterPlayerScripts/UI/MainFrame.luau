local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local React = require(ReplicatedStorage.Packages.react)

local Components = script.Parent.Components
local ErrorToast = require(Components.ErrorToast)
local LevelBar = require(Components.LevelBar)
local InventoryFrame = require(script.Parent.InventoryFrame)
local HotbarSlot = require(script.Parent.HotbarSlot)

local e = React.createElement

local TABS = { "All", "Tools", "Resources", "Weapons", "Misc" }

type InventoryController = {
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

type Props = {
	client: InventoryController?,
}

local runtimeClient: InventoryController?

local function getRuntimeClient(): InventoryController
	if not runtimeClient then
		local player = Players.LocalPlayer
		local playerScripts = player:WaitForChild("PlayerScripts")
		runtimeClient = require(playerScripts:WaitForChild("InventoryClient"))
	end
	return runtimeClient
end

local function MainFrame(props: Props?)
	local client = if props and props.client then props.client else getRuntimeClient()
	local inventoryOpen, setInventoryOpen = React.useState(client.IsOpen)
	local inventoryData, setInventoryData = React.useState(client.Data)
	local selectedStackId, setSelectedStackId = React.useState(client.SelectedStackId)
	local lastError, setLastError = React.useState(client.LastError)

	React.useEffect(function()
		return client.Subscribe(function()
			setInventoryOpen(client.IsOpen)
			setInventoryData(client.Data)
			setSelectedStackId(client.SelectedStackId)
			setLastError(client.LastError)
		end)
	end, {})

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		ToggleInventory = e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(112, 44),
			BackgroundColor3 = Color3.fromRGB(45, 45, 55),
			TextColor3 = Color3.new(1, 1, 1),
			Text = if inventoryOpen then "Hide" else "Open",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextWrapped = false,
			ZIndex = 20,
			[React.Event.Activated] = function()
				local nextOpen = not inventoryOpen
				setInventoryOpen(nextOpen)
				client.SetWindowOpen(nextOpen)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Stroke = e("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255) }),
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
		Error = e(ErrorToast, {
			message = lastError,
			onDismiss = client.ClearError,
		}),
	})
end

return MainFrame
