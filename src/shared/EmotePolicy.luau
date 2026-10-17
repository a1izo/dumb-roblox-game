--!strict
-- Where an emote may play, decided in one place (the server enforces it; the wheel greys out and explains what
-- it refuses; the specs pin it down). Outside a case everything plays. In a case:
--   - never during a cutscene (the intro, a death, an arrest, the verdict, the ending), nor a lobby-only emote
--     (it looks like a game signal), nor a duo;
--   - at the meeting and the vote everyone stands at a seat: only the waist up plays ("upper"), and nothing
--     that is mostly legs, sets something on the floor, or walks;
--   - a Deathsinger never strolls;
--   - effects are kept small (no flashes, no shake), loud sounds and camera moves stay off.
-- Pure: it takes what it needs and returns its answer, so the client, the server and the tests agree.

local EmoteInfo = require(script.Parent.EmoteInfo)

local EmotePolicy = {}

export type Situation = {
	inCase: boolean, -- taking part in a case (a player or a Deathsinger), not in the lobby
	phase: string, -- the case's phase ("Lobby" outside one)
	deathsinger: boolean, -- dead in this case: a Deathsinger
	cutscene: boolean, -- a cutscene everyone sees is playing
}

EmotePolicy.CUTSCENE_PHASES = { Intro = true, Verdict = true, Outro = true, Reveal = true } :: { [string]: boolean }
EmotePolicy.SEATED_PHASES = { Meeting = true, Vote = true } :: { [string]: boolean }
-- The cues (Services/Cues) of the cutscenes everyone sees: each stops every emote in the case. A cue only one
-- player sees (the Eyes deal) never does: everyone's emotes stopping at once would give it away.
EmotePolicy.CUTSCENE_CUES =
	{ intro = true, death = true, arrest = true, verdict = true, outro = true } :: { [string]: boolean }

EmotePolicy.REASONS = {
	cutscene = "Not during a cutscene",
	lobby = "Lobby only",
	duo = "Duos are for the lobby",
	seated = "Not while seated",
	deathsinger = "Not as a Deathsinger",
}

-- (allowed, why not, mask): the mask is "upper" when only the waist up may play.
function EmotePolicy.check(info: EmoteInfo.Info, at: Situation): (boolean, string?, string?)
	if not at.inCase then
		return true, nil, nil
	end
	if at.cutscene or EmotePolicy.CUTSCENE_PHASES[at.phase] then
		return false, EmotePolicy.REASONS.cutscene, nil
	end
	if info.lobbyOnly then
		return false, EmotePolicy.REASONS.lobby, nil
	end
	if info.duo then
		return false, EmotePolicy.REASONS.duo, nil
	end
	if at.deathsinger then
		if info.stroll then
			return false, EmotePolicy.REASONS.deathsinger, nil
		end
		return true, nil, nil
	end
	if EmotePolicy.SEATED_PHASES[at.phase] then
		if info.stroll or info.floorProps or info.lowBody then
			return false, EmotePolicy.REASONS.seated, nil
		end
		return true, nil, "upper"
	end
	return true, nil, nil
end

-- How strong the effects may be here (0..4): in a case at most one small accent.
function EmotePolicy.fxRung(info: EmoteInfo.Info, at: Situation): number
	if at.inCase then
		return math.min(info.fx, 1)
	end
	return info.fx
end

-- May its sound play here (a loud one never in a case)?
function EmotePolicy.sound(info: EmoteInfo.Info, at: Situation): boolean
	return not (at.inCase and info.loud)
end

-- May the emoter's own camera move with it (the showpiece camera, a private cutscene)? In the lobby only.
function EmotePolicy.camera(_info: EmoteInfo.Info, at: Situation): boolean
	return not at.inCase
end

return EmotePolicy
