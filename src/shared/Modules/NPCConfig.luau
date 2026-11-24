--!strict

local Types = require(script.Parent.Types)

local NPCConfig = {}

NPCConfig.AITickInterval = 0.15
NPCConfig.DefaultInteractDistance = 18
NPCConfig.PlayerBaseAttackCooldown = 0.55
NPCConfig.PlayerBaseFistDamage = 8
NPCConfig.PlayerBaseAttackRange = 9
NPCConfig.PlotSafeMarginStuds = 8
NPCConfig.BossBarMaxDistance = 95
NPCConfig.BossSyncRadius = 140
NPCConfig.RewardMaxDistance = 160
NPCConfig.MinContributionRatio = 0.03
NPCConfig.AttackJitterAllowance = 0.06

NPCConfig.Skills = {
	slime_acid_splash = {
		SkillId = "slime_acid_splash",
		DisplayName = "กรดพิษกระจาย (Acid Splash)",
		Shape = "Circle",
		TargetMode = "TargetPosition",
		CastRange = 22,
		Radius = 7.5,
		BoxSize = Vector3.zero,
		WindupTime = 1.15,
		ActiveDuration = 0.25,
		Cooldown = 7.0,
		Damage = 18,
		HealAmount = 0,
		MinHealthPercent = 0,
		MaxHealthPercent = 1.0,
		StatusEffect = {
			Type = "Slow",
			Magnitude = 0.25,
			Duration = 2.5,
		},
		AnimKey = "SkillCast",
		TelegraphColor = Color3.fromRGB(120, 235, 95),
	},
} :: { [string]: Types.NPCSkillDefinition }

local DEFAULT_ENEMY_ANIMATIONS: { [string]: string } = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Attack = "rbxassetid://522635514",
	SkillCast = "rbxassetid://522638767",
	Hit = "rbxassetid://507770818",
	Death = "rbxassetid://507770677",
}

NPCConfig.NPCs = {
	moss_slime = {
		NPCId = "moss_slime",
		DisplayName = "Moss Slime",
		Category = "Enemy",
		IsBoss = false,
		Level = 2,
		MaxHP = 110,
		WalkSpeed = 9,
		AggroRange = 24,
		AttackRange = 5.5,
		BasicAttackDamage = 9,
		BasicAttackCooldown = 1.8,
		LeashDistance = 42,
		ExpReward = 25,
		CashReward = 15,
		PlaceholderColor = Color3.fromRGB(88, 205, 102),
		PlaceholderScale = Vector3.new(3.2, 2.6, 3.2),
		Animations = DEFAULT_ENEMY_ANIMATIONS,
		SkillIds = { "slime_acid_splash" },
		LootTable = {
			{ ItemId = "slime_gel", Chance = 0.75, MinAmount = 1, MaxAmount = 2 },
			{ ItemId = "carrot_seed", Chance = 0.35, MinAmount = 1, MaxAmount = 2 },
			{ ItemId = "berry_feed", Chance = 0.25, MinAmount = 1, MaxAmount = 1 },
		},
	},
} :: { [string]: Types.NPCDefinition }

NPCConfig.DefaultSpawnZones = {
	{
		SpawnZoneId = "forest_slime_zone",
		NPCId = "moss_slime",
		DefaultPosition = Vector3.new(85, 4, 85),
		SpawnRadius = 14,
		PatrolRadius = 18,
		MaxConcurrent = 4,
		RespawnDelay = 8,
	},
} :: { Types.NPCSpawnZoneConfig }

NPCConfig.WeaponStats = {
	iron_sword = { Damage = 28, Cooldown = 0.50, Range = 10.5 },
	normal_Sword = { Damage = 18, Cooldown = 0.55, Range = 9.5 },
} :: { [string]: { Damage: number, Cooldown: number, Range: number } }

return NPCConfig
