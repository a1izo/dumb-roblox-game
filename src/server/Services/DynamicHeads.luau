-- An avatar's own head on an R6 body (2026-10-23). A modern avatar's head is a mesh with the face painted on it;
-- Roblox's R6 build has no such heads and gives the body its plain head with the default smile instead. This builds
-- the avatar as R15 once to borrow that head (its mesh and its picture), sizes it to an R6 head and puts it in the
-- plain head's place: named Head, held by the neck and by whatever held the plain one, holding all it held. The
-- plain head's face decal comes along, see-through: an emote's drawn face shows on it while the head's own picture
-- is put away for the emote (Controllers/EmoteController; ATTRIBUTE keeps the picture). Borrowed heads are kept per
-- head; an avatar whose head has no picture of its own keeps the plain head and its face.

local Players = game:GetService("Players")

local DynamicHeads = {}

DynamicHeads.ATTRIBUTE = "LHeadTexture" -- on a fitted head: its own picture

local HEIGHT = 1.2 -- studs, an R6 head as it is drawn (the plain head's mesh at 1.25 on a 1-stud part)

local borrowed: { [number]: MeshPart | false } = {}

-- The avatar's head as a MeshPart to copy (nil when its head has no picture of its own).
local function headOf(description: HumanoidDescription): MeshPart?
	local id = description.Head
	if id == 0 then
		return nil
	end
	local known = borrowed[id]
	if known ~= nil then
		return if known then known else nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	local head = if ok and model then model:FindFirstChild("Head") else nil
	local found: MeshPart | false = false
	if head and head:IsA("MeshPart") and head.TextureID ~= "" then
		head.Parent = nil
		-- (its face rig, its R15 joints and marks: the R6 body brings its own)
		for _, child in ipairs(head:GetChildren()) do
			child:Destroy()
		end
		for name in pairs(head:GetAttributes()) do
			if string.sub(name, 1, 3) ~= "RBX" then
				head:SetAttribute(name, nil)
			end
		end
		found = head
	end
	if ok and model then
		model:Destroy()
	end
	borrowed[id] = found
	return if found then found else nil
end

-- Puts the avatar's own head on `body` (an R6 body built from `description`, not yet in the world). True when it did.
function DynamicHeads.fit(body: Model, description: HumanoidDescription): boolean
	local plain = body:FindFirstChild("Head")
	if not plain or not plain:IsA("BasePart") then
		return false
	end
	local source = headOf(description)
	if not source or plain.Parent ~= body then
		return false
	end
	local head = source:Clone()
	head.Name = "Head"
	head.Size = source.Size * (HEIGHT / source.Size.Y)
	head.CFrame = plain.CFrame
	head.Color = plain.Color
	head.Anchored = plain.Anchored
	head.CanCollide = plain.CanCollide
	head.CanQuery = plain.CanQuery
	head.CanTouch = plain.CanTouch
	head.Massless = plain.Massless
	head.CollisionGroup = plain.CollisionGroup
	head:SetAttribute(DynamicHeads.ATTRIBUTE, head.TextureID)
	-- What the plain head held (its hair, hat and face attachments, its face decal), on the new one; its mesh goes.
	for _, child in ipairs(plain:GetChildren()) do
		if child:IsA("Decal") and child.Name == "face" then
			child.Transparency = 1
			child.Parent = head
		elseif not child:IsA("DataModelMesh") then
			child.Parent = head
		end
	end
	head.Parent = body
	-- and what held it (the neck, an accessory's weld) holds the new one, in the same place
	for _, joint in ipairs(body:GetDescendants()) do
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			if (joint :: any).Part0 == plain then
				(joint :: any).Part0 = head
			end
			if (joint :: any).Part1 == plain then
				(joint :: any).Part1 = head
			end
		end
	end
	plain:Destroy()
	return true
end

return DynamicHeads
