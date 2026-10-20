-- The Butler's pick: when Ace dies, the Butler gets a short window to name the next Ace (any other
-- living player). It opens by itself when the server asks and closes when the pick is made or the
-- time runs out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Toasts = require(script.Parent.Toasts)

local ButlerPickRemote = Net.event("ButlerPick")

local C = Kit.color
local T = Kit.Tokens

local ButlerPanel = {}

local renderCandidates: (any, any?, boolean?) -> { any }
local candidates: { { userId: number, alias: string } } = {}
local endsAt = 0
local chosen: number? = nil
local open = false

local function refresh()
	local options = {}
	for _, entry in ipairs(candidates) do
		table.insert(options, { id = entry.userId, text = entry.alias })
	end
	renderCandidates(options, chosen)
end

function ButlerPanel.init()
	local win = Kit.window({ name = "butlerPick", title = Terms.f("Name the next {zero}"), size = "M" })
	local body = win.body
	Kit.label({
		Text = Terms.f(
			"{Zero} is dead. Pick who carries on: they get a fresh arrest. Pick someone from {circle} and their title is worthless."
		),
		size = "small",
		color = C.dim,
		Parent = body,
	})
	local timer = Kit.num({
		text = "",
		size = 26,
		color = C.bone,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Parent = body,
	})
	Clock.bind(timer, Clock.format, function()
		return endsAt
	end)
	local list = Kit.scroll({
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -(76 + 70)),
		Parent = body,
	})
	renderCandidates = Kit.pickGrid(list, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		chosen = id
		refresh()
	end)
	Kit.button({
		text = Terms.f("Name them {zero}"),
		icon = "butler",
		variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = body,
	}, function()
		if not chosen then
			Toasts.show("Choose someone first.", "bad")
			return
		end
		ButlerPickRemote:FireServer(chosen)
	end)
	Kit.register(win, {
		stay = true,
		allowed = function(view)
			return view.living and open
		end,
		show = refresh,
		hide = function(reason)
			if reason == "rule" then
				chosen = nil
			end
		end,
	})
	ButlerPickRemote.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		open = payload.open == true
		if not open then
			Router.close("butlerPick", "rule")
			return
		end
		candidates = if type(payload.candidates) == "table" then payload.candidates else {}
		endsAt = tonumber(payload.endsAt) or 0
		if Router.isOpen("butlerPick") then
			refresh()
		else
			Router.open("butlerPick")
		end
	end)
end

return ButlerPanel
