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

local function snapToGrid(pos: Vector3, gridSize: number): Vector3
	if gridSize <= 0 then
		return pos
	end
	return Vector3.new(
		math.round(pos.X / gridSize) * gridSize,
		pos.Y,
		math.round(pos.Z / gridSize) * gridSize
	)
end

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

function ClientPlacer.new(plot: Model)
	local objectsList = placeableObjects:GetChildren()
	assert(#objectsList > 0, "ReplicatedStorage.PlaceableObjects is empty")

	local self = setmetatable({
		plot = plot,
		objects = objectsList,
		objectIndex = 1,
		preview = nil :: Model?,
		selectionBox = nil :: SelectionBox?,
		rotation = 0,
		gridSize = 0,
	}, ClientPlacer)

	self:initiateRenderPreview()
	self:bindInputs()
	return self
end

function ClientPlacer:preparePreviewModel(model: Model)
	if self.preview then
		self.preview:Destroy()
	end

	local preview = model:Clone()
	for _, part in preview:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
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
	local cast = castMouse({ self.preview, character })
	if not cast then return end

	local snappedPos = snapToGrid(cast.Position, self.gridSize)
	local _, size = self.preview:GetBoundingBox()
	local finalPos = snappedPos + Vector3.new(0, size.Y / 2, 0)
	local targetCF = CFrame.new(finalPos) * CFrame.Angles(0, self.rotation, 0)
	self.preview:PivotTo(targetCF)

	local isValid = PlacementValidator.withinBounds(self.plot, size, targetCF)
		and PlacementValidator.noCollisions(self.plot, size, targetCF)
	if self.selectionBox then
		self.selectionBox.Color3 = if isValid
			then Color3.fromRGB(0, 255, 100)
			else Color3.fromRGB(255, 60, 60)
	end
end

function ClientPlacer:tryPlaceBlock(_, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin or not self.preview then return end
	Network.Plot.TryPlace.send({
		name = self.preview.Name,
		targetCF = self.preview:GetPivot(),
	})
end

function ClientPlacer:rotateBlock(_, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		self.rotation = (self.rotation + math.pi / 2) % (math.pi * 2)
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
		self.gridSize = if self.gridSize == 0 then 2 else 0
	end
end

function ClientPlacer:bindInputs()
	ContextActionService:BindAction(PLACE_ACTION, function(...) self:tryPlaceBlock(...) end, false, Enum.UserInputType.MouseButton1)
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

	if self.preview then
		self.preview:Destroy()
		self.preview = nil
	end
	self.selectionBox = nil
end

return ClientPlacer
