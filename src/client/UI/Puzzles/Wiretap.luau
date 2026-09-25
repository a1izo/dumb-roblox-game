-- Phone · Wiretap: the recording's waveform (pale) and yours (red). Tune frequency and gain
-- until they lie on top of each other.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

local POINTS = 40

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local frequency, gain = def.START[1], def.START[2]
	local scope = Kit.Base.make("Frame", {
		Name = "Scope",
		BackgroundColor3 = Color3.fromRGB(10, 18, 14),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0.55, 0),
		Parent = ctx.area,
	})
	Kit.Base.make("Frame", { -- the zero line
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = scope,
	})
	local function wave(holder: Instance, f: number, g: number, color: Color3, size: number)
		for i = 0, POINTS - 1 do
			local t = i / (POINTS - 1)
			local y = 0.5 - math.sin(t * math.pi * 2 * f / 2 + puzzle.phase) * g / (def.MAX_GAIN + 1) * 0.45
			Common.dot(holder, t, y, size, color, 4)
		end
	end
	local recording = Kit.frame({ Name = "Recording", Parent = scope })
	wave(recording, puzzle.frequency, puzzle.gain, Color3.fromRGB(150, 220, 170), 8)
	local live = Kit.frame({ Name = "Live", ZIndex = 5, Parent = scope })
	local done = false
	local function draw()
		Kit.clear(live)
		wave(live, frequency, gain, C.red, 4)
		if not done and frequency == puzzle.frequency and gain == puzzle.gain then
			done = true
			ctx.submit({ frequency, gain })
		end
	end
	local controls =
		Kit.frame({ Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), Parent = ctx.area })
	Kit.list(controls, Kit.space.s)
	local row = Common.dial(controls, "Frequency", frequency, 1, def.MAX_FREQUENCY, function(v)
		frequency = v
		draw()
	end, { LayoutOrder = 1 })
	Common.dial(controls, "Gain", gain, 1, def.MAX_GAIN, function(v)
		gain = v
		draw()
	end, { LayoutOrder = 2 })
	ctx.first(row:FindFirstChild("Plus") :: GuiObject)
	draw()
end
