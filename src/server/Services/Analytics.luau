-- Roblox analytics: the onboarding funnel and every coin coming in or going out. Shown on
-- the Creator Dashboard (Analytics > Funnels / Economy). Every call is safe: failures and
-- Studio play tests are ignored.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

-- The first-session funnel, in order.
Analytics.STEPS = {
	joined = { 1, "Joined the lobby" },
	ready = { 2, "Pressed READY" },
	matchStarted = { 3, "First match started" },
	matchFinished = { 4, "First match finished" },
	academy = { 5, "Finished the Academy" },
	firstWin = { 6, "First win" },
}

local ENABLED = not RunService:IsStudio()

function Analytics.step(player: Player, key: string)
	local step = Analytics.STEPS[key]
	if not ENABLED or not step then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step[1], step[2])
	end)
end

-- Coins in (source) or out (sink). kind: "Gameplay", "IAP", "Shop", "TimedReward" or
-- "Onboarding"; sku names what it was for.
function Analytics.coins(player: Player, amount: number, balance: number, kind: string, sku: string?)
	if not ENABLED or amount == 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			if amount > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",
			math.abs(amount),
			balance,
			kind,
			sku
		)
	end)
end

function Analytics.init()
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		Analytics.step(player, "joined")
	end)
end

return Analytics
