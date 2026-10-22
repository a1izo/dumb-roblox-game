-- Where emotes may play (Shared/EmotePolicy), pinned down: everything in the lobby; in a case never in a
-- cutscene, never a lobby-only emote or a duo, the waist up only at the meeting and the vote (and nothing there
-- that is legs, floor props or a walk), no stroll for a Deathsinger; effects small, loud sounds and the camera
-- off in a case; only the cutscenes everyone sees stop the case's emotes. And every emote's description
-- (Shared/EmoteInfo) agrees with its shop item.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))

-- A made-up emote: plain unless told otherwise.
local function info(overrides: { [string]: any }?): EmoteInfo.Info
	local made: any = {
		clip = "test",
		name = "Test",
		rarity = "common",
		lobbyOnly = false,
		duo = false,
		stroll = false,
		stance = false,
		floorProps = false,
		lowBody = false,
		cinematic = false,
		fx = 0,
		loud = false,
	}
	for key, value in pairs(overrides or {}) do
		made[key] = value
	end
	return made
end

local function at(phase: string, overrides: { [string]: any }?): EmotePolicy.Situation
	local made: any = { inCase = phase ~= "Lobby", phase = phase, deathsinger = false, cutscene = false }
	for key, value in pairs(overrides or {}) do
		made[key] = value
	end
	return made
end

-- Every phase a case goes through (Services/RoundService), and where plain emotes play in full.
local FULL = { Briefing = true, Investigation = true }
local PHASES = { "Intro", "Briefing", "Investigation", "Meeting", "Vote", "Verdict", "Outro", "Reveal" }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("EmotePolicy", function()
		it("lets everything play in the lobby", function()
			for _, flags in ipairs({
				{},
				{ lobbyOnly = true },
				{ duo = true },
				{ stroll = true },
				{ floorProps = true, lowBody = true },
				{ cinematic = true, fx = 4, loud = true },
			}) do
				local ok, reason, mask = EmotePolicy.check(info(flags), at("Lobby"))
				expect(ok).to.equal(true)
				expect(reason).to.equal(nil)
				expect(mask).to.equal(nil)
			end
		end)

		it(
			"plays a plain emote in full at the briefing, the investigation and the Death Note, never in a cutscene",
			function()
				for _, phase in ipairs(PHASES) do
					local ok, reason, mask = EmotePolicy.check(info(), at(phase))
					if FULL[phase] then
						expect(ok).to.equal(true)
						expect(mask).to.equal(nil)
					elseif EmotePolicy.SEATED_PHASES[phase] then
						expect(ok).to.equal(true)
						expect(mask).to.equal("upper")
					else
						expect(ok).to.equal(false)
						expect(reason).to.equal(EmotePolicy.REASONS.cutscene)
					end
				end
			end
		)

		it("stops for a cutscene everyone sees, in any phase", function()
			for _, phase in ipairs(PHASES) do
				local ok, reason = EmotePolicy.check(info(), at(phase, { cutscene = true }))
				expect(ok).to.equal(false)
				expect(reason).to.equal(EmotePolicy.REASONS.cutscene)
			end
		end)

		it("keeps lobby-only emotes and duos out of every case phase", function()
			for _, phase in ipairs(PHASES) do
				if not EmotePolicy.CUTSCENE_PHASES[phase] then
					local ok, reason = EmotePolicy.check(info({ lobbyOnly = true }), at(phase))
					expect(ok).to.equal(false)
					expect(reason).to.equal(EmotePolicy.REASONS.lobby)
					ok, reason = EmotePolicy.check(info({ duo = true }), at(phase))
					expect(ok).to.equal(false)
					expect(reason).to.equal(EmotePolicy.REASONS.duo)
					ok = EmotePolicy.check(info({ duo = true }), at(phase, { deathsinger = true }))
					expect(ok).to.equal(false)
				end
			end
		end)

		it("plays the waist up only at the meeting and the vote, and nothing there that needs the legs", function()
			for phase in pairs(EmotePolicy.SEATED_PHASES) do
				for _, flags in ipairs({ { stroll = true }, { floorProps = true }, { lowBody = true } }) do
					local ok, reason = EmotePolicy.check(info(flags), at(phase))
					expect(ok).to.equal(false)
					expect(reason).to.equal(EmotePolicy.REASONS.seated)
				end
				local _, _, mask = EmotePolicy.check(info({ fx = 3 }), at(phase))
				expect(mask).to.equal("upper")
			end
		end)

		it("never lets a Deathsinger stroll, and leaves their other emotes whole", function()
			local ok, reason = EmotePolicy.check(info({ stroll = true }), at("Investigation", { deathsinger = true }))
			expect(ok).to.equal(false)
			expect(reason).to.equal(EmotePolicy.REASONS.deathsinger)
			local fine, _, mask = EmotePolicy.check(info({ lowBody = true }), at("Meeting", { deathsinger = true }))
			expect(fine).to.equal(true)
			expect(mask).to.equal(nil)
		end)

		it("plays effects in full everywhere, keeps loud sounds quiet and the camera still in a case", function()
			for rung = 0, 4 do
				local emote = info({ fx = rung, loud = true })
				expect(EmotePolicy.fxRung(emote, at("Lobby"))).to.equal(rung)
				expect(EmotePolicy.fxRung(emote, at("Investigation"))).to.equal(rung)
			end
			expect(EmotePolicy.sound(info({ loud = true }), at("Lobby"))).to.equal(true)
			expect(EmotePolicy.sound(info({ loud = true }), at("Investigation"))).to.equal(false)
			expect(EmotePolicy.sound(info(), at("Investigation"))).to.equal(true)
			expect(EmotePolicy.camera(info({ cinematic = true }), at("Lobby"))).to.equal(true)
			expect(EmotePolicy.camera(info({ cinematic = true }), at("Briefing"))).to.equal(false)
		end)

		it("stops emotes for the cutscenes everyone sees, never for one player's own", function()
			for _, kind in ipairs({ "intro", "meetingIntro", "death", "arrest", "verdict", "outro" }) do
				expect(EmotePolicy.CUTSCENE_CUES[kind]).to.equal(true)
			end
			for _, kind in ipairs({ "eyesDeal", "handoff", "shot" }) do
				expect(EmotePolicy.CUTSCENE_CUES[kind]).to.equal(nil)
			end
		end)

		it("describes every shop emote as its item says", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				local emote = EmoteInfo.of(item.emote)
				expect(emote.item).to.equal(item)
				expect(emote.name).to.equal(item.name)
				expect(emote.rarity).to.equal(item.rarity)
				expect(emote.lobbyOnly).to.equal(item.lobbyOnly == true)
				expect(emote.duo).to.equal(item.duo == true)
				expect(emote.stroll).to.equal(item.stroll == true)
				expect(emote.fx >= 0 and emote.fx <= 4).to.equal(true)
				-- a duo is refused in a case, whatever else it is
				if emote.duo then
					expect((EmotePolicy.check(emote, at("Investigation")))).to.equal(false)
				end
			end
		end)

		it("puts every press-to-do moment inside its clip, with a branch to play", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				local context = EmoteInfo.of(item.emote).context
				if context then
					local clip = ClipPlayer.get(item.emote)
					expect(clip ~= nil).to.equal(true)
					expect(type(context.label) == "string" and #context.label > 0).to.equal(true)
					expect(context.from >= 0 and context.from < context.to).to.equal(true)
					expect(context.to <= (clip :: any).length).to.equal(true)
					expect(ClipPlayer.get(context.branch) ~= nil).to.equal(true)
					if context.alt then
						expect(ClipPlayer.get(context.alt) ~= nil).to.equal(true)
					end
				end
			end
		end)

		it("gives a group dance at most five places to join, on a loop", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				local places = EmoteInfo.of(item.emote).formation
				if places then
					expect(#places >= 1 and #places <= 5).to.equal(true)
					expect((ClipPlayer.get(item.emote) :: any).loop).to.equal(true)
					for _, place in ipairs(places) do
						expect(type(place[1]) == "number" and type(place[2]) == "number").to.equal(true)
					end
				end
			end
		end)

		it("times every sound cue inside its clip, the ids left as strings for the owner", function()
			for clip, cues in pairs(EmoteMedia.CUES) do
				local prepared = ClipPlayer.get(clip)
				expect(prepared ~= nil).to.equal(true)
				for _, cue in ipairs(cues) do
					expect(type(cue.id)).to.equal("string")
					expect(cue.at >= 0 and cue.at <= (prepared :: any).length).to.equal(true)
				end
			end
		end)
	end)
end
