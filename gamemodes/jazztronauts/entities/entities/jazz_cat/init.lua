AddCSLuaFile("cl_init.lua")
AddCSLuaFile("sh_chatmenu.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")
include("sh_chatmenu.lua")

util.AddNetworkString("JazzRequestChatStart")

ENT.Multiplier = 1

local SF_NOHEADTRACK = 1
local SF_PHYSICSLUL = 2
local SF_NEWANGLES = 4


local outputs =
{
	"OnPicked",
	"OnNotPicked",
}

local updateCollision = function(self)
	-- The cats don't actually have a physics model so just make a box around em
	local mins, maxs = self:AdjustBounds()
	self:PhysicsInitBox(mins, maxs, "watermelon")
	mins:Rotate(self:GetAngles())
	maxs:Rotate(self:GetAngles())
	self:SetCollisionBounds(mins,maxs)

	if not self:HasSpawnFlags(SF_PHYSICSLUL) then 
		self:SetMoveType(MOVETYPE_NONE)
	end
end

function ENT:Initialize()

	-- Lookup corresponding npc model
	local npcinfo = missions.GetNPCInfo(self.NPCID)
	self:SetModel(npcinfo and npcinfo.model or self.Model)

	-- Fallback for older maps: Rotate so new models align right on old spawns
	if not self:HasSpawnFlags(SF_NEWANGLES) then
		local ang = self:GetAngles()
		ang:Add(Angle( 90, 90, 0 ))
		self:SetAngles( ang )
	end

	self:SetIdleAnim(self.IdleAnim)

	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(69)
		if not self:HasSpawnFlags(SF_PHYSICSLUL) then
			phys:EnableMotion(false)
		else
			phys:Wake()
		end
	end

	self:SetNPCID(self.NPCID or missions.NPC_CAT_BAR)
	if self:GetNPCID() == missions.NPC_CAT_BAR then
		self:SetHubInfo( string.lower( GetConVar("jazz_hub"):GetString() ..":"..
		GetConVar("jazz_hub_outro"):GetString() ..":"..
		GetConVar("jazz_hub_outro2"):GetString() ..":"..
		GetConVar("jazz_trolley"):GetString() ) )
	end
	self:SetupChatTables()

end

function ENT:KeyValue( key, value )

	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end

	if key == "DefaultAnim" or key == "idleanim" then
		self.IdleAnim = value
	end

	if key == "npcid" then
		self.NPCID = tonumber(value)
	end
	
	if key == "skin" then
		self:SetSkin(tonumber(value))
	end

	if key == "multiplier" then
		self.Multiplier = tonumber(value) or 1
	end
end


function ENT:AcceptInput( name, activator, caller, data )

	if name == "Skin" then self:SetSkin(tonumber(data)) return true end

	if name == "SetIdle" then self:SetIdleAnim(tostring(data)) return true end

	return false
end

function ENT:SetIdleAnim(anim)
	self.IdleAnim = anim

	self:ResetSequence(self:LookupSequence(self.IdleAnim))

	updateCollision(self)

	self:SetPlaybackRate(1.0)
end

function ENT:Think()
	self:NextThink(CurTime())
	return true
end

function ENT:Use(activator, caller)
	if !IsValid(caller) || not caller:IsPlayer() then return end

	self:StartChat(caller)
end

net.Receive("JazzRequestChatStart", function(len, ply)
	local cat = net.ReadEntity()

	if IsValid(cat) && cat.StartChat then
		cat:StartChat(ply)
	end
end )

-- In the map, entities are placed in all possible cat locations
-- Randomly choose which ones to keep so only a single cat is spawned
hook.Add("InitPostEntity", "JazzPlaceSingleCat", function()
	local NPCS = {}
	local cats = ents.FindByClass("jazz_cat")

	-- Sort into distinct lists based on each cat id
	for _, v in pairs(cats) do
		NPCS[v.NPCID] = NPCS[v.NPCID] or {}
		local count = v.Multiplier or 1
		for i = 1, count do
			table.insert(NPCS[v.NPCID], v)
		end
	end

	-- Select a random one to keep, destroy the rest
	for id, npcs in pairs(NPCS) do
		local survivor = table.Random(npcs)

		if IsValid(survivor) then
			survivor:TriggerOutput("OnPicked", survivor)
		end

		-- Kill the rest
		for _, v in pairs(npcs) do
			if v != survivor then
				v:TriggerOutput("OnNotPicked", v)
				v:Remove()
			end
		end
	end
end )