--!strict

local AdminConfig = {}

AdminConfig.AllowCreator = true

AdminConfig.AllowStudioAccess = true

AdminConfig.AuthCacheTTLSeconds = 90

AdminConfig.StudioNonAdminTestUserIds = {} :: { [number]: boolean }

AdminConfig.AdminUserIds = {} :: { [number]: boolean }

AdminConfig.GroupConfig = {
	GroupId = 0,
	MinAdminRank = 250,
}

AdminConfig.AutoCreateStudioDummyTools = false

AdminConfig.DefaultWalkSpeed = 16
AdminConfig.MinWalkSpeed = 4
AdminConfig.MaxWalkSpeed = 120
AdminConfig.SpeedPresets = { 16, 24, 32, 50, 80, 100 }

AdminConfig.MaxSpawnAmountPerAction = 99
AdminConfig.MaxPetSpawnAmountPerAction = 10
AdminConfig.MaxAuditLogEntries = 50
AdminConfig.MaxCriticalAuditLogEntries = 50

return AdminConfig
