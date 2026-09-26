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

local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local C = Kit.color
local T = Kit.Tokens

local PracticePanel = {}

type Dummy = { part: BasePart, model: Model, alias: string, name: string, first: string, last: string }

local win: any
local body: ScrollingFrame
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

local function feedback(text: string): TextLabel
	return Kit.label({ Text = text, color = C.red, LayoutOrder = 99, Parent = body })
end

-- A name field, handwritten (the Grimoire) or typewritten (a warrant).
local function nameField(font: string, order: number): TextBox
	local _, box = Kit.field({
		placeholder = if font == "hand" then "First name  Last name" else "The suspect's full real name",
		font = font,
		size = if font == "hand" then 32 else "lead",
		Size = UDim2.new(1, 0, 0, 60),
		LayoutOrder = order,
		Parent = body,
	})
	if font == "hand" then
		box.TextXAlignment = Enum.TextXAlignment.Center
	end
	return box
end

-- Drills ----------------------------------------------------------------------------------

local function grimoireDrill()
	local list = dummies()
	if #list == 0 then
		return
	end
	local target = list[math.random(1, #list)]
	win.setTitle(Terms.f("Practice {grimoire}"))
	Kit.label({
		Text = Terms.f(
			"In a match, {hand} learns names letter by letter. Here you know it already: write {alias}'s real name, {name}.",
			{ alias = target.alias, name = string.upper(target.name) }
		),
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = "Capital letters and extra spaces do not matter. Any other mistake wastes the round.",
		size = "small",
		color = C.dim,
		LayoutOrder = 2,
		Parent = body,
	})
	local box = nameField("hand", 3)
	local result: TextLabel? = nil
	Kit.hold(
		{
			text = "Hold to write the name",
			icon = "quill",
			variant = "primary",
			Size = UDim2.new(1, 0, 0, 56),
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
				result = feedback("That is not the exact name. Check the spelling and try again.")
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
	win.setTitle("Practice warrant")
	local notes = {}
	for _, entry in ipairs(list) do
		table.insert(notes, string.format("%s:  %s", entry.alias, string.upper(entry.name)))
	end
	Kit.label({
		Text = "Your notes so far:  " .. table.concat(notes, "   ·   "),
		font = "document",
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = Terms.f("New clue: {hand}'s first name has {n} letters.", { n = #target.first }),
		font = "bodyBold",
		color = C.candle,
		LayoutOrder = 2,
		Parent = body,
	})
	local options = {}
	for _, entry in ipairs(list) do
		table.insert(options, { id = entry.alias, text = entry.alias })
	end
	local picked: string? = nil
	local grid = Kit.frame({
		Name = "Suspects",
		Size = UDim2.new(1, 0, 0, math.ceil(#options / 3) * (48 + T.space.s)),
		LayoutOrder = 3,
		Parent = body,
	})
	local render
	render = Kit.pickGrid(grid, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		picked = id
		render(options, picked)
	end)
	render(options, nil)
	local box = nameField("document", 4)
	local result: TextLabel? = nil
	Kit.hold(
		{
			text = "Hold to serve the warrant",
			icon = "cuffs",
			variant = "primary",
			Size = UDim2.new(1, 0, 0, 56),
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
					Terms.f("Wrong suspect. In a match, arresting an innocent player hands the win to {hand}.")
				)
			elseif not NameUtil.matches(box.Text, target.first, target.last) then
				result = feedback("Right suspect, wrong name. A rejected warrant blocks you until the next round.")
			else
				finish()
			end
		end
	)
end

local function eyesDrill()
	win.setTitle(Terms.f("{Eyes}"))
	Kit.label({
		Text = Terms.f(
			"From round 2, one {cultist} may accept {eyes}. Up close, they see a player's real name for 3 seconds, but their own eyes glow red for everyone to see, and they die soon after."
		),
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = "A hood blocks the eyes for the round it is worn.",
		size = "small",
		color = C.dim,
		LayoutOrder = 2,
		Parent = body,
	})
	Kit.button({
		text = "Look at the dummies",
		icon = "eye",
		variant = "primary",
		Size = UDim2.new(1, 0, 0, 56),
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
				FontFace = T.font.document,
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
	Kit.clear(body)
	build()
	Router.open("practice")
end

function PracticePanel.init()
	win = Kit.window({ name = "practice", title = "Practice", size = "M" })
	body = Kit.scroll({ Parent = win.body })
	Kit.list(body, T.space.m)
	Kit.pad(body, T.space.xs, T.space.xs)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
	})
end

return PracticePanel
