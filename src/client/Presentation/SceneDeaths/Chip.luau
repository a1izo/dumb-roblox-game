-- Choked on a potato chip (11 s; remade 2026-11-11 as a scene death). Death Note's "I'll take a potato chip... and
-- EAT IT!", gone wrong. A dark study at night (the set: maps/venues/scenes/remade.py chip): the desk under its lamp,
-- rain on the tall window, the bag of chips on the desk. A hand into the bag; the chip held up; the flourish, filmed as
-- the anime films it (the camera whipping round from below, the picture going red and black with speed lines); the
-- bite; the crunch, a gold flash; frozen; then the hands go to the throat; staggering back, a hand out to the lens;
-- the knees; over onto the face on the floorboards. No words, no faces.

local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local ModelLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelLibrary"))
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local GOLD = Color3.fromRGB(255, 214, 120)
local LAMP = Color3.fromRGB(255, 206, 150)
local FLOURISH, BITE, CRUNCH, THROAT = 2.3, 3.15, 3.38, 5.0

local function build(ctx)
	local folder = ctx:set()
	if folder == nil then
		ctx:part({ size = Vector3.new(22, 1, 18), at = Vector3.new(0, -0.5, 0), color = Color3.fromRGB(40, 30, 24) })
		ctx:part({ size = Vector3.new(6, 2.8, 3.2), at = Vector3.new(0, 1.4, -2.6), color = Color3.fromRGB(50, 36, 26) })
	end
	-- the desk lamp's warm pool, the window's cold light behind the lens, a dim fill
	ctx:light(Vector3.new(-1.6, 5.4, -2.4), LAMP, 16, 1.8, true)
	ctx:light(Vector3.new(0, 6, -9), Color3.fromRGB(130, 150, 190), 22, 0.6)
	ctx:light(Vector3.new(6, 7, 6), Color3.fromRGB(90, 96, 120), 20, 0.3)

	-- the bag on the desk, at its front corner (found by looking down onto the desk's top)
	local deskTop = 2.9
	if folder then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		local hit = workspace:Raycast(ctx:world(Vector3.new(0.55, 8, -1.7)), Vector3.new(0, -12, 0), params)
		if hit then
			deskTop = ctx.origin:PointToObjectSpace(hit.Position).Y
		end
	end
	local bag = ModelLibrary.get("ChipBag")
	if bag then
		bag:PivotTo(ctx.origin * CFrame.new(0.6, deskTop, -1.7) * CFrame.Angles(0, math.rad(200), 0))
		for _, p in ipairs(bag:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		bag.Parent = ctx.stage.folder
	end

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneChipVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", Vector3.new(0, 4.5, 0))
	end
	local function chest(): Vector3
		return at("Torso", Vector3.new(0, 3, 0))
	end

	-- the chip (the Core's), in the right hand from the bag to the bite, held as a chip is held
	local chip: Instance? = nil
	ctx:at(1.05, function()
		local arm = victim and ctx:limb(victim, "Right Arm")
		if not victim or not arm then
			return
		end
		local model = ModelLibrary.get("Chip")
		if model then
			local _, size = model:GetBoundingBox()
			local biggest = math.max(size.X, size.Y, size.Z)
			if biggest > 0 then
				model:ScaleTo(model:GetScale() * 0.5 / biggest)
			end
			model:PivotTo(
				arm.CFrame
					* CFrame.new(0.023, -1.14, -0.157)
					* CFrame.Angles(math.rad(-47.58), math.rad(-0.5), math.rad(0.45))
			)
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanCollide = false
					p.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = arm
					weld.Part1 = p
					weld.Parent = p
				end
			end
			model.Parent = victim
			chip = model
		else
			chip = ctx:attach(victim, "Right Arm", {
				size = Vector3.new(0.5, 0.06, 0.38),
				at = Vector3.new(0, -1.12, -0.32),
				rot = Vector3.new(20, 30, 10),
				color = Color3.fromRGB(226, 182, 92),
				shape = "Cylinder",
				name = "Chip",
			})
		end
	end)
	-- the flourish: the picture goes red and black, speed lines rushing in to the hand
	ctx:at(FLOURISH, function()
		local layer = ctx:layer(3)
		local tint = Instance.new("Frame")
		tint.BorderSizePixel = 0
		tint.BackgroundColor3 = Color3.fromRGB(90, 0, 6)
		tint.BackgroundTransparency = 0.45
		tint.Size = UDim2.fromScale(1, 1)
		tint.Parent = layer
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		gradient.Parent = tint
		local lines = {}
		for k = 1, 30 do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.BackgroundColor3 = Color3.new(1, 1, 1)
			line.BackgroundTransparency = 0.35
			line.Position = UDim2.fromScale(0.5, 0.5)
			line.Size = UDim2.new(0.8, 0, 0, if k % 3 == 0 then 3 else 1)
			line.Rotation = k * 12
			line.Parent = layer
			table.insert(lines, line)
		end
		ctx:during(FLOURISH, CRUNCH + 0.15, function(t)
			for k, line in ipairs(lines) do
				line.Rotation = k * 12 + math.sin(t * 40 + k) * 3
				-- (the lines rush in: each starts far out and runs toward the middle, over and over)
				local u = ((t * 3 + k * 0.137) % 1)
				line.Position = UDim2.fromScale(
					0.5 + math.cos(math.rad(line.Rotation)) * 0.05 * (1 - u),
					0.5 + math.sin(math.rad(line.Rotation)) * 0.05 * (1 - u)
				)
				line.Size = UDim2.new(0.25 + 0.6 * u, 0, 0, if k % 3 == 0 then 3 else 1)
			end
		end)
		ctx:atNow(CRUNCH + 0.15, function()
			layer:Destroy()
		end)
	end)
	ctx:grade(
		FLOURISH,
		CRUNCH + 0.15,
		{ Saturation = -0.6, Contrast = 0.5, TintColor = Color3.fromRGB(255, 150, 150) },
		0.08
	)
	-- the crunch: a gold flash at the mouth, crumbs everywhere, the chip gone
	ctx:at(CRUNCH, function()
		Sfx.play("uiHover", { pitch = 0.5, volume = 1 })
		local h = victim and ctx:limb(victim, "Head")
		if h then
			local mouth = h.Position + h.CFrame.LookVector * 0.6 - Vector3.new(0, 0.25, 0)
			Vfx.Emit.burst(mouth, {
				tex = "VfxChunk",
				grid = 2,
				startRandom = true,
				color = { { 0, Color3.fromRGB(240, 200, 110) }, { 1, Color3.fromRGB(200, 150, 70) } },
				size = { { 0, 0.12 }, { 1, 0.06 } },
				life = { 0.6, 1.1 },
				speed = { 4, 9 },
				spread = 60,
				accel = Vector3.new(0, -30, 0),
				rot = { 0, 360 },
				spin = { -300, 300 },
				lit = 0.8,
			}, 30)
			Vfx.Recipes.twinkle(mouth + Vector3.new(0.3, 0.3, 0), { color = GOLD, scale = 1.4 })
			Vfx.Light.flash(mouth, GOLD, 10, 5, 0.4)
		end
		if chip then
			chip:Destroy()
			chip = nil
		end
		Cinema.flash(GOLD, 0.6, 0.3)
	end)
	-- frozen: the picture holds its breath (colour draining), then the choke breaks it
	ctx:grade(CRUNCH + 0.15, THROAT, { Saturation = -0.85, Contrast = 0.3 }, 0.6)
	ctx:at(THROAT, function()
		Vfx.Screen.shake(0.8, 0.4)
	end)

	-- cameras
	-- 0.0 from in front of the desk, low: the figure behind the lamp, the bag
	ctx:camera(0, 1.5, function(t)
		local u = t / 1.5
		return CFrame.lookAt(Vector3.new(1.4 - 0.4 * u, 3.3, -8 + 0.6 * u), Vector3.new(0, 3.6, -1.2)), 38
	end)
	-- 1.5 the hand, the chip held up in the lamplight
	ctx:camera(1.5, FLOURISH, function(_t)
		local h = at("Right Arm", Vector3.new(0.5, 3, -1))
		return CFrame.lookAt(Vector3.new(1.8, 3.6, -4.2), h + Vector3.new(0, -0.6, 0)), 32
	end)
	-- the flourish: whipping round from below, the picture tipping
	ctx:camera(FLOURISH, BITE, function(t)
		local u = (t - FLOURISH) / (BITE - FLOURISH)
		local a = math.rad(-70 + 140 * u)
		local h = head()
		local eye = h + Vector3.new(math.sin(a) * 3.2, -1.8, -math.cos(a) * 3.2)
		return CFrame.lookAt(eye, h + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(-18 + 36 * u)), 34 - 8 * u
	end)
	-- the bite: hard in on the face, snapping tighter on the crunch
	ctx:camera(BITE, 4.8, function(t)
		local h = head()
		local fov = if t < CRUNCH then 26 else 17 + (t - CRUNCH) * 0.8
		return CFrame.lookAt(h + Vector3.new(0.4, -0.15, -1.9), h + Vector3.new(0, -0.05, 0)), fov
	end)
	-- 4.8 handheld from the side: the choking, the stagger back, the hand out to the lens
	ctx:camera(4.8, 7.7, function(t)
		local c = chest()
		local shake = Vector3.new(math.sin(t * 7) * 0.08, math.sin(t * 9) * 0.06, 0)
		return CFrame.lookAt(Vector3.new(4.2, 3.8, -3.4) + shake, c + Vector3.new(0, 0.6, 0)), 40
	end)
	-- 7.7 high over the floor beside the desk: the knees, the fall, still
	ctx:camera(7.7, 11, function(t)
		local u = math.clamp((t - 7.7) / 3.3, 0, 1)
		return CFrame.lookAt(Vector3.new(2.5, 8.5 + 1.5 * u, -1.5), Vector3.new(0, 0.6, 1.2)), 42 - 4 * u
	end)
	ctx:grade(0, nil, { Saturation = -0.25, Contrast = 0.2, TintColor = Color3.fromRGB(250, 236, 220) }, 0.1)
end

return { length = 11, build = build }
