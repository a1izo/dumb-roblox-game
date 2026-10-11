--!strict
-- The wire format of the Tokyo scramble's snapshots (the MapSync unreliable event): where every crowd
-- walker and every car is, five times a second. A lost snapshot is simply replaced by the next. Small
-- on purpose: 6 bytes of header and 6 bytes a body (about 280 bytes for 40 walkers and 4 cars), far
-- under the 900 an unreliable event carries.
--   header  u32 time (milliseconds since the map's ScrambleEpoch), u8 walkers, u8 cars
--   body    i16 x, i16 z (1/32 stud from the map's origin), u8 heading (1/256 turn), u8 flags
-- A walker's place in the list is its number for the whole match (clients keep one rig per number).

local MapSync = {}

MapSync.RATE = 5 -- snapshots a second
-- The models a car can be (ModelCatalog keys): a car's kind in a snapshot counts from 0 along this list.
MapSync.CARS = { "Taxi", "Car", "KeiTruck" }
MapSync.LIMIT = 900 -- bytes an unreliable event may carry
MapSync.MOST = 255 -- bodies of each kind

local HEADER = 6
local BODY = 6
local SCALE = 32

-- Walker flags.
MapSync.SHOWN = 1 -- in the world (off: between rounds, or a spare number)
MapSync.PASSING = 2 -- stepping through someone it could not get round: it collides with nobody
MapSync.STANDING = 4 -- at a post (a clerk behind a counter): it never walks
-- Car flags: SHOWN, then...
MapSync.BRAKING = 2
local KIND_SHIFT, KIND_MASK = 2, 3 -- which car model (0-3)
local HONK_SHIFT, HONK_MASK = 4, 3 -- counts the car's honks (mod 4): a change is a honk to play

export type Walker = { x: number, z: number, heading: number, shown: boolean, passing: boolean, standing: boolean }
export type Car = { x: number, z: number, heading: number, shown: boolean, braking: boolean, kind: number, honks: number }
export type Snapshot = { time: number, walkers: { Walker }, cars: { Car } }

local function i16(v: number): number
	return math.clamp(math.round(v * SCALE), -32768, 32767)
end

local function turn(heading: number): number
	return math.round((heading / (2 * math.pi)) % 1 * 256) % 256
end

local function flag(on: boolean?, bit: number): number
	return if on then bit else 0
end

local function writeBody(b: buffer, o: number, x: number, z: number, heading: number, flags: number)
	buffer.writei16(b, o, i16(x))
	buffer.writei16(b, o + 2, i16(z))
	buffer.writeu8(b, o + 4, turn(heading))
	buffer.writeu8(b, o + 5, flags)
end

-- time: seconds since the map's ScrambleEpoch.
function MapSync.encode(time: number, walkers: { Walker }, cars: { Car }): buffer
	local nWalkers, nCars = math.min(#walkers, MapSync.MOST), math.min(#cars, MapSync.MOST)
	local b = buffer.create(HEADER + (nWalkers + nCars) * BODY)
	buffer.writeu32(b, 0, math.clamp(math.round(time * 1000), 0, 4294967295))
	buffer.writeu8(b, 4, nWalkers)
	buffer.writeu8(b, 5, nCars)
	local o = HEADER
	for i = 1, nWalkers do
		local w = walkers[i]
		local flags = flag(w.shown, MapSync.SHOWN)
			+ flag(w.passing, MapSync.PASSING)
			+ flag(w.standing, MapSync.STANDING)
		writeBody(b, o, w.x, w.z, w.heading, flags)
		o += BODY
	end
	for i = 1, nCars do
		local c = cars[i]
		local flags = flag(c.shown, MapSync.SHOWN)
			+ flag(c.braking, MapSync.BRAKING)
			+ bit32.lshift(bit32.band(c.kind, KIND_MASK), KIND_SHIFT)
			+ bit32.lshift(bit32.band(c.honks, HONK_MASK), HONK_SHIFT)
		writeBody(b, o, c.x, c.z, c.heading, flags)
		o += BODY
	end
	return b
end

-- nil for anything that is not a whole snapshot.
function MapSync.decode(b: any): Snapshot?
	if typeof(b) ~= "buffer" or buffer.len(b) < HEADER then
		return nil
	end
	local nWalkers, nCars = buffer.readu8(b, 4), buffer.readu8(b, 5)
	if buffer.len(b) ~= HEADER + (nWalkers + nCars) * BODY then
		return nil
	end
	local snapshot: Snapshot =
		{ time = buffer.readu32(b, 0) / 1000, walkers = table.create(nWalkers), cars = table.create(nCars) }
	local o = HEADER
	for i = 1, nWalkers + nCars do
		local x, z = buffer.readi16(b, o) / SCALE, buffer.readi16(b, o + 2) / SCALE
		local heading = buffer.readu8(b, o + 4) / 256 * 2 * math.pi
		local flags = buffer.readu8(b, o + 5)
		local shown = bit32.band(flags, MapSync.SHOWN) ~= 0
		if i <= nWalkers then
			snapshot.walkers[i] = {
				x = x,
				z = z,
				heading = heading,
				shown = shown,
				passing = bit32.band(flags, MapSync.PASSING) ~= 0,
				standing = bit32.band(flags, MapSync.STANDING) ~= 0,
			}
		else
			snapshot.cars[i - nWalkers] = {
				x = x,
				z = z,
				heading = heading,
				shown = shown,
				braking = bit32.band(flags, MapSync.BRAKING) ~= 0,
				kind = bit32.band(bit32.rshift(flags, KIND_SHIFT), KIND_MASK),
				honks = bit32.band(bit32.rshift(flags, HONK_SHIFT), HONK_MASK),
			}
		end
		o += BODY
	end
	return snapshot
end

-- The shortest way round from one heading to another (radians, -pi to pi).
function MapSync.turnBetween(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

return MapSync
