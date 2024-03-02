--Logical entity to fire I/O based on players entering/exiting its PVS
--main use is hub optimization (don't do expensive things if no one is there to see them)

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:SetupDataTables()

	self:NetworkVar( "Bool", 0, "Occupied" )
	self:NetworkVar( "Bool", 1, "ForceOccupy" )
	self:NetworkVar( "Bool", 2, "InitiallyFull" )

end

local outputs =
{
	"OnOccupied",
	"OnUnoccupied"
}

function ENT:KeyValue(key, value)

	if key == "initialstate" then
		self:SetInitiallyFull(tobool(value))
		self:SetOccupied(tobool(value))
	end

	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end

end

function ENT:AcceptInput(input, activator, caller, data)

	local data = tonumber(data)

	if input == "ForceOccupancy" then
		self:SetForceOccupy(true)

		if data and data > 0 then --let a set forced occupancy have an automatic timer set in

			timer.Create( self:GetName() .. self:EntIndex() .. "ReleaseForcedOccupancy", data, 1, function()
				if not IsValid(self) then return end
				self:SetForceOccupy(false)
			end)

		else -- if we get an input without a time attached again, we want manual control
			timer.Remove( self:GetName() .. self:EntIndex() .. "ReleaseForcedOccupancy" )
		end

	elseif input == "ReleaseForcedOccupancy" then

		self:SetForceOccupy(false)
		timer.Remove(self:GetName() .. self:EntIndex() .. "ReleaseForcedOccupancy") -- make sure this isn't waiting in the wings to confuse us later

	end

end

function ENT:Initialize()

	self:SetModel("models/editor/camera.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(false)

end

function ENT:Think()

	if SERVER then

		local players = player.GetHumans()

		 --only care to change once we've gotten players, or if we're not forced open
		if not self:GetForceOccupy() and ( #players > 0 or not self:GetInitiallyFull() ) then

			local test = false
			
			if not test then
				
				for _, v in ipairs(players) do

					local view = v:GetViewEntity() --will *usually* be the player themself
					if IsValid(view) then
						test = test or view:TestPVS(self)
						if test then break end
					end
					if v.JazzDialogPVS then
						test = test or self:TestPVS(v.JazzDialogPVS)
						if test then break end
					end

				end

			end
			--only fire an output if we've changed
			if self:GetOccupied() ~= test then

				self:SetInitiallyFull(false) --we're now using a set value, ignore this
				self:SetOccupied(test)
				self:TriggerOutput( test and "OnOccupied" or "OnUnoccupied", v )
				--print( test and "OnOccupied" or "OnUnoccupied")

			end

		end

		self:NextThink(CurTime())
		return true

	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:Draw()
end
