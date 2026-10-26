--!strict
-- The match suit, shared by the server (CharacterService dresses every body in a case) and this client's cutscenes
-- (Presentation/Stage: its copies of those bodies, and its faceless stand-in): what of an avatar comes off under the
-- suit, and the cloth itself, fitted to a body part.

local Models = require(script.Parent.Models)

local Suit = {}

-- Set on a dressed body (CharacterService.dressNoir); a copy of it carries it too.
Suit.DRESSED = "LNoirOutfit"
-- Set on the suit's own Shirt and Pants, which stay on.
Suit.OWN = "LSuitOwn"

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

-- The cloth shells are this much larger than the part they cover, and the trousers' this much darker.
local CLOTH_PAD = 0.03
-- Each shell's base box, the body part it is cut for (its lapels, pockets and seams stand off this box): the game
-- sizes the box to the part, so the details keep their depth instead of shrinking the cloth into the body.
local SHELL_BASE = { SuitTorso = Vector3.new(2, 2, 1), SuitLimb = Vector3.new(1, 2, 1) }
local TROUSER_TINT = Color3.new(0.8, 0.8, 0.82)

-- The suit's cloth for one R6 part (the jacket for the Torso, a sleeve for an arm, a trouser leg for a leg), sized
-- and placed on it, not parented and not welded; none before the Core import carries it (Models.suit).
function Suit.cloth(part: BasePart): { BasePart }
	local key = if part.Name == "Torso" then "SuitTorso" else "SuitLimb"
	local tint = if string.find(part.Name, "Leg") then TROUSER_TINT else nil
	local shell = Models.suit(key)
	if not shell then
		return {}
	end
	local fit = part.Size / SHELL_BASE[key]
	local pad = Vector3.new(CLOTH_PAD, CLOTH_PAD, CLOTH_PAD)
	local parts = {}
	for _, item in ipairs(shell:GetDescendants()) do
		if item:IsA("MeshPart") then
			local ok, native = pcall(function()
				return item.MeshSize
			end)
			item.Size = if ok and native.Magnitude > 0 then native * fit + pad else part.Size + pad
			item.CFrame = part.CFrame
			local look = item:FindFirstChildWhichIsA("SurfaceAppearance")
			if look and tint then
				look.Color = tint
			end
			table.insert(parts, item)
		end
	end
	for _, item in ipairs(parts) do
		item.Parent = nil
	end
	shell:Destroy()
	return parts
end

return Suit
