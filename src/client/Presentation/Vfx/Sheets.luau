--!strict
-- The VFX kit's flipbook sheets: which texture is a grid of frames, how big the grid is and how it plays. Pure data and
-- arithmetic (no Instances), so a spec can read it; Emit.make applies the answer to a ParticleEmitter.
--
-- Two kinds of name. The OLD ones (art/scripts/vfx, in the Fx props file since ModelsFx 3) keep exactly the way they have
-- always played. The NEW ones (the plan's Part 5 library, in the file from ModelsFx 4) play by their declared mode:
--   loop      runs round and round, each particle starting on a random frame
--   oneshot   plays once, its frame rate set from the particle's life so the last frame lands at its death
--   random    every particle picks one cell and holds it (a bag of different pieces, not an animation)
-- While the place has no real new texture (Tex.real false) a new name shows an OLD texture (Tex.FALLBACK), so it plays as
-- that old texture's own sheet; the new grid would cut the old picture into the wrong cells.

local Sheets = {}

export type Old = { grid: number, fps: number }
export type New = { grid: number, mode: string, fps: number? }

-- The old sheets: their grid and the rate they play at when an effect does not say.
Sheets.OLD = {
	VfxFlame = { grid = 8, fps = 30 },
	VfxCandleFlame = { grid = 8, fps = 30 },
	VfxSmoke = { grid = 8, fps = 24 },
	VfxWisp = { grid = 4, fps = 12 },
	VfxDust = { grid = 4, fps = 12 },
	VfxChunk = { grid = 2, fps = 0 },
	VfxMoth = { grid = 2, fps = 14 },
	VfxAsh = { grid = 4, fps = 16 },
} :: { [string]: Old }

-- The new sheets (the declared table of art/scripts/vfx/check_textures.py); fps is for a loop only. A one-shot sheet's rate
-- comes from the life, a random one has none. VfxCrackA/B, VfxScorch and VfxSigil are single images: not here.
Sheets.NEW = {
	VfxSmokePuff = { grid = 8, mode = "oneshot" },
	VfxSmokePlume = { grid = 8, mode = "loop", fps = 24 },
	VfxDustRoll = { grid = 8, mode = "oneshot" },
	VfxMist = { grid = 4, mode = "loop", fps = 12 },
	VfxFire = { grid = 8, mode = "loop", fps = 30 },
	VfxFireBurst = { grid = 8, mode = "oneshot" },
	VfxCandle = { grid = 8, mode = "loop", fps = 30 },
	VfxAuraFlame = { grid = 4, mode = "loop", fps = 24 },
	VfxImpactA = { grid = 4, mode = "oneshot" },
	VfxImpactB = { grid = 4, mode = "oneshot" },
	VfxImpactC = { grid = 4, mode = "oneshot" },
	VfxShock = { grid = 4, mode = "oneshot" },
	VfxGlint = { grid = 4, mode = "oneshot" },
	VfxSparks = { grid = 2, mode = "random" },
	VfxSlashA = { grid = 4, mode = "oneshot" },
	VfxSlashB = { grid = 4, mode = "oneshot" },
	VfxArc = { grid = 4, mode = "random" },
	VfxEnergyWisp = { grid = 4, mode = "loop", fps = 16 },
	VfxAshFlakes = { grid = 4, mode = "loop", fps = 16 },
	VfxShards = { grid = 4, mode = "random" },
	VfxPaper = { grid = 4, mode = "loop", fps = 12 },
	VfxFeatherTumble = { grid = 4, mode = "loop", fps = 12 },
} :: { [string]: New }

-- What an emitter's flipbook does.
export type Plan = {
	grid: number | { number },
	mode: string, -- "Loop" | "OneShot" | "PingPong" | "Random": an Enum.ParticleFlipbookMode name
	fps: number | { number },
	startRandom: boolean,
	blend: boolean,
}

-- The shortest life a spec gives its particles (seconds).
local function lifeMin(life: any): number
	if life == nil then
		return 1
	elseif type(life) == "number" then
		return life
	end
	return life[1]
end

-- The frame rate that lands a sheet's last frame at the death of the shortest-lived particle (a longer-lived one holds
-- its last frame, a one-shot's end, rather than being cut off before it).
function Sheets.oneShotFps(frames: number, life: any): number
	return frames / math.max(0.05, lifeMin(life))
end

-- The flipbook for a spec, or nil when it has none. `real` says whether the texture's own picture is in the place (Tex.real
-- of the name); `fallback` is Tex.FALLBACK, the old name each new one wears until then.
function Sheets.plan(spec: { [string]: any }, real: boolean, fallback: { [string]: string }): Plan?
	local name: string = spec.tex or ""
	local new = Sheets.NEW[name]
	if new and not real then
		-- (the old picture is on show: only its own grid can cut it; nothing the spec says about the new one applies)
		local old = fallback[name]
		local sheet = old and Sheets.OLD[old]
		if not sheet then
			return nil
		end
		return {
			grid = sheet.grid,
			mode = "Loop",
			fps = if spec.variants == true then 0 else sheet.fps,
			startRandom = true,
			blend = spec.blend ~= false,
		}
	end
	if new then
		local grid = spec.grid or new.grid
		local frames = if type(grid) == "number" then grid * grid else grid[1] * grid[2]
		local mode, fps, startRandom = "Loop", spec.fps, true
		local variants = spec.variants == true or (new.mode == "random" and spec.variants ~= false)
		if variants then
			-- (one random cell, held: a loop at no frame rate that starts anywhere)
			fps = 0
		elseif spec.mode ~= nil then
			mode = spec.mode
			startRandom = spec.startRandom == true
		elseif new.mode == "oneshot" then
			mode = "OneShot"
			startRandom = false
			fps = fps or Sheets.oneShotFps(frames, spec.life)
		else
			fps = fps or new.fps
		end
		if mode == "OneShot" and fps == nil then
			fps = Sheets.oneShotFps(frames, spec.life)
		end
		return {
			grid = grid,
			mode = mode,
			fps = fps or 30,
			startRandom = startRandom,
			blend = spec.blend ~= false,
		}
	end
	-- an old name, or none at all: the way it has always played
	local sheet = Sheets.OLD[name]
	local grid = spec.grid or (sheet and sheet.grid)
	if not grid then
		return nil
	end
	return {
		grid = grid,
		mode = spec.mode or "Loop",
		fps = if spec.variants == true then 0 else spec.fps or (sheet and sheet.fps) or 30,
		startRandom = spec.variants == true or spec.startRandom == true or (spec.grid == nil and sheet ~= nil),
		blend = spec.blend ~= false,
	}
end

return Sheets
