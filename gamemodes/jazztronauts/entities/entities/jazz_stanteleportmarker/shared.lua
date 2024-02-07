--this entity does two things for us: Exists both server and clientside, and doesn't move (while the actual teleport entity might)

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Ducked" ) --should the player teleporting here be ducked?
	self:NetworkVar( "Entity", 0, "Destination" ) --where the actual teleport is
	self:NetworkVar( "String", 0, "DestinationName" ) --name of our teleporter entity
end

function ENT:Initialize()
	self:SetModel("models/props_interiors/vendingmachinesoda01a.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(false)
end

--should always network teleport markers
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove(fullupdate)
	if worldmarker then
		worldmarker.SetEnabled(self,false)
	end
end

function ENT:Draw()
end
