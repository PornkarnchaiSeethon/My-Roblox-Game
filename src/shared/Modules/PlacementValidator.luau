local PlacementValidator = {}

PlacementValidator.DEFAULT_GRID_SIZE = 2
PlacementValidator.SERVER_GRID_SIZE = 1
PlacementValidator.GRID_PRESETS = { 2, 4, 1 }

local BOUNDS_EPSILON = 0.01
local QUARTER_TURN = math.pi / 2

local function getPlotPrimaryPart(plot: Model): BasePart?
	return plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
end

local function getRotatedFootprint(objectSize: Vector3, rotationIndex: number): (number, number)
	if (rotationIndex % 2) == 1 then
		return objectSize.Z, objectSize.X
	end
	return objectSize.X, objectSize.Z
end

function PlacementValidator.getPlotFloorLocalY(plot: Model): number
	local primaryPart = getPlotPrimaryPart(plot)
	if not primaryPart then
		return 0
	end
	local localPrimaryPos = plot:GetPivot():PointToObjectSpace(primaryPart.Position)
	return localPrimaryPos.Y + primaryPart.Size.Y * 0.5
end

function PlacementValidator.snapPositionToGrid(
	plot: Model,
	objectSize: Vector3,
	worldPos: Vector3,
	rotationIndex: number,
	gridSize: number?
): CFrame
	local plotCF = plot:GetPivot()
	local primaryPart = getPlotPrimaryPart(plot)
	local step = math.round(rotationIndex) % 4
	local localPos = plotCF:PointToObjectSpace(worldPos)
	local resolvedGrid = if typeof(gridSize) == "number" and gridSize > 0
		then gridSize
		else PlacementValidator.DEFAULT_GRID_SIZE

	local snappedX = localPos.X
	local snappedZ = localPos.Z
	if primaryPart then
		local plotSize = primaryPart.Size
		local footX, footZ = getRotatedFootprint(objectSize, step)
		local originX = -plotSize.X * 0.5 + footX * 0.5
		local originZ = -plotSize.Z * 0.5 + footZ * 0.5
		snappedX = originX + math.round((localPos.X - originX) / resolvedGrid) * resolvedGrid
		snappedZ = originZ + math.round((localPos.Z - originZ) / resolvedGrid) * resolvedGrid
	else
		snappedX = math.round(localPos.X / resolvedGrid) * resolvedGrid
		snappedZ = math.round(localPos.Z / resolvedGrid) * resolvedGrid
	end

	local localY = PlacementValidator.getPlotFloorLocalY(plot) + objectSize.Y * 0.5
	local localCF = CFrame.new(snappedX, localY, snappedZ) * CFrame.Angles(0, step * QUARTER_TURN, 0)
	return plotCF:ToWorldSpace(localCF)
end

function PlacementValidator.snapCFrameToGrid(
	plot: Model,
	objectSize: Vector3,
	worldCF: CFrame,
	gridSize: number?
): CFrame
	local localCF = plot:GetPivot():ToObjectSpace(worldCF)
	local _, yaw, _ = localCF:ToEulerAnglesYXZ()
	local rotationIndex = math.round(yaw / QUARTER_TURN) % 4
	return PlacementValidator.snapPositionToGrid(plot, objectSize, worldCF.Position, rotationIndex, gridSize)
end

function PlacementValidator.withinBounds(plot: Model, objectSize: Vector3, worldCF: CFrame): boolean
	local primaryPart = getPlotPrimaryPart(plot)
	if not primaryPart then
		return false
	end

	local localCF = plot:GetPivot():ToObjectSpace(worldCF)
	local plotSize = primaryPart.Size
	local halfX, halfZ = objectSize.X / 2, objectSize.Z / 2

	local corners = {
		localCF:PointToWorldSpace(Vector3.new(halfX, 0, halfZ)),
		localCF:PointToWorldSpace(Vector3.new(-halfX, 0, halfZ)),
		localCF:PointToWorldSpace(Vector3.new(halfX, 0, -halfZ)),
		localCF:PointToWorldSpace(Vector3.new(-halfX, 0, -halfZ)),
	}

	local limitX = plotSize.X / 2 + BOUNDS_EPSILON
	local limitZ = plotSize.Z / 2 + BOUNDS_EPSILON
	for _, corner in corners do
		if math.abs(corner.X) > limitX or math.abs(corner.Z) > limitZ then
			return false
		end
	end

	return true
end

function PlacementValidator.noCollisions(plot: Model, objectSize: Vector3, worldCF: CFrame): boolean
	local objects = plot:FindFirstChild("Objects")
	if not objects then
		return false
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { objects }

	local parts = workspace:GetPartBoundsInBox(worldCF, objectSize * 0.98, params)
	return #parts == 0
end

return PlacementValidator
