--!strict

local AdminConfig = {}

-- อนุญาตให้เจ้าของแมพ (game.CreatorId) เข้าถึง Admin Panel อัตโนมัติ
AdminConfig.AllowCreator = true

-- อนุญาตให้เข้าถึง Admin Panel ได้เมื่อทดสอบใน Roblox Studio
AdminConfig.AllowStudioAccess = true

-- ระยะเวลา TTL (วินาที) สำหรับแคชสิทธิ์แอดมิน เพื่อให้การถอดยศกลุ่มมีผลทันทีระหว่างเซสชัน
AdminConfig.AuthCacheTTLSeconds = 90

-- รายชื่อ UserId ที่ต้องการยกเว้นสิทธิ์แอดมินใน Roblox Studio สำหรับทดสอบ QA (เช่น Local Server)
-- ตัวอย่าง: [-2] = true,
AdminConfig.StudioNonAdminTestUserIds = {} :: { [number]: boolean }

-- รายชื่อแอดมินเพิ่มเติม: ใช้ UserId (ตัวเลข) เท่านั้น ห้ามใช้ Username เพราะผู้เล่นสามารถเปลี่ยนชื่อได้
-- ตัวอย่าง: [123456789] = true,
AdminConfig.AdminUserIds = {} :: { [number]: boolean }

-- ตั้งค่ากลุ่ม Roblox (กำหนด GroupId > 0 เพื่อเปิดใช้งานการตรวจสอบยศ)
AdminConfig.GroupConfig = {
	GroupId = 0,
	MinAdminRank = 250,
}

-- โหมดพัฒนา (เฉพาะ Roblox Studio): สร้าง Tool จำลองใน ServerStorage.AllItems อัตโนมัติสำหรับไอเทมที่ยังขาด
AdminConfig.AutoCreateStudioDummyTools = false

-- ค่าความเร็วการเดิน (WalkSpeed)
AdminConfig.DefaultWalkSpeed = 16
AdminConfig.MinWalkSpeed = 4
AdminConfig.MaxWalkSpeed = 120
AdminConfig.SpeedPresets = { 16, 24, 32, 50, 80, 100 }

-- ข้อจำกัดการเสกไอเทมและบันทึกประวัติการใช้งาน
AdminConfig.MaxSpawnAmountPerAction = 99
AdminConfig.MaxAuditLogEntries = 50
AdminConfig.MaxCriticalAuditLogEntries = 50

return AdminConfig
