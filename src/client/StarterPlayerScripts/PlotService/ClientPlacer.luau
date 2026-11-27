local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local PlacementValidator = require(ReplicatedStorage.Shared.Modules:WaitForChild("PlacementValidator"))
local Network = require(ReplicatedStorage.Shared.Modules:WaitForChild("Network"))
local placeableObjects = ReplicatedStorage:WaitForChild("PlaceableObjects")

local RENDER_NAME = "RenderPlacementPreview"
local PLACE_ACTION = "PlaceObjectAction"
local ROTATE_ACTION = "RotateObjectAction"
local CYCLE_ACTION = "CycleObjectAction"
local DELETE_ACTION = "DeleteObjectAction"
local GRID_ACTION = "ToggleGridAction"

local ClientPlacer = {}
ClientPlacer.__index = ClientPlacer

local GRID_LINE_COLOR = Color3.fromRGB(220, 240, 255)
local GRID_LINE_THICKNESS = 0.06
local GRID_LINE_HEIGHT = 0.02
local MAX_GRID_LINES_PER_AXIS = 80

local function castMouse(ignoreList: { Instance }): RaycastResult?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

function ClientPlacer.new(plot: Model, initialObjectName: string?)
	local objectsList = {}
	for _, child in placeableObjects:GetChildren() do
		if child:IsA("Model") then
			table.insert(objectsList, child)
		end
	end
	assert(#objectsList > 0, "ReplicatedStorage.PlaceableObjects has no Models")

	local startIndex = 1
	if initialObjectName then
		for idx, obj in objectsList do
			if obj.Name == initialObjectName then
				startIndex = idx
				break
			end
		end
	end

	local presets = PlacementValidator.GRID_PRESETS
	local defaultGrid = presets[1] or PlacementValidator.DEFAULT_GRID_SIZE

	local self = setmetatable({
		plot = plot,
		objects = objectsList,
		objectIndex = startIndex,
		preview = nil :: Model?,
		selectionBox = nil :: SelectionBox?,
		gridOverlay = nil :: Folder?,
		objectSize = Vector3.zero,
		rotationIndex = 0,
		gridPresetIndex = 1,
		gridSize = defaultGrid,
		lastTargetCF = nil :: CFrame?,
		lastValid = false,
	}, ClientPlacer)

	self:rebuildGridOverlay()
	self:initiateRenderPreview()
	self:bindInputs()
	return self
end

function ClientPlacer:clearGridOverlay()
	if self.gridOverlay then
		self.gridOverlay:Destroy()
		self.gridOverlay = nil
	end
end

function ClientPlacer:rebuildGridOverlay()
	self:clearGridOverlay()

	local primaryPart = self.plot.PrimaryPart or self.plot:FindFirstChildWhichIsA("BasePart")
	if not primaryPart or self.gridSize <= 0 then
		return
	end

	local size = primaryPart.Size
	local step = self.gridSize
	while (size.X / step) > MAX_GRID_LINES_PER_AXIS or (size.Z / step) > MAX_GRID_LINES_PER_AXIS do
		step *= 2
	end

	local folder = Instance.new("Folder")
	folder.Name = "PlacementGridOverlay"

	local topY = size.Y * 0.5 + GRID_LINE_HEIGHT * 0.5
	local halfX = size.X * 0.5
	local halfZ = size.Z * 0.5

	local x = -halfX
	while x <= halfX + 0.001 do
		local line = Instance.new("BoxHandleAdornment")
		line.Adornee = primaryPart
		line.Size = Vector3.new(GRID_LINE_THICKNESS, GRID_LINE_HEIGHT, size.Z)
		line.CFrame = CFrame.new(x, topY, 0)
		line.Color3 = GRID_LINE_COLOR
		line.Transparency = 0.72
		line.AlwaysOnTop = false
		line.ZIndex = 1
		line.Parent = folder
		x += step
	end

	local z = -halfZ
	while z <= halfZ + 0.001 do
		local line = Instance.new("BoxHandleAdornment")
		line.Adornee = primaryPart
		line.Size = Vector3.new(size.X, GRID_LINE_HEIGHT, GRID_LINE_THICKNESS)
		line.CFrame = CFrame.new(0, topY, z)
		line.Color3 = GRID_LINE_COLOR
		line.Transparency = 0.72
		line.AlwaysOnTop = false
		line.ZIndex = 1
		line.Parent = folder
		z += step
	end

	folder.Parent = primaryPart
	self.gridOverlay = folder
end

function ClientPlacer:selectObjectByName(objectName: string): boolean
	for idx, obj in self.objects do
		if obj.Name == objectName then
			self.objectIndex = idx
			self:preparePreviewModel(obj)
			return true
		end
	end
	return false
end

function ClientPlacer:preparePreviewModel(model: Model)
	if self.preview then
		self.preview:Destroy()
	end

	local _, objectSize = model:GetBoundingBox()
	self.objectSize = objectSize

	local preview = model:Clone()
	for _, part in preview:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Transparency = 0.5
		end
	end

	local box = Instance.new("SelectionBox")
	box.Adornee = preview
	box.LineThickness = 0.05
	box.Parent = preview

	preview.Parent = workspace
	self.preview = preview
	self.selectionBox = box
end

function ClientPlacer:initiateRenderPreview()
	self:preparePreviewModel(self.objects[self.objectIndex])
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		self:renderPreview()
	end)
end

function ClientPlacer:renderPreview()
	if not self.preview then return end

	local character = game.Players.LocalPlayer.Character
	local ignoreList: { Instance } = { self.preview }
	if character then
		table.insert(ignoreList, character)
	end
	local objectsFolder = self.plot:FindFirstChild("Objects")
	if objectsFolder then
		table.insert(ignoreList, objectsFolder)
	end

	local cast = castMouse(ignoreList)
	if not cast then return end

	local size = self.objectSize
	local targetCF = PlacementValidator.snapPositionToGrid(
		self.plot,
		size,
		cast.Position,
		self.rotationIndex,
		self.gridSize
	)
	self.preview:PivotTo(targetCF)

	local isValid = PlacementValidator.withinBounds(self.plot, size, targetCF)
		and PlacementValidator.noCollisions(self.plot, size, targetCF)
	self.lastTargetCF = targetCF
	self.lastValid = isValid
	if self.selectionBox then
		self.selectionBox.Color3 = if isValid
			then Color3.fromRGB(0, 255, 100)
			else Color3.fromRGB(255, 60, 60)
	end
end

function ClientPlacer:tryPlaceBlock(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or not self.preview then
		return Enum.ContextActionResult.Pass
	end
	local targetCF = self.lastTargetCF or self.preview:GetPivot()
	if not self.lastValid then
		return Enum.ContextActionResult.Sink
	end
	Network.Plot.TryPlace.send({
		name = self.preview.Name,
		targetCF = targetCF,
	})
	return Enum.ContextActionResult.Sink
end

function ClientPlacer:rotateBlock(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		self.rotationIndex = (self.rotationIndex + 1) % 4
	end
end

function ClientPlacer:cycleBlock(_, state: Enum.UserInputState, inputObj: InputObject)
	if state ~= Enum.UserInputState.Begin then return end
	local step = if inputObj.KeyCode == Enum.KeyCode.E then 1 else -1
	self.objectIndex = ((self.objectIndex - 1 + step) % #self.objects) + 1
	self:preparePreviewModel(self.objects[self.objectIndex])
end

function ClientPlacer:tryDeleteBlock(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then return end
	local cast = castMouse({ self.preview, game.Players.LocalPlayer.Character })
	if cast and cast.Instance then
		Network.Plot.TryDelete.send({ target = cast.Instance })
	end
end

function ClientPlacer:toggleGrid(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		local presets = PlacementValidator.GRID_PRESETS
		self.gridPresetIndex = (self.gridPresetIndex % #presets) + 1
		self.gridSize = presets[self.gridPresetIndex]
		self:rebuildGridOverlay()
	end
end

function ClientPlacer:bindInputs()
	ContextActionService:BindAction(PLACE_ACTION, function(...) return self:tryPlaceBlock(...) end, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction(ROTATE_ACTION, function(...) self:rotateBlock(...) end, false, Enum.KeyCode.R)
	ContextActionService:BindAction(CYCLE_ACTION, function(...) self:cycleBlock(...) end, false, Enum.KeyCode.E, Enum.KeyCode.Q)
	ContextActionService:BindAction(DELETE_ACTION, function(...) self:tryDeleteBlock(...) end, false, Enum.KeyCode.X)
	ContextActionService:BindAction(GRID_ACTION, function(...) self:toggleGrid(...) end, false, Enum.KeyCode.G)
end

function ClientPlacer:destroy()
	RunService:UnbindFromRenderStep(RENDER_NAME)
	ContextActionService:UnbindAction(PLACE_ACTION)
	ContextActionService:UnbindAction(ROTATE_ACTION)
	ContextActionService:UnbindAction(CYCLE_ACTION)
	ContextActionService:UnbindAction(DELETE_ACTION)
	ContextActionService:UnbindAction(GRID_ACTION)

	self:clearGridOverlay()
	if self.preview then
		self.preview:Destroy()
		self.preview = nil
	end
	self.selectionBox = nil
end

return ClientPlacer
