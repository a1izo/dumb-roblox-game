-- Sharp accessories on R6 bodies (2026-10-23). An R6 body's accessories come as plain parts with a SpecialMesh, and
-- a body wearing those is drawn from one small packed texture: the owner saw every avatar blocky (the coat, the mask,
-- the shirt), while the same avatar built as R15, its accessories MeshParts, was sharp. Each such handle is rebuilt as
-- a MeshPart with the same mesh, texture, size and place (AssetService), its welds, attachments and values moved over
-- and its name kept ("Handle"), so the code that hides a hat or a body finds it as before; with none of the old kind
-- left, the body's own clothing and face come out sharp too. A mesh is fetched once and copied after that; one that
-- cannot be fetched keeps its old handle.

local AssetService = game:GetService("AssetService")

local CrispAccessories = {}

local templates: { [string]: MeshPart | false } = {}
local waiting: { [string]: { thread } } = {}

-- The mesh as a MeshPart to copy (nil when it cannot be had). A second ask while the first is fetching waits for it.
local function template(meshId: string): MeshPart?
	local known = templates[meshId]
	if known ~= nil then
		return if known then known else nil
	end
	local queue = waiting[meshId]
	if queue then
		table.insert(queue, coroutine.running())
		coroutine.yield()
		local now = templates[meshId]
		return if now then now else nil
	end
	waiting[meshId] = {}
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(meshId, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	templates[meshId] = if ok and part then part else false
	for _, thread in ipairs(waiting[meshId]) do
		task.spawn(thread)
	end
	waiting[meshId] = nil
	return if ok and part then part else nil
end

-- The old kind of handle: a Part shaped by a file mesh.
local function oldHandle(accessory: Instance): (BasePart?, SpecialMesh?)
	if not accessory:IsA("Accessory") then
		return nil, nil
	end
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("Part") then
		return nil, nil
	end
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if not mesh or mesh.MeshType ~= Enum.MeshType.FileMesh or mesh.MeshId == "" then
		return nil, nil
	end
	return handle, mesh
end

-- Rebuilds one accessory's handle as a MeshPart. True when it did.
local function sharpen(accessory: Accessory): boolean
	local handle, mesh = oldHandle(accessory)
	if not handle or not mesh then
		return false
	end
	local source = template(mesh.MeshId)
	-- (it may have changed while the mesh was fetched)
	if not source or handle.Parent ~= accessory or not mesh.Parent then
		return false
	end
	local part = source:Clone()
	part.Name = "Handle"
	part.TextureID = mesh.TextureId
	part.Size = part.MeshSize * mesh.Scale
	part.Color = handle.Color
	part.Material = handle.Material
	part.Reflectance = handle.Reflectance
	part.Transparency = handle.Transparency
	part.CastShadow = handle.CastShadow
	part.CollisionGroup = handle.CollisionGroup
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = handle.Anchored
	-- (a SpecialMesh's offset moves the mesh inside its part; the MeshPart is the mesh, so it moves instead)
	local shift = CFrame.new(mesh.Offset)
	part.CFrame = handle.CFrame * shift
	-- (the game's own marks carry over; Roblox's, RBX..., cannot be set by a game and are Roblox's to put back)
	for name, value in pairs(handle:GetAttributes()) do
		if string.sub(name, 1, 3) ~= "RBX" then
			pcall(part.SetAttribute, part, name, value)
		end
	end
	-- Nothing that could fail is left once the joints move: in the accessory first, so they never leave the body.
	part.Parent = accessory
	local body = accessory.Parent
	-- What holds it (wherever the joint lives: the handle's AccessoryWeld, or a weld on the body) now holds the new one.
	local held = false
	local scope = if body then body:GetDescendants() else handle:GetDescendants()
	for _, joint in ipairs(scope) do
		if joint:IsA("JointInstance") and (joint.Part0 == handle or joint.Part1 == handle) then
			if joint.Part0 == handle then
				joint.C0 = shift:Inverse() * joint.C0
				joint.Part0 = part
			else
				joint.C1 = shift:Inverse() * joint.C1
				joint.Part1 = part
			end
			held = true
		elseif joint:IsA("WeldConstraint") and (joint.Part0 == handle or joint.Part1 == handle) then
			if joint.Part0 == handle then
				joint.Part0 = part
			else
				joint.Part1 = part
			end
			held = true
		end
	end
	local own: Attachment? = nil
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") then
			child.CFrame = shift:Inverse() * child.CFrame
			child.Parent = part
			own = own or child
		elseif not child:IsA("DataModelMesh") then
			-- (a RigidConstraint holds it by the attachments, which move with it)
			held = held or child:IsA("RigidConstraint")
			child.Parent = part
		end
	end
	handle:Destroy()
	if not held and own and body then
		-- Not welded on yet (Roblox welds an accessory a moment after it lands, and not again for a new handle): the
		-- weld Roblox would make, from the handle's attachment to the body's of the same name.
		for _, mark in ipairs(body:GetDescendants()) do
			if
				mark:IsA("Attachment")
				and mark.Name == own.Name
				and mark ~= own
				and not mark:FindFirstAncestorOfClass("Accessory")
			then
				local at = mark.Parent
				if at and at:IsA("BasePart") then
					local weld = Instance.new("Weld")
					weld.Name = "AccessoryWeld"
					weld.Part0 = part
					weld.Part1 = at
					weld.C0 = own.CFrame
					weld.C1 = mark.CFrame
					weld.Parent = part
					break
				end
			end
		end
	end
	return true
end

-- (one that fails says why, in the Output, and keeps its old handle)
local function tryToSharpen(accessory: Accessory)
	local ok, err = pcall(sharpen, accessory)
	if not ok then
		warn("[DeathsGambit] Could not rebuild " .. accessory:GetFullName() .. " as a MeshPart: " .. tostring(err))
	end
end

-- Rebuilds every old-kind accessory handle the body wears, all at once, and returns when they are done (the meshes
-- fetched the first time only). A body that is not in the world yet works too (a rebuilt avatar before it is
-- shown, the Tokyo crowd's templates).
function CrispAccessories.sharpen(body: Model)
	local pending = 0
	local me = coroutine.running()
	local parked = false
	for _, item in ipairs(body:GetChildren()) do
		if oldHandle(item) then
			pending += 1
			task.spawn(function()
				tryToSharpen(item :: Accessory)
				pending -= 1
				if pending == 0 and parked then
					task.spawn(me)
				end
			end)
		end
	end
	if pending > 0 then
		parked = true
		coroutine.yield()
	end
end

-- For a body already in the world (an R6 avatar Roblox spawned itself, a test bot): what it wears now, and what it
-- puts on later (an avatar's accessories may arrive after the body, each welded on once it lands).
function CrispAccessories.watch(body: Model)
	task.spawn(CrispAccessories.sharpen, body)
	body.ChildAdded:Connect(function(child)
		if not child:IsA("Accessory") then
			return
		end
		task.delay(0.5, function()
			if child.Parent == body then
				tryToSharpen(child)
			end
		end)
	end)
end

return CrispAccessories
