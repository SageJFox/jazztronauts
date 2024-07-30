module( "snatch", package.seeall )

local propdatastr = [[
	steamid BIGINT NOT NULL,
	propname VARCHAR(128) NOT NULL,
	type VARCHAR(16) NOT NULL,
	total INT UNSIGNED NOT NULL DEFAULT 1,
	recent INT UNSIGNED NOT NULL DEFAULT 1,
	worth INT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY(steamid, propname, type, worth)
]]

-- Per-player prop stealing data
jsql.Register("jazz_propdata", propdatastr)

local Query = jsql.Query

--[[
	The previous version of the table had a fatal flaw
	Its worth wasn't part of its primary key, so two of the same thing couldn't be worth different amounts when snatched
	It mitigated this issue by storing the map name with it (with it being part of the primary key)
	It worked for most things, but failed to factor for two scenarios:
		-things being dynamically spawned vs mapper placed have different values (not typically a huge issue, would mostly be NPCs/item pickups)
		-brushes (kind of a massive problem, the first brush of a certain material set the price for every one after it)
	(I mean, it also made the roadtrip multiplier not work too but that didn't exist when this was made so not blaming anyone there)

	Unfortunately if we don't manually go in and fix the old tables, it'll be broken in an even worse way for old games until the server hits a NG+ reset
]]
local function FixOld()
	local testold = sql.Query("SELECT * FROM jazz_propdata WHERE mapname IS NOT NULL")

	--old setup detected
	if type(testold) == "table" and #testold > 0 then

		--get it outta here
		Query(string.format("DROP TABLE jazz_propdata; CREATE TABLE jazz_propdata (%s)",propdatastr))

		--copy the old info into the new version of the table
		for i=1, #testold do
			
			local insert = "INSERT OR IGNORE INTO jazz_propdata (steamid, propname, type, total, recent, worth) "
				.. string.format("VALUES ('%s', '%s', '%s', '%s', '%s', '%s')", testold[i].steamid, testold[i].propname, testold[i].type, testold[i].total, testold[i].recent, testold[i].worth)
			
			local altr = "UPDATE jazz_propdata SET "
				.. string.format("total = total + %s, ", testold[i].total)
				.. string.format("recent = recent + %s ", testold[i].recent)
				.. string.format("WHERE propname='%s' AND ", testold[i].propname)
				.. string.format("steamid='%s' AND ", testold[i].steamid)
				.. string.format("type='%s' AND ", testold[i].type)
				.. string.format("worth='%s'", testold[i].worth)

			-- Try an update, then an insert
			if Query(altr) == false then return nil end
			if Query(insert) == false then return nil end
		end
	end
end

--do you have a better idea?
FixOld()


-- Get the collected count of a specific model
function GetPropCount(model)
	local altr = "SELECT SUM(total), SUM(recent) FROM jazz_propdata "
		.. string.format("WHERE propname='%s'", model)

	local res = Query(altr)
	if type(res) == "table" then
		return tonumber(res[1].total), tonumber(res[1].recent)
	end

	return 0, 0
end

-- Get the collected count of all props
function GetPropCounts()
	local altr = "SELECT * FROM jazz_propdata"

	local res = Query(altr)

	if type(res) == "table" then
		for i=1, #res do
			-- Convert to number
			res[i].total = tonumber(res[i].total)
			res[i].recent = tonumber(res[i].recent)
			res[i].worth = tonumber(res[i].worth)

			-- Allow key lookup
			--res[res[i].propname] = res[i]
			--res[i] = nil
		end
		return res
	end

	return {}
end

-- Get the collected count of all props collected by a specific player
function GetPlayerPropCounts(ply, recentonly)
	if not IsValid(ply) then return {} end
	local id = ply:SteamID64() or "0"
	local altr = "SELECT * FROM jazz_propdata "
		.. string.format("WHERE steamid='%s'", id)

	-- Only include entries with nonzero recents
	if recentonly then
		altr = altr .. string.format(" AND recent > 0")
	end

	local res = Query(altr)

	if type(res) == "table" then
		for i=1, #res do
			-- Convert to number
			res[i].total = tonumber(res[i].total)
			res[i].recent = tonumber(res[i].recent)
			res[i].worth = tonumber(res[i].worth)

			-- Allow key lookup
			--res[res[i].propname] = res[i]
			--res[i] = nil
		end
		return res
	end

	return {}
end

-- Increment the global count of a specific prop
function AddProp(ply, model, worth, type)
	if not model or #model == 0 or not IsValid(ply) then return nil end
	local id = ply:SteamID64() or "0"
	type = type or "prop"

	local altr = "UPDATE jazz_propdata SET total = total + 1, "
		.. "recent = recent + 1 "
		.. string.format("WHERE propname='%s' AND ", model)
		.. string.format("steamid='%s' AND ", id)
		.. string.format("type='%s' AND ", type)
		.. string.format("worth='%d'", worth)
	local insert = "INSERT OR IGNORE INTO jazz_propdata (steamid, propname, type, worth) "
		.. string.format("VALUES ('%s', '%s', '%s', '%d')", id, model, type, worth)

	-- Try an update, then an insert
	if Query(altr) == false then return nil end
	if Query(insert) == false then return nil end

	return GetPropCount(model)
end

-- Reset the recently collected prop counts
-- Usually happens when they pulled the trash chute
function ClearRecentProps()
	local altr = "UPDATE jazz_propdata SET recent = 0"
	return Query(altr) != false
end

function ClearPlayerRecentProps(ply)
	if not IsValid(ply) then return nil end

	local id = ply:SteamID64() or "0"
	local altr = "UPDATE jazz_propdata SET recent = 0 "
		.. string.format("WHERE steamid='%s'", id)
	return Query(altr) != false
end
