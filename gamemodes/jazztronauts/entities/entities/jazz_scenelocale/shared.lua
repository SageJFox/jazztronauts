--basically an info_target with some layer support

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.Layers = { { ["z"] = 0, ["zsnap"] = 64 } }

if SERVER then
	util.AddNetworkString("JazzSceneLocaleUpdateClient")
end

function ENT:KeyValue(key, value)
	if string.find(key,"layer") then
		local digit = tonumber( string.match(key,"layer(%d+)$") )
		if isnumber(digit) then
			if not self.Layers[digit] then self.Layers[digit] = { ["z"] = 0, ["zsnap"] = 64 } end
			self.Layers[digit].z = tonumber(value)
		end
	end
	if string.find(key,"zsnap") then
		local digit = tonumber( string.match(key,"zsnap(%d+)$") )
		if isnumber(digit) then
			if not self.Layers[digit] then self.Layers[digit] = { ["z"] = 0, ["zsnap"] = 64 } end
			self.Layers[digit].zsnap = tonumber(value)
		end
	end
end

function ENT:Initialize()
	self:SetModel("models/editor/camera.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(false)
end

--get values from the map (server) onto the clients where they're actually needed

if SERVER then
	hook.Add("PlayerInitialSpawn","JazzSceneLocaleUpdateClient",function(ply)
		timer.Simple(1,function()
			for _, v in ipairs(ents.FindByClass("jazz_scenelocale")) do
				net.Start("JazzSceneLocaleUpdateClient")
					net.WriteEntity(v)
					net.WriteTable(v.Layers)
				net.Send(ply)
				--PrintTable(v.Layers)
			end
		end)
	end)
end

net.Receive("JazzSceneLocaleUpdateClient",function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end
	table.CopyFromTo( net.ReadTable(), ent.Layers )
	--PrintTable(ent.Layers)
end)

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:Draw()
end
