--!strict
-- A word to players on a low Graphics Quality (the owner's graphics plan, 2026-11-13, phase 7). A script cannot raise
-- the setting, and Roblox lights a place in full (shadows, the lamps' pools, the grade) only from a middle level up;
-- on Automatic it often falls back to a flat look that was never judged. So the first time a player is in a map in a
-- session, on Automatic or a level under LOW_UNDER, one small notice (Kit/Notice, as the guide's tips are) says where
-- to raise it. Once per session, never over a full-screen overlay, an announcement or a tip, and not when the guide is
-- off in Settings.

local Players = game:GetService("Players")

local HintController = require(script.Parent.Parent.Onboarding.HintController)
local UI = script.Parent.Parent.UI
local Announcer = require(UI.Announcer)
local Hud = require(UI.Hud)
local Kit = require(UI.Kit)
local Motion = require(UI.Core.Motion)
local Router = require(UI.Core.Router)
local Screens = require(UI.Screens)
local Settings = require(UI.Core.Settings)
local LightingController = require(script.Parent.LightingController)

local QualityNotice = {}

local LOW_UNDER = 7 -- the saved levels 1 to 6 (and Automatic) are told; 7 and up have the full lighting
local TEXT = "Raise Graphics Quality in the Roblox menu to see the full lighting."
local SHOW_TIME = 12
local CHECK_EVERY = 2
local SETTLE = 12 -- seconds in a map before the notice, so it does not land on the first announcements

local shown = false

-- Whether a saved Graphics Quality is one to tell (Automatic, or a level under LOW_UNDER).
function QualityNotice.wants(level: Enum.SavedQualitySetting): boolean
	return level == Enum.SavedQualitySetting.Automatic or level.Value < LOW_UNDER
end

local function saved(): Enum.SavedQualitySetting?
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel
	end)
	return if ok and typeof(level) == "EnumItem" then level :: any else nil
end

local function show()
	local dismissed = false
	local notice = Kit.notice({
		Name = "GraphicsNotice",
		kind = "info",
		eyebrow = "Graphics",
		body = TEXT,
		Visible = false,
		close = function()
			dismissed = true
		end,
		actions = {
			{
				text = "Got it",
				onClick = function()
					dismissed = true
				end,
			},
		},
		Parent = Screens.toast,
	})
	local card = notice.group :: CanvasGroup
	local position, anchor = Hud.tipPlacement(nil)
	card.AnchorPoint = anchor
	card.Position = position
	Motion.fade(card, true, 0.25)
	Motion.slideIn(card, Vector2.new(0, -10), 0.3)
	local started = os.clock()
	while not dismissed and os.clock() - started < SHOW_TIME and Settings.get("hints") do
		task.wait(0.2)
	end
	local tween = Motion.fade(card, false, 0.3)
	if tween then
		tween.Completed:Wait()
	end
	notice.group:Destroy()
end

function QualityNotice.init()
	task.spawn(function()
		local inMap = 0
		while not shown do
			task.wait(CHECK_EVERY)
			if LightingController.venue() == "map" and Players.LocalPlayer.Character then
				inMap += CHECK_EVERY
			else
				inMap = 0
			end
			local level = saved()
			if level and not QualityNotice.wants(level) then
				return -- (a level that has the full lighting: nothing to say, this session)
			end
			if
				inMap >= SETTLE
				and Settings.get("hints")
				and not Router.isBlocking()
				and not Announcer.isShowing()
				and not HintController.isUp()
			then
				shown = true
				show()
			end
		end
	end)
end

return QualityNotice
