--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local PetGrowthManager = {}

function PetGrowthManager.ApplyHungerDecay(petData: any, now: number): boolean
	if petData.State == "Stored" or petData.State == "Breeding" then
		return false
	end

	local lastRef = petData.LastFedAt or 0
	if lastRef <= 0 then
		petData.LastFedAt = now
		return false
	end

	local elapsedMinutes = math.floor((now - lastRef) / 60)
	if elapsedMinutes <= 0 then
		return false
	end

	local decay = elapsedMinutes * PetConfig.HungerDecayPerMinute
	local prevHunger = petData.Hunger or PetConfig.MaxHunger
	local nextHunger = math.clamp(prevHunger - decay, 0, PetConfig.MaxHunger)
	if nextHunger ~= prevHunger then
		petData.Hunger = nextHunger
		petData.LastFedAt = lastRef + (elapsedMinutes * 60)
		return true
	end

	return false
end

function PetGrowthManager.FeedPet(
	player: Player,
	petData: any,
	foodItemId: string,
	inventoryService: any
): (boolean, string, boolean)
	local foodStats = PetConfig.Foods[foodItemId]
	if not foodStats then
		return false, "ไอเทมนี้ไม่ใช่อาหารสำหรับสัตว์เลี้ยง", false
	end

	local species = PetConfig.Species[petData.SpeciesId]
	if not species then
		return false, "ไม่พบข้อมูลสายพันธุ์สัตว์เลี้ยง", false
	end

	if petData.State == "Breeding" then
		return false, "ไม่สามารถให้อาหารขณะสัตว์เลี้ยงกำลังผสมพันธุ์", false
	end

	if not inventoryService.HasItem(player, foodItemId) then
		return false, "คุณไม่มีอาหารชนิดนี้ในกระเป๋า", false
	end

	local consumed = inventoryService.ConsumeItem(player, foodItemId)
	if not consumed then
		return false, "ไม่สามารถหักไอเทมอาหารได้", false
	end

	-- โบนัส EXP 1.25 เท่าหากเป็นอาหารโปรดของสายพันธุ์นั้น
	local isFavorite = species.FavoriteFood == foodItemId
	local expMultiplier = if isFavorite then 1.25 else 1.0
	local gainedExp = math.floor(foodStats.GrowthExp * expMultiplier)

	local oldStage = petData.Stage
	petData.Hunger = math.clamp((petData.Hunger or 0) + foodStats.HungerRestore, 0, PetConfig.MaxHunger)
	petData.GrowthExp = (petData.GrowthExp or 0) + gainedExp
	petData.LastFedAt = os.time()
	petData.Level = math.clamp(1 + math.floor(math.sqrt(petData.GrowthExp / 25)), 1, 100)

	-- อัปเดต Stage อัตโนมัติ (ยกเว้นขั้น Evolved ที่ต้องกดยืนยันหรือใช้ Catalyst)
	if petData.Stage == "Baby" and petData.GrowthExp >= species.StageThresholds.Juvenile then
		petData.Stage = "Juvenile"
	end
	if petData.Stage == "Juvenile" and petData.GrowthExp >= species.StageThresholds.Adult then
		petData.Stage = "Adult"
	end

	local stageChanged = oldStage ~= petData.Stage
	local msg = if isFavorite
		then `ให้อาหารโปรดสำเร็จ! (+{gainedExp} Growth EXP)`
		else `ให้อาหารสำเร็จ (+{gainedExp} Growth EXP)`

	return true, msg, stageChanged
end

function PetGrowthManager.TryEvolve(
	player: Player,
	petData: any,
	catalystItemId: string?,
	inventoryService: any
): (boolean, string)
	if petData.State == "Breeding" then
		return false, "ไม่สามารถวิวัฒนาการขณะสัตว์เลี้ยงกำลังผสมพันธุ์"
	end

	local species = PetConfig.Species[petData.SpeciesId]
	if not species or not species.EvolutionTarget then
		return false, "สัตว์เลี้ยงสายพันธุ์นี้ไม่สามารถวิวัฒนาการต่อได้"
	end

	local targetSpecies = PetConfig.Species[species.EvolutionTarget]
	if not targetSpecies then
		return false, "ไม่พบข้อมูลสายพันธุ์เป้าหมายสำหรับวิวัฒนาการ"
	end

	if petData.Stage ~= "Adult" or (petData.GrowthExp or 0) < species.StageThresholds.Evolved then
		return false, "สัตว์เลี้ยงยังมีค่าการเติบโตไม่ถึงเกณฑ์วิวัฒนาการ"
	end

	if species.EvolutionItem then
		local requiredItem = species.EvolutionItem
		if catalystItemId ~= nil and catalystItemId ~= requiredItem then
			return false, "ไอเทมกระตุ้นการวิวัฒนาการไม่ถูกต้อง"
		end
		if not inventoryService.HasItem(player, requiredItem) or not inventoryService.ConsumeItem(player, requiredItem) then
			return false, "ต้องใช้ไอเทมกระตุ้นการวิวัฒนาการที่กำหนด"
		end
	end

	if petData.Nickname == species.DisplayName then
		petData.Nickname = targetSpecies.DisplayName
	end

	petData.SpeciesId = species.EvolutionTarget
	petData.Stage = "Evolved"
	petData.PotentialBonus = math.clamp(math.round(((petData.PotentialBonus or 1.0) + 0.05) * 100) / 100, 1.0, 1.35)
	return true, `วิวัฒนาการเป็น {targetSpecies.DisplayName} สำเร็จ!`
end

return PetGrowthManager
