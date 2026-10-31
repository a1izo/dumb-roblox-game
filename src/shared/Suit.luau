--!strict
-- The match suit, shared by the server (CharacterService dresses every body in a case) and this client's cutscenes
-- (Presentation/Stage: its copies of those bodies, and its faceless stand-in): what of an avatar comes off under the
-- suit, and the suit itself, fitted to a body part: the cloth, the shirt's cuffs and the hands, the tie.

local Create = require(script.Parent.Create)
local ModelLibrary = require(script.Parent.ModelLibrary)
local Models = require(script.Parent.Models)

local Suit = {}

-- Set on a dressed body (CharacterService.dressNoir); a copy of it carries it too.
Suit.DRESSED = "LNoirOutfit"
-- Set on the suit's own Shirt and Pants, which stay on.
Suit.OWN = "LSuitOwn"

-- The colours painted on the body under the cloth (and all a body shows before the Core import): a deep charcoal,
-- the trousers a shade darker, so the suit reads as a suit and not as a black box in a dark room (2026-10-27).
Suit.JACKET = Color3.fromRGB(46, 46, 52)
Suit.TROUSERS = Color3.fromRGB(38, 38, 43)
Suit.SHIRT = Color3.fromRGB(234, 232, 226)
Suit.TIE = Color3.fromRGB(190, 22, 36)
local CLIP = Color3.fromRGB(196, 198, 204)

local CLOTHING_ACCESSORIES = {
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
	[Enum.AccessoryType.DressSkirt] = true,
}

-- The attachments of the head: an accessory held by one of these (a hat, hair, glasses, a mask) stays on in a
-- match; anything worn on the body (a coat, a cape, wings, a belt, a scarf, a shoulder pet) comes off, whatever
-- its type says (old ones say Unknown). A rigid coat left on lay over the suit's cloth and the two cut through
-- each other at every move (2026-10-26).
local HEAD_ATTACHMENTS = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
}

local function onHead(accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	if not handle then
		return false
	end
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then
			return true
		end
	end
	return false
end

-- Does this child of a body come off under the suit? The avatar's clothing (classic and layered), its body
-- colours and everything it wears below the head, so no outfit can give anyone away; the suit's own pieces stay.
function Suit.offBody(item: Instance): boolean
	if item:GetAttribute(Suit.OWN) then
		return false
	end
	if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
		return true
	end
	return item:IsA("Accessory") and (CLOTHING_ACCESSORIES[item.AccessoryType] == true or not onHead(item))
end

-- How much larger each shell is than the part it covers (both sides together). Far enough off the body that no edge
-- of it comes within 0.02 studs of the cloth's rounded edges (whose bevel cuts into the margin); never the same for two
-- shells that touch, or their faces would lie in one plane and flicker where they meet (the jacket over a sleeve or a
-- trouser leg, one trouser leg against the other).
Suit.PAD = {
	Torso = 0.084,
	["Left Arm"] = 0.06,
	["Right Arm"] = 0.066,
	["Left Leg"] = 0.06,
	["Right Leg"] = 0.066,
}
local PAD_OTHER = 0.06
-- Each shell's base box, the body part it is cut for (its lapels, pockets and seams stand off this box): the game
-- sizes the box to the part, so the details keep their depth instead of shrinking the cloth into the body.
local SHELL_BASE = { SuitTorso = Vector3.new(2, 2, 1), SuitLimb = Vector3.new(1, 2, 1) }
local TROUSER_TINT = Color3.new(0.82, 0.82, 0.84)
-- How far the shirt front stands off the jacket's base box (props_gameplay.SHIRT_OUT): the tie lies on it.
local SHIRT_OUT = 0.012

local function absolute(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

-- The imported prop's meshes laid on `cframe` as the prop was made (upright, facing -Z: ModelLibrary has undone the
-- importer's turn), stretched along the body's own axes by `stretch` (each mesh's own axes may lie otherwise).
local function fitted(model: Model, cframe: CFrame, stretch: Vector3): { MeshPart }
	local pivot = model:GetPivot()
	local parts = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("MeshPart") then
			local rel = pivot:ToObjectSpace(item.CFrame)
			local turn = rel.Rotation
			item.Size = item.Size * absolute(turn:VectorToObjectSpace(stretch))
			item.CFrame = cframe * CFrame.new(rel.Position * stretch) * turn
			table.insert(parts, item)
		end
	end
	for _, item in ipairs(parts) do
		item.Parent = nil
	end
	model:Destroy()
	return parts
end

-- How much of an R6 arm's end is the hand: the sleeve stops this far short of it. Under the imported suit it is a
-- modelled fist (Suit.hand); before the import, a classic Roblox hand in the player's skin. Either way nothing
-- reaches past the arm's end (alizo, 2026-10-28: the fingered hands that hung below the arm went), so what a hand
-- holds sits in it; and the hands are a bit higher quality (the user, 2026-10-27, asked again 2026-10-29).
Suit.HAND = 0.7

-- The suit's cloth for one R6 part (the jacket for the Torso, a sleeve for an arm, a trouser leg for a leg), sized
-- and placed on it, not parented and not welded; none before the Core import carries it (Models.suit). A sleeve
-- stops Suit.HAND short of the arm's end, where the hand shows.
function Suit.cloth(part: BasePart): { BasePart }
	local key = if part.Name == "Torso" then "SuitTorso" else "SuitLimb"
	local tint = if string.find(part.Name, "Leg") then TROUSER_TINT else nil
	local shell = Models.suit(key)
	if not shell then
		return {}
	end
	local size, at = part.Size, part.CFrame
	if string.find(part.Name, "Arm") then
		size = Vector3.new(size.X, size.Y - Suit.HAND, size.Z)
		at = at * CFrame.new(0, Suit.HAND / 2, 0)
	end
	-- (the base box grows by the pad; what stands off it keeps its depth)
	local base = SHELL_BASE[key]
	local stretch = size / base + Vector3.one * (Suit.PAD[part.Name] or PAD_OTHER) / base
	local parts = fitted(shell, at, stretch)
	for _, item in ipairs(parts) do
		local look = item:FindFirstChildWhichIsA("SurfaceAppearance")
		if look and tint then
			look.Color = tint
		end
	end
	return parts :: any
end

-- Does the body wear the imported jacket (with the shirt front and collar on it), or only the painted torso?
function Suit.tailored(): boolean
	return ModelLibrary.has("SuitTorso") and ModelLibrary.has("SuitTie")
end

-- Colours a part, through its surface's tint when it has one (an imported mesh's texture is made pale to take it).
function Suit.paint(part: BasePart, colour: Color3)
	part.Color = colour
	local look = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if look then
		look.Color = colour
	end
end

local function piece(size: Vector3, colour: Color3, cframe: CFrame, material: Enum.Material?): Part
	return Create("Part", {
		Size = size,
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		CFrame = cframe,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
end

-- The shirt's cuff and the hand at the end of one sleeve (`arm` is "Left Arm" or "Right Arm"), the cuff a white
-- band just below the sleeve's end. With the imported suit, the Core import's fist (SuitHandL / SuitHandR,
-- art/scripts/props_gameplay.py: knuckles, the fingers curled under with their nails, the thumb laid across, a little
-- narrower than the sleeve) in the player's skin, its top at the cuff and its bottom at the arm's end; and the arm
-- itself goes see-through (its sleeve and this fist are the arm now: the painted block under them would box the hand
-- in). Before the import, a classic R6 hand: the arm's last Suit.HAND in the player's skin, a skin shell a hair over
-- the arm (so the suit-painted part under it never shows).
function Suit.hand(arm: BasePart, skin: Color3): { BasePart }
	local width, depth = arm.Size.X, arm.Size.Z
	local finish = arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0) -- the arm's end
	local pad = 0.03 -- (under the sleeve's own pad, over the arm's faces)
	local cuff = piece(
		Vector3.new(width + pad * 2.4, 0.09, depth + pad * 2.4),
		Suit.SHIRT,
		finish * CFrame.new(0, Suit.HAND - 0.045, 0)
	)
	cuff.Name = "Cuff"
	local key = if string.find(arm.Name, "Left") then "SuitHandL" else "SuitHandR"
	local fist = if ModelLibrary.has("SuitLimb") then ModelLibrary.get(key) else nil
	if fist then
		-- (made for an arm a stud wide; placed by its middle)
		local size = (ModelLibrary.size(key) or Vector3.new(0.84, 0.72, 0.96)) * width
		-- The cuff round the fist's wrist, just under the sleeve's end: as wide as the sleeve, with the arm see-through
		-- its underside showed as a white plate standing out past the hand (seen in a play test, 2026-10-31).
		cuff.Size = Vector3.new(size.X * 0.86, 0.11, size.Z * 0.9)
		cuff.CFrame = finish * CFrame.new(0, Suit.HAND - 0.055, 0)
		local parts: { BasePart } = { cuff }
		for _, item in ipairs(fitted(fist, finish * CFrame.new(0, Suit.HAND - size.Y / 2, 0), Vector3.one * width)) do
			item.Name = "Hand"
			Suit.paint(item, skin)
			table.insert(parts, item)
		end
		arm.Transparency = 1
		return parts
	end
	local hand = piece(
		Vector3.new(width + pad, Suit.HAND, depth + pad),
		skin,
		finish * CFrame.new(0, Suit.HAND / 2 - pad / 4, 0)
	)
	hand.Name = "Hand"
	return { cuff, hand }
end

-- Repaints the hands under "holder" (a body's LHandLeft / LHandRight) in a skin that arrived late; the cuffs stay white.
function Suit.reskin(holder: Instance, skin: Color3)
	for _, item in ipairs(holder:GetChildren()) do
		if item:IsA("BasePart") and item.Name == "Hand" then
			Suit.paint(item, skin)
		end
	end
end

-- The shirt and tie on the front of a torso, in `colour` (the Tokyo crowd's looks bring their own): the tailored
-- Windsor tie with its dimple and silver clip, lying on the jacket's shirt front (the Core import's SuitTie); before
-- the import, a shirt front, a collar and a tie built of parts on the painted torso.
function Suit.tie(torso: BasePart, colour: Color3?): { BasePart }
	local tint = colour or Suit.TIE
	local top = torso.Size.Y / 2
	local model = if Suit.tailored() then ModelLibrary.get("SuitTie") else nil
	if model then
		local pad = Suit.PAD.Torso / 2
		local shirt = -torso.Size.Z / 2 - pad - SHIRT_OUT * (1 + Suit.PAD.Torso)
		local size = ModelLibrary.size("SuitTie") or Vector3.new(0.3, 1.1, 0.12)
		-- the knot just under the collar, the tie's back on the shirt
		local at = torso.CFrame * CFrame.new(0, top + pad - 0.06 - size.Y / 2, shirt - 0.004 - size.Z / 2)
		local parts = fitted(model, at, Vector3.one)
		for _, item in ipairs(parts) do
			-- (the silver clip is a piece of its own, never dyed)
			if not string.find(item.Name, "Clip") then
				Suit.paint(item, tint)
			end
		end
		return parts :: any
	end
	local front = -torso.Size.Z / 2
	return {
		piece(Vector3.new(0.55, 0.75, 0.05), Suit.SHIRT, torso.CFrame * CFrame.new(0, top - 0.4, front - 0.01)),
		piece(Vector3.new(0.6, 0.12, 0.08), Suit.SHIRT, torso.CFrame * CFrame.new(0, top - 0.05, front - 0.02)),
		piece(
			Vector3.new(0.22, 0.16, 0.08),
			tint:Lerp(Color3.new(0, 0, 0), 0.15),
			torso.CFrame * CFrame.new(0, top - 0.2, front - 0.06),
			Enum.Material.Fabric
		),
		piece(
			Vector3.new(0.2, 0.95, 0.05),
			tint,
			torso.CFrame * CFrame.new(0, top - 0.75, front - 0.06),
			Enum.Material.Fabric
		),
		piece(
			Vector3.new(0.3, 0.035, 0.03),
			CLIP,
			torso.CFrame * CFrame.new(0, top - 0.78, front - 0.1),
			Enum.Material.Metal
		),
	}
end

return Suit
