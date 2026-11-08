-- One-shot (DGPass, read only): one line per script under the place's Rojo roots, "path=class=length:hash", so they
-- can be matched to the repo's history before anything is written. Removed again right after the pass.
if game.GameId ~= 10767766818 then
	return
end
local RunService = game:GetService("RunService")
if RunService:IsRunning() then
	return
end

local function h(s)
	local b = buffer.fromstring(s)
	local a, t = 1, 0
	for i = 0, buffer.len(b) - 1 do
		a = (a + buffer.readu8(b, i)) % 65521
		t = (t + a) % 65521
	end
	return buffer.len(b) .. ":" .. string.format("%d", t * 65536 + a)
end

local ROOTS = {
	{ "ReplicatedStorage", "Shared" },
	{ "ServerScriptService", "Server" },
	{ "StarterPlayer", "StarterPlayerScripts", "Client" },
	{ "ReplicatedFirst", "DGCover" },
	{ "StarterPlayer", "StarterCharacterScripts", "Animate" },
}

task.spawn(function()
	task.wait(10)
	local n = 0
	for _, root in ipairs(ROOTS) do
		local inst = game:GetService(root[1])
		for i = 2, #root do
			inst = inst and inst:WaitForChild(root[i], 90)
		end
		if not inst then
			print("[DGPASS] MISSING ROOT " .. table.concat(root, "."))
			continue
		end
		local list = { inst }
		for _, d in ipairs(inst:GetDescendants()) do
			table.insert(list, d)
		end
		for _, d in ipairs(list) do
			if d:IsA("LuaSourceContainer") then
				print("[DGPASS] S " .. d:GetFullName() .. "=" .. d.ClassName .. "=" .. h(d.Source))
				n += 1
				if n % 40 == 0 then
					task.wait()
				end
			end
		end
	end
	print("[DGPASS] read done " .. n)
end)
