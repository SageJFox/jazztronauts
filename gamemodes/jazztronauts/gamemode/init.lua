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
		prop:Spawn()
		timer.Simple( 0, function() if IsValid(prop) then prop:ResetSequenceInfo() prop:ResetSequence( anim ) end end )
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
		return prop
	end
	return nil
end

--spawn three dismount points, in a 270 degree arc in front of the given ladder point
local threefront = function(normal,ladderEndPoint,ladderName)
	local dismount = { ents.Create("info_ladder_dismount"), ents.Create("info_ladder_dismount"), ents.Create("info_ladder_dismount") }
	local tr = {}
	local normal = Vector(normal)
	if not isvector(ladderEndPoint) then return { nil }, { nil } end
	for i = 1, 3 do
		
		local dismountPos = Vector( ladderEndPoint.x + normal.x * 33,  ladderEndPoint.y + normal.y * 33, ladderEndPoint.z - 16 )
		local dismountTry = Vector(dismountPos)
		dismountTry.z = dismountTry.z + 48
		tr[i] = util.TraceHull( {
			["mins"] = Vector( -17, -17, 0 ),
			["maxs"] = Vector( 17, 17, 37 ),
			["mask"] = MASK_PLAYERSOLID_BRUSHONLY,
			["start"] = dismountTry,
			["endpos"] = dismountPos
		} )
		--PrintTable(tr[i])
		if IsValid(dismount[i]) then
			if not tr[i].StartSolid then --todo: test if needed
				dismountPos.z = dismountTry.z - ( 48 * tr[i].Fraction )
			end
			dismount[i]:SetPos(dismountPos)
			if ladderName then dismount[i]:SetKeyValue("target",ladderName) end
			dismount[i]:Spawn()
			--if it's stuck in a solid, remove it
			if tr[i].AllSolid then
				dismount[i]:Remove()
			end
		end

		normal:Rotate(Angle(0,90 * i,0)) --will rotate 90 after the first, then 180

	end
	return dismount, tr
end

replacements = {
	-----------------------------------L4D/2-----------------------------------
	["func_simpleladder"] = function(tab,entnum)
		
		if not istable(tab.bmodel) then print("func_simpleladder with no brush model! BSP corrupted?") return nil end
		--get the origin of the ladder brush
		local origin = Vector(tab.bmodel.maxs)
		origin:Add(Vector(tab.bmodel.mins))
		origin:Mul(0.5)

		if tonumber(tab["normal.z"]) < 1 then
			--we can only handle straight up and down ladders for now, so, apologize for that
			if tonumber(tab["normal.z"]) ~= 0 then
				MsgC(Color(224,186,0),"BSP entity #"..tostring(entnum)..": slanted ladder!\n")
				local message = ents.Create("point_message")
				if IsValid(message) then
					message:SetKeyValue("developeronly","0")
					message:SetKeyValue("message","(#"..tostring(entnum)..") Sorry, slanted ladders aren't supported yet!")
					message:SetKeyValue("radius","160")
					message:SetPos(origin)
					message:Spawn()
					message:Activate()
				end
				return message
			end

			--grab the reach of the ladder brush, as well as its normal
			--we'll use these to figure out where the front of the ladder is.
			local reach = Vector(tab.bmodel.maxs)
			reach:Add(-Vector(tab.bmodel.mins))
			reach:Mul(0.5)
			
			local normal = Vector(tab["normal.x"],tab["normal.y"],tab["normal.z"])
			normal:Normalize()

			--we're spawning a useableladder, which is gonna have to exist in the space in front of this
			local ladp0 = Vector(origin)

			--move the ladder outside of any geometry it's intersecting, in the direction of its normal
			local scoot = util.TraceHull( { ["mins"] = Vector( -17, -17, 0 ), ["maxs"] = Vector( 17, 17, 73 ), ["mask"] = MASK_PLAYERSOLID_BRUSHONLY,
				["start"] = ladp0 + (normal * 28), ["endpos"] = ladp0 } ) --24 is just a hair under the max length the hull would need to clear the origin at 45 degrees, so give it about an extra 4
			ladp0.x = scoot.HitPos.x
			ladp0.y = scoot.HitPos.y
			ladp0.z = math.ceil( origin.z + reach.z )

			--make sure we don't get stuck in the world above/below the ladder (displacements, mostly)
			local tr = util.TraceHull( { ["mins"] = Vector( -17, -17, 0 ), ["maxs"] = Vector( 17, 17, 73 ), ["mask"] = MASK_PLAYERSOLID_BRUSHONLY,
				["start"] = ladp0, ["endpos"] = Vector( ladp0.x, ladp0.y, origin.z - reach.z - 16 ) } )
			if tr.StartSolid then ladp0.z = ladp0.z - ( reach.z * 2 * tr.FractionLeftSolid ) end
			local ladp1 = Vector(tr.HitPos)
			ladp1.z = math.ceil(ladp1.z)

			--if the whole trace was solid or the ladder is gonna be shorter than regular step-height, don't bother
			if not tr.AllSolid and math.abs( ladp0.z - ladp1.z ) >= 18 then
				local ladder = ents.Create("func_useableladder")
				if IsValid(ladder) then
					ladder:SetKeyValue("point0",tostring(ladp0))
					ladder:SetKeyValue("point1",tostring(ladp1))
					ladder:SetPos(origin)
					ladder:SetName("jazz_added_ladder_"..tostring(entnum))
					ladder:Spawn()

					--ladder dismount points
					--not strictly necessary but make nagivating the ladder much easier

					--top one. This one's important as we use it as a sorta "probe" for if an infected-only ladder is worth keeping
					--(L4D uses playerclip as survivor-only, while in GMod it's all players, so if the top is clipped off the player can't do anything with it anyway)
					local laddertop = ents.Create("info_ladder_dismount")
					local laddertoppos = Vector( origin.x - normal.x * (reach.x + 17),  origin.y - normal.y * (reach.y + 17), ladp0.z + 1 )
					local laddertoptry = Vector(laddertoppos)
					laddertoptry.z = laddertoptry.z + 48
					local tr2 = util.TraceHull( { ["mins"] = Vector( -17, -17, 0 ), ["maxs"] = Vector( 17, 17, 37 ), ["mask"] = MASK_PLAYERSOLID_BRUSHONLY,
						["start"] = laddertoptry, ["endpos"] = laddertoppos } )
					--PrintTable(tr2)
					if IsValid(laddertop) then
						if not tr2.StartSolid then laddertoppos.z = laddertoptry.z - ( 48 * tr2.Fraction ) end
						laddertop:SetPos(laddertoppos)
						laddertop:SetKeyValue("target",ladder:GetName())
						laddertop:Spawn()
						if tr2.AllSolid then
							laddertop:Remove()
						end
					end

					--others on top
					local laddertop3, laddertoptr = threefront( normal, ladp0, ladder:GetName() )
					--if it's floating, remove it
					for k, v in ipairs(laddertop3) do
						if IsValid(v) and istable(laddertoptr[k]) and not laddertoptr[k].Hit then
							v:Remove()
						end
					end

					--bottom ones
					local ladderbot = threefront( normal, ladp1, ladder:GetName() )
					-- if it's more than a quarter of the way up the ladder, remove it
					for _, v in ipairs(ladderbot) do
						if IsValid(v) and math.abs(v:GetPos().z - ladp1.z) * 4 > math.abs(ladp0.z - ladp1.z) then
							v:Remove()
						end
					end


					ladder:Activate()
					--infected-only ladders
					if tonumber(tab.team) == 2 then
						if tr2.AllSolid then --if top was blocked, it probably goes nowhere, just remove it
							ladder:Remove()
							return nil
						else --add visualizers
							local visual = ents.Create("func_illusionary")
							if IsValid(visual) then
								visual:SetModel(tab.model)
								visual:Spawn()
							end
						end
					end
					return ladder
				end
			else
				local message = ents.Create("point_message")
				if IsValid(message) then
					message:SetKeyValue("developeronly","0")
					message:SetKeyValue("message","Ladder (#"..tostring(entnum)..") blocked!")
					message:SetKeyValue("radius","160")
					message:SetPos(origin)
					message:Spawn()
					message:Activate()
				end
				return message
			end
		else
			MsgC(Color(255,0,0),"BSP entity #"..tostring(entnum)..": bad ladder normals!\n")
			local message = ents.Create("point_message")
			if IsValid(message) then
				message:SetKeyValue("developeronly","0")
				message:SetKeyValue("message","Sorry, this ladder (#"..tostring(entnum)..") had bad data in the BSP!")
				message:SetKeyValue("radius","160")
				message:SetPos(origin)
				message:Spawn()
				message:Activate()
				return message
			end
		end
		return nil
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
			["knife"] = "models/weapons/melee/w_knife_t.mdl",
			["machete"] = "models/weapons/melee/w_machete.mdl",
			["pitchfork"] = "models/weapons/melee/w_pitchfork.mdl",
			["shovel"] = "models/weapons/melee/w_shovel.mdl",
			["tonfa"] = "models/weapons/melee/w_tonfa.mdl",
		}
		models.Any = table.Random(models)
		local wep = table.Random(string.Split(tab.melee_weapon,","))
		return basicPhys( tab, models[wep] or models.Any )
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
	["info_survivor_position"] = function(tab)
		local spawn = ents.Create("info_player_start")
		if IsValid(spawn) then
			spawn:SetPos(Vector(tab.origin or "0 0 0"))
			spawn:SetAngles(Angle(tab.angles or "0 0 0"))
			if tab.targetname and tab.targetname ~= "" then spawn:SetName(tab.targetname) end
			spawn:Spawn() --ha
			return spawn
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
				timer.Simple(1,function() if IsValid(phy) then phy:EnableMotion(true) end end) --todo: maybe check if it was intentionally motion disabled (flag #8)
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
	["prop_minigun"] = function(tab) return basicMdl(tab, "models/w_models/weapons/w_minigun.mdl") end,
	["prop_minigun_l4d1"] = function(tab) return basicMdl(tab, "models/w_models/weapons/w_minigun.mdl") end,
	["prop_mounted_machine_gun"] = function(tab) return basicMdl(tab, "models/w_models/weapons/50cal.mdl") end,
	["weapon_pistol_spawn"] = function(tab) return basicPhys(tab, IsMounted(550) and "models/w_models/weapons/w_pistol_a.mdl" or "models/w_models/weapons/w_pistol_1911.mdl") end,
	["weapon_pistol_magnum_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_desert_eagle.mdl") end,
	["weapon_smg_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_smg_uzi.mdl") end,
	["weapon_smg_silenced_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_smg_a.mdl") end,
	["weapon_smg_mp5_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_smg_mp5.mdl") end,
	["weapon_rifle_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_rifle_m16a2.mdl") end,
	["weapon_rifle_ak47_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_rifle_ak47.mdl") end,
	["weapon_rifle_desert_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_desert_rifle.mdl") end,
	["weapon_rifle_m60_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_m60.mdl") end,
	["weapon_rifle_sg552_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_rifle_sg552.mdl") end,
	["weapon_hunting_rifle_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_sniper_mini14.mdl") end,
	["weapon_sniper_military_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_sniper_military.mdl") end,
	["weapon_sniper_awp_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_sniper_awp.mdl") end,
	["weapon_sniper_scout_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_sniper_scout.mdl") end,
	["weapon_pumpshotgun_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_shotgun.mdl") end,
	["weapon_shotgun_chrome_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_pumpshotgun_a.mdl") end,
	["weapon_autoshotgun_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_autoshot_m4super.mdl") end,
	["weapon_shotgun_spas_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_shotgun_spas.mdl") end,
	["weapon_grenade_launcher_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_grenade_launcher.mdl") end,
	["weapon_pipe_bomb_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_pipebomb.mdl") end,
	["weapon_molotov_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_molotov.mdl") end,
	["weapon_vomitjar_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_bile_flask.mdl") end,
	["weapon_pain_pills_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_painpills.mdl") end,
	["weapon_adrenaline_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_adrenaline.mdl") end,
	["weapon_first_aid_kit_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_medkit.mdl") end,
	["weapon_defibrillator_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_defibrillator.mdl") end,
	["weapon_upgradepack_explosive_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_explosive_ammopack.mdl") end,
	["weapon_upgradepack_incendiary_spawn"] = function(tab) return basicPhys(tab, "models/w_models/weapons/w_eq_incendiary_ammopack.mdl") end,
	["weapon_gascan_spawn"] = function(tab) return basicPhys(tab, "models/props_junk/gascan001a.mdl") end,
	------------------------------------TF2------------------------------------
	["item_healthkit_full"] = function(tab) return basicMdl(tab, "models/items/medkit_large.mdl") end, --todo birthday mode/halloween versions when appropriate
	["item_healthkit_medium"] = function(tab) return basicMdl(tab, "models/items/medkit_medium.mdl") end,
	["item_healthkit_small"] = function(tab) return basicMdl(tab, "models/items/medkit_small.mdl") end,
	["item_ammopack_full"] = function(tab) return basicMdl(tab, "models/items/ammopack_large.mdl") end,
	["item_ammopack_medium"] = function(tab) return basicMdl(tab, "models/items/ammopack_medium.mdl") end,
	["item_ammopack_small"] = function(tab) return basicMdl(tab, "models/items/ammopack_small.mdl") end,
	["tf_pumpkin_bomb"] = function(tab) return basicMdl(tab, "models/props_halloween/pumpkin_explode.mdl") end,
	["tf_generic_bomb"] = function(tab) return basicMdl(tab, "models/props_halloween/pumpkin_explode.mdl") end,
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
		if istable(manager) then
			if replacements[manager.entity_name] then
				local prop = replacements[manager.entity_name](tab)
				if IsValid(prop) then
					if tobool(manager.random_rotation) then prop:SetAngles(Angle(0,math.Rand(0,360),0)) end
					if tobool(manager.drop_to_ground) then
						local startpos, endpos = prop:GetPos(), prop:GetPos()
						endpos.z = -16384
						local tr = util.TraceLine({["start"] = startpos, ["endpos"] = endpos})
						if tr.Hit then prop:SetPos(tr.HitPos) end
					end
					return prop
				end
			end
		end
		return nil
	end,
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
				local ladorig = #ents.FindByClass("func_useableladder")
				--PrintTable(bsp.entities or {})
				for k, v in ipairs(bsp.entities) do
					if replacements[v.classname] then
						if #ents.FindByClass(v.classname) == 0 then
							replacements[v.classname](v,k,bsp.entities)
						else
							print(v.classname.." exists! Stand-in not needed")
						end
					end
					--if v.classname == "func_simpleladder" then print(k) PrintTable(v) end
				end

				timer.Simple(0,function()
					MsgC(Color(0,255,0),"Ladders created: "..tostring(#ents.FindByClass("func_useableladder") - ladorig).."\n")
				end)

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
