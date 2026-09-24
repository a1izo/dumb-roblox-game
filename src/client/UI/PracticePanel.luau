-- Academy drills that are not case files: a practice Grimoire, a practice warrant and a look
-- through Specter's Eyes. Everything runs on this client against the practice dummies; the
-- only thing sent to the server is "drill finished".

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Terms = require(Shared:WaitForChild("Terms"))

local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local PracticePanel = {}

type Dummy = { part: BasePart, model: Model, alias: string, name: string, first: string, last: string }

local window: Frame
local titleLabel: TextLabel
local body: Frame
local onFinished: (() -> ())? = nil

local function dummies(): { Dummy }
	local list = {}
	for _, part in ipairs(CollectionService:GetTagged("LDummy")) do
		local name = part:GetAttribute("PracticeName")
		local alias = part:GetAttribute("Alias")
		if part:IsA("BasePart") and part.Parent and part.Parent:IsA("Model") and type(name) == "string" then
			local first, last = string.match(name, "^(%S+)%s+(%S+)$")
			table.insert(list, {
				part = part,
				model = part.Parent :: Model,
				alias = tostring(alias),
				name = name,
				first = first or name,
				last = last or "",
			})
		end
	end
	table.sort(list, function(a, b)
		return a.alias < b.alias
	end)
	return list
end

local function finish()
	local done = onFinished
	onFinished = nil
	Router.close("practice", "user")
	if done then
		done()
	end
end

-- The dummy tips over, then stands up again a few seconds later (only on this screen).
local function collapse(target: Dummy)
	local model = target.model
	local start = model:GetPivot()
	local feet = start * CFrame.new(0, -3.8, 0)
	local fallen = feet * CFrame.Angles(math.rad(80), 0, 0) * CFrame.new(0, 3.8, 0)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(t: number)
		if model.Parent then
			model:PivotTo(start:Lerp(fallen, t))
		end
	end)
	Motion.tween(value, { Value = 1 }, 0.6, Enum.EasingStyle.Bounce)
	task.delay(4, function()
		if model.Parent then
			model:PivotTo(start)
		end
		value:Destroy()
	end)
end

local function feedback(text: string, color: Color3): TextLabel
	return Widgets.label({
		Text = text,
		TextColor3 = color,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 99,
		Parent = body,
	})
end

-- Drills ----------------------------------------------------------------------------------

local function grimoireDrill()
	local list = dummies()
	if #list == 0 then
		return
	end
	local target = list[math.random(1, #list)]
	titleLabel.Text = "PRACTICE GRIMOIRE"
	window.BackgroundColor3 = Theme.colors.deathNote
	Widgets.label({
		Text = Terms.f(
			"In a match, {hand} learns names letter by letter. Here you know it already: write {alias}'s real name, {name}.",
			{ alias = target.alias, name = string.upper(target.name) }
		),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	})
	Widgets.label({
		Text = "Capital letters and extra spaces do not matter. Any other mistake wastes the round.",
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	})
	local box = Widgets.textbox({
		PlaceholderText = "First name  Last name",
		Font = Theme.fonts.hand,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 3,
		Parent = body,
	})
	local result: TextLabel? = nil
	Widgets.holdButton(
		{
			Text = "HOLD TO WRITE THE NAME",
			Font = Theme.fonts.black,
			Variant = "primary",
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = 4,
			Parent = body,
		},
		1,
		function()
			if result then
				result:Destroy()
			end
			if NameUtil.matches(box.Text, target.first, target.last) then
				collapse(target)
				finish()
			else
				result = feedback("That is not the exact name. Check the spelling and try again.", Theme.colors.bad)
			end
		end
	)
end

local function warrantDrill()
	local list = dummies()
	if #list == 0 then
		return
	end
	local target = list[math.random(1, #list)]
	titleLabel.Text = Terms.f("PRACTICE WARRANT")
	window.BackgroundColor3 = Theme.colors.panel
	local notes = {}
	for _, entry in ipairs(list) do
		table.insert(notes, string.format("%s:  %s", entry.alias, string.upper(entry.name)))
	end
	Widgets.label({
		Text = "Your notes so far:  " .. table.concat(notes, "   ·   "),
		Font = Theme.fonts.typewriter,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	})
	Widgets.label({
		Text = Terms.f("New clue: {hand}'s first name has {n} letters.", { n = #target.first }),
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.gold,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	})
	local picked: string? = nil
	local grid = Widgets.frame({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Parent = body })
	local render
	render = Widgets.pickGrid(grid, UDim2.new(1 / 3, -6, 0, 40), function(id)
		picked = id
		local options = {}
		for _, entry in ipairs(list) do
			table.insert(options, { id = entry.alias, text = entry.alias })
		end
		render(options, picked)
	end)
	local options = {}
	for _, entry in ipairs(list) do
		table.insert(options, { id = entry.alias, text = entry.alias })
	end
	render(options, nil)
	local box = Widgets.textbox({
		PlaceholderText = "The suspect's full real name",
		Font = Theme.fonts.typewriter,
		LayoutOrder = 4,
		Parent = body,
	})
	local result: TextLabel? = nil
	Widgets.holdButton(
		{
			Text = "HOLD TO SERVE THE WARRANT",
			Font = Theme.fonts.black,
			Variant = "team",
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = 5,
			Parent = body,
		},
		1,
		function()
			if result then
				result:Destroy()
			end
			if picked ~= target.alias then
				result = feedback(
					Terms.f("Wrong suspect. In a match, arresting an innocent player hands the win to {hand}."),
					Theme.colors.bad
				)
			elseif not NameUtil.matches(box.Text, target.first, target.last) then
				result = feedback(
					"Right suspect, wrong name. A rejected warrant blocks you until the next round.",
					Theme.colors.bad
				)
			else
				finish()
			end
		end
	)
end

local function eyesDrill()
	titleLabel.Text = Terms.f("{EYES}")
	window.BackgroundColor3 = Theme.colors.panel
	Widgets.label({
		Text = Terms.f(
			"From round 2, one {cultist} may accept {eyes}. Up close, they see a player's real name for 3 seconds, but their own eyes glow red for everyone to see, and they die soon after."
		),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	})
	Widgets.label({
		Text = "A hood blocks the eyes for the round it is worn.",
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	})
	Widgets.button({
		Text = "LOOK AT THE DUMMIES",
		Font = Theme.fonts.black,
		Variant = "primary",
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 3,
		Parent = body,
	}, function()
		finish()
		local tint = Create("ColorCorrectionEffect", {
			Name = "PracticeEyes",
			TintColor = Color3.fromRGB(255, 150, 150),
			Saturation = -0.4,
			Contrast = 0.15,
			Parent = Lighting,
		})
		local labels = {}
		for _, entry in ipairs(dummies()) do
			local gui = Create("BillboardGui", {
				Adornee = entry.part,
				AlwaysOnTop = true,
				LightInfluence = 0,
				Size = UDim2.fromScale(7, 1.2),
				StudsOffset = Vector3.new(0, 3.4, 0),
				Parent = playerGui,
			})
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(entry.name),
				TextColor3 = Color3.fromRGB(255, 50, 50),
				TextStrokeTransparency = 0.2,
				TextScaled = true,
				Font = Theme.fonts.typewriter,
				Parent = gui,
			})
			table.insert(labels, gui)
		end
		task.delay(4, function()
			tint:Destroy()
			for _, gui in ipairs(labels) do
				gui:Destroy()
			end
		end)
	end)
end

local DRILLS = { grimoire = grimoireDrill, warrant = warrantDrill, eyes = eyesDrill }

-- Opens a drill; onDone runs once when it is finished.
function PracticePanel.open(drill: string, onDone: () -> ())
	local build = DRILLS[drill]
	if not build then
		return
	end
	onFinished = onDone
	Widgets.clear(body)
	build()
	Router.open("practice")
end

function PracticePanel.init()
	local inner
	window, inner = Widgets.modal(Screens.modal, "Practice", Vector2.new(560, 520), function()
		Router.close("practice", "user")
	end)
	titleLabel = window:FindFirstChild("Title") :: TextLabel
	body = Widgets.scroll({ Parent = inner })
	Widgets.list(body, Theme.space.md)
	Widgets.padding(body, 2)
	Router.register("practice", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			window.Visible = true
		end,
		hide = function()
			window.Visible = false
		end,
	})
end

return PracticePanel
