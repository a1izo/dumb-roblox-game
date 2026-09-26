-- Every player action in one table. The same entry drives the keyboard key, the gamepad
-- button, the on-screen action bar (touch and mouse) and the key hint shown next to it.
-- `when` decides if the action is available right now; nothing else needs to know.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Terms = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terms"))

local EyesController = require(script.Parent.Parent.Controllers.EyesController)
local NotePanel = require(script.Parent.Parent.UI.NotePanel)
local Router = require(script.Parent.Parent.UI.Core.Router)

local Actions = {}

-- Phases that are mostly a cutscene or a results screen: no quick chat, no action bar.
Actions.CUTSCENE_PHASES = { Intro = true, Verdict = true, Outro = true, Reveal = true } :: { [string]: boolean }

export type View = Router.View

export type Action = {
	id: string,
	label: (View) -> string,
	keys: { Enum.KeyCode },
	pad: Enum.KeyCode?,
	padLabel: string?,
	variant: string?,
	when: (View) -> boolean,
	run: () -> (),
}

local function inMatchPhase(view: View, ...: string): boolean
	for _, phase in ipairs({ ... }) do
		if view.phase == phase then
			return true
		end
	end
	return false
end

local function fixed(text: string): (View) -> string
	return function()
		return text
	end
end

Actions.list = {
	{
		id = "evidence",
		label = fixed("Evidence"),
		keys = { Enum.KeyCode.B },
		pad = Enum.KeyCode.DPadUp,
		padLabel = "D-Up",
		when = function(view: View)
			return view.participant
		end,
		run = function()
			Router.toggle("evidence")
		end,
	},
	{
		id = "privateScreen",
		label = function(view: View)
			return if view.role == "Kira" then Terms.f("{Grimoire}") else "Case report"
		end,
		keys = { Enum.KeyCode.P },
		pad = Enum.KeyCode.ButtonY,
		padLabel = "Y",
		variant = "primary",
		when = function(view: View)
			return view.living and view.phase == "DeathNote"
		end,
		run = function()
			Router.toggle(if Router.view().role == "Kira" then "grimoire" else "report")
		end,
	},
	{
		id = "quickChat",
		label = fixed("Quick chat"),
		keys = { Enum.KeyCode.Q },
		pad = Enum.KeyCode.DPadLeft,
		padLabel = "D-Left",
		when = function(view: View)
			return (view.living or view.specter) and not Actions.CUTSCENE_PHASES[view.phase]
		end,
		run = function()
			Router.toggle("quickChat")
		end,
	},
	{
		id = "note",
		label = function(view: View)
			return if view.private.carrying == "blank" then "Write note" else "Read note"
		end,
		keys = { Enum.KeyCode.N },
		pad = Enum.KeyCode.DPadRight,
		padLabel = "D-Right",
		variant = "team",
		when = function(view: View)
			return view.living and view.private.carrying ~= nil and inMatchPhase(view, "Investigation", "DeathNote")
		end,
		run = NotePanel.toggle,
	},
	{
		id = "drop",
		label = function(view: View)
			return if view.private.carrying == "blank" then "Discard sheet" else "Drop note"
		end,
		keys = { Enum.KeyCode.G },
		pad = Enum.KeyCode.DPadDown,
		padLabel = "D-Down",
		when = function(view: View)
			return view.living and view.private.carrying ~= nil and inMatchPhase(view, "Investigation", "DeathNote")
		end,
		run = NotePanel.drop,
	},
	{
		id = "eyesDeal",
		label = fixed(Terms.f("Accept {eyes}")),
		keys = {},
		variant = "primary",
		when = function(view: View)
			return view.living
				and view.role == "Follower"
				and view.private.canDeal == true
				and view.phase == "Investigation"
		end,
		run = EyesController.deal,
	},
	{
		id = "eyesRead",
		label = fixed("Read name"),
		keys = { Enum.KeyCode.R },
		pad = Enum.KeyCode.ButtonR1,
		padLabel = "RB",
		variant = "primary",
		when = function(view: View)
			return view.living and view.private.eyes ~= nil and view.phase == "Investigation"
		end,
		run = EyesController.read,
	},
	{
		id = "scratchpad",
		label = fixed("Scratchpad"),
		keys = { Enum.KeyCode.V },
		pad = Enum.KeyCode.ButtonR2,
		padLabel = "RT",
		variant = "ghost",
		when = function(view: View)
			return view.participant
		end,
		run = function()
			Router.toggle("scratchpad")
		end,
	},
	{
		id = "help",
		label = fixed("How to play"),
		keys = { Enum.KeyCode.H },
		variant = "ghost",
		-- Everywhere, the lobby included (the HUD only shows action chips in a match).
		when = function()
			return true
		end,
		run = function()
			Router.toggle("howToPlay")
		end,
	},
	{
		id = "zeroDesk",
		label = fixed(Terms.f("{ZeroDesk}")),
		keys = { Enum.KeyCode.Z },
		pad = Enum.KeyCode.ButtonL2,
		padLabel = "LT",
		variant = "team",
		when = function(view: View)
			return view.participant and view.role == "L"
		end,
		run = function()
			Router.toggle("zeroDesk")
		end,
	},
} :: { Action }

function Actions.get(id: string): Action?
	for _, action in ipairs(Actions.list) do
		if action.id == id then
			return action
		end
	end
	return nil
end

function Actions.available(view: View): { Action }
	local result = {}
	for _, action in ipairs(Actions.list) do
		if action.when(view) then
			table.insert(result, action)
		end
	end
	return result
end

-- The key to show next to an action for the input the player used last ("" on touch).
function Actions.hint(action: Action): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return action.padLabel or ""
	end
	local key = action.keys[1]
	return if key then key.Name else ""
end

return Actions
