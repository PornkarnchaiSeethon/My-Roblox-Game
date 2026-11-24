--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimController = require(ReplicatedStorage.Shared.Modules:WaitForChild("AnimController"))
local NPCConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("NPCConfig"))
local Types = require(ReplicatedStorage.Shared.Modules:WaitForChild("Types"))

type VisualRigEntry = {
	ServerModel: Model,
	VisualModel: Model,
	CurrentCF: CFrame,
	IsPlaceholder: boolean,
	AnimState: string,
	AnimChangedAt: number,
	BaseScale: Vector3,
}

local NPCVisualRenderer = {}

local started = false
local trackedModels: { [string]: Model } = {}
local attachedModels: { [Model]: boolean } = {}
local activeVisualRigs: { [Model]: VisualRigEntry } = {}

local DEFAULT_TELEGRAPH_COLOR = Color3.fromRGB(235, 70, 65)
local ENEMY_STROKE_DEFAULT = Color3.fromRGB(70, 80, 105)
local FRIENDLY_STROKE_DEFAULT = Color3.fromRGB(80, 155, 235)
local WINDUP_STROKE_COLOR = Color3.fromRGB(255, 165, 65)
local HIT_STROKE_COLOR = Color3.fromRGB(255, 90, 90)

local function getOrCreateVisualsFolder(): Folder
	local existing = Workspace:FindFirstChild("NPCVisuals")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "NPCVisuals"
	folder.Parent = Workspace
	return folder
end

local function spawnBurstVFX(position: Vector3, color: Color3, count: number, size: number)
	local anchor = Instance.new("Part")
	anchor.Name = "NPCVFX"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor

	emitter:Emit(count)
	Debris:AddItem(anchor, 1.2)
end

local function spawnFloatingNumber(position: Vector3, amount: number, isHeal: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "NPCFloatingNumber"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0))
	anchor.Parent = Workspace

	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingNumberGui"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 75
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 20
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = Color3.fromRGB(16, 18, 24)
	local displayNum = math.max(1, math.floor(math.abs(amount)))
	if isHeal then
		label.Text = "+" .. tostring(displayNum)
		label.TextColor3 = Color3.fromRGB(95, 235, 130)
	else
		label.Text = "-" .. tostring(displayNum)
		label.TextColor3 = Color3.fromRGB(255, 205, 75)
	end
	label.Parent = gui

	local riseTween = TweenService:Create(
		anchor,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = anchor.Position + Vector3.new(0, 3.2, 0) }
	)
	riseTween:Play()

	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fadeTween:Play()

	Debris:AddItem(anchor, 0.8)
end

local function buildPlaceholderVisualRig(modelName: string, baseColor: Color3, baseScale: Vector3): Model
	local model = Instance.new("Model")
	model.Name = modelName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = baseScale
	root.Color = baseColor
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local headDiameter = math.max(1.0, math.min(baseScale.X, baseScale.Z) * 0.55)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(headDiameter, headDiameter, headDiameter)
	head.Color = baseColor:Lerp(Color3.new(1, 1, 1), 0.18)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.CFrame = CFrame.new(0, baseScale.Y * 0.5 + headDiameter * 0.45, 0)
	head.Parent = model

	model.PrimaryPart = root
	AnimController.ResolveAnimator(model)
	return model
end

local function createVisualRig(serverModel: Model, def: Types.NPCDefinition?): (Model, boolean, Vector3)
	local baseScale = if def then def.PlaceholderScale else Vector3.new(3, 4, 3)
	local baseColor = if def then def.PlaceholderColor else Color3.fromRGB(165, 175, 190)

	local npcModels = ReplicatedStorage:FindFirstChild("NPCModels")
	local template = if def and npcModels then npcModels:FindFirstChild(def.NPCId) else nil

	if template and template:IsA("Model") then
		local cloned = template:Clone()
		for _, desc in cloned:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanQuery = false
				desc.CanTouch = false
			end
		end
		if not cloned.PrimaryPart then
			local hrp = cloned:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				cloned.PrimaryPart = hrp
			else
				local firstPart = cloned:FindFirstChildWhichIsA("BasePart", true)
				if firstPart then
					cloned.PrimaryPart = firstPart
				end
			end
		end
		AnimController.ResolveAnimator(cloned)
		local extents = cloned:GetExtentsSize()
		return cloned, false, if extents.Y > 0.1 then extents else baseScale
	end

	local placeholder = buildPlaceholderVisualRig(serverModel.Name .. "_Visual", baseColor, baseScale)
	return placeholder, true, baseScale
end

local function computeProceduralOffset(animState: string, elapsed: number, baseScale: Vector3): CFrame
	if animState == "Walk" then
		local bobY = math.abs(math.sin(elapsed * 9)) * 0.28
		local tiltZ = math.sin(elapsed * 9) * 0.05
		return CFrame.new(0, bobY, 0) * CFrame.Angles(0, 0, tiltZ)
	elseif animState == "Idle" then
		local breathY = math.sin(elapsed * 2.4) * 0.08
		return CFrame.new(0, breathY, 0)
	elseif animState == "SkillWindup" then
		local crouchY = -math.min(0.35, baseScale.Y * 0.08)
		local jitterZ = math.sin(elapsed * 28) * 0.04
		return CFrame.new(0, crouchY, 0.15) * CFrame.Angles(math.rad(-12), 0, jitterZ)
	elseif animState == "Attack" or animState == "SkillCast" then
		local t = math.clamp(1 - (elapsed / 0.35), 0, 1)
		return CFrame.new(0, t * 0.2, -t * 0.9) * CFrame.Angles(math.rad(14 * t), 0, 0)
	elseif animState == "Hit" then
		local t = math.clamp(1 - (elapsed / 0.28), 0, 1)
		return CFrame.new(0, t * 0.12, t * 0.55) * CFrame.Angles(math.rad(-14 * t), 0, 0)
	elseif animState == "Death" then
		local t = math.clamp(elapsed / 0.4, 0, 1)
		return CFrame.new(0, -t * (baseScale.Y * 0.32), 0) * CFrame.Angles(0, 0, math.rad(85 * t))
	end
	return CFrame.identity
end

local function updateOverheadUI(serverModel: Model, visualModel: Model, isFriendly: boolean)
	local adorneeParent: Instance = visualModel.PrimaryPart or visualModel
	local gui = adorneeParent:FindFirstChild("NPCOverheadGui")
	if not gui or not gui:IsA("BillboardGui") then
		gui = visualModel:FindFirstChild("NPCOverheadGui")
	end
	if not gui or not gui:IsA("BillboardGui") then
		return
	end

	local container = gui:FindFirstChild("Container")
	if not container then
		return
	end

	local displayName = tostring(serverModel:GetAttribute("DisplayName") or serverModel.Name)
	local level = tonumber(serverModel:GetAttribute("Level")) or 1
	local animState = tostring(serverModel:GetAttribute("AnimState") or "Idle")

	local nameLabel = container:FindFirstChild("NameLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = string.format("Lv.%d %s", math.floor(level), displayName)
	end

	local stroke = container:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		if animState == "SkillWindup" then
			stroke.Color = WINDUP_STROKE_COLOR
			stroke.Thickness = 2
		elseif animState == "Hit" then
			stroke.Color = HIT_STROKE_COLOR
			stroke.Thickness = 2
		else
			stroke.Color = if isFriendly then FRIENDLY_STROKE_DEFAULT else ENEMY_STROKE_DEFAULT
			stroke.Thickness = 1.5
		end
	end

	if not isFriendly then
		local maxHp = math.max(1, tonumber(serverModel:GetAttribute("MaxHP")) or 100)
		local hp = math.clamp(tonumber(serverModel:GetAttribute("HP")) or maxHp, 0, maxHp)
		local ratio = math.clamp(hp / maxHp, 0, 1)

		local track = container:FindFirstChild("HPTrack")
		local fill = if track then track:FindFirstChild("Fill") else nil
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.fromScale(ratio, 1)
		end

		local hpLabel = if track then track:FindFirstChild("HPLabel") else nil
		if hpLabel and hpLabel:IsA("TextLabel") then
			hpLabel.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHp))
		end
	end
end

local function createOverheadBillboard(visualModel: Model, isFriendly: boolean)
	local targetParent: Instance = visualModel.PrimaryPart or visualModel
	local existingOnParent = targetParent:FindFirstChild("NPCOverheadGui")
	if existingOnParent then
		existingOnParent:Destroy()
	end
	local existingOnModel = visualModel:FindFirstChild("NPCOverheadGui")
	if existingOnModel then
		existingOnModel:Destroy()
	end

	local extentsSize = visualModel:GetExtentsSize()
	local offsetY = math.max(3.2, extentsSize.Y * 0.5 + 1.2)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NPCOverheadGui"
	billboard.Size = UDim2.fromOffset(174, if isFriendly then 30 else 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 55
	billboard.Adornee = visualModel
	billboard.Parent = targetParent

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	container.BackgroundTransparency = 0.18
	container.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1.5
	stroke.Color = if isFriendly then FRIENDLY_STROKE_DEFAULT else ENEMY_STROKE_DEFAULT
	stroke.Parent = container

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Position = UDim2.fromOffset(6, 3)
	nameLabel.Size = UDim2.new(1, -12, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = if isFriendly
		then Color3.fromRGB(165, 220, 255)
		else Color3.fromRGB(245, 247, 255)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = container

	if not isFriendly then
		local track = Instance.new("Frame")
		track.Name = "HPTrack"
		track.Position = UDim2.new(0, 8, 1, -20)
		track.Size = UDim2.new(1, -16, 0, 14)
		track.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
		track.BorderSizePixel = 0
		track.Parent = container

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 5)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(215, 62, 72)
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 5)
		fillCorner.Parent = fill

		local hpLabel = Instance.new("TextLabel")
		hpLabel.Name = "HPLabel"
		hpLabel.Size = UDim2.fromScale(1, 1)
		hpLabel.BackgroundTransparency = 1
		hpLabel.Font = Enum.Font.GothamBold
		hpLabel.TextSize = 10
		hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		hpLabel.TextStrokeTransparency = 0.45
		hpLabel.ZIndex = 2
		hpLabel.Parent = track
	end
end

local function attachVisualRig(serverModel: Model, isFriendly: boolean)
	if attachedModels[serverModel] or not serverModel.Parent then
		return
	end
	attachedModels[serverModel] = true

	local npcIdAttr = serverModel:GetAttribute("NPCId")
	local npcId = if typeof(npcIdAttr) == "string" then npcIdAttr else ""
	local def = NPCConfig.NPCs[npcId]

	local uidAttr = serverModel:GetAttribute("NPCUID")
	local npcUID = if typeof(uidAttr) == "string" and uidAttr ~= "" then uidAttr else nil

	local visualModel, isPlaceholder, baseScale = createVisualRig(serverModel, def)
	local initialCF = serverModel:GetPivot()
	visualModel.Name = serverModel.Name .. "_Visual"
	visualModel:PivotTo(initialCF)
	visualModel.Parent = getOrCreateVisualsFolder()

	if npcUID then
		trackedModels[npcUID] = visualModel
	end

	createOverheadBillboard(visualModel, isFriendly)
	updateOverheadUI(serverModel, visualModel, isFriendly)

	local initialAnimState = tostring(serverModel:GetAttribute("AnimState") or "Idle")
	local animMap = if def then def.Animations else nil
	AnimController.PlayState(visualModel, initialAnimState, animMap)

	local entry: VisualRigEntry = {
		ServerModel = serverModel,
		VisualModel = visualModel,
		CurrentCF = initialCF,
		IsPlaceholder = isPlaceholder,
		AnimState = initialAnimState,
		AnimChangedAt = os.clock(),
		BaseScale = baseScale,
	}
	activeVisualRigs[serverModel] = entry

	local connections: { RBXScriptConnection } = {}
	local function onAttrChanged()
		if serverModel.Parent and visualModel.Parent then
			updateOverheadUI(serverModel, visualModel, isFriendly)
		end
	end

	table.insert(connections, serverModel:GetAttributeChangedSignal("HP"):Connect(onAttrChanged))
	table.insert(connections, serverModel:GetAttributeChangedSignal("MaxHP"):Connect(onAttrChanged))
	table.insert(connections, serverModel:GetAttributeChangedSignal("DisplayName"):Connect(onAttrChanged))
	table.insert(connections, serverModel:GetAttributeChangedSignal("Level"):Connect(onAttrChanged))

	table.insert(
		connections,
		serverModel:GetAttributeChangedSignal("AnimState"):Connect(function()
			if not serverModel.Parent or not visualModel.Parent then
				return
			end
			local animState = tostring(serverModel:GetAttribute("AnimState") or "Idle")
			entry.AnimState = animState
			entry.AnimChangedAt = os.clock()
			AnimController.PlayState(visualModel, animState, animMap)
			updateOverheadUI(serverModel, visualModel, isFriendly)
		end)
	)

	local ancestryConn: RBXScriptConnection
	ancestryConn = serverModel.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			for _, conn in connections do
				conn:Disconnect()
			end
			table.clear(connections)
			ancestryConn:Disconnect()
			activeVisualRigs[serverModel] = nil
			attachedModels[serverModel] = nil
			if npcUID and (trackedModels[npcUID] == visualModel or trackedModels[npcUID] == serverModel) then
				trackedModels[npcUID] = nil
			end
			AnimController.CleanupRig(visualModel)
			visualModel:Destroy()
		end
	end)
end

local function watchNPCFolder(folder: Instance, isFriendly: boolean)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			attachVisualRig(child, isFriendly)
		end
	end

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(function()
				if child.Parent then
					attachVisualRig(child, isFriendly)
				end
			end)
		end
	end)
end

function NPCVisualRenderer.FindClosestEnemyUID(origin: Vector3, maxRange: number): string?
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		return nil
	end

	local bestUID: string? = nil
	local bestDist = maxRange

	for _, child in enemiesFolder:GetChildren() do
		if child:IsA("Model") then
			local uid = child:GetAttribute("NPCUID")
			local hp = child:GetAttribute("HP")
			if typeof(uid) == "string" and uid ~= "" and typeof(hp) == "number" and hp > 0 then
				local dist = (child:GetPivot().Position - origin).Magnitude
				if dist <= bestDist then
					bestDist = dist
					bestUID = uid
				end
			end
		end
	end

	return bestUID
end

function NPCVisualRenderer.RenderTelegraph(payload: Types.NPCTelegraphPayload)
	local safeLook = if payload.LookVector.Magnitude > 0.01
		then payload.LookVector.Unit
		else Vector3.new(0, 0, -1)

	local skillDef = NPCConfig.Skills[payload.SkillId]
	local color = if skillDef then skillDef.TelegraphColor else DEFAULT_TELEGRAPH_COLOR
	local duration = math.max(0.15, payload.Duration)

	local part = Instance.new("Part")
	part.Name = "NPCTelegraph"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.68

	if payload.Shape == "Circle" then
		local diameter = math.max(0.5, payload.Radius * 2)
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.25, diameter, diameter)
		part.CFrame = CFrame.new(payload.Origin) * CFrame.Angles(0, 0, math.rad(90))
	else
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(math.max(0.5, payload.BoxSize.X), 0.25, math.max(0.5, payload.BoxSize.Z))
		part.CFrame = CFrame.lookAt(payload.Origin, payload.Origin + safeLook)
	end

	part.Parent = Workspace

	TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Transparency = 0.20 }
	):Play()

	Debris:AddItem(part, duration + 0.08)
end

function NPCVisualRenderer.PlayVisualEvent(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local eventType = payload.EventType
	local worldPos = payload.WorldPos
	if typeof(worldPos) ~= "Vector3" and typeof(payload.NPCUID) == "string" then
		local model = trackedModels[payload.NPCUID]
		if model and model.Parent then
			worldPos = model:GetPivot().Position
		end
	end

	if typeof(worldPos) ~= "Vector3" then
		return
	end

	if eventType == "Damage" then
		local amount = tonumber(payload.Amount) or 0
		spawnFloatingNumber(worldPos, amount, false)
	elseif eventType == "Heal" then
		local amount = tonumber(payload.Amount) or 0
		spawnFloatingNumber(worldPos, amount, true)
	elseif eventType == "SkillImpact" then
		spawnBurstVFX(worldPos + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 115, 70), 22, 0.85)
	elseif eventType == "BasicAttack" then
		spawnBurstVFX(worldPos + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 215, 120), 10, 0.5)
	elseif eventType == "Spawn" then
		spawnBurstVFX(worldPos + Vector3.new(0, 1.4, 0), Color3.fromRGB(120, 215, 255), 18, 0.65)
	elseif eventType == "Death" then
		spawnBurstVFX(worldPos + Vector3.new(0, 1.4, 0), Color3.fromRGB(190, 95, 255), 26, 0.8)
	end
end

function NPCVisualRenderer.Init()
	if started then
		return
	end
	started = true

	getOrCreateVisualsFolder()

	RunService.RenderStepped:Connect(function(dt: number)
		local alpha = math.clamp(1 - math.exp(-14 * dt), 0, 1)
		local now = os.clock()

		for serverModel, entry in activeVisualRigs do
			if not serverModel.Parent or not entry.VisualModel.Parent then
				continue
			end

			local targetCF = serverModel:GetPivot()
			if (targetCF.Position - entry.CurrentCF.Position).Magnitude > 25 then
				entry.CurrentCF = targetCF
			else
				entry.CurrentCF = entry.CurrentCF:Lerp(targetCF, alpha)
			end

			if entry.IsPlaceholder then
				local offset = computeProceduralOffset(entry.AnimState, now - entry.AnimChangedAt, entry.BaseScale)
				entry.VisualModel:PivotTo(entry.CurrentCF * offset)
			else
				entry.VisualModel:PivotTo(entry.CurrentCF)
			end
		end
	end)

	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		watchNPCFolder(enemiesFolder, false)
	end

	local npcsFolder = Workspace:FindFirstChild("NPCs")
	if npcsFolder then
		watchNPCFolder(npcsFolder, true)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Enemies" then
			watchNPCFolder(child, false)
		elseif child.Name == "NPCs" then
			watchNPCFolder(child, true)
		end
	end)
end

return NPCVisualRenderer
