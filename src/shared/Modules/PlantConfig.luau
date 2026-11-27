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
PlantConfig.NaturePetAuraBonus = 0.10

PlantConfig.Planters = {
	wooden_planter = {
		DisplayName = "Wooden Planter",
		GrowthSpeedMultiplier = 1.0,
		MoistureRetentionMultiplier = 1.0,
	},
} :: { [string]: PlanterDefinition }

PlantConfig.Fertilizers = {
	compost_fertilizer = {
		DisplayName = "Compost Fertilizer",
		GrowthSpeedBonus = 0.35,
		BonusYieldMin = 0,
		BonusYieldMax = 1,
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
