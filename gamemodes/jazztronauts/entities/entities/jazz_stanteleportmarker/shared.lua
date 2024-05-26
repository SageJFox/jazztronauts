--this entity does two things for us: Exists both server and clientside, and doesn't move (while the actual teleport entity might)

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.Sign1Text = ""
ENT.Sign2Text = ""
ENT.BaseMaterial = Material("models/props_bar/jazz_streetsign_blanksigns.png","vertexlitgeneric noclamp ignorez")
ENT.screen_rt = nil --irt.New("jazz_stanteleportmarkersign", destRTWidth, destRTHeight )
ENT.destRTWidth = 512
ENT.destRTHeight = 64

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Ducked" ) --should the player teleporting here be ducked, or for busmarker: if sign is selected
	self:NetworkVar( "Bool", 1, "BusMarker" ) --Use for Bus Summoner Deep Dive rather than Stan
	self:NetworkVar( "Bool", 2, "DeletedRetry" ) --see superhack, only retry once (and prevent spam on shutdown)
	self:NetworkVar( "Entity", 0, "Destination" ) --where the actual teleport entity is, or info_landmark for busmarker
	self:NetworkVar( "String", 0, "DestinationName" ) --name of our teleporter entity, or combined sign text on busmarker
	self:NetworkVar( "Float", 0, "Level" ) --Level required by Upgrade to use --busmarker uses 99 for unused, 100 used
end

if CLIENT then

	--local destRTWidth = 512
	--local destRTHeight = 64
	--local screen_rt = irt.New("jazz_stanteleportmarkersign", destRTWidth, destRTHeight )
	--local baseMaterial = Material("models/props_bar/jazz_streetsign_blanksigns.png","vertexlitgeneric noclamp ignorez")
	
	surface.CreateFont( "JazzRoadwaySigns", {
		font = "JazzRoadway",
		size = 40,
		weight = 500,
		antialias = true,
	} )

	function ENT:DrawRTScreen()
		if not self:GetBusMarker() or not self.screen_rt then return end
		self.screen_rt:Render(function()
			cam.Start2D()
				render.Clear(0,0,0,0,true,true)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(self.BaseMaterial)
				surface.DrawTexturedRect(0, 0, self.destRTWidth, self.destRTHeight)

				surface.SetFont("JazzRoadwaySigns")
				local w, h = surface.GetTextSize(self.Sign1Text)
				local w2, h2 = surface.GetTextSize(self.Sign2Text)
				local mwidth = 194 --max width of one sign text
				local mat = Matrix()
				if w > mwidth then
					mat:Scale(Vector(mwidth/w, 1, 1))
				else
					mat:Translate(Vector(mwidth/2 - w/2, 0, 0))
				end
				local mat2 = Matrix()
				if w2 > mwidth then
					mat2:Scale(Vector(mwidth/w2, 1, 1))
				else
					mat2:Translate(Vector(mwidth/2 - w2/2, 0, 0))
				end

				cam.PushModelMatrix(mat)
					draw.SimpleText(self.Sign1Text, "JazzRoadwaySigns", 31, 13, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				cam.PopModelMatrix()
				cam.PushModelMatrix(mat2)
					draw.SimpleText(self.Sign2Text, "JazzRoadwaySigns", 287, 13, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				cam.PopModelMatrix()

			cam.End2D()
		end)
	end

	--local signmat = self.screen_rt:GetVertexLitMaterial(false,true)

	--our edit of Roadway has small numbers at these characters
	smallnumbers = {
		["0"] = "º",
		["1"] = "¹",
		["2"] = "²",
		["3"] = "³",
		["4"] = "¼",
		["5"] = "½",
		["6"] = "¾",
		["7"] = "©",
		["8"] = "ª",
		["9"] = "®"
	}

	--with multiple chunks, anything three characters or less in the first chunk will be assumed to be a prefix. These are also prime candidates.
	--making list very complete to assume we get map pack interplay and/or Bar bus stop support added too
	prefix = {
		["^JAZZ$"] = true, --hey that's us!
		--["^TTT$"] = true,
		["^TEST$"] = true,
		--["^SDK$"] = true,
		["^SURF$"] = true,
		["^PUZZLE$"] = true,
		["^RATS$"] = true,
		["^JAIL$"] = true,
		["^GMDM$"] = true,
		["^TRASH$"] = true,
		["^CINEMA$"] = true,
		["^PROTO$"] = true,
		["^KILLBOX$"] = true,
		--CS
		["^COOP$"] = true,
		--common custom CS
		["^BHOP$"] = true,
		["^CSDE$"] = true,
		["^FUN$"] = true,
		["^NADE$"] = true,

		--Episodes
		--["^EP1$"] = true,
		--["^EP2$"] = true,
		--DOD:S
		--["^DOD$"] = true,
		--TF2
		--["^CTF$"] = true,
		["^KOTH$"] = true,
		--["^PLR$"] = true,
		--["^MVM$"] = true,
		["^ARENA$"] = true,
		--["^VSH$"] = true,
		["^PASS$"] = true,
		--common custom TF2
		["^TRADE$"] = true,
		["^IDLE$"] = true,
		["^JUMP$"] = true,
		["^DUEL$"] = true,
		["^KOTF$"] = true,
		["^CORE$"] = true,
		["^ACHIEVEMENT$"] = true,
		["^SLENDER$"] = true,
		["^TF2WARE$"] = true,
		["^TF2?KART$"] = true,
		--L4D/2
		--["^L4D$"] = true,
		["^C%d+M%d+$"] = true, --fuck it, pattern time
		["^TUTORIAL$"] = true,
		--Fisty Frags
		--["^FOF$"] = true,
		["^FOFHR$"] = true,
		--other/misc
		--["^SYN$"] = true,
		["^ASI$"] = true,
		["^DIPRIP$"] = true,
	}

	--and suffixes (i.e. in the last chunk), which are a little harder to natually spot anyway. Think we *will* stick to two or less for an auto assumption
	suffix = {
		["^%d+[AB]?$"] = true, --HL2 + Episodes
		["^FINAL%d*%a*$"] = true, --final (it's never final)
		["^RC%d*%a*$"] = true, --release candidate
		["^V%d+%a*$"] = true, --version number
		["^%a%d+%a*$"] = true, --Alpha, Beta, etc.
		--TF2
		["^RATS$"] = true,
		["^EVENT$"] = true,
		["^INVASION$"] = true,
		["^SNOWY$"] = true,
		["^WINTER$"] = true,
		--misc custom
		["^HRCS$"] = true,
	}

	--processing the map name for use with our font
	function ProcessMapName(name)
		local tab = string.Split( string.upper(name), "_" )
		if table.IsEmpty(tab) then return "" end
		if #tab == 1 then tab = string.Split( string.upper(name), " " ) end -- no underscores, try spaces
		if #tab == 1 then return tab[1] end -- no separators, that's yer lot

		local suptext = function(text)
			local text = string.lower(text)
			for k, v in pairs(smallnumbers) do
				text = string.Replace(text,k,v)
			end
			return text
		end

		local checkchunk = function(chunk,checktab,min)
			if #chunk <= min then return suptext(chunk) end --if we're below our minimum amount, assume it's a prefix/suffix
			for k, _ in pairs(checktab) do
				if string.match(chunk,k) then
					return suptext(chunk)
				end
			end
			return chunk
		end

		--the actual processing, checking the first and last bits for prefix/suffix
		local prefix1, suffix1 = checkchunk(tab[1], prefix, 3), checkchunk(tab[#tab],suffix,2)
		--if we have more than three map chunks, we'll try them all
		local foundstart, foundend = false, false
		if #tab > 3 then
			if tab[1] ~= prefix1 then
				--print(#tab,"total chunks")
				for i = 2, #tab - 1 do
					local try = checkchunk(tab[i], prefix, 3)
					if tab[i] == try then break end
					--print("prefix:",tab[i],try)
					tab[i] = try
				end
			end
			if tab[#tab] ~= suffix1 then
				for i = 2, #tab - 1 do
					local try = checkchunk(tab[#tab + 1 - i], suffix, 2)
					if tab[#tab + 1 - i] == try then break end
					--print(i,"suffix:",#tab + 1 - i,tab[#tab + 1 - i],try)
					tab[#tab + 1 - i] = try
				end
			end
		end
		--if we have three or more chunks, or our first chunk wasn't a prefix, try suffix
		if #tab > 2 or tab[1] == prefix1 then tab[#tab] = suffix1 end
		tab[1] = prefix1

		--slap it back together
		return table.concat(tab," ")
	end

	-- local test = {
	-- 	"dm_juicyasszone",
	-- 	"gm_the_book_of_henry_v2c",
	-- 	"koth_sawmill_final2",
	-- 	"nobody told me this was a map",
	-- 	"jazz_pyramid_head",
	-- 	"diprip_vroom_vroom_v8",
	-- 	"the best map ever a4c",
	-- 	"the best map ever v2 a4c",
	-- }
	-- for _, v in ipairs(test) do
	-- 	print(v,ProcessMapName(v))
	-- end
	
	local material = Material( "sprites/light_glow02_add_noz" )
	local red = Color( 255, 0, 0 )

	function ENT:Draw()
		if self:GetBusMarker() then
			--self:DrawRTScreen()
			if self:GetDucked() and self:GetLevel() == 99 then
				self:SetSkin( CurTime() - math.floor(CurTime()) < 0.5 and 1 or 2 )
			elseif self:GetLevel() == 99 then -- using level 99 as code for unused, 100 is used
				self:SetSkin(0)
			else
				self:SetSkin(3)
			end

			jazzvoid.SetupVoidLighting(self)
			if self.screen_rt then
				render.MaterialOverrideByIndex(3, self.screen_rt:GetVertexLitMaterial(false,true))
			else
				self.screen_rt = irt.New("jazz_stanteleportmarkersign" .. tostring(self:EntIndex()), self.destRTWidth, self.destRTHeight )
				self:DrawRTScreen()
			end
			self:DrawModel()
			render.MaterialOverrideByIndex(1, nil)

			render.SuppressEngineLighting(false)
			--draw glowsprites
			render.SetMaterial( material )
			if self:GetSkin() % 2 ~= 0 then --1 & 3

				local pos = self:GetAttachment(self:LookupAttachment("light1")).Pos
				--render.SetBlend( util.PixelVisible(pos,16,util.GetPixelVisibleHandle()) ) --we love bug #3166
				render.DrawSprite( pos, 16, 16, red)
			end
			if self:GetSkin() > 1 then --2 & 3
				local pos = self:GetAttachment(self:LookupAttachment("light2")).Pos
				--render.SetBlend( util.PixelVisible(pos,16,util.GetPixelVisibleHandle()) )
				render.DrawSprite( pos, 16, 16, red)
			end
			--render.SetBlend(1)

		end
	end

	--for some reason the sign's texture portion (but not text) likes to get fucked up if we don't have some alternative 2D render context going with it
	--it works with the snatcher being out or with the feed showing, if the menu isn't present, or with the camera swep regardless of menu being open, it typically works in the void, or halos
	--so fuck it, add invisible halos to them, I can't figure out a proper fix
	--also sorry if any of this doesn't work for you in any horrible fashion, at this point it works for me
	hook.Add("PreDrawHalos","jazzfixthisstupidfuckingbug",function()
		halo.Add(ents.FindByClass("jazz_stanteleportmarker"),color_black,0,0,1,true,false)
	end)

end

function groundHit(pos,adjust)
	--local adjust = adjust or vector_origin
	
	local tr = util.TraceLine( {
		start = pos,
		endpos = pos + Vector(0, 0, -32767),
		filter = function(ent)
			if ent:IsWorld() then return true end
			if ent:IsPlayer() then return false end
			if ent:IsNPC() then return false end
			if ent:IsNextBot() then return false end
			if ent:GetClass() == "jazz_stanteleportmarker" then return false end
			if ent:IsSolid() then return true end
		end,
		mask = MASK_NPCSOLID
	} )
	local vec = nil
	if tr.Hit then
		vec = Vector(tr.HitPos)
		--vec.z = vec.z + adjust.z
	else
		vec = pos
	end
	return vec
end

function ENT:Initialize()
	self:SetModel("models/props_bar/streetsign.mdl")
	self:SetCollisionGroup(self:GetBusMarker() and COLLISION_GROUP_DEBRIS_TRIGGER or COLLISION_GROUP_IN_VEHICLE)
	self:DrawShadow(self:GetBusMarker())

	if self:GetBusMarker() then
		self:SetBodygroup(1,1)
		self.RenderGroup = RENDERGROUP_OPAQUE
		if SERVER then
			self:SetPos( groundHit( self:GetPos(), Vector(0, 0, -0.25) ) )
			self:PhysicsInit(SOLID_VPHYSICS)
		end
		local signnames = string.Split(self:GetDestinationName(),":")
		self.Sign1Text = ProcessMapName and ProcessMapName(signnames[1]) or signnames[1]
		self.Sign2Text = ProcessMapName and ProcessMapName(signnames[2]) or signnames[2]
		--[[if CLIENT then
			self.screen_rt = irt.New("jazz_stanteleportmarkersign" .. tostring(self:EntIndex()), self.destRTWidth, self.destRTHeight )
			self:DrawRTScreen()
		end]]
		--print(self.Sign1Text,":",self.Sign2Text,self:GetPos())
	end
	if SERVER then self:NextThink( CurTime() + 1 ) end
end

function ENT:Think()
	if SERVER and not IsValid(self:GetDestination()) then self:Remove() end
	if CLIENT and self:GetBusMarker() then self:DrawRTScreen() end
	self:NextThink( CurTime() + 3 ) --not super concerned with running this often
	return true
end

--should always network teleport markers
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove(fullupdate)
	if worldmarker then
		worldmarker.SetEnabled(self,false)
	end
	--superhack for HL2's citadel 4 map
	if SERVER and self:GetBusMarker() and not self:GetDeletedRetry() then
		--print("HACKHACK")
		local busmark = ents.Create("jazz_stanteleportmarker")
		if not IsValid(busmark) then return end
		busmark:SetDucked(self:GetDucked())
		busmark:SetBusMarker(self:GetBusMarker())
		busmark:SetDestination(self:GetDestination())
		busmark:SetDestinationName(self:GetDestinationName())
		busmark:SetLevel(self:GetLevel())
		busmark:SetDeletedRetry(true) --just try once
		busmark:Spawn()
		busmark:Fire("AddOutput","classname prop_combine_ball",0,self,busmark)
		busmark:Fire("AddOutput","targetname jazzWHATTHEFUCKWHY",0,self,busmark)
		busmark:SetPos(self:GetPos())
	end
end