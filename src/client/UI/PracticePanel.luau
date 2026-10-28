-- Academy drills that are not case files: a practice Manual, a practice arrest (the drill's id is still
-- "warrant") and a look through the Oculus. Everything runs on this client against the practice dummies;
-- the only thing sent to the server is "drill finished".

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
local Puppets = require(script.Parent.Parent.World.Puppets)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local C = Kit.color
local T = Kit.Tokens

local PracticePanel = {}

type Dummy = { part: BasePart, model: Model, alias: string, name: string, first: string, last: string }

-- The arrest drill's notes: where each dummy was (one each, so the clue points at one).
local PLACES = { "the archive", "the courtyard", "the bell tower", "the library", "the chapel" }

local win: any
local body: ScrollingFrame
local onFinished: (() -> ())? = nil
-- The dummy the Manual drill uses while the Trial points at one (nil: any dummy), and whether its real name
-- has been learned by staring yet (the Trial's drill only gives it away once it has).
local preferred: string? = nil
local preferredKnown = false

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

-- The puppet's strings go slack and it drops in a heap, then is hauled back up (only on this screen); the
-- grey stand-in (before the Lobby models are imported) tips over and stands up again.
local function collapse(target: Dummy)
	if Puppets.drop(target.part) then
		return
	end
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
	return Kit.label({ Text = text, color = C.white, LayoutOrder = 99, Parent = body })
end

-- The Manual's name field, handwritten.
local function nameField(order: number): TextBox
	local _, box = Kit.field({
		placeholder = "First name  Last name",
		font = "hand",
		size = 32,
		Size = UDim2.new(1, 0, 0, 60),
		LayoutOrder = order,
		Parent = body,
	})
	box.TextXAlignment = Enum.TextXAlignment.Center
	return box
end

-- Drills ----------------------------------------------------------------------------------

local function grimoireDrill()
	local list = dummies()
	if #list == 0 then
		return
	end
	local target = list[math.random(1, #list)]
	local trial = false
	for _, entry in ipairs(list) do
		if entry.alias == preferred then
			target = entry
			trial = true
		end
	end
	win.setTitle(Terms.f("Practice {grimoire}"))
	if trial and not preferredKnown then
		-- The Trial's turn to stare comes first: no name to write yet.
		Kit.label({
			Text = string.format("You don't know %s's real name yet. Stare at it first.", target.alias),
			LayoutOrder = 1,
			Parent = body,
		})
		Kit.button({
			text = "Go and stare",
			icon = "eye",
			variant = "primary",
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = 2,
			Parent = body,
		}, function()
			onFinished = nil
			Router.close("practice", "user")
		end)
		return
	end
	Kit.label({
		Text = Terms.f(
			if trial then "{alias}'s real name is {name}. Write it in full." else "Write {alias}'s real name: {name}.",
			{ alias = target.alias, name = string.upper(target.name) }
		),
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = "Spelling must be exact. Case doesn't matter.",
		size = "small",
		color = C.dim,
		LayoutOrder = 2,
		Parent = body,
	})
	local box = nameField(3)
	local result: TextLabel? = nil
	Kit.button({
		text = "Write the name",
		icon = "quill",
		variant = "primary",
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 4,
		Parent = body,
	}, function()
		if result then
			result:Destroy()
		end
		if NameUtil.matches(box.Text, target.first, target.last) then
			collapse(target)
			finish()
		else
			result = feedback("Wrong name. Check the spelling.")
		end
	end)
end

local function warrantDrill()
	local list = dummies()
	if #list == 0 then
		return
	end
	local target = list[math.random(1, #list)]
	win.setTitle("Practice arrest")
	-- Where everyone was when the victim fell: a place each, shuffled, and the clue points at one.
	local places = table.clone(PLACES)
	for index = #places, 2, -1 do
		local other = math.random(1, index)
		places[index], places[other] = places[other], places[index]
	end
	local where, notes = {}, {}
	for index, entry in ipairs(list) do
		where[entry.alias] = places[(index - 1) % #places + 1]
		table.insert(notes, string.format("%s:  %s", entry.alias, where[entry.alias]))
	end
	Kit.label({
		Text = Terms.f("You are {zero}. Point at your suspect."),
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = "Where everyone was: " .. table.concat(notes, ", "),
		font = "document",
		LayoutOrder = 2,
		Parent = body,
	})
	Kit.label({
		Text = string.format("Clue: someone in %s was staring at the victim with red eyes.", where[target.alias]),
		font = "bodyBold",
		color = C.candle,
		LayoutOrder = 3,
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
		LayoutOrder = 4,
		Parent = body,
	})
	local render
	render = Kit.pickGrid(grid, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		picked = id
		render(options, picked)
	end)
	render(options, nil)
	local result: TextLabel? = nil
	Kit.button({
		text = "Arrest",
		icon = "cuffs",
		variant = "primary",
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 5,
		Parent = body,
	}, function()
		if result then
			result:Destroy()
		end
		if picked ~= target.alias then
			result = feedback(Terms.f("Wrong suspect. In a real match, {zero} would die."))
		else
			-- Arrested: the puppet is yanked upright on its strings.
			Puppets.jerk(target.part)
			finish()
		end
	end)
end

local function eyesDrill()
	win.setTitle(Terms.f("{Eyes}"))
	Kit.label({
		Text = Terms.f("{Circle} learns names by hacking stations. A {cultist} with {eyes} can read names by staring."),
		LayoutOrder = 1,
		Parent = body,
	})
	Kit.label({
		Text = "Saw glowing eyes? Remember who they were looking at.",
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
			local head = Puppets.headOf(entry.part)
			local gui = Create("BillboardGui", {
				Adornee = head or entry.part,
				AlwaysOnTop = true,
				LightInfluence = 0,
				Size = UDim2.fromScale(7, 1.2),
				StudsOffset = Vector3.new(0, if head then 1.2 else 3.4, 0),
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

-- The Manual drill uses this dummy (its alias, "Dummy B") until set back to nil (the Trial points at one).
-- known: its real name was learned by staring; until then the drill sends the player to stare first.
function PracticePanel.prefer(alias: string?, known: boolean?)
	preferred = alias
	preferredKnown = known == true
end

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
