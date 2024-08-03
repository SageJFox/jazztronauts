//Allow mappers to make arbitrary money gates
AddCSLuaFile("cl_init.lua")

ENT.Type = "point"
ENT.Price = 1			--how much to charge
ENT.FullValue = true	--fail (and don't charge) if the player doesn't have enough money
ENT.Multiplier = false 	--scale price with NG+ multiplier

util.AddNetworkString("JazzLogicPurchaseChat")

local outputs =
{
	"OnPurchaseAttempt",
	"OnPurchased",
	"OnInsufficientFunds",
	"OnPartialFunds"
}

function ENT:KeyValue(key, value)

	if key == "price" then
		self.Price = math.Round(tonumber(value)) --no partial money
	elseif key == "needfullvalue" then
		self.FullValue = tobool(value)
	elseif key == "usemultiplier" then
		self.Multiplier = tobool(value)
	--todo: add marker (vector or entity(s)?) location to display price when player is near.
	end

	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end

end

--player can +use these
local directsources = {
	["func_button"] = true,
	["func_rot_button"] = true,
	["momentary_rot_button"] = true,
	["func_door"] = true,
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
	["prop_physics"] = true,
	["prop_physics_override"] = true,
	["prop_physics_multiplayer"] = true,
	["prop_physics_respawnable"] = true,
	["prop_dynamic"] = true,
	["prop_dynamic_override"] = true,
	["prop_vehicle"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_jeep"] = true,
	["prop_vehicle_crane"] = true,
	["prop_vehicle_driveable"] = true,
}

function ENT:AcceptInput( name, activator, caller, data )
	if name == "AttemptPurchase" then
		if IsValid(activator) and activator:IsPlayer() then

			self:TriggerOutput( "OnPurchaseAttempted", activator )

			local total, price = jazzmoney.GetNotes(activator), self.Price * -1
			if self.Multiplier then price = price * (newgame.GetMultiplierBase() + 1) end

			--weird but okay
			if price == 0 then
				self:TriggerOutput( "OnPurchased", activator )
				return true
			end

			--attempt was blocked by user settings
			local protection = math.Round( activator:GetInfoNum("jazz_money_protection", 1) )

			if protection == 2 or ( protection == 1 and IsValid(caller) and directsources[caller:GetClass()] ~= true ) or mapcontrol.IsInHub() ~= true then

				net.Start("JazzLogicPurchaseChat")
					net.WriteString((price > 0) and "jazz.money.blockgive" or "jazz.money.blocktake")
					net.WriteString( ( isstring(caller:GetName()) and caller:GetName() ~= "" ) and caller:GetName() or caller:GetClass() )
					net.WriteUInt(math.abs(price), 32)
				net.Send(activator)

				--self:TriggerOutput( "OnInsufficientFunds", activator ) --maybe should? Iunno.
				return true

			end

			--too rich for my blood
			if total + price < 0 then
				--partial
				if self.FullValue ~= true and total > 0 then
					jazzmoney.ChangeNotes( activator, total * -1 ) --don't go below 0
					self:TriggerOutput( "OnPartialFunds", activator ) --todo: should probably have this output the amount it actually took so logic can be based off of it
				else
					self:TriggerOutput( "OnInsufficientFunds", activator )
				end

				return true
			end

			--scold abusers
			if price > 99999 then
				net.Start("JazzLogicPurchaseChat")
					net.WriteString("jazz.money.cheat")
					net.WriteString("")
					net.WriteUInt(0, 32)
				net.Send(activator)
			end

			jazzmoney.ChangeNotes( activator, price )
			self:TriggerOutput( "OnPurchased", activator )

			return true
		end
	end

	return false
end