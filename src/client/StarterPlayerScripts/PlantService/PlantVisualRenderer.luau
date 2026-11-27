--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlantConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlantConfig"))

local PlantVisualRenderer = {}

local DRY_SOIL_COLOR = Color3.fromRGB(138, 98, 64)
local WET_SOIL_COLOR = Color3.fromRGB(74, 48, 30)

local HEIGHT_BY_STAGE: { [string]: number } = {
	Seed = 0.45,
	Sprout = 1.1,
	Growing = 2.0,
	Mature = 2.8,
}

type PlanterRecord = {
	Connections: { RBXScriptConnection },
	VisualCrop: Model?,
	Billboard: BillboardGui?,
	CurrentCropId: string?,
	CurrentStage: string?,
}

local started = false
local watchedPlotsFolders: { [Instance]: boolean } = {}
local trackedPlanters: { [Model]: PlanterRecord } = {}

local function buildPlaceholderPlant(cropId: string, stage: string): (Model, number)
	local cropDef = PlantConfig.Crops[cropId]
	local model = Instance.new("Model")
	model.Name = "CropVisual_" .. stage

	local height = HEIGHT_BY_STAGE[stage] or 1.0
	local width = 0.55 + (height * 0.24)

	local stem = Instance.new("Part")
	stem.Name = "PrimaryPart"
	stem.Size = Vector3.new(width, height, width)
	stem.Anchored = true
	stem.CanCollide = false
	stem.CanQuery = false
	stem.Material = Enum.Material.SmoothPlastic
	stem.Color = if stage == "Mature" and cropDef
		then cropDef.PlaceholderColor
		else Color3.fromRGB(76, 175, 80)
	stem.Parent = model

	if stage == "Growing" or stage == "Mature" then
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Shape = Enum.PartType.Ball
		local crownSize = width * (if stage == "Mature" then 1.35 else 1.05)
		crown.Size = Vector3.new(crownSize, crownSize, crownSize)
		crown.Anchored = true
		crown.CanCollide = false
		crown.CanQuery = false
		crown.Material = Enum.Material.SmoothPlastic
		crown.Color = if stage == "Mature" and cropDef
			then cropDef.PlaceholderColor
			else Color3.fromRGB(92, 195, 96)
		crown.CFrame = stem.CFrame * CFrame.new(0, height * 0.5, 0)
		crown.Parent = model
	end

	model.PrimaryPart = stem
	return model, height
end

local function resolveCropModel(cropId: string, stage: PlantConfig.PlantStage): (Model, boolean, number)
	local cropDef = PlantConfig.Crops[cropId]
	local modelsFolder = ReplicatedStorage:FindFirstChild("PlantModels")
	if cropDef and modelsFolder then
		local modelName = cropDef.StageModels[stage]
		local template = if modelName then modelsFolder:FindFirstChild(modelName) else nil
		if template and template:IsA("Model") then
			local cloned = template:Clone()
			for _, desc in cloned:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
					desc.CanQuery = false
				end
			end
			return cloned, false, 0
		end
	end

	local placeholder, placeholderHeight = buildPlaceholderPlant(cropId, stage)
	return placeholder, true, placeholderHeight
end

local function ensureBillboard(planterModel: Model, record: PlanterRecord): BillboardGui
	if record.Billboard and record.Billboard.Parent then
		return record.Billboard
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PlantStatusBillboard"
	bb.Size = UDim2.fromOffset(162, 54)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.MaxDistance = 36
	bb.AlwaysOnTop = false

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	container.BackgroundTransparency = 0.18
	container.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(68, 76, 98)
	stroke.Parent = container

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Position = UDim2.fromOffset(6, 3)
	nameLabel.Size = UDim2.new(1, -12, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Color3.fromRGB(245, 247, 255)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = container

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Position = UDim2.fromOffset(6, 21)
	statusLabel.Size = UDim2.new(1, -12, 0, 15)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 10
	statusLabel.TextColor3 = Color3.fromRGB(185, 210, 195)
	statusLabel.Parent = container

	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.Position = UDim2.new(0, 8, 1, -10)
	track.Size = UDim2.new(1, -16, 0, 5)
	track.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 205, 125)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local adornee = planterModel.PrimaryPart
		or planterModel:FindFirstChild("SoilPart", true)
		or planterModel:FindFirstChildWhichIsA("BasePart", true)
	if adornee and adornee:IsA("BasePart") then
		bb.Adornee = adornee
	end
	bb.Parent = planterModel
	record.Billboard = bb
	return bb
end

local function refreshPlanterVisual(planterModel: Model)
	local record = trackedPlanters[planterModel]
	if not record or not planterModel.Parent then
		return
	end

	local rawCropId = planterModel:GetAttribute("CropId")
	local cropId = if typeof(rawCropId) == "string" then rawCropId else nil
	local rawStage = planterModel:GetAttribute("PlantStage")
	local stage = if typeof(rawStage) == "string" then rawStage else nil
	local isWet = planterModel:GetAttribute("IsWet") == true
	local rawProgress = planterModel:GetAttribute("GrowthProgress")
	local progress = if typeof(rawProgress) == "number" then math.clamp(rawProgress, 0, 1) else 0

	local soilPart = planterModel:FindFirstChild("SoilPart", true)
	if soilPart and soilPart:IsA("BasePart") then
		soilPart.Color = if isWet then WET_SOIL_COLOR else DRY_SOIL_COLOR
	end

	if not cropId or cropId == "" or not stage or stage == "" then
		if record.VisualCrop then
			record.VisualCrop:Destroy()
			record.VisualCrop = nil
		end
		record.CurrentCropId = nil
		record.CurrentStage = nil
		if record.Billboard then
			record.Billboard.Enabled = false
		end
		return
	end

	if record.CurrentCropId ~= cropId or record.CurrentStage ~= stage or not record.VisualCrop or not record.VisualCrop.Parent then
		if record.VisualCrop then
			record.VisualCrop:Destroy()
			record.VisualCrop = nil
		end

		local cropVisual, isPlaceholder, placeholderHeight = resolveCropModel(cropId, stage :: PlantConfig.PlantStage)
		local targetCF: CFrame
		if soilPart and soilPart:IsA("BasePart") then
			local yOffset = if isPlaceholder then (soilPart.Size.Y * 0.5 + placeholderHeight * 0.5) else (soilPart.Size.Y * 0.5)
			targetCF = CFrame.new(soilPart.Position + Vector3.new(0, yOffset, 0))
		else
			local yOffset = if isPlaceholder then (0.8 + placeholderHeight * 0.5) else 1.2
			targetCF = planterModel:GetPivot() * CFrame.new(0, yOffset, 0)
		end

		cropVisual:PivotTo(targetCF)
		cropVisual.Parent = planterModel
		record.VisualCrop = cropVisual
		record.CurrentCropId = cropId
		record.CurrentStage = stage
	end

	local bb = ensureBillboard(planterModel, record)
	local container = bb:FindFirstChild("Container")
	local cropDef = PlantConfig.Crops[cropId]
	if container then
		bb.Enabled = true
		local isMature = stage == "Mature"
		local pct = math.floor(progress * 100)
		local waterTag = if isWet then "[ชุ่มชื้น]" else "[ดินแห้ง]"
		local stageTag = if isMature then "พร้อมเก็บเกี่ยว!" else `{pct}%`

		local nameLabel = container:FindFirstChild("NameLabel") :: TextLabel?
		if nameLabel then
			nameLabel.Text = if cropDef then cropDef.DisplayName else cropId
		end

		local statusLabel = container:FindFirstChild("StatusLabel") :: TextLabel?
		if statusLabel then
			statusLabel.Text = `{stageTag} {waterTag}`
			statusLabel.TextColor3 = if isMature
				then Color3.fromRGB(255, 220, 90)
				elseif isWet then Color3.fromRGB(125, 210, 255)
				else Color3.fromRGB(240, 175, 110)
		end

		local stroke = container:FindFirstChild("Stroke") :: UIStroke?
		if stroke then
			stroke.Color = if isMature
				then Color3.fromRGB(245, 195, 65)
				elseif isWet then Color3.fromRGB(80, 170, 235)
				else Color3.fromRGB(68, 76, 98)
		end

		local track = container:FindFirstChild("ProgressTrack")
		local fill = if track then track:FindFirstChild("Fill") :: Frame? else nil
		if fill then
			fill.Size = UDim2.fromScale(if isMature then 1 else progress, 1)
			fill.BackgroundColor3 = if isMature
				then Color3.fromRGB(245, 195, 65)
				else Color3.fromRGB(80, 205, 125)
		end
	end
end

local function cleanupPlanter(planterModel: Model)
	local rec = trackedPlanters[planterModel]
	if not rec then
		return
	end
	trackedPlanters[planterModel] = nil

	for _, conn in rec.Connections do
		conn:Disconnect()
	end
	if rec.VisualCrop then
		rec.VisualCrop:Destroy()
	end
	if rec.Billboard then
		rec.Billboard:Destroy()
	end
end

local function watchPlanter(planterModel: Model)
	if trackedPlanters[planterModel] or not PlantConfig.Planters[planterModel.Name] then
		return
	end
	if not planterModel:IsDescendantOf(game) then
		return
	end

	local conns: { RBXScriptConnection } = {}
	trackedPlanters[planterModel] = {
		Connections = conns,
		VisualCrop = nil,
		Billboard = nil,
		CurrentCropId = nil,
		CurrentStage = nil,
	}

	for _, attr in { "CropId", "PlantStage", "IsWet", "GrowthProgress" } do
		table.insert(
			conns,
			planterModel:GetAttributeChangedSignal(attr):Connect(function()
				refreshPlanterVisual(planterModel)
			end)
		)
	end

	table.insert(
		conns,
		planterModel.AncestryChanged:Connect(function(_, newParent)
			if not newParent or not planterModel:IsDescendantOf(game) then
				cleanupPlanter(planterModel)
			end
		end)
	)

	refreshPlanterVisual(planterModel)
end

local function watchPlotsFolder(plotsFolder: Instance)
	if watchedPlotsFolders[plotsFolder] then
		return
	end
	watchedPlotsFolders[plotsFolder] = true

	for _, desc in plotsFolder:GetDescendants() do
		if desc:IsA("Model") and PlantConfig.Planters[desc.Name] then
			watchPlanter(desc)
		end
	end

	plotsFolder.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") and PlantConfig.Planters[desc.Name] then
			task.defer(watchPlanter, desc)
		end
	end)
end

function PlantVisualRenderer.PlayEffect(eventType: string, worldPos: Vector3)
	local attachmentPart = Instance.new("Part")
	attachmentPart.Name = "PlantVFX"
	attachmentPart.Size = Vector3.new(0.2, 0.2, 0.2)
	attachmentPart.Transparency = 1
	attachmentPart.Anchored = true
	attachmentPart.CanCollide = false
	attachmentPart.CanQuery = false
	attachmentPart.CFrame = CFrame.new(worldPos + Vector3.new(0, 1.8, 0))
	attachmentPart.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Lifetime = NumberRange.new(0.4, 0.85)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Rate = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})

	local emitCount = 14
	if eventType == "Water" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(90, 190, 255))
		emitCount = 16
	elseif eventType == "Harvest" or eventType == "Mature" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 75))
		emitCount = 22
	elseif eventType == "Fertilize" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(190, 130, 255))
		emitCount = 16
	else
		emitter.Color = ColorSequence.new(Color3.fromRGB(110, 230, 115))
	end

	emitter.Parent = attachmentPart
	emitter:Emit(emitCount)
	Debris:AddItem(attachmentPart, 1.2)
end

function PlantVisualRenderer.Start()
	if started then
		return
	end
	started = true

	local existingPlots = Workspace:FindFirstChild("Plots")
	if existingPlots then
		watchPlotsFolder(existingPlots)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Plots" then
			watchPlotsFolder(child)
		end
	end)
end

PlantVisualRenderer.Init = PlantVisualRenderer.Start

return PlantVisualRenderer
