-- and I.. am.. (art/refs/deaths/ironman.md, 18 s): a ruined battlefield at dusk; the victim on one knee before a
-- towering armoured warlord (our own design) with an army behind him. The gauntlet on the victim's right hand, the six
-- stones sliding in and lighting one after another, energy crackling up the arm; the warlord sees it; the look up,
-- "And I... am..."; the SNAP; white; a shockwave in the stones' six colours; the army goes to ash figure by figure,
-- the warlord sits down slow and goes to ash; the victim staggers back, the arm burnt black and smoking, sits against
-- a broken wall; the light in the chest dims and goes out.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Costumes = require(script.Parent.Costumes) :: any

local STONES = {
	Color3.fromRGB(160, 70, 240),
	Color3.fromRGB(60, 130, 255),
	Color3.fromRGB(255, 40, 50),
	Color3.fromRGB(255, 150, 30),
	Color3.fromRGB(60, 230, 100),
	Color3.fromRGB(255, 220, 60),
}
local ASH = Color3.fromRGB(120, 112, 104)

local function ashAway(ctx, model: Model, seconds: number)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
			Vfx.Emit.burst(p.Position, {
				tex = "VfxDust",
				color = ASH,
				size = { { 0, 0.18 }, { 1, 0.08 } },
				life = { 1.2, 2.2 },
				speed = { 1, 3 },
				spread = 50,
				accel = Vector3.new(4, 1.5, 0),
				drag = 0.6,
				lit = 0.6,
			}, 14, p.Size)
			ctx:tween(p, seconds, { Transparency = 1, Color = ASH })
		elseif p:IsA("Decal") then
			ctx:tween(p, seconds, { Transparency = 1 })
		end
	end
end

-- The set of parts (before it was modelled): only when the Scenes import is missing.
local function standIn(ctx)
	-- the battlefield
	ctx:part({
		size = Vector3.new(200, 1, 200),
		at = Vector3.new(0, -0.5, -20),
		color = Color3.fromRGB(70, 58, 48),
		material = Enum.Material.Mud,
	})
	for k = 1, 16 do
		ctx:part({
			size = Vector3.new(1.5 + k % 4, 0.8 + k % 3, 1.2 + k % 5),
			at = Vector3.new(-30 + (k * 37) % 60, 0.4, -40 + (k * 23) % 50),
			rot = Vector3.new(k * 13, k * 41, k * 7),
			color = Color3.fromRGB(96, 90, 84),
			material = Enum.Material.Concrete,
		})
	end
	ctx:part({
		size = Vector3.new(7, 6, 1.2),
		at = Vector3.new(0.5, 3, 2.8),
		rot = Vector3.new(0, 4, -3),
		color = Color3.fromRGB(104, 96, 88),
		material = Enum.Material.Concrete,
	})
	ctx:part({
		size = Vector3.new(4, 9, 1),
		at = Vector3.new(-12, 4.5, -18),
		rot = Vector3.new(0, 20, 6),
		color = Color3.fromRGB(90, 84, 78),
		material = Enum.Material.Concrete,
	})
	local sky = ctx:part({
		size = Vector3.new(400, 160, 1),
		at = Vector3.new(0, 60, -120),
		color = Color3.fromRGB(200, 120, 70),
		cast = false,
	})
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.LightInfluence = 0
	g.Parent = sky
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 50, 54)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(190, 110, 60)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(240, 160, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 66, 50)),
	})
	grad.Parent = f
	for _, w in ipairs({
		{ Vector3.new(1, 160, 300), Vector3.new(-120, 60, -20) },
		{ Vector3.new(1, 160, 300), Vector3.new(120, 60, -20) },
		{ Vector3.new(300, 160, 1), Vector3.new(0, 60, 80) },
	}) do
		ctx:part({ size = w[1], at = w[2], color = Color3.fromRGB(110, 76, 56), cast = false })
	end
	ctx:part({
		size = Vector3.new(300, 1, 300),
		at = Vector3.new(0, 140, -20),
		color = Color3.fromRGB(70, 56, 52),
		cast = false,
	})
	ctx:light(Vector3.new(30, 14, -50), Color3.fromRGB(255, 150, 80), 120, 2.4, true)
	ctx:light(Vector3.new(-4, 8, 6), Color3.fromRGB(220, 190, 170), 30, 2.0)
	ctx:light(Vector3.new(6, 10, 2), Color3.fromRGB(255, 200, 150), 30, 2.6, true)
	ctx:light(Vector3.new(-5, 6, -3), Color3.fromRGB(170, 190, 255), 24, 1.4)
	ctx:light(Vector3.new(0, 12, -11), Color3.fromRGB(255, 180, 120), 30, 2.2)
end

local function build(ctx)
	if ctx:set() then
		-- (the battlefield, modelled: art/scripts/maps/venues/scenes/ironman.py; the low sun behind the army;
		-- an ember fill on the faces turned away from it)
		ctx:light(Vector3.new(4, 6, 6), Color3.fromRGB(255, 170, 110), 18, 0.6)
		ctx:light(Vector3.new(-3, 5, -2), Color3.fromRGB(170, 180, 230), 14, 0.35)
	else
		standIn(ctx)
	end
	for _, at in ipairs({ Vector3.new(-18, 0, -30), Vector3.new(16, 0, -26), Vector3.new(-6, 0, -44) }) do
		SceneDeaths.emit(ctx, at, Vector3.new(4, 1, 4), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(70, 64, 60),
			size = { { 0, 4 }, { 1, 12 } },
			alpha = { { 0, 0.4 }, { 1, 1 } },
			life = { 5, 8 },
			speed = { 2, 4 },
			spread = 15,
			rot = { 0, 360 },
			lit = 0.5,
			rate = 4,
		}):Emit(8)
	end
	SceneDeaths.emit(ctx, Vector3.new(0, 8, -10), Vector3.new(50, 14, 40), {
		tex = "VfxDust",
		color = Color3.fromRGB(150, 130, 110),
		size = { { 0, 0.1 }, { 1, 0.05 } },
		life = { 4, 6 },
		speed = { 0.5, 1.5 },
		spread = 180,
		accel = Vector3.new(1.5, -0.2, 0),
		lit = 0.6,
		rate = 60,
	})

	-- the warlord, the army behind him, the victim on one knee before him
	local killer = ctx:actor("figure", CFrame.lookAt(Vector3.new(0, 0, -6.5), Vector3.zero), "sceneIronKiller", 0, 1.5)
	if killer then
		local plate = Color3.fromRGB(60, 54, 70)
		ctx:dress(killer, {
			head = Color3.fromRGB(70, 62, 84),
			torso = plate,
			arms = plate,
			legs = plate,
			material = Enum.Material.Metal,
			face = false,
		})
		-- his ridged gold helm and chest plate (modelled: props_scenes)
		ctx:wear(killer, "warlordHelm")
		ctx:wear(killer, "warlordPlate")
	end
	local army = {}
	for k = 1, 14 do
		local at = Vector3.new(-16 + (k % 7) * 5.2 + (k > 7 and 2.6 or 0), 0, -12 - (k > 7 and 6 or 0))
		-- (each soldier from its own moment of the looping stance: the ranks never move as one)
		local s = ctx:actor("figure", CFrame.lookAt(at, Vector3.new(0, 0, 4)), "sceneIronSoldier", -((k * 2.3) % 18))
		if s then
			ctx:dress(s, {
				head = Color3.fromRGB(46, 44, 50),
				torso = Color3.fromRGB(40, 38, 44),
				arms = Color3.fromRGB(40, 38, 44),
				legs = Color3.fromRGB(34, 32, 38),
				face = false,
			})
			ctx:wear(s, "spear")
			table.insert(army, s)
		end
	end
	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6.5)), "sceneIronVictim")
	local stones = {}
	local gauntlet: Model? = nil
	local chestLight: PointLight? = nil
	local chestDisc: BasePart? = nil
	if victim then
		ctx:face(victim, "pain")
		-- the gauntlet (modelled: props_scenes), its six sockets empty until each stone slides in at 2.05+
		gauntlet = ctx:wear(victim, "gauntlet")
		local spec = Costumes.gauntlet
		local base = Vector3.new(spec.at[1].p[1], spec.at[1].p[2], spec.at[1].p[3])
		for _, socket in ipairs(Costumes.gauntletSockets) do
			-- (in the arm's frame: the gauntlet sits square on it; a stone stands a little proud of its socket)
			local at = base + Vector3.new(socket[1], socket[2], socket[3] - 0.03)
			local s = ctx:attach(victim, "Right Arm", {
				size = Vector3.new(0.13, 0.13, 0.13),
				at = at,
				color = Color3.fromRGB(30, 30, 30),
				shape = "Ball",
				glow = false,
				name = "Stone",
			})
			table.insert(stones, s)
		end
		chestDisc = ctx:attach(victim, "Torso", {
			size = Vector3.new(0.45, 0.45, 0.06),
			at = Vector3.new(0, 0.35, -0.52),
			color = Color3.fromRGB(150, 220, 255),
			glow = true,
			shape = "Cylinder",
			rot = Vector3.new(0, 90, 0),
		})
		local torso = ctx:limb(victim, "Torso")
		if torso then
			chestLight = Instance.new("PointLight")
			chestLight.Color = Color3.fromRGB(150, 220, 255)
			chestLight.Range = 5
			chestLight.Brightness = 2
			chestLight.Parent = torso
		end
	end
	local function head(m: Model?): Vector3
		local h = m and ctx:limb(m, "Head")
		return if h then ctx.origin:PointToObjectSpace(h.Position) else Vector3.new(0, 4.6, 0)
	end
	local function hand(): Vector3
		local a = victim and ctx:limb(victim, "Right Arm")
		return if a
			then ctx.origin:PointToObjectSpace((a.CFrame * CFrame.new(0, -0.9, 0)).Position)
			else Vector3.new(0.6, 4, -1)
	end

	-- 0.0 wide: towering warlord, the kneeling victim, the army
	ctx:shot(0.0, Vector3.new(9, 4.2, 5), Vector3.new(0, 3.5, -4), 50, { eye = Vector3.new(8.4, 4.0, 4.4) })
	-- 2.0 close on the gauntlet: the stones slide in, one after another
	ctx:shot(2.0, function()
		return hand() + Vector3.new(0.9, 0.2, -2.4)
	end, function()
		return hand()
	end, 38)
	for i = 1, 6 do
		ctx:at(2.05 + (i - 1) * 0.22, function()
			local s = stones[i]
			if s then
				s.Color = STONES[i]
				s.Material = Enum.Material.Neon
				Vfx.Emit.burst(s.Position, {
					tex = "VfxFlare",
					color = STONES[i],
					size = { { 0, 0.2 }, { 0.2, 1.4 }, { 1, 0 } },
					life = 0.25,
					rot = { 0, 360 },
					bright = 2.4,
					z = 2,
				}, 1)
				Vfx.Light.flash(s.Position, STONES[i], 8, 2, 0.3)
			end
		end)
	end
	ctx:during(2.0, 8.6, function()
		if math.random() < 0.18 and victim then
			local a = ctx:limb(victim, "Right Arm")
			if a then
				local from = (a.CFrame * CFrame.new(math.random() - 0.5, -1, math.random() - 0.5)).Position
				Vfx.Beams.bolt(
					from,
					(a.CFrame * CFrame.new(math.random() - 0.5, 0.8, math.random() - 0.5)).Position,
					0.12,
					{
						color = Color3.fromRGB(255, 220, 160),
						width = 0.06,
						bright = 2,
						pieces = 5,
					}
				)
			end
		end
	end)
	-- 3.5 the warlord sees it
	ctx:shot(3.5, function()
		return head(killer) + Vector3.new(1.2, -1.6, 5.2)
	end, function()
		return head(killer)
	end, 34)
	-- 5.0 the look up, the line
	ctx:shot(5.0, function()
		return head(victim) + Vector3.new(0.9, -1.0, -2.8)
	end, function()
		return head(victim) + Vector3.new(0, 0.2, 0)
	end, 38)
	ctx:at(5.4, function()
		table.insert(ctx.cleanups, Cinema.line({ { "And", 0 }, { "I...", 0.5 }, { "am...", 1.9 } }, 3.0))
	end)
	-- 8.5 the fingers: the snap; 9.0 white, the six-colour shockwave
	ctx:shot(8.5, function()
		return hand() + Vector3.new(0.9, 0.3, -0.9)
	end, function()
		return hand()
	end, 26)
	ctx:at(8.62, function()
		Cinema.flash(Color3.new(1, 1, 1), 1, 1.1)
		local at = ctx:world(hand())
		Vfx.Light.flash(at, Color3.new(1, 1, 1), 80, 8, 0.8)
		for i, c in ipairs(STONES) do
			task.delay(0.05 * i, function()
				Vfx.Beams.wave(
					CFrame.new(at),
					0.5,
					60,
					1.6,
					{ tex = "VfxRingBand", color = c, width = 1.2, light = 1, bright = 2 }
				)
			end)
		end
	end)
	ctx:shot(9.0, Vector3.new(14, 7, 8), Vector3.new(0, 3, -8), 56)
	-- 10.0 the army goes to ash, figure by figure; the warlord sits down slowly and goes too
	for k, s in ipairs(army) do
		ctx:at(10.0 + k * 0.17, function()
			ashAway(ctx, s, 1.4)
		end)
	end
	ctx:at(12.0, function()
		if killer then
			ashAway(ctx, killer, 1.8)
		end
	end)
	-- (from in front of the broken wall, at the right: from behind it, the modelled wall filled the frame's left)
	ctx:shot(10.0, Vector3.new(7.5, 3.4, 1.8), Vector3.new(-1, 3.6, -9), 50, { eye = Vector3.new(6.6, 3.6, 2.3) })
	-- 13.0 the victim staggering back, sitting down against the wall, the arm burnt black and smoking
	ctx:at(12.9, function()
		if not victim then
			return
		end
		-- burnt black: the arm, the stones and the gauntlet (its painted textures gone, so its colour shows, from a dark
		-- red to char)
		local burnt = { ctx:limb(victim, "Right Arm") }
		for _, s in ipairs(stones) do
			table.insert(burnt, s)
		end
		for _, p in ipairs(if gauntlet then gauntlet:GetDescendants() else {}) do
			if p:IsA("SurfaceAppearance") then
				p:Destroy()
			elseif p:IsA("BasePart") then
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
				p.Color = Color3.fromRGB(70, 20, 18)
				table.insert(burnt, p)
			end
		end
		for _, p in ipairs(burnt) do
			if p then
				ctx:tween(p, 0.8, { Color = Color3.fromRGB(26, 22, 20) })
				p.Material = Enum.Material.Slate
			end
		end
		local arm = ctx:limb(victim, "Right Arm")
		if arm then
			Vfx.Emit.make(arm, {
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = Color3.fromRGB(90, 86, 82),
				size = { { 0, 0.4 }, { 1, 1.6 } },
				alpha = { { 0, 0.5 }, { 1, 1 } },
				life = { 1.2, 1.8 },
				speed = { 0.6, 1.2 },
				accel = Vector3.new(0, 1.4, 0),
				rot = { 0, 360 },
				rate = 6,
			})
			Vfx.Emit.make(arm, {
				tex = "VfxEmber",
				color = Color3.fromRGB(255, 120, 40),
				size = { { 0, 0.1 }, { 1, 0 } },
				life = { 0.5, 1 },
				speed = { 0.5, 1.5 },
				spread = 60,
				accel = Vector3.new(0, 2, 0),
				bright = 1.6,
				rate = 14,
			})
		end
	end)
	ctx:shot(13.0, Vector3.new(4.6, 3.6, -4.6), Vector3.new(0, 2.8, 0.4), 44)
	-- 15.5 close: the head lolling, the chest light dimming out
	ctx:shot(15.5, function()
		return head(victim) + Vector3.new(0.8, -0.6, -2.6)
	end, function()
		return head(victim) + Vector3.new(0, -0.5, 0)
	end, 36)
	ctx:at(15.8, function()
		if chestLight then
			ctx:tween(chestLight, 1.8, { Brightness = 0 })
		end
		if chestDisc then
			ctx:tween(chestDisc, 1.8, { Color = Color3.fromRGB(30, 34, 40) })
		end
	end)
	ctx:grade(0, nil, { Saturation = -0.15, Contrast = 0.14, TintColor = Color3.fromRGB(255, 226, 200) }, 0.1)
end

return { length = 18, build = build }
