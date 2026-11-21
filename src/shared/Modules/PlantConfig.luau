--!strict

export type PlantStage = "Seed" | "Sprout" | "Growing" | "Mature"

export type CropDefinition = {
	SeedId: string,
	DisplayName: string,
	HarvestItemId: string,
	Rarity: "Common" | "Rare" | "Epic",
	GrowthDurationSeconds: number,
	MoistureDurationSeconds: number,
	DrySpeedMultiplier: number,
	BaseYieldMin: number,
	BaseYieldMax: number,
	MaxHarvestCycles: number,
	RegrowProgressAfterHarvest: number,
	ExpReward: number,
	CashReward: number,
	StageModels: { [PlantStage]: string },
	PlaceholderColor: Color3,
}

export type PlanterDefinition = {
	DisplayName: string,
	GrowthSpeedMultiplier: number,
	MoistureRetentionMultiplier: number,
}

export type FertilizerDefinition = {
	DisplayName: string,
	GrowthSpeedBonus: number,
	BonusYieldMin: number,
	BonusYieldMax: number,
}

local PlantConfig = {}

PlantConfig.SprinklerRadiusStuds = 12
PlantConfig.InteractDistanceStuds = 24
PlantConfig.NaturePetAuraBonus = 0.10 -- +10% ความเร็วเติบโตเมื่อมี sprout_slime หรือ flora_guardian เดินใน Plot

PlantConfig.Planters = {
	wooden_planter = {
		DisplayName = "Wooden Planter",
		GrowthSpeedMultiplier = 1.0,
		MoistureRetentionMultiplier = 1.0,
	},
	fertile_garden_bed = {
		DisplayName = "Fertile Garden Bed",
		GrowthSpeedMultiplier = 1.20,
		MoistureRetentionMultiplier = 1.25,
	},
} :: { [string]: PlanterDefinition }

PlantConfig.Fertilizers = {
	compost_fertilizer = {
		DisplayName = "Compost Fertilizer",
		GrowthSpeedBonus = 0.35,
		BonusYieldMin = 0,
		BonusYieldMax = 1,
	},
	mystic_fertilizer = {
		DisplayName = "Mystic Fertilizer",
		GrowthSpeedBonus = 0.20,
		BonusYieldMin = 1,
		BonusYieldMax = 2,
	},
} :: { [string]: FertilizerDefinition }

PlantConfig.Crops = {
	carrot_seed = {
		SeedId = "carrot_seed",
		DisplayName = "Crunchy Carrot",
		HarvestItemId = "fresh_carrot",
		Rarity = "Common",
		GrowthDurationSeconds = 90,
		MoistureDurationSeconds = 60,
		DrySpeedMultiplier = 0.5,
		BaseYieldMin = 2,
		BaseYieldMax = 3,
		MaxHarvestCycles = 1,
		RegrowProgressAfterHarvest = 0,
		ExpReward = 15,
		CashReward = 10,
		StageModels = {
			Seed = "carrot_seed_Seed",
			Sprout = "carrot_seed_Sprout",
			Growing = "carrot_seed_Growing",
			Mature = "carrot_seed_Mature",
		},
		PlaceholderColor = Color3.fromRGB(255, 145, 40),
	},
	berry_seed = {
		SeedId = "berry_seed",
		DisplayName = "Forest Berry Bush",
		HarvestItemId = "berry_feed",
		Rarity = "Common",
		GrowthDurationSeconds = 150,
		MoistureDurationSeconds = 90,
		DrySpeedMultiplier = 0.5,
		BaseYieldMin = 2,
		BaseYieldMax = 4,
		MaxHarvestCycles = 3,
		RegrowProgressAfterHarvest = 0.45,
		ExpReward = 25,
		CashReward = 15,
		StageModels = {
			Seed = "carrot_seed_Seed",
			Sprout = "berry_seed_Sprout",
			Growing = "berry_seed_Growing",
			Mature = "berry_seed_Mature",
		},
		PlaceholderColor = Color3.fromRGB(220, 65, 95),
	},
	moon_herb_seed = {
		SeedId = "moon_herb_seed",
		DisplayName = "Moonlight Herb",
		HarvestItemId = "moon_herb",
		Rarity = "Rare",
		GrowthDurationSeconds = 240,
		MoistureDurationSeconds = 120,
		DrySpeedMultiplier = 0.4,
		BaseYieldMin = 1,
		BaseYieldMax = 3,
		MaxHarvestCycles = 1,
		RegrowProgressAfterHarvest = 0,
		ExpReward = 45,
		CashReward = 30,
		StageModels = {
			Seed = "carrot_seed_Seed",
			Sprout = "carrot_seed_Sprout",
			Growing = "carrot_seed_Growing",
			Mature = "moon_herb_seed_Mature",
		},
		PlaceholderColor = Color3.fromRGB(110, 195, 255),
	},
	golden_apple_seed = {
		SeedId = "golden_apple_seed",
		DisplayName = "Golden Apple Sapling",
		HarvestItemId = "golden_apple",
		Rarity = "Epic",
		GrowthDurationSeconds = 420,
		MoistureDurationSeconds = 180,
		DrySpeedMultiplier = 0.35,
		BaseYieldMin = 1,
		BaseYieldMax = 2,
		MaxHarvestCycles = 2,
		RegrowProgressAfterHarvest = 0.50,
		ExpReward = 90,
		CashReward = 65,
		StageModels = {
			Seed = "carrot_seed_Seed",
			Sprout = "berry_seed_Sprout",
			Growing = "berry_seed_Growing",
			Mature = "golden_apple_seed_Mature",
		},
		PlaceholderColor = Color3.fromRGB(255, 215, 60),
	},
} :: { [string]: CropDefinition }

function PlantConfig.GetStageFromProgress(progress: number): PlantStage
	if progress >= 1.0 then
		return "Mature"
	elseif progress >= 0.60 then
		return "Growing"
	elseif progress >= 0.25 then
		return "Sprout"
	end
	return "Seed"
end

function PlantConfig.IsFarmingObject(objectName: string): boolean
	return PlantConfig.Planters[objectName] ~= nil or objectName == "hydro_sprinkler"
end

return PlantConfig
