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
PetConfig.BreedCooldownSeconds = 900 -- 15 นาทีต่อการผสมพันธุ์ 1 ครั้ง
PetConfig.DefaultMaxPetCapacity = 20
PetConfig.DefaultMaxEquippedCombat = 3

PetConfig.FunctionalPlotObjects = {
	pet_incubator = "Incubator",
	breeding_pen = "Breeding",
} :: { [string]: "Incubator" | "Breeding" }

PetConfig.Foods = {
	berry_feed = { HungerRestore = 25, GrowthExp = 40 },
	golden_apple = { HungerRestore = 60, GrowthExp = 120 },
	evo_crystal = { HungerRestore = 100, GrowthExp = 300, IsEvolutionCatalyst = true },
} :: { [string]: FoodDefinition }

PetConfig.Eggs = {
	forest_egg = {
		HatchTimeSeconds = 180,
		Pool = {
			{ SpeciesId = "sprout_slime", Weight = 75 },
			{ SpeciesId = "moss_wolf", Weight = 25 },
		},
	},
	mystic_forest_egg = {
		HatchTimeSeconds = 420,
		Pool = {
			{ SpeciesId = "moss_wolf", Weight = 60 },
			{ SpeciesId = "ancient_treant", Weight = 40 },
		},
	},
} :: { [string]: EggDefinition }

PetConfig.Species = {
	sprout_slime = {
		DisplayName = "Sprout Slime",
		Rarity = "Common",
		BaseHP = 120,
		BaseATK = 15,
		AttackCooldown = 1.8,
		AttackRange = 14,
		WalkSpeed = 12,
		FavoriteFood = "berry_feed",
		StageThresholds = { Juvenile = 100, Adult = 350, Evolved = 800 },
		EvolutionTarget = "flora_guardian",
		EvolutionItem = "evo_crystal",
		ModelByStage = {
			Baby = "sprout_slime_Baby",
			Juvenile = "sprout_slime_Adult",
			Adult = "sprout_slime_Adult",
			Evolved = "flora_guardian_Evolved",
		},
	},
	moss_wolf = {
		DisplayName = "Moss Wolf",
		Rarity = "Rare",
		BaseHP = 210,
		BaseATK = 28,
		AttackCooldown = 1.5,
		AttackRange = 16,
		WalkSpeed = 16,
		FavoriteFood = "golden_apple",
		StageThresholds = { Juvenile = 150, Adult = 450, Evolved = 1000 },
		EvolutionTarget = "ancient_treant",
		EvolutionItem = "evo_crystal",
		ModelByStage = {
			Baby = "moss_wolf_Baby",
			Juvenile = "moss_wolf_Adult",
			Adult = "moss_wolf_Adult",
			Evolved = "ancient_treant_Evolved",
		},
	},
	flora_guardian = {
		DisplayName = "Flora Guardian",
		Rarity = "Epic",
		BaseHP = 380,
		BaseATK = 48,
		AttackCooldown = 1.4,
		AttackRange = 18,
		WalkSpeed = 16,
		FavoriteFood = "golden_apple",
		StageThresholds = { Juvenile = 0, Adult = 0, Evolved = 0 },
		EvolutionTarget = nil,
		EvolutionItem = nil,
		ModelByStage = {
			Baby = "flora_guardian_Evolved",
			Juvenile = "flora_guardian_Evolved",
			Adult = "flora_guardian_Evolved",
			Evolved = "flora_guardian_Evolved",
		},
	},
	ancient_treant = {
		DisplayName = "Ancient Treant",
		Rarity = "Legendary",
		BaseHP = 560,
		BaseATK = 64,
		AttackCooldown = 1.6,
		AttackRange = 20,
		WalkSpeed = 14,
		FavoriteFood = "golden_apple",
		StageThresholds = { Juvenile = 0, Adult = 0, Evolved = 0 },
		EvolutionTarget = nil,
		EvolutionItem = nil,
		ModelByStage = {
			Baby = "ancient_treant_Evolved",
			Juvenile = "ancient_treant_Evolved",
			Adult = "ancient_treant_Evolved",
			Evolved = "ancient_treant_Evolved",
		},
	},
} :: { [string]: SpeciesDefinition }

-- ตารางจับคู่ผสมพันธุ์ (เรียงชื่อ SpeciesId ตามตัวอักษรคั่นด้วย '|')
PetConfig.BreedingRecipes = {
	["sprout_slime|sprout_slime"] = {
		DurationSeconds = 300,
		Outcomes = {
			{ EggItemId = "forest_egg", Weight = 80 },
			{ EggItemId = "mystic_forest_egg", Weight = 20 },
		},
	},
	["moss_wolf|sprout_slime"] = {
		DurationSeconds = 360,
		Outcomes = {
			{ EggItemId = "forest_egg", Weight = 50 },
			{ EggItemId = "mystic_forest_egg", Weight = 50 },
		},
	},
	["moss_wolf|moss_wolf"] = {
		DurationSeconds = 420,
		Outcomes = {
			{ EggItemId = "mystic_forest_egg", Weight = 100 },
		},
	},
	["flora_guardian|flora_guardian"] = {
		DurationSeconds = 480,
		Outcomes = {
			{ EggItemId = "mystic_forest_egg", Weight = 100 },
		},
	},
	["flora_guardian|sprout_slime"] = {
		DurationSeconds = 360,
		Outcomes = {
			{ EggItemId = "forest_egg", Weight = 40 },
			{ EggItemId = "mystic_forest_egg", Weight = 60 },
		},
	},
	["ancient_treant|flora_guardian"] = {
		DurationSeconds = 540,
		Outcomes = {
			{ EggItemId = "mystic_forest_egg", Weight = 100 },
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
