--!strict
-- The swap-in registry. Every sound, animation, model and icon the game can use is listed
-- here by name. An empty id means "use the built-in fallback": silence for audio, the
-- procedural pose for animations, the part-built version for models.
--
-- To use your own assets:
--   audio / animations: upload them in Studio or on the Creator Dashboard and paste the id
--     ("rbxassetid://123..." or just the number) into the matching slot.
--   models: export them from Studio as .rbxm into assets/shared/Models (Rojo syncs that folder
--     to ReplicatedStorage.InkboundAssets.Models) and name the file after the key below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

export type Audio = {
	id: string, -- your upload
	ref: string, -- the track this slot was chosen for (a note, never loaded)
	fallbackId: string, -- used while id is empty, e.g. a licensed Creator Store track
	volume: number?,
}

-- Music slots. Roblox rejects uploads of copyrighted music, so an OST pick may never get an
-- id; fill fallbackId with a licensed track from the Creator Store in that case.
Assets.music = {
	lobby = { id = "", ref = "Black Souls: Dreaming Doll (M-ART)", fallbackId = "" },
	shop = { id = "", ref = "Deltarune Ch.1: Hip Shop", fallbackId = "" },
	training = { id = "", ref = "Deltarune Ch.1: Beginning", fallbackId = "" },
	intro = { id = "", ref = "Deltarune Ch.1: The Legend", fallbackId = "" },
	revealHand = { id = "", ref = "Deltarune Ch.1: ANOTHER HIM", fallbackId = "" },
	inv_TaskForceHQ = { id = "", ref = "OMORI: Lost Library", fallbackId = "" },
	inv_UniversityCampus = { id = "", ref = "Deltarune Ch.1: School", fallbackId = "" },
	inv_TokyoDistrict = { id = "", ref = "OMORI: Underwater Highway", fallbackId = "" },
	grimoire = { id = "", ref = "Black Souls: Grimoire (M-ART)", fallbackId = "" },
	meeting = { id = "", ref = "Deltarune Ch.3+4: Query?", fallbackId = "" },
	vote = { id = "", ref = "Deltarune Ch.3+4: Black Knife", fallbackId = "" },
	specter = { id = "", ref = "OMORI: WHITE SPACE", fallbackId = "" },
	winAgency = { id = "", ref = "Deltarune Ch.2: Powers Combined", fallbackId = "" },
	winHand = { id = "", ref = "Deltarune Ch.1: THE WORLD REVOLVING", fallbackId = "" },
	defeat = { id = "", ref = "Deltarune Ch.2: Faint Courage (Game Over)", fallbackId = "" },
	results = { id = "", ref = "Deltarune Ch.2: Until Next Time", fallbackId = "" },
} :: { [string]: Audio }

-- Sound effects. Roblox's own uploads in the Creator Store are free to use.
Assets.sfx = {
	uiClick = { id = "", ref = "soft click", fallbackId = "" },
	uiHover = { id = "", ref = "faint tick", fallbackId = "" },
	uiOpen = { id = "", ref = "paper slide", fallbackId = "" },
	toast = { id = "", ref = "short chime", fallbackId = "" },
	coin = { id = "", ref = "coin chime", fallbackId = "" },
	flashChime = { id = "", ref = "monitor beep", fallbackId = "" },
	pageTurn = { id = "", ref = "page turn", fallbackId = "" },
	penScratch = { id = "", ref = "pen scratching paper", fallbackId = "" },
	heartbeat = { id = "", ref = "single heartbeat", fallbackId = "" },
	flatline = { id = "", ref = "heart monitor flatline", fallbackId = "" },
	bell = { id = "", ref = "distant church bell", fallbackId = "" },
	gavel = { id = "", ref = "gavel strike", fallbackId = "" },
	handcuffs = { id = "", ref = "handcuffs click", fallbackId = "" },
	clockTick = { id = "", ref = "clock tick", fallbackId = "" },
	thunder = { id = "", ref = "rolling thunder", fallbackId = "" },
	rainLoop = { id = "", ref = "steady rain loop", fallbackId = "" },
	eyesOpen = { id = "", ref = "low whoosh with a whisper", fallbackId = "" },
	wisp = { id = "", ref = "soft ghostly chime", fallbackId = "" },
} :: { [string]: Audio }

-- Animations by pose id (see src/shared/Anim/Poses.luau). "" = the procedural pose. Every
-- client plays these from public events, on every character, so they must be poses anyone
-- could see anyway.
Assets.anim = {
	write = "",
	collapseHeart = "",
	collapseIllness = "",
	collapseFall = "",
	collapseTraffic = "",
	cuffed = "",
	slump = "",
	kneel = "",
	raiseHand = "",
	laugh = "",
	victory = "",
	defeat = "",
	specterFloat = "",
} :: { [string]: string }

-- The game-wide movement set (R15). Empty slots keep Roblox's defaults.
Assets.locomotion = {
	idle = "",
	idleAlt = "",
	walk = "",
	run = "",
	jump = "",
	fall = "",
	climb = "",
	swim = "",
	swimIdle = "",
} :: { [string]: string }

-- Catalog clothing for the noir outfit layer. Empty = the part-built suit and tie.
Assets.outfit = {
	shirt = "",
	pants = "",
} :: { [string]: string }

-- Placeholder glyphs until an icon sheet is uploaded; an image id replaces the glyph.
Assets.icons = {
	evidence = { glyph = "▤", image = "" },
	quickChat = { glyph = "✉", image = "" },
	note = { glyph = "✎", image = "" },
	eyes = { glyph = "◉", image = "" },
	desk = { glyph = "0", image = "" },
	vote = { glyph = "☐", image = "" },
	settings = { glyph = "⚙", image = "" },
	coin = { glyph = "¢", image = "" },
} :: { [string]: { glyph: string, image: string } }

-- "123" and "rbxassetid://123" both become "rbxassetid://123"; "" stays "".
function Assets.contentId(id: string): string
	if id == "" then
		return ""
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- The id to play for an audio slot, or nil while both the upload and the fallback are empty.
function Assets.audioId(entry: Audio?): string?
	if not entry then
		return nil
	end
	local id = if entry.id ~= "" then entry.id else entry.fallbackId
	if id == "" then
		return nil
	end
	return Assets.contentId(id)
end

-- A fresh copy of a model you exported to assets/shared/Models, or nil to build the fallback.
function Assets.model(key: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("InkboundAssets")
	local models = root and root:FindFirstChild("Models")
	local model = models and models:FindFirstChild(key)
	if model then
		return model:Clone()
	end
	return nil
end

return Assets
