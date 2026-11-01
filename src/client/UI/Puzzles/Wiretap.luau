-- Phone / Wiretap: the recording's waveform in pencil on the scope, and the live line in ink over it. Tune the
-- frequency (how many waves) and the gain (how tall) until the live line lies on the recording.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local T = Kit.Tokens

local POINTS = 48

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local frequency, gain = def.START[1], def.START[2]

	local scope = Common.card({
		Name = "Scope",
		fill = Common.SHEET,
		Size = UDim2.new(1, 0, 1, -(T.touch * 2 + 32)),
		Parent = ctx.area,
	})
	local trace = Kit.Base.make("Frame", {
		Name = "Trace",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		Parent = scope,
	})
	for i = 1, 3 do
		Common.rule(
			trace,
			UDim2.fromScale(0, i / 4),
			UDim2.new(1, 0, 0, 1),
			if i == 2 then Common.SOFT else Common.FAINT
		)
	end
	for i = 1, 7 do
		Common.rule(trace, UDim2.fromScale(i / 8, 0), UDim2.new(0, 1, 1, 0))
	end
	local function y(t: number, f: number, g: number): number
		return 0.5 - math.sin(t * math.pi * f + puzzle.phase) * g / (def.MAX_GAIN + 1) * 0.46
	end
	for i = 0, POINTS - 1 do
		local t = i / (POINTS - 1)
		Common.dot(trace, t, y(t, puzzle.frequency, puzzle.gain), 9, Common.FAINT, 3)
	end
	local live = {}
	for i = 0, POINTS - 1 do
		live[i] = Common.dot(trace, 0, 0.5, 4, Common.INK, 5)
	end
	local status = Common.caption(scope, "", {
		color = Common.INK,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(200, 18),
	})
	status.ZIndex = 8

	local done = false
	local function draw()
		for i = 0, POINTS - 1 do
			local t = i / (POINTS - 1)
			live[i].Position = UDim2.fromScale(t, y(t, frequency, gain))
		end
		local close = (if frequency == puzzle.frequency then 1 else 0) + (if gain == puzzle.gain then 1 else 0)
		status.Text = if close == 2 then "CLEAR LINE" elseif close == 1 then "NEARLY" else "STATIC"
		if not done and close == 2 then
			done = true
			for _, dot in pairs(live) do
				dot.BackgroundColor3 = Common.RED
			end
			ctx.submit({ frequency, gain })
		end
	end

	local controls = Kit.frame({
		Name = "Controls",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch * 2 + 16),
		Parent = ctx.area,
	})
	Kit.list(controls, 16)
	Common.stepper(ctx, controls, "Frequency", frequency, 1, def.MAX_FREQUENCY, function(v)
		frequency = v
		draw()
	end, { LayoutOrder = 1, first = true })
	Common.stepper(ctx, controls, "Gain", gain, 1, def.MAX_GAIN, function(v)
		gain = v
		draw()
	end, { LayoutOrder = 2 })
	draw()
end
