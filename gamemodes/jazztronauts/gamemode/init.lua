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

--just spawning in a model for the entity
local basicMdl = function( tab, default, anim )
	local prop = ents.Create("prop_dynamic")
	local anim = anim or "idle"
	if IsValid(prop) then
		for k, v in pairs(tab) do
			if not isstring(v) or k == "classname" then continue end
			prop:SetKeyValue(k,v)
		end
		prop:SetModel((tab.model and tab.model ~= "") and tab.model or default)
		prop:SetPos(Vector(tab.origin or "0 0 0"))
		prop:SetAngles(Angle(tab.angles or "0 0 0"))
		prop:SetSkin(tonumber(tab.skin) or 0)
		local col = string.Split(tab.rendercolor or ""," ")
		if #col == 3 then prop:SetColor(Color( tonumber(col[1]) or 255, tonumber(col[2]) or 255, tonumber(col[3]) or 255, 255 )) end
		prop:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		prop:Spawn()
		timer.Simple( 0, function() if IsValid(prop) then prop:ResetSequenceInfo() prop:ResetSequence( anim ) end end )
		return prop
	end
	return nil
end

--just spawning in a solid model for the entity
local basicMdlSolid = function( tab, default, anim )
	local prop = basicMdl(tab, default, anim)
	if IsValid(prop) then
		prop:PhysicsInit(SOLID_VPHYSICS)
		local phy = prop:GetPhysicsObject()
		if IsValid(phy) then phy:EnableMotion(false) end
		return prop
	end
	return nil
end

--just spawning in a physics prop for the entity
local basicPhys = function( tab, default )
	local prop = ents.Create("prop_physics")
	if IsValid(prop) then
		for k, v in pairs(tab) do
			if not isstring(v) or k == "classname" then continue end
			prop:SetKeyValue(k,v)
		end
		prop:SetModel((tab.model and tab.model ~= "") and tab.model or default)
		prop:SetPos(Vector(tab.origin or "0 0 0"))
		prop:SetAngles(Angle(tab.angles or "0 0 0"))
		prop:SetSkin(tonumber(tab.skin) or 0)
		local col = string.Split(tab.rendercolor or ""," ")
		if #col == 3 then prop:SetColor(Color( tonumber(col[1]) or 255, tonumber(col[2]) or 255, tonumber(col[3]) or 255, 255 )) end
		--todo: check for motion disabled, etc.?
		prop:PhysicsInit(SOLID_VPHYSICS)
		prop:Spawn()
		prop:PhysWake()
		return prop
	end
	return nil
end

local L4DWeapon = function( tab, default )
	tab.model = default --okay
	local wep = nil
	if bit.band(tonumber(tab.spawnflags) or 0, 1) == 1 then --enable physics
		wep = basicPhys(tab, default)
		if not IsValid(wep) then return nil end
		wep:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	else
		wep = basicMdl(tab, default)
		if not IsValid(wep) then return nil end
	end
	if tab.weaponskin then wep:SetSkin(tonumber(tab.weaponskin) or 0) end
	return wep
end

--just spawning in another entity for the entity
local basicEnt = function( tab, entname )
	local prop = ents.Create(entname)
	if IsValid(prop) then
		for k, v in pairs(tab) do
			if not isstring(v) or k == "classname" then continue end
			prop:SetKeyValue(k,v)
		end
		prop:SetPos(Vector(tab.origin or "0 0 0"))
		prop:SetAngles(Angle(tab.angles or "0 0 0"))
		prop:Spawn()
		prop:Activate()
		return prop
	end
	return nil
end

local month = tonumber( os.date("%m",os.time()) )
--July for Jazztronauts' workshop debut (Happy birthday Jazz! c: )
if month == 7 then month = 12
--December or "snowy" for gift wrap
elseif string.find(game.GetMap(), "_snow") then month = 12
--October, "event", or zombie survival for halloween (of course some of them are event for christmas, but, whatever)
elseif string.find(game.GetMap(), "_event") or string.find(game.GetMap(), "^zi_") then month = 10 end

replacements = {
	-----------------------------------L4D/2-----------------------------------
	["func_simpleladder"] = function(tab,entnum)
		local ladder = ents.Create("func_wall")
		if IsValid(ladder) then
			local origin = Vector(tab.origin or "0 0 0")
			--push grid-aligned ladders just a smidge, in case they have clip brushes around them
			if math.abs(tonumber(tab["normal.x"])) == 1 or math.abs(tonumber(tab["normal.y"])) == 1 then
				origin:Add(Vector( tonumber(tab["normal.x"]), tonumber(tab["normal.y"]), 0 ))
			end
			ladder:SetPos(origin)
			ladder:SetAngles(Angle(tab.angles or "0 0 0"))
			ladder:SetModel(tab.model)
			ladder:Spawn()
			if tonumber(tab["normal.z"]) == 1 then
				local message = ents.Create("point_message")
				if IsValid(message) then
					local originm = Vector(tab.bmodel.maxs)
					originm:Add(Vector(tab.bmodel.mins))
					originm:Mul(0.5)
					message:SetKeyValue("developeronly","0")
					message:SetKeyValue("message","(#"..entnum..") ".."Sorry if this ladder's seemingly broken, blame Valve")
					message:SetKeyValue("radius","160")
					message:SetPos(originm)
					message:Spawn()
					message:Activate()
				end
			end
			return ladder
		end
	end,
	["weapon_melee_spawn"] = function(tab)
		local models = {
			["baseball_bat"] = "models/weapons/melee/w_bat.mdl",
			["cricket_bat"] = "models/weapons/melee/w_cricket_bat.mdl",
			["crowbar"] = "models/weapons/melee/w_crowbar.mdl",
			["electric_guitar"] = "models/weapons/melee/w_electric_guitar.mdl",
			["fireaxe"] = "models/weapons/melee/w_fireaxe.mdl",
			["frying_pan"] = "models/weapons/melee/w_frying_pan.mdl",
			["golfclub"] = "models/weapons/melee/w_golfclub.mdl",
			["katana"] = "models/weapons/melee/w_katana.mdl",
			["knife"] = "models/w_models/weapons/w_knife_t.mdl",
			["machete"] = "models/weapons/melee/w_machete.mdl",
			["pitchfork"] = "models/weapons/melee/w_pitchfork.mdl",
			["shovel"] = "models/weapons/melee/w_shovel.mdl",
			["tonfa"] = "models/weapons/melee/w_tonfa.mdl",
		}
		models.Any = table.Random(models)
		local wep = table.Random(string.Split(tab.melee_weapon,","))
		return L4DWeapon( tab, models[wep] or models.Any )
	end,
	["prop_door_rotating_checkpoint"] = function(tab)
		local door = ents.Create("prop_door_rotating")
		if IsValid(door) then
			for k, v in pairs(tab) do
				if not isstring(v) or k == "classname" then continue end
				door:SetKeyValue(k,v)
			end
			door:SetPos(Vector(tab.origin or "0 0 0"))
			door:SetAngles(Angle(tab.angles or "0 0 0"))
			--door:SetSkin(tonumber(tab.skin) or 0)
			door:PhysicsInit(SOLID_VPHYSICS)
			door:Spawn()
			return door
		end
		return nil
	end,
	["prop_car_alarm"] = function(tab)
		local car = basicPhys(tab, "models/props_vehicles/cara_69sedan.mdl")
		if IsValid(car) then
			local phy = car:GetPhysicsObject()
			if IsValid(phy) then
				--freeze it for a bit so the glass has time to adhere
				phy:EnableMotion(false)
				timer.Simple(1,function() if IsValid(car) then phy:EnableMotion(true) phy:Wake() end end) --todo: maybe check if it was intentionally motion disabled (flag #8)
			end
		end
	end,
	["prop_car_glass"] = function(tab)
		local glass = basicMdl(tab, "models/props_vehicles/cara_69sedan_glass.mdl")
		--attach it tah its cah (give said cah time tah spawn)
		timer.Simple(0,function()
			if IsValid(glass) then
				local car = ents.FindByName(tab.parentname)[1]
				if IsValid(car) then glass:SetParent(car) end
			end
		end)
	end,
	["weapon_ammo_spawn"] = function(tab) return basicMdl(tab, "models/props/terror/ammo_stack.mdl") end,
	["upgrade_laser_sight"] = function(tab) return basicMdl(tab, "models/w_models/weapons/w_laser_sights.mdl") end,
	["upgrade_ammo_explosive"] = function(tab) return basicMdl(tab, "models/props/terror/exploding_ammo.mdl") end,
	["upgrade_ammo_incendiary"] = function(tab) return basicMdl(tab, "models/props/terror/incendiary_ammo.mdl") end,
	["prop_minigun"] = function(tab) return basicMdlSolid(tab, "models/w_models/weapons/w_minigun.mdl") end,
	["prop_minigun_l4d1"] = function(tab) return basicMdlSolid(tab, "models/w_models/weapons/w_minigun.mdl") end,
	["prop_mounted_machine_gun"] = function(tab) return basicMdlSolid(tab, "models/w_models/weapons/50cal.mdl") end,
	["weapon_pistol_spawn"] = function(tab) return L4DWeapon(tab, IsMounted(550) and "models/w_models/weapons/w_pistol_a.mdl" or "models/w_models/weapons/w_pistol_1911.mdl") end,
	["weapon_pistol_magnum_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_desert_eagle.mdl") end,
	["weapon_smg_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_smg_uzi.mdl") end,
	["weapon_smg_silenced_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_smg_a.mdl") end,
	["weapon_smg_mp5_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_smg_mp5.mdl") end,
	["weapon_rifle_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_rifle_m16a2.mdl") end,
	["weapon_rifle_ak47_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_rifle_ak47.mdl") end,
	["weapon_rifle_desert_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_desert_rifle.mdl") end,
	["weapon_rifle_m60_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_m60.mdl") end,
	["weapon_rifle_sg552_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_rifle_sg552.mdl") end,
	["weapon_hunting_rifle_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_sniper_mini14.mdl") end,
	["weapon_sniper_military_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_sniper_military.mdl") end,
	["weapon_sniper_awp_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_sniper_awp.mdl") end,
	["weapon_sniper_scout_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_sniper_scout.mdl") end,
	["weapon_pumpshotgun_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_shotgun.mdl") end,
	["weapon_shotgun_chrome_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_pumpshotgun_a.mdl") end,
	["weapon_autoshotgun_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_autoshot_m4super.mdl") end,
	["weapon_shotgun_spas_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_shotgun_spas.mdl") end,
	["weapon_grenade_launcher_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_grenade_launcher.mdl") end,
	["weapon_pipe_bomb_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_pipebomb.mdl") end,
	["weapon_molotov_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_molotov.mdl") end,
	["weapon_vomitjar_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_bile_flask.mdl") end,
	["weapon_pain_pills_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_painpills.mdl") end,
	["weapon_adrenaline_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_adrenaline.mdl") end,
	["weapon_first_aid_kit_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_medkit.mdl") end,
	["weapon_defibrillator_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_defibrillator.mdl") end,
	["weapon_upgradepack_explosive_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_explosive_ammopack.mdl") end,
	["weapon_upgradepack_incendiary_spawn"] = function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_eq_incendiary_ammopack.mdl") end,
	["weapon_gascan_spawn"] = function(tab) return L4DWeapon(tab, "models/props_junk/gascan001a.mdl") end,
	["prop_health_cabinet"] = function(tab)
		local cabinet = basicMdlSolid(tab, "models/props_interiors/medicalcabinet02.mdl","open") --start it open (don't wanna bother setting up the ability for it to be opened)
		if IsValid(cabinet) then
			for i = 1, (tonumber(tab.HealthCount) or 2) do
				local attach = cabinet:GetAttachment(cabinet:LookupAttachment("item" .. tostring(i))) 
				if istable(attach) then
					local prop = replacements[ math.random(2) == 1 and "weapon_first_aid_kit_spawn" or "weapon_pain_pills_spawn"]({})
					if IsValid(prop) then
						local phys = prop:GetPhysicsObject()
						if IsValid(phys) then phys:Sleep() end
						prop:SetPos(attach.Pos)
						prop:SetAngles(attach.Ang)
					end
				end
			end
			return cabinet
		end
		return nil
	end,
	["prop_fuel_barrel"] = function(tab) return basicMdlSolid(tab, "models/props_industrial/barrel_fuel.mdl") end,
	["func_orator"] = function(tab)
		if not tab.model then return nil end
		if bit.band(tonumber(tab.spawnflags) or 0, 1) == 1 then --non-solid
			return basicMdl(tab, "")
		else
			return basicMdlSolid(tab, "")
		end
	end,
	["weapon_item_spawn"] = function(tab)
		--note: not bothering with director stuff. If you're crazy enough to try to implement something like it, check for spawnflag #2 [Spawned Item Must Exist]
		local whatarewe = {}
		if tobool(tab.item1) then table.insert(whatarewe, replacements["weapon_ammo_spawn"]) end
		if tobool(tab.item2) then table.insert(whatarewe, replacements["weapon_first_aid_kit_spawn"]) end
		if tobool(tab.item3) then table.insert(whatarewe, replacements["weapon_molotov_spawn"]) end
		if tobool(tab.item4) then table.insert(whatarewe, replacements["weapon_pain_pills_spawn"]) end
		if tobool(tab.item5) then table.insert(whatarewe, replacements["weapon_pipe_bomb_spawn"]) end
		if tobool(tab.item6) then table.insert(whatarewe, function(tab) return L4DWeapon(tab, "models/props_equipment/oxygentank01.mdl") end) end
		if tobool(tab.item7) then table.insert(whatarewe, function(tab) return L4DWeapon(tab, "models/props_junk/propanecanister001a.mdl") end) end
		if tobool(tab.item8) then table.insert(whatarewe, function(tab) return L4DWeapon(tab, "models/props_junk/gascan001a.mdl") end) end
		if tobool(tab.item11) then table.insert(whatarewe, replacements["weapon_adrenaline_spawn"]) end
		if tobool(tab.item12) then table.insert(whatarewe, replacements["weapon_defibrillator_spawn"]) end
		if tobool(tab.item13) then table.insert(whatarewe, replacements["weapon_vomitjar_spawn"]) end
		if tobool(tab.item16) then table.insert(whatarewe, function(tab) return L4DWeapon(tab, "models/weapons/melee/w_chainsaw.mdl") end) end
		if tobool(tab.item17) then table.insert(whatarewe, function(tab) return L4DWeapon(tab, "models/w_models/weapons/w_grenade_launcher.mdl") end) end
		if tobool(tab.item18) then table.insert(whatarewe, replacements["weapon_rifle_m60_spawn"]) end
		if tab.melee_weapon and tab.melee_weapon ~= "" then table.insert(whatarewe, replacements["weapon_melee_spawn"]) end
		local choice = table.Random(whatarewe)(tab)
		-- print(tostring(tab.item1 or 0) .. tostring(tab.item2 or 0) .. tostring(tab.item3 or 0) .. tostring(tab.item4 or 0) .. tostring(tab.item5 or 0) ..
		-- tostring(tab.item6 or 0) .. tostring(tab.item7 or 0) .. tostring(tab.item8 or 0) .. tostring(tab.item11 or 0) .. tostring(tab.item12 or 0) .. 
		-- tostring(tab.item13 or 0) .. tostring(tab.item16 or 0) .. tostring(tab.item17 or 0) .. tostring(tab.item18 or 0), tab.spawnflags)
		if IsValid(choice) then
			local startpos, endpos = choice:GetPos(), choice:GetPos()
			endpos.z = -16384
			if choice:GetModel() == "models/props/terror/ammo_stack.mdl" then --ammo collides weird with being so wide, just do line check for it
				local tr = util.TraceLine({["start"] = startpos, ["endpos"] = endpos})
				if tr.Hit then choice:SetPos(tr.HitPos) end
			else
				local tr = util.TraceEntity({["start"] = startpos, ["endpos"] = endpos}, choice)
				if tr.Hit then choice:SetPos(tr.HitPos) end
			end
		end
		return choice
	end,
	["weapon_spawn"] = function(tab)
		--oh god here we go
		local pistols = {
			["weapon_pistol"] = replacements["weapon_pistol_spawn"],
			["weapon_pistol_magnum"] = replacements["weapon_pistol_magnum_spawn"],
		}
		local smgs = {
			["weapon_smg"] = replacements["weapon_smg_spawn"],
			["weapon_smg_silenced"] = replacements["weapon_smg_silenced_spawn"],
			["weapon_smg_mp5"] = replacements["weapon_smg_mp5_spawn"],
		}
		local rifles = {
			["weapon_rifle"] = replacements["weapon_rifle_spawn"],
			["weapon_rifle_desert"] = replacements["weapon_rifle_desert_spawn"],
			["weapon_rifle_ak47"] = replacements["weapon_rifle_ak47_spawn"],
			["weapon_rifle_sg552"] = replacements["weapon_rifle_sg552_spawn"],
		}
		local sniperrifles = {
			["weapon_hunting_rifle"] = replacements["weapon_hunting_rifle_spawn"],
			["weapon_sniper_military"] = replacements["weapon_sniper_military_spawn"],
			["weapon_sniper_awp"] = replacements["weapon_sniper_awp_spawn"],
			["weapon_sniper_scout"] = replacements["weapon_sniper_scout_spawn"],
		}
		local shotst1 = {
			["weapon_pumpshotgun"] = replacements["weapon_pumpshotgun_spawn"],
			["weapon_shotgun_chrome"] = replacements["weapon_shotgun_chrome_spawn"],
		}
		local shotst2 = {
			["weapon_autoshotgun"] = replacements["weapon_autoshotgun_spawn"],
			["weapon_shotgun_spas"] = replacements["weapon_shotgun_spas_spawn"],
		}
		local weps = {
			["any_pistol"] = table.Random(pistols),
			["any_smg"] = table.Random(smgs),
			["any_rifle"] = table.Random(rifles),
			["any_sniper_rifle"] = table.Random(sniperrifles),
			["tier1_shotgun"] = table.Random(shotst1),
			["tier2_shotgun"] = table.Random(shotst2),
		}
		table.Merge(weps,pistols)
		weps.any_shotgun = math.random(2) == 1 and weps.tier1_shotgun or weps.tier2_shotgun
		local wepst1 = {}
		table.Merge(wepst1,smgs)
		table.Merge(wepst1,shotst1)
		local wepst2 = {}
		table.Merge(wepst2,rifles)
		table.Merge(wepst2,sniperrifles)
		table.Merge(wepst2,shotst2)
		weps.tier1_any = table.Random(wepst1)
		weps.tier2_any = table.Random(wepst2)
		table.Merge(weps,wepst1)
		table.Merge(weps,wepst2)
		weps.any_primary = math.random(2) == 1 and weps.tier1_any or weps.tier2_any --technically biases towards T1 stuff but *who cares*
		weps.any = table.Random(weps)
		local wep = weps[tab.weapon_selection] and weps[tab.weapon_selection](tab) or weps.any(tab)
		if bit.band(tonumber(tab.spawnflags) or 0, 16) == 0 then --Constrain to spawn position (don't drop to the ground) -except we're checking for not
			local startpos, endpos = wep:GetPos(), wep:GetPos()
			endpos.z = -16384
			local tr = util.TraceEntity({["start"] = startpos, ["endpos"] = endpos}, wep)
			if tr.Hit then wep:SetPos(tr.HitPos) end
		end
		return wep
	end,
	["upgrade_ammo_explosive"] = function(tab) return basicMdl(tab, "models/props/terror/exploding_ammo.mdl") end,
	["upgrade_ammo_incendiary"] = function(tab) return basicMdl(tab, "models/props/terror/incendiary_ammo.mdl") end,
	["upgrade_laser_sight"] = function(tab) return basicMdl(tab, "models/w_models/weapons/w_laser_sights.mdl") end,
	["upgrade_spawn"] = function(tab)
		local whatarewe = {}
		if tobool(tab.laser_sight) then table.insert(whatarewe, replacements["upgrade_laser_sight"]) end
		if tobool(tab.upgradepack_incendiary) then table.insert(whatarewe, function(tab) return basicMdl(tab, "models/w_models/weapons/w_eq_incendiary_ammopack.mdl") end) end
		if tobool(tab.upgradepack_explosive) then table.insert(whatarewe, function(tab) return basicMdl(tab, "models/w_models/weapons/w_eq_explosive_ammopack.mdl") end) end

		local upgrade = table.Random(whatarewe)(tab)
		if not IsValid(upgrade) then return nil end
		--drop to world
		local startpos, endpos = upgrade:GetPos(), upgrade:GetPos()
		endpos.z = -16384
		local tr = util.TraceLine({["start"] = startpos, ["endpos"] = endpos})
		if tr.Hit then upgrade:SetPos(tr.HitPos) end

		return upgrade
	end,
	------------------------------------TF2------------------------------------
	["item_healthkit_full"] = function(tab) return basicMdl(tab, (month == 10 and "models/props_halloween/halloween_" or "models/items/") .. "medkit_large" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["item_healthkit_medium"] = function(tab) return basicMdl(tab, (month == 10 and "models/props_halloween/halloween_" or "models/items/") .. "medkit_medium" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["item_healthkit_small"] = function(tab) return basicMdl(tab, (month == 10 and "models/props_halloween/halloween_" or "models/items/") .. "medkit_small" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["item_ammopack_full"] = function(tab) return basicMdl(tab, "models/items/ammopack_large" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["item_ammopack_medium"] = function(tab) return basicMdl(tab, "models/items/ammopack_medium" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["item_ammopack_small"] = function(tab) return basicMdl(tab, "models/items/ammopack_small" .. (month == 12 and "_bday.mdl" or ".mdl")) end,
	["tf_pumpkin_bomb"] = function(tab) return basicMdlSolid(tab, "models/props_halloween/pumpkin_explode.mdl") end,
	["tf_generic_bomb"] = function(tab) return basicMdlSolid(tab, "models/props_halloween/pumpkin_explode.mdl") end,
	["halloween_fortune_teller"] = function(tab)
		local teller = basicMdl(tab, "models/bots/merasmus/merasmas_misfortune_teller.mdl")
		if IsValid(teller) then
			teller:DrawShadow(false)
			return teller
		end
		return nil
	end,
	["team_control_point"] = function(tab)
		local prop = basicMdl(tab, "models/effects/cappoint_hologram.mdl")
		if IsValid(prop) then
			prop:SetBodygroup(0,tonumber(tab.point_default_owner) or 0)
			return prop
		end
		return nil
	end,
	["item_teamflag"] = function(tab)
		local prop = basicMdl(tab, "models/flag/briefcase.mdl","spin")
		if IsValid(prop) then
			prop:SetModel((tab.flag_model and tab.flag_model ~= "") and tab.flag_model or "models/flag/briefcase.mdl")
			local teamskin = tonumber(tab.TeamNum) or 0 --teams are 0 neutral, 1 spectator, 2 RED, 3 BLU while skins are 0 RED, 1 BLU, 2 Neutral
			if teamskin == 2 then teamskin = 0 elseif teamskin == 3 then teamskin = 1 else teamskin = 2 end
			prop:SetSkin(teamskin)
			return prop
		end
		return nil
	end,
	["tf_spell_pickup"] = function(tab)
		local prop = basicMdl(tab, "models/props_halloween/hwn_spellbook_upright.mdl")
		if IsValid(prop) then
			prop:SetModel( ( tab.powerup_model and tab.powerup_model ~= "" ) and tab.powerup_model or
			( tobool(tab.tier) and "models/props_halloween/hwn_spellbook_upright_major.mdl" or "models/props_halloween/hwn_spellbook_upright.mdl" ) )
			--todo spawn particles for the book as well?
			return prop
		end
		return nil
	end,
	["entity_spawn_point"] = function(tab,entnum,enttab) --todo manager.entity_count to limit number spawned?
		local manager = nil
		for _, v in ipairs(enttab) do
			if v.targetname == tab.spawn_manager_name then manager = v break end
		end
		if istable(manager) and replacements[manager.entity_name] then
			local prop = replacements[manager.entity_name](tab)
			if IsValid(prop) then
				if tobool(manager.random_rotation) then prop:SetAngles(Angle(0,math.Rand(0,360),0)) end
				if tobool(manager.drop_to_ground) then
					local startpos, endpos = prop:GetPos(), prop:GetPos()
					endpos.z = -16384
					local tr = util.TraceEntity({["start"] = startpos, ["endpos"] = endpos}, prop)
					if tr.Hit then prop:SetPos(tr.HitPos) end
				end
				return prop
			end
		end
		return nil
	end,
	------------------------------------TTT------------------------------------
	["weapon_ttt_beacon"] = function(tab) return basicPhys(tab, "models/props_lab/reciever01b.mdl") end,
	["ttt_beacon"] = function(tab) return basicPhys(tab, "models/props_lab/reciever01b.mdl") end,
	["weapon_ttt_binoculars"] = function(tab) return basicPhys(tab, "models/props/cs_office/paper_towels.mdl") end,
	["weapon_ttt_c4"] = function(tab) return basicPhys(tab, "models/weapons/w_c4.mdl") end,
	["weapon_ttt_confgrenade"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_fraggrenade.mdl") end,
	["ttt_confgrenade_proj"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_fraggrenade.mdl") end,
	["weapon_ttt_cse"] = function(tab) return basicPhys(tab, "models/items/battery.mdl") end,
	["ttt_cse_proj"] = function(tab) return basicPhys(tab, "models/items/battery.mdl") end,
	["weapon_ttt_decoy"] = function(tab) return basicPhys(tab, "models/props_lab/reciever01b.mdl") end,
	["ttt_decoy"] = function(tab) return basicPhys(tab, "models/props_lab/reciever01b.mdl") end,
	["weapon_ttt_defuser"] = function(tab) return basicPhys(tab, "models/weapons/w_defuser.mdl") end,
	["weapon_ttt_flaregun"] = function(tab) return basicPhys(tab, "models/weapons/w_357.mdl") end,
	["weapon_ttt_glock"] = function(tab) return basicPhys(tab, "models/weapons/w_pist_glock18.mdl") end,
	["weapon_ttt_health_station"] = function(tab) return basicPhys(tab, "models/props/cs_office/microwave.mdl") end,
	["ttt_health_station"] = function(tab) return basicPhys(tab, "models/props/cs_office/microwave.mdl") end,
	["weapon_ttt_knife"] = function(tab) return basicPhys(tab, "models/weapons/w_knife_t.mdl") end,
	["ttt_knife_proj"] = function(tab) return basicPhys(tab, "models/weapons/w_knife_t.mdl") end,
	["weapon_ttt_m16"] = function(tab) return basicPhys(tab, "models/weapons/w_rif_m4a1.mdl") end,
	["weapon_ttt_phammer"] = function(tab) return basicPhys(tab, "models/weapons/w_IRifle.mdl") end,
	["ttt_physhammer"] = function(tab) return basicPhys(tab, "models/items/combine_rifle_ammo01.mdl") end,
	["weapon_ttt_push"] = function(tab) return basicPhys(tab, "models/weapons/w_physics.mdl") end,
	["weapon_ttt_radio"] = function(tab) return basicPhys(tab, "models/props/cs_office/radio.mdl") end,
	["ttt_radio"] = function(tab) return basicPhys(tab, "models/props/cs_office/radio.mdl") end,
	["weapon_ttt_sipistol"] = function(tab) return basicPhys(tab, "models/weapons/w_pist_usp_silencer.mdl") end,
	["weapon_ttt_smokegrenade"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_smokegrenade.mdl") end,
	["ttt_smokegrenade_proj"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_smokegrenade.mdl") end,
	["weapon_ttt_stungun"] = function(tab) return basicPhys(tab, "models/weapons/w_smg_ump45.mdl") end,
	["weapon_ttt_teleport"] = function(tab) return basicPhys(tab, "models/weapons/w_slam.mdl") end,
	["weapon_ttt_unarmed"] = function(tab) return basicPhys(tab, "models/weapons/w_crowbar.mdl") end,
	["weapon_ttt_wtester"] = function(tab) return basicPhys(tab, "models/props_lab/huladoll.mdl") end,
	["weapon_zm_carry"] = function(tab) return basicPhys(tab, "models/weapons/w_stunbaton.mdl") end,
	["weapon_zm_improvised"] = function(tab) return basicPhys(tab, "models/weapons/w_crowbar.mdl") end,
	["weapon_zm_mac10"] = function(tab) return basicPhys(tab, "models/weapons/w_smg_mac10.mdl") end,
	["weapon_zm_molotov"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_flashbang.mdl") end,
	["ttt_firegrenade_proj"] = function(tab) return basicPhys(tab, "models/weapons/w_eq_flashbang.mdl") end,
	["weapon_zm_pistol"] = function(tab) return basicPhys(tab, "models/weapons/w_pist_fiveseven.mdl") end,
	["weapon_zm_revolver"] = function(tab) return basicPhys(tab, "models/weapons/w_pist_deagle.mdl") end,
	["weapon_zm_rifle"] = function(tab) return basicPhys(tab, "models/weapons/w_snip_scout.mdl") end,
	["weapon_zm_shotgun"] = function(tab) return basicPhys(tab, "models/weapons/w_shot_xm1014.mdl") end,
	["weapon_zm_sledge"] = function(tab) return basicPhys(tab, "models/weapons/w_mach_m249para.mdl") end,
	["ttt_random_weapon"] = function(tab)
		local ktab = {
			{ "weapon_ttt_glock", "item_ammo_pistol_ttt" },
			{ "weapon_ttt_m16", "item_ammo_pistol_ttt" },
			{ "weapon_ttt_smokegrenade" },
			{ "weapon_zm_mac10", "item_ammo_smg1_ttt" },
			{ "weapon_zm_molotov" },
			{ "weapon_zm_pistol", "item_ammo_pistol_ttt" },
			{ "weapon_zm_revolver", "item_ammo_revolver_ttt" },
			{ "weapon_zm_rifle", "item_ammo_357_ttt" },
			{ "weapon_zm_shotgun", "item_box_buckshot_ttt" },
			{ "weapon_zm_sledge" }
		}
		local pick = math.random(#ktab)
		local ammospawns = tonumber(tab.auto_ammo)
		if ammospawns and ammospawns > 0 and ktab[pick][2] then
			for i = 1, ammospawns do
				local ammo = replacements[ktab[pick][2]](tab)
				if IsValid(ammo) then
					local ammopos = ammo:GetPos()
					ammopos.z = ammopos.z + 3 * i
					ammo:SetPos(ammopos)
					ammo:SetAngles(VectorRand():Angle())
					ammo:PhysWake()
				end
			end
		end
		return replacements[ktab[pick][1]](tab)
	end,
	["item_ammo_357_ttt"] = function(tab) return basicEnt(tab, "item_ammo_357") end,
	["item_ammo_pistol_ttt"] = function(tab) return basicEnt(tab, "item_ammo_pistol") end,
	["item_ammo_revolver_ttt"] = function(tab)
		local ammo = basicEnt(tab, "item_ammo_357")
		if IsValid(ammo) then ammo:SetColor(Color( 255, 100, 100, 255 )) end
		return ammo
	end,
	["item_ammo_smg1_ttt"] = function(tab) return basicEnt(tab, "item_ammo_smg1") end,
	["item_box_buckshot_ttt"] = function(tab) return basicEnt(tab, "item_box_buckshot") end,
	["ttt_random_ammo"] = function(tab)
		local ktab = {
			"item_ammo_357_ttt",
			"item_ammo_pistol_ttt",
			"item_ammo_revolver_ttt",
			"item_ammo_smg1_ttt",
			"item_box_buckshot_ttt"
		}
		return replacements[ktab[math.random(#ktab)]](tab)
	end,
	------------------------------------CSS------------------------------------
	["weapon_c4"] = function(tab) return basicPhys(tab, "models/weapons/w_c4.mdl") end,
	["planted_c4"] = function(tab) return basicMdl(tab, "models/weapons/w_c4.mdl") end,
	["func_bomb_target"] = function(tab) --put a bomb in the middle of the target zone
		local bomb = ents.Create("prop_physics")
		if IsValid(bomb) then
			local pos = Vector(tab.bmodel.maxs)
			pos:Add(Vector(tab.bmodel.mins))
			pos:Mul(0.5)
			bomb:SetModel("models/weapons/w_c4.mdl")
			bomb:SetPos(pos)
			bomb:PhysicsInit(SOLID_VPHYSICS)
			bomb:Spawn()
			bomb:PhysWake()
			return bomb
		end
		return nil
	end,
	["hostage_entity"] = function(tab)
		local hostage = ents.Create("npc_citizen")
		if IsValid(hostage) then
			hostage:SetPos(Vector(tab.origin) or "0 0 0")
			hostage:SetAngles(Angle(tab.angles) or "0 0 0")
			hostage:SetKeyValue("citizentype", "4")
			hostage:SetKeyValue("spawnflags", bit.bor( SF_CITIZEN_NOT_COMMANDABLE, SF_NPC_NO_PLAYER_PUSHAWAY, SF_NPC_GAG ))
			hostage:SetModel("models/characters/hostage_0" .. tostring( #ents.FindByClass("npc_citizen") % 4 + 1 ) .. ".mdl")
			hostage:Spawn()
			return hostage
		end
		return nil
	end,
	-----------------------------------DoD:S-----------------------------------
	["dod_bomb_target"] = function(tab) return basicMdl(tab, "models/weapons/w_tnt_red.mdl") end,
	["dod_control_point"] = function(tab)
		if bit.band(tonumber(tab.flags) or 0, 2) > 0 or string.find(tab.targetname,"fake") then return nil end --Spawnflag 2 - Start with model hidden
		local flag = basicMdl(tab, "models/mapmodels/flags.mdl")
		if IsValid(flag) then
			local teams = {
				[0] = "reset",
				[2] = "allies",
				[3] = "axis",
			}
			local tm = tonumber(tab.point_default_owner) or 0
			flag:SetModel( tab["point_" .. teams[tm] .. "_model"] or "models/mapmodels/flags.mdl" )
			flag:SetBodyGroups( tab["point_" .. teams[tm] .. "_model_bodygroup"] or "0" )
		end
		return flag
	end,
	------------------------------------FoF------------------------------------
	["fof_crate"] = function(tab) return basicMdlSolid(tab, "models/items_fof/safe_crate.mdl") end,
	["fof_crate_med"] = function(tab) return basicMdlSolid(tab, "models/items_fof/safe_crate_small.mdl") end,
	["fof_crate_low"] = function(tab) return basicMdlSolid(tab, "models/items_fof/safe_crate_small.mdl") end,
	["fof_cap_entity"] = function(tab) return basicMdl(tab, "models/props/cap_circle_512.mdl") end,
	["fof_mobile_point"] = function(tab) return basicMdl(tab, "models/props/cap_circle_512.mdl") end,
	["item_whiskey"] = function(tab) return basicPhys(tab, "models/weapons/w_whiskey.mdl") end, --pass the whiskey
	["item_potion"] = function(tab) return basicPhys(tab, "models/props/potion_bottle.mdl") end,
	["npc_horse"] = function(tab) return basicMdl(tab, "models/horse/horse1.mdl", "idle1") end,
	["fof_horse"] = function(tab) return basicMdl(tab, "models/horse/riding_horse.mdl", "idle") end,
	["fof_cart_push"] = function(tab) return basicMdlSolid(tab, "models/horse/riding_horse.mdl") end,
	["fof_cannon_ball"] = function(tab) return basicPhys(tab, "models/weapons/cannon_ball.mdl") end,
	["weapon_knife"] = function(tab) return basicPhys(tab, "models/weapons/w_knife.mdl") end,
	["weapon_axe"] = function(tab) return basicPhys(tab, "models/weapons/w_axe.mdl") end,
	["weapon_machete"] = function(tab) return basicPhys(tab, "models/weapons/w_machete.mdl") end,
	["weapon_bow"] = function(tab) return basicPhys(tab, "models/weapons/w_bow.mdl") end,
	["weapon_xbow"] = function(tab) return basicPhys(tab, "models/weapons/w_xbow.mdl") end,
	["weapon_carbine"] = function(tab) return basicPhys(tab, "models/weapons/w_carbine.mdl") end,
	["weapon_coachgun"] = function(tab) return basicPhys(tab, "models/weapons/w_coachgun.mdl") end,
	["weapon_coltnavy"] = function(tab) return basicPhys(tab, "models/weapons/w_coltnavy.mdl") end,
	["weapon_volcanic"] = function(tab) return basicPhys(tab, "models/weapons/w_volcanic.mdl") end,
	["weapon_deringer"] = function(tab) return basicPhys(tab, "models/weapons/w_deringer.mdl") end,
	["weapon_dynamite"] = function(tab) return basicPhys(tab, "models/weapons/w_dynamite.mdl") end,
	["weapon_dynamite_black"] = function(tab) return basicPhys(tab, "models/weapons/w_dynamite_black.mdl") end,
	["weapon_henryrifle"] = function(tab) return basicPhys(tab, "models/weapons/w_henryrifle.mdl") end,
	["weapon_peacemaker"] = function(tab) return basicPhys(tab, "models/weapons/w_peacemaker.mdl") end,
	["weapon_maresleg"] = function(tab) return basicPhys(tab, "models/weapons/w_maresleg.mdl") end,
	["weapon_walker"] = function(tab) return basicPhys(tab, "models/weapons/w_walker.mdl") end,
	["weapon_schofield"] = function(tab) return basicPhys(tab, "models/weapons/w_schofield.mdl") end,
	["weapon_sharps"] = function(tab) return basicPhys(tab, "models/weapons/w_sharps.mdl") end,
	["weapon_sawedoff_shotgun"] = function(tab) return basicPhys(tab, "models/weapons/w_sawed_shotgun.mdl") end,
	["weapon_whiskey"] = function(tab) return basicPhys(tab, "models/weapons/w_whiskey.mdl") end,
	["weapon_bow_black"] = function(tab) return basicPhys(tab, "models/weapons/w_bow_black.mdl") end,
	["weapon_dynamite_belt"] = function(tab) return basicPhys(tab, "models/weapons/w_dynamite_yellow.mdl") end,
	["weapon_ghostgun"] = function(tab) return basicPhys(tab, "models/weapons/w_ghostgun.mdl") end,
	["weapon_hammerless"] = function(tab) return basicPhys(tab, "models/weapons/w_hammerless.mdl") end,
	["weapon_remington_army"] = function(tab) return basicPhys(tab, "models/weapons/w_remington_army.mdl") end,
	["weapon_spencer"] = function(tab) return basicPhys(tab, "models/weapons/w_spencer.mdl") end,
	["trigger_hurt_fof"] = function(tab) return basicEnt(tab, "trigger_hurt") end,
}

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
			
			-- Put in entity proxies
			local bsp = bsp2.LoadBSP( game.GetMap(), nil, { bsp3.LUMP_ENTITIES, bsp3.LUMP_BRUSHES, bsp3.LUMP_GAME_LUMP, bsp3.LUMP_MODELS } )
			if bsp ~= nil then
				task.Await(bsp:GetLoadTask())
				--PrintTable(bsp.entities or {})
				for k, v in ipairs(bsp.entities) do

					if replacements[v.classname] then
						if #ents.FindByClass(v.classname) == 0 then
							replacements[v.classname](v,k,bsp.entities)
						else
							print(v.classname.." exists! Stand-in not needed")
						end
					end

					if (v.classname == "move_rope" or v.classname == "keyframe_rope") and v.targetname then
						local ropemarker = ents.Create("jazz_static_proxy")
						if IsValid(ropemarker) then
							for key, value in pairs(v) do
								if not isstring(value) or key == "classname" or key == "targetname" then continue end
								ropemarker:SetKeyValue(key,value)
							end
							ropemarker:SetModel("models/editor/axis_helper_thick.mdl")
							ropemarker:SetPos(Vector(v.origin or "0 0 0"))
							ropemarker:SetAngles(Angle(v.angles or "0 0 0"))
							ropemarker:Spawn()
							ropemarker:Fire("AddOutput","OnSnatched ".. v.targetname .. ":Break::0:1",0,ropemarker,ropemarker)
							ropemarker.IsProxy = false
						end
					end

					--spawn markers for Roadtrips
					if string.find(v.classname,"_changelevel") then
						
						local destname = v.map or string.lower(game.GetMap())
						if string.lower(destname) == string.lower(game.GetMap()) then continue end --Seriously Valve what the fuck

						local ent = nil
						--fine Valve, use the same name for other ents
						for _, v in ipairs(ents.FindByName(v.landmark)) do
							if IsValid(v) and v:GetClass() == "info_landmark" then print(v) ent = v break end
						end
						local busmark = ents.Create("jazz_stanteleportmarker")

						if not IsValid(ent) or not IsValid(busmark) then continue end

						progress.RoadtripSetNext(game.GetMap()) --make sure this current map is on the list
						progress.RoadtripAddAllowedMap(destname)

						busmark:SetPos(ent:GetPos())
						busmark:SetAngles( Angle( 0, ent:GetAngles().y, 0 ) ) --just kidding no angles on landmarks
						busmark:SetBusMarker(true)
						busmark:SetDestinationName(destname .. ":" .. game.GetMap()) --map names can't have a colon, so we use that as a separator
						busmark:SetDestination(ent)
						busmark:SetLevel(99)
						busmark:Spawn()

					end
				end
			end
			
		end

		-- Changelevels on at least Ep1/Ep2 maps completely lock up the player, even after respawn. How fun!
		for _, v in ipairs(ents.FindByClass("trigger_changelevel")) do v:Remove() end
		for _, v in ipairs(ents.FindByClass("info_changelevel")) do v:Remove() end
		
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

--collect brush model (get its size and a texture, call it a brush for the chute)
local function CollectBModel(bmodel, ply)
	print("COLLECTED: *" .. bmodel)
	bmodel = bmodel + 1
	if table.IsEmpty(JAZZ_LOADED_BSP) then return end
	local bmdl = JAZZ_LOADED_BSP[bsp3.LUMP_MODELS][bmodel]
	if not bmdl then print("No bmodel *"..tostring(bmodel - 1).."!") return end

	local size = bmdl.maxs - bmdl.mins
	local length = size.x + size.y + size.z

	local worth = math.pow(length, 1.1) / 15.0

	local maxmaterial = "tools/toolsnodraw"

	local maxarea = -1
	for _, v in pairs(bmdl.faces) do
		if not v.texinfo then continue end
		local texinfo = v.texinfo
		local texdata = texinfo.texdata
		local mat = texdata.material

		local area = string.find(mat, "TOOLS/TOOLSNODRAW") and 0 or v.area
		if area > maxarea then
			maxarea = area
			maxmaterial = mat
		end
	end

	if not maxmaterial then
		print("Collected bmodel with no valid surface materials! (*" .. bmdl.id .. ")")
		return
	end

	maxmaterial = string.lower(maxmaterial):gsub("_[+-]?%d+_[+-]?%d+_[+-]?%d+$",""):gsub("^maps/[%w_]+/","")

	-- Collect the prop to the poop chute
	if worth and worth > 0 then --TODO: Check if worth > 1 not 0
		worth = worth * newgame.GetMultiplier()
		if not IsValid(ply) then return end

		local newCount = snatch.AddProp(ply, maxmaterial, worth, "brush")
		propfeed.notify_brush( maxmaterial, ply, worth )
		--propfeed.notify( prop, ply, newCount, worth)
	end
end

local function matstripstr(str)
	if not str or str == "" then return "models/weapons/w_smg1/smg_crosshair" end
	local tab = string.Explode("/",string.StripExtension(str))
	table.RemoveByValue(tab,"materials")
	return table.concat(tab,"/")
end

--convert entities into sprites
local conversions = {
	["env_sun"] = "sprites/light_glow02_add_noz",
	["env_fire"] = "sprites/fire1",
	["env_sprite"] = function(ent) return matstripstr(ent:GetModel()) end,
	["point_spotlight"] = "sprites/glow_test02",
	["env_beam"] = function(ent)
		local kvs = ent:GetKeyValues()
		local mat = kvs and kvs["material"] or nil
		return matstripstr(mat)
	end,
	["env_spark"] = "editor/env_spark",
}
conversions["env_laser"] = conversions["env_beam"]

local function CollectEntity(ent, ply)

	if not IsValid(ent) then return end

	local material = isfunction(conversions[ent:GetClass()]) and conversions[ent:GetClass()](ent) or conversions[ent:GetClass()]
	--todotodo: worth and such!
	local worth = 10
	-- Collect the prop to the poop chute
	if worth and worth > 0 then --TODO: Check if worth > 1 not 0
		worth = worth * newgame.GetMultiplier()
		propfeed.notify_entity( material, ply, worth )

		-- Also maybe collect the prop for player missions
		--for _, v in pairs(player.GetAll()) do
		--	missions.AddMissionProp(v, material)
		--end
	end
end

-- Called when prop is snatched from the level
function GM:CollectProp(prop, ply)

	--todo: probably better to eventually move this up to where CollectProp is called. oh well
	local modelname = tostring( prop and prop:GetModel() or prop:GetClass()) --"<entity>") --easier to see what's breaking
	local bmodel = string.match( modelname, "^%*(%d+)")
	if bmodel then CollectBModel( tonumber(bmodel), ply) return end
	
	if conversions[prop:GetClass()] then CollectEntity( prop, ply) return end

	print("COLLECTED: " .. modelname)
	local worth = mapgen.CollectProp(ply, prop)

	if prop.TriggerOutput then
		prop:TriggerOutput("OnSnatched", ply)
	end

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
	return string.lower(displacement.face.texinfo.texdata.material):gsub("_[+-]?%d+_[+-]?%d+_[+-]?%d+$",""):gsub("^maps/[%w_]+/","")
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

-- no fall damage with Run
function GM:GetFallDamage(ply, speed)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "weapon_run" then
		if not wep:ShouldTakeFallDamage() then return 0 end
	end

	return self.BaseClass.GetFallDamage(self, ply, speed)
end

function GM:EntityTakeDamage( target, dmginfo )
	local attacker = dmginfo:GetAttacker()
	if IsValid(target) and target:IsPlayer() and IsValid(attacker) then
		local wep = target:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_run" then
			--physics shield
			if bit.band(dmginfo:GetDamageType(),bit.bor(DMG_CLUB,DMG_SLASH,DMG_CRUSH)) > 0 and not attacker:IsNPC() then
				local scale = wep:PhysDmgScale() or 1
				local olddmg = dmginfo:GetDamage()
				dmginfo:ScaleDamage( scale )
				if scale < 1 then
					if dmginfo:GetDamage() <= (wep:PhysDmgLevel() or 0) then dmginfo:SetDamage(0) end --completely block damage if it's less than [level]
					local volumeadjust = math.max(15,math.min(100,olddmg - dmginfo:GetDamage())) / 100 --get a number between 0.15 and 1 depending on our damage blocked
					target:EmitSound("weapons/physcannon/energy_bounce1.wav",100,125 - scale * 100 + math.Rand(-10,10),volumeadjust)
					--print("Bdoosh",volumeadjust)
				end
			--radsuit
			else
				local ogdamage = dmginfo:GetDamage()
				--the idea with the math here is to greatly mitigate incidential damage, while still letting stuff that's meant to instantly kill *probably* do so.
				if ogdamage > 0 and (attacker:GetClass() == "trigger_hurt" or attacker:GetClass() == "trigger_waterydeath") then
					local maxdamage = 10 - (wep:TriggerHurtLevel() or 0)
					--take our chance to completely block the damage
					if math.random() > (wep:TriggerHurtScale() or 0) + math.max(0, ogdamage/1000 * (maxdamage / 10)) then
						dmginfo:SetDamage(0)
					--damage got through, but, let's try to limit it
					elseif ogdamage <= math.pow(2,11 - maxdamage) and ogdamage > maxdamage and tobool(wep:TriggerHurtLevel()) then
						dmginfo:SetDamage(maxdamage)
					end
				end
			end
		end
	end

	return self.BaseClass.EntityTakeDamage(target,dmginfo)
end


local madlibs = {}
madlibs[1] = {
	"Bartender", "Cellist", "Singer", "Pianist", "The Gang", "The Player", "Garry", "A mingebag", "Nobody", "Everybody", "info_player_start", "An average housecat", 
	"A dev", "Sun", "Foohy", "Kaz", "Matt", "Ptown", "Sierra", "C", "Gordon", "Freeman", "Somebody", "Gabe", "Everyone", "No one", "The World", "A fan",
	"The Bartender", "The Cellist", "The Singer", "The Pianist", "Rubat", "Rob", "Rungo", "Georff", "Podge", "Your computer", "My computer"
}
madlibs[2] = {
	" loves", " ate", " smoked", " snatched", " saw", " shot", " blew up", " smells", "'s blinded", " cataloged", " stole", " programmed", " drew", " lost", " made",
	" modeled", " mapped", " found", " chased", " tackled", " crowbarred", " swung at", " lifted", " altered", " remembered", " forgot", " summoned", " won", " posed",
	" dissolved", " threw", " plundered", " bought", " sold", " believes in", " installed", " needs", " refactored", " shattered", " broke", " gibbed", " dumped",
	" dance fought", " drove", " crashed", " sunk", " defenestrated", " heard", " equipped", " cursed", " fell on", " fell off", " once told", " foretold", " slayed",
	" stunned", " shrunk", " left", " is out with", " is out without", "'s gonna roll", " doesn't care for", " accepted", " rejected", " punted", " silenced",
	" muted", " blocked", " went under", " went over", " went through", " skipped", " shredded", " grabbed", " thanked", " spawned", " opened", " destroyed",
	" pwned", " froze", " stalled", " played"
}
madlibs[3] = {
	" Jazztronauts", " the Bar", " crack", " you", " a watermelon", " a crate", " God", " Source", " Garry's Mod", " GMod", " me", " my heart", " the players",
	" a prop snatcher", " Stan", " Hacker Goggles", " some NPCs", " cats", " smooth jazz", " a crowbar", " a gun", " the trolley", " a headcrab", " the mind",
	" a Vortigaunt", " capitalism", " Counter-Strike: Source", " ur mom lol", " GMan", " somebody", " a car", " a radio", " a cactus", " a creepy doll", " a jeep",
	" a horse statue", " an antlion", " a thruster", " a hoverball", " the Void", " Void skeletons", " it", " Alyx", " Steam", " Valve", " 9 out of 10 players",
	" at the top of lung", " all night long", " really badly", " quite well", " too well", " somebody to love", " a ghost", " a possum", " a bee", " a tumblr sexyman",
	" the Gravity Gun", " the Physgun", " the Tool Gun", " the spawn menu", " the server", " something", " nothing", " aliens", " monsters", " Kleiners",
	" computers", " Que Chevere", " the piano", " the cello", " the microphone", " the saxophone"
}
madlibs[4] = {
	".", "!", "?", "?!", "!!", "...", "!!!"
}

local function generatephrase(time)
	local phrase = ""
	
	local seed = bit.tobit(util.SharedRandom("Jazztronauts!!",-2147483648,2147483647,time)) --32 bits
	for k, v in ipairs(madlibs) do
		phrase = phrase .. v[bit.rshift(seed,k * 7) % #v + 1] 
	end
	return string.Trim(phrase)
end

concommand.Add("jazz_debug_madlibs", function(ply, cmd, args)
	local count = tonumber(args[1]) and tonumber(args[1]) or 1
	for i = 1, count do
		print(generatephrase(math.Rand(-2147483648,2147483647)))
	end
end, nil, "Generate a mad libs pass phrases. Specify a number for multiple.")

local acknowledge = generatephrase(CurTime())

concommand.Add("jazz_reset_progress", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	local phrase = table.concat(args, " ")
	if phrase != acknowledge or phrase == "" then
		acknowledge = generatephrase(CurTime())
		local failInfo = "Are you sure you want to reset progress? This command cannot be undone."
		.. "\nRe-run this command with the argument \"" .. acknowledge .. "\" to acknowledge."
		if IsValid(ply) then
			ply:ChatPrint(failInfo)
		else
			print(failInfo)
		end
		return
	end

	acknowledge = generatephrase(CurTime())
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
