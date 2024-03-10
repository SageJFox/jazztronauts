--this entity does two things for us: Exists both server and clientside, and doesn't move (while the actual teleport entity might)

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Ducked" ) --should the player teleporting here be ducked?
	self:NetworkVar( "Bool", 1, "BusMarker" ) --Use for Bus Summoner Deep Dive rather than Stan
	self:NetworkVar( "Bool", 2, "DeletedRetry" ) --see superhack
	self:NetworkVar( "Entity", 0, "Destination" ) --where the actual teleport is
	self:NetworkVar( "String", 0, "DestinationName" ) --name of our teleporter entity
	self:NetworkVar( "Float", 0, "Level" ) --Level required by Upgrade to use
end
function groundHit(pos,adjust)
	local adjust = adjust or vector_origin
	
	local tr = util.TraceLine( {
		start = pos,
		endpos = pos + Vector(0, 0, -32767),
		filter = function(ent)
			if ent:IsWorld() then return true end
			if ent:IsPlayer() then return false end
			if ent:IsNPC() then return false end
			if ent:IsNextBot() then return false end
			
			if ent:IsSolid() then return true end
		end,
		mask = MASK_NPCSOLID
	} )
	local vec = nil
	if tr.Hit then
		vec = Vector(tr.HitPos)
		vec.z = vec.z + adjust.z
	end
	return vec
end

function ENT:Initialize()
	self:SetModel("models/props_bar/streetsign.mdl")
	self:SetCollisionGroup(self:GetBusMarker() and COLLISION_GROUP_DEBRIS_TRIGGER or COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(self:GetBusMarker())

	if self:GetBusMarker() then
		self:PhysicsInit(SOLID_VPHYSICS)
		self.RenderGroup = RENDERGROUP_OPAQUE
		if SERVER then self:SetPos( groundHit( self:GetPos(), Vector(0, 0, -0.25) ) ) end
		local signnames = string.Split(self:GetDestinationName(),":")
		self.Sign1Text = signnames[1]
		self.Sign2Text = signnames[2]
		print(self.Sign1Text,":",self.Sign2Text,self:GetPos())
	end
	if SERVER then self:NextThink( CurTime() + 1 ) end
end

if SERVER then
	function ENT:Think()
		if not IsValid(self:GetDestination()) then self:Remove() end
		self:NextThink( CurTime() + 3 ) --not super concerned with running this often
		return true
	end
end

--should always network teleport markers
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove(fullupdate)
	if worldmarker then
		worldmarker.SetEnabled(self,false)
	end
	--superhack for HL2's citadel 4 map
	if SERVER and self:GetBusMarker() and not self:GetDeletedRetry() then
		print("HACKHACK")
		local busmark = ents.Create("jazz_stanteleportmarker")
		if not IsValid(busmark) then return end
		busmark:SetDucked(self:GetDucked())
		busmark:SetBusMarker(self:GetBusMarker())
		busmark:SetDestination(self:GetDestination())
		busmark:SetDestinationName(self:GetDestinationName())
		busmark:SetLevel(self:GetLevel())
		busmark:SetDeletedRetry(true)
		busmark:Spawn()
		busmark:Fire("AddOutput","classname prop_combine_ball",0,self,busmark)
		busmark:Fire("AddOutput","targetname jazzWHATTHEFUCKWHY",0,self,busmark)
		busmark:SetPos(self:GetPos())
	end
end

function ENT:Draw()
	if self:GetBusMarker() then
		self:DrawModel()
		--todo: do blinking fx if it's selected
		--use ducked bool to tell if it's selected
	end
end
--I tried
--[[function ENT:Dissolve()
	return false
end]]