local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Modules:WaitForChild("knit"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))
local ToolConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("ToolConfig"))
local Janitor = require(Modules:WaitForChild("janitor"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local DataService = require(script.Parent.DataService)

local InventoryServer = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})
InventoryServer.AllInventories = {} :: {[Player]: Types.Inventory}
InventoryServer.Janitors = {}
InventoryServer.CharacterJanitors = {}
InventoryServer.Respawning = {} :: {[Player]: boolean}
InventoryServer.HasLoaded = {} :: {[Player]: boolean}
InventoryServer.ToolCanTouch = {} :: {[BasePart]: boolean}
InventoryServer.ActionCooldowns = {} :: {[Player]: {[string]: number}}

InventoryServer.MaxStacks = 20
function InventoryServer.SerializeInventory(inv: Types.Inventory)
	local saveTable = {
		Hotbar = table.clone(inv.Hotbar),
		NextStackId = inv.NextStackId,
		Stacks = {},
	}

	for _, stackData in inv.Inventory do
		table.insert(saveTable.Stacks, {
			Name = stackData.Name,
			Count = #stackData.Items,
			StackId = stackData.StackId,
		})
	end

	return saveTable
end

function InventoryServer.SyncProfile(player: Player, profileOverride)
	local inv = InventoryServer.AllInventories[player]
	local profile = profileOverride or DataService.GetProfile(player)
	if not inv or not profile then return false end

	profile.Data.Items = InventoryServer.SerializeInventory(inv)
	return true
end

function InventoryServer.SerializeForClient(inv: Types.Inventory)
	local update = {
		Hotbar = table.clone(inv.Hotbar),
		NextStackId = inv.NextStackId,
		Stacks = {},
	}

	for _, stackData in inv.Inventory do
		table.insert(update.Stacks, {
			Name = stackData.Name,
			DisplayName = stackData.DisplayName,
			Description = stackData.Description,
			Image = stackData.Image,
			ItemType = stackData.ItemType,
			IsDroppable = stackData.IsDroppable,
			Count = #stackData.Items,
			StackId = stackData.StackId,
		})
	end

	return update
end

function InventoryServer.UpdateClient(player: Player)
	local inv = InventoryServer.AllInventories[player]
	if not inv then return end

	InventoryServer.SyncProfile(player)
	Network.Inventory.Update.sendTo(InventoryServer.SerializeForClient(inv), player)
end

function InventoryServer.CheckInventoryFull(player: Player, tool: Tool): boolean
	if not tool:IsA("Tool") then return true end
	local inv = InventoryServer.AllInventories[player]
	if not inv then return true end

	if #inv.Inventory < InventoryServer.MaxStacks then
		return false
	end

	local toolData = ToolConfig.Get(tool)
	local maxPerStack = toolData.MaxStack or 1

	for _, stackData in inv.Inventory do
		if stackData.Name == tool.Name and #stackData.Items < maxPerStack then
			return false
		end
	end
	return true
end

function InventoryServer.RegisterItem(player: Player, tool: Tool)
	if not tool:IsA("Tool") then return end
	if InventoryServer.Respawning[player] then return end

	local inv = InventoryServer.AllInventories[player]
	if not inv then return end

	for _, stackData in inv.Inventory do
		if table.find(stackData.Items, tool) then
			InventoryServer.UpdateDroppedItem(tool)
			return
		end
	end

	InventoryServer.UpdateDroppedItem(tool)

	local toolData = ToolConfig.Get(tool)
	local itemType = toolData.ItemType or "Resource"
	local maxStack = toolData.MaxStack or 1

	for _, stackData in inv.Inventory do
		if stackData.Name == tool.Name and #stackData.Items < maxStack then
			table.insert(stackData.Items, tool)
			InventoryServer.UpdateClient(player)
			return
		end
	end

	if #inv.Inventory >= InventoryServer.MaxStacks then
		task.defer(function()
			tool.Parent = workspace
		end)
		Network.Inventory.Error.sendTo("Inventory is full!", player)
		return
	end

	inv.NextStackId += 1
	local newStack: Types.StackData = {
		Name = tool.Name,
		DisplayName = toolData.DisplayName or tool.Name,
		Description = toolData.Description or "",
		Image = toolData.Image or "",
		ItemType = itemType,
		IsDroppable = toolData.IsDroppable ~= false,
		Items = {tool},
		StackId = inv.NextStackId,
	}
	table.insert(inv.Inventory, newStack)

	if itemType ~= "Armor" then
		for i = 1, 10 do
			local slotKey = "Slot" .. i
			if inv.Hotbar[slotKey] == nil then
				InventoryServer.EquipToHotbar(player, newStack.StackId, i, true)
				break
			end
		end
	end

	InventoryServer.UpdateClient(player)
end

function InventoryServer.UnregisterItem(player: Player, tool: Tool)
	if not tool:IsA("Tool") then return end
	if InventoryServer.Respawning[player] then return end

	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	if tool.Parent == backpack or (char and tool.Parent == char) then
		return
	end

	local inv = InventoryServer.AllInventories[player]
	if not inv then return end

	for stackIndex, stackData in inv.Inventory do
		local itemIndex = table.find(stackData.Items, tool)
		if itemIndex then
			table.remove(stackData.Items, itemIndex)
			if #stackData.Items == 0 then
				InventoryServer.UnequipFromHotbar(player, stackData.StackId, true)
				table.remove(inv.Inventory, stackIndex)
			end
			InventoryServer.UpdateClient(player)
			break
		end
	end
end

function InventoryServer.GetInventoryData(player: Player): Types.Inventory?
	while player.Parent and not InventoryServer.AllInventories[player] do
		task.wait()
	end
	return InventoryServer.AllInventories[player]
end

local function removeFromHotbar(player: Player, stackId: number)
	local inv = InventoryServer.AllInventories[player]
	if not inv then return end
	for slotKey, equippedId in inv.Hotbar do
		if equippedId == stackId then
			inv.Hotbar[slotKey] = nil
		end
	end
end

function InventoryServer.EquipToHotbar(player: Player, stackId: number, slotNum: number, suppressUpdate: boolean?)
	if typeof(stackId) ~= "number" or typeof(slotNum) ~= "number" then return end
	if slotNum % 1 ~= 0 or slotNum < 1 or slotNum > 10 then return end
	local inv = InventoryServer.AllInventories[player]
	if not inv or not InventoryServer.FindStackFromId(player, stackId) then return end

	removeFromHotbar(player, stackId)
	inv.Hotbar["Slot" .. slotNum] = stackId
	if not suppressUpdate then
		InventoryServer.UpdateClient(player)
	end
end

function InventoryServer.UnequipFromHotbar(player: Player, stackId: number, suppressUpdate: boolean?)
	if typeof(stackId) ~= "number" then return end
	local inv = InventoryServer.AllInventories[player]
	if not inv then return end

	removeFromHotbar(player, stackId)
	if not suppressUpdate then
		InventoryServer.UpdateClient(player)
	end
end

function InventoryServer.FindStackFromId(player: Player, stackId: number): Types.StackData?
	local inv = InventoryServer.AllInventories[player]
	if not inv then return nil end
	for _, stackData in inv.Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
	return nil
end

function InventoryServer.HasItem(player: Player, itemName: string): boolean
	local inv = InventoryServer.AllInventories[player]
	if not inv then return false end
	for _, stackData in inv.Inventory do
		if stackData.Name == itemName and #stackData.Items > 0 then
			return true
		end
	end
	return false
end

function InventoryServer.ConsumeItem(player: Player, itemName: string): boolean
	local inv = InventoryServer.AllInventories[player]
	if not inv then return false end

	for stackIndex, stackData in inv.Inventory do
		if stackData.Name == itemName and #stackData.Items > 0 then
			local tool = table.remove(stackData.Items)
			if #stackData.Items == 0 then
				InventoryServer.UnequipFromHotbar(player, stackData.StackId, true)
				table.remove(inv.Inventory, stackIndex)
			end
			if tool then
				tool:Destroy()
			end
			InventoryServer.UpdateClient(player)
			return true
		end
	end

	return false
end

function InventoryServer.GiveItem(player: Player, itemName: string): boolean
	local allItems = ServerStorage:FindFirstChild("AllItems")
	local sample = allItems and allItems:FindFirstChild(itemName)
	if not sample or not sample:IsA("Tool") then
		return false
	end

	if InventoryServer.CheckInventoryFull(player, sample) then
		return false
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return false
	end

	local clone = sample:Clone()
	clone.Parent = backpack
	InventoryServer.RegisterItem(player, clone)
	return true
end

function InventoryServer.HoldItem(player: Player, slotNum: number)
	if typeof(slotNum) ~= "number" or slotNum % 1 ~= 0 or slotNum < 1 or slotNum > 10 then return end
	local inv = InventoryServer.AllInventories[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not inv or not char or not hum then return end

	local stackId = inv.Hotbar["Slot" .. slotNum]
	if not stackId then
		hum:UnequipTools()
		return
	end

	local stackData = InventoryServer.FindStackFromId(player, stackId)
	if not stackData or #stackData.Items == 0 then return end

	local currentTool = char:FindFirstChildOfClass("Tool")
	if currentTool and table.find(stackData.Items, currentTool) then
		hum:UnequipTools()
	else
		local tool = stackData.Items[1]
		if tool and tool:IsDescendantOf(player) then
			hum:EquipTool(tool)
		end
	end
end

function InventoryServer.UnholdItems(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum:UnequipTools() end
end

function InventoryServer.DropItem(player: Player, stackId: number): boolean
	if typeof(stackId) ~= "number" then return false end
	local stackData = InventoryServer.FindStackFromId(player, stackId)
	if not stackData or not stackData.IsDroppable then
		Network.Inventory.Error.sendTo("You cannot drop this item!", player)
		return false
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	local toolToDrop = stackData.Items[1]
	if not root or not toolToDrop then return false end
	if toolToDrop.Parent ~= player.Backpack and toolToDrop.Parent ~= char then return false end

	toolToDrop.Parent = workspace
	toolToDrop:PivotTo(root.CFrame * CFrame.new(0, 0, -3))
	return true
end

function InventoryServer.UpdateDroppedItem(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end

	if tool.Parent == workspace then
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				if InventoryServer.ToolCanTouch[part] == nil then
					InventoryServer.ToolCanTouch[part] = part.CanTouch
				end
				part.CanTouch = false
				part.CanCollide = true
			end
		end

		if not handle:FindFirstChild("DroppedPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DroppedPrompt"
			prompt.ObjectText = ToolConfig.Get(tool).DisplayName or tool.Name
			prompt.ActionText = "Pick Up"
			prompt.Parent = handle

			prompt.Triggered:Connect(function(playerWhoTriggered)
				if InventoryServer.Respawning[playerWhoTriggered] then return end
				if tool.Parent ~= workspace or prompt.Parent ~= handle then return end
				if InventoryServer.CheckInventoryFull(playerWhoTriggered, tool) then
					Network.Inventory.Error.sendTo("Inventory is full!", playerWhoTriggered)
					return
				end
				local backpack = playerWhoTriggered:FindFirstChild("Backpack")
				if backpack and tool.Parent == workspace then
					prompt:Destroy()
					tool.Parent = backpack
				end
			end)
		end
	else
		local prompt = handle:FindFirstChild("DroppedPrompt")
		if prompt then prompt:Destroy() end

		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") then
				if InventoryServer.ToolCanTouch[part] ~= nil then
					part.CanTouch = InventoryServer.ToolCanTouch[part]
					InventoryServer.ToolCanTouch[part] = nil
				end
				part.CanCollide = false
			end
		end
	end
end

function InventoryServer.SaveData(player: Player, profileOverride)
	if not InventoryServer.HasLoaded[player] then return end
	InventoryServer.SyncProfile(player, profileOverride)
end

function InventoryServer.LoadData(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile then return end

	local savedData = profile.Data.Items
	if type(savedData) ~= "table" then
		savedData = {}
	end

	local backpack = player:WaitForChild("Backpack")
	local savedStacks = savedData.Stacks
	if type(savedStacks) ~= "table" then
		savedStacks = {}
	end

	local newInv: Types.Inventory = {
		Inventory = {},
		Hotbar = if type(savedData.Hotbar) == "table" then savedData.Hotbar else {},
		NextStackId = if type(savedData.NextStackId) == "number" then savedData.NextStackId else 0,
	}

	local allItems = ServerStorage:FindFirstChild("AllItems")
	if allItems then
		for _, savedStack in savedStacks do
			if type(savedStack) ~= "table" or type(savedStack.Name) ~= "string" then
				continue
			end

			local sample = allItems:FindFirstChild(savedStack.Name)
			if sample and sample:IsA("Tool") then
				local itemsTable = {}
				local toolData = ToolConfig.Get(sample)
				local itemType = toolData.ItemType or "Resource"
				local maxCount = toolData.MaxStack or 1
				local count = math.clamp(math.floor(tonumber(savedStack.Count) or 0), 0, maxCount)

				for i = 1, count do
					local clone = sample:Clone()
					clone.Parent = backpack
					table.insert(itemsTable, clone)
				end

				if #itemsTable > 0 then
					table.insert(newInv.Inventory, {
						Name = sample.Name,
						DisplayName = toolData.DisplayName or sample.Name,
						Description = toolData.Description or "",
						Image = toolData.Image or "",
						ItemType = itemType,
						IsDroppable = toolData.IsDroppable ~= false,
						Items = itemsTable,
						StackId = if type(savedStack.StackId) == "number" then savedStack.StackId else 0,
					})
				end
			else
				warn("Missing item template in ServerStorage.AllItems: " .. tostring(savedStack.Name))
			end
		end
	elseif #savedStacks > 0 then
		warn("Inventory data warning")
	end

	InventoryServer.AllInventories[player] = newInv
	InventoryServer.HasLoaded[player] = true
	InventoryServer.UpdateClient(player)
end

function InventoryServer.OnPlayerAdded(player: Player)
	local janitor = Janitor.new()
	InventoryServer.Janitors[player] = janitor
	janitor:add(function()
		local characterJanitor = InventoryServer.CharacterJanitors[player]
		if characterJanitor then
			characterJanitor:cleanup()
		end
		InventoryServer.CharacterJanitors[player] = nil
		InventoryServer.Janitors[player] = nil
		InventoryServer.AllInventories[player] = nil
		InventoryServer.ActionCooldowns[player] = nil
		InventoryServer.Respawning[player] = nil
		InventoryServer.HasLoaded[player] = nil
	end)

	local inv: Types.Inventory = {
		Inventory = {},
		Hotbar = {},
		NextStackId = 0,
	}
	InventoryServer.AllInventories[player] = inv

	local char = player.Character or player.CharacterAdded:Wait()
	InventoryServer.LoadData(player)

	local function onCharacterAdded(character: Model)
		local previousCharacterJanitor = InventoryServer.CharacterJanitors[player]
		if previousCharacterJanitor then
			previousCharacterJanitor:cleanup()
		end

		local characterJanitor = Janitor.new()
		InventoryServer.CharacterJanitors[player] = characterJanitor

		local backpack = player:WaitForChild("Backpack")
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid

		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") then
				InventoryServer.RegisterItem(player, tool)
			end
		end

		characterJanitor:add(backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				InventoryServer.RegisterItem(player, child)
			end
		end))
		characterJanitor:add(backpack.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				InventoryServer.UnregisterItem(player, child)
			end
		end))

		characterJanitor:add(character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				InventoryServer.RegisterItem(player, child)
			end
		end))
		characterJanitor:add(character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				InventoryServer.UnregisterItem(player, child)
			end
		end))

		characterJanitor:add(humanoid.Died:Connect(function()
			InventoryServer.Respawning[player] = true
			humanoid:UnequipTools()

			local tempFolder = Instance.new("Folder")
			tempFolder.Name = player.Name .. "_TempItems"
			tempFolder.Parent = ServerStorage

			for _, item in backpack:GetChildren() do
				if item:IsA("Tool") then
					item.Parent = tempFolder
				end
			end

			local newChar
			while player.Parent and not newChar do
				local currentCharacter = player.Character
				if currentCharacter and currentCharacter ~= character then
					newChar = currentCharacter
					break
				end
				task.wait()
			end

			local newBackpack = player:FindFirstChild("Backpack")
			while player.Parent and not newBackpack do
				task.wait()
				newBackpack = player:FindFirstChild("Backpack")
			end

			if not player.Parent or not newChar or not newBackpack then
				tempFolder:Destroy()
				InventoryServer.Respawning[player] = nil
				return
			end

			for _, item in tempFolder:GetChildren() do
				item.Parent = newBackpack
			end
			tempFolder:Destroy()
			InventoryServer.Respawning[player] = false
			InventoryServer.UpdateClient(player)
		end))
	end

	task.spawn(onCharacterAdded, char)
	janitor:add(player.CharacterAdded:Connect(onCharacterAdded))
end

function InventoryServer.OnPlayerRemoving(player: Player)
	InventoryServer.SaveData(player)
	if InventoryServer.Janitors[player] then
		InventoryServer.Janitors[player]:cleanup()
	end
end

function InventoryServer.Client:GetInventory(player: Player)
	local inv = InventoryServer.AllInventories[player]
	if not inv then
		return nil
	end
	return InventoryServer.SerializeForClient(inv)
end

function InventoryServer:KnitInit()
	DataService.OnBeforeProfileRelease(function(player, profile)
		InventoryServer.SaveData(player, profile)
	end)
end

function InventoryServer:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(InventoryServer.OnPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(InventoryServer.OnPlayerAdded)
	Players.PlayerRemoving:Connect(InventoryServer.OnPlayerRemoving)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			InventoryServer.SaveData(player)
		end
	end)

	for _, tool in workspace:GetChildren() do
		if tool:IsA("Tool") then
			InventoryServer.UpdateDroppedItem(tool)
		end
	end
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			InventoryServer.UpdateDroppedItem(child)
		end
	end)

	local function allowAction(player: Player, actionName: string, cooldown: number): boolean
		local now = os.clock()
		local playerCooldowns = InventoryServer.ActionCooldowns[player]
		if not playerCooldowns then
			playerCooldowns = {}
			InventoryServer.ActionCooldowns[player] = playerCooldowns
		end

		local lastAction = playerCooldowns[actionName]
		if lastAction and now - lastAction < cooldown then
			return false
		end

		playerCooldowns[actionName] = now
		return true
	end

	Network.Inventory.Request.listen(function(_, player)
		if not allowAction(player, "Request", 0.25) then return end
		if InventoryServer.GetInventoryData(player) then
			InventoryServer.UpdateClient(player)
		end
	end)
	Network.Inventory.EquipToHotbar.listen(function(data, player)
		if not allowAction(player, "EquipToHotbar", 0.1) then return end
		InventoryServer.EquipToHotbar(player, data.stackId, data.slotNum)
	end)
	Network.Inventory.UnequipFromHotbar.listen(function(data, player)
		if not allowAction(player, "UnequipFromHotbar", 0.1) then return end
		InventoryServer.UnequipFromHotbar(player, data.stackId)
	end)
	Network.Inventory.HoldItem.listen(function(data, player)
		if not allowAction(player, "HoldItem", 0.05) then return end
		InventoryServer.HoldItem(player, data.slotNum)
	end)
	Network.Inventory.UnholdItems.listen(function(_, player)
		if not allowAction(player, "UnholdItems", 0.05) then return end
		InventoryServer.UnholdItems(player)
	end)
	Network.Inventory.DropItem.listen(function(data, player)
		if not allowAction(player, "DropItem", 0.2) then return end
		InventoryServer.DropItem(player, data.stackId)
	end)
end

InventoryServer.Start = InventoryServer.KnitStart

return InventoryServer
