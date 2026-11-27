--!strict

local RunService = game:GetService("RunService")

local AnimController = {}

type RigCache = {
	Tracks: { [string]: AnimationTrack },
	CurrentState: string?,
	ActionLockedUntil: number,
	CleanupConn: RBXScriptConnection?,
}

local PRIORITY_BY_KEY: { [string]: Enum.AnimationPriority } = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	Attack = Enum.AnimationPriority.Action,
	SkillWindup = Enum.AnimationPriority.Action2,
	SkillCast = Enum.AnimationPriority.Action3,
	Hit = Enum.AnimationPriority.Action2,
	Death = Enum.AnimationPriority.Action4,
}

local LOOPED_KEYS: { [string]: boolean } = {
	Idle = true,
	Walk = true,
}

local rigCaches: { [Model]: RigCache } = {}

local function getOrCreateCache(rig: Model): RigCache
	local existing = rigCaches[rig]
	if existing then
		return existing
	end

	local cache: RigCache = {
		Tracks = {},
		CurrentState = nil,
		ActionLockedUntil = 0,
		CleanupConn = nil,
	}
	rigCaches[rig] = cache

	cache.CleanupConn = rig.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			AnimController.CleanupRig(rig)
		end
	end)

	return cache
end

function AnimController.ResolveAnimator(rig: Model): Animator?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local animController = rig:FindFirstChildOfClass("AnimationController")
	if not animController then
		animController = Instance.new("AnimationController")
		animController.Parent = rig
	end

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animController
	end
	return animator
end

function AnimController.LoadTrack(rig: Model, animKey: string, animationId: string): AnimationTrack?
	if type(animationId) ~= "string" or animationId == "" or animationId == "rbxassetid://0" then
		return nil
	end

	local animator = AnimController.ResolveAnimator(rig)
	if not animator then
		return nil
	end

	local cache = getOrCreateCache(rig)
	local cacheKey = animKey .. "|" .. animationId
	if cache.Tracks[cacheKey] then
		return cache.Tracks[cacheKey]
	end

	local animation = Instance.new("Animation")
	animation.Name = animKey
	animation.AnimationId = animationId

	local ok, track = pcall(function(): AnimationTrack
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if ok and track then
		local priority = PRIORITY_BY_KEY[animKey]
		if priority then
			track.Priority = priority
		end
		track.Looped = LOOPED_KEYS[animKey] == true
		cache.Tracks[cacheKey] = track
		return track
	end

	return nil
end

function AnimController.PlayState(
	rig: Model,
	animKey: string,
	animMap: { [string]: string }?,
	fadeTime: number?,
	speed: number?,
	lockDuration: number?,
	onMarker: ((string) -> ())?
): AnimationTrack?
	local cache = getOrCreateCache(rig)
	local now = os.clock()

	if animKey ~= "Death" and LOOPED_KEYS[animKey] and now < cache.ActionLockedUntil then
		return nil
	end

	if LOOPED_KEYS[animKey] and cache.CurrentState == animKey then
		return nil
	end

	cache.CurrentState = animKey
	if lockDuration and lockDuration > 0 then
		cache.ActionLockedUntil = now + lockDuration
	elseif animKey == "Death" then
		cache.ActionLockedUntil = now + 10
	end

	if RunService:IsServer() and rig:GetAttribute("AnimState") ~= animKey then
		rig:SetAttribute("AnimState", animKey)
	end

	local resolvedFade = fadeTime or 0.18
	local animId = if animMap then animMap[animKey] else nil
	if type(animId) ~= "string" or animId == "" or animId == "rbxassetid://0" then
		for _, otherTrack in cache.Tracks do
			if otherTrack.IsPlaying and LOOPED_KEYS[animKey] then
				otherTrack:Stop(resolvedFade)
			end
		end
		return nil
	end

	local track = AnimController.LoadTrack(rig, animKey, animId)
	if not track then
		return nil
	end

	for _, otherTrack in cache.Tracks do
		if otherTrack ~= track and otherTrack.IsPlaying and LOOPED_KEYS[animKey] then
			otherTrack:Stop(resolvedFade)
		end
	end

	track:Play(resolvedFade, 1, speed or 1)

	if onMarker then
		local fired = false
		local markerConn: RBXScriptConnection? = nil
		local stoppedConn: RBXScriptConnection? = nil

		markerConn = track:GetMarkerReachedSignal("HitFrame"):Connect(function(param: string)
			if fired then
				return
			end
			fired = true
			if markerConn then
				markerConn:Disconnect()
				markerConn = nil
			end
			if stoppedConn then
				stoppedConn:Disconnect()
				stoppedConn = nil
			end
			onMarker(param)
		end)

		stoppedConn = track.Stopped:Once(function()
			if markerConn then
				markerConn:Disconnect()
				markerConn = nil
			end
			stoppedConn = nil
		end)
	end

	return track
end

function AnimController.StopAll(rig: Model, fadeTime: number?)
	local cache = rigCaches[rig]
	if not cache then
		return
	end

	local resolvedFade = fadeTime or 0.18
	for _, track in cache.Tracks do
		if track.IsPlaying then
			track:Stop(resolvedFade)
		end
	end
	cache.CurrentState = nil
	cache.ActionLockedUntil = 0
end

function AnimController.CleanupRig(rig: Model)
	local cache = rigCaches[rig]
	if not cache then
		return
	end

	if cache.CleanupConn then
		cache.CleanupConn:Disconnect()
		cache.CleanupConn = nil
	end

	for _, track in cache.Tracks do
		pcall(function()
			if track.IsPlaying then
				track:Stop(0)
			end
			track:Destroy()
		end)
	end

	rigCaches[rig] = nil
end

function AnimController.LoadAnimation(rig: Model, animName: string, animationId: string): AnimationTrack?
	return AnimController.LoadTrack(rig, animName, animationId)
end

function AnimController.Play(
	rig: Model,
	animName: string,
	animationId: string,
	looped: boolean?,
	fadeTime: number?
): AnimationTrack?
	local track = AnimController.LoadTrack(rig, animName, animationId)
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
	local cache = rigCaches[rig]
	if not cache then
		return
	end
	local prefix = animName .. "|"
	local resolvedFade = fadeTime or 0.15
	for key, track in cache.Tracks do
		if string.sub(key, 1, #prefix) == prefix and track.IsPlaying then
			track:Stop(resolvedFade)
		end
	end
end

function AnimController.ClearRig(rig: Model)
	AnimController.CleanupRig(rig)
end

return AnimController
