-- The emotes the wheel plays (the module keeps its old name: saved data and requires use it).

local Cosmetics = require(script.Parent.Cosmetics)

local QuickChat = {}

export type Emote = {
	id: string, -- the clip (Anim/Clips)
	name: string,
	item: string?, -- the shop item that unlocks it (Shared/Cosmetics); nil: everyone's
	pass: string?, -- a pass that unlocks it too (the Emote Pack's four)
	lobbyOnly: boolean?,
}

-- Emotes are clips from Blender (Anim/Clips), named by id. The first eleven are everyone's (the last two are
-- duos, played with the nearest player: Anim/EmoteMeta `duo`); the rest are
-- every emote in the shop's catalog, in its order (so a new emote is one entry in Shared/Cosmetics).
QuickChat.EMOTES = {
	{ id = "wave", name = "Wave" },
	{ id = "point", name = "Point" },
	{ id = "cheer", name = "Cheer" },
	{ id = "laugh", name = "Laugh" },
	{ id = "dance", name = "Dance" },
	{ id = "salute", name = "Salute" },
	{ id = "bow", name = "Bow" },
	{ id = "shrug", name = "Shrug" },
	{ id = "facepalm", name = "Facepalm" },
	{ id = "highFive", name = "High Five", lobbyOnly = true },
	{ id = "handshake", name = "Handshake", lobbyOnly = true },
} :: { Emote }

for _, item in ipairs(Cosmetics.ofKind("emote")) do
	table.insert(QuickChat.EMOTES, {
		id = item.emote,
		name = item.name,
		item = item.id,
		pass = item.pass,
		lobbyOnly = item.lobbyOnly,
	})
end

local byId: { [string]: Emote } = {}
for _, emote in ipairs(QuickChat.EMOTES) do
	byId[emote.id] = emote
end

-- The emote for a clip id, or nil.
function QuickChat.emote(id: string?): Emote?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

return QuickChat
