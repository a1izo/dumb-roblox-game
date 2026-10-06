-- The How to Play book, drawn as a spread: the table of contents on the left page and the open
-- chapter on the right. The last chapter lists the controls for the input the player is using
-- (keyboard, gamepad, touch). It opens from Settings (closing it goes back there), with H
-- anywhere, and from the match HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Book = require(Shared:WaitForChild("Copy"):WaitForChild("HowToPlay"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local HowToPlay = {}

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

-- The left page's share of the spread.
local CONTENTS_WIDTH = 0.34

local contents: ScrollingFrame
local chapterTitle: any
local page: ScrollingFrame
local current = 1
local firstEntry: TextButton? = nil
-- The screen to go back to when the book closes (Settings, when it was opened from there).
local returnTo: string? = nil

local function controls(): { string }
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return {
			"Tap the prompts that appear near stations, notes and hoods.",
			"The buttons on the right side are the actions you can take right now.",
			"Press and hold your role badge to see your role card and real name.",
			"The chat button opens chat during meetings.",
		}
	elseif string.find(last.Name, "Gamepad") then
		return {
			"X / Y / B: use the prompts near stations, notes and hoods.",
			"D-pad up: evidence board.  D-pad left: quick chat.",
			"D-pad right / down: read or drop the note you carry.",
			"Hold LB: role card.  RT: scratchpad.  RB: read a name with the eyes.",
			Terms.f("LT: {zeroDesk} (only for {zero})."),
			"B: close the open window.",
		}
	end
	return {
		Terms.f("E / F / T: use the prompts near stations, notes and hoods (F fakes a task for {Hand}'s side)."),
		"B: evidence board.  Q: quick chat and emotes.",
		"N / G: read or write your note / drop it.",
		"Hold C: role card.  V: scratchpad.  H: this book.",
		Terms.f("R: read a name with {eyes}.  Z: {zeroDesk}."),
		Terms.f("P: reopen your private screen during {phase}.", { phase = Terms.PHASE.DeathNote }),
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
		Kit.label({ Text = line, size = "body", LayoutOrder = order, Parent = page })
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
	chapterTitle = Kit.text({ face = "Gothic", text = "", size = T.size.heading, color = C.red, Parent = right })
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
