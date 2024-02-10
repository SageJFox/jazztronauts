AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.IsTween = false 
ENT.TweenTime = 5

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "Script" ) --name of the script file that we want to override, i.e. "npc_cat_bar.event0" or "jazz_bar_intro"
 	self:NetworkVar( "String", 1, "Branch" ) --the branch inside said script that we want to override, i.e. "begin" or "m1"
	self:NetworkVar( "String", 2, "Command") --the actual command we're inserting, built from the rest of the info this entity has been given
 	self:NetworkVar( "Int", 0, "BranchNumber" ) --where we want to insert our camera. 0 is at the start of the branch, -1 is the end, otherwise we're replacing the nth camera call
 	self:NetworkVar( "Int", 1, "FOV" ) --the FOV we want this override to use. 0 means don't override FOV
 	--self:NetworkVar( "Bool", 0, "IsTween" ) --do we want a tweencam rather than a setcam?
 	--self:NetworkVar( "Float", 0, "TweenTime" ) --if we're tweening, our tween time
end

function ENT:KeyValue(key, value)
	if key == "script" then
		self:SetScript(value)
	elseif key == "branch" then
		self:SetBranch(value)
	elseif key == "branchnumber" then
		self:SetBranchNumber(tonumber(value))
	elseif key == "fov" then
		self:SetFOV(tonumber(value) or 0)
	elseif key == "istween" then
		self.IsTween = tobool(value)
	elseif key == "tweentime" then
		self.TweenTime = tonumber(value)
	end
end

function ENT:Initialize()
	if SERVER then
		--build our command string "tweencam [tweentime] [pos];[ang] [fov]" or "setcam [pos];[ang] [fov]"
		--we're leaving out the labels for space saving (they get removed while being processed and no one's gonna be reading these anyway)
		--we're also not doing "*tweencam...*"/"*setcam...*" in case the camera call is inside of a block
		local command = (self.IsTween and self.TweenTime) and "tweencam " .. tostring(self.TweenTime) .. " " or "setcam "
		local fov = self:GetFOV() ~= 0 and (" " .. tostring(self:GetFOV())) or ""
		self:SetCommand(command .. tostring(self:GetPos()) .. ";" .. tostring(self:GetAngles()) .. fov)
	end
	--print(self:GetScript().."."..self:GetBranch().. ": *"..self:GetCommand().."* ("..self:GetBranchNumber()..")")
	self:SetModel("models/editor/camera.mdl")
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(false)
end

--should always network scene view overrides
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:Draw()
end
