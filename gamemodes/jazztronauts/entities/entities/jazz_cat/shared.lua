local chatmenu = include("sh_chatmenu.lua")

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.AutomaticFrameAdvance = true

ENT.Model = "models/andy/cats/cat_bartender.mdl"
ENT.IdleAnim = "idle"

if SERVER then
	util.AddNetworkString("JazzPlayScript")
end

local hubtrolleybugme = GetConVar("jazz_barhop_allow")

local function ClientRun(ply, str) if SERVER then ply:SendLua(str) else RunString(str, "JazzChatMenu") end end

function ENT:SetupDataTables()
	self:NetworkVar("Int", "NPCID")
	self:NetworkVar("String", "HubInfo")
end

function ENT:SetupChatTables()
	self.ChatChoices = {}
	if self:GetNPCID() == missions.NPC_CAT_BAR then
		self.ChatChoices.WelcomeText = "#jazz.store.welcome"
		chatmenu.AddChoice(self.ChatChoices, "#jazz.store.upgrade", function(self, ply) ClientRun(ply, "jstore.OpenUpgradeStore()") end)
		chatmenu.AddChoice(self.ChatChoices, "#jazz.store.store", function(self, ply) ClientRun(ply, "jstore.OpenStore()") end)
		chatmenu.AddChoice(self.ChatChoices, "#jazz.store.chat", function(self, ply) self:StartChat(ply) end)
		--add option for switching this map to be the hub
		timer.Simple(1, function()
			local selector = ents.FindByClass("jazz_hub_selector")[1]
			if not IsValid(self) or not IsValid(selector) or not hubtrolleybugme:GetBool() then return end
			
			if self:GetHubInfo() ~= selector:GetHubInfo() then
				chatmenu.AddChoice(self.ChatChoices, "#jazz.store.hub", function(self, ply)
					local script = "hub.begin"
					if SERVER then
						dialog.Dispatch(script, ply, self)
					else
						net.Start("JazzPlayScript")
							net.WriteEntity(self)
							net.WriteString(script)
						net.SendToServer()
					end
				end)
			end
		end)
	else
		--self.ChatChoices.WelcomeText = ""
		--chatmenu.AddChoice(self.ChatChoices, "Let's chat!", function(self, ply) self:StartChat(ply) end)
	end
end

net.Receive("JazzPlayScript", function(len, ply)
	local cat = net.ReadEntity()
	local script = net.ReadString()

	if IsValid(cat) then
		dialog.Dispatch(script, ply, cat)
	end
end )

function ENT:GetIdleScript()
	local npcidle = "idle.begin" .. self.NPCID
	return dialog.IsScriptValid(npcidle) and npcidle or "idle.begin"
end

function ENT:StartChat(ply)
	if SERVER then
		local script = converse.GetNextScript(ply, self.NPCID)
		script = dialog.IsScriptValid(script) and script or self:GetIdleScript()
		//REMOVE:
		//script = "dunked.begin"
		dialog.Dispatch(script, ply, self)
	else
		net.Start("JazzRequestChatStart")
			net.WriteEntity(self)
		net.SendToServer()
	end
end

-- Adjust bounds depending on sequence
function ENT:AdjustBounds()

	local mins, maxs = self:GetModelBounds()

	local anim = self:GetSequenceName(self:GetSequence())

	local table adjustments = {}

	--set our default function
	local default = function(mins, maxs)
		--removing tail collision
		mins.x = mins.x * 0.5
		return mins, maxs
	end

	-- flip our bounds if we're hanging
	adjustments["pose_hangingout"] = function(mins, maxs)
		mins.x = mins.x * 0.5
		maxs.z = maxs.z * -1
		return mins, maxs
	end

	--squish and stretch if we're passed out
	adjustments["pose_passedout"] = function(mins, maxs)
		mins.x = mins.x * 0.5
		maxs.x = maxs.x * 3.5
		mins.y = mins.y * 0.75
		maxs.y = maxs.y * 1.125
		maxs.z = maxs.z * 0.175
		return mins, maxs
	end

	--squish and stretch if we're napping
	adjustments["pose_napping"] = function(mins, maxs)
		mins.x = mins.x * 0.5
		--maxs.x = maxs.x * 3.5
		mins.y = mins.y * 1.75
		--maxs.y = maxs.y * 1.125
		maxs.z = maxs.z * 0.25
		return mins, maxs
	end

	--squish and stretch if we're relaxed
	adjustments["pose_relax"] = function(mins, maxs)
		mins.x = mins.x * 0.625
		maxs.x = maxs.x * 0.625
		maxs.z = maxs.z * 0.5
		maxs.y = maxs.y * 2.5
		return mins, maxs
	end

	--squish if we're sitting
	adjustments["pose_sit01"] = function(mins, maxs)
		mins.x = mins.x * 0.5
		maxs.z = maxs.z * 0.75
		return mins, maxs
	end

	--squish if we're sitting at the bar
	adjustments["pose_sit02"] = function(mins, maxs)
		mins.x = mins.x * 0.25
		maxs.z = maxs.z * 0.75
		return mins, maxs
	end

	if adjustments[anim] ~= nil then
		return adjustments[anim](mins, maxs)
	else
		return default(mins, maxs)
	end
end