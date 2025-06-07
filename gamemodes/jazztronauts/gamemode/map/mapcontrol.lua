
module( 'mapcontrol', package.seeall )
local defaultMapHost = "http://jazz.foohy.net/addons.txt"
local defaultAddonList = "data_static/jazztronauts/addons.txt"
local overrideAddonCache = "jazztronauts/addons_override.txt"

local fallbackVersion = VERSION < 210618 -- Maps unmounted fixed in gmod dev branch version 210618. Before that, fallback to local addons/maps instead

local includeExternal = CreateConVar("jazz_include_external", 1, FCVAR_ARCHIVE, "Whether or not to include an external addon host. Used for searching all of workshop")
local includeLocalAddons = CreateConVar("jazz_include_localaddon", 0, FCVAR_ARCHIVE, "Whether or not to include maps from locally installed addons. ")
local includeLocalMaps = CreateConVar("jazz_include_localmap", 0, FCVAR_ARCHIVE, "Whether or not to include local loose maps in the maps folder.")

local includeExternalHost = CreateConVar("jazz_include_external_host", defaultMapHost, FCVAR_ARCHIVE,
	   "Override the source of what random maps to pull from.\n"
	.. "Can be either a URL to a text file, listing each workshop addon by id\n"
	.. "Or a workshop collection ID itself.")

local hubmap = CreateConVar("jazz_hub", "jazz_bar",bit.bor(FCVAR_ARCHIVE,FCVAR_PRINTABLEONLY),"Name of the map to use as a hub.")
local outromap = CreateConVar("jazz_hub_outro", "jazz_outro",bit.bor(FCVAR_ARCHIVE,FCVAR_PRINTABLEONLY),"Name of the map to use for normal ending.")
local outro2map = CreateConVar("jazz_hub_outro2", "jazz_outro2",bit.bor(FCVAR_ARCHIVE,FCVAR_PRINTABLEONLY),"Name of the map to use for true ending.")

concommand.Add("jazz_clear_cache", function()
	ClearCache()
end,
nil, "Clears the temporary cache of downloaded map files")

local function UpdateMapsConvarChanged()
	SetupMaps()
end

cvars.AddChangeCallback(includeExternal:GetName(), UpdateMapsConvarChanged, "jazz_mapcontrol_cback")
cvars.AddChangeCallback(includeLocalAddons:GetName(), UpdateMapsConvarChanged, "jazz_mapcontrol_cback")
cvars.AddChangeCallback(includeLocalMaps:GetName(), UpdateMapsConvarChanged, "jazz_mapcontrol_cback")

votesToLeave = 0 --if we're too close to the edict limit to summon the bus, count bus summoner useage as a vote to leave

function voteToLeave(vote)
	if ents.GetEdictCount() < 8064 then votesToLeave = 0 return end --we've dipped back below a dangerous edict level, no need for voting
	local summoners = 0 --total number of bus summoners with player owners (not all players might have/be able to get summoners if we're near edict limit)
	for _, ent in ents.Iterator() do
		if IsValid(ent) then
			if ent:GetClass() == "jazz_bus" then return end --we have a bus, that'll handle leaving
			if ent:GetClass() == "weapon_buscaller" and IsValid(ent:GetOwner()) and ent:GetOwner():IsPlayer() and not ent.JazzAFK then
				summoners = summoners + 1
			end
		end
	end
	local majority = math.ceil(summoners / 2)
	votesToLeave = vote and votesToLeave + 1 or math.max(0,votesToLeave - 1)
	if votesToLeave >= majority and not IsLaunching() then --get us out of here
		--TODO: make this a little less abrupt. Add HUD stuff explaining what's going on/showing a current vote to leave
		Launch(GetHubMap())
	end
end

local server_ugc = false

if file.Find("lua/bin/gmsv_workshop_*.dll", "GAME")[1] ~= nil then
	require("workshop")
	server_ugc = true
else
	if game.IsDedicated() then
		print("If you want to use ugc maps on a dedicated server please install gmsv_workshop! | https://github.com/WilliamVenner/gmsv_workshop")
	end
end

curSelected = curSelected or {}
addonList = addonList or {}

local function jazzmap(mapname)
	--these initial checks allow maps to be used as hubs that don't have jazz prefix
	if IsInHub() --[[or IsInEncounter()]] then return true end
	local endmaps = GetEndMaps()
	if endmaps[1] == mapname or endmaps[2] == mapname then return true end

	local pref = string.Split(mapname, "_")[1]
	return pref == "jazz"
end

function GetMap()
	return curSelected.map
end

function IsInHub()
	return game.GetMap() == GetHubMap()
end

function IsInEncounter()
	return game.GetMap() == GetEncounterMap()
end

function IsInGamemodeMap()
	return jazzmap(game.GetMap())
end

function GetIntroMap()
	return "jazz_intro"
end

function GetEncounterMap()
	return "jazz_apartments"
end

function GetEndMaps()
	local outro, outro2 = outromap:GetString(), outro2map:GetString()
	if outro == nil or outro == "" then outro = "jazz_outro" end
	if outro2 == nil or outro2 == "" then outro2 = "jazz_outro2" end
	return { outro, outro2 }
end

function GetNextEncounter()
	local bshardCount, bshardReq = mapgen.GetTotalCollectedBlackShards(), mapgen.GetTotalRequiredBlackShards()
	local isngp = newgame.GetResetCount() > 0
	if not isngp then return nil end

	local seen1, seen2, seen3 = tobool(newgame.GetGlobal("encounter_1")),
		tobool(newgame.GetGlobal("encounter_2")),
		tobool(newgame.GetGlobal("encounter_3"))
	local halfway = math.Round(bshardReq / 2)

	-- First encounter, show if ng+ (not required level change though)
	if bshardCount == 0 and not seen1 then
		return 1, false
	elseif bshardCount >= 1 and bshardCount < halfway and not seen2 then
		return 2, true
	elseif bshardCount > halfway and not seen3 then
		return 3, true
	end

	return nil
end

function GetHubMap()
	local hub = hubmap:GetString()
	if hub == nil or hub == "" then return "jazz_bar" end
	hub = string.StripExtension(hub) --in case they put .bsp on the end
	return hub
end

function GetMapID(mapname)
	local crc = tonumber(util.CRC(string.lower(mapname)))
	return crc % 90000000 + 10000000
end

if SERVER then
	util.AddNetworkString("jazz_rollmap")

	local launched = false

	-- Roll a new random map to select
	function RollMap()
		print("mapcontrol.RollMap() is disabled.")
		return
		/*
		local newMap = table.Random(mapList)
		SetSelectedMap(newMap)
		return newMap, mapIDs[newMap]
		*/
	end

	function GetRandomAddon()
		return table.Random(addonList)
	end

	function IsWorkshopAddon(name)
		return tonumber(name) != nil
	end

	-- Given a unique map id, roll to it
	function RollMapID(id)
		local newMap = addonList[id] and table.Random(addonList[id])
		if newMap then
			SetSelectedMap(newMap)
		end

		return newMap
	end

	-- Get a random valid unique map id
	function GetRandomMapID()
		local v, _ = table.Random(addonList)
		return v
	end

	function GetMapsInAddon(wsid)
		local maps = {}
		local found = file.Find("maps/*.bsp", wsid)
		for _, v in pairs(found) do
			table.insert(maps, string.StripExtension(v))
		end

		return maps
	end

	function GetSelectedMap()
		return curSelected.map
	end

	-- Update the new selected map
	function SetSelectedMap(newMap)
		if newMap == curSelected.map then return end
		curSelected.map = newMap

		-- Update workshop info
		local wsid = workshop.FindOwningAddon(newMap)
		curSelected.wsid = wsid

		-- If workshop info present, it might be a map pack, so store that too
		curSelected.maps = wsid and GetMapsInAddon(wsid) or {}

		hook.Call("JazzMapRandomized", GAMEMODE, curSelected.map, curSelected.wsid)

		mapcontrol.Refresh()
	end

	-- Send the current map to this player (usually if they just joined)
	function Refresh(ply)
		if not curSelected.map then return end

		net.Start("jazz_rollmap")
			net.WriteString(curSelected.map)
			net.WriteString(curSelected.wsid or "")
			net.WriteUInt(#curSelected.maps, 8)
			for _, v in ipairs(curSelected.maps) do
				net.WriteString(v)
			end
		return IsValid(ply) and net.Send(ply) or net.Broadcast()
	end


	function Launch(mapname)
		local lastmap = game.GetMap()
		newgame.SetGlobal("last_map", lastmap)
		playerwait.SavePlayers()
		launched = true
		RunConsoleCommand("changelevel", mapname)
		--if the map launch fails, go back to hub
		timer.Simple(1,function()
			--if lastmap == game.GetMap() then --fun fact this check doesn't matter, if the level change succeeded this code doesn't run at all
				RunConsoleCommand("changelevel", GetHubMap())
				--if hub try fails (bad concommand), go back specifically to the bar
				timer.Simple(1,function()
					--if lastmap == game.GetMap() then
						RunConsoleCommand("changelevel", "jazz_bar")
					--end
				end)
			--end
		end)
	end

	function IsLaunching()
		return launched
	end


	-- Given a workshop id, try to download and mount it
	-- if it hasn't already been downloaded/mounted
	function InstallAddon(wsid, finishFunc, decompFunc)

		local function PostDownload(filepath, errmsg)
			-- Bad workshop ID or network failure
			if not filepath then
				print("Failed to download addon: " .. errmsg)
				finishFunc(nil, errmsg)
				return
			end

			-- Try mounting
			print("Addon downloaded, decompressing and mounting...")
			local time = SysTime()
			local s, files = game.MountGMA(filepath)
			print("Mounting: " .. (SysTime() - time) .. " seconds.")

			if s and files then
				print("CONTENT MOUNTED!!!")
				--PrintTable(files)
			end

			finishFunc(files)
		end

		-- Download from internet and mount
		if not server_ugc then
			workshop.DownloadGMA(wsid, function(filepath, errmsg)
				PostDownload(filepath, errmsg)
			end, decompFunc)
		else
			print("Downloading Via UGC!")
			steamworks.DownloadUGC(wsid, function(filepath, file)
				print("UGC Download Success!")
				PostDownload(filepath, "Failed to download addon: UGC download failed.")
			end, decompFunc)
		end
	end

	function ClearCache()
		workshop.ClearCache()
	end

	local function GetExternalMapAddons(contents)
		local addons = {}

		for line in string.gmatch(contents, "[^\r\n]+") do
			local num = tonumber(line)
			if not num then continue end
			table.insert(addons, num)
		end

		-- Built in cache that comes with the game
		if #addons == 0 then
			ErrorNoHalt("Bad addon list, using backup!") --in case Foohy's server eats the list we still want people able to tell us

			for line in string.gmatch(file.Read(defaultAddonList, "GAME"), "[^\r\n]+") do
				local num = tonumber(line)
				if not num then continue end
				table.insert(addons, num)
			end
		end

		return addons
	end

	local function GetLocalMapAddons()
		local valid = {}
		local addons = engine.GetAddons()

		-- For each installed addon, search its contents for a map file
		for _, v in pairs(addons) do
			local found = file.Find("maps/*.bsp", v.title)
			if #found > 0 then
				table.insert(valid, v.wsid)
			end
		end

		return valid
	end

	local function GetLocalMaps()
		local maps, nojazz = file.Find("maps/*.bsp", "GAME"), {}
		for k, v in pairs(maps) do
			--filter jazz maps from pool
			if not jazzmap(string.GetFileFromFilename(v)) then table.insert(nojazz,string.StripExtension(v)) end
		end

		return nojazz
	end

	-- Build a list of all addons that have maps installed
	-- This list will become our entire possible sample range -- so it's gonna be big
	local function setupMapTask()
		local addons = {}

		local function insertAddons(newaddons)
			for k, v in pairs(newaddons) do
				addons[v] = true
			end
		end

		-- Automatically fall back to just choosing local addons gracefully if their user settings are the defaults of external
		-- If it's different then respect that decision though, but on fallback gmod versions external maps won't work
		local fallbackLocalOnly = fallbackVersion and includeExternal:GetBool()
		if fallbackLocalOnly then
			print("=====================\n JAZZTRONAUTS IS USING FALLBACK SETTINGS DUE TO CURRENT GMOD VERSION LIMITATIONS")
		end
		if includeExternal:GetBool() and not fallbackLocalOnly then
			local addonTask = task.NewCallback(function(done)
				local host = includeExternalHost:GetString()
				if not string.find(host,"^https?://") then host = "https://" .. host end
				http.Fetch(host, done, function(err) ErrorNoHalt("Failed to get latest addons.txt list!\n" .. err .. "\n") done() end)
			end )
			local addonsStr = task.Await(addonTask)

			if addonsStr and string.len(string.Trim(addonsStr)) > 0 then
				--todo: should do something to help prevent this from saving garbage from a bad host
				-- Save this successful run
				file.CreateDir(string.GetPathFromFilename(overrideAddonCache))
				file.Write(overrideAddonCache, addonsStr)
			else
				if addonsStr and string.len(string.Trim(addonsStr)) == 0 then ErrorNoHalt("Failed to fetch latest addons.txt list, list empty!")
				else ErrorNoHalt("Failed to fetch latest addons.txt list") end
				-- Try loading from their last successful download cache
				addonsStr = file.Read(overrideAddonCache, "DATA")
			end

			insertAddons(GetExternalMapAddons(addonsStr or ""))
		end

		if includeLocalAddons:GetBool() or fallbackLocalOnly then
			insertAddons(GetLocalMapAddons())
		end

		if includeLocalMaps:GetBool() or fallbackLocalOnly then
			insertAddons(GetLocalMaps())
		end

		addonList = table.GetKeys(addons)
	end

	function SetupMaps()
		task.New(setupMapTask, 1) -- ehh it'll get to it eventually
	end

	-- Spawn the exit bus's enterance portal at the specified position/angle.
	-- Note this spawns three entities, the enterance, the bus, and the exit
	-- (also note the bus itself has many entities attached to it. The seats, the radio...)
	lastBusEnts = lastBusEnts or {}
	function SpawnExitBus(pos, ang, target)
		local target = target or "<hub>"
		local spawnpos = pos
		local spawnang = Angle(ang)
		spawnang:RotateAroundAxis(spawnang:Up(), 90)

		-- Do a trace forward to where the bus will exit
		local tr = util.TraceLine( {
			start = pos,
			endpos = pos + ang:Forward() * 100000,
			mask = MASK_SOLID_BRUSHONLY
		} )

		local pos2 = tr.HitPos
		local ang2 = Angle(ang)
		ang2:RotateAroundAxis(ang2:Up(), -90)

		--if we're summoning the bus towards the edges of the map grid, crazy physics detection could dick us over

		--check our entrance
		local crazycheck = Vector(spawnpos)
		crazycheck:Add(ang:Forward() * -1024) -- TODO: 1024 back is just a rough estimate for leadup, figure out how much the trolley actually needs!

		--check our exit
		local crazy2 = Vector(pos2)
		crazy2:Add(ang:Forward() * 1024) -- TODO: 1024 forward is just a rough estimate for exit bore, figure out how much the trolley actually needs!

		--figure out if any of these are cray-zay
		--print("Am I crazy? ",crazycheck,crazy2)
		local craycray = math.max(math.abs(crazycheck.x),math.abs(crazycheck.y),math.abs(crazycheck.z),math.abs(crazy2.x),math.abs(crazy2.y),math.abs(crazy2.z))

		if craycray >= 16000 then
			GetConVar("crazyfix"):SetBool(true)
			RunConsoleCommand("sv_crazyphysics_warning","0")
			RunConsoleCommand("sv_crazyphysics_defuse","0")
			RunConsoleCommand("sv_crazyphysics_remove","0")
			print("Spawning or exiting too close to edge, disabling crazy physics protection!")
		end
 		--delay the bus so crazy physics has a chance to turn off before it spawns in and just gets removed anyway
		timer.Simple(0, function()
			local bus = ents.Create("jazz_bus")
			if IsValid(bus) then
				-- Remove last ones
				for _, v in pairs(lastBusEnts) do SafeRemoveEntityDelayed(v, 5) end
				bus:SetPos(spawnpos)
				bus:SetAngles(spawnang)
				bus:SetDestination(target)
				bus:SetHubBus(false)
				bus:Spawn()
				bus:Activate()
				table.insert(lastBusEnts, bus)

				local ent = ents.Create("jazz_bus_portal")
				if IsValid(ent) then
					ent:SetPos(spawnpos)
					ent:SetAngles(spawnang)
					ent:SetBus(bus)
					ent:Spawn()
					ent:Activate()
					table.insert(lastBusEnts, ent)
				end

				local exit = ents.Create("jazz_bus_portal")
				if IsValid(exit) then
					exit:SetPos(pos2)
					exit:SetAngles(ang2)
					exit:SetBus(bus)
					exit:SetIsExit(true)
					exit:Spawn()
					exit:Activate()

					bus.ExitPortal = exit -- So bus knows when to stop
					table.insert(lastBusEnts, exit)
				end
			elseif ents.GetEdictCount() >= 8064 then --bus was unable to spawn, check edicts. If we're here we're in a bad spot
				local oldbus = nil
				if #lastBusEnts > 0 then
					for _, ent in ipairs(lastBusEnts) do
						if IsValid(ent) and ent:GetClass() == "jazz_bus" then
							oldbus = ent
							break
						end
					end
				end
				if IsValid(oldbus) then return end --we have an old bus, crisis averted
				print("No bus and nearing edict limit. Abort!")
			end

		end)
	end

else //CLIENT

	net.Receive("jazz_rollmap", function(len, ply)
		curSelected = net.ReadString()
		local wsid = tonumber(net.ReadString())
		local maps = { curSelected }

		-- Read list of maps that are a part of this map pack
		-- Can be zero
		local num = net.ReadUInt(8)
		maps = {}
		for i = 1, num do
			table.insert(maps, net.ReadString())
		end
		PrintTable(maps)

		print("New map received: " .. curSelected)

		-- Broadcast update
		hook.Call("JazzMapRandomized", GAMEMODE, curSelected, wsid)
	end )


end
