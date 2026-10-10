--!strict
-- Tracks in the snow (the campus's mechanic), the parts both sides share: where a print is left, the
-- store of recent prints (oldest out first, never more than CAP, none older than LIFE) and their wire
-- format: 8 bytes a print (position to an eighth of a stud from the map's origin, heading, age).

local Tracks = {}

Tracks.STRIDE = 2.2 -- studs walked between two prints
Tracks.SPREAD = 0.35 -- left and right of the line walked
Tracks.REACH = 4.5 -- how far below the body the ground is looked for
Tracks.LIFE = 60 -- seconds a print lasts
Tracks.CAP = 1800 -- prints kept at most

export type Print = { x: number, y: number, z: number, heading: number, t: number }
export type Decoded = { x: number, y: number, z: number, heading: number, age: number }

-- Untrodden snow takes prints: the lawns' looks ("Snow" and its variants), never the swept paths.
function Tracks.leavesPrint(look: any): boolean
	return type(look) == "string" and string.sub(look, 1, 4) == "Snow" and look ~= "SnowPath"
end

export type Recorder = {
	add: (x: number, y: number, z: number, heading: number, t: number) -> Print,
	prune: (now: number) -> (),
	all: (now: number) -> { Print },
	clear: () -> (),
}

function Tracks.newRecorder(cap: number?, life: number?): Recorder
	local most = cap or Tracks.CAP
	local lasts = life or Tracks.LIFE
	local list: { Print } = {}
	local recorder = {} :: Recorder
	function recorder.add(x, y, z, heading, t)
		local print_ = { x = x, y = y, z = z, heading = heading, t = t }
		table.insert(list, print_)
		while #list > most do
			table.remove(list, 1)
		end
		return print_
	end
	function recorder.prune(now)
		local cut = 0
		for i, print_ in ipairs(list) do
			if now - print_.t < lasts then
				break
			end
			cut = i
		end
		for _ = 1, cut do
			table.remove(list, 1)
		end
	end
	function recorder.all(now)
		recorder.prune(now)
		return table.clone(list)
	end
	function recorder.clear()
		table.clear(list)
	end
	return recorder
end

local BYTES = 8
local SCALE = 8 -- an eighth of a stud
local AGE_STEP = 0.25 -- seconds per unit of age (255 units: just over a minute)

local function i16(v: number): number
	return math.clamp(math.round(v * SCALE), -32768, 32767)
end

function Tracks.encode(prints: { Print }, now: number): buffer
	local b = buffer.create(#prints * BYTES)
	for i, print_ in ipairs(prints) do
		local o = (i - 1) * BYTES
		buffer.writei16(b, o, i16(print_.x))
		buffer.writei16(b, o + 2, i16(print_.y))
		buffer.writei16(b, o + 4, i16(print_.z))
		local turn = (print_.heading / (2 * math.pi)) % 1
		buffer.writeu8(b, o + 6, math.round(turn * 255))
		buffer.writeu8(b, o + 7, math.clamp(math.round((now - print_.t) / AGE_STEP), 0, 255))
	end
	return b
end

function Tracks.decode(b: buffer): { Decoded }
	local out = {}
	for o = 0, buffer.len(b) - BYTES, BYTES do
		table.insert(out, {
			x = buffer.readi16(b, o) / SCALE,
			y = buffer.readi16(b, o + 2) / SCALE,
			z = buffer.readi16(b, o + 4) / SCALE,
			heading = buffer.readu8(b, o + 6) / 255 * 2 * math.pi,
			age = buffer.readu8(b, o + 7) * AGE_STEP,
		})
	end
	return out
end

return Tracks
