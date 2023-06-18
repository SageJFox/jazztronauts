-- Runs concommands without the risk of currupting the vmf
ENT.Type = "point"
ENT.DisableDuplicator = true

function ENT:Initialize()

end

function ENT:KeyValue( key, value )
	if key == "level" then self.Level = value end
end


function ENT:ChangeLevel( activator, caller, data )
	if self.Level == "<hub>" then
		mapcontrol.Launch(mapcontrol.GetHubMap())
	elseif self.Level == "<encounter>" then
		mapcontrol.Launch(mapcontrol.GetEncounterMap())
	elseif self.Level == "<intro>" then
		mapcontrol.Launch(mapcontrol.GetIntroMap())
	elseif self.Level == "<outro1>" then
		mapcontrol.Launch(mapcontrol.GetEndMaps()[1])
	elseif self.Level == "<outro2>" then
		mapcontrol.Launch(mapcontrol.GetEndMaps()[2])
	else
		mapcontrol.Launch(self.Level)
	end
end

function ENT:AcceptInput( name, activator, caller, data )

	if name == "ChangeLevel" then self:ChangeLevel( activator, caller, data ) return true end

	return false
end