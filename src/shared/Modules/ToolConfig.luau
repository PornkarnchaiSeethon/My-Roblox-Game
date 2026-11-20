export type ToolData = {
	DisplayName: string?,
	ItemType: string?,
	MaxStack: number?,
	Description: string?,
	Image: string?,
	IsDroppable: boolean?,
}

local ToolConfig = {}

ToolConfig.MaxStackByType = {
	Weapon = 1,
	Armor = 1,
	Special = 1,
	Consumable = 5,
	Resource = 10,
}

-- Add tool-specific data here. The key must match the Tool.Name.
ToolConfig.Items = {
	berry_feed = {
		DisplayName = "Berry Feed",
		ItemType = "Consumable",
		MaxStack = 32,
		Description = "อาหารผลไม้สำหรับสัตว์เลี้ยงในฟาร์ม เพิ่มความอิ่มและค่าเติบโต",
		Image = "rbxassetid://1010101001",
		IsDroppable = true,
	},
	golden_apple = {
		DisplayName = "Golden Apple",
		ItemType = "Consumable",
		MaxStack = 16,
		Description = "แอปเปิ้ลทองคำชั้นเลิศ เพิ่มความอิ่มและค่าเติบโตจำนวนมาก",
		Image = "rbxassetid://1010101007",
		IsDroppable = true,
	},
	evo_crystal = {
		DisplayName = "Evolution Crystal",
		ItemType = "Special",
		MaxStack = 10,
		Description = "คริสตัลกระตุ้นการวิวัฒนาการเมื่อสัตว์เลี้ยงโตเต็มวัย",
		Image = "rbxassetid://1010101002",
		IsDroppable = false,
	},
	forest_egg = {
		DisplayName = "Forest Pet Egg",
		ItemType = "Special",
		MaxStack = 5,
		Description = "ไข่สัตว์เลี้ยงป่า นำไปฟักที่เครื่องฟักไข่ใน Plot",
		Image = "rbxassetid://1010101003",
		IsDroppable = false,
	},
	mystic_forest_egg = {
		DisplayName = "Mystic Forest Egg",
		ItemType = "Special",
		MaxStack = 5,
		Description = "ไข่สายพันธุ์หายากจากการผสมพันธุ์ในฟาร์ม",
		Image = "rbxassetid://1010101004",
		IsDroppable = false,
	},
	pet_incubator = {
		DisplayName = "Egg Incubator",
		ItemType = "Special",
		MaxStack = 3,
		Description = "วางใน Plot เพื่อใช้ฟักไข่สัตว์เลี้ยง",
		Image = "rbxassetid://1010101005",
		IsDroppable = false,
	},
	breeding_pen = {
		DisplayName = "Breeding Pen",
		ItemType = "Special",
		MaxStack = 2,
		Description = "วางใน Plot เพื่อผสมพันธุ์สัตว์เลี้ยงโตเต็มวัย 2 ตัว",
		Image = "rbxassetid://1010101006",
		IsDroppable = false,
	},
}

local function getToolName(toolOrName: Tool | string): string
	if typeof(toolOrName) == "Instance" then
		return toolOrName.Name
	end
	return toolOrName
end

function ToolConfig.Get(toolOrName: Tool | string): ToolData
	local toolName = getToolName(toolOrName)
	local configured = ToolConfig.Items[toolName] or {}
	local tool = if typeof(toolOrName) == "Instance" and toolOrName:IsA("Tool")
		then toolOrName
		else nil

	local itemType = configured.ItemType
	if not itemType and tool then
		itemType = tool:GetAttribute("ItemType")
	end
	itemType = itemType or "Resource"

	local description = configured.Description
	if description == nil and tool then
		description = tool.ToolTip
	end

	local image = configured.Image
	if image == nil and tool then
		image = tool.TextureId
	end

	local isDroppable = configured.IsDroppable
	if isDroppable == nil then
		isDroppable = if tool then tool:GetAttribute("IsDroppable") ~= false else true
	end

	local maxStack = configured.MaxStack or ToolConfig.MaxStackByType[itemType] or 1
	local displayName = configured.DisplayName or if tool then tool.Name else toolName

	return {
		DisplayName = displayName,
		ItemType = itemType,
		MaxStack = math.max(1, math.floor(maxStack)),
		Description = description or "",
		Image = image or "",
		IsDroppable = isDroppable,
	}
end

return ToolConfig
