--!strict
-- What the players' avatars do in cutscenes: activities for the intro vignettes (by the kind
-- of mark they stand on), reactions to deaths and verdicts, role reveals and endings. Every
-- pick is seeded from public data only (the match, the cue, user ids), never from roles, so
-- every screen shows the same thing and nobody learns anything from it.

local Activities = {}

export type Activity = {
	clip: string,
	props: { string },
	caption: string, -- what the vignette caption says they are doing
	outdoor: boolean?, -- only where there is open sky
}

-- mark kind -> what can be done there
Activities.BY_KIND = {
	desk = {
		{ clip = "taskWork", props = {}, caption = "going through the case files" },
		{ clip = "actMagnify", props = { "magnifier" }, caption = "studying the evidence" },
		{ clip = "actCabinet", props = {}, caption = "searching the records" },
		{ clip = "actThink", props = {}, caption = "thinking it over" },
	},
	stand = {
		{ clip = "actCoffee", props = { "cup" }, caption = "on a coffee break" },
		{ clip = "actPhone", props = { "phone" }, caption = "checking messages" },
		{ clip = "actReadFile", props = { "file" }, caption = "reading a file" },
		{ clip = "actLookAround", props = {}, caption = "keeping watch" },
		{ clip = "actStretch", props = {}, caption = "stretching" },
		{ clip = "actThink", props = {}, caption = "lost in thought" },
		{ clip = "actUmbrella", props = { "umbrella" }, caption = "waiting out the rain", outdoor = true },
	},
	seat = {
		{ clip = "sit", props = {}, caption = "taking a seat" },
		{ clip = "actNewspaper", props = { "newspaper" }, caption = "reading the evening paper" },
		{ clip = "actCrouchSweets", props = { "sweets" }, caption = "thinking, crouched on a chair" },
	},
	wall = {
		{ clip = "actLeanWall", props = {}, caption = "leaning on the wall" },
	},
} :: { [string]: { Activity } }

-- Reactions when someone dies or is voted out (one-shots that hold their last pose).
Activities.REACTIONS = {
	"reactGasp",
	"reactHandsHead",
	"reactCoverMouth",
	"reactLookAway",
	"reactStartle",
	"reactFacepalm",
	"reactShrug",
	"point",
}

-- Endings: winners and losers without a victory-pose cosmetic get one of these.
Activities.VICTORY = { "victory", "victoryFist", "victoryBow", "victoryCross", "cheer", "reactSlowClap" }
Activities.DEFEAT = { "defeat", "defeatFloor", "reactFacepalm", "reactHandsHead", "reactShrug" }

-- Private role reveals: clip, props, and whether the actor sits.
Activities.REVEAL = {
	Kira = { clip = "revealOpen", props = { "grimoire" }, after = "laugh" },
	Follower = { clip = "revealPray", props = { "candle" } },
	L = { clip = "actCrouchSweets", props = { "sweets" }, seat = true },
	Watari = { clip = "revealTip", props = { "umbrella" } },
	TaskForce = { clip = "revealBadge", props = { "badge" } },
} :: { [string]: { clip: string, props: { string }, after: string?, seat: boolean? } }

-- A deterministic pick for one person from a list.
function Activities.pick<T>(list: { T }, seed: number, userId: number): T
	local rng = Random.new((seed * 7919 + userId) % 2147483647)
	return list[rng:NextInteger(1, #list)]
end

return Activities
