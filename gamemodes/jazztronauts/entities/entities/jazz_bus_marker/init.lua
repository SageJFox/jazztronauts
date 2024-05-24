AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")


function ENT:Initialize()
	self:DrawShadow(false)
	self.BaseClass.Initialize(self)
end

function ENT:ValidPlayer(ply)
	if !IsValid(ply) then return false end

	local w = ply:GetWeapon("weapon_buscaller")
	return IsValid(w) and w:GetBusMarker() == self
end

function ENT:HasEnoughPlayers()
	local playerCount = 0

	--ignore AFK players
	for _, v in ipairs(player.GetAll()) do
		if IsValid(v) and not v.JazzAFK then
			playerCount = playerCount + 1
		end
	end

	return #self.PlayerList > playerCount / 2
end

function ENT:ActivateMarker()

	mapcontrol.SpawnExitBus(self:GetPos(), self:GetAngles(), self.Destination)

	for i = 1, game.MaxPlayers() do

		local ply = Entity(i)
		if not IsValid(ply) or not ply:IsPlayer() then return end

		local w = ply:GetWeapon("weapon_buscaller")
		if not IsValid(w) then return end

		if w:GetBusMarker() == self then
			local busstop = w:GetBusStop()
			w:SetBusStop(nil)
			if IsValid(busstop) then
				busstop:SetDucked(false)
				busstop:SetLevel(100)
			end
		end

	end
	
end

function ENT:UpdateSpeed()
	self:SetSpeed(self:HasEnoughPlayers() and 1/3 or 0)
end