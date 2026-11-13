local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local customInventoryFolder = ReplicatedStorage:WaitForChild("CustomInventory")
local settingsFolder = customInventoryFolder:WaitForChild("Settings")
local remoteEvents = customInventoryFolder:WaitForChild("RemoteEvents")

local invFolderName = settingsFolder:WaitForChild("InventoryFolderName").Value
local hotbarFolderName = settingsFolder:WaitForChild("HotbarFolderName").Value
local backpackFolderName = settingsFolder:WaitForChild("BackpackFolderName").Value
local hotbarSlots = settingsFolder:WaitForChild("HotbarSlots").Value

-- 1. สร้างโฟลเดอร์เก็บ ObjectValue ของไอเทมสำหรับผู้เล่นแต่ละคน
local function createInventoryFolder(player)
	local inventoryFolder = Instance.new("Folder")
	inventoryFolder.Name = invFolderName
	inventoryFolder.Parent = player

	local hotbarFolder = Instance.new("Folder")
	hotbarFolder.Name = hotbarFolderName
	hotbarFolder.Parent = inventoryFolder

	local backpackFolder = Instance.new("Folder")
	backpackFolder.Name = backpackFolderName
	backpackFolder.Parent = inventoryFolder

	for i = 1, hotbarSlots do
		local slotValue = Instance.new("ObjectValue")
		slotValue.Name = tostring(i)
		slotValue.Value = nil
		slotValue.Parent = hotbarFolder
	end

	return inventoryFolder, hotbarFolder, backpackFolder
end

-- 2. คอยตรวจจับเมื่อผู้เล่นได้รับหรือเสีย Tool ในตัวละคร/Backpack
local function trackPlayerTools(player)
	local inventoryFolder = player:WaitForChild(invFolderName)
	local hotbarFolder = inventoryFolder:WaitForChild(hotbarFolderName)
	local backpackFolder = inventoryFolder:WaitForChild(backpackFolderName)

	local function getAllPlayerTools()
		local tools = {}
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item:IsA("Tool") then
					table.insert(tools, item)
				end
			end
		end
		if player.Character then
			for _, item in ipairs(player.Character:GetChildren()) do
				if item:IsA("Tool") then
					table.insert(tools, item)
				end
			end
		end
		return tools
	end

	local function isToolTracked(tool)
		for _, slot in ipairs(hotbarFolder:GetChildren()) do
			if slot.Value == tool then return true end
		end
		for _, slot in ipairs(backpackFolder:GetChildren()) do
			if slot.Value == tool then return true end
		end
		return false
	end

	local function updatePlayerTools()
		local currentTools = getAllPlayerTools()
		local currentToolsMap = {}
		for _, tool in ipairs(currentTools) do
			currentToolsMap[tool] = true
		end

		-- ลบ ObjectValue ที่ Tool หายไปแล้ว
		for _, slot in ipairs(hotbarFolder:GetChildren()) do
			if slot.Value and not currentToolsMap[slot.Value] then
				slot.Value = nil
			end
		end
		for _, slot in ipairs(backpackFolder:GetChildren()) do
			if not slot.Value or not currentToolsMap[slot.Value] then
				slot:Destroy()
			end
		end

		-- เพิ่ม Tool ใหม่เข้าช่องว่างใน Hotbar ก่อน ถ้าเต็มให้เข้า Backpack
		for _, tool in ipairs(currentTools) do
			if not isToolTracked(tool) then
				local placedInHotbar = false
				for i = 1, hotbarSlots do
					local slot = hotbarFolder:FindFirstChild(tostring(i))
					if slot and slot.Value == nil then
						slot.Value = tool
						placedInHotbar = true
						break
					end
				end

				if not placedInHotbar then
					local newSlot = Instance.new("ObjectValue")
					newSlot.Name = tool.Name
					newSlot.Value = tool
					newSlot.Parent = backpackFolder
				end
			end
		end
	end

	local function onCharacterAdded(character)
		-- รีเซ็ตช่องเมื่อเกิดใหม่
		for _, slot in ipairs(hotbarFolder:GetChildren()) do
			slot.Value = nil
		end
		backpackFolder:ClearAllChildren()

		local backpack = player:WaitForChild("Backpack")
		backpack.ChildAdded:Connect(updatePlayerTools)
		backpack.ChildRemoved:Connect(updatePlayerTools)
		character.ChildAdded:Connect(updatePlayerTools)
		character.ChildRemoved:Connect(updatePlayerTools)

		task.wait(0.1)
		updatePlayerTools()
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- 3. รับคำสั่งจาก Client ผ่าน RemoteEvents
remoteEvents:WaitForChild("EquipTool").OnServerEvent:Connect(function(player, tool)
	if not tool or not tool:IsA("Tool") then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and tool.Parent == player:FindFirstChildOfClass("Backpack") then
		humanoid:EquipTool(tool)
	end
end)

remoteEvents:WaitForChild("UnequipTool").OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end)

remoteEvents:WaitForChild("DropTool").OnServerEvent:Connect(function(player, tool)
	if not tool or not tool:IsA("Tool") then return end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and (tool.Parent == character or tool.Parent == player:FindFirstChildOfClass("Backpack")) then
		tool.Parent = workspace
		if tool:FindFirstChild("Handle") then
			tool.Handle.CFrame = rootPart.CFrame * CFrame.new(0, 0, -4)
		end
	end
end)

remoteEvents:WaitForChild("SwapSlots").OnServerEvent:Connect(function(player, slot1, slot2)
	if not slot1 or not slot2 then return end
	local invFolder = player:FindFirstChild(invFolderName)
	if not invFolder then return end

	if slot1:IsDescendantOf(invFolder) and slot2:IsDescendantOf(invFolder) then
		local temp = slot1.Value
		slot1.Value = slot2.Value
		slot2.Value = temp

		-- ลบ ObjectValue ใน Backpack ถ้าค่าว่างเปล่าหลังสลับ
		local backpackFolder = invFolder:FindFirstChild(backpackFolderName)
		if slot1.Parent == backpackFolder and slot1.Value == nil then
			slot1:Destroy()
		end
		if slot2.Parent == backpackFolder and slot2.Value == nil then
			slot2:Destroy()
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	createInventoryFolder(player)
	trackPlayerTools(player)
end)
