module( 'mapgen', package.seeall )

SpawnedShards = SpawnedShards or {}
InitialShardCount = InitialShardCount or 0

local shardsNeededConVar = CreateConVar("jazz_total_shards", 100, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The total number of shards needed to finish the game. Cannot be changed in-game.")
local blackShardsNeededConVar = CreateConVar("jazz_total_black_shards", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "The total number of shards needed to finish the game. Cannot be changed in-game.")

local shardTblName = "jazznetplyshards"
local propTblName = "jazznetplyprops"

if SERVER then
	nettable.Create(shardTblName, nettable.TRANSMIT_AUTO, 1.0)
	nettable.Create(propTblName, nettable.TRANSMIT_AUTO, 1.0)
end

-- No two shards can ever be closer than this
local MinShardDist = 500

function GetShardCount()
	return table.Count(SpawnedShards), InitialShardCount
end

function GetTotalCollectedShards()
	return (nettable.Get("jazz_shard_info") or {})["collected"] or 0
end

function GetTotalRequiredShards()
	return shardsNeededConVar:GetInt()
end

function GetTotalGeneratedShards()
	return (nettable.Get("jazz_shard_info") or {})["total"] or 0
end

function GetTotalCollectedBlackShards()
	return nettable.Get("jazz_shard_info")["corrupted_collected"] or 0
end

function GetTotalRequiredBlackShards()
	return blackShardsNeededConVar:GetInt()
end

function GetPlayerShards()
	return nettable.Get(shardTblName)
end

function GetPlayerProps()
	return nettable.Get(propTblName)
end

function GetShards()
	return SpawnedShards
end

local AcceptEntClass = {
	["npc_antlion_grub"] = true,
	["npc_grenade_frag"] = true,
	["prop_combine_ball"] = true,
	["jazz_static_proxy"] = true,
	["physics_cannister"] = true,
	["hunter_flechette"] = true,
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true,
	["prop_physics_respawnable"] = true,
	["prop_dynamic"] = true,
	["prop_dynamic_override"] = true,
	["prop_ragdoll"] = true,
	["prop_door_rotating"] = true,
	--let's get esoteric wee
	["gmod_tool"] = true,
	["gmod_camera"] = true,
	["simple_physics_prop"] = true, --created by phys_convert
	["raggib"] = true, --?
	["helicopter_chunk"] = true,
	["grenade_helicopter"] = true,
	["gib"] = true,
	["rpg_missile"] = true,
	["apc_missile"] = true,
	["npc_grenade_bugbait"] = true,
	["phys_magnet"] = true,
	["prop_ragdoll_attached"] = true,
	["gmod_wire_hoverdrivecontroler"] = true,
	["weapon_striderbuster"] = true,
	["npc_satchel"] = true, --SLAM
	["npc_tripmine"] = true, --SLAM
	["grenade_ar2"] = true,
	["combine_mine"] = true,
	["env_headcrabcanister"] = true,
	["prop_thumper"] = true,
	["env_flare"] = true,
	--let's live dangerously
	--a lot of this stuff could be core map structure, if it's at all possible at some point we should make these snatchable but leave them in place
	--(for the dynamic stuff probably replace their textures with void or something else, static stuff could be normal void shells)
	--also note that all of this is gonna wind up being brush models, which are... gross to handle right now.
	["func_button"] = true,
	["func_button_rot"] = true,
	["func_door"] = true,
	["func_door_rotating"] = true,
	["func_water_analog"] = true,
	["func_movelinear"] = true,
	["func_lod"] = true, --todo: if anything should get the staticprop treatment, it'd be this
	["func_brush"] = true,
	["func_wall"] = true,
	["func_wall_toggle"] = true,
	["func_illusionary"] = true,
	["func_breakable"] = true,
	["func_breakable_surf"] = true,
	["func_physbox"] = true,
	["func_physbox_multiplayer"] = true,
	["func_tank"] = true,
	["func_tanktrain"] = true,
	["func_tracktrain"] = true,
	["func_plat"] = true,
	["func_platrot"] = true,
	["func_monitor"] = true,
	--even scarier
	["trigger_once"] = true,
	["trigger_multiple"] = true,
	["trigger_look"] = true,
	["trigger_hurt"] = true,
	["infodecal"] = true,
	["info_overlay"] = true,
	["env_sprite"] = true,
	["env_glow"] = true,
	["env_sun"] = true,
	["env_fire"] = true,
	["point_spotlight"] = true,
	--["npc_spotlight"] = true, --might not exist?
	["env_beam"] = true,
	["env_laser"] = true,
	["env_spark"] = true,
	--[[ --todo: eventually
	["env_lightglow"] = true,
	["env_smokestack"] = true,
	["keyframe_track"] = true,
	["light"] = true,]]
	["prop_detail"] = true,
	["prop_detail_sprite"] = true,
}

local IgnoreEntClass = {
	["weapon_propsnatcher"] = true
}

function CanSnatch(ent)

	--Accept only this kinda stuff
	if not IsValid(ent) or not ent:IsValid() then return false end

	local ent_class = ent:GetClass()

	-- Always return false for these class types.
	if IgnoreEntClass[ent_class] then return false end

	-- Assume this flag on this flag becomes a thing
	if ent.IgnoreForSnatch then return false end

	-- Weapons held by players
	if ent:IsWeapon() and IsValid(ent:GetParent()) and ent:GetParent():IsPlayer() then return false end

	-- Local player weapons
	if CLIENT and ent:IsWeapon() and ent:IsCarriedByLocalPlayer() then return false end

	-- Everything that's parented to the bus itself.
	if IsValid(ent:GetParent()) and string.find(ent:GetParent():GetClass(), "jazz_bus") then return false end

	-- Vote podium
	if ent_class == "prop_dynamic" and IsValid(ent:GetParent()) and ent:GetParent():GetClass() == "jazz_shard_podium" then return false end

	-- Good bye Dr. Kleiner...
	if ent:IsNPC() then return true end

	-- Certain specific class names to be checked.
	if string.find(ent_class, "weapon_") ~= nil then return true end
	if string.find(ent_class, "prop_vehicle") ~= nil then return true end
	if string.find(ent_class, "item_") ~= nil then return true end
	if string.find(ent_class, "ammo_") ~= nil then return true end

	--Weapons not using "weapon_" in their name
	if ent:IsWeapon() then return true end

	-- ???
	-- if string.find(ent_class, "jazz_bus_") ~= nil then return true end
	-- if ent:IsPlayer() and ent:Alive() then return true end -- you lost your privileges

	return AcceptEntClass[ent_class]

end

if SERVER then
	util.AddNetworkString("jazz_shardcollect")
	local function updatePlayerCollectedShards()
		local mapfilter = not mapcontrol.IsInGamemodeMap() and game.GetMap() or nil
		local allShards = progress.GetMapShards(mapfilter)
		local shardPlyTable = {}
		for _, v in pairs(allShards) do
			if tobool(v.collected) and v.collect_player then
				shardPlyTable[v.collect_player] = shardPlyTable[v.collect_player] or 0
				shardPlyTable[v.collect_player] = shardPlyTable[v.collect_player] + 1
			end
		end
		PrintTable(shardPlyTable)
		nettable.Set(shardTblName, shardPlyTable)
	end

	function CollectShard(ply, shardent)

		-- It's gotta be one of our shards ;)
		local res = table.RemoveByValue(SpawnedShards, shardent, ply)
		if not res then return nil, nil end

		progress.CollectShard(game.GetMap(), shardent.ShardID, ply)
		UpdateShardCount()

		return #SpawnedShards, InitialShardCount
	end

	function CollectProp(ply, ent)
		if !CanSnatch(ent) then return nil end

		local worth = ent.JazzWorth or 1
		return worth
	end

	function CollectBlackShard(ent)
		local mapinfo = progress.GetMap(game.GetMap())
		if not mapinfo or mapinfo.corrupt == progress.CORRUPT_NONE then return false end

		progress.SetCorrupted(game.GetMap(), progress.CORRUPT_STOLEN)
		return true
	end

	function UpdateShardCount(ply)
		updatePlayerCollectedShards()

		net.Start("jazz_shardcollect")
			net.WriteUInt(#SpawnedShards, 16)
			for _, v in pairs(SpawnedShards) do
				net.WriteEntity(v)
			end

			net.WriteUInt(InitialShardCount, 16)
		if IsValid(ply) then net.Send(ply) else net.Broadcast() end
	end

	local function checkAreaTrace(pos, ang)
		local mask = bit.bor(MASK_SOLID, CONTENTS_PLAYERCLIP, CONTENTS_SOLID, CONTENTS_GRATE)
		local traces = {}
		local tdist = 1000000
		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Up() * tdist,
			mask = mask
		}))

		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Up() * -tdist,
			mask = mask
		}))

		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Right() * tdist,
			mask = mask
		}))

		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Right() * -tdist,
			mask = mask
		}))

		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Forward() * tdist,
			mask = mask
		}))

		table.insert(traces, util.TraceLine( {
			start = pos,
			endpos = pos + ang:Forward() * -tdist,
			mask = mask
		}))

		local num = 0
		for _, v in pairs(traces) do num = num + (v.HitSky and 1 or 0) end

		-- If more than 3 cardinal directions are skybox
		-- this might be some utility entity the player can't reach
		if num >= 3 then return false end

		-- Ensure there's enough space for a player to grab this from different sides
		local minBounds = 32
		local areaUp = (traces[1].Fraction + traces[2].Fraction) * tdist
		local areaFwd = (traces[3].Fraction + traces[4].Fraction) * tdist
		local areaRight = (traces[5].Fraction + traces[6].Fraction) * tdist
		if (areaUp < minBounds or areaFwd < minBounds or areaRight < minBounds) then return false end

		return true
	end

	-- Return true if the value has any matching flags
	local function maskAny(val, ...)
		local args = {...}
		for k, v in pairs(args) do
			if bit.band(val, v) == v then return true end
		end

		return false
	end

	-- Return true if the entity will spawn within a trigger teleport
	-- This usually makes it impossible to get to
	local function isWithinTrigger(ent)
		local pos = ent:GetPos()
		local tps = ents.FindByClass("trigger_teleport*")
		for _, v in pairs(tps) do
			local min = v:LocalToWorld(v:OBBMins())
			local max = v:LocalToWorld(v:OBBMaxs())

			if pos:WithinAABox(min, max) then
				return true
			end
		end

		return false
	end

	local spawnpoints = {
		"info_player_start",
		"gmod_player_start",
		--HL2:DM
		"info_player_deathmatch",
		"info_player_rebel",
		"info_player_combine",
		--CS:S
		"info_player_counterterrorist",
		"info_player_terrorist",
		--DoD:S
		"info_player_axis",
		"info_player_allies",
		--TF2
		"info_player_teamspawn",
		--Portal 2
		"info_coop_spawn",
		--misc.
		"ins_spawnpoint",
		"aoc_spawnpoint",
		"dys_spawn_point",
		"info_player_pirate",
		"info_player_viking",
		"info_player_knight",
		"diprip_start_team_blue",
		"diprip_start_team_red",
		"info_player_red",
		"info_player_blue",
		"info_player_coop",
		"info_player_human",
		"info_player_zombie",
		"info_player_zombiemaster",
		--L4D/2
		"info_survivor_position",
		"info_survivor_rescue",
		--Black Mesa
		--"info_player_scientist",
		--"info_player_marine",
	}

	-- Entities that facilitate transporting players
	local teleports = {
		["trigger_teleport"] = "target",
		["jazz_door"] = "TeleportName",
		["theater_door"] = "TeleportName",

		-- some maps use these for cutscenes, let them override?
		["point_teleport"] = "", -- itself is the point
		["info_target"] = "", -- itself is the point, also names matter (see below)
	}

	local infotarget_names = {
		"spawn_loot", --TF2 Monoculus dies
		"spawn_loot_winner", --TF2 Hell winning Team
		"spawn_loot_loser", --TF2 Hell losing Team
		"spawn_purgatory", --TF2 Monoculus teleports
		"spawn_warcrimes", --TF2 Hell end of round losers
	}

	local initialStanDestSpawned = false

	local function CreateMarker(ent,level,defaultName)
		local level = level or 1
		local defaultName = defaultName or ""
		local stanmark = ents.Create("jazz_stanteleportmarker")
		if not (IsValid(ent) and IsValid(stanmark)) then return end
		stanmark:SetPos(ent:GetPos())
		stanmark:Spawn()
		stanmark:SetDestination(ent)
		stanmark:SetDestinationName(ent:GetName() ~= "" and ent:GetName() or defaultName)
		stanmark:SetLevel(level)
		stanmark:SetBusMarker(false)
		if ent:GetClass() == "point_teleport" then
			local ducked = tobool(bit.band(ent:GetFlags(),2)) -- Into Duck (episodic)
			--print("Ducked?",ducked)
			stanmark:SetDucked(ducked)
		else
			stanmark:SetDucked(false)
		end
		return stanmark
	end

	local function getPotentialPlayerPositions()
		local positions = {}

		-- Spawnpoints
		for _, pt in ipairs(spawnpoints) do
			for _, v in ipairs(ents.FindByClass(pt)) do
				if not IsValid(v) then continue end
				positions[#positions + 1] = v:GetPos()
				if not initialStanDestSpawned then CreateMarker(v,2,"spawn") end --using community localization tokens
			end
		end

		for _, v in ipairs(ents.FindByClass("sky_camera")) do
			if not initialStanDestSpawned then CreateMarker(v,2,"skybox") end --using community localization tokens
		end


		-- Teleports
		for name, dest in pairs(teleports) do
			local dests = {}
			local destscount = 1
			for _, ent in pairs(ents.FindByClass(name)) do

				local really = true
				if name == "info_target" then
					really = false
					for _, s in ipairs(infotarget_names) do
						if ent:GetName() == s then
							really = true
							break
						end
					end
				end
				if not really then continue end

				-- No destination keyvalue, so itself is the destination
				if #dest == 0 then
					positions[#positions + 1] = ent:GetPos()
					dests[ent] = destscount
				else
					local destName = ent:GetKeyValues()[dest] or ent[dest]
					if not destName or #destName == 0 then continue end

					-- Add in all destination ents with matching name
					for _, v in pairs(ents.FindByName(destName)) do
						positions[#positions + 1] = v:GetPos()
						dests[v] = destscount
					end
				end
				destscount = destscount + 1
			end
			--create stan markers
			if not initialStanDestSpawned then --don't rerun this if we've already done it
				dests = table.Flip(dests) --initially built table with values as keys to eliminate potential duplicate entries (if multiple teleporters go to the same destination)
				for _, v in pairs(dests) do
					if not IsValid(v) then continue end
					CreateMarker(v)
				end
				initialStanDestSpawned = true
			end
		end

		return positions
	end

	local destinations = {
		"point_teleport",
		"info_teleport_destination",
		"info_target",
		--leave these last, with spawns added after!
		"point_camera",
		"sky_camera"
	}

	local level2destnum = #destinations - 1

	table.Add(destinations,spawnpoints)

	--handle teleporters that don't exist when map spawns
	hook.Add("OnEntityCreated", "JazzStanTeleportMarkers", function(ent)
		timer.Simple(1,function() --wait a bit so it can initialize

			if not IsValid(ent) then return end
			--gonna be making a lot of these, no sense going over them for themselves
			if ent:GetClass() == "jazz_stanteleportmarker" then return end

			for k, v in ipairs(destinations) do

				if ent:GetClass() == v then

					local really = true
					if ent:GetClass() == "info_target" then
						really = false
						for _, s in ipairs(infotarget_names) do
							if ent:GetName() == s then
								really = true
								break
							end
						end
					end

					if not really then continue end
					--make sure we don't have a marker already
					for _, s in ipairs(ents.FindByClass("jazz_stanteleportmarker")) do
						if s:GetDestination() == ent then return end
					end
					
					local level = k >= level2destnum and 2 or 1
					local name = k >= level2destnum and (k > level2destnum and "spawn" or "skybox") or ""
					CreateMarker(ent,level,name)
					return

				end
			end

		end)
	end)

	local function getPositionLeafs(map)
		local positions = getPotentialPlayerPositions()
		local leaves = {}

		for _, v in pairs(positions) do
			local leaf = map:GetLeaf( v )
			if not leaf or leaves[leaf] then continue end
			leaves[leaf] = true
		end

		return table.GetKeys(leaves)
	end

	-- Check if this shard is actually reachable by the player at all
	-- There must be some sort of connecting leaf between the player and shard
	local function isPlayerReachable(ent, map, leafs)
		local function checkLeaf(l)
			return bit.band(l.contents, CONTENTS_SOLID + CONTENTS_GRATE + CONTENTS_WINDOW + CONTENTS_DETAIL + CONTENTS_PLAYERCLIP) == 0
		end

		local shard_leaf = map:GetLeaf( ent:GetPos() )
		for _, v in pairs(leafs) do
			if map:AreLeafsConnected(shard_leaf, v, checkLeaf) then
				return true
			end
		end

		return false
	end

	local function findValidSpawn(ent, map, leafs)
		local pos = ent:GetPos()

		--the map origin is a stinky spot, don't do it
		--todo: This is a bit of a bandage fix, figure out why it likes to grab every brush model when it's here and stop it from doing that, instead
		--(especially since the black shard take everything does these too)
		if pos:Distance(vector_origin) < 16 then return end 

		pos:Add( Vector(0, 0, 16) )

		-- If moving the entity that small amount up puts it out of the world -- nah
		if not util.IsInWorld(pos) then return end

		-- If the point is inside something solid -- also nah
		if maskAny(util.PointContents(pos), CONTENTS_PLAYERCLIP, CONTENTS_SOLID, CONTENTS_GRATE) then return end

		-- Don't spawn inside a trigger_teleport either
		if isWithinTrigger(ent) then return end

		-- Check if they're near a suspicious amount of sky
		if not checkAreaTrace(pos, ent:GetAngles()) then return end

		-- Goal spot must be reachable from the players
		-- disabled for now, seems to a little fucky on certain maps but it does work 99% of the time
		--if not isPlayerReachable(ent, map, leafs) then return end

		return { pos = pos, ang = ent:GetAngles() }
	end

	local function isInSkyBox(ent)
		if ent:GetClass() == "sky_camera" then return true end

		local skycam = ents.FindByClass("sky_camera")
		if #skycam == 0 then return false end -- Map has no skybox

		return skycam[1]:TestPVS(ent)
	end

	local function spawnShard(transform, id)
		if transform == nil then return nil end

		local shard = ents.Create( "jazz_shard" )
		if IsValid(shard) then
			shard:SetPos(transform.pos)
			shard:SetAngles(transform.ang)

			shard.ShardID = id
			shard:Spawn()
			shard:Activate()
		end

		return shard
	end

	-- Calculate the size of this map and how many shards it's worth
	function CalculateShardCount()
		local curmap = bsp2.GetCurrent()
		if not curmap then return 8 end -- ??

		local winfo = curmap.entities and curmap.entities[1]
		if not winfo then return 8 end

		local maxs, mins = Vector(winfo.world_maxs), Vector(winfo.world_mins)

		-- Calculate only length across the area, ignoring Z because people make bigass fucking skyboxes
		local length = math.sqrt(math.pow(maxs.x - mins.x,2) + math.pow(maxs.y - mins.y,2))
		print(length)
		-- Shard count dependent on map size
		local shardcount = math.Remap(length, 8000, 100000, 4, 24)
		return math.ceil(shardcount)
	end

	function CalculatePropValues(mapWorth)
		local props = ents.GetAll()
		local counts = {}
		local function getKey(ent) return ent:GetClass() .. "_" .. (ent:GetModel() or "") end

		for _, v in pairs(props) do
			if not CanSnatch(v) then continue end

			local k = getKey(v)
			counts[k] = counts[k] or 0
			counts[k] = counts[k] + 1
		end

		--PrintTable(counts)

		for _, v in pairs(props) do
			local count = counts[getKey(v)]
			if not count then continue end

			local worth = (mapWorth / table.Count(counts)) / count
			v.JazzWorth = math.max(1, worth)
		end

	end

	function GetSpawnPoint(ent, map, leafs)
		if !IsValid(ent) or !ent:CreatedByMap() then return nil end
		if isInSkyBox(ent) then return nil end -- god wouldn't that suck

		return findValidSpawn(ent, map, leafs)
	end


	local hullMin = Vector(-20, -20, 0)
	local hullMax = Vector(20, 20, 50)


	-- Just do a shitload of traces in an attempt to find a plausible center to the room
	local function tryBlackShard(pos)

		-- Dumb drop to floor check
		local trDrop = util.TraceHull({
			start = pos,
			endpos = pos + Vector(0, 0, -1) * 1000000,
			mins = hullMin,
			maxs = hullMax
		})

		-- Check height?

		if trDrop.StartSolid then return nil end
		if trDrop.HitNonWorld then return nil end

		return trDrop.HitPos
	end

	-- Depending on the map, there might be certain entities that automatically
	-- Make for great shard spawn locations. These will take preference over
	-- the default shard generation algorithm
	function GetPreferredSpawns(seed)
		local prefix = string.Split(game.GetMap(), "_")[1]
		return hook.Call("JazzGetShardSpawnOverrides", GAMEMODE, prefix, seed)
	end

	local function minDistance2(posang, postbl)
		local mindist = math.huge
		for _, v in pairs(postbl) do
			if v == posang then continue end
			mindist = math.min(mindist, (posang.pos - v.pos):LengthSqr())
		end

		return mindist
	end

	local function sharditer(seed, preferredSpawns)
		local validSpawns = {}
		preferredSpawns = preferredSpawns or {}
		local entIter = nil
		local c = 0

		-- Set up generator seed + ent random pairs iter
		math.randomseed(seed)
		entIter, entState = RandomPairs(ents.GetAll())
		prefIter, prefState = RandomPairs(preferredSpawns)

		-- Build a list of possible bsp leaves the player might start in
		local map = bsp2.GetCurrent()
		local leafs = getPositionLeafs(map)

		return function()
			local posang = nil

			-- Try spawning a 'preferred' shard first
			local _, pref = prefIter(prefState)
			if pref then
				c = c + 1
				posang = pref
			end

			-- For normal shards, go randomly through map ents to find random spawns
			-- Not all entities have a valid spawn, so go until we find one (or run out)
			while not posang do

				-- Grab a random entity
				local _, ent = entIter(entState)
				if not ent then break end
				if not IsValid(ent) then continue end

				-- Find it's corresponding spawn point
				local newposang = GetSpawnPoint(ent, map, leafs)
				if not newposang then continue end

				-- Ensure it's not next to a previously spawned shard
				local mindist2 = MinShardDist^2
				if minDistance2(newposang, preferredSpawns) > mindist2 and
				   minDistance2(newposang, validSpawns) > mindist2
				then
					posang = newposang
					c = c + 1
					break
				end
			end

			-- Store as valid spawn
			table.insert(validSpawns, posang)

			-- Give them the next-found shard position
			if posang then return c, posang end
		end
	end

	-- Spawn black shards. Maybe. If no good places, or if it isn't feeling good today, will not make anything
	function GenerateBlackShard(seed)
		seed = seed or math.random(1, 1000)
		math.randomseed(seed)

		-- Try to find a good spot
		for count, posang in sharditer(seed + 1231, preferredSpawns) do
			local pos = tryBlackShard(posang.pos)
			if pos then
				local shard = ents.Create("jazz_shard_black")
				shard:SetPos(pos)
				shard:Spawn()
				shard:Activate()

				return true
			end
		end

		return false
	end

	function GenerateShards(count, seed, shardtbl)
		for _, v in pairs(SpawnedShards) do
			if IsValid(v) then v:Remove() end
		end
		seed = seed or math.random(1, 1000)
		math.randomseed(seed)
		SpawnedShards = {}

		-- Get preferred spawns, if there are any
		local preferredSpawns = GetPreferredSpawns(seed) or {}

		-- Select count random spawns and go
		local n = 0
		local function registerShard(posang)
			count = count - 1
			if count < 0 then return false end
			n = n + 1

			-- Create a new shard only if it hasn't been collected
			local shard = nil
			if not shardtbl or not tobool(shardtbl[n].collected) then
				shard = spawnShard(posang, n)
			end

			table.insert(SpawnedShards, shard)
			return true
		end

		for count, posang in sharditer(seed, preferredSpawns) do
			print(count, posang)
			if not registerShard(posang) then break end
		end

		InitialShardCount = n
		UpdateShardCount()

		print("Generated " .. InitialShardCount .. " shards. Happy hunting!")
		return InitialShardCount
	end

	function LoadHubProps()
		local hubdata = progress.LoadHubPropData()
		for _, v in pairs(hubdata) do
			mapgen.SpawnHubProp(v.model, v.transform.pos, v.transform.ang, v.toy == "1")
		end
	end

	function SaveHubProps()
		local props = {}
		for _, v in pairs(ents.GetAll()) do
			if v.JazzHubSpawned then table.insert(props, v) end
		end

		progress.SaveHubPropData(props)
	end

	function SpawnHubProp(model, pos, ang, inSphere)
		local etype = inSphere and "jazz_prop_sphere" or "prop_physics"
		local ent = ents.Create(etype)
		ent:SetModel(model)
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:Spawn()
		ent:Activate()
		ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ent.JazzHubSpawned = true

		return ent
	end

	hook.Add("PlayerSpawn", "JazzPreventSpawnBlockers", function(ply,trans)
		ply.JazzSpawnTime = CurTime()
	end )

	hook.Add("PlayerShouldTakeDamage", "JazzPreventSpawnBlockers", function(ply,attacker)
		if CurTime() - ply.JazzSpawnTime <= 0.5 and attacker:GetClass() == "trigger_hurt" then
			if IsValid(attacker) then
				print("Preventing spawn blocker, " .. tostring(attacker) .. " killed!" )
				attacker:Remove()
			end
			return false
		end
	end )

	hook.Add("OnEntityCreated", "JazzPreventWeaponStrippers", function(ent)
		timer.Simple(0, function() --give it a tick to figure out what it is
			if IsValid(ent) then
				local class = ent:GetClass()
				if string.find(class, "weapon", 1, true) and string.find(class, "strip", 1, true) then
					print("Preventing weapon stripping, " .. tostring(ent) .. " killed!")
					ent:Remove()
				end
				--these could be paired with trigger_weapon_strip, and could have logic depending on supercharging a gravity gun to continue the map
				if class == "trigger_weapon_dissolve" then
					local MapLua = ents.Create( "lua_run" )
					MapLua:SetName( "JazzWeaponDissolveHook" )
					MapLua:Spawn()
					ent:Fire("AddOutput", "OnStartTouch JazzWeaponDissolveHook:RunPassedCode:hook.Run( 'JazzWeaponDissolve' ):0:1")
					ent:Fire("AddOutput", "OnStartTouch JazzWeaponDissolveHook:Kill::1:1")
				end
			end
		end )
	end )

	--sort of relying on a lot of stuff to go right for this to work, but fuck it, it's a weird entity setup
	hook.Add("JazzWeaponDissolve", "JazzGetMeAPhyscannon", function()
		for _, v in ipairs(player.GetHumans()) do
			local gravgun = ents.Create("weapon_physcannon")
			if IsValid(gravgun) then
				gravgun:SetKeyValue( "spawnflags", 2) --deny player pickup
				gravgun.IgnoreForSnatch = true --"The game will crash if a weapon targeted for dissolving by this entity is removed by other means."
				gravgun:SetPos(v:GetPos())
				gravgun:Spawn()
				--[[// HACK: This hack is required to allow weapons to be disintegrated
					// in the citadel weapon-strip scene
					// Make them not pick-uppable again. This also has the effect of allowing weapons
					// to collide with triggers. ]]
				gravgun:RemoveSolidFlags(FSOLID_TRIGGER)
				local phys = gravgun:GetPhysicsObject()
				if IsValid(phys) then phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP) end
				--don't leave it lying there
				timer.Simple(20, function() if IsValid(gravgun) then gravgun:Remove() end end )
			end
		end
	end )

else //CLIENT
	net.Receive("jazz_shardcollect", function(len, ply)
		SpawnedShards = {}
		local left = net.ReadUInt(16)
		for i=1, left do
			table.insert(SpawnedShards, net.ReadEntity())
		end
		local total = net.ReadUInt(16)

		surface.PlaySound("ambient/alarms/warningbell1.wav")
		InitialShardCount = total

		-- Broadcast update
		--hook.Call("JazzShardCollected", GAMEMODE, left, total)
	end )


end