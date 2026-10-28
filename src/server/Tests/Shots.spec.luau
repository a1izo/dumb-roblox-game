-- The cutscenes made in Blender (Shared/Cinema/Shots): every sound one asks for has its slot in Shared/Assets (five
-- map intro sounds were asked for and missing, 2026-10-27), the voiced role cutscenes say their lines with a few seconds
-- of their scene round them (about 4 s more than the line and a beat, 2026-10-27), and a voiced clip longer than its line
-- stretches its cutscene to fit (Shared/Cinema/CutLength).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local CutLength = require(Shared:WaitForChild("Cinema"):WaitForChild("CutLength"))

local function shots(): { [string]: any }
	local out = {}
	for _, module in ipairs(Shared:WaitForChild("Cinema"):WaitForChild("Shots"):GetChildren()) do
		if module:IsA("ModuleScript") then
			out[module.Name] = require(module) :: any
		end
	end
	return out
end

local VOICED = { RoleDiavolo = true, RoleMuerto = true, RoleButler = true, RoleAce = true }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Shots", function()
		it("asks only for sounds that have a slot", function()
			for name, shot in pairs(shots()) do
				for _, event in ipairs(shot.events or {}) do
					if event.kind == "sfx" then
						if Assets.sfx[event.slot] == nil then
							error(name .. " asks for the missing sound slot " .. tostring(event.slot))
						end
					end
				end
				local sound = shot.sound
				if type(sound) == "table" then
					expect(sound.voice == nil or Assets.sfx[sound.voice] ~= nil).to.equal(true)
					expect(sound.bed == nil or Assets.music[sound.bed] ~= nil).to.equal(true)
					expect(sound.music == nil or Assets.music[sound.music] ~= nil).to.equal(true)
				end
			end
		end)

		it("gives each voiced role cutscene its line, with some of its scene before and after", function()
			local all = shots()
			for name in pairs(VOICED) do
				local shot = all[name]
				expect(shot ~= nil).to.equal(true)
				expect(type(shot.sound) == "table" and type(shot.sound.voice) == "string").to.equal(true)
				local finish = CutLength.lineEnd(shot)
				expect(finish ~= nil).to.equal(true)
				-- the line starts after a lead-in of the scene's own acting (up to about 6 s), and the shot plays on after
				-- it to its own ending (up to 7 s: the owner, 2026-10-28, let Diavolo's and the Muerto's play out)
				expect(shot.sound.voiceAt >= 0.8 and shot.sound.voiceAt <= 6.5).to.equal(true)
				expect(shot.length >= (finish :: number) and shot.length - (finish :: number) <= 7).to.equal(true)
				for _, event in ipairs(shot.events) do
					expect(event.kind ~= "subtitle" and event.kind ~= "card").to.equal(true)
				end
			end
			-- the Operative's scene (19 s since 2026-10-27) keeps its role card captions, under its own music
			expect(all.RoleOperative.length).to.equal(19)
			expect(all.RoleOperative.sound.music).to.equal("musicOperative")
		end)

		it("stretches a voiced cutscene to a longer clip, never shortens it", function()
			local shot = {
				length = 6,
				sound = { voice = "voiceDiavolo", voiceAt = 1 },
				events = { { t = 1, kind = "line", words = { { "a", 0 }, { "b", 3.5 } } } },
			}
			-- the line runs 1 .. 5 (its last word and half a second)
			expect(CutLength.lineEnd(shot)).to.equal(5)
			expect(CutLength.of(shot, nil)).to.equal(6)
			expect(CutLength.of(shot, 3)).to.equal(6)
			expect(math.abs(CutLength.of(shot, 8) - 12) < 1e-6).to.equal(true)
			expect(CutLength.of({ length = 15 }, 30)).to.equal(15)
		end)
	end)
end
