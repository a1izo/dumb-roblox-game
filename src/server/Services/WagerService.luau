-- Death's wager on the server (the rules are Shared/Wager): Deathsingers bet on who Diavolo is and on who the
-- next vote removes. Vote calls are settled at each verdict, the Diavolo guess when the case closes. Winnings
-- go into the player's case stats (wagerCoins, wagersWon), so they are paid with the rest of the case's
-- rewards (RewardService) and count for the ghost quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Wager = require(Shared:WaitForChild("Wager"))

local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local WagerRemote = Net.event("Wager")

local WagerService = {}

local books: { [number]: Wager.Book } = {}

local function situation(): Wager.Situation
	local living, inCase = {}, {}
	for _, ps in ipairs(Match.list) do
		inCase[ps.userId] = true
		if ps.alive then
			living[ps.userId] = true
		end
	end
	return { active = Match.active, phase = Match.phase, round = Match.round, living = living, inCase = inCase }
end

local function isPlayer(ps): boolean
	return typeof(ps.player) == "Instance" and ps.player.Parent == Players
end

-- Tells a player their bets (what they guessed, what they have won so far).
local function push(ps)
	if not isPlayer(ps) then
		return
	end
	local book = books[ps.userId] or Wager.newBook()
	WagerRemote:FireClient(ps.player, {
		diavolo = book.diavolo,
		vote = book.votes[Match.round],
		round = Match.round,
		won = ps.stats.wagerCoins or 0,
		canDiavolo = not Match.isKiraSide(ps),
	})
end

local function onRequest(player: Player, payload: any)
	if type(payload) ~= "table" or not RateLimit.allow(player, "wager", 0.5) then
		return
	end
	local ps = Match.get(player)
	if not ps or not Match.active then
		return
	end
	if payload.action == "get" then
		push(ps)
		return
	end
	local kind = payload.kind
	local target = tonumber(payload.userId)
	if type(kind) ~= "string" or target == nil then
		return
	end
	local book = books[ps.userId]
	if not book then
		book = Wager.newBook()
		books[ps.userId] = book
	end
	local bettor = { dead = not ps.alive and ps.status ~= "left", kiraSide = Match.isKiraSide(ps) }
	local blocker = Wager.blocker(bettor, book, kind, target, situation(), ps.userId)
	if blocker then
		Match.notify(player, blocker, "bad")
		push(ps)
		return
	end
	if kind == "diavolo" then
		book.diavolo = target
	else
		book.votes[Match.round] = target
	end
	push(ps)
end

local function win(ps, coins: number, text: string)
	ps.stats.wagerCoins = (ps.stats.wagerCoins or 0) + coins
	ps.stats.wagersWon = (ps.stats.wagersWon or 0) + 1
	if isPlayer(ps) then
		Match.notify(ps.player, text, "good")
	end
end

-- At a verdict: `removedUserId` was voted out (nil when nobody was).
function WagerService.settleVote(removedUserId: number?)
	for userId, book in pairs(books) do
		local guess = book.votes[Match.round]
		local ps = Match.getByUserId(userId)
		if ps and guess ~= nil then
			if Wager.voteRight(guess, removedUserId) then
				win(
					ps,
					Wager.VOTE_COINS,
					string.format(
						"Death's wager: you called the vote. +%d coins when the case closes.",
						Wager.VOTE_COINS
					)
				)
			end
			push(ps)
		end
	end
end

-- When the case closes, before the rewards are paid.
function WagerService.settleCase()
	local diavolo = Match.findRole("Kira")
	for userId, book in pairs(books) do
		local ps = Match.getByUserId(userId)
		if ps and Wager.diavoloRight(book.diavolo, if diavolo then diavolo.userId else nil) then
			win(
				ps,
				Wager.DIAVOLO_COINS,
				string.format("Death's wager: you named Diavolo. +%d coins.", Wager.DIAVOLO_COINS)
			)
		end
	end
end

function WagerService.onMatchStart()
	books = {}
end

function WagerService.onMatchEnd()
	books = {}
end

function WagerService.init()
	WagerRemote.OnServerEvent:Connect(onRequest)
end

return WagerService
