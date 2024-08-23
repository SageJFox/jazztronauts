-- Board that displays currently selected maps
AddCSLuaFile()
AddCSLuaFile("sh_honk.lua")
include("sh_honk.lua")

ENT.Type = "point"
ENT.TravelTime = 2.5
ENT.LeadUp = 2000
ENT.TravelDist = 4500
ENT.Chance = 1

local SF_NEWPOS = 1

local stops = stops or {}
local pick = pick or nil
local picktime = picktime or 0
local stop = stop or nil


function ENT:Initialize()

	-- Hook into map change events
	if SERVER then
		hook.Add("JazzMapRandomized", self, function(self, newmap, wsid)
			if self.LastMap != newmap then
				self.LastMap = newmap

				if self.LastMap then
					self:OnMapChanged(newmap, wsid)
				end
			end
		end )
		for v = 1, self.Chance do
			table.insert(stops, self)
		end
	end
end

function ENT:KeyValue(key, value)
	if key == "traveltime" then
		self.TravelTime = tonumber(value)
	elseif key == "leadup" then
		self.LeadUp = tonumber(value)
	elseif key == "traveldist" then
		self.TravelDist = tonumber(value)
	elseif key == "chance" then
		self.Chance = math.Round(tonumber(value) or 1)
	end
end
function ENT:OnMapChanged(newmap, wsid)
	-- if the map has multiple stops, pick just one
	if #stops > 1 then
		--ensure all stops use the same pick (even if it was invalid and later removed)
		if picktime < engine.TickCount() then
			picktime = engine.TickCount()
			pick = math.ceil(util.SharedRandom("itsasbigasawhaleanditsabouttosetsail", 0.001, #stops, picktime))
			stop = stops[pick]
		end 
		--validation, if the pick was invalid remove it and try again
		if not IsValid(stop) then
			for k, v in ipairs(stops) do
				if v == stop then table.remove(stops, k) end
			end
			timer.Simple(0,function()
				if not IsValid(self) then return end
				self:OnMapChanged(newmap, wsid)
			end)
			return
		end

		if stop ~= self then return end
	end
	local bus = ents.Create( "jazz_bus" )
	if not IsValid(bus) then return end
	local pos = self:GetPos()
	if not self:HasSpawnFlags(SF_NEWPOS) then -- Fallback for older maps: Add offset for old spawns
		local adjust = Vector(90, 230, 0)
		adjust:Rotate(self:GetAngles())
		pos:Add(adjust)
	end
	bus:SetPos(pos)
	bus:SetAngles(self:GetAngles())
	bus:SetMap(newmap, wsid or "")
	if isnumber(self.TravelTime) then bus.TravelTime = self.TravelTime end
	if isnumber(self.LeadUp) then bus.LeadUp = self.LeadUp end
	if isnumber(self.TravelDist) then bus.TravelDist = self.TravelDist end
	bus:SetHubBus(true)
	bus:Spawn()
end

function ENT:OnRemove()
	for k, v in ipairs(stops) do
		if v == self then table.remove(stops, k) end
	end
end