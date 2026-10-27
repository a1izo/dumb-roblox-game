--!strict
-- The way into the lobby. On joining (2026-10-27): the eye (UI/EyeIntro) over the black ReplicatedFirst's DGIntro put
-- up on the very first frame (first/Cover), held shut until the game has loaded, then open, then into the lobby; a
-- player arriving by teleport from a match search comes in through the loading screen instead, as they left. Coming
-- back from a case: the loading screen (UI/AppleLoading) while the lobby loads again. Then `onRevealed` runs (the
-- lobby's own entrance: the title cards fall in, the rest glitches in).

local Players = game:GetService("Players")

local AppleLoading = require(script.Parent.AppleLoading)
local EyeIntro = require(script.Parent.EyeIntro)

local LobbyIntro = {}

local HOLD_MOST = 45 -- the longest a held loading screen waits for the way back before it lifts by itself

local playing = false
-- A loading screen put up ahead of the way back (the results closed while the case still ends: `hold`), which
-- comeBack carries on with.
local held: AppleLoading.Loader? = nil

-- The black screen, found (DGCover's, on joining) or made.
local function cover(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("DGIntro") :: ScreenGui?
	if not gui then
		local made = Instance.new("ScreenGui")
		made.Name = "DGIntro"
		made.IgnoreGuiInset = true
		made.ScreenInsets = Enum.ScreenInsets.None
		made.DisplayOrder = 1000
		made.ResetOnSpawn = false
		made.Parent = playerGui
		gui = made
	end
	local screen = gui :: ScreenGui
	local black = screen:FindFirstChild("Black") :: Frame?
	if not black then
		local made = Instance.new("Frame")
		made.Name = "Black"
		made.BackgroundColor3 = Color3.new(0, 0, 0)
		made.BorderSizePixel = 0
		made.Size = UDim2.fromScale(1, 1)
		made.Parent = screen
		black = made
	end
	local frame = black :: Frame
	screen:SetAttribute("Claimed", true)
	screen.Enabled = true
	frame.Visible = true
	frame.BackgroundTransparency = 0
	return screen
end

-- Puts the black up now (before coming back from a case, so the lobby is never seen half-built).
function LobbyIntro.cover()
	cover()
end

function LobbyIntro.isPlaying(): boolean
	return playing
end

-- The join: the eye, or the loading screen (arriving by teleport, or into a case already running: `viaLoading`).
-- `isLoaded` says when the game is ready to be seen.
function LobbyIntro.join(isLoaded: () -> boolean, onRevealed: (() -> ())?, viaLoading: boolean?)
	if playing then
		return
	end
	playing = true
	local gui = cover()
	task.spawn(function()
		if viaLoading or gui:GetAttribute("Teleported") then
			local loader = AppleLoading.open()
			-- (the still the teleport carried, now under the moving screen)
			local carried = gui.Parent and gui.Parent:FindFirstChild("DGTeleport")
			if carried then
				carried:Destroy()
			end
			gui.Enabled = false
			local started = os.clock()
			while not isLoaded() and os.clock() - started < 45 do
				loader.progress(math.min(0.95, (os.clock() - started) / 8))
				task.wait(0.1)
			end
			loader.finish(onRevealed)
		else
			EyeIntro.play(gui, isLoaded, onRevealed)
		end
		gui.Enabled = false
		playing = false
	end)
end

-- Coming back from a case: the loading screen while the lobby's things load again, then the lobby.
function LobbyIntro.comeBack(load: (progress: (number) -> ()) -> (), onRevealed: (() -> ())?)
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		local loader = held or AppleLoading.open()
		held = nil
		local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("DGIntro") :: ScreenGui?
		if gui then
			gui.Enabled = false
		end
		pcall(load, loader.progress)
		loader.finish(onRevealed)
		playing = false
	end)
end

-- The results closed while the case still winds down: the loading screen comes up now (not the meeting room), its
-- apple creeping down, and the way back (comeBack) carries on with it once the server sends you home. If that never
-- comes it lifts by itself.
function LobbyIntro.hold()
	if held or playing then
		return
	end
	local loader = AppleLoading.open()
	held = loader
	task.spawn(function()
		local started = os.clock()
		while held == loader and os.clock() - started < HOLD_MOST do
			-- (a third of the fall over the first ten seconds, then slower)
			loader.progress(math.min(0.6, (os.clock() - started) / 30))
			task.wait(0.2)
		end
		if held == loader then
			held = nil
			loader.finish(nil)
		end
	end)
end

return LobbyIntro
