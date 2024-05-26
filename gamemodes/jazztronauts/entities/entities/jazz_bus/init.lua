AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("default.lua")

include("shared.lua")

local trolleyScript = CreateConVar("jazz_trolley", "default", FCVAR_ARCHIVE, "Alternate styles for the trolley can be created with a lua script, loaded here. Will take effect next map load.\n" ..
"Don't mess with this unless you know what you're doing.")

local _, _, setup = string.find( trolleyScript:GetString(), "(%S*)%.?l?L?u?U?a?A?$" ) --let .lua be optional
if setup then
	setup = setup .. ".lua"
else
	ErrorNoHalt("File defined in jazz_trolley not found! Using default.lua")
	setup = "default.lua"
end
if file.Exists(setup,"THIRDPARTY") or file.Exists(setup,"LUA") or file.Exists("gamemodes/jazztronauts/entities/entities/jazz_bus/"..setup,"THIRDPARTY") then
	AddCSLuaFile(setup)
	include(setup)
else
	ErrorNoHalt("File defined in jazz_trolley not found! Using default.lua\n")
	include("default.lua")
end

ENT.ShadowControl = {}
ENT.ShadowControl.secondstoarrive  = 0.0000001
ENT.ShadowControl.pos			  = Vector(0, 0, 0)
ENT.ShadowControl.angle			= Angle(0, 0, 0)
ENT.ShadowControl.maxspeed		 = 1000000000000
ENT.ShadowControl.maxangular	   = 1000000
ENT.ShadowControl.maxspeeddamp	 = 10000
ENT.ShadowControl.maxangulardamp   = 1000000
ENT.ShadowControl.dampfactor	   = 1
ENT.ShadowControl.teleportdistance = 10
ENT.ShadowControl.deltatime		= 0
ENT.SpectateCamOffset			= Vector(0, 0, 64)

-- Different movement states the bus can be in
-- Wink wink nudge nudge zak's state machine library
local MOVE_STATIONARY	= 1
local MOVE_ARRIVING	= 2
local MOVE_LEAVING		= 3
local MOVE_LEAVING_PORTAL = 4

ENT.BusLeaveDelay = 1
ENT.BusLeaveAccel = 500

local noMoveEntsConVar = CreateConVar("jazz_bus_nomove", "0")

ENT.PrelimSounds =
{
	{ snd = "ambient/machines/wall_move1.wav", delay = 2.8 },
	{ snd = "ambient/machines/wall_move4.wav", delay = 2.8},
	{ snd = "ambient/machines/thumper_startup1.wav", delay = 2.8},
	{ snd = "jazztronauts/trolley/jazz_trolley_bell.wav", delay = 1.0}
}

ENT.BrakeSounds =
{
	"jazztronauts/trolley/brake_1.wav",
	"jazztronauts/trolley/brake_2.wav",
}

ENT.CrashSound = { "vehicles/v8/vehicle_impact_heavy1.wav", 90, 150 }
ENT.SkidSound = { "vehicles/v8/skid_normalfriction.wav", 90, 110 }
ENT.EngineOffSound = { "vehicles/v8/v8_stop1.wav", 90, 110 }
ENT.DingSound = { "jazztronauts/trolley/jazz_trolley_bell.wav", 90, 110 }

local shockingisntit = {
	"npc/roller/mine/rmine_explode_shock1.wav",
	"npc/roller/mine/rmine_shockvehicle1.wav",
	"npc/roller/mine/rmine_shockvehicle2.wav",
	"npc/scanner/scanner_pain1.wav",
	"npc/scanner/scanner_pain2.wav"
}

ENT.TravelTime = 1.5
ENT.LeadUp = 2000
ENT.TravelDist = 4500
ENT.SkidPlayed = false
ENT.EngineOffPlayed = false

util.AddNetworkString("jazz_bus_explore_voideffects")

util.AddNetworkString("jazz_bus_launcheffects")

function ENT:Initialize()
	local target = self:GetDestination()
	if not target or target == "<hub>" or target == "" then self:SetDestination(mapcontrol.GetHubMap()) end
	if self.PreInit then self:PreInit() end
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetTrigger(true) -- So we get 'touch' callbacks that fuck shit up
	if not self:GetHubBus() then
		self:SetNoDraw(true)
	end

	hook.Add( "CanTool", "NoBusRemoval", function( ply, tr, toolname, tool )
		if toolname ~= "remover" then return end
		if !IsValid( tr.Entity ) then return end
		if tr.Entity:GetClass() ~= "jazz_bus" then return end

		ply:Freeze(true)
		ply:DropWeapon()
		ply:EmitSound(table.Random(shockingisntit), 50)
		util.ScreenShake(ply:GetPos(), 20, 5, 2, 50)

		timer.Create( "BusRemovalUnfreeze", 1.5, 1, function()
			if !IsValid( ply ) then return end
			ply:Freeze(false)
		end )
		return false
	end )

	if self.AttachSeats then
		self:AttachSeats()
	else
		--we need at least one seat, make sure we have one
		self:AttachSeat(vector_origin,angle_zero)
	end

	self.StartAngles = self.SpawnRotation and self:SpawnRotation(self:GetAngles()) or self:GetAngles()
	self:SetAngles(self.StartAngles) --fix our orientation

	self.StartPos = self.SpawnOffset and self:SpawnOffset(self:GetPos()) or self:GetPos()
	self.GoalPos = self.GoalOffset and self:GoalOffset(self:GetPos()) or self:GetPos()
	self.StartTime = CurTime()

	-- Start us off right at the start
	self:SetPos(self.StartPos)

	self.LongThinkTime = CurTime() + 60 --think in a minute

	if self:GetHubBus() then

		-- Setup shadow controller
		self:StartMotionController()

		self:EmitSound( unpack(self.CrashSound) )
		self:EmitSound( "jazz_bus_idle", 90, 150 )

		-- Hook into when the map is changed so this bus knows to leave
		hook.Add("JazzMapRandomized", "JazzHubBusChange_" .. self:GetCreationID(), function(newmap)
			if IsValid(self) and self:GetDestination() != newmap then
				for i, v in ipairs( player.GetAll() ) do
					print( v:ExitVehicle() )
				end
				self:Leave()
			end
		end )

	else
		self.MoveState = MOVE_STATIONARY

		-- Play an ominous sound that something's coming
		local prelim = table.Random(self.PrelimSounds)
		sound.Play(prelim.snd, self.StartPos, 85, 100, 1)

		-- Also setup the screetching sound
		local rf = RecipientFilter()
		rf:AddAllPlayers()
		self.BrakeSound = CreateSound(self, table.Random(self.BrakeSounds), rf)
		self.BrakeSound:SetSoundLevel(100)

		-- Let it sink in
		self:SetBreakTime(CurTime() + prelim.delay)
		timer.Simple(prelim.delay, function()
			if IsValid(self) then self:Arrive() end
		end )
	end

	-- Setup radio
	if self.AttachRadio then self:AttachRadio() end

	if SERVER then
		
		if IsValid(self.RadioEnt) and IsValid(self.Radio) then self.RadioEnt:DeleteOnRemove(self.Radio) end

		hook.Add("PlayerEnteredVehicle", self, function(self, ply, veh, role)
			self:CheckLaunch()
		end)

		-- Hook into when a player leaves so we can double check launch conditions
		hook.Add("PlayerDisconnected", self, function()
			timer.Simple(0, function()
				self:CheckLaunch()
			end)
		end )
	end
end

-- Automatically sit the provided player down into an available seat
function ENT:SitPlayer(ply)
	if not IsValid(ply) then return false end

	for _, v in pairs(self.Seats) do
		if IsValid(v) and not IsValid(v:GetDriver()) then
			ply:EnterVehicle(v)
			return true
		end
	end

	return false
end

function ENT:CheckLaunch()
	if not self:GetHubBus() and self.CommittedToLeaving then return end

	local filled, total = self:GetNumOccupants()
	local required = math.min(player.GetCount(), total)

	if filled >= required then
		if not self:GetHubBus() then
			self.CommittedToLeaving = true
			-- Queue up the void music
			self:QueueTimedMusic()
		end
		timer.Simple(1, function()
			self.IsLaunching = true
			self:Leave()
			if self:GetHubBus() then
				net.Start("jazz_bus_launcheffects")
					net.WriteEntity(self)
				net.Broadcast()
			end
		end )
		self:EmitSound( "jazz_bus_idle", 90, 150 )
		util.ScreenShake(self:GetPos(), 10, 5, 1, 1000)
	end
end

function ENT:Arrive()
	-- Setup shadow controller
	self:StartMotionController()

	local phys = self:GetPhysicsObject()

	if phys then
		phys:EnableGravity( true )
		phys:EnableMotion( true )
		phys:Wake()
	end
	self:SetNoDraw(false)

	if IsValid(self.RadioEnt) then
		self.RadioEnt:SetNoDraw(false)
	end
	for _, v in pairs(self.Seats) do
		if IsValid(v) then
			v:SetNoDraw(v.NoDraw)
		end
	end

	self.BrakeSound:Play()

	self.StartTime = CurTime()
	self.MoveState = MOVE_ARRIVING

	-- Tweak the arrive position so we don't break the second barrier in a narrow space
	if IsValid(self.ExitPortal) then
		local MoveDistance = math.Clamp(self.ExitPortal:DistanceToVoid(self:GetFront(), true), 50, self.HalfLength*2)
		self.GoalPos = self:GetPos() + self:GetBusForward() * MoveDistance
	end

end

function ENT:Leave()
	if self.MoveState == MOVE_LEAVING then return end

	self:EmitSound("jazz_bus_accelerate2")

	self.StartTime = CurTime()
	self.StartPos = self:GetPos()
	local BusAngle = self:GetBusForward()
	self.GoalPos = self:GetHubBus() and self.GoalPos + self:GetBusForward() * self.TravelDist or self.GoalPos + BusAngle * 2000

	self.MoveState = MOVE_LEAVING

	self:ResetTrigger("arrived")
	self:GetPhysicsObject():EnableMotion(true)
	self:GetPhysicsObject():Wake()

	hook.Add("PlayerLeaveVehicle","JazzHoppedOffTheBus",function(ply,veh)
		ply.LeftJazzBus = true
	end)
	
	if not self:GetHubBus() then
		hook.Add( "PlayerLeaveVehicle", "VoidEjection", function( ply )
			timer.Create( "VoidEjectTimer", 0, 1, function() -- timer prevents crash
				if not IsValid(self) then return end
				local repcount = 0
				local BehindBus = self:GetPos() + Vector(0, 0, 50) + BusAngle * -150
				repeat
					repcount = repcount + 1
					BehindBus = BehindBus + BusAngle * -100
					ply:SetPos(BehindBus)
				until ( ply:IsInWorld( BehindBus ) or repcount > 20 )

				local EjectSpeed = Vector(0, 0, 0) + BusAngle * -2000
				ply:SetVelocity(EjectSpeed)
				ply:Kill()
				ply:Spectate(OBS_MODE_DEATHCAM)
				hook.Add( "PlayerSpawn", "VoidEjectedRespawn", function()
					self:SitPlayer(ply)
				end )
			end )
		end )
	end
end

function ENT:AttachSeat(pos, ang, mdl, nodraw)
	pos = self:LocalToWorld(pos)
	ang = self:LocalToWorldAngles(ang)
	local mdl = mdl or "models/nova/airboat_seat.mdl"
	local nodraw = nodraw or false

	local ent = ents.Create("prop_vehicle_prisoner_pod")
	if IsValid(ent) then
		ent:SetModel(mdl)
		ent:SetKeyValue("vehiclescript","scripts/vehicles/prisoner_pod.txt")
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:SetParent(self)
		ent:Spawn()
		ent:Activate()
		ent:SetNoDraw(not self:GetHubBus())
		ent.NoDraw = nodraw

		self.Seats = self.Seats or {}
		table.insert(self.Seats, ent)
	end
end

function ENT:GetNumOccupants()
	if not self.Seats then return 0, 0 end

	local count = 0
	local total = 0
	for _, v in pairs(self.Seats) do
		if IsValid(v) then
			total = total + 1
			if IsValid(v:GetDriver()) then
				count = count + 1
			end
		end
	end

	return count, total
end

function ENT:GetOccupants()
	if not self.Seats then return {} end

	local players = {}
	for _, v in pairs(self.Seats) do
		if IsValid(v) then
			local ply = v:GetDriver()
			if IsValid(ply) and ply:IsPlayer() then
				table.insert(players,ply)
			end
		end
	end

	return players
end

-- Predict when we'll blast into the jazz dimension
-- This is so we can 'preroll' some shnazzy music that blasts into high gear right when it gets going
function ENT:QueueTimedMusic()
	local estHitTime = self.BusLeaveDelay

	if IsValid(self.ExitPortal) then
		local dist = self:GetFront():Distance(self.ExitPortal:GetPos())
		estHitTime = estHitTime + math.sqrt(2 * dist / self.BusLeaveAccel) -- d = 0.5at^2
	else
		self.BusLeaveAccel = 0 --don't move, we don't wanna end up outside of the map and despawn before we leave
	end

	local startTime = estHitTime - self.VoidMusicPreroll
	self.ChangelevelTime = CurTime() + estHitTime + self.VoidMusicFadeEnd

	if self.RadioMusic then self.RadioMusic:FadeOut(startTime) end

	local bshard = ents.FindByClass("jazz_shard_black")[1]
	local isCorrupted = IsValid(bshard) and bshard:GetStartSuckTime() > 0

	net.Start("jazz_bus_explore_voideffects")
		net.WriteEntity(self)
		net.WriteFloat(CurTime() + startTime)
		net.WriteBool(isCorrupted)
	net.Broadcast()
end

function ENT:Touch(other)
	if noMoveEntsConVar:GetBool() then return end
	if other:IsPlayer() and table.HasValue( self.Seats, other:GetVehicle() ) then return end
	if not IsValid( other:GetPhysicsObject() ) then return end
	if other:GetClass() == self:GetClass() then return end
	if IsValid( other:GetParent() ) and other:GetParent():GetClass() == self:GetClass() then return end

	if self:GetHubBus() then
		local _, p = self:GetProgress()
		if p > 1 and not self.IsLaunching then return end
	else
		if self.MoveState == MOVE_STATIONARY then return end
	end
	local front = self:GetFront()
	local moveFwdAmt = (front - other:GetPos()):Dot(self:GetBusForward())
	local velocity = self:GetHubBus() and self:GetVelocity() or self:GetBusForward() * 5000
	
	local phys = IsValid(other) and other:GetPhysicsObject()

	if IsValid(phys) then
		if self:GetHubBus() then
			phys:EnableMotion(true)
			phys:Wake()
			phys:SetVelocity(self:GetBusForward() * 10000000)
		else
			phys:SetVelocity(velocity)
			other:SetPos(other:GetPos() + self:GetBusForward() * moveFwdAmt)
			phys:EnableMotion(true) -- Bus stops for nobody
		end
	end

	local d = DamageInfo()
	d:SetDamage((velocity - other:GetVelocity()):Length() )
	d:SetAttacker(self)
	d:SetInflictor(self)
	d:SetDamageType(bit.bor(DMG_VEHICLE,DMG_CRUSH))
	if self:GetHubBus() then velocity = self:GetBusForward() * velocity:Length() end
	d:SetDamageForce(velocity * 10000) -- Just fuck them up

	other:TakeDamageInfo( d )
end

function ENT:GetProgress()
	local t = CurTime() - (self.StartTime or 0)

	return t, t / self.TravelTime
end

function ENT:PhysicsStationary(phys, deltatime)
	self.ShadowControl.pos = self.GoalPos
	self.ShadowControl.angle = self.StartAngles
end

function ENT:PhysicsArriving(phys, deltatime)
	local _, perc = self:GetProgress()
	local p = math.EaseInOut(math.Clamp(perc, 0, 1), 0, 2)
	local rotAng = 0

	self.ShadowControl.pos = LerpVector(p, self.StartPos, self.GoalPos)
	self.ShadowControl.angle = Angle(self.StartAngles)
	self.ShadowControl.angle:RotateAroundAxis(self.StartAngles:Forward(), rotAng)
end

function ENT:PhysicsLeaving(phys, deltatime)
	local t, perc = self:GetProgress()
	local dist = (self.StartPos - self.GoalPos):Length()
	local pos = 0.5 * (self.BusLeaveAccel) * math.pow(t, 2) -- (1/2)at^2 = position
	local rotAng = 0

	self.ShadowControl.pos = LerpVector(pos/dist, self.StartPos, self.GoalPos)
	self.ShadowControl.angle = Angle(self.StartAngles)
	self.ShadowControl.angle:RotateAroundAxis(self.StartAngles:Forward(), rotAng)
end

function ENT:PhysicsLeavingPortal(phys, deltatime)
	local t, perc = self:GetProgress()
	local rotAng = 0
	local pos = t * self.JazzSpeed

	self.ShadowControl.pos = self.StartPos + self.MoveForward * pos
	self.ShadowControl.angle = Angle(self.StartAngles)
	self.ShadowControl.angle:RotateAroundAxis(self.StartAngles:Forward(), rotAng)
end

function ENT:PhysicsSimulate( phys, deltatime )
	--todo could probably move the hub bus onto the state system... eventually
	if self:GetHubBus() then
		local t, perc = self:GetProgress()
		local rotAng = 0

		if self.MoveState == MOVE_LEAVING then
			p = math.pow(perc, 2)

			-- Bus is speeding up, rotate backward a bit
			rotAng = math.Clamp(perc * 16, 0, 1) * 3.5
		else
			p = math.EaseInOut(math.Clamp(perc, 0, 1), 1, 1)

			-- Bus slowing down, rotate forwards
			rotAng = math.Clamp(1.2 - perc, 0, 1) * -3.5
		end

		self.ShadowControl.pos = LerpVector(p, self.StartPos, self.GoalPos)
		self.ShadowControl.angle = Angle(self.StartAngles)
		self.ShadowControl.angle:RotateAroundAxis(self:GetBusForward():Angle():Right(), rotAng)
	else
		if self.MoveState == MOVE_STATIONARY then
			self:PhysicsStationary(phys, deltatime)
		elseif self.MoveState == MOVE_ARRIVING then
			self:PhysicsArriving(phys, deltatime)
		elseif self.MoveState == MOVE_LEAVING then
			self:PhysicsLeaving(phys, deltatime)
		elseif self.MoveState == MOVE_LEAVING_PORTAL then
			self:PhysicsLeavingPortal(phys, deltatime)
		end
	end

	phys:ComputeShadowControl( self.ShadowControl )
end

function ENT:TriggerAt(name, time, func)
	local t, p = self:GetProgress()
	local fullname = name .. "_Trigger"
	//print(t, t)
	if t > time and not self[fullname] then
		self[fullname] = true
		func()
	end
end

function ENT:ResetTrigger(name)
	if not self:GetHubBus() then return end
	local fullname = name .. "_Trigger"
	self[fullname] = false
end

function ENT:Think()

	--afk checking. If someone's holding up the show, get their ass into a seat
	if self.LongThinkTime and CurTime() > self.LongThinkTime then
		--don't start forcing people on if no one's gotten in the bus yet
		if self:GetNumOccupants() > 0 then
			self.LongThinkTime = CurTime() + 10 --think again in ten seconds

			local checkPlayers = player.GetHumans()
			--don't bother checking players who are already seated
			for _, v in ipairs(self:GetOccupants()) do
				table.RemoveByValue(checkPlayers,v)
			end

			for _, v in ipairs(checkPlayers) do
				if IsValid(v) and v.JazzAFK then
					if not v:Alive() then v:Spawn() end
					--wait a tick so they could respawn if needed
					timer.Simple(0,function() if IsValid(self) and IsValid(v) then self:SitPlayer(v) end end)
				end
			end
		else
			self.LongThinkTime = CurTime() + 30 --try again in 30 seconds
		end
	end

	if self:GetHubBus() then
		local t, p = self:GetProgress()
	
		-- Keep the bus awake while it should be moving
		if p < 1 and self:GetPhysicsObject():IsAsleep() then
			self:GetPhysicsObject():Wake()
		end
	
		if self.MoveState == MOVE_LEAVING then
			self:TriggerAt("accelturbo", 0.4, function()
				self:EmitSound( "jazz_bus_accelerate", 90, 150 )
			end )
		end
	
		-- Skid sound when stopping
		self:TriggerAt("stopslide", 0.7, function()
			self:EmitSound( unpack(self.SkidSound) )
		end )
	
		self:TriggerAt("engineoff", 1.5, function()
			self:EmitSound( unpack(self.EngineOffSound) )
			self:StopSound("jazz_bus_idle")
		end )
	
		self:TriggerAt("dingding", self.TravelTime - 0.2, function()
			self:EmitSound( unpack(self.DingSound) )
		end )
	
		-- Allow the bus to settle into its spot before stopping movement
		local endTime = self.IsLaunching and 1.2 or 0
		self:TriggerAt("arrived", self.TravelTime + endTime, function()
			self:GetPhysicsObject():EnableMotion(false)
			self:SetPos(self.GoalPos)
			self:SetAngles(self.StartAngles)
	
			if self.MoveState == MOVE_LEAVING then
				self:Remove()
			end
		end )

		if self.RadioMusic then self.RadioMusic:Play() end

		return
		
	end

	if self.MoveState == MOVE_ARRIVING then
		local t, perc = self:GetProgress()
		if perc > 1 && !self:GetPhysicsObject():IsAsleep() then
			self:GetPhysicsObject():Sleep()
			self:GetPhysicsObject():EnableMotion(false)
			self:SetPos(self.GoalPos)
			self.MoveState = MOVE_STATIONARY
			self.TeleportLockOn = ents.Create("jazz_stanteleportmarker")
			if IsValid(self.TeleportLockOn) then
				--spawn this now so it's at a decent location relative to us
				self.TeleportLockOn:SetDestination(self)
				if SERVER then self.TeleportLockOn:SetName("jazz_bus_teleportmarker") end
				self.TeleportLockOn:SetDestinationName(jazzloc.Localize("jazz_bus"))
				local pos = Vector(self:GetPos())
				pos:Add(LocalToWorld(self.SpectateCamOffset,angle_zero,vector_origin,self:GetAngles()))
				self.TeleportLockOn:SetPos(pos)
				self.TeleportLockOn:SetParent(self)
				self.TeleportLockOn:SetLevel(1)
				self.TeleportLockOn:Spawn()
			end

			self.BrakeSound:FadeOut(0.2)

		end

		if self.RadioMusic then self.RadioMusic:Play() end
	end

	if IsValid(self.ExitPortal) then
		local leaving		= self.MoveState == MOVE_LEAVING
		local leavingPortal = self.MoveState == MOVE_LEAVING_PORTAL

		-- Switch to 'portal' travel model if we hit a portal
		if leaving and self.ExitPortal:ShouldBreak() then
			self.MoveState = MOVE_LEAVING_PORTAL
			self.StartTime = CurTime()
			self.MoveForward = (self.GoalPos - self.StartPos):GetNormal()
			self.StartPos = self:GetPos()
		end

		-- Stop moving the bus entirely when the rear of the bus gets inside the portal
		if (leaving or leavingPortal) and self.ExitPortal:DistanceToVoid(self:GetRear()) > 0 then
			self.MoveState = MOVE_STATIONARY
			self.GoalPos = self:GetPos()
		end
	end


	-- Changelevel at the end
	if self.ChangelevelTime and CurTime() > self.ChangelevelTime then
		--if self:GetNumOccupants() >= player.GetCount() then
			local map = self:GetDestination()
			if map == "" or map == "<hub>" then map = mapcontrol.GetHubMap() end
			progress.RoadtripSetNext(map)
			mapcontrol.Launch(map)
		--end
	end

end

function ENT:OnRemove()
	self:StopSound("jazz_bus_accelerate")
	self:StopSound("jazz_bus_accelerate2")
	self:StopSound("jazz_bus_idle")

	if self.Seats then
		for _, v in pairs(self.Seats) do
			if IsValid(v) then v:Remove() end
		end
	end

	if self.RadioMusic then self.RadioMusic:Stop() end
	if IsValid(self.Radio) then self.Radio:Remove() end

	if not self:GetHubBus() then return end

	-- Tastefully wait just a bit to let the players know they fucked up when they wanted to travel by cat
	if self.IsLaunching then
		local mapname = self:GetDestination()
		timer.Simple(2, function()
			mapcontrol.Launch(mapname)
		end )
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end