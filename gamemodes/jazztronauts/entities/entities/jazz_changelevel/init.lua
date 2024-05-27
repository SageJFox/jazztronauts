-- Runs concommands without the risk of currupting the vmf
ENT.Type = "point"
ENT.DisableDuplicator = true

function ENT:Initialize()
	--self:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)
end

function ENT:KeyValue( key, value )
	if key == "level" then self.Level = value end
end

local dest =
{
	["<hub>"] = function() return mapcontrol.GetHubMap() end,
	["<encounter>"] = function() return mapcontrol.GetEncounterMap() end,
	["<intro>"] = function() return mapcontrol.GetIntroMap() end,
	["<outro1>"] = function() return mapcontrol.GetEndMaps()[1] end,
	["<outro2>"] = function() return mapcontrol.GetEndMaps()[2] end,
}

function ENT:ChangeLevel( activator, caller, data )
	local level = dest[self.Level] and dest[self.Level]() or self.Level
	mapcontrol.Launch(level)
end

function ENT:AcceptInput( name, activator, caller, data )

	if name == "ChangeLevel" then self:ChangeLevel( activator, caller, data ) return true end

	return false
end