-- Camera · Vertical hold: the picture rolls while the hold is off and tears sideways while the
-- tracking is off. Both dials right and it locks.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local hold, tracking = def.START, def.START
	local screen = Kit.Base.make("Frame", {
		Name = "Screen",
		BackgroundColor3 = Color3.fromRGB(10, 14, 20),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(0.58, 0, 1, 0),
		Parent = ctx.area,
	})
	-- A night street, drawn as a picture that can roll and tear.
	local picture = Kit.frame({ Name = "Picture", Parent = screen })
	local bands = {}
	for i = 1, 8 do
		local band = Kit.frame({
			Name = "Band",
			Position = UDim2.fromScale(0, (i - 1) / 8),
			Size = UDim2.fromScale(1, 1 / 8),
			ClipsDescendants = true,
			Parent = picture,
		})
		local inner = Kit.frame({
			Name = "Inner",
			Position = UDim2.fromScale(0, -(i - 1)),
			Size = UDim2.fromScale(1, 8),
			Parent = band,
		})
		Kit.Base.make("Frame", { -- moon
			BackgroundColor3 = C.bone,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.72, 0.08),
			Size = UDim2.fromScale(0.1, 0.13),
			Parent = inner,
		})
		for b, h in ipairs({ 0.45, 0.62, 0.38, 0.55, 0.7 }) do
			Kit.Base.make("Frame", { -- buildings
				BackgroundColor3 = Color3.fromRGB(28, 34, 44),
				BorderSizePixel = 0,
				Position = UDim2.fromScale((b - 1) * 0.2, 1 - h),
				Size = UDim2.fromScale(0.19, h),
				Parent = inner,
			})
		end
		Kit.Base.make("Frame", { -- street
			BackgroundColor3 = Color3.fromRGB(46, 50, 58),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.88),
			Size = UDim2.fromScale(1, 0.12),
			Parent = inner,
		})
		bands[i] = band
	end
	local status = Common.caption(screen, "no signal", {
		Position = UDim2.new(0, 8, 0, 6),
		color = C.red,
	})
	local controls =
		Kit.frame({ Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 1), Parent = ctx.area })
	Kit.list(controls, Kit.space.m)
	local locked = false
	local function changed()
		if locked then
			return
		end
		if hold == puzzle.hold and tracking == puzzle.tracking then
			locked = true
			status.Text = "SIGNAL LOCKED"
			status.TextColor3 = C.good
			ctx.submit({ hold, tracking })
		end
	end
	local holdRow = Common.dial(controls, "Vertical hold", hold, 0, def.MAX, function(v)
		hold = v
		changed()
	end, { LayoutOrder = 1 })
	Common.dial(controls, "Tracking", tracking, 0, def.MAX, function(v)
		tracking = v
		changed()
	end, { LayoutOrder = 2 })
	ctx.first(holdRow:FindFirstChild("Plus") :: GuiObject)
	local roll = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		local holdError = hold - puzzle.hold
		local trackError = math.abs(tracking - puzzle.tracking)
		roll = (roll + holdError * dt * 0.35) % 1
		picture.Position = UDim2.fromScale(0, if holdError == 0 then 0 else roll)
		for i, band in ipairs(bands) do
			local tear = if trackError == 0 then 0 else math.sin(os.clock() * 9 + i * 1.7) * trackError * 0.02
			band.Position = UDim2.fromScale(tear, (i - 1) / 8)
		end
	end)
	screen.Destroying:Once(function()
		connection:Disconnect()
	end)
end
