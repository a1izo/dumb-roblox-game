--!strict
-- The rune courtyard's rules: nine tiles in a 3 x 3 grid light up in a sequence; walk onto them in
-- the same order. The sequence starts at three and grows by one every round; one wrong tile ends the
-- run, and the score is the rounds you cleared. The server owns the sequence (a seed per run); the
-- client only lights the tiles it is told to. Pure rules, tested in LobbyGames.spec.

local Runes = {}

Runes.TILES = 9
Runes.START = 3
Runes.STEP = 0.75 -- seconds each rune stays lit while it is shown
Runes.GRACE = 0.9 -- seconds after the last rune before steps are accepted
Runes.INPUT_TIMEOUT = 14 -- seconds you get for each step
Runes.MAX_ROUNDS = 40
Runes.WANDER = 46 -- studs from the courtyard's middle where a run is given up

export type State = { seed: number, round: number, pos: number, seq: { number } }

-- The first `length` tiles of a run's sequence: the same prefix for the same seed however long
-- it grows, and never the same tile twice running (a step is entering a tile).
function Runes.sequence(seed: number, length: number): { number }
	local rng = Random.new(seed)
	local out = {}
	local last = 0
	for i = 1, length do
		local tile = rng:NextInteger(1, Runes.TILES - 1)
		if tile >= last and last > 0 then
			tile += 1
		end
		out[i] = tile
		last = tile
	end
	return out
end

function Runes.start(seed: number): State
	return { seed = seed, round = 1, pos = 0, seq = Runes.sequence(seed, Runes.START) }
end

-- One step onto a tile: "ok" (right, more to go), "round" (right, the sequence is done: the next
-- round, one longer, is now in the state) or "wrong".
function Runes.step(state: State, tile: number): string
	if state.seq[state.pos + 1] ~= tile then
		return "wrong"
	end
	state.pos += 1
	if state.pos < #state.seq then
		return "ok"
	end
	state.round += 1
	state.pos = 0
	state.seq = Runes.sequence(state.seed, Runes.START + state.round - 1)
	return "round"
end

-- Rounds cleared so far (the score).
function Runes.rounds(state: State): number
	return state.round - 1
end

function Runes.showTime(length: number): number
	return length * Runes.STEP + Runes.GRACE
end

-- Which tile (1 to 9, row by row from the north-west) a point stands on, given its offset from the
-- grid's middle (x east, z south), the tile size and the gap between tiles; nil off the tiles.
function Runes.tileAt(dx: number, dz: number, size: number, gap: number): number?
	local pitch = size + gap
	local function cell(v: number): number?
		local i = math.floor((v + pitch * 1.5) / pitch)
		if i < 0 or i > 2 then
			return nil
		end
		local centre = (i - 1) * pitch
		if math.abs(v - centre) > size / 2 then
			return nil
		end
		return i
	end
	local column, row = cell(dx), cell(dz)
	if not column or not row then
		return nil
	end
	return row * 3 + column + 1
end

return Runes
