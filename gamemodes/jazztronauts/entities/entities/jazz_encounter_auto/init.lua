ENT.Type = "point"

local outputs = { "OnEncounter1", "OnEncounter2", "OnEncounter3", "OnMapSpawn" }
outputs[0] = "OnNoEncounter"

function ENT:Initialize()
	local encounter = mapcontrol.GetNextEncounter() or 0
	self:TriggerOutput("OnMapSpawn", self, encounter)
	self:TriggerOutput(outputs[encounter] or "OnNoEncounter", self)
	--print("Encounter:",outputs[encounter],encounter)
	timer.Simple(1,function()
		if IsValid(self) then self:Remove() end
	end)
end

function ENT:KeyValue(key, value)
	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end
end