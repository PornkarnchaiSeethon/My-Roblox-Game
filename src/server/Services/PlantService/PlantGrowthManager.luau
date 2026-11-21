--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local PlantGrowthManager = {}

function PlantGrowthManager.PlantSeed(
	player: Player,
	plantsData: any,
	objectId: string,
	planterType: string,
	seedItemId: string,
	inventoryService: any
): (boolean, string)
	local cropDef = PlantConfig.Crops[seedItemId]
	if not cropDef then
		return false, "ไอเทมที่เลือกไม่ใช่เมล็ดพันธุ์พืช"
	end
	if not PlantConfig.Planters[planterType] then
		return false, "วัตถุนี้ไม่รองรับการเพาะปลูก"
	end
	if plantsData.Planters[objectId] ~= nil then
		return false, "กระบะปลูกนี้มีพืชกำลังเติบโตอยู่แล้ว"
	end

	local activeCount = 0
	for _ in plantsData.Planters do
		activeCount += 1
	end
	if activeCount >= (plantsData.MaxActivePlanters or 24) then
		return false, "จำนวนแปลงปลูกที่ใช้งานพร้อมกันเต็มพิกัดแล้ว"
	end

	if not inventoryService.HasItem(player, seedItemId) then
		return false, "คุณไม่มีเมล็ดพันธุ์ชนิดนี้ในกระเป๋า"
	end
	if not inventoryService.ConsumeItem(player, seedItemId) then
		return false, "ไม่สามารถหักเมล็ดพันธุ์ออกจากกระเป๋าได้"
	end

	local now = os.time()
	plantsData.Planters[objectId] = {
		ObjectId = objectId,
		PlanterType = planterType,
		CropId = seedItemId,
		Stage = "Seed",
		GrowthProgress = 0,
		PlantedAt = now,
		LastSimulatedAt = now,
		MoistureUntil = now + math.floor(cropDef.MoistureDurationSeconds * 0.5),
		FertilizerId = "",
		HarvestsRemaining = cropDef.MaxHarvestCycles,
	}
	return true, "ปลูก " .. cropDef.DisplayName .. " สำเร็จ!"
end

function PlantGrowthManager.WaterPlant(
	player: Player,
	planterData: any,
	inventoryService: any
): (boolean, string)
	if not planterData then
		return false, "ยังไม่มีพืชในกระบะปลูกนี้"
	end
	if not inventoryService.HasItem(player, "watering_can") then
		return false, "ต้องมีบัวรดน้ำ (Watering Can) อยู่ในกระเป๋า"
	end

	local cropDef = PlantConfig.Crops[planterData.CropId]
	local planterDef = PlantConfig.Planters[planterData.PlanterType]
	if not cropDef or not planterDef then
		return false, "ข้อมูลแปลงปลูกไม่ถูกต้อง"
	end

	local duration = math.floor(cropDef.MoistureDurationSeconds * planterDef.MoistureRetentionMultiplier)
	planterData.MoistureUntil = os.time() + duration
	return true, "รดน้ำแปลงปลูกเรียบร้อย ดินชุ่มชื้นเต็มที่!"
end

function PlantGrowthManager.ApplyFertilizer(
	player: Player,
	planterData: any,
	fertilizerItemId: string,
	inventoryService: any
): (boolean, string)
	if not planterData then
		return false, "ยังไม่มีพืชในกระบะปลูกนี้"
	end
	if planterData.Stage == "Mature" then
		return false, "พืชโตเต็มวัยพร้อมเก็บเกี่ยวแล้ว ไม่จำเป็นต้องใส่ปุ๋ย"
	end
	if (planterData.FertilizerId or "") ~= "" then
		return false, "แปลงนี้ได้รับปุ๋ยบำรุงไปแล้วในรอบนี้"
	end

	local fertDef = PlantConfig.Fertilizers[fertilizerItemId]
	if not fertDef then
		return false, "ไอเทมนี้ไม่ใช่ปุ๋ยสำหรับการเกษตร"
	end
	if not inventoryService.HasItem(player, fertilizerItemId) then
		return false, "ไม่พบปุ๋ยชนิดนี้ในกระเป๋า"
	end
	if not inventoryService.ConsumeItem(player, fertilizerItemId) then
		return false, "ไม่พบปุ๋ยชนิดนี้ในกระเป๋า"
	end

	planterData.FertilizerId = fertilizerItemId
	return true, "ใส่ " .. fertDef.DisplayName .. " สำเร็จ!"
end

function PlantGrowthManager.StepPlanterGrowth(
	planterData: any,
	now: number,
	hasSprinklerNearby: boolean,
	hasNaturePetAura: boolean
): (boolean, boolean)
	local cropDef = PlantConfig.Crops[planterData.CropId]
	local planterDef = PlantConfig.Planters[planterData.PlanterType]
	if not cropDef or not planterDef then
		return false, false
	end

	local elapsed = math.max(0, now - (planterData.LastSimulatedAt or now))
	planterData.LastSimulatedAt = now
	if elapsed <= 0 or planterData.Stage == "Mature" then
		if hasSprinklerNearby and (planterData.MoistureUntil or 0) < (now + 30) then
			planterData.MoistureUntil = now + cropDef.MoistureDurationSeconds
			return true, false
		end
		return false, false
	end

	if hasSprinklerNearby then
		planterData.MoistureUntil = math.max(planterData.MoistureUntil or 0, now + cropDef.MoistureDurationSeconds)
	end

	-- คำนวณเวลาช่วงที่ดินชุ่มชื้นเทียบกับช่วงที่ดินแห้ง (รองรับการคำนวณ Offline Catch-up อย่างแม่นยำ)
	local prevTime = now - elapsed
	local wetSeconds = math.clamp((planterData.MoistureUntil or 0) - prevTime, 0, elapsed)
	local drySeconds = elapsed - wetSeconds

	local speedMult = planterDef.GrowthSpeedMultiplier
	if (planterData.FertilizerId or "") ~= "" then
		local fertDef = PlantConfig.Fertilizers[planterData.FertilizerId]
		if fertDef then
			speedMult += fertDef.GrowthSpeedBonus
		end
	end
	if hasNaturePetAura then
		speedMult += PlantConfig.NaturePetAuraBonus
	end

	local effectiveSeconds = (wetSeconds * speedMult) + (drySeconds * speedMult * cropDef.DrySpeedMultiplier)
	local progressDelta = effectiveSeconds / math.max(1, cropDef.GrowthDurationSeconds)
	local oldStage = planterData.Stage

	planterData.GrowthProgress = math.clamp((planterData.GrowthProgress or 0) + progressDelta, 0, 1.0)
	planterData.Stage = PlantConfig.GetStageFromProgress(planterData.GrowthProgress)

	local becameMature = (oldStage ~= "Mature" and planterData.Stage == "Mature")
	return (oldStage ~= planterData.Stage or progressDelta > 0), becameMature
end

function PlantGrowthManager.HarvestCrop(
	player: Player,
	profileData: any,
	objectId: string,
	inventoryService: any
): (boolean, string, number)
	local plantsData = profileData.Plants
	if type(plantsData) ~= "table" or type(plantsData.Planters) ~= "table" then
		return false, "ไม่มีพืชให้เก็บเกี่ยวในแปลงนี้", 0
	end

	local planterData = plantsData.Planters[objectId]
	if not planterData then
		return false, "ไม่มีพืชให้เก็บเกี่ยวในแปลงนี้", 0
	end
	if planterData.Stage ~= "Mature" or (planterData.GrowthProgress or 0) < 1.0 then
		return false, "พืชยังเติบโตไม่เต็มที่ กรุณารอจนกว่าจะสุกงอม", 0
	end

	local cropDef = PlantConfig.Crops[planterData.CropId]
	if not cropDef then
		return false, "ไม่พบข้อมูลผลผลิตของพืชชนิดนี้", 0
	end

	local yieldCount = math.random(cropDef.BaseYieldMin, cropDef.BaseYieldMax)
	if (planterData.FertilizerId or "") ~= "" then
		local fertDef = PlantConfig.Fertilizers[planterData.FertilizerId]
		if fertDef then
			yieldCount += math.random(fertDef.BonusYieldMin, fertDef.BonusYieldMax)
		end
	end

	-- มอบไอเทมเข้ากระเป๋าทีละชิ้น หากกระเป๋าเต็มตั้งแต่ชิ้นแรกจะยกเลิกธุรกรรมและไม่ลบต้นไม้
	local granted = 0
	for _ = 1, yieldCount do
		if inventoryService.GiveItem(player, cropDef.HarvestItemId) then
			granted += 1
		else
			break
		end
	end

	if granted == 0 then
		return false, "กระเป๋าสัมภาระเต็ม (สูงสุด 20 กอง) กรุณาจัดกระเป๋าก่อนเก็บเกี่ยว", 0
	end

	-- อัปเดตสถิติ HarvestStats, Cash และ EXP อย่างปลอดภัย (ป้องกัน Division by Zero)
	if type(plantsData.HarvestStats) ~= "table" then
		plantsData.HarvestStats = {}
	end
	plantsData.HarvestStats[cropDef.SeedId] = (plantsData.HarvestStats[cropDef.SeedId] or 0) + granted
	profileData.Cash = (profileData.Cash or 0) + cropDef.CashReward
	profileData.CurrentLevel = math.max(1, profileData.CurrentLevel or 1)
	profileData.ExpForNextLevel = math.max(100, profileData.ExpForNextLevel or 100)
	profileData.CurrentExp = (profileData.CurrentExp or 0) + cropDef.ExpReward

	while profileData.CurrentExp >= profileData.ExpForNextLevel do
		profileData.CurrentExp -= profileData.ExpForNextLevel
		profileData.CurrentLevel += 1
		profileData.ExpForNextLevel = math.max(100, math.floor(100 * (1.25 ^ (profileData.CurrentLevel - 1))))
	end

	planterData.HarvestsRemaining = (planterData.HarvestsRemaining or 1) - 1
	if planterData.HarvestsRemaining > 0 then
		planterData.GrowthProgress = cropDef.RegrowProgressAfterHarvest
		planterData.Stage = PlantConfig.GetStageFromProgress(planterData.GrowthProgress)
		planterData.FertilizerId = ""
		planterData.LastSimulatedAt = os.time()
	else
		plantsData.Planters[objectId] = nil
	end

	local partialNote = if granted < yieldCount then " (กระเป๋าเต็มบางส่วน)" else ""
	return true, string.format("เก็บเกี่ยวสำเร็จ! ได้รับ %s x%d%s", cropDef.DisplayName, granted, partialNote), granted
end

return PlantGrowthManager
