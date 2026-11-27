--!strict

export type PetStage = "Baby" | "Juvenile" | "Adult" | "Evolved"
export type PetRarity = "Common" | "Rare" | "Epic" | "Legendary"
export type PetState = "InPlot" | "Equipped" | "Breeding" | "Stored"

export type SpeciesDefinition = {
	DisplayName: string,
	Rarity: PetRarity,
	BaseHP: number,
	BaseATK: number,
	AttackCooldown: number,
	AttackRange: number,
	WalkSpeed: number,
	FavoriteFood: string,
	StageThresholds: { Juvenile: number, Adult: number, Evolved: number },
	EvolutionTarget: string?,
	EvolutionItem: string?,
	ModelByStage: { [PetStage]: string },
}

export type FoodDefinition = {
	HungerRestore: number,
	GrowthExp: number,
	IsEvolutionCatalyst: boolean?,
}

export type EggPoolEntry = {
	SpeciesId: string,
	Weight: number,
}

export type EggDefinition = {
	HatchTimeSeconds: number,
	Pool: { EggPoolEntry },
}

export type BreedingOutcome = {
	EggItemId: string,
	Weight: number,
}

export type BreedingRecipe = {
	DurationSeconds: number,
	Outcomes: { BreedingOutcome },
}

local PetConfig = {}

PetConfig.MaxHunger = 100
PetConfig.HungerDecayPerMinute = 2
PetConfig.BreedCooldownSeconds = 900
PetConfig.DefaultMaxPetCapacity = 20
PetConfig.DefaultMaxEquippedCombat = 3

PetConfig.FunctionalPlotObjects = {
	pet_incubator = "Incubator",
	breeding_pen = "Breeding",
} :: { [string]: "Incubator" | "Breeding" }

PetConfig.Foods = {
	berry_feed = { HungerRestore = 25, GrowthExp = 40 },
} :: { [string]: FoodDefinition }

PetConfig.Eggs = {
	forest_egg = {
		HatchTimeSeconds = 180,
		Pool = {
			{ SpeciesId = "sprout_slime", Weight = 100 },
		},
	},
} :: { [string]: EggDefinition }

PetConfig.Species = {
	simple_pet = {
		DisplayName = "Simple Pet",
		Rarity = "Common",
		BaseHP = 120,
		BaseATK = 15,
		AttackCooldown = 1.8,
		AttackRange = 14,
		WalkSpeed = 12,
		FavoriteFood = "berry_feed",
		StageThresholds = { Juvenile = 100, Adult = 350, Evolved = 800 },
		EvolutionTarget = nil,
		EvolutionItem = nil,
		ModelByStage = {
			Baby = "simple_pet",
			Juvenile = "sprout_slime_Adult",
			Adult = "sprout_slime_Adult",
			Evolved = "sprout_slime_Adult",
		},
	},
} :: { [string]: SpeciesDefinition }

PetConfig.BreedingRecipes = {
	["sprout_slime|sprout_slime"] = {
		DurationSeconds = 300,
		Outcomes = {
			{ EggItemId = "forest_egg", Weight = 100 },
		},
	},
} :: { [string]: BreedingRecipe }

function PetConfig.GetBreedingKey(speciesA: string, speciesB: string): string
	if speciesA <= speciesB then
		return speciesA .. "|" .. speciesB
	end
	return speciesB .. "|" .. speciesA
end

function PetConfig.CalculateStats(speciesId: string, level: number, potentialBonus: number): (number, number)
	local species = PetConfig.Species[speciesId]
	if not species then
		return 0, 0
	end
	local scale = (1 + (math.max(1, level) - 1) * 0.08) * math.max(1, potentialBonus)
	return math.floor(species.BaseHP * scale), math.floor(species.BaseATK * scale)
end

return PetConfig
