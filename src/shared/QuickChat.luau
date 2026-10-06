-- Quick-chat phrases and emotes. Outside meetings these are the only way to talk.

local QuickChat = {}

QuickChat.PHRASES = {
	"Follow me",
	"Suspicious",
	"I'm working here",
	"Watch this station",
	"I saw something",
	"Where is everyone?",
	"Stay together",
	"Split up",
	"Trust me",
	"Help!",
	"Yes",
	"No",
}

-- Emotes are clips from Blender (Anim/Clips.luau), named by id. The Emote Pack pass unlocks the
-- showy ones.
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
	-- Emote Pack pass
	{ id = "dance2", name = "Groove", pass = "emotes" },
	{ id = "dance3", name = "Spin", pass = "emotes" },
	{ id = "chip", name = "Potato chip", pass = "emotes" },
	{ id = "think", name = "Thinker", pass = "emotes" },
}

return QuickChat
