AddCSLuaFile()

if SERVER then
	local function validSpawnEntity(ent)
		return IsValid(ent) and (ent.Alive and ent:Alive() or true)
	end

	local function getSpawnEntity(ply)
		local obstarget = ply:GetObserverTarget()

		if validSpawnEntity(obstarget) then
			return obstarget
		end
	end

	function GM:GetDefaultSpawn(ply)
		--return self.BaseClass.PlayerSelectSpawn(self, ply)

		if ( self.TeamBased ) then

			local ent = self:PlayerSelectTeamSpawn( ply:Team(), ply )
			if ( IsValid( ent ) ) then return ent end

		end

		-- Save information about all of the spawn points
		-- in a team based game you'd split up the spawns
		if ( !IsTableOfEntitiesValid( self.SpawnPoints ) ) then

			self.LastSpawnPoint = 0
			self.SpawnPoints = ents.FindByClass( "info_player_start" )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_deathmatch" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_combine" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_rebel" ) )

			-- CS Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_counterterrorist" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_terrorist" ) )

			-- DOD Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_axis" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_allies" ) )

			-- (Old) GMod Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "gmod_player_start" ) )

			-- TF Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_teamspawn" ) )

			-- INS Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "ins_spawnpoint" ) )

			-- AOC Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "aoc_spawnpoint" ) )

			-- Dystopia Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "dys_spawn_point" ) )

			-- PVKII Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_pirate" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_viking" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_knight" ) )

			-- DIPRIP Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "diprip_start_team_blue" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "diprip_start_team_red" ) )

			-- OB Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_red" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_blue" ) )

			-- SYN Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_coop" ) )

			-- ZPS Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_human" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_zombie" ) )

			-- ZM Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_zombiemaster" ) )

			-- FOF Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_fof" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_desperado" ) )
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_vigilante" ) )

			-- L4D Maps
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_survivor_rescue" ) )
			-- Removing this one for the time being, c1m4_atrium has one of these in a box under the map --undone, why would you remove it for that dumb of a reason
			self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_survivor_position" ) )

		end

		local Count = table.Count( self.SpawnPoints )

		if ( Count == 0 ) then
			Msg("[PlayerSelectSpawn] Error! No spawn points!\n")
			return nil
		end

		-- If any of the spawnpoints have a MASTER flag then only use that one.
		-- This is needed for single player maps.
		for k, v in pairs( self.SpawnPoints ) do
			--we're not singleplayer, only do it if we've got one player
			if (game.MaxPlayers() == 1 or player.GetCount() <= 1) and ( v:HasSpawnFlags( 1 ) && hook.Call( "IsSpawnpointSuitable", GAMEMODE, ply, v, true ) ) then
				return v
			end

		end

		local ChosenSpawnPoint = nil

		-- Try to work out the best, random spawnpoint --Todo: could this let us spawn players at the actual spawn they're looking at?
		for i = 1, Count do

			ChosenSpawnPoint = table.Random( self.SpawnPoints )

			if ( IsValid( ChosenSpawnPoint ) && ChosenSpawnPoint:IsInWorld() ) then
				if ( ( ChosenSpawnPoint == ply:GetVar( "LastSpawnpoint" ) || ChosenSpawnPoint == self.LastSpawnPoint ) && Count > 1 ) then continue end

				if ( hook.Call( "IsSpawnpointSuitable", GAMEMODE, ply, ChosenSpawnPoint, i == Count ) ) then

					self.LastSpawnPoint = ChosenSpawnPoint
					ply:SetVar( "LastSpawnpoint", ChosenSpawnPoint )
					return ChosenSpawnPoint

				end

			end

		end

		return ChosenSpawnPoint

	end

	-- Allow spawning on players if they're hovered over someone that's alive
	function GM:PlayerSelectSpawn(ply)
		local target = getSpawnEntity(ply)

		if not IsValid(target) or target == ply then
			target = self:GetDefaultSpawn(ply)
		end

		ply.JazzSpawnEntity = target

		return target
	end

	hook.Add("PlayerSpawn", "JazzPlayerSpawnLogic", function(ply)
		-- If they spawn on the trolley specifically, automatically just put them in a seat
		local ent = ply.JazzSpawnEntity
		if not IsValid(ent) then return end

		if ent:GetClass() == "jazz_stanteleportmarker" and IsValid(ent:GetParent()) then
			ent = ent:GetParent()
		end

		-- If they spawned on the bus, or spawned on a player sitting in a bus, spawn on the bus
		local bus = ent:GetClass() == "jazz_bus" and ent or nil
		if not IsValid(bus) then
			local parent = ent:IsPlayer() and IsValid(ent:GetVehicle()) and ent:GetVehicle():GetParent()
			bus = IsValid(parent) and parent:GetClass() == "jazz_bus" and parent or nil
		end

		-- Sit em' down
		if IsValid(bus) then
			bus:SitPlayer(ply)
			return
		end

		-- Activate anti-stuck code when PvP is on since players are allowed to collide
		-- Prob doesn't need to be a hook, but makes sense keeping it with the other collision stuff
		if cvars.Bool("jazz_pvp") then
			hook.Run("JazzPlayerOnPlayer", ply, ent)
		end
	end )

	-- Get a list of all non-player spawn points (including the trolley/default map)
	local function getNonPlayerSpawns(ply)
		local spawns = {
			ply -- Signifies default map spawn
		}
		for _, v in ipairs(ents.FindByClass("jazz_bus")) do
			if not IsValid(v) or v:GetHubBus() then continue end
			if IsValid(v.TeleportLockOn) then
				table.insert(spawns,v.TeleportLockOn)
			else
				table.insert(spawns,v)
			end
		end
		--table.Add(spawns, ents.FindByClass("jazz_bus"))

		return spawns
	end

	-- Get a list of all available spawnpoints
	local function getAvailableSpawns(ply)
		local spawns = getNonPlayerSpawns(ply)

		local players = player.GetAll()
		for _, v in pairs(players) do
			if IsValid(v) and v:Alive() then table.insert(spawns, v) end
		end

		return spawns
	end

	-- Given the current target, retrieve the next spectate target
	local function getNextSpawn(ply, curtarget)
		local spawns = getAvailableSpawns(ply)
		if #spawns == 0 then return nil end

		local i = table.KeyFromValue(spawns, curtarget) or 1
		i = (i % #spawns) + 1

		return spawns[i]
	end

	function GM:PlayerDeathThink(ply)

		local wantsSpawn = ply:KeyPressed( IN_ATTACK ) || ply:KeyPressed( IN_JUMP )
		local inSpectate = ply:GetObserverMode() != OBS_MODE_NONE

		-- Switch observing player if they click the button or they're not spectating yet
		if ply:KeyPressed(IN_ATTACK2) or (wantsSpawn and not inSpectate) then
			local curtarget = getSpawnEntity(ply)
			local nexttarget = getNextSpawn(ply, curtarget)

			-- If the next target is invalid or there's only one spawnpoint, then just immediately spawn on that
			-- no need to preview it
			if IsValid(nexttarget) and (inSpectate or #getAvailableSpawns(ply) > 1) then

				-- Setup spectate on the next target
				if IsValid(nexttarget) then
					ply:Spectate(OBS_MODE_CHASE)
					ply:SpectateEntity(nexttarget)

					-- If the next target is _ourselves_, we treat it as a default map spawn
					if nexttarget == ply then
						local spawnpoint = self:GetDefaultSpawn(ply)
						if IsValid(spawnpoint) then
							ply:SetPos(spawnpoint:GetPos())
						end
					end
				end

				return
			end

		end

		if ply.NextSpawnTime && ply.NextSpawnTime > CurTime() then return end

		-- Respawn on time's up
		if ply:IsBot() or wantsSpawn then
			ply:Spawn()
		end

	end

	function GM:SetupPlayerVisibility(ply, viewEntity)
		if ply:GetObserverMode() == OBS_MODE_NONE then return end

		local curtarget = getSpawnEntity(ply)
		if IsValid(curtarget) then
			AddOriginToPVS(curtarget:GetPos())
		end
	end

end

-- Draw spectate stuff
if CLIENT then
	local function GetSpectateName(ent)
		if ent == LocalPlayer() then return jazzloc.Localize("jazz.respawn.playerstart") end
		if ent:IsPlayer() then return ent:GetName() end

		local class = ent:GetClass()
		if class == "jazz_stanteleportmarker" then class = "jazz_bus" end
		return jazzloc.Localize(class)
	end

	hook.Add("HUDPaint", "JazzDrawSpectate", function()
		if LocalPlayer():GetObserverMode() == OBS_MODE_NONE then return end
		local obstarget = LocalPlayer():GetObserverTarget()
		if not IsValid(obstarget) then return end
		local name = GetSpectateName(obstarget)
		local hintText = jazzloc.Localize("jazz.respawn.switch",jazzloc.Localize(input.LookupBinding("+attack2")))

		surface.SetFont("DermaDefault")
		local wn, hn = surface.GetTextSize(name)
		local wh, hh = surface.GetTextSize(hintText)
		local w, h = math.max(wn, wh) * 1.3, math.max(hn, hh) * 1.3

		local x, y = ScrW()/2, ScrH()/2 + ScreenScale(55)
		surface.SetTextColor(255, 255, 255, 255)
		draw.RoundedBox(5, x - w/2, y - h/2, w, h * 2, Color(0, 0, 0, 150))

		surface.SetTextPos(x - wn/2, y - hn / 2)
		surface.DrawText(name)

		surface.SetTextPos(x - wh / 2, y + h - hh / 2)
		surface.DrawText(hintText)
	end)
end
