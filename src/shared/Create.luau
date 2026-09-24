-- Builds an instance from a property table. Parent is applied last so the
-- instance is fully configured before it replicates or renders.

local function Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
