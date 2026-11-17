--!strict
-- The VFX kit's textures by name ("VfxFlame", "VfxBurst"...; art/scripts/vfx/textures.py draws them): the id of each
-- one's carrier quad in the Fx props import (DeathsGambitModels_Fx.fbx, ModelLibrary.carrierTexture), or a stand-in
-- from Roblox's own particle textures until that file is imported. In the harness place (workspace attribute
-- DGVfxLocal) they are read from Studio's content folder, where the harness puts the PNGs, so play tests show the
-- real textures with nothing uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local Tex = {}

-- Roblox's own textures standing in until the import (the closest look each has).
local STAND_IN: { [string]: string } = {
	VfxFlame = "rbxasset://textures/particles/fire_main.dds",
	VfxCandleFlame = "rbxasset://textures/particles/fire_main.dds",
	VfxSmoke = "rbxasset://textures/particles/smoke_main.dds",
	VfxDust = "rbxasset://textures/particles/smoke_main.dds",
	VfxWisp = "rbxasset://textures/particles/smoke_main.dds",
}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- The new library's names (V1.1 to V1.6, in the Fx props file from ModelsFx 4) and the OLD texture each one wears while
-- the place has only ModelsFx 3: the closest look among the old names, so the live place never shows a sparkle while it
-- waits for the import. Every value is an old name (never another key here), so one step always ends at an old texture,
-- which is the real one when the place has the old file and a Roblox stand-in when it has nothing.
Tex.FALLBACK = {
	VfxSmokePuff = "VfxSmoke",
	VfxSmokePlume = "VfxSmoke",
	VfxDustRoll = "VfxDust",
	VfxMist = "VfxSmoke",
	VfxImpactA = "VfxBurst",
	VfxImpactB = "VfxBurst",
	VfxImpactC = "VfxBurst",
	VfxShock = "VfxRing",
	VfxGlint = "VfxFlare",
	VfxSparks = "VfxStreak",
	VfxSlashA = "VfxSlash",
	VfxSlashB = "VfxSlash",
	VfxArc = "VfxStreak",
	VfxEnergyWisp = "VfxWisp",
	VfxAshFlakes = "VfxAsh",
	VfxShards = "VfxChunk",
	VfxPaper = "VfxPage",
	VfxFeatherTumble = "VfxFeather",
	VfxCrackA = "VfxCrack",
	VfxCrackB = "VfxCrack",
	VfxScorch = "VfxSmoke",
	VfxSigil = "VfxCircle",
} :: { [string]: string }

local found: { [string]: string } = {}

-- The texture's id ("" for none at all).
function Tex.id(name: string): string
	if workspace:GetAttribute("DGVfxLocal") then
		return "rbxasset://textures/dg_vfx_harness/" .. name .. ".png"
	end
	local known = found[name]
	if known then
		return known
	end
	local id = ModelLibrary.carrierTexture(name)
	if id and id ~= "" then
		found[name] = id
		return id
	end
	local old = Tex.FALLBACK[name]
	if old then
		return Tex.id(old)
	end
	return STAND_IN[name] or SPARKLE
end

-- True when the real texture is there (imported, or the harness's), not a stand-in.
function Tex.real(name: string): boolean
	if workspace:GetAttribute("DGVfxLocal") then
		return true
	end
	if found[name] then
		return true
	end
	local id = ModelLibrary.carrierTexture(name)
	return id ~= nil and id ~= ""
end

return Tex
