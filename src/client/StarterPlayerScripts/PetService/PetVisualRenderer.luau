--!strict
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local PetConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("PetConfig"))

local PetVisualRenderer = {}

type ClientPetMotion = {
	BasePos: Vector3,
	CurrentRot: CFrame,
	BobPhase: number,
	BobOffset: number,
}

local started = false
local trackedModels: { [string]: Model } = {}
local petMotions: { [string]: ClientPetMotion } = {}

local TURN_RESPONSIVENESS = 10
local FOLLOW_RESPONSIVENESS = 8
local TELEPORT_SNAP_DISTANCE = 45
local BOB_SPEED = 10
local BOB_AMPLITUDE = 0

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

local function initPetMotion(uid: string, model: Model)
	local state = model:GetAttribute("State")
	if state == "InPlot" or state == "Equipped" then
		local pivot = model:GetPivot()
		petMotions[uid] = {
			BasePos = pivot.Position,
			CurrentRot = pivot.Rotation,
			BobPhase = math.random() * math.pi * 2,
			BobOffset = 0,
		}
	else
		petMotions[uid] = nil
	end
end

local function computePivotHeight(model: Model): number
	local attr = tonumber(model:GetAttribute("PivotHeightOffset"))
	if attr ~= nil then
		return attr
	end
	local pivotY = model:GetPivot().Position.Y
	local lowestY = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local cf = descendant.CFrame
			local half = descendant.Size * 0.5
			local extentY = math.abs(cf.XVector.Y) * half.X
				+ math.abs(cf.YVector.Y) * half.Y
				+ math.abs(cf.ZVector.Y) * half.Z
			local partBottomY = cf.Position.Y - extentY
			if partBottomY < lowestY then
				lowestY = partBottomY
			end
		end
	end
	if lowestY == math.huge then
		local bboxCF, bboxSize = model:GetBoundingBox()
		lowestY = bboxCF.Position.Y - (bboxSize.Y * 0.5)
	end
	return pivotY - lowestY
end

local function getGroundRaycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, folderName in { "ActiveCombatPets", "Enemies", "NPCs", "NPCSpawns" } do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function resolveGroundedY(x: number, refY: number, z: number, pivotHeight: number, ownerChar: Model?, rayParams: RaycastParams): number
	local hit = workspace:Raycast(Vector3.new(x, refY + 6, z), Vector3.new(0, -24, 0), rayParams)
	if hit then
		return hit.Position.Y + pivotHeight
	end
	if ownerChar then
		local humanoid = ownerChar:FindFirstChildOfClass("Humanoid")
		local rootPart = ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and rootPart then
			local footOffset = if humanoid.HipHeight > 0 then (humanoid.HipHeight + rootPart.Size.Y * 0.5) else 3
			return (rootPart.Position.Y - footOffset) + pivotHeight
		end
	end
	return (refY - 3) + pivotHeight
end

local function trackPetModel(model: Model)
	local uid = model:GetAttribute("PetUID")
	if type(uid) ~= "string" then
		return
	end

	trackedModels[uid] = model
	initPetMotion(uid, model)
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
	model:GetAttributeChangedSignal("State"):Connect(function()
		if not model.Parent then
			return
		end
		local state = model:GetAttribute("State")
		if state == "InPlot" or state == "Equipped" then
			if not petMotions[uid] then
				initPetMotion(uid, model)
			end
		else
			petMotions[uid] = nil
		end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and trackedModels[uid] == model then
			trackedModels[uid] = nil
			petMotions[uid] = nil
		end
	end)
end

local function stepPetMotions(rawDt: number)
	local dt = math.min(rawDt, 0.1)
	local turnAlpha = 1 - math.exp(-TURN_RESPONSIVENESS * dt)
	local followAlpha = 1 - math.exp(-FOLLOW_RESPONSIVENESS * dt)
	local rayParams: RaycastParams? = nil

	for uid, motion in petMotions do
		local model = trackedModels[uid]
		if not model or not model.Parent then
			petMotions[uid] = nil
			continue
		end

		local state = model:GetAttribute("State")
		if state == "InPlot" then
			local targetAttr = model:GetAttribute("MoveTarget")
			if typeof(targetAttr) ~= "Vector3" then
				continue
			end

			local walkSpeed = tonumber(model:GetAttribute("WalkSpeed")) or 10
			local basePos = motion.BasePos
			local flatDelta = Vector3.new(targetAttr.X - basePos.X, 0, targetAttr.Z - basePos.Z)
			local dist = flatDelta.Magnitude

			if dist > 0.08 then
				local stepDist = math.min(dist, walkSpeed * dt)
				local nextXZ = basePos + (flatDelta.Unit * stepDist)
				motion.BasePos = Vector3.new(nextXZ.X, targetAttr.Y, nextXZ.Z)

				local targetLook = Vector3.new(targetAttr.X, motion.BasePos.Y, targetAttr.Z)
				if (targetLook - motion.BasePos).Magnitude > 0.01 then
					local targetRot = CFrame.lookAt(motion.BasePos, targetLook).Rotation
					motion.CurrentRot = motion.CurrentRot:Lerp(targetRot, turnAlpha)
				end

				motion.BobPhase += dt * BOB_SPEED
				local targetBob = math.abs(math.sin(motion.BobPhase)) * BOB_AMPLITUDE
				motion.BobOffset += (targetBob - motion.BobOffset) * math.min(1, dt * 16)

				local visualPos = motion.BasePos + Vector3.new(0, motion.BobOffset, 0)
				model:PivotTo(CFrame.new(visualPos) * motion.CurrentRot)
			elseif motion.BobOffset > 0.005 then
				motion.BobOffset += (0 - motion.BobOffset) * math.min(1, dt * 14)
				if motion.BobOffset <= 0.005 then
					motion.BobOffset = 0
				end
				local visualPos = motion.BasePos + Vector3.new(0, motion.BobOffset, 0)
				model:PivotTo(CFrame.new(visualPos) * motion.CurrentRot)
			end
		elseif state == "Equipped" then
			local ownerUserId = tonumber(model:GetAttribute("OwnerUserId"))
			local owner = if ownerUserId then Players:GetPlayerByUserId(ownerUserId) else nil
			local ownerChar = owner and owner.Character
			local rootPart = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then
				continue
			end

			if not rayParams then
				rayParams = getGroundRaycastParams()
			end

			local slotIndex = tonumber(model:GetAttribute("CombatSlot")) or 1
			local pivotHeight = computePivotHeight(model)
			local combatTarget = model:GetAttribute("CombatTargetPos")

			local goalX: number
			local goalZ: number
			local refY: number
			local idleLookDir: Vector3

			if typeof(combatTarget) == "Vector3" then
				local angle = math.rad((slotIndex - 1) * 120)
				goalX = combatTarget.X + math.cos(angle) * 3.5
				goalZ = combatTarget.Z + math.sin(angle) * 3.5
				refY = combatTarget.Y
				idleLookDir = Vector3.new(combatTarget.X - motion.BasePos.X, 0, combatTarget.Z - motion.BasePos.Z)
			else
				local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
				if flatLook.Magnitude < 0.01 then
					flatLook = Vector3.new(0, 0, -1)
				else
					flatLook = flatLook.Unit
				end
				local ownerFlatCF = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook)
				local angle = math.rad(135 + (slotIndex - 1) * 45)
				local flatOffset = Vector3.new(math.cos(angle) * 4.5, 0, math.sin(angle) * 4.5)
				local followWorld = (ownerFlatCF * CFrame.new(flatOffset)).Position
				goalX = followWorld.X
				goalZ = followWorld.Z
				refY = rootPart.Position.Y
				idleLookDir = flatLook
			end

			local goalY = resolveGroundedY(goalX, refY, goalZ, pivotHeight, ownerChar, rayParams)
			local goalPos = Vector3.new(goalX, goalY, goalZ)
			local dist = (goalPos - motion.BasePos).Magnitude

			if dist > TELEPORT_SNAP_DISTANCE then
				motion.BasePos = goalPos
			else
				local nextX = motion.BasePos.X + (goalPos.X - motion.BasePos.X) * followAlpha
				local nextZ = motion.BasePos.Z + (goalPos.Z - motion.BasePos.Z) * followAlpha
				local nextGroundY = resolveGroundedY(nextX, refY, nextZ, pivotHeight, ownerChar, rayParams)
				local nextY = motion.BasePos.Y + (nextGroundY - motion.BasePos.Y) * math.min(1, dt * 16)
				motion.BasePos = Vector3.new(nextX, nextY, nextZ)
			end

			local moveFlat = Vector3.new(goalPos.X - motion.BasePos.X, 0, goalPos.Z - motion.BasePos.Z)
			local desiredLook = if typeof(combatTarget) == "Vector3"
				then idleLookDir
				elseif moveFlat.Magnitude > 0.35 then moveFlat
				else idleLookDir

			if desiredLook.Magnitude > 0.01 then
				local targetRot = CFrame.lookAt(motion.BasePos, motion.BasePos + desiredLook.Unit).Rotation
				motion.CurrentRot = motion.CurrentRot:Lerp(targetRot, turnAlpha)
			end

			model:PivotTo(CFrame.new(motion.BasePos) * motion.CurrentRot)
		else
			petMotions[uid] = nil
		end
	end
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

	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			watchPlot(plot)
		end
		plotsFolder.ChildAdded:Connect(watchPlot)
	end

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

	RunService.RenderStepped:Connect(stepPetMotions)

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
