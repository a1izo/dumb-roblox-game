-- The How to Play book, drawn as a spread: the table of contents on the left page and the open
-- chapter on the right. The last chapter lists the controls for the input the player is using
-- (keyboard, gamepad, touch). It opens from Settings (closing it goes back there), with H
-- anywhere, and from the match HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Book = require(Shared:WaitForChild("Copy"):WaitForChild("HowToPlay"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Keys = require(script.Parent.Parent.Input.Keys)

local C = Kit.color
local T = Kit.Tokens

local HowToPlay = {}

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

-- The left page's share of the spread.
local CONTENTS_WIDTH = 0.38 -- (wide enough for the longest chapter, "Muertos and the Oculus of the Dead")

local contents: ScrollingFrame
local chapterTitle: any
local page: ScrollingFrame
local current = 1
local firstEntry: TextButton? = nil
-- The screen to go back to when the book closes (Settings, when it was opened from there).
local returnTo: string? = nil

local function controls(): { string }
	local input = Keys.input()
	if input == "touch" then
		return {
			"Tap the prompts that appear near stations, notes and the bell.",
			"The buttons on the right side are the actions you can take right now.",
			"Press and hold your role badge to see your role card and real name.",
			"The chat button opens chat: players close by in free roam, the whole table in meetings.",
			"Settings > Controls moves, resizes or hides the buttons.",
		}
	end
	-- The player's own keys (Settings > Controls), joined with " / " where an action has two.
	local function k(...: string): string
		local parts = {}
		for _, id in ipairs({ ... }) do
			local text = Keys.text(id)
			if text ~= "" then
				table.insert(parts, text)
			end
		end
		return if #parts > 0 then table.concat(parts, " / ") else "(no key)"
	end
	if input == "gamepad" then
		return {
			string.format("%s: use the prompts near stations, notes and the bell.", k("interact", "pickUp")),
			string.format("%s: quick chat.  %s: read or drop the note you carry.", k("quickChat"), k("note", "drop")),
			string.format(
				"Hold %s: role card.  %s: scratchpad.  %s: stare (learn a real name).",
				k("roleCard"),
				k("scratchpad"),
				k("eyesRead")
			),
			string.format(
				Terms.f("%s: {grimoire} (only for {hand}).  %s: sabotage (only for {cultists})."),
				k("privateScreen"),
				k("sabotageBlackout", "sabotageJam", "sabotageBarricade")
			),
			string.format("%s: walk.  %s: look round.  %s: jump.", k("move"), k("look"), k("jump")),
			"B: close the open window.",
		}
	end
	return {
		string.format("%s: use the prompts near stations, notes and the bell.", k("interact", "pickUp")),
		string.format(
			"%s: quick chat and emotes.  %s: read or write your note / drop it.",
			k("quickChat"),
			k("note", "drop")
		),
		string.format(
			"Hold %s: role card.  %s: scratchpad.  %s: this book.",
			k("roleCard"),
			k("scratchpad"),
			k("help")
		),
		string.format(
			Terms.f("%s: stare to learn a real name ({hand} and {cultists}).  %s: {grimoire} (only for {hand})."),
			k("eyesRead"),
			k("privateScreen")
		),
		string.format(
			Terms.f("%s: blackout, jam stations, barricade (only for {cultists})."),
			k("sabotageBlackout", "sabotageJam", "sabotageBarricade")
		),
		string.format(Terms.f("%s: arrest someone during a meeting (only for {zero})."), k("arrest")),
		string.format(
			"%s: walk.  %s: jump.  %s: turn the camera.  %s: shift lock.",
			k("moveForward", "moveLeft", "moveBack", "moveRight"),
			k("jump"),
			k("turnLeft", "turnRight"),
			k("shiftLock")
		),
		"Every key can be changed in Settings > Controls.",
	}
end

local function chapters()
	local list = table.clone(Book)
	table.insert(list, { title = "Controls", body = controls() })
	return list
end

local function showChapter(index: number)
	local list = chapters()
	current = math.clamp(index, 1, #list)
	local chapter = list[current]
	chapterTitle:set(chapter.title)
	Kit.clear(page)
	for order, line in ipairs(chapter.body) do
		Kit.label({ Text = Keys.resolve(line), size = "body", LayoutOrder = order, Parent = page })
	end
	page.CanvasPosition = Vector2.zero
	Kit.clear(contents)
	firstEntry = nil
	for order, entry in ipairs(list) do
		local button = Kit.entry({
			text = entry.title,
			numeral = NUMERALS[order],
			size = 24,
			seed = order,
			selected = order == current,
			Size = UDim2.new(1, -T.space.s, 0, 42),
			LayoutOrder = order,
			Parent = contents,
		}, function()
			showChapter(order)
		end)
		firstEntry = firstEntry or button
	end
end

function HowToPlay.init()
	local win = Kit.window({ name = "howToPlay", title = "How to play", size = "L" })
	-- Left page: the table of contents.
	contents = Kit.scroll({ Size = UDim2.new(CONTENTS_WIDTH, -T.space.l, 1, 0), Parent = win.body })
	Kit.list(contents, T.space.xxs)
	-- The spine between the pages.
	Kit.Base.make("Frame", {
		Name = "Spine",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(CONTENTS_WIDTH, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = win.body,
	})
	-- Right page: the open chapter.
	local right = Kit.frame({
		Name = "Chapter",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1 - CONTENTS_WIDTH, -T.space.xl, 1, 0),
		Parent = win.body,
	})
	chapterTitle = Kit.text({ face = "Head", text = "", size = T.size.heading, color = C.white, Parent = right })
	page = Kit.scroll({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = right })
	Kit.list(page, T.space.m)
	Kit.pad(page, 0, T.space.xs)
	Kit.register(win, {
		show = function(args)
			returnTo = if type(args) == "table" and type(args.returnTo) == "string" then args.returnTo else nil
			showChapter(current)
		end,
		hide = function(reason)
			local back = returnTo
			returnTo = nil
			if back and (reason == "user" or reason == "back") then
				task.defer(Router.open, back)
			end
		end,
		firstSelection = function()
			return firstEntry
		end,
	})
end

return HowToPlay
