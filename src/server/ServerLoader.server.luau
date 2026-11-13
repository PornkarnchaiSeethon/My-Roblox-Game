local ServerScriptService = game:GetService("ServerScriptService")

local Service = ServerScriptService.Services

local loaded = {}

for _, moduleScript in Service:GetDescendants() do
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

	if type(result.Init) == "function" then
		local initOk, err = pcall(result.Init)
		if not initOk then
			warn(`[Bootstrap] Init failed: {moduleScript.Name}\n{err}`)
			continue
		end
	end

	table.insert(loaded, { name = moduleScript.Name, module = result })
end

for _, entry in loaded do
	if type(entry.module.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(entry.module.Start)
			if not ok then
				warn(`[Bootstrap] Start failed: {entry.name}\n{err}`)
			end
		end)
	end
end
