-- Hold Tab (the pad's D-Up, or the Tasks button on a phone) to see where you stand: the objectives
-- list opens, and the stations you still have to work glow white through walls, on your screen only
-- (the same white the Muerto's deal shows). Let go and both are gone. Roblox's player list is off in
-- a case (CoreGuiController), so Tab is free there.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local ClientState = require(script.Parent.Parent.ClientState)

local TabView = {}

-- Told when the view opens or closes (the HUD's objectives list; set by the client's bootstrap, so
-- this module needs nothing of the HUD's: the HUD's actions need this one).
TabView.onShown = function(_shown: boolean) end

local held = false
local highlights: { Highlight } = {}

local function clearHighlights()
	for _, highlight in ipairs(highlights) do
		highlight:Destroy()
	end
	highlights = {}
end

-- Your open stations, outlined white.
local function showStations()
	clearHighlights()
	local open = {}
	for _, entry in ipairs(ClientState.private.stations or {}) do
		if not entry.done then
			open[entry.id] = true
		end
	end
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for _, desk in ipairs(CollectionService:GetTagged("LStation")) do
		if open[desk:GetAttribute("StationId")] then
			local highlight = Instance.new("Highlight")
			highlight.Name = "LMyStation"
			highlight.Adornee = desk.Parent or desk
			highlight.FillColor = Color3.new(1, 1, 1)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.55
			highlight.OutlineTransparency = 0.1
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = gui
			table.insert(highlights, highlight)
		end
	end
end

local function set(on: boolean)
	on = on and ClientState.isParticipant()
	if on == held then
		return
	end
	held = on
	TabView.onShown(on)
	if on then
		showStations()
	else
		clearHighlights()
	end
end

-- The touch button's toggle.
function TabView.toggle()
	set(not held)
end

function TabView.isHeld(): boolean
	return held
end

function TabView.init()
	ContextActionService:BindAction("DeathsGambit_TabView", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			set(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			set(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.DPadUp)
	-- A station done while looking stops glowing; leaving the case closes the view.
	ClientState.PrivateChanged:Connect(function()
		if held then
			showStations()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.isParticipant() then
			set(false)
		end
	end)
end

return TabView
