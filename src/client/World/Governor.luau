--!strict
-- Lightens the game by itself when frames run slow (Shared/GovernorRules says when, and in what
-- order). The Low graphics setting still switches everything at once; this adds cuts of its own on a
-- device that needs them, without the player having to find the setting, and takes them back
-- between rounds, never during one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GovernorRules = require(Shared:WaitForChild("GovernorRules"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local Governor = {}

-- Fired with the new step whenever a cut is made or the cuts are taken back.
Governor.Changed = Signal.new()

local state = GovernorRules.new()
local forced: number? = nil

function Governor.step(): number
	return forced or state.step
end

-- True when the governor itself has cut `what`: "particles", "glow", "shadows", "crowd" or "prints".
function Governor.cut(what: string): boolean
	return GovernorRules.cut(Governor.step(), what)
end

-- True when `what` should be lightened: the Low graphics setting, or a cut of the governor's.
function Governor.low(what: string): boolean
	return Settings.get("lowGraphics") == true or Governor.cut(what)
end

-- Debug: holds the governor at a step (0 to 5), or lets it measure again (nil).
function Governor.force(step: number?)
	forced = if step then math.clamp(math.floor(step), 0, #GovernorRules.CUTS) else nil
	Governor.Changed:Fire(Governor.step())
end

-- Frames a second as the governor sees them (averaged over about a second).
function Governor.rate(): number
	return state.rate
end

function Governor.init()
	RunService.Heartbeat:Connect(function(dt)
		if GovernorRules.advance(state, dt) and forced == nil then
			Governor.Changed:Fire(state.step)
		end
	end)
	local active = ClientState.public.active == true
	ClientState.PublicChanged:Connect(function()
		local now = ClientState.public.active == true
		if now == active then
			return
		end
		active = now
		local had = state.step
		GovernorRules.reset(state)
		if had > 0 and forced == nil then
			Governor.Changed:Fire(0)
		end
	end)
end

return Governor
