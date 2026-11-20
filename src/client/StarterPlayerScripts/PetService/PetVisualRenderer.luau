--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local PetVisualRenderer = {}

local started = false
local trackedModels: { [string]: Model } = {}

local STAGE_COLORS: { [string]: Color3 } = {
	Baby = Color3.fromRGB(145, 220, 165),
	Juvenile = Color3.fromRGB(100, 185, 255),
	Adult = Color3.fromRGB(255, 200, 85),
	Evolved = Color3.fromRGB(215, 130, 255),
}

local function updateBillboard(model: Model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		return
	end

	local billboard = primary:FindFirstChild("PetStatusBillboard") :: BillboardGui?
	if not billboard then
		local created = Instance.new("BillboardGui")
		created.Name = "PetStatusBillboard"
		created.Size = UDim2.fromOffset(150, 48)
		created.StudsOffset = Vector3.new(0, 3.2, 0)
		created.AlwaysOnTop = false
		created.MaxDistance = 60
		created.Parent = primary

		local bg = Instance.new("Frame")
		bg.Name = "Container"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
		bg.BackgroundTransparency = 0.22
		bg.Parent = created

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(70, 80, 105)
		stroke.Parent = bg

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Position = UDim2.fromOffset(6, 3)
		nameLabel.Size = UDim2.new(1, -12, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.fromRGB(245, 247, 255)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = bg

		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Position = UDim2.fromOffset(6, 20)
		subLabel.Size = UDim2.new(1, -12, 0, 13)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.TextSize = 10
		subLabel.TextColor3 = Color3.fromRGB(185, 195, 220)
		subLabel.Parent = bg

		local barTrack = Instance.new("Frame")
		barTrack.Name = "HungerTrack"
		barTrack.Position = UDim2.new(0, 8, 1, -10)
		barTrack.Size = UDim2.new(1, -16, 0, 5)
		barTrack.BackgroundColor3 = Color3.fromRGB(35, 40, 54)
		barTrack.BorderSizePixel = 0
		barTrack.Parent = bg

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = barTrack

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(80, 205, 125)
		fill.BorderSizePixel = 0
		fill.Parent = barTrack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		billboard = created
	end

	local container = billboard and billboard:FindFirstChild("Container")
	if not container then
		return
	end

	local nickname = tostring(model:GetAttribute("Nickname") or "Pet")
	local stage = tostring(model:GetAttribute("Stage") or "Baby")
	local level = tonumber(model:GetAttribute("Level")) or 1
	local hunger = math.clamp(tonumber(model:GetAttribute("Hunger")) or 100, 0, PetConfig.MaxHunger)
	local stageColor = STAGE_COLORS[stage] or Color3.fromRGB(160, 175, 200)

	local nameLabel = container:FindFirstChild("NameLabel") :: TextLabel?
	if nameLabel then
		nameLabel.Text = `{nickname}  Lv.{level}`
	end
	local subLabel = container:FindFirstChild("SubLabel") :: TextLabel?
	if subLabel then
		subLabel.Text = stage
		subLabel.TextColor3 = stageColor
	end
	local stroke = container:FindFirstChild("Stroke") :: UIStroke?
	if stroke then
		stroke.Color = stageColor
	end

	local track = container:FindFirstChild("HungerTrack")
	local fill = track and track:FindFirstChild("Fill") :: Frame?
	if fill then
		local ratio = hunger / PetConfig.MaxHunger
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = if ratio > 0.5
			then Color3.fromRGB(80, 205, 125)
			elseif ratio > 0.25 then Color3.fromRGB(240, 185, 65)
			else Color3.fromRGB(225, 75, 85)
	end
end

local function trackPetModel(model: Model)
	local uid = model:GetAttribute("PetUID")
	if type(uid) ~= "string" then
		return
	end

	trackedModels[uid] = model
	updateBillboard(model)

	local function onAttrChanged()
		if model.Parent then
			updateBillboard(model)
		end
	end

	model:GetAttributeChangedSignal("Nickname"):Connect(onAttrChanged)
	model:GetAttributeChangedSignal("Stage"):Connect(onAttrChanged)
	model:GetAttributeChangedSignal("Level"):Connect(onAttrChanged)
	model:GetAttributeChangedSignal("Hunger"):Connect(onAttrChanged)

	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and trackedModels[uid] == model then
			trackedModels[uid] = nil
		end
	end)
end

local function spawnBurstVFX(position: Vector3, color: Color3, count: number, size: number)
	local anchor = Instance.new("Part")
	anchor.Name = "PetVFX"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.75)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor

	emitter:Emit(count)
	Debris:AddItem(anchor, 1.2)
end

local function spawnAttackBeam(fromPos: Vector3, toPos: Vector3)
	local dist = (toPos - fromPos).Magnitude
	if dist < 0.1 then
		return
	end

	local beamPart = Instance.new("Part")
	beamPart.Name = "PetAttackFlash"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = Color3.fromRGB(255, 115, 90)
	beamPart.Size = Vector3.new(0.25, 0.25, dist)
	beamPart.CFrame = CFrame.lookAt((fromPos + toPos) * 0.5, toPos)
	beamPart.Parent = workspace

	TweenService:Create(
		beamPart,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }
	):Play()

	Debris:AddItem(beamPart, 0.22)
end

local function watchFolder(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PetUID") then
			trackPetModel(child)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(function()
				if child.Parent and child:GetAttribute("PetUID") then
					trackPetModel(child)
				end
			end)
		end
	end)
end

local function watchPlot(plot: Instance)
	local petsFolder = plot:FindFirstChild("Pets")
	if petsFolder then
		watchFolder(petsFolder)
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Pets" then
			watchFolder(child)
		end
	end)
end

function PetVisualRenderer.Start()
	if started then
		return
	end
	started = true

	-- ติดตามโฟลเดอร์ Plots
	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			watchPlot(plot)
		end
		plotsFolder.ChildAdded:Connect(watchPlot)
	end

	-- ติดตามโฟลเดอร์ ActiveCombatPets
	local combatFolder = workspace:FindFirstChild("ActiveCombatPets")
	if combatFolder then
		watchFolder(combatFolder)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveCombatPets" then
			watchFolder(child)
		elseif child.Name == "Plots" then
			for _, plot in child:GetChildren() do
				watchPlot(plot)
			end
			child.ChildAdded:Connect(watchPlot)
		end
	end)

	-- รับ PetVisualEvent (Unreliable) เพื่อแสดง VFX
	Network.PetNetwork.PetVisualEvent.listen(function(data)
		local model = trackedModels[data.PetUID]
		local originPos = if model and model.Parent then model:GetPivot().Position else data.TargetPos
		if not originPos then
			return
		end

		if data.EventType == "Eat" then
			spawnBurstVFX(originPos + Vector3.new(0, 1.5, 0), Color3.fromRGB(95, 225, 130), 12, 0.55)
		elseif data.EventType == "Evolve" then
			spawnBurstVFX(originPos + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 210, 75), 32, 0.9)
		elseif data.EventType == "Hatch" then
			spawnBurstVFX(originPos + Vector3.new(0, 1.5, 0), Color3.fromRGB(130, 215, 255), 24, 0.75)
		elseif data.EventType == "Attack" then
			if data.TargetPos then
				spawnAttackBeam(originPos, data.TargetPos)
				spawnBurstVFX(data.TargetPos, Color3.fromRGB(255, 100, 85), 10, 0.45)
			else
				spawnBurstVFX(originPos, Color3.fromRGB(255, 100, 85), 8, 0.45)
			end
		end
	end)
end

return PetVisualRenderer
