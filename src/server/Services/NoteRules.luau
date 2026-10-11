--!strict
-- The rules for passing a note hand to hand, as pure checks (NoteService gathers the facts;
-- the spec tests every answer). A problem is a short code; nil means the pass may go ahead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NoteRules = {}

NoteRules.RANGE = Config.PASS_RANGE + 0.5 -- horizontal studs between the two, offering
NoteRules.ACCEPT_RANGE = Config.PASS_RANGE + 1.5 -- a little slack while the other decides
NoteRules.HEIGHT = 3 -- vertical studs (not across floors)

export type Facts = {
	phase: string,
	self: boolean, -- giver and receiver are the same player
	giverCarrying: string?, -- "note" / "blank" / nil
	burning: boolean, -- the note is being burned
	receiverLiving: boolean, -- living, in the match, not away
	receiverCarrying: string?,
	distance: number, -- horizontal studs
	height: number, -- vertical studs (absolute)
	giverPending: boolean, -- the giver already has an offer out
	receiverIncoming: boolean, -- the receiver already has an offer waiting
	cooldown: number, -- seconds until the giver may offer again (0 = now)
}

function NoteRules.offerProblem(f: Facts): string?
	if f.phase ~= "Investigation" then
		return "phase"
	elseif f.self then
		return "self"
	elseif f.giverCarrying ~= "note" then
		return "notCarrying"
	elseif f.burning then
		return "burning"
	elseif not f.receiverLiving then
		return "gone"
	elseif f.distance > NoteRules.RANGE or f.height > NoteRules.HEIGHT then
		return "tooFar"
	elseif f.receiverCarrying ~= nil then
		return "handsFull"
	elseif f.giverPending then
		return "giverBusy"
	elseif f.receiverIncoming then
		return "receiverBusy"
	elseif f.cooldown > 0 then
		return "cooldown"
	end
	return nil
end

export type AcceptFacts = {
	phase: string,
	expired: boolean,
	noteMoved: boolean, -- the giver no longer holds the offered note (dropped, burned, gone)
	receiverLiving: boolean,
	giverLiving: boolean,
	receiverCarrying: string?,
	distance: number,
	height: number,
}

function NoteRules.acceptProblem(f: AcceptFacts): string?
	if f.phase ~= "Investigation" then
		return "phase"
	elseif f.expired then
		return "expired"
	elseif f.noteMoved then
		return "noteMoved"
	elseif not f.giverLiving or not f.receiverLiving then
		return "gone"
	elseif f.receiverCarrying ~= nil then
		return "handsFull"
	elseif f.distance > NoteRules.ACCEPT_RANGE or f.height > NoteRules.HEIGHT then
		return "tooFar"
	end
	return nil
end

-- What each problem tells the player who asked.
NoteRules.MESSAGE = {
	phase = "Notes change hands only during the investigation.",
	self = "You already hold it.",
	notCarrying = "You are not holding a written note.",
	burning = "The note is burning.",
	gone = "They can't take it now.",
	tooFar = "Get closer to pass the note.",
	handsFull = "Their hands are full.",
	giverBusy = "You are already offering your note.",
	receiverBusy = "Someone is already offering them a note.",
	cooldown = "Wait a moment before offering again.",
	expired = "The offer ran out.",
	noteMoved = "The note is no longer offered.",
} :: { [string]: string }

return NoteRules
