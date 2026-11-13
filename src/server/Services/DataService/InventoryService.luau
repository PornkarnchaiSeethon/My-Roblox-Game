local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Types = require(ReplicatedStorage.Shared.Modules.Types)
local Janitor = require(ReplicatedStorage.Packages.janitor)

local AUTOSAVE_TIME = 15
local DEFAULT_MAX_STACK = 1
local DEFAULT_ITEM_TYPE = "Special"

local InventoryService = {}
InventoryService.AllInventories = {} :: { [Player]: Types.Inventory }
InventoryService.Janitors = {}

InventoryService.MaxStackData = {
	Armor = 1,
	Special = 1,
	Consumable = 5,
	Resource = 10,
	Weapon = 1,
}
InventoryService.MaxStacks = 20

-- ---------------------------------------------------------------------------
-- Save / Load (placeholder)
-- ---------------------------------------------------------------------------

function InventoryService.SaveData(player: Player)
	print("Saving data for player: " .. player.Name)
end

function InventoryService.LoadData(player: Player)
	print("Loading data for player: " .. player.Name)
end

-- ---------------------------------------------------------------------------
-- Register / Unregister
-- ---------------------------------------------------------------------------

function InventoryService.RegisterItem(player: Player, tool: Instance)
	if not tool:IsA("Tool") then
		return
	end

	local inv = InventoryService.AllInventories[player]
	if not inv then
		return
	end

	-- Already registered (e.g. Backpack -> Character when equipping)
	for _, stackData in inv.Inventory do
		if table.find(stackData.Items, tool) then
			return
		end
	end

	-- Try to add to an existing stack that still has room
	for _, stackData in inv.Inventory do
		local maxInStack = InventoryService.MaxStackData[stackData.ItemType] or DEFAULT_MAX_STACK
		if stackData.Name == tool.Name and #stackData.Items < maxInStack then
			table.insert(stackData.Items, tool)
			return
		end
	end

	-- Otherwise create a new stack
	if #inv.Inventory >= InventoryService.MaxStacks then
		warn("Inventory is full for player: " .. player.Name)
		return
	end

	local stack: Types.StackData = {
		Name = tool.Name,
		Description = tool.ToolTip,
		Image = tool.TextureId,
		ItemType = tool:GetAttribute("ItemType") or DEFAULT_ITEM_TYPE,
		IsDropable = tool:GetAttribute("IsDroppable") == true,
		Items = { tool },
		StackId = inv.NextStackId,
	}
	inv.NextStackId += 1
	table.insert(inv.Inventory, stack)
end

function InventoryService.UnregisterItem(player: Player, tool: Instance)
	if not tool:IsA("Tool") then
		return
	end

	-- Still owned by the player (just moved between Backpack and Character)
	if tool.Parent == player.Backpack or (player.Character ~= nil and tool.Parent == player.Character) then
		return
	end

	local inv = InventoryService.AllInventories[player]
	if not inv then
		return
	end

	for index, stackData in inv.Inventory do
		local found = table.find(stackData.Items, tool)
		if found then
			table.remove(stackData.Items, found)

			if #stackData.Items == 0 then
				table.remove(inv.Inventory, index)

				-- Clear Hotbar / Armor slots that pointed to this stack
				for slot, stackId in inv.Hotbar do
					if stackId == stackData.StackId then
						inv.Hotbar[slot] = nil
					end
				end
				for slot, stackId in inv.Armor do
					if stackId == stackData.StackId then
						inv.Armor[slot] = nil
					end
				end
			end

			break
		end
	end
end

-- ---------------------------------------------------------------------------
-- Player lifecycle
-- ---------------------------------------------------------------------------

function InventoryService.OnPlayerAdd(player: Player)
	local backpack = player:WaitForChild("Backpack")

	for _, tool in StarterPack:GetChildren() do
		while not backpack:FindFirstChild(tool.Name) do
			if not player.Parent then
				return -- player left while waiting
			end
			task.wait()
		end
	end

	-- Main janitor (lives as long as the player is in the game)
	local janitor = Janitor.new()
	InventoryService.Janitors[player] = janitor
	janitor:GiveChore(function()
		InventoryService.Janitors[player] = nil
		InventoryService.AllInventories[player] = nil
	end)

	InventoryService.AllInventories[player] = {
		Inventory = {},
		Hotbar = {},
		Armor = {},
		NextStackId = 0,
	}

	-- Character janitor (cleaned every time the character respawns)
	local charJanitor = Janitor.new()
	janitor:GiveChore(function()
		charJanitor:Clean()
	end)

	if not player.Character then
		player.CharacterAdded:Wait()
	end

	-- Player left (or was cleaned up) while we were waiting
	if InventoryService.Janitors[player] ~= janitor then
		return
	end

	InventoryService.LoadData(player)

	local function charAdded(char: Model)
		charJanitor:Clean() -- drop connections from the previous character

		local currentBackpack = player:WaitForChild("Backpack")

		for _, tool in currentBackpack:GetChildren() do
			InventoryService.RegisterItem(player, tool)
		end

		charJanitor:GiveChore(char.ChildAdded:Connect(function(child: Instance)
			InventoryService.RegisterItem(player, child)
		end))
		charJanitor:GiveChore(char.ChildRemoved:Connect(function(child: Instance)
			InventoryService.UnregisterItem(player, child)
		end))
		charJanitor:GiveChore(currentBackpack.ChildAdded:Connect(function(child: Instance)
			InventoryService.RegisterItem(player, child)
		end))
		charJanitor:GiveChore(currentBackpack.ChildRemoved:Connect(function(child: Instance)
			InventoryService.UnregisterItem(player, child)
		end))
	end

	task.spawn(charAdded, player.Character :: Model)
	janitor:GiveChore(player.CharacterAdded:Connect(charAdded))
end

function InventoryService.OnPlayerRemove(player: Player)
	local janitor = InventoryService.Janitors[player]
	if not janitor then
		return -- already cleaned (BindToClose + PlayerRemoving can both fire)
	end

	InventoryService.SaveData(player) -- save BEFORE cleaning
	janitor:Clean()
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function InventoryService.Start()
	for _, player: Player in Players:GetPlayers() do
		task.spawn(InventoryService.OnPlayerAdd, player)
	end

	Players.PlayerAdded:Connect(InventoryService.OnPlayerAdd)
	Players.PlayerRemoving:Connect(InventoryService.OnPlayerRemove)

	game:BindToClose(function()
		for _, player: Player in Players:GetPlayers() do
			InventoryService.OnPlayerRemove(player)
		end
	end)

	-- Autosave: spread players evenly across AUTOSAVE_TIME
	task.spawn(function()
		while true do
			local players = Players:GetPlayers()
			if #players == 0 then
				task.wait(1) -- avoid a busy loop when the server is empty
			else
				for _, player in players do
					task.wait(AUTOSAVE_TIME / #players)
					if InventoryService.AllInventories[player] then
						InventoryService.SaveData(player)
					end
				end
			end
		end
	end)
end

return InventoryService
