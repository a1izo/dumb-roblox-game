-- Quick-chat phrases and emotes. Outside meetings these are the only way to talk.

local Terms = require(script.Parent.Terms)

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

-- Emotes are clips from Blender (Anim/Clips.luau), named by id. The first nine are everyone's; the
-- rest are gestures from the shop (`item`, Shared/Cosmetics), and the Emote Pack pass still unlocks
-- its four (`pass`).
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
	-- From the shop (the first four also with the Emote Pack pass)
	{ id = "dance2", name = "Groove", pass = "emotes", item = "emote_groove" },
	{ id = "dance3", name = "Spin", pass = "emotes", item = "emote_spin" },
	{ id = "chip", name = "Potato chip", pass = "emotes", item = "emote_chip" },
	{ id = "think", name = "Thinker", pass = "emotes", item = "emote_think" },
	{ id = "coinFlip", name = "Coin Flip", item = "emote_coin" },
	{ id = "appleBite", name = "Apple Bite", item = "emote_apple" },
	{ id = "puppetDance", name = "Puppet Dance", item = "emote_puppet" },
	{ id = "writeAir", name = "Write in the Air", item = "emote_air" },
	{ id = "aceCrouch", name = Terms.f("{Zero}'s Crouch"), item = "emote_crouch" },
}

return QuickChat
