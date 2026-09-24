-- Every window and panel registers here with the rules for when it may be open:
--   allowed(view) : closes the screen as soon as this turns false
--   auto(view)    : opens the screen when this turns true and closes it when it turns false
-- Only one modal is open at a time; opening another replaces it. Back (gamepad B, or a tap
-- on the dimmed backdrop) closes the newest screen. This replaces the per-panel phase rules.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Motion = require(script.Parent.Motion)
local Screens = require(script.Parent.Parent.Screens)

local Router = {}

export type View = {
	phase: string,
	active: boolean,
	participant: boolean,
	living: boolean,
	specter: boolean,
	role: string?,
	private: { [string]: any },
}

export type Spec = {
	layer: string, -- "modal", "panel" or "overlay"
	-- Makes the screen visible; args come from Router.open.
	show: (args: any?) -> (),
	-- Hides it. reason: "user", "rule", "replaced" or "back".
	hide: (reason: string) -> (),
	allowed: ((View) -> boolean)?,
	auto: ((View) -> boolean)?,
	-- The window, for the pop animation and for gamepad selection.
	window: GuiObject?,
	-- The first button a gamepad should select when the screen opens.
	firstSelection: (() -> GuiObject?)?,
}

-- Fired as (name, isOpen).
Router.Changed = Signal.new()

local specs: { [string]: Spec } = {}
local openOrder: { [string]: number } = {}
local autoState: { [string]: boolean } = {}
local blocking: { [string]: boolean } = {}
local counter = 0
local scrim: TextButton

local BACK_ACTION = "InkboundBack"

function Router.view(): View
	return {
		phase = ClientState.phase(),
		active = ClientState.public.active == true,
		participant = ClientState.isParticipant(),
		living = ClientState.isLiving(),
		specter = ClientState.isSpecter(),
		role = ClientState.role(),
		private = ClientState.private,
	}
end

local function anyOpen(layer: string?): boolean
	for name in pairs(openOrder) do
		if layer == nil or specs[name].layer == layer then
			return true
		end
	end
	return false
end

-- Panels that open on their own for a phase (the vote, the meeting) stay up; Back only
-- closes modals and panels the player opened.
local function closable(spec: Spec): boolean
	return spec.layer == "modal" or (spec.layer == "panel" and spec.auto == nil)
end

local function newest(): string?
	local best, bestOrder = nil, -1
	for name, order in pairs(openOrder) do
		if closable(specs[name]) and order > bestOrder then
			best, bestOrder = name, order
		end
	end
	return best
end

local function refreshChrome()
	scrim.Visible = anyOpen("modal")
	if newest() then
		ContextActionService:BindActionAtPriority(BACK_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				Router.back()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction(BACK_ACTION)
	end
end

local function selectFirst(spec: Spec)
	if not UserInputService.GamepadEnabled or not spec.firstSelection then
		return
	end
	local target = spec.firstSelection()
	if target and target.Visible then
		GuiService.SelectedObject = target
	end
end

local function deselect(spec: Spec)
	local selected = GuiService.SelectedObject
	if selected and spec.window and selected:IsDescendantOf(spec.window) then
		GuiService.SelectedObject = nil
	end
end

function Router.register(name: string, spec: Spec)
	specs[name] = spec
end

function Router.isOpen(name: string): boolean
	return openOrder[name] ~= nil
end

-- A screen closed itself (for example after its form was sent).
function Router.close(name: string, reason: string?)
	local spec = specs[name]
	if not spec or not openOrder[name] then
		return
	end
	openOrder[name] = nil
	deselect(spec)
	spec.hide(reason or "user")
	refreshChrome()
	Router.Changed:Fire(name, false)
end

-- Opens a screen if its rules allow it. Returns true when it is open afterwards.
function Router.open(name: string, args: any?): boolean
	local spec = specs[name]
	if not spec then
		warn("[Inkbound] Router: unknown screen " .. name)
		return false
	end
	if spec.allowed and not spec.allowed(Router.view()) then
		return false
	end
	if spec.layer == "modal" then
		for other in pairs(openOrder) do
			if other ~= name and specs[other].layer == "modal" then
				Router.close(other, "replaced")
			end
		end
	end
	local wasOpen = openOrder[name] ~= nil
	counter += 1
	openOrder[name] = counter
	spec.show(args)
	if not wasOpen then
		if spec.window and spec.layer == "modal" then
			Motion.pop(spec.window)
		end
		selectFirst(spec)
		refreshChrome()
		Router.Changed:Fire(name, true)
	end
	return true
end

function Router.toggle(name: string, args: any?)
	if Router.isOpen(name) then
		Router.close(name, "user")
	else
		Router.open(name, args)
	end
end

-- Closes the newest modal or panel. Returns true if something closed.
function Router.back(): boolean
	local name = newest()
	if name then
		Router.close(name, "back")
		return true
	end
	return false
end

-- Applies every screen's rules to the current state.
function Router.evaluate()
	local view = Router.view()
	for name, spec in pairs(specs) do
		if spec.auto then
			local wanted = spec.auto(view)
			if wanted and not autoState[name] then
				autoState[name] = true
				Router.open(name)
			elseif not wanted and autoState[name] then
				autoState[name] = false
				Router.close(name, "rule")
			end
		end
		if openOrder[name] and spec.allowed and not spec.allowed(view) then
			Router.close(name, "rule")
		end
	end
end

-- Cutscenes and full-screen results "block" announcements and other overlays.
function Router.setBlocking(reason: string, on: boolean)
	blocking[reason] = if on then true else nil
end

function Router.isBlocking(): boolean
	return next(blocking) ~= nil
end

function Router.init()
	scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.AutoButtonColor = false
	scrim.Text = ""
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.45
	scrim.BorderSizePixel = 0
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.ZIndex = 0
	scrim.Selectable = false
	scrim.Visible = false
	scrim.Parent = Screens.modal
	scrim.Activated:Connect(function()
		Router.back()
	end)
	ClientState.PublicChanged:Connect(Router.evaluate)
	ClientState.PrivateChanged:Connect(Router.evaluate)
	ClientState.PhaseChanged:Connect(Router.evaluate)
end

return Router
