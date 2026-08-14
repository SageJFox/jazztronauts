AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_entity"

local radiusbits = 9

function ENT:SetupDataTables()
	--Parent entity might not exist on client, so track it separately
	self:NetworkVar("Bool", "Parented")
end

if SERVER then
	ENT.Radius = 20
	ENT.StartEnabled = false
	ENT.Enabled = false
	ENT.AlwaysVisible = false
	ENT.Smooth = true
	ENT.AttentionMarker = "yes"

	util.AddNetworkString("jazz_worldmarker")

	local inputs = {}

	inputs["Toggle"] = function(self, activator, caller, param)
		self:Toggle()
		return true
	end

	inputs["Enable"] = function(self, activator, caller, param)
		self:Enable()
		return true
	end
	
	inputs["Disable"] = function(self, activator, caller, param)
		self:Disable()
		return true
	end
	
	inputs["SetParent"] = function(self, activator, caller, param)
		local parents = ents.FindByName(param)
		self:Parent(#parents > 0 and parents[1] or nil)
		return true
	end
	
	inputs["ClearParent"] = function(self, activator, caller, param)
		self:Parent(nil)
		return true
	end

	inputs["SetParentAttachment"] = function(self, activator, caller, param)
		self:Parent(self:GetParent(), self:LookupAttachment(param))
		return true
	end

	inputs["SetParentAttachmentMaintainOffset"] = function(self, activator, caller, param)
		self:Parent(self:GetParent())
		return false
	end

	function ENT:AcceptInput(inputname, activator, caller, param)
		if not inputs[inputname] then return true end

		return inputs[inputname](self, activator, caller, param)
	end

	local kvs = {}

	kvs["icon"] = function(self, value)
		self.AttentionMarker = value
	end

	kvs["radius"] = function(self, value)
		self.Radius = math.abs(tonumber(value) or 20) % (2 ^ radiusbits)
	end

	kvs["parentname"] = function(self, value)
		inputs["SetParent"](self, nil, nil, value)
	end

	kvs["spawnflags"] = function(self, value)
		--Start Enabled (1)
		self.StartEnabled = bit.band(tonumber(value), 1) ~= 0
		--Always Visible (2)
		self.AlwaysVisible = bit.band(tonumber(value), 2) ~= 0
		--Enable Smoothing (4)
		self.Smooth = bit.band(tonumber(value), 4) ~= 0
	end


	function ENT:KeyValue(key, value)
		if kvs[key] then kvs[key](self, value) end

		-- Store outputs
		--[[if table.HasValue(outputs, key) then
			self:StoreOutput(key, value)
		end]]
	end

	function ENT:Update(pl, enableonly)
		net.Start("jazz_worldmarker")
			net.WriteEntity(self)
			net.WriteBool(self.Enabled)
			net.WriteBool(tobool(enableonly)) --Only sending an enabled update?
		if not enabledonly then
			net.WriteString(self.AttentionMarker)
			net.WriteUInt(self.Radius, radiusbits)
			net.WriteBool(tobool(self.AlwaysVisible))
			net.WriteBool(tobool(self.Smooth))
		end
		if IsValid(pl) then
			net.Send(pl)
			return
		end
		net.Broadcast()
	end

	function ENT:Initialize()
		self.Enabled = self.StartEnabled
		self:Update()
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	local load_queue = {}

	hook.Add("PlayerInitialSpawn", "jazz_worldmarker", function(pl, trans)
		load_queue[pl] = true
	end)

	hook.Add("StartCommand", "jazz_worldmarker", function(pl, cmd)
		if load_queue[pl] and not cmd:IsForced() then
			load_queue[pl] = nil
			for _, self in ipairs(ents.FindByClass("jazz_worldmarker")) do
				self:Update(pl, false)
			end
		end
	end)

	function ENT:Enable()
		self.Enabled = true
		self:Update(nil, true)
	end

	function ENT:Disable()
		self.Enabled = false
		self:Update(nil, true)
	end

	function ENT:Toggle()
		self.Enabled = not self.Enabled
		self:Update(nil, true)
	end

	function ENT:Parent(ent, attachment)
		self:SetParent(ent, attachment)
		self:SetParented(IsValid(ent))
	end

	function ENT:OnRemove()
		self:Disable()
	end
	
	return
end

----------------------------------CLIENT---------------------------------------

net.Receive("jazz_worldmarker", function(len, ply, marker)
	local self = net.ReadEntity()
	if not IsValid(self) then return end

	local markerName = tostring(self)
	local enable = net.ReadBool()
	if net.ReadBool() then --Only sending an enabled update
		worldmarker.SetEnabled(markerName, enable)
		return
	end
	local markerTexture = net.ReadString()
	local radius = net.ReadUInt(radiusbits)
	local alwaysVisible = net.ReadBool()
	local AttentionMarker = Material("materials/ui/jazztronauts/" .. markerTexture .. ".png", "smooth " .. (net.ReadBool() and "1" or "0"))

	worldmarker.Register(markerName, AttentionMarker, radius, alwaysVisible)
	worldmarker.Update(markerName, self:GetPos())
	worldmarker.SetEnabled(markerName, enable)
end)

function ENT:Think()
	if not (self:GetParented() or self:GetParent()) then return end
	worldmarker.Update(tostring(self), self:GetPos())
end