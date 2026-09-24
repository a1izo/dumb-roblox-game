-- The How to Play book: a chapter list on the left and the chapter on the right. The last
-- chapter lists the controls for the input the player is using (keyboard, gamepad, touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Book = require(Shared:WaitForChild("Copy"):WaitForChild("HowToPlay"))
local Terms = require(Shared:WaitForChild("Terms"))

local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local HowToPlay = {}

local window: Frame
local chapterList: ScrollingFrame
local titleLabel: TextLabel
local page: ScrollingFrame
local current = 1
local firstButton: TextButton? = nil

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
		"E / F / T: use the prompts near stations, notes and hoods (F fakes a task for the Hand's side).",
		"B: evidence board.  Q: quick chat and emotes.",
		"N / G: read or write your note / drop it.",
		"Hold C: role card.  V: scratchpad.  H: this book.",
		Terms.f("R: read a name with {eyes}.  Z: {zeroDesk}."),
		"P: reopen your private screen in the Grimoire phase.",
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
	titleLabel.Text = chapter.title
	Widgets.clear(page)
	for order, line in ipairs(chapter.body) do
		Widgets.label({
			Text = line,
			TextSize = Theme.text.body,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -8, 0, 0),
			LayoutOrder = order,
			Parent = page,
		})
	end
	Widgets.clear(chapterList)
	firstButton = nil
	for order, entry in ipairs(list) do
		local button = Widgets.button({
			Text = entry.title,
			TextSize = Theme.text.small,
			TextXAlignment = Enum.TextXAlignment.Left,
			Variant = if order == current then "primary" else "ghost",
			Size = UDim2.new(1, -6, 0, 36),
			LayoutOrder = order,
			Parent = chapterList,
		}, function()
			showChapter(order)
		end)
		Widgets.padding(button, 0, Theme.space.sm)
		firstButton = firstButton or button
	end
end

function HowToPlay.init()
	local body
	window, body = Widgets.modal(Screens.modal, "How to play", Vector2.new(760, 540), function()
		Router.close("howToPlay", "user")
	end)
	chapterList = Widgets.scroll({ Size = UDim2.new(0.32, 0, 1, 0), Parent = body })
	Widgets.list(chapterList, Theme.space.xs)
	local right = Widgets.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.66, 0, 1, 0),
		Parent = body,
	})
	titleLabel = Widgets.label({
		Font = Theme.fonts.gothic,
		TextSize = 30,
		TextColor3 = Theme.colors.gold,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = right,
	})
	page = Widgets.scroll({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = right })
	Widgets.list(page, Theme.space.md)
	Router.register("howToPlay", {
		layer = "modal",
		window = window,
		show = function()
			showChapter(current)
			window.Visible = true
		end,
		hide = function()
			window.Visible = false
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return HowToPlay
