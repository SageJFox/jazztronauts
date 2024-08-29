if SERVER then
	AddCSLuaFile()
end

SWEP.Base					= "weapon_basehold"
SWEP.PrintName				= jazzloc.Localize("jazz.weapon.buscaller")
SWEP.Slot					= 5
SWEP.Category				= "#jazz.weapon.category"
SWEP.Purpose				= jazzloc.Localize("jazz.weapon.buscaller.desc")
SWEP.AutoSwitchFrom			= false

SWEP.WepSelectIcon = "b"
SWEP.AutoIconAngle = Angle(0, 100, 70)

SWEP.ViewModel				= "models/weapons/c_bus_summoner.mdl"
SWEP.WorldModel				= "models/weapons/w_bus_summoner.mdl"
SWEP.HoldType				= "pistol"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 0.1
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "weapons/357/357_fire2.wav" )
SWEP.Primary.Automatic		= false

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo		= "none"

SWEP.Spawnable				= true
SWEP.RequestInfo			= {}

SWEP.BeamMat				= Material("cable/physbeam")

SWEP.Upgrade				= nil --I feel like there has to be a better way than this mess, but I could not find it.

if SERVER then
	util.AddNetworkString("JazzBusSummonerKeyChain")
end

function SWEP:Initialize()
	self.BaseClass.Initialize( self )
	self:SetWeaponHoldType( self.HoldType )
	self.AttachIdx = self:LookupAttachment("muzzle")
	timer.Simple(0,function()
		if not IsValid(self) then return end
		self:SetBodygroup(1,self.Upgrade and 1 or 0)
	end)
end

function SWEP:Equip(ply)
	timer.Simple(0, function()
	if not IsValid(self) or not IsValid(ply) or not ply:IsPlayer() then return end
		self.Upgrade = missions.PlayerCompletedAll(ply)
		self:SetBodygroup(1,self.Upgrade and 1 or 0)
		net.Start("JazzBusSummonerKeyChain")
			net.WriteEntity(self)
			net.WriteBool(self.Upgrade)
		net.Send(player.GetHumans())
	end)
end

function SWEP:SetupDataTables()
	self.BaseClass.SetupDataTables( self )

	self:NetworkVar("Entity", "BusMarker")
	self:NetworkVar("Entity", "BusStop")
end

function SWEP:Deploy()
	return true
end

function SWEP:DrawWorldModel()

	self:DrawModel()

end


function SWEP:UpdateBeamHum()
	local active = self:IsPrimaryAttacking()

	if not self:IsCarriedByLocalPlayer() then return end

	if active or IsValid(self:GetBusStop()) then
		if not self.BeamHum then
			self.BeamHum = CreateSound(self, "ambient/energy/force_field_loop1.wav")
		end

		if not self.BeamHum:IsPlaying() then
			self.BeamHum:Play()
		end
	elseif self.BeamHum then
		self.BeamHum:Stop()
		self.BeamHum = nil
	end
end

function SWEP:SwitchWeaponThink()
	if not IsFirstTimePredicted() then return end
	local owner = self:GetOwner()
	local forceAttack = owner:KeyDownLast(IN_ATTACK) and owner:KeyDown(IN_ATTACK)

	-- Because this is only a hack, only do it for one 'cycle'
	-- User must un-press attack before being able to attack again
	if not forceAttack then
		self.IgnoreAttackForced = true
	end

	if forceAttack and not self:IsPrimaryAttacking() and not self.IgnoreAttackForced then
		self:PrimaryAttack()
		print("force attack")
		self.IgnoreAttackForced = true
		timer.Simple(0,function()
			if not IsValid(self) then return end
			local owner = self:GetOwner()
			if not IsValid(owner) or not owner:Alive() or (owner:InVehicle() and not owner:GetAllowWeaponsInVehicle()) then
				self.BeamHum:Stop()
				self.BeamHum = nil
			end
		end)
	end

end

function SWEP:Think()

	self:SwitchWeaponThink()
	if SERVER then return end

	local marker = self:GetBusMarker()

	-- If the marker is no longer valid, stop attacking
	if not IsValid(marker) and self.HadMarker then
		self:StopPrimaryAttacking()
		self.HadMarker = false
	end

	self:UpdateBeamHum()
	if IsValid(marker) and marker.AddJazzRenderBeam then
		marker:AddJazzRenderBeam(self:GetOwner())
	end

	-- If the marker has enough people, vary the pitch as it gets closer
	if IsValid(marker) and marker.GetSpawnPercent then
		self.HadMarker = true

		local perc = marker:GetSpawnPercent()
		if self.BeamHum then self.BeamHum:ChangePitch(100 + perc * 100) end
	end
end

-- Get the bus stop they're aimed at, or nil if they aren't looking at one
local function GetLookMarker(pos, dir, fov)
	for _, v in pairs(ents.FindByClass("jazz_bus_marker")) do
		if v.IsLookingAt and v:IsLookingAt(pos, dir, fov) then return v end
	end

	return nil
end

function SWEP:CreateBusMarker(pos, angle)
	local marker = ents.Create("jazz_bus_marker")
	if not IsValid(marker) then return nil end
	marker:SetPos(pos)
	marker:SetAngles(angle)
	local busstop = self:GetBusStop()
	if IsValid(busstop) then
		marker.Destination = string.Split( busstop:GetDestinationName(), ":")[1]
	end
	marker:Spawn()
	marker:Activate()

	return marker
end

local voted = nil

-- Set the player up with either the marker they're aimed at or a brand new one
function SWEP:CreateOrUpdateBusMarker()
	local owner = self:GetOwner()
	local pos = owner:GetShootPos()
	local dir = owner:GetAimVector()

	local marker = GetLookMarker(pos, dir, owner:GetFOV())

	-- If we weren't looking at an existing marker,
	-- do a trace to where WE want to put it
	if not IsValid(marker) then
		local tr = util.TraceLine( {
			start = pos,
			endpos = pos + dir * 100000,
			mask = MASK_SOLID,
			collisiongroup = COLLISION_GROUP_WEAPON
		} )

		marker = self:CreateBusMarker(tr.HitPos, tr.HitNormal:Angle())
		if not IsValid(marker) and ents.GetEdictCount() >= 8064 then
			if not voted then
				voted = true
				mapcontrol.voteToLeave(true)
			end
			return
		end
	end

	self:SetBusMarker(marker)
	marker:AddPlayer(owner)
end

function SWEP:PrimaryAttack()
	self.BaseClass.PrimaryAttack(self)

	self:GetOwner():ViewPunch( Angle( -1, 0, 0 ) )
	self:EmitSound( self.Primary.Sound, 50, math.random( 200, 255 ) )

	if IsFirstTimePredicted() then
		if IsValid(self:GetBusStop()) then
			self:GetBusStop():SetBodygroup(2,1)
		end
		if SERVER then

			self:CreateOrUpdateBusMarker()
		end
	end

	self:ShootEffects()
end

function SWEP:CheckBusStop()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local td = util.GetPlayerTrace(owner)
	td.filter = function(ent)
		if IsValid(ent) and (ent:GetClass() == "jazz_stanteleportmarker" or ent:GetName() == "jazzWHATTHEFUCKWHY") and ent:GetBusMarker() then return true else return false end end

	local tr = util.TraceLine(td)
	if IsValid(tr.Entity) and tr.Entity ~= self:GetBusStop() then
		--print(tr.Entity)
		self:SetBusStop(tr.Entity)
		tr.Entity:SetDucked(true)
	else --clear previous marker
		local busstop = self:GetBusStop()
		if IsValid(busstop) then
			busstop:SetBodygroup(2,0)
			busstop:SetLevel(99)
			busstop:SetDucked(false)
		end
		--print("nil")
		self:SetBusStop(nil)
	end

end

function SWEP:SecondaryAttack()
	self.BaseClass.SecondaryAttack(self)

	self:GetOwner():ViewPunch( Angle( -1, 0, 0 ) )
	self:EmitSound( self.Primary.Sound, 50, math.random( 200, 255 ) )

	if IsFirstTimePredicted() then

		if SERVER then
			self:CheckBusStop()
		end
	end

end

function SWEP:ShootEffects()

	local owner = self:GetOwner()
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )

end

function SWEP:StopPrimaryAttack()
	self:SendWeaponAnim( ACT_VM_IDLE )
	if !IsFirstTimePredicted() then return end

	if IsValid(self:GetBusStop()) then
		self:GetBusStop():SetBodygroup(2,0)
	end

	if SERVER and IsValid(self:GetBusMarker()) then
		self:GetBusMarker():RemovePlayer(self:GetOwner())
	end

	self:SetBusMarker(nil)
	if voted then
		voted = nil
		mapcontrol.voteToLeave(false)
	end
end

function SWEP:Cleanup()
	if self.BeamHum then
		self.BeamHum:Stop()
	end
	if voted then
		voted = nil
		mapcontrol.voteToLeave(false)
	end
	self.IgnoreAttackForced = false
end


function SWEP:Reload() return false end
function SWEP:CanPrimaryAttack() return true end
function SWEP:CanSecondaryAttack() return true end
function SWEP:Reload() return false end

hook.Add("CreateMove", "JazzSwitchToBusCaller", function(cmd)
	if not LocalPlayer():Alive() then return end

	-- Suppress weapon fire if we're over a summon circle
	local curWep = LocalPlayer():GetActiveWeapon()
	local firstShot = cmd:KeyDown(IN_ATTACK) && not LocalPlayer():KeyDownLast(IN_ATTACK)
	if firstShot && (!IsValid(curWep) or curWep:GetClass() != "weapon_buscaller") then

		local pos = LocalPlayer():GetShootPos()
		local dir = LocalPlayer():GetAimVector()

		local marker = GetLookMarker(pos, dir)

		-- Valid marker hit, suppress and switch to weapon
		if IsValid(marker) then
			local caller = LocalPlayer():GetWeapon("weapon_buscaller")

			-- Automatically switch to the bus caller weapon
			if IsValid(caller) then
				cmd:SelectWeapon(caller)
			end
		end
	end
end )

if CLIENT then

	local funnydraw = GetConVar("r_drawtranslucentworld")
	
	function SWEP:renderPlayerBeam()
		if not IsValid(self) then return false end

		local ply = self:GetOwner()
		if not IsValid(ply) then return false end

		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep ~= self then return false end

		local busstop = self:GetBusStop()
		if not IsValid(busstop) then return false end

		-- Get attach point of gun's muzzle
		local attach = ply:GetShootPos()
		local attachIdx = self.AttachIdx or 1

		if attachIdx > 0 then
			local attachInfo = self:GetAttachment(attachIdx) -- World model position, at very least
			local vm = ply:GetViewModel()
			if self:IsCarriedByLocalPlayer() and IsValid(vm) then
				attachInfo = vm:GetAttachment(attachIdx) or attachInfo -- View model position
			end
			if istable(attachInfo) then attach = attachInfo.Pos end
		end
		
		-- Draw beam
		local dist = attach:Distance(busstop:GetPos())
		local offset = -CurTime()*4

		render.SetMaterial(self.BeamMat)
		render.DrawBeam(attach, busstop:GetAttachment(busstop:LookupAttachment("sign")).Pos, 3, offset, dist/100 + offset, color_blue)
		return true
	end

	hook.Add("PostDrawOpaqueRenderables", "JazzDrawBusstopBeams", function()
		--work around for a bug where translucent won't render
		if funnydraw:GetBool() == false then
			for _, v in ipairs(ents.FindByClass("weapon_buscaller")) do
				if not IsValid(v) then continue end
				v:renderPlayerBeam()
			end
		end
	end )

	hook.Add("PostDrawTranslucentRenderables", "JazzDrawBusstopBeams", function()
		for _, v in ipairs(ents.FindByClass("weapon_buscaller")) do
			if not IsValid(v) then continue end
			v:renderPlayerBeam()
		end
	end )

	net.Receive("JazzBusSummonerKeyChain", function()
		local self = net.ReadEntity()
		if IsValid(self) then
			self.Upgrade = net.ReadBool()
			self:SetBodygroup(1, self.Upgrade and 1 or 0)
		end
	end)

	function SWEP:PreDrawViewModel(vm, ply, wep)
		if self.Upgrade == nil then self.Upgrade = missions.PlayerCompletedAll(ply) end --catches issues in very first spawn as server host
		vm:SetBodygroup(1,self.Upgrade and 1 or 0)
	end

end


-- Give the player the bus caller if they're hovering over it and somehow don't have it
hook.Add("SetupMove", "JazzSwitchToBusCaller", function(ply, mv, cmd)
	local curWep = ply:GetActiveWeapon()
	if CLIENT or not cmd:KeyDown(IN_ATTACK) then return end
	if IsValid(curWep) and curWep:GetClass() == "weapon_buscaller" then return end
	if ply:HasWeapon("weapon_buscaller") then return end

	-- Check to see if we're clicking in the direction of a bus caller
	local pos = ply:GetShootPos()
	local dir = ply:GetAimVector()

	local marker = GetLookMarker(pos, dir)

	-- If we're in the direction of a marker, give the player the weapon and switch to it
	if IsValid(marker) then
		local wep = ply:Give("weapon_buscaller")

		-- Manually switch to it. Very hacky and not predicted,
		-- but we're already too late for prediction anyway
		if IsValid(wep) then
			ply:SelectWeapon(wep:GetClass())
		end
	end
end )
