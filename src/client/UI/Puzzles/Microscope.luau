-- Forensics / Microscope: a fibre from the page in the eyepiece, out of focus and badly lit. Turn the focus until
-- it is one sharp line and the light until the field is clear; then the three fibres on the slide tray can be
-- compared, and the matching one picked.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local T = Kit.Tokens

-- Draws a fibre (a bent line across) in a new frame inside `parent`; `blur` doubles it into ghosts.
local function fibre(parent: GuiObject, bends: { number }, blur: number, z: number): Frame
	local holder = Kit.frame({ Name = "Fibre", ZIndex = z, Parent = parent })
	local count = #bends
	for copy = -1, 1 do
		if copy == 0 or blur > 0 then
			local offset = copy * blur * 0.018
			local px, py = 0, 0.5
			for i, bend in ipairs(bends) do
				local x, y = i / count, 0.5 + bend * 0.1
				local line =
					Common.scaleLine(holder, px, py + offset, x, y + offset, if blur > 0 then 5 else 3, Common.INK, z)
				line.BackgroundTransparency = if blur > 0 then math.min(0.5 + blur * 0.07, 0.85) else 0
				px, py = x, y
			end
		end
	end
	return holder
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local focus, light = def.START, def.START

	local left = Kit.frame({ Name = "Scope", Size = UDim2.new(0.46, -8, 1, 0), Parent = ctx.area })
	local lens = Kit.Base.make("CanvasGroup", {
		Name = "Eyepiece",
		BackgroundColor3 = Common.SHEET,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -(T.touch * 2 + 28)),
		Parent = left,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = lens })
	Kit.Base.make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = lens })
	-- the eyepiece's rim, drawn over it
	local rim = Kit.Base.make("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = lens.Size,
		ZIndex = 5,
		Parent = left,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = rim })
	Kit.Base.round(rim)
	Kit.Base.stroke(rim, Common.INK, 4, 0)
	Kit.Boil.attach(rim, 1)
	-- dark (too little light) or washed out (too much)
	local dark = Kit.Base.make("Frame", {
		Name = "Dark",
		BackgroundColor3 = Kit.color.ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = lens,
	})
	local glare = Kit.Base.make("Frame", {
		Name = "Glare",
		BackgroundColor3 = Common.SHEET,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = lens,
	})

	local controls = Kit.frame({
		Name = "Controls",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch * 2 + 12),
		Parent = left,
	})
	Kit.list(controls, 12)

	local tray = Kit.frame({
		Name = "Tray",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.54, -8, 1, 0),
		Parent = ctx.area,
	})
	Common.caption(tray, "slide tray", { Size = UDim2.new(1, 0, 0, 18) })
	local slides = Common.grid(
		tray,
		1,
		#puzzle.choices,
		10,
		{ Name = "Slides", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24) }
	)
	local choices = {}
	local sharp = false
	local current: Frame? = nil
	local function draw()
		local blur = math.abs(focus - puzzle.focus)
		local off = light - puzzle.light
		dark.BackgroundTransparency = if off < 0 then 1 - math.min(-off * 0.13, 0.85) else 1
		glare.BackgroundTransparency = if off > 0 then 1 - math.min(off * 0.15, 0.9) else 1
		if current then
			current:Destroy()
		end
		current = fibre(lens, puzzle.sample, blur, 3)
		sharp = blur == 0 and off == 0
		for _, choice in ipairs(choices) do
			Common.setEnabled(choice, sharp)
		end
		ctx.hint(if sharp then "Sharp. Now pick the matching fibre." else def.hint)
	end
	Common.stepper(ctx, controls, "Focus", focus, 0, def.MAX, function(v)
		focus = v
		draw()
	end, { LayoutOrder = 1, first = true })
	Common.stepper(ctx, controls, "Light", light, 0, def.MAX, function(v)
		light = v
		draw()
	end, { LayoutOrder = 2 })

	for index, bends in ipairs(puzzle.choices) do
		local tile
		tile = Common.target(ctx, { Name = "Slide", LayoutOrder = index, Parent = slides }, function()
			if not sharp then
				return
			end
			if ctx.submit({ focus, light, index }) then
				Common.ring(tile, nil, 0.95)
			else
				ctx.miss(tile, "Not the same fibre.")
			end
		end)
		Common.caption(tile, "slide " .. index, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18) })
		local art = Kit.frame({
			Name = "Art",
			Position = UDim2.new(0.06, 0, 0, 20),
			Size = UDim2.new(0.88, 0, 1, -24),
			Parent = tile,
		})
		fibre(art, bends, 0, 3)
		table.insert(choices, tile)
	end
	draw()
end
