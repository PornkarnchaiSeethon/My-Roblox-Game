local PlacementValidator = {}

function PlacementValidator.withinBounds(plot: Model, objectSize: Vector3, worldCF: CFrame): boolean
	local primaryPart = plot.PrimaryPart
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

	for _, corner in corners do
		if math.abs(corner.X) > plotSize.X / 2 or math.abs(corner.Z) > plotSize.Z / 2 then
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
