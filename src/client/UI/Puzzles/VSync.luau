-- Camera / Vertical hold: a monitor on the left, rolling while the hold is off (faster the further off, and the
-- way it is off) and tearing sideways while the tracking is off. Both right and the picture locks.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local BANDS = 6

-- A night street drawn in pencil: a moon, rooftops, a lamp and the kerb.
local function scene(parent: Instance)
	local function block(x, y, w, h, color, z)
		return Kit.Base.make("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			ZIndex = z or 2,
			Parent = parent,
		})
	end
	local moon = block(0.74, 0.1, 0.09, 0.13, Common.SHEET, 2)
	Kit.Base.round(moon)
	Kit.Base.stroke(moon, Common.INK, 2, 0)
	for b, h in ipairs({ 0.42, 0.6, 0.34, 0.52, 0.66, 0.4 }) do
		block((b - 1) * 0.17, 0.86 - h, 0.15, h, Common.GREY, 2)
		-- lit windows
		for w = 1, 3 do
			block((b - 1) * 0.17 + 0.03 + ((w - 1) % 2) * 0.06, 0.86 - h + 0.06 + w * 0.08, 0.03, 0.04, Common.SHEET, 3)
		end
	end
	block(0.6, 0.38, 0.012, 0.48, Common.INK, 3) -- the lamp post
	block(0.57, 0.36, 0.07, 0.03, Common.INK, 3)
	block(0, 0.86, 1, 0.02, Common.INK, 3) -- the kerb
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local hold, tracking = def.START, def.START

	local monitor =
		Common.card({ Name = "Monitor", fill = Common.SHEET, Size = UDim2.new(0.58, 0, 1, 0), Parent = ctx.area })
	local screen = Kit.Base.make("Frame", {
		Name = "Screen",
		BackgroundColor3 = Common.SHADE,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 1, -58),
		Parent = monitor,
	})
	-- the picture is cut in bands (each shows its own slice of the scene) so it can tear; each band holds the scene
	-- twice, one above the other, so a roll wraps round
	local bands, inners = {}, {}
	for i = 1, BANDS do
		local band = Kit.Base.make("Frame", {
			Name = "Band",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0, (i - 1) / BANDS),
			Size = UDim2.fromScale(1, 1 / BANDS),
			Parent = screen,
		})
		local inner = Kit.frame({ Name = "Inner", Size = UDim2.fromScale(1, BANDS * 2), Parent = band })
		for copy = 0, 1 do
			local holder = Kit.frame({
				Name = "Scene",
				Position = UDim2.fromScale(0, copy * 0.5),
				Size = UDim2.fromScale(1, 0.5),
				Parent = inner,
			})
			scene(holder)
		end
		bands[i], inners[i] = band, inner
	end
	Common.grain(screen, 0.75)
	local status = Common.caption(monitor, "no hold", {
		color = Common.INK,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -10),
		Size = UDim2.new(1, -28, 0, 22),
	})

	local controls = Kit.frame({
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.42, -16, 1, 0),
		Parent = ctx.area,
	})
	Kit.list(controls, Kit.space.l)
	Common.text(controls, "The hold stops the roll. The tracking stops the tear.", {
		color = Common.GREY,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 0,
	})
	local locked = false
	local function changed()
		if locked then
			return
		end
		status.Text = string.upper(
			if hold ~= puzzle.hold then "rolling" elseif tracking ~= puzzle.tracking then "tearing" else "locked"
		)
		if hold == puzzle.hold and tracking == puzzle.tracking then
			locked = true
			ctx.submit({ hold, tracking })
		end
	end
	Common.stepper(ctx, controls, "Vertical hold", hold, 0, def.MAX, function(v)
		hold = v
		changed()
	end, { LayoutOrder = 1, first = true })
	Common.stepper(ctx, controls, "Tracking", tracking, 0, def.MAX, function(v)
		tracking = v
		changed()
	end, { LayoutOrder = 2 })
	changed()

	local roll = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		local holdError = hold - puzzle.hold
		local trackError = math.abs(tracking - puzzle.tracking)
		roll = if holdError == 0 then 0 else (roll + holdError * dt * 0.12) % 1
		local t = os.clock()
		for i = 1, BANDS do
			local tear = if trackError == 0 then 0 else math.sin(t * 7 + i * 1.9) * trackError * 0.012
			-- (each band shows its slice of the scene: its own top, moved by the roll)
			inners[i].Position = UDim2.fromScale(0, -(i - 1) - roll * BANDS)
			bands[i].Position = UDim2.fromScale(tear, (i - 1) / BANDS)
		end
	end)
	screen.Destroying:Once(function()
		connection:Disconnect()
	end)
end
