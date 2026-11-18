local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

local InventoryClient = Knit.CreateController({
	Name = "InventoryClient",
})
InventoryClient.Data = nil :: Types.ClientInventory?
InventoryClient.SelectedStackId = nil :: number?
InventoryClient.IsOpen = true
InventoryClient.LastError = nil :: string?

local started = false
local listeners: { () -> () } = {}

local KeyToSlot = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

local function notify()
	for _, callback in listeners do
		callback()
	end
end

function InventoryClient.Subscribe(callback: () -> ()): () -> ()
	table.insert(listeners, callback)
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

function InventoryClient.GetStack(stackId: number?): Types.ClientStackData?
	if not stackId or not InventoryClient.Data then return nil end
	for _, stackData in InventoryClient.Data.Stacks do
		if stackData.StackId == stackId then
			return stackData
		end
	end
	return nil
end

function InventoryClient.SetWindowOpen(isOpen: boolean)
	if InventoryClient.IsOpen == isOpen then return end
	InventoryClient.IsOpen = isOpen
	notify()
end

function InventoryClient.SelectStack(stackId: number?)
	InventoryClient.SelectedStackId = stackId
	notify()
end

function InventoryClient.ClearError()
	if InventoryClient.LastError == nil then return end
	InventoryClient.LastError = nil
	notify()
end

function InventoryClient.HoldItem(slotNum: number)
	Network.Inventory.HoldItem.send({ slotNum = slotNum })
end

function InventoryClient.EquipToHotbar(stackId: number, slotNum: number)
	Network.Inventory.EquipToHotbar.send({ stackId = stackId, slotNum = slotNum })
end

function InventoryClient.UnequipFromHotbar(stackId: number)
	Network.Inventory.UnequipFromHotbar.send({ stackId = stackId })
end

function InventoryClient.DropItem(stackId: number)
	local stackData = InventoryClient.GetStack(stackId)
	if not stackData or not stackData.IsDroppable then return end
	Network.Inventory.DropItem.send({ stackId = stackId })
end

function InventoryClient.Start()
	if started then return end
	started = true

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	Network.Inventory.Update.listen(function(data)
		InventoryClient.Data = data
		if InventoryClient.SelectedStackId and not InventoryClient.GetStack(InventoryClient.SelectedStackId) then
			InventoryClient.SelectedStackId = nil
		end
		notify()
	end)

	Network.Inventory.Error.listen(function(message)
		InventoryClient.LastError = message
		notify()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.B then
			InventoryClient.SetWindowOpen(not InventoryClient.IsOpen)
			return
		end

		local slotNum = KeyToSlot[input.KeyCode]
		if slotNum then
			InventoryClient.HoldItem(slotNum)
		end
	end)

	task.spawn(function()
		for _ = 1, 10 do
			if InventoryClient.Data then
				break
			end
			Network.Inventory.Request.send(nil)
			task.wait(0.5)
		end
	end)
	notify()
end

function InventoryClient:KnitInit() end

function InventoryClient:KnitStart()
	InventoryClient.Start()
end

return InventoryClient
