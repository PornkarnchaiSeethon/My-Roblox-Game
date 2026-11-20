--!strict
local CollectionService = game:GetService("CollectionService")
local DataService = require(script.Parent.Parent.DataService.DataService)

local EnemyController = {}

local registeredEnemies: { [Model]: boolean } = {}

local function isAliveEnemy(enemy: Model): boolean
	if not enemy.Parent then
		return false
	end
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health > 0
	end
	local hp = enemy:GetAttribute("HP")
	if type(hp) == "number" then
		return hp > 0
	end
	return false
end

local function getEnemyPosition(enemy: Model): Vector3?
	if enemy.PrimaryPart then
		return enemy.PrimaryPart.Position
	end
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return nil
end

function EnemyController.RegisterEnemy(enemy: Model)
	if not enemy:IsA("Model") or registeredEnemies[enemy] then
		return
	end
	registeredEnemies[enemy] = true
	enemy.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			registeredEnemies[enemy] = nil
		end
	end)
end

function EnemyController.UnregisterEnemy(enemy: Model)
	registeredEnemies[enemy] = nil
end

local function collectCandidates(): { Model }
	local seen: { [Model]: boolean } = {}
	local list: { Model } = {}

	for enemy in registeredEnemies do
		if not seen[enemy] then
			seen[enemy] = true
			table.insert(list, enemy)
		end
	end

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, child in enemiesFolder:GetChildren() do
			if child:IsA("Model") and not seen[child] then
				seen[child] = true
				table.insert(list, child)
			end
		end
	end

	for _, tagged in CollectionService:GetTagged("Enemy") do
		if tagged:IsA("Model") and not seen[tagged] then
			seen[tagged] = true
			table.insert(list, tagged)
		end
	end

	return list
end

function EnemyController.GetNearestEnemy(origin: Vector3, maxRange: number): Model?
	local bestEnemy: Model? = nil
	local bestDist = maxRange

	for _, enemy in collectCandidates() do
		if not isAliveEnemy(enemy) then
			continue
		end
		local pos = getEnemyPosition(enemy)
		if not pos then
			continue
		end
		local dist = (pos - origin).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestEnemy = enemy
		end
	end

	return bestEnemy
end

function EnemyController.ApplyPetDamage(player: Player, enemyModel: Model, damage: number): boolean
	if damage <= 0 or not isAliveEnemy(enemyModel) then
		return false
	end

	local defeated = false
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
		defeated = humanoid.Health <= 0
	else
		local hp = enemyModel:GetAttribute("HP")
		if type(hp) == "number" then
			local nextHp = math.max(0, hp - damage)
			enemyModel:SetAttribute("HP", nextHp)
			defeated = nextHp <= 0
		else
			return false
		end
	end

	if defeated then
		local expReward = enemyModel:GetAttribute("ExpReward")
		if type(expReward) == "number" and expReward > 0 then
			DataService.AddExp(player, expReward)
		end
		if not humanoid then
			enemyModel:Destroy()
		end
	end

	return true
end

return EnemyController
