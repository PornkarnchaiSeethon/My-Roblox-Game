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
	wooden_planter = {
		DisplayName = "Wooden Planter",
		ItemType = "Special",
		MaxStack = 10,
		Description = "กระบะปลูกผักไม้มาตรฐาน วางใน Plot เพื่อเริ่มเพาะปลูก",
		Image = "rbxassetid://1020202001",
		IsDroppable = false,
	},
	fertile_garden_bed = {
		DisplayName = "Fertile Garden Bed",
		ItemType = "Special",
		MaxStack = 5,
		Description = "แปลงดินอุดมสมบูรณ์ เร่งความเร็วการเติบโตของพืช 20% และเก็บความชื้นนานขึ้น",
		Image = "rbxassetid://1020202002",
		IsDroppable = false,
	},
	hydro_sprinkler = {
		DisplayName = "Hydro Sprinkler",
		ItemType = "Special",
		MaxStack = 3,
		Description = "สปริงเกลอร์รดน้ำอัตโนมัติให้กระบะปลูกในรัศมี 12 Studs",
		Image = "rbxassetid://1020202003",
		IsDroppable = false,
	},
	watering_can = {
		DisplayName = "Watering Can",
		ItemType = "Special",
		MaxStack = 1,
		Description = "บัวรดน้ำประจำฟาร์ม ใช้รดน้ำเพิ่มความชุ่มชื้นให้แปลงผัก",
		Image = "rbxassetid://1020202004",
		IsDroppable = false,
	},
	compost_fertilizer = {
		DisplayName = "Compost Fertilizer",
		ItemType = "Consumable",
		MaxStack = 20,
		Description = "ปุ๋ยหมักอินทรีย์ เร่งความเร็วการเติบโตของพืช 35%",
		Image = "rbxassetid://1020202005",
		IsDroppable = true,
	},
	mystic_fertilizer = {
		DisplayName = "Mystic Fertilizer",
		ItemType = "Consumable",
		MaxStack = 10,
		Description = "ปุ๋ยเวทมนตร์ เพิ่มจำนวนผลผลิตตอนเก็บเกี่ยว +1 ถึง +2 ชิ้น",
		Image = "rbxassetid://1020202006",
		IsDroppable = false,
	},
	carrot_seed = {
		DisplayName = "Carrot Seed",
		ItemType = "Resource",
		MaxStack = 32,
		Description = "เมล็ดแครอท โตไว เหมาะสำหรับผู้เริ่มต้นทำฟาร์ม",
		Image = "rbxassetid://1020202007",
		IsDroppable = true,
	},
	berry_seed = {
		DisplayName = "Forest Berry Seed",
		ItemType = "Resource",
		MaxStack = 32,
		Description = "เมล็ดเบอร์รี่ป่า เก็บเกี่ยวซ้ำได้ 3 รอบ ให้ผลผลิตเป็น Berry Feed สำหรับสัตว์เลี้ยง",
		Image = "rbxassetid://1020202008",
		IsDroppable = true,
	},
	moon_herb_seed = {
		DisplayName = "Moonlight Herb Seed",
		ItemType = "Resource",
		MaxStack = 20,
		Description = "เมล็ดสมุนไพรจันทรา วัตถุดิบสำคัญสำหรับปรุงโพชัน",
		Image = "rbxassetid://1020202009",
		IsDroppable = true,
	},
	golden_apple_seed = {
		DisplayName = "Golden Apple Seed",
		ItemType = "Special",
		MaxStack = 10,
		Description = "เมล็ดแอปเปิลทองคำหายาก เก็บเกี่ยวซ้ำได้ 2 รอบ",
		Image = "rbxassetid://1020202010",
		IsDroppable = false,
	},
	fresh_carrot = {
		DisplayName = "Fresh Carrot",
		ItemType = "Consumable",
		MaxStack = 20,
		Description = "แครอทสดกรอบจากแปลงผัก ใช้ฟื้นฟูพลังงานหรือขายรับเงิน",
		Image = "rbxassetid://1020202011",
		IsDroppable = true,
	},
	moon_herb = {
		DisplayName = "Moonlight Herb",
		ItemType = "Resource",
		MaxStack = 32,
		Description = "สมุนไพรเรืองแสงจากฟาร์ม ใช้เป็นส่วนผสมปรุงยาฟื้นฟู",
		Image = "rbxassetid://1020202012",
		IsDroppable = true,
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
