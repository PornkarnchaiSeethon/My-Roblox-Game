local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("knit"))
local ServicesFolder = ServerScriptService:WaitForChild("Services")

local legacyModules = {}

for _, moduleScript in ServicesFolder:GetDescendants() do
	if not moduleScript:IsA("ModuleScript") then
		continue
	end

	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(`[Bootstrap] require failed: {moduleScript:GetFullName()}\n{result}`)
		continue
	end

	if type(result) ~= "table" then
		continue
	end

	local isKnitService = type(result.Name) == "string" and result.KnitComm ~= nil
	if not isKnitService and (type(result.Init) == "function" or type(result.Start) == "function") then
		table.insert(legacyModules, { name = moduleScript.Name, module = result })
	end
end

for _, entry in legacyModules do
	if type(entry.module.Init) == "function" then
		local ok, err = pcall(entry.module.Init)
		if not ok then
			warn(`[Bootstrap] Legacy Init failed: {entry.name}\n{err}`)
		end
	end
end

Knit.Start()
	:andThen(function()
		for _, entry in legacyModules do
			if type(entry.module.Start) == "function" then
				task.spawn(function()
					local ok, err = pcall(entry.module.Start)
					if not ok then
						warn(`[Bootstrap] Legacy Start failed: {entry.name}\n{err}`)
					end
				end)
			end
		end
	end)
	:catch(function(err)
		warn(`[Bootstrap] Knitserver Start failed:\n{err}`)
	end)
