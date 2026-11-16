local PlotSpawnPool = {}

local available: { BasePart } = {}
local used: { [number]: BasePart } = {}
local initialized = false


local function initialize()
	if initialized then return end
	initialized = true

	local spawnFolder = workspace:FindFirstChild("PlotSpawns")
	if not spawnFolder then
		return
	end

	for _, instance in spawnFolder:GetChildren() do
		if instance:IsA("BasePart") then
			table.insert(available, instance)
		end
	end
end

-- ดึงจุดวาง Plot ที่ว่างอยู่ให้ผู้เล่น
function PlotSpawnPool.get(player: Player): BasePart
	initialize()

	local existing = used[player.UserId]
	if existing then
		return existing
	end

	local plotSpawn = table.remove(available)
	assert(plotSpawn, "ไม่มีพื้นที่ Plot ว่างเหลือสำหรับผู้เล่นใหม่ หรือไม่พบ Workspace.PlotSpawns")
	used[player.UserId] = plotSpawn
	return plotSpawn
end

-- คืนจุดวาง Plot กลับเข้ากองกลางเมื่อผู้เล่นออกจากเกม
function PlotSpawnPool.returnPlot(player: Player)
	local plotSpawn = used[player.UserId]
	if plotSpawn then
		used[player.UserId] = nil
		table.insert(available, plotSpawn)
	end
end

return PlotSpawnPool
