-- Every player action in one table. The same entry drives the keyboard key, the gamepad
-- button, the on-screen action bar (touch and mouse) and the key hint shown next to it.
-- `when` decides if the action is available right now; nothing else needs to know.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Bindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bindings"))
local Terms = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terms"))

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local EyesController = require(script.Parent.Parent.Controllers.EyesController)
local NotePanel = require(script.Parent.Parent.UI.NotePanel)
local Router = require(script.Parent.Parent.UI.Core.Router)

local SabotageRemote = Net.event("Sabotage")

local Actions = {}

-- Phases that are mostly a cutscene or a results screen: no quick chat, no action bar.
Actions.CUTSCENE_PHASES = { Intro = true, Verdict = true, Outro = true, Reveal = true } :: { [string]: boolean }

export type View = Router.View

export type Action = {
	id: string,
	label: (View) -> string,
	keys: { Enum.KeyCode },
	pad: Enum.KeyCode?,
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

-- Emotes (the quick-chat page's wheel) work in the lobby too, and in a case for the living and the
-- Specters outside the cutscenes. Not while watching a case from the lobby, nor for a Specter waiting
-- there (hidden).
function Actions.emotesAllowed(view: View): boolean
	if view.participant then
		return (view.living or view.specter) and not Actions.CUTSCENE_PHASES[view.phase]
	end
	return not view.spectating and view.private.away ~= true
end

local function fixed(text: string): (View) -> string
	return function()
		return text
	end
end

-- The meeting and the vote, where Ace's arrest lives.
local function isMeeting(view: View): boolean
	return view.phase == "Meeting" or view.phase == "Vote"
end

local function sabotageLeft(view: View): number
	local readyAt = tonumber(view.private.sabotageReadyAt) or 0
	return math.max(0, math.ceil(readyAt - workspace:GetServerTimeNow()))
end

local function sabotageLabel(text: string): (View) -> string
	return function(view: View)
		local left = sabotageLeft(view)
		return if left > 0 then string.format("%s (%d s)", text, left) else text
	end
end

Actions.list = {
	{
		-- One key for your role's power (R / RB): Diavolo's Manual, a Muerto's blackout, Ace's arrest.
		id = "ability",
		label = function(view: View)
			if isMeeting(view) then
				return Terms.f("{Zero}'s arrest")
			elseif view.role == "Kira" then
				return Terms.f("{Grimoire}")
			end
			return sabotageLabel("Blackout")(view)
		end,
		keys = { Enum.KeyCode.R },
		pad = Enum.KeyCode.ButtonR1,
		variant = "primary",
		when = function(view: View)
			if not view.living then
				return false
			end
			if isMeeting(view) then
				return view.private.isAce == true and view.private.arrestUsed ~= true
			end
			return view.phase == "Investigation" and (view.role == "Kira" or view.role == "Follower")
		end,
		run = function()
			local view = Router.view()
			if isMeeting(view) then
				Router.toggle("arrest")
			elseif view.role == "Kira" then
				Router.toggle("grimoire")
			else
				SabotageRemote:FireServer({ kind = "blackout" })
			end
		end,
	},
	{
		-- A second key (T / Y) for the one role that has a second power: a Muerto's Oculus deal, then
		-- its stare.
		id = "ability2",
		label = function(view: View)
			return if view.private.eyes then "Read name" else Terms.f("Accept {eyes}")
		end,
		keys = { Enum.KeyCode.T },
		pad = Enum.KeyCode.ButtonY,
		when = function(view: View)
			return view.living
				and view.role == "Follower"
				and view.phase == "Investigation"
				and (view.private.eyes ~= nil or view.private.canDeal == true)
		end,
		run = function()
			if Router.view().private.eyes then
				EyesController.stare()
			else
				EyesController.deal()
			end
		end,
	},
	{
		id = "quickChat",
		label = fixed("Emotes"),
		keys = { Enum.KeyCode.Q },
		pad = Enum.KeyCode.DPadLeft,
		when = Actions.emotesAllowed,
		run = function()
			Router.toggle("quickChat")
		end,
	},
	{
		-- quick chat's phrases, in a case (their own page, their own key: UI/QuickChatPanel)
		id = "phrases",
		label = fixed("Quick chat"),
		keys = { Enum.KeyCode.M },
		pad = Enum.KeyCode.ButtonL3,
		when = function(view: View)
			return view.participant and Actions.emotesAllowed(view)
		end,
		run = function()
			Router.toggle("phrases")
		end,
	},
	{
		id = "note",
		label = function(view: View)
			return if view.private.carrying == "blank" then "Write note" else "Read note"
		end,
		keys = { Enum.KeyCode.N },
		pad = Enum.KeyCode.DPadRight,
		variant = "team",
		when = function(view: View)
			return view.living and view.private.carrying ~= nil and inMatchPhase(view, "Investigation")
		end,
		run = NotePanel.toggle,
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
		return if action.pad then Bindings.label(action.pad.Name) else ""
	end
	local key = action.keys[1]
	return if key then Bindings.label(key.Name) else ""
end

return Actions
