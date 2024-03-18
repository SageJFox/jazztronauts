ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.PrintName		= "#jazz_bus"
ENT.Author			= ""
ENT.Information	= ""
ENT.Category		= ""
ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/matt/jazz_trolley.mdl" )
ENT.HalfLength		= 300
ENT.JazzSpeed		= 800 -- How fast to explore the jazz dimension

ENT.RadioMusicName = "jazztronauts/music/que_chevere_radio_loop.wav"
ENT.RadioModel = "models/props_lab/citizenradio.mdl"

ENT.VoidMusicName = "jazztronauts/music/que_chevere_travel_fade.mp3"
ENT.VoidMusicPreroll = 2.9 -- how many seconds it takes to get to the chorus
ENT.VoidMusicFadeStart = 12.0
ENT.VoidMusicFadeEnd   = 19.0

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "BreakTime")
	self:NetworkVar("String", 0, "Destination")
	self:NetworkVar("String",	1, "WorkshopID")
	self:NetworkVar("Int",		0, "MapProgress")
	self:NetworkVar("Bool", 0, "HubBus") -- are we a hub bus or an explore bus?
end

function ENT:ToProgressMask(mapname)
	local col, total = progress.GetMapShardCount(mapname)
	if not total or total == 0 then return 0 end

	return bit.bor(bit.lshift(total, 16), col)
end

function ENT:FromProgressMask(val)
	local mask = bit.lshift(1, 16) - 1
	return bit.band(val, mask),
		bit.band(bit.rshift(val, 16), mask)
end

function ENT:SetMap(mapname, workshopID)
	self:SetDestination(mapname)
	self:SetWorkshopID(workshopID)
	self:SetMapProgress(self:ToProgressMask(mapname))
end

function ENT:CanProperty()
	return false
end