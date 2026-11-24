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
	wolf_feral_lunge = {
		SkillId = "wolf_feral_lunge",
		DisplayName = "เขี้ยวพุ่งขย้ำ (Feral Lunge)",
		Shape = "Box",
		TargetMode = "ForwardLine",
		CastRange = 24,
		Radius = 0,
		BoxSize = Vector3.new(5.5, 6, 18),
		WindupTime = 0.85,
		ActiveDuration = 0.20,
		Cooldown = 8.5,
		Damage = 26,
		HealAmount = 0,
		MinHealthPercent = 0,
		MaxHealthPercent = 1.0,
		DashForwardDistance = 15,
		AnimKey = "SkillCast",
		TelegraphColor = Color3.fromRGB(255, 110, 75),
	},
	golem_earth_slam = {
		SkillId = "golem_earth_slam",
		DisplayName = "พสุธากัมปนาท (Earthshatter Slam)",
		Shape = "Circle",
		TargetMode = "SelfOrigin",
		CastRange = 18,
		Radius = 14.0,
		BoxSize = Vector3.zero,
		WindupTime = 1.45,
		ActiveDuration = 0.30,
		Cooldown = 11.0,
		Damage = 42,
		HealAmount = 0,
		MinHealthPercent = 0,
		MaxHealthPercent = 1.0,
		StatusEffect = {
			Type = "Slow",
			Magnitude = 0.40,
			Duration = 3.0,
		},
		AnimKey = "SkillCast",
		TelegraphColor = Color3.fromRGB(235, 75, 65),
	},
	golem_stone_mend = {
		SkillId = "golem_stone_mend",
		DisplayName = "เกราะศิลาฟื้นฟู (Stone Mend)",
		Shape = "Circle",
		TargetMode = "SelfOrigin",
		CastRange = 30,
		Radius = 8.0,
		BoxSize = Vector3.zero,
		WindupTime = 1.20,
		ActiveDuration = 0.30,
		Cooldown = 18.0,
		Damage = 0,
		HealAmount = 120,
		MinHealthPercent = 0,
		MaxHealthPercent = 0.55,
		AnimKey = "SkillCast",
		TelegraphColor = Color3.fromRGB(95, 205, 255),
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
	feral_wolf = {
		NPCId = "feral_wolf",
		DisplayName = "Feral Moss Wolf",
		Category = "Enemy",
		IsBoss = false,
		Level = 5,
		MaxHP = 240,
		WalkSpeed = 14,
		AggroRange = 32,
		AttackRange = 6.5,
		BasicAttackDamage = 18,
		BasicAttackCooldown = 1.4,
		LeashDistance = 52,
		ExpReward = 55,
		CashReward = 35,
		PlaceholderColor = Color3.fromRGB(92, 110, 96),
		PlaceholderScale = Vector3.new(3.0, 3.4, 4.8),
		Animations = DEFAULT_ENEMY_ANIMATIONS,
		SkillIds = { "wolf_feral_lunge" },
		LootTable = {
			{ ItemId = "wolf_fang", Chance = 0.65, MinAmount = 1, MaxAmount = 2 },
			{ ItemId = "moon_herb_seed", Chance = 0.22, MinAmount = 1, MaxAmount = 1 },
			{ ItemId = "forest_egg", Chance = 0.08, MinAmount = 1, MaxAmount = 1 },
		},
	},
	ancient_stone_golem = {
		NPCId = "ancient_stone_golem",
		DisplayName = "Ancient Forest Golem [BOSS]",
		Category = "Enemy",
		IsBoss = true,
		Level = 12,
		MaxHP = 1250,
		WalkSpeed = 10,
		AggroRange = 45,
		AttackRange = 8.5,
		BasicAttackDamage = 32,
		BasicAttackCooldown = 2.1,
		LeashDistance = 65,
		ExpReward = 260,
		CashReward = 180,
		PlaceholderColor = Color3.fromRGB(115, 125, 138),
		PlaceholderScale = Vector3.new(6.5, 8.5, 5.5),
		Animations = DEFAULT_ENEMY_ANIMATIONS,
		SkillIds = { "golem_earth_slam", "golem_stone_mend" },
		LootTable = {
			{ ItemId = "evo_crystal", Chance = 0.50, MinAmount = 1, MaxAmount = 1 },
			{ ItemId = "golden_apple_seed", Chance = 0.30, MinAmount = 1, MaxAmount = 1 },
			{ ItemId = "mystic_forest_egg", Chance = 0.18, MinAmount = 1, MaxAmount = 1 },
		},
	},
	elder_rowan = {
		NPCId = "elder_rowan",
		DisplayName = "ผู้เฒ่าโรแวน (Elder Rowan)",
		Category = "Friendly",
		IsBoss = false,
		Level = 99,
		MaxHP = 9999,
		WalkSpeed = 0,
		AggroRange = 0,
		AttackRange = 0,
		BasicAttackDamage = 0,
		BasicAttackCooldown = 0,
		LeashDistance = 10,
		ExpReward = 0,
		CashReward = 0,
		PlaceholderColor = Color3.fromRGB(70, 140, 215),
		PlaceholderScale = Vector3.new(2.6, 5.2, 2.0),
		Animations = {
			Idle = "rbxassetid://507766388",
		},
		SkillIds = {},
		LootTable = {},
		DialogueLines = {
			"ยินดีต้อนรับสู่ดินแดนฟาร์มและผจญภัย! คุณสามารถปลูกพืชใน Plot [H] และฟักไข่สัตว์เลี้ยง [P] เพื่อสร้างทีมต่อสู้ได้",
			"ระวังวงเตือนสีแดงบนพื้นเมื่อต่อสู้กับมอนสเตอร์ป่าและ Ancient Forest Golem เพราะสกิลของพวกมันรุนแรงมาก!",
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
	{
		SpawnZoneId = "wolf_pack_zone",
		NPCId = "feral_wolf",
		DefaultPosition = Vector3.new(145, 4, 90),
		SpawnRadius = 18,
		PatrolRadius = 24,
		MaxConcurrent = 3,
		RespawnDelay = 12,
	},
	{
		SpawnZoneId = "boss_golem_arena",
		NPCId = "ancient_stone_golem",
		DefaultPosition = Vector3.new(210, 5, 140),
		SpawnRadius = 4,
		PatrolRadius = 14,
		MaxConcurrent = 1,
		RespawnDelay = 45,
	},
	{
		SpawnZoneId = "village_guide_spawn",
		NPCId = "elder_rowan",
		DefaultPosition = Vector3.new(24, 4, 24),
		SpawnRadius = 0,
		PatrolRadius = 0,
		MaxConcurrent = 1,
		RespawnDelay = 5,
	},
} :: { Types.NPCSpawnZoneConfig }

NPCConfig.WeaponStats = {
	iron_sword = { Damage = 28, Cooldown = 0.50, Range = 10.5 },
	normal_Sword = { Damage = 18, Cooldown = 0.55, Range = 9.5 },
} :: { [string]: { Damage: number, Cooldown: number, Range: number } }

return NPCConfig
