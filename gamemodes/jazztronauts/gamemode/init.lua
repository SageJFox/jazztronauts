jit.opt.start( 3 )
jit.opt.start( "hotloop=36", "hotexit=60", "tryside=4" )

include("sv_jazztronauts.lua")
include("sv_resource.lua")

include( "shared.lua" )
include( "newgame/init.lua")
include( "store/init.lua" )
include( "ui/init.lua" )
include( "map/init.lua" )
include( "missions/init.lua")
include( "snatch/init.lua" )
include( "playerwait/init.lua")
include( "lzma/lzma.lua")

include( "player.lua" )

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_scoreboard.lua" )
AddCSLuaFile( "cl_jazzphysgun.lua")
AddCSLuaFile( "player.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "missions/cl_init.lua" )
AddCSLuaFile( "playerwait/cl_init.lua")
AddCSLuaFile( "newgame/cl_init.lua")

AddCSLuaFile( "cl_hud.lua" )
AddCSLuaFile("cl_texturelocs.lua")

util.AddNetworkString("shard_notify")

local LOADING_SCREEN_URL = "asset://garrysmod/html/jazzload/loading-basic.html"
if BRANCH == "x86-64" then
	LOADING_SCREEN_URL = "asset://garrysmod/html/jazzload/loading.html"
end

CreateConVar("crazyfix","0",bit.bor(FCVAR_PROTECTED,FCVAR_UNREGISTERED,FCVAR_UNLOGGED))

concommand.Add( "jazz_test_lzma", function()

	print("RUNNING LZMA TEST")

	local test = lzma.Decompressor( lzma.FileReader("test2.gma"), lzma.FileWriter("yourmom.dat") )
	local decoded_header = false

	test:SetProgressCallback( function( decompressed, total, percent )

		if decoded_header == false and decompressed > 0x40000 then
			decoded_header = true

			local b, e = pcall( gmad.ReadFileEntries, test:GetWindowReader() )
			PrintTable( b and e or { e } )
		end

		print( ("decompressing: %0.2f%%"):format( percent ) )

	end )

	test:Start()

end)

local autoSetMap = CreateConVar("jazz_debug_checkmap", "1", { FCVAR_ARCHIVE }, "Disable automatically changing maps depending on story progress")

local function SetIfDefault(convarstr, ...)
	local convar = GetConVar(convarstr)
	if not convar or convar:GetDefault() == convar:GetString() then
		RunConsoleCommand(convarstr, ...)
	end
end

function GM:Initialize()
	self.BaseClass:Initialize()

	game.SetGlobalState( "gordon_invulnerable", GLOBAL_DEAD )

	SetIfDefault("sv_loadingurl", LOADING_SCREEN_URL)
	SetIfDefault("sv_gravity", "800")
	SetIfDefault("sv_airaccelerate", "150")

	RunConsoleCommand("mp_falldamage", "1")

	mapcontrol.ClearCache()
	mapcontrol.SetupMaps()

	-- Add the current map's workshop pack to download
	-- Usually this is automatic, but because we're doing some manual mounting, it doesn't happen
	local wsid = workshop.FindOwningAddon(game.GetMap()) or ""
	resource.AddWorkshop(wsid)
end

function GM:InitPostEntity()
	self.BaseClass:InitPostEntity()

	-- Check if the current map makes sense for where we are in the story
	-- If not (and returns false), we're changing level to the correct one
	local redirect = self:CheckGamemodeMap()
	if redirect then print("=========== REDIRECT: " .. redirect) end
	if redirect and redirect != game.GetMap() and autoSetMap:GetBool() then
		mapcontrol.Launch(redirect)
	end
end

-- Given a certain global state, we want to 100% force whether or not we should be on a map
-- For example, on a fresh restart, always start at the tutorial
function GM:CheckGamemodeMap()
	local curMap = game.GetMap()
	local lastMap = newgame.GetGlobal("last_map")
	local unlocked = tobool(newgame.GetGlobal("unlocked_encounter"))
	newgame.SetGlobal("unlocked_encounter", false) -- Reset, they can only visit it when we say so

	-- Haven't finished intro yet, changelevel to intro
	if not tobool(newgame.GetGlobal("finished_intro")) then
		if curMap != mapcontrol.GetIntroMap() then
			return mapcontrol.GetIntroMap()
		end

	-- Changelevel'd back to intro? WHy?
	elseif curmap == mapcontrol.GetIntroMap() then
		--return mapcontrol.GetHubMap() -- nah, let em, not hurting anybody
	end

	-- Don't let them changelevel to the Ending Level until they've got enough shards
	-- OR if they've already seen the ending
	local hasEnded = tobool(newgame.GetGlobal("ended"))
	local endType = tonumber(newgame.GetGlobal("ending"))

	--local collected, required = mapgen.GetTotalCollectedShards(), mapgen.GetTotalRequiredShards()
	--local bcollected, brequired = mapgen.GetTotalCollectedBlackShards(), mapgen.GetTotalRequiredBlackShards()

	local endmaps = mapcontrol.GetEndMaps()

	-- Only applicable if they haven't finished the game yet
	if not hasEnded then

		-- If they're supposed to be ending but on a normal map instead, switch to end
		if endType and endmaps[endType] then
			return endmaps[endType]
		end

		-- Check for bad ending shard stuff
		local _, shouldencounter = mapcontrol.GetNextEncounter()
		if shouldencounter then
			return mapcontrol.GetEncounterMap()
		end
	end

	-- No map change occurring
	return nil
end

function GM:JazzMapStarted()
	print("MAP STARTED!!!!!!!")
	local isIntro = game.GetMap() == mapcontrol.GetIntroMap()
	if not mapcontrol.IsInGamemodeMap() or isIntro then
		game.CleanUpMap()
		self:GenerateJazzEntities(isIntro)
	end

	-- Unlock and respawn everyone
	for _, v in pairs(player.GetAll()) do
		v:UnLock()
		v:KillSilent()
		v:Spawn()
	end

	-- If intro map, mark as played
	if game.GetMap() == mapcontrol.GetIntroMap() then
		--newgame.SetGlobal("finished_intro", true)
	end

	crazywarn = crazywarn or GetConVar("sv_crazyphysics_warning"):GetString()
	crazydefuse = crazydefuse or GetConVar("sv_crazyphysics_defuse"):GetString()
	crazyremove = crazyremove or GetConVar("sv_crazyphysics_remove"):GetString()

end

function GM:GenerateJazzEntities(noshards)

	if not mapcontrol.IsInHub() then
		if not noshards then
			local bcollected, brequired = mapgen.GetTotalCollectedBlackShards(), mapgen.GetTotalRequiredBlackShards()

			-- Add current map to list of 'started' maps
			local map = progress.GetMap(game.GetMap())

			-- After collecting 5 bad boy shards, stop spawning normal shards
			local shouldGenNormalShards = tobool(newgame.GetGlobal("ended")) or bcollected <= brequired / 2

			-- If the map doesn't exist, try to generate as many shards as we can
			-- Then store that as the map's worth
			if not map or tonumber(map.seed) == 0 then
				print("Brand new map")
				local shardworth = mapgen.CalculateShardCount()
				local seed = math.random(0, 100000)
				if shouldGenNormalShards then
					shardworth = mapgen.GenerateShards(shardworth, seed) -- Not guaranteed to make all shards
				end

				map = progress.StartMap(game.GetMap(), seed, shardworth)

				-- Chance to corrupt the map if ng+
				-- JK chance is 100%
				if tobool(newgame.GetGlobal("encounter_1")) and map.corrupt == progress.CORRUPT_NONE then
					progress.SetCorrupted(game.GetMap(), progress.CORRUPT_SPAWNED)
					map = progress.GetMap(game.GetMap()) -- Re-query to see if it took
				end

			-- Else, spawn shards, but only the ones that haven't been collected
			else
				map = progress.StartMap(game.GetMap()) -- Start a new session, but keep existin mapgen info
				local shards = progress.GetMapShards(game.GetMap())

				if shouldGenNormalShards then
					local generated = mapgen.GenerateShards(#shards, tonumber(map.seed), shards)

					if #shards > generated then
						print("WARNING: Generated less shards than we have data for. Did the map change?")
						-- Probably mark those extra shards as collected I guess?
					end
				end
			end

			-- If the map has been corrupted, spawn a black shard
			-- (it will handle whether it was already stolen)
			if (map.corrupt > progress.CORRUPT_NONE) then
				mapgen.GenerateBlackShard(map.seed)
			end

			--spawn markers for Roadtrips
			for _, v in ipairs(ents.FindByClass("*_changelevel")) do

				local destname = string.Trim( utf8.char( unpack( v:GetInternalVariable( "m_szMapName" ) ) ), "\0" )
				if string.lower(destname) == string.lower(game.GetMap()) then continue end --Seriously Valve what the fuck

				local ent = nil
				--fine Valve, use the same name for other ents
				for _, v in ipairs(ents.FindByName( string.Trim( utf8.char( unpack( v:GetInternalVariable( "m_szLandmarkName" ) ) ), "\0" ) )) do
					if IsValid(v) and v:GetClass() == "info_landmark" then ent = v break end
				end
				local busmark = ents.Create("jazz_stanteleportmarker")

				if not IsValid(ent) or not IsValid(busmark) then continue end

				busmark:SetPos(ent:GetPos())
				--busmark:SetAngles( Angle( 0, 0, ent:GetAngles().z ) ) --just kidding no angles on landmarks
				busmark:SetBusMarker(true)
				busmark:SetDestinationName(destname .. ":" .. game.GetMap()) --map names can't have a colon, so we use that as a separator
				busmark:SetDestination(ent)
				busmark:SetLevel(99)
				busmark:Spawn()

				v:Remove() --changelevels on at least Ep1/Ep2 maps completely lock up the player, even after respawn. How fun!

			end
		end

		-- Spawn static prop proxy entities
		snatch.SpawnProxies()

		-- Calculate worth of each map-spawned prop
		-- Mo' players = mo' money
		mapgen.CalculatePropValues(15000)
	end

end

function GM:ShutDown()
	if not mapcontrol.IsInHub() then
		progress.UpdateMapSession(game.GetMap())
	end

	--revert crazyphysics settings
	local crazyfix = GetConVar("crazyfix")
	if crazyfix:GetBool() == true then
		if crazywarn then RunConsoleCommand("sv_crazyphysics_warning",crazywarn) end
		if crazydefuse then RunConsoleCommand("sv_crazyphysics_defuse",crazydefuse) end
		if crazyremove then RunConsoleCommand("sv_crazyphysics_remove",crazyremove) end
		crazyfix:SetBool(false)
	end

	if not mapcontrol.IsLaunching() then
		local convar = GetConVar("sv_loadingurl")
		if convar and convar:GetString() == LOADING_SCREEN_URL then
			RunConsoleCommand("sv_loadingurl", "")
		end
	end
end

-- Save progress every little bit or so
function GM:Think()
	if not self.JazzNextSave or CurTime() > self.JazzNextSave then
		progress.UpdateMapSession(game.GetMap())
		self.JazzNextSave = CurTime() + 30
	end
end

-- Called when somebody has collected a shard
function GM:CollectShard(shard, ply)
	local left, total = mapgen.CollectShard(ply, shard)
	if not left then return false end
	-- Go you
	ply:ChangeNotes(math.floor( shard.JazzWorth * newgame.GetMultiplier() ))
	newgame.GetRoadtripTotals() --update totals, too

	net.Start("shard_notify")
		net.WriteEntity( ply )
	net.Broadcast()

end

-- Called when somebody has collected a bad boy shard
function GM:CollectBlackShard(shard, ply)
	local corr = mapgen.CollectBlackShard(shard)
	print("Collecting black shard. Map corrupted now? ", corr)

	-- Set endgame state if not ended
	if not tobool(newgame.GetGlobal("ended")) then
		local bcollected, brequired = mapgen.GetTotalCollectedBlackShards(), mapgen.GetTotalRequiredBlackShards()

		-- CONGRATS, YOU KILLED US ALL
		if bcollected >= brequired then
			newgame.SetGlobal("ending", newgame.ENDING_ECLIPSE)
		end
	end
end

-- Called when prop is snatched from the level
function GM:CollectProp(prop, ply)
	print("COLLECTED: " .. tostring(prop and prop:GetModel() or "<entity>"))
	local worth = mapgen.CollectProp(ply, prop)

	-- Collect the prop to the poop chute
	if worth and worth > 0 then --TODO: Check if worth > 1 not 0
		worth = worth * newgame.GetMultiplier()
		local newCount = snatch.AddProp(ply, prop:GetModel(), worth)
		propfeed.notify( prop, ply, newCount, worth)

		-- Also maybe collect the prop for player missions
		for _, v in pairs(player.GetAll()) do
			missions.AddMissionProp(v, prop:GetModel())
		end
	end
end

-- Calculate which side material of the brush we'll store
-- Brushes can have a different material for each face, so just take the
-- largest non-tool surface area
function GM:GetPrimaryBrushMaterial(brush)

	local maxmaterial = nil
	local maxarea = -1
	for _, v in pairs(brush.sides) do
		if not v.winding then continue end
		local texinfo = v.texinfo
		local texdata = texinfo.texdata
		local mat = texdata.material

		local area = string.find(mat, "TOOLS/TOOLSNODRAW") and 0 or v.winding:Area()
		if area > maxarea then
			maxarea = area
			maxmaterial = mat
		end
	end

	if not maxmaterial then
		print("Collected brush with no valid surface materials! (brushid: " .. brush.id .. ")")
		return
	end

	maxmaterial = string.lower(maxmaterial):gsub("_[+-]?%d+_[+-]?%d+_[+-]?%d+$",""):gsub("^maps/[%w_]+/","")
	return maxmaterial, maxarea
end

function GM:GetPrimaryDisplacementMaterial(displacement)
	return displacement.face.texinfo.texdata.material
end

function GM:CollectBrush(brush, players)

	local material, area = self:GetPrimaryBrushMaterial(brush)

	local size = brush.max - brush.min
	local length = size.x + size.y + size.z

	local worth = math.pow(length, 1.1) / 15.0

	-- Collect the prop to the poop chute
	if worth and worth > 0 then --TODO: Check if worth > 1 not 0
		worth = worth * newgame.GetMultiplier()
		for _, ply in pairs(players) do
			if not IsValid(ply) then continue end

			local newCount = snatch.AddProp(ply, material, worth, "brush")
			propfeed.notify_brush( material, ply, worth )
			--propfeed.notify( prop, ply, newCount, worth)
		end
	end

	-- Also maybe collect the prop for player missions
	/*
	for _, v in pairs(player.GetAll()) do
		missions.AddMissionProp(v, prop:GetModel())
	end
	*/
end

function GM:CollectDisplacement(displacement, players)

	local material, area = self:GetPrimaryDisplacementMaterial(displacement)

	local size = displacement.maxs - displacement.mins
	local length = size.x + size.y + size.z

	local worth = math.pow(length, 1.1) / 15.0

	-- Collect the prop to the poop chute
	if worth and worth > 0 then --TODO: Check if worth > 1 not 0
		worth = worth * newgame.GetMultiplier()
		for _, ply in pairs(players) do
			if not IsValid(ply) then continue end

			local newCount = snatch.AddProp(ply, material, worth, "displacement")
			propfeed.notify_brush( material, ply, worth )
			--propfeed.notify( prop, ply, newCount, worth)
		end
	end
end


function GM:JazzDialogFinished(ply, script, markseen)

	-- Mark this as 'seen', so other systems know to continue
	if script and markseen then
		unlocks.Unlock(converse.ScriptsList, ply, script)
	end
end

-- TODO: Just for debugging for now
local function PrintMapHistory(ply)

	ply:ChatPrint("Waddup. Here's all the maps we've played (including unfinished):")
	local maps = progress.GetMapHistory()

	if maps then
		for _, v in pairs(maps) do
			local mapstr = v.filename
			mapstr = mapstr //.. " (Started " .. string.NiceTime(os.time() - v.starttime) .. " ago)"

			ply:ChatPrint(mapstr)
		end
	end
end

function GM:PlayerInitialSpawn( ply )
	self.BaseClass:PlayerInitialSpawn(ply)

	ply:SetTeam(1) -- We're all on the same team fellas

	-- Update the new player with the current map selection state
	mapcontrol.Refresh(ply)
	mapgen.UpdateShardCount(ply)

	-- Update them with their active missions
	missions.UpdatePlayerMissionInfo(ply)

	-- Freeze them if map hasn't started yet
	if self:IsWaitingForPlayers() then
		timer.Simple(0, function()
			if self:IsWaitingForPlayers() then
				ply:Lock()
			end
		end )
	end

	ply:SuppressHint( "Annoy1" )
	ply:SuppressHint( "Annoy2" )
	if mapcontrol.IsInGamemodeMap() then
		ply:SuppressHint( "OpeningMenu" )
	end
	ply:SendHint( "OpeningContext", 30 )
end

-- PlayerInitialSpawn runs before player is fully loaded and can see, for visible stuff use this hook
hook.Add("OnClientInitialized", "JazzTransitionIntoBar", function(ply)
	-- Hey. Don't play this in singleplayer
	if game.SinglePlayer() then
		timer.Simple(3, function()
			dialog.Dispatch("no_singleplayer_allowed.begin", ply)
		end )
	end
end )

function GM:PlayerSpawn( ply )
	local class = mapcontrol.IsInGamemodeMap() and "player_hub" or "player_explore"
	player_manager.SetPlayerClass( ply, class)

	-- Stop observer mode
	ply:UnSpectate()

	local ang = ply:EyeAngles()
	ang.r = 0
	ply:SetEyeAngles(ang)

	player_manager.OnPlayerSpawn( ply )
	player_manager.RunClass( ply, "Spawn" )

	--self.BaseClass.PlayerSpawn( self, ply )

	hook.Call( "PlayerLoadout", GAMEMODE, ply )
	hook.Call( "PlayerSetModel", GAMEMODE, ply )
	ply:SetupHands()
end

-- Stop killing the player, they don't collide
function GM:IsSpawnpointSuitable(ply, spawnent, makesuitable)
	return true
end

-- Don't allow pvp by default, except self-damage cause rocketjumping fun
function GM:PlayerShouldTakeDamage(ply, attacker)
	if attacker:IsValid() and attacker:IsPlayer() and ply != attacker then
		return cvars.Bool("jazz_pvp")
	end

	return true
end

-- no fall damange with Run
function GM:GetFallDamage(ply, speed)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "weapon_run" then
		if not wep:ShouldTakeFallDamage() then return 0 end
	end

	return self.BaseClass.GetFallDamage(self, ply, speed)
end

function GM:EntityTakeDamage( target, dmginfo )
	if  target:IsPlayer() and bit.band(dmginfo:GetDamageType(),bit.bor(DMG_CLUB,DMG_SLASH,DMG_CRUSH)) > 0 and not dmginfo:GetAttacker():IsNPC() then
		local wep = target:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_run" then
			local scale = wep:PhysDmgScale() or 1
			local olddmg = dmginfo:GetDamage()
			dmginfo:ScaleDamage( scale )
			if scale < 1 then
				if dmginfo:GetDamage() <= (wep:PhysDmgLevel() or 0) then dmginfo:SetDamage(0) end --completely block damage if it's less than [level]
				local volumeadjust = math.max(15,math.min(100,olddmg - dmginfo:GetDamage())) / 100 --get a number between 0.15 and 1 depending on our damage blocked
				target:EmitSound("weapons/physcannon/energy_bounce1.wav",100,125 - scale * 100 + math.Rand(-10,10),volumeadjust)
				--print("Bdoosh",volumeadjust)
			end
		end
	end

	return self.BaseClass.EntityTakeDamage(target,dmginfo)
end


local acknowledge = "yep, dump it"
concommand.Add("jazz_reset_progress", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local phrase = table.concat(args, " ")
	if phrase != acknowledge then
		local failInfo = "Are you sure you want to reset progress? This command cannot be undone."
		.. "\nRe-run this command with the argument \"" .. acknowledge .. "\" to acknowledge."
		if IsValid(ply) then
			ply:ChatPrint(failInfo)
		else
			print(failInfo)
		end
		return
	end

	jsql.Reset()
	unlocks.ClearAll()
	mapcontrol.Launch(mapcontrol.GetIntroMap())

	print("Dump'd.")

end, nil, "Reset all jazztronauts progress entirely. This wipes all player progress, map history, purchases, unlocks, and previous game data.")

--keep track of changes to crazyphysics
cvars.AddChangeCallback("sv_crazyphysics_warning",function(convar,oldval,newval)
	if not GetConVar("crazyfix"):GetBool() then
		crazywarn = newval
	end
end)
cvars.AddChangeCallback("sv_crazyphysics_defuse",function(convar,oldval,newval)
	if not GetConVar("crazyfix"):GetBool() then
		crazydefuse = newval
	end
end)
cvars.AddChangeCallback("sv_crazyphysics_remove",function(convar,oldval,newval)
	if not GetConVar("crazyfix"):GetBool() then
		crazyremove = newval
	end
end)
