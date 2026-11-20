--!strict
local AnimController = {}

local trackCache: { [Model]: { [string]: AnimationTrack } } = {}

local function getAnimator(rig: Model): Animator?
	local animController = rig:FindFirstChildOfClass("AnimationController")
	if animController then
		local animator = animController:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animController
		end
		return animator
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	return nil
end

function AnimController.LoadAnimation(rig: Model, animName: string, animationId: string): AnimationTrack?
	if animationId == "" then
		return nil
	end

	local animator = getAnimator(rig)
	if not animator then
		return nil
	end

	local rigTracks = trackCache[rig]
	if not rigTracks then
		rigTracks = {}
		trackCache[rig] = rigTracks
		rig.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				trackCache[rig] = nil
			end
		end)
	end

	if rigTracks[animName] then
		return rigTracks[animName]
	end

	local animation = Instance.new("Animation")
	animation.Name = animName
	animation.AnimationId = animationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if ok and track then
		rigTracks[animName] = track
		return track
	end
	return nil
end

function AnimController.Play(rig: Model, animName: string, animationId: string, looped: boolean?, fadeTime: number?): AnimationTrack?
	local track = AnimController.LoadAnimation(rig, animName, animationId)
	if not track then
		return nil
	end
	if looped ~= nil then
		track.Looped = looped
	end
	if not track.IsPlaying then
		track:Play(fadeTime or 0.15)
	end
	return track
end

function AnimController.Stop(rig: Model, animName: string, fadeTime: number?)
	local rigTracks = trackCache[rig]
	local track = rigTracks and rigTracks[animName]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.15)
	end
end

function AnimController.ClearRig(rig: Model)
	local rigTracks = trackCache[rig]
	if rigTracks then
		for _, track in rigTracks do
			if track.IsPlaying then
				track:Stop(0)
			end
		end
		trackCache[rig] = nil
	end
end

return AnimController
