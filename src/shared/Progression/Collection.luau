--!strict
-- Collection milestones: owning so many emotes (any emote item, however it came: bought, earned, or with
-- the Emote Pack) pays coins once and gives a title (a title item whose source is "collection").
-- CosmeticsService.grantMilestones hands them out after a purchase, on arriving and on respawning.

local Cosmetics = require(script.Parent.Parent.Cosmetics)

local Collection = {}

export type Milestone = { count: number, coins: number, title: string }

Collection.MILESTONES = {
	{ count = 10, coins = 100, title = "title_c_mover" },
	{ count = 25, coins = 250, title = "title_c_showstopper" },
	{ count = 50, coins = 750, title = "title_c_living_legend" },
} :: { Milestone }

-- How many emote items `owns` says are owned.
function Collection.count(owns: (Cosmetics.Item) -> boolean): number
	local count = 0
	for _, item in ipairs(Cosmetics.ofKind("emote")) do
		if owns(item) then
			count += 1
		end
	end
	return count
end

-- The milestones reached whose title is not owned yet, lowest first.
function Collection.due(count: number, ownsTitle: (string) -> boolean): { Milestone }
	local list = {}
	for _, milestone in ipairs(Collection.MILESTONES) do
		if count >= milestone.count and not ownsTitle(milestone.title) then
			table.insert(list, milestone)
		end
	end
	return list
end

-- The next milestone above `count`, or nil past the last.
function Collection.nextAfter(count: number): Milestone?
	for _, milestone in ipairs(Collection.MILESTONES) do
		if count < milestone.count then
			return milestone
		end
	end
	return nil
end

-- The milestone a title belongs to, or nil.
function Collection.ofTitle(titleId: string): Milestone?
	for _, milestone in ipairs(Collection.MILESTONES) do
		if milestone.title == titleId then
			return milestone
		end
	end
	return nil
end

-- Every milestone's title exists and is a collection title, the counts rise and fit the catalog.
function Collection.valid(): boolean
	local last = 0
	for _, milestone in ipairs(Collection.MILESTONES) do
		local title = Cosmetics.byId(milestone.title)
		if not title or title.kind ~= "title" or title.source ~= "collection" then
			return false
		end
		if milestone.count <= last or milestone.count > #Cosmetics.ofKind("emote") or milestone.coins <= 0 then
			return false
		end
		last = milestone.count
	end
	return true
end

return Collection
