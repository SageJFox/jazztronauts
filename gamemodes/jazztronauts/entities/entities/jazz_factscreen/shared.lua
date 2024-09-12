
-- Board that displays currently selected map's factoids
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model =  "models/sunabouzu/jazz_tv01.mdl"
ENT.ModelScale =  1
ENT.IdleAnim = "idle"

local SF_INVISIBLE_WHEN_OFF = 1

function ENT:SetupDataTables()
	self:NetworkVar("Int", "FactID")
	self:NetworkVar("Float", "ToggleDelay")
	self:NetworkVar("Entity", "Selector")
	self:NetworkVar("Int", "RTMat")
	if SERVER then
		self:SetRTMat(1)
	end
end

if SERVER then
	util.AddNetworkString("JazzFactScreenUpdate")

	local outputs =
	{
		"OnFactDisplayed",
		"OnFactRemoved"
	}

	net.Receive("JazzFactScreenUpdate",function()
		local self = net.ReadEntity()
		if IsValid(self) then
			self:TriggerOutput(net.ReadBool() and "OnFactDisplayed" or "OnFactRemoved", self)
		end
	end)
	
	function ENT:Initialize()

		self:SetModel(self.Model)
		self:SetModelScale(self.ModelScale)
		--self:PhysicsInit(SOLID_VPHYSICS)
		--self:SetMoveType(MOVETYPE_NONE)
		self:SetSelector(ents.FindByClass("jazz_hub_selector")[1])

		local id = math.random(1, 1000)
		if self.FactName and self.FactName ~= "" then
			--check for list
			local facts = string.Explode( "%s*,%s*", string.Trim(self.FactName), true )
			local removefacts = {}
			for k, fact in ipairs(facts) do
				--we wanna remove the fact instead of add
				if string.sub( fact, 1, 1 ) == "-" then
					--if we're removing some, we need the full set in our list
					if #removefacts == 0 then
						table.Add( facts, {
							"ws_owner",
							"ws_views",
							"ws_filesize",
							"ws_favorites",
							"ws_subscriptions",
							"ws_upload_date",
							"ws_update_date",
							"ws_screenshots",
							"ws_tags",
							"comment",
							"map_size",
							"skybox",
							"map_comment",
							"brush_count",
							"static_props",
							"entity_count",
							"map_name"
						} )
					end
					table.insert( removefacts, string.sub( fact, 2 ) )
					table.remove(facts, k)
				end
			end
			--actually removing the blacklisted facts
			for _, v in ipairs(removefacts) do
				table.RemoveByValue( facts, v )
			end
			--pick one
			local fact = facts[math.random(#facts)]
			id = factgen.GetFactIDByName(fact .. (fact == "comment" and tostring(self:EntIndex() % 10) or ""), true)
		else
			id = self:EntIndex()
		end

		self:SetFactID(id)
	end

	function ENT:KeyValue(key, value)
		if key == "model" then
			self.Model = value
		elseif key == "modelscale" then
			self.ModelScale = tonumber(value) or 1
		elseif key == "skin" then
			self:SetSkin(tonumber(value))
		elseif key == "DefaultAnim" then
			self.IdleAnim = value
		elseif key == "factname" then
			self.FactName = value
		elseif key == "rtmat" then
			self:SetRTMat(tonumber(value) or 1)
		elseif key == "disableshadows" then
			self:DrawShadow(not tobool(value))
		end
		
		if table.HasValue(outputs, key) then
			self:StoreOutput(key, value)
		end
	end

	
	function ENT:AcceptInput( name, activator, caller, data )

		if name == "Skin" then self:SetSkin(tonumber(data)) return true end

		if name == "SetIdle" then self:SetIdleAnim(tostring(data)) return true end

		if name == "SetModelScale" then self:SetModelScale(tonumber(data) or 1, 0.00001) return true end

		return false
	end

	function ENT:SetIdleAnim(anim)
		self.IdleAnim = anim
	
		self:ResetSequence(self:LookupSequence(self.IdleAnim))
	
		self:SetPlaybackRate(1.0)
	end
	

	local function UpdateToggleDelay()
		local screens = ents.FindByClass("jazz_factscreen")
		table.sort(screens, function(a, b)
			local apos, bpos = a:GetPos(), b:GetPos()
			return apos.x < bpos.x
		end )

		for k, v in ipairs(screens) do
			v:SetToggleDelay(k * 0.05)
		end
	end

	-- Setup toggle delay on all fact screens
	hook.Add("InitPostEntity", "InitFactscreenDelays", UpdateToggleDelay)
	hook.Add("OnReloaded", "InitFactscreenDelaysReload", UpdateToggleDelay)
	UpdateToggleDelay()

	return
end

local RTWidth = 512
local RTHeight = 512
local VisibleHeight = 0.5

local LoadingMaterial = Material("ui/jazztronauts/testpattern")

local lastFactUpdate = 0

surface.CreateFont( "FactScreenFont", {
	font	  = "VCR OSD Mono",
	size	  = 35,
	weight	= 700,
	antialias = false
})
surface.CreateFont( "FactScreenTitle", {
	font	  = "VCR OSD Mono",
	size	  = 55,
	weight	= 700,
	antialias = false
})
surface.CreateFont( "FactScreenError", {
	font	  = "VCR OSD Mono",
	size	  = 25,
	weight	= 700,
	antialias = false
})

-- Render a test pattern that actually fits on these monitors
local TestSize = 64
local loadRT = irt.New("jazzfact_testpattern", TestSize, TestSize)
	:EnablePointSample(true)
loadRT:Render( function()
	cam.Start2D()
		surface.SetMaterial(LoadingMaterial)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(0, TestSize * 0.2, TestSize, TestSize * 0.6)
	cam.End2D()
end )
local loadMaterial = loadRT:GetUnlitMaterial()

-- Render a specific fact
local factMaterials = {}
local isOn = false
local function renderFact(rt, f, title, bgcolor, font)

	rt:Render( function()
		local mostr = "<font=" .. (font or "FactScreenFont") ..">" .. jazzloc.Localize(f.fact) .. "</font>"
		mostr = string.Replace(mostr,"‚",",") --replaces U+201A "Single Low-9 Quotation Mark" with comma (we're done with localization, commas are safe again)
		local mo = markup.Parse(mostr, RTWidth * 0.98)

		cam.Start2D()

			surface.SetDrawColor(bgcolor or Color(205, 20, 105))
			surface.DrawRect(0, 0, 512, 512)
			surface.SetTextColor(0, 0, 0)
			surface.SetFont("FactScreenFont")
			draw.SimpleText(jazzloc.Localize(title or ""), "FactScreenTitle", RTWidth/2, RTHeight * 0.28, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			mo:Draw(RTWidth/2 - mo:GetWidth()/2, VisibleHeight * RTHeight - mo:GetHeight()/2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		cam.End2D()
	end )
end

local function setDHTMLPic(dhtml, pic)
	local str =[[
		<head>
		<style>
			body
			{
				background-image: url("%s");
				background-color: #000000;
				background-size: contain;
				background-repeat: no-repeat;
				background-position: center center;
			}
		</style>
		</head>
		<body></body>
	]]

	dhtml:SetHTML(string.format(str, pic))
end

-- Specific rendering for a slideshow of pictures
local slideshowRT = nil
local slideshowPics = {}
jazzSlideshowDHTML = jazzSlideshowDHTML or nil --#TODO MAKE LOCAL YOU FUCK
local lastPic = nil
local function renderSlideshow()
	if not isOn or not slideshowRT or not jazzSlideshowDHTML then return end

	local pic = slideshowPics[(math.Round(CurTime() * 0.5) % #slideshowPics) + 1]
	if lastPic != pic then
		lastPic = pic
		setDHTMLPic(jazzSlideshowDHTML, pic)
	end
	jazzSlideshowDHTML:UpdateHTMLTexture()
	slideshowRT:Render(function()
		local slideMat = jazzSlideshowDHTML:GetHTMLMaterial()
		if not slideMat then return end

		cam.Start2D()
			surface.SetDrawColor(255, 1, 255)
			surface.DrawRect(0, 0, RTWidth, RTHeight)

			surface.SetMaterial(slideMat)
			surface.DrawTexturedRectUV(0, 0, RTWidth, RTHeight, 0, 0, 1, 1)

		cam.End2D()
	end)
end

hook.Add("Think", "UpdateJazzSlideshow", renderSlideshow)

local function loadMapScreenshots(rt, f)
	slideshowRT = rt
	slideshowPics = string.Split(f.fact, "|")
	jazzSlideshowDHTML = jazzSlideshowDHTML or vgui.Create("DHTML")
	jazzSlideshowDHTML:SetSize(512, 512)
	jazzSlideshowDHTML:SetAlpha(0)
end

local safety = GetConVar("jazz_safety_mode")

local function loadOwner(rt, f)
	steamworks.RequestPlayerInfo(f.fact, function(name)
		f.fact = name or f.fact
		if math.Round(safety:GetFloat()) > 0 then f.fact = string.gsub(f.fact,"%S","█") end
		renderFact(rt, f, "jazz.fact.owner")
	end )
end

local commentformat = "^" .. string.Trim(jazzloc.Localize("jazz.fact.comment","(.-)","(.-)")) .. "$"

local function commentfunc(rt, f)
	if math.Round(safety:GetFloat()) <= 0 then renderFact(rt,f) end --skip processing if not needed
	local newf = {
		["id"] = f.id,
		["name"] = f.name
	}
	local _, _, comm, auth = string.find(f.fact, commentformat)

	if not (comm or auth) then renderFact(rt,f) end --abort!

	if math.Round(safety:GetFloat()) == 2 then comm = string.gsub(comm,"%S","█") end
	if math.Round(safety:GetFloat()) >= 1 then auth = string.gsub(auth,"%S","█") end

	newf.fact = jazzloc.Localize("jazz.fact.comment", comm, auth)

	renderFact(rt,newf)
end

-- Allow some fact names to override what it does when it would otherwise render
local factOverrides = {
	ws_screenshots = loadMapScreenshots,
	ws_owner = loadOwner,
	comment = commentfunc,
	failure = function(rt, f) renderFact(rt, f, nil, Color(136, 12, 12), "FactScreenError") end
}

local function updateFactMaterials()
	local facts = factgen.GetFacts()
	isOn = false
	for k, v in pairs(facts) do
		local factMat = factMaterials[k] or irt.New("jazz_factscreen_" .. k, RTWidth, RTHeight)
		factMaterials[k] = factMat

		-- Only re-render if there's a new fact, not for clearing
		if #v.fact == 0 then continue end

		-- Allow certain facts to do fancy things
		local loadFunc = factOverrides[v.name] or (string.find( v.name, "comment%d+" ) and factOverrides["comment"] ) or function(rt, f)
			local title = string.Split(string.Split(f.fact, "\n")[1], ":")[1]
			f.fact = string.sub(f.fact, (title and #title + 3 or 0))
			renderFact(rt, f, title)
		end
		loadFunc(factMat, v)

		isOn = true
	end
end

-- Whenever the facts update, trigger a re-render of fact materials
-- Additionally activates the screen sweep animation
timer.Simple(0, function()
	factgen.Hook("updateBrowserFactScreens", function()
		lastFactUpdate = CurTime()
		updateFactMaterials()
	end )
end)

function ENT:Initialize()
	self.RTMat = self:GetRTMat() --not changing once set so no need to constantly fetch this
end

function ENT:ShouldShowTestPattern()
	return (not self.CurrentFactMaterial) and (not self:HasSpawnFlags(SF_INVISIBLE_WHEN_OFF))
end

function ENT:Think()
	if not self.LastUpdate or self.LastUpdate < lastFactUpdate then
		local actualUpdateTime = lastFactUpdate + self:GetToggleDelay()
		if CurTime() > actualUpdateTime then
			self.LastUpdate = lastFactUpdate

			self:UpdateFactMaterial()
		end
	end
end

function ENT:GetRealFactID()
	local active = factgen.GetActiveFactIDs()
	if active[self:GetFactID()] then
		return self:GetFactID()
	end

	for i=1, table.Count(active) do
		local k = 1 + (self:GetFactID() + i) % #active
		if active[k] then return k end
	end

	return 0
end

function ENT:UpdateFactMaterial()
	self.CurrentFactMaterial = isOn and factMaterials[self:GetRealFactID()]
	self:EmitSound("ui/buttonclick.wav", 75, 200, 1)
	net.Start("JazzFactScreenUpdate")
		net.WriteEntity(self)
		net.WriteBool(isOn)
	net.SendToServer()
end

function ENT:Draw()
	local curMat = self.CurrentFactMaterial and self.CurrentFactMaterial:GetUnlitMaterial() or nil
	if self:ShouldShowTestPattern() then
		curMat = loadMaterial
	end
	if curMat then
		render.MaterialOverrideByIndex(self.RTMat, curMat)
		self:DrawModel()
		render.MaterialOverrideByIndex(self.RTMat, nil)
	end
end
