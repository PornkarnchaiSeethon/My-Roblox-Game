export type ToolData = {
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
	-- Example:
	-- Wood = {
	-- 	ItemType = "Resource",
	-- 	MaxStack = 10,
	-- 	Description = "Basic building material",
	-- 	Image = "rbxassetid://0000000000",
	-- 	IsDroppable = true,
	-- },
}

local function getToolName(toolOrName: Tool | string): string
	if typeof(toolOrName) == "Instance" then
		return toolOrName.Name
	end
	return toolOrName
end

function ToolConfig.Get(toolOrName: Tool | string): ToolData
	local configured = ToolConfig.Items[getToolName(toolOrName)] or {}
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

	return {
		ItemType = itemType,
		MaxStack = math.max(1, math.floor(maxStack)),
		Description = description or "",
		Image = image or "",
		IsDroppable = isDroppable,
	}
end

return ToolConfig
