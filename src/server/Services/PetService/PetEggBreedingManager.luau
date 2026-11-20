--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local PetEggBreedingManager = {}

local function rollWeighted(pool: { { [string]: any } }, keyName: string): string
	local totalWeight = 0
	for _, entry in pool do
		totalWeight += entry.Weight
	end
	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in pool do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry[keyName]
		end
	end
	return pool[1][keyName]
end

function PetEggBreedingManager.StartIncubation(
	player: Player,
	petsProfile: any,
	objectId: string,
	eggItemId: string,
	inventoryService: any
): (boolean, string)
	local eggDef = PetConfig.Eggs[eggItemId]
	if not eggDef then
		return false, "ไอเทมที่เลือกไม่ใช่ไข่สัตว์เลี้ยง"
	end
	if petsProfile.Incubators[objectId] ~= nil then
		return false, "เครื่องฟักไข่นี้กำลังทำงานอยู่"
	end
	if not inventoryService.HasItem(player, eggItemId) or not inventoryService.ConsumeItem(player, eggItemId) then
		return false, "ไม่พบไข่สัตว์เลี้ยงในกระเป๋า"
	end

	local now = os.time()
	petsProfile.Incubators[objectId] = {
		EggItemId = eggItemId,
		StartedAt = now,
		HatchAt = now + eggDef.HatchTimeSeconds,
		InheritedBonus = math.round((1.0 + math.random() * 0.12) * 100) / 100,
	}
	return true, "เริ่มฟักไข่แล้ว"
end

function PetEggBreedingManager.ClaimHatchedPet(
	petsProfile: any,
	objectId: string
): (boolean, string, any?)
	local incData = petsProfile.Incubators[objectId]
	if not incData then
		return false, "ไม่มีไข่ในเครื่องฟักนี้", nil
	end
	if os.time() < incData.HatchAt then
		return false, "ไข่ยังฟักไม่เสร็จสมบูรณ์", nil
	end

	local currentCount = 0
	for _ in petsProfile.Instances do
		currentCount += 1
	end
	local maxCapacity = petsProfile.MaxPetCapacity or PetConfig.DefaultMaxPetCapacity
	if currentCount >= maxCapacity then
		return false, "ความจุสัตว์เลี้ยงในฟาร์มเต็มแล้ว", nil
	end

	local eggDef = PetConfig.Eggs[incData.EggItemId]
	if not eggDef or #eggDef.Pool == 0 then
		return false, "ไม่พบข้อมูลไข่สัตว์เลี้ยง", nil
	end

	local speciesId = rollWeighted(eggDef.Pool :: any, "SpeciesId")
	local speciesDef = PetConfig.Species[speciesId]
	if not speciesDef then
		return false, "ไม่พบข้อมูลสายพันธุ์จากไข่", nil
	end

	local newUID = HttpService:GenerateGUID(false)
	local newPet = {
		UID = newUID,
		SpeciesId = speciesId,
		Nickname = speciesDef.DisplayName,
		Stage = "Baby",
		Level = 1,
		GrowthExp = 0,
		Hunger = PetConfig.MaxHunger,
		PotentialBonus = incData.InheritedBonus or 1.0,
		State = "InPlot",
		LastFedAt = os.time(),
		BreedCooldownUntil = 0,
	}

	petsProfile.Instances[newUID] = newPet
	petsProfile.Incubators[objectId] = nil
	return true, "ฟักไข่สำเร็จ ได้รับ " .. speciesDef.DisplayName, newPet
end

function PetEggBreedingManager.StartBreeding(
	petsProfile: any,
	objectId: string,
	uidA: string,
	uidB: string
): (boolean, string)
	if uidA == uidB then
		return false, "ต้องเลือกสัตว์เลี้ยงคนละตัวกัน"
	end
	if petsProfile.BreedingPens[objectId] ~= nil then
		return false, "คอกผสมพันธุ์นี้กำลังใช้งานอยู่"
	end

	local petA = petsProfile.Instances[uidA]
	local petB = petsProfile.Instances[uidB]
	if not petA or not petB then
		return false, "ไม่พบข้อมูลสัตว์เลี้ยงที่เลือก"
	end

	local now = os.time()
	if (petA.Stage ~= "Adult" and petA.Stage ~= "Evolved") or (petB.Stage ~= "Adult" and petB.Stage ~= "Evolved") then
		return false, "สัตว์เลี้ยงทั้งสองตัวต้องโตเต็มวัยก่อนผสมพันธุ์"
	end
	if petA.State ~= "InPlot" or petB.State ~= "InPlot" then
		return false, "สัตว์เลี้ยงต้องอยู่ในฟาร์ม (ไม่ได้ออกรบหรือติดภารกิจอื่น)"
	end
	if now < (petA.BreedCooldownUntil or 0) or now < (petB.BreedCooldownUntil or 0) then
		return false, "สัตว์เลี้ยงยังอยู่ในช่วงพักฟื้นหลังผสมพันธุ์"
	end

	local recipeKey = PetConfig.GetBreedingKey(petA.SpeciesId, petB.SpeciesId)
	local recipe = PetConfig.BreedingRecipes[recipeKey]
	if not recipe then
		return false, "สายพันธุ์คู่นี้ไม่สามารถผสมพันธุ์กันได้"
	end

	local resultEgg = rollWeighted(recipe.Outcomes :: any, "EggItemId")
	local avgBonus = (((petA.PotentialBonus or 1.0) + (petB.PotentialBonus or 1.0)) / 2) + (math.random(0, 5) / 100)

	petA.State = "Breeding"
	petB.State = "Breeding"
	petsProfile.BreedingPens[objectId] = {
		ParentA_UID = uidA,
		ParentB_UID = uidB,
		StartedAt = now,
		FinishAt = now + recipe.DurationSeconds,
		ResultEggItemId = resultEgg,
		ResultBonus = math.clamp(math.round(avgBonus * 100) / 100, 1.0, 1.35),
	}
	return true, "เริ่มการผสมพันธุ์เรียบร้อยแล้ว"
end

function PetEggBreedingManager.ClaimBreedingEgg(
	player: Player,
	petsProfile: any,
	objectId: string,
	inventoryService: any
): (boolean, string)
	local pen = petsProfile.BreedingPens[objectId]
	if not pen then
		return false, "ไม่มีรายการผสมพันธุ์ในคอกนี้"
	end
	local now = os.time()
	if now < pen.FinishAt then
		return false, "การผสมพันธุ์ยังไม่เสร็จสมบูรณ์"
	end

	-- ตรวจสอบและส่งไข่เข้ากระเป๋าผ่าน InventoryService (ป้องกันไข่หายเมื่อกระเป๋าเต็ม)
	local given = inventoryService.GiveItem(player, pen.ResultEggItemId)
	if not given then
		return false, "กระเป๋าไอเทมเต็ม กรุณาเคลียร์ช่องว่างก่อนรับไข่"
	end

	local petA = petsProfile.Instances[pen.ParentA_UID]
	local petB = petsProfile.Instances[pen.ParentB_UID]
	if petA then
		petA.State = "InPlot"
		petA.BreedCooldownUntil = now + PetConfig.BreedCooldownSeconds
	end
	if petB then
		petB.State = "InPlot"
		petB.BreedCooldownUntil = now + PetConfig.BreedCooldownSeconds
	end

	petsProfile.BreedingPens[objectId] = nil
	return true, "ได้รับไข่สัตว์เลี้ยงเข้ากระเป๋าเรียบร้อยแล้ว!"
end

return PetEggBreedingManager
