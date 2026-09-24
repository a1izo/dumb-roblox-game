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

-- Emotes use the character's own Animate script when possible, with the default
-- Roblox animations as a fallback.
QuickChat.EMOTES = {
	{ id = "wave", name = "Wave", r15 = "rbxassetid://507770239", r6 = "rbxassetid://128777973" },
	{ id = "point", name = "Point", r15 = "rbxassetid://507770453", r6 = "rbxassetid://128853357" },
	{ id = "cheer", name = "Cheer", r15 = "rbxassetid://507770677", r6 = "rbxassetid://129423030" },
	{ id = "laugh", name = "Laugh", r15 = "rbxassetid://507770818", r6 = "rbxassetid://129423131" },
	{ id = "dance", name = "Dance", r15 = "rbxassetid://507771019", r6 = "rbxassetid://182435998" },
}

return QuickChat
