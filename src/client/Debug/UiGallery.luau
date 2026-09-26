-- The design system on one page, for checking the look without playing a match: lettering at
-- every size, every surface, every control in every state, all icons and all slip kinds.
-- Opened from the debug panel's UI tab (Studio only). Resize the Studio window or use the
-- device emulator to see the phone layouts.

local Icons =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Icons"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Router = require(script.Parent.Parent.UI.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local UiGallery = {}

local built = false

local function section(parent: Instance, order: () -> number, title: string)
	Kit.frame({ Size = UDim2.new(1, 0, 0, T.space.l), LayoutOrder = order(), Parent = parent })
	Kit.text({ face = "Gothic", text = title, size = T.size.title, LayoutOrder = order(), Parent = parent })
	Kit.rule({ color = C.red, transparency = 0.4, LayoutOrder = order(), Parent = parent })
end

local function row(parent: Instance, order: () -> number, height: number?): Frame
	local frame = Kit.frame({
		Size = UDim2.new(1, 0, 0, height or T.touch + 8),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		LayoutOrder = order(),
		Parent = parent,
	})
	Kit.list(frame, T.space.m, true)
	return frame
end

local function build()
	local win = Kit.window({ name = "uiGallery", title = "The Grimoire kit", size = "L" })
	local list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, T.space.xs, T.space.xs)
	local order = Kit.counter()

	section(list, order, "Lettering")
	for _, size in ipairs({ T.size.hero, T.size.display, T.size.heading, T.size.title }) do
		Kit.text({ face = "Gothic", text = "Investigation " .. size, size = size, LayoutOrder = order(), Parent = list })
	end
	for _, size in ipairs({ 52, 40, 30, 24 }) do
		Kit.text({
			face = "Scrawl",
			text = "Kenji Mori, heart attack. letters letters",
			size = size,
			LayoutOrder = order(),
			Parent = list,
		})
	end
	for _, font in ipairs({ "body", "bodyBold", "bodyItalic", "label", "document", "mono" }) do
		Kit.label({
			Text = font .. ": The Hand writes one full real name a night.",
			font = font,
			LayoutOrder = order(),
			Parent = list,
		})
	end

	section(list, order, "Surfaces")
	local pages = row(list, order, 200)
	for _, tone in ipairs({ "black", "raised", "parchment", "white" }) do
		local _, content =
			Kit.page({ tone = tone, ruled = tone == "black", Size = UDim2.fromOffset(220, 190), Parent = pages })
		Kit.label({
			Text = tone,
			font = "document",
			color = if tone == "parchment" or tone == "white" then C.ink else C.bone,
			Parent = content,
		})
	end
	local marks = row(list, order, 110)
	Kit.banner({ text = "The Grimoire", size = T.size.heading, Parent = marks })
	Kit.seal({ size = 90, icon = "hand", Parent = marks })
	Kit.seal({ size = 90, color = C.steel, text = "A", Parent = marks })
	Kit.stamp({ text = "Case closed", width = 220, Parent = marks })
	Kit.heading({ text = "A section heading", detail = "with a detail", LayoutOrder = order(), Parent = list })
	local cards = row(list, order, 90)
	for _, tone in ipairs({ "raised", "lifted", "page", "parchment" }) do
		local card = Kit.card({
			tone = tone,
			accent = if tone == "raised" then T.rarity.Epic else nil,
			Size = UDim2.fromOffset(200, 80),
			Parent = cards,
		})
		Kit.label({ Text = "card: " .. tone, color = if tone == "parchment" then C.ink else C.bone, Parent = card })
	end

	section(list, order, "Controls")
	local buttons = row(list, order)
	for _, variant in ipairs({ "primary", "danger", "secondary", "ghost", "parchment", "good" }) do
		Kit.button({ text = variant, variant = variant, icon = "quill", key = "E", Parent = buttons })
	end
	local disabled = Kit.button({ text = "disabled", variant = "primary", Parent = buttons })
	Kit.setEnabled(disabled, false)
	local holds = row(list, order)
	Kit.hold({ text = "Hold to write", icon = "grimoire" }, 1.2, function()
		print("[Inkbound debug] held")
	end).Parent =
		holds
	Kit.iconButton({ icon = "settings", Parent = holds })
	Kit.keycap({ text = "LB", Parent = holds })
	local chips = row(list, order, 96)
	Kit.actionChip({ icon = "evidence", label = "Evidence", key = "B", Parent = chips })
	Kit.actionChip({ icon = "eye", label = "Read name", key = "R", variant = "primary", Parent = chips })
	Kit.actionChip({ icon = "mail", label = "Discard sheet", key = "D-Down", Parent = chips })
	Kit.actionChip({ icon = "quill", label = "Scratchpad", touch = true, Parent = chips })
	Kit.tabs({
		items = {
			{ id = "a", label = "Hats", icon = "hood" },
			{ id = "b", label = "Trails" },
			{ id = "c", label = "Eyes", icon = "eye" },
		},
		selected = "a",
		LayoutOrder = order(),
		Parent = list,
	}, function() end)
	for index, name in ipairs({ "Raven", "Moth", "Crow" }) do
		local line = Kit.nameLine({
			text = name,
			sub = "voted " .. index,
			right = string.rep("I", index),
			LayoutOrder = order(),
			Parent = list,
		})
		line.setMarked(index == 2)
		line.setSelected(index == 1)
	end
	Kit.entry({ text = "How to play", numeral = "I", LayoutOrder = order(), Parent = list })
	Kit.entry({ text = "The open chapter", numeral = "II", selected = true, LayoutOrder = order(), Parent = list })
	local picks = Kit.frame({ Name = "Picks", Size = UDim2.new(1, 0, 0, 104), LayoutOrder = order(), Parent = list })
	local renderPicks
	renderPicks = Kit.pickGrid(picks, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		renderPicks({
			{ id = 1, text = "Raven", sub = "voted" },
			{ id = 2, text = "Moth" },
			{ id = 3, text = "Crow" },
			{ id = 4, text = "Skip" },
		}, id)
	end)
	renderPicks({
		{ id = 1, text = "Raven", sub = "voted" },
		{ id = 2, text = "Moth" },
		{ id = 3, text = "Crow" },
		{ id = 4, text = "Skip" },
	}, 2)
	Kit.field({ placeholder = "Write a full name…", maxLength = 32, LayoutOrder = order(), Parent = list })
	local paper = Kit.card({ tone = "parchment", Size = UDim2.new(1, 0, 0, 80), LayoutOrder = order(), Parent = list })
	Kit.field({
		placeholder = "A field on paper…",
		font = "document",
		paper = true,
		Size = UDim2.fromScale(1, 1),
		Parent = paper,
	})
	Kit.slider({ LayoutOrder = order(), Parent = list }, "Music", 0.6, 0, 1, 0.1, function() end)
	Kit.toggle({ LayoutOrder = order(), Parent = list }, "Reduce motion", true, function() end)
	local _, setMeter = Kit.meter({ LayoutOrder = order(), Parent = list })
	setMeter(0.62)

	section(list, order, "Icons")
	local icons = Kit.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order(),
		Parent = list,
	})
	Kit.grid(icons, UDim2.fromOffset(84, 70), T.space.xs)
	local names = {}
	for name in pairs(Icons.cells) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local cell = Kit.frame({ Parent = icons })
		Kit.icon({
			name = name,
			size = 36,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Parent = cell,
		})
		Kit.label({
			Text = name,
			size = "micro",
			color = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 42),
			Parent = cell,
		})
	end

	section(list, order, "Slips")
	for kind in pairs(Kit.Slip.KINDS) do
		Kit.slip({
			text = "A " .. kind .. " slip: the tip box was emptied.",
			kind = kind,
			LayoutOrder = order(),
			Parent = list,
		})
	end
	Kit.register(win)
end

function UiGallery.open()
	if not built then
		built = true
		build()
	end
	Router.open("uiGallery")
end

return UiGallery
