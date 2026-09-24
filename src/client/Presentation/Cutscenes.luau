-- Wires every presenter to its cue kind.

local CueRouter = require(script.Parent.CueRouter)
local Presenters = script.Parent.Presenters

local Cutscenes = {}

local KINDS = {
	intro = "Intro",
	death = "Death",
	verdict = "Verdict",
	arrest = "Arrest",
	eyesDeal = "EyesDeal",
	outro = "Outro",
}

function Cutscenes.init()
	for kind, moduleName in pairs(KINDS) do
		CueRouter.register(kind, require(Presenters:WaitForChild(moduleName)) :: any)
	end
	CueRouter.init()
end

return Cutscenes
