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

type Props = {
	client: InventoryController?,
}

local runtimeClient: InventoryController? = nil

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

local function MainFrame(props: Props?)
	local client, setClient = React.useState(function(): InventoryController?
		if props and props.client then
			return props.client
		end
		return tryGetRuntimeClient()
	end)

	local inventoryOpen, setInventoryOpen = React.useState(if client then client.IsOpen else false)
	local inventoryData, setInventoryData = React.useState(if client then client.Data else nil)
	local selectedStackId, setSelectedStackId = React.useState(if client then client.SelectedStackId else nil)
	local lastError, setLastError = React.useState(if client then client.LastError else nil)

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

	-- Sync ข้อมูลและ Subscribe เมื่อได้ตัว client มาแล้ว
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

	if not client then
		return nil
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		ToggleInventory = e("TextButton", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
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
