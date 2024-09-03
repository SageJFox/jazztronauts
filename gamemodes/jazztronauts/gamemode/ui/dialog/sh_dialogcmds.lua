AddCSLuaFile()

module("dialog", package.seeall)

local hubtrolleybugme = CreateConVar("jazz_barhop_allow",1,bit.bor(FCVAR_ARCHIVE,FCVAR_REPLICATED),"Allow dialog prompt for a Barhop.\n"..
"A Barhop is available when the server gets onto a valid Jazztronauts hub map with settings defined that don't match the server's setup.\n"..
"For example, if a hub map was found on the level browser and visited, or if a custom trolley is defined that doesn't match the current hub.\n"..
"When enabled and appropriate, the Bartender will have a dialog option to switch the various settings in-line with the map's.\n"..
"(Note that users must be super admins to actually act on this dialog.) Set to 0 if you don't want this option present.")

-- Use of the map trigger command must be on entity names prefixed with this
local mapTriggerPrefix = "jazzio_"

-- If we want our various set commands to print scene root conversions to console
local RUN_CONVERSION = true

local maxLocalesUInt = 3 -- 2^3 = 8 max locales

--only act on these convars, anything else is off limits!
local convaraccepted = {
	["jazz_hub"] = 1,
	["jazz_hub_outro"] = 2,
	["jazz_hub_outro2"] = 3,
	["jazz_trolley"] = 4,
}

if SERVER then
	util.AddNetworkString( "dialog_requestcommand" )

	net.Receive("dialog_requestcommand", function(len, ply)
		if not IsValid(ply) or not mapcontrol.IsInGamemodeMap() then
			ErrorNoHalt("Dialog map triggers only work within jazztronaut gamemode maps!")
			return
		end
		local entName = net.ReadString()
		local inp = net.ReadString()
		local delay = net.ReadFloat()
		local param = net.ReadString()

		if string.sub(entName, 0, #mapTriggerPrefix) != mapTriggerPrefix then
			ErrorNoHalt("Dialog map triggers only work on entities prefixed with \"" .. mapTriggerPrefix .. "\"")
			return
		end

		local entities = ents.FindByName(entName)
		for _, v in pairs(entities) do
			v:Fire(inp, param, delay)
		end
	end )

	util.AddNetworkString( "dialog_requestsetconvar" )


	net.Receive("dialog_requestsetconvar", function(len, ply)
		if not hubtrolleybugme:GetBool() then return end
		if not IsValid(ply) then return end

		--script tries to prevent non-admins from using this, but if they get cheeky with jazz_debug_runscript stop'em
		local admin = net.ReadEntity()
		if not IsValid(admin) or not admin:IsPlayer() or not admin:IsSuperAdmin() then
			ErrorNoHalt("Convars can only be set by super admins!")
			return
		end
		-- only do this once (i.e. on the player who sent it)
		if ply ~= admin then return end

		local command = net.ReadString()
		local value = net.ReadString()

		--At least pretend like we're doing this safely (let's be real if someone wants to fuck your server up, they probably aren't doing it here)
		if not isnumber(convaraccepted[command]) then
			ErrorNoHalt("Script attempted to request illegal convar \"" .. command .. "\"!")
			return
		end

		if not ConVarExists(command) then
			ErrorNoHalt("Convar \"" .. command .. "\" doesn't exist!")
			return
		end
		local convar = GetConVar(command)
		convar:SetString(value)
	end )

	util.AddNetworkString( "dialog_requestpvs" )
	net.Receive("dialog_requestpvs", function(len, ply)
		if not IsValid(ply) or not mapcontrol.IsInGamemodeMap() then
			print("*setcam* will only add to PVS in gamemode maps!")
			return
		end
		local pos = net.ReadVector()
		ply.JazzDialogPVS = pos
	end )

	util.AddNetworkString("dialog_requestlocale")
	util.AddNetworkString("dialog_returnlocale")

	net.Receive("dialog_requestlocale", function(len, ply)

		if not IsValid(ply) then return end

		local name = net.ReadString()
		if not name then return end

		local count = net.ReadUInt(maxLocalesUInt)
		local tab = {}
		for i = 0, count do
			local str = net.ReadString()
			if not str then return end
			table.insert(tab,str)
		end
		if table.IsEmpty(tab) then return end
		--PrintTable(tab)

		local ent, locale = nil, nil
		for _, v in ipairs(tab) do	
			local enttab = ents.FindByName(v)
			if next(enttab) ~= nil then
				ent = enttab[1]
				locale = v
				break
			end
		end

		local pos = vector_origin
		local ang = angle_zero

		local layers = {0}
		local zSnap = {64}

		if IsValid(ent) then
			pos = ent:GetPos()
			ang = ent:GetAngles()
			if istable(ent.Layers) then
				--print(locale)
				for k, v in ipairs(ent.Layers) do
					if not istable(v) then print("Layers table entry "..tostring(k).." not a table!") continue end
					layers[k] = v.z
					zSnap[k] = v.zsnap
					--print(k,":")
					--PrintTable(v,1)
					--print("\n")
				end
				--print("layers:")
				--PrintTable(layers,1)
				--print("zSnap:")
				--PrintTable(zSnap,1)
			end
		end

		net.Start("dialog_returnlocale")
			net.WriteString(name)
			net.WriteString(tostring(locale))
			--net.WriteEntity(ent)
			net.WriteVector(pos)
			net.WriteAngle(ang)
			net.WriteTable(layers)
			net.WriteTable(zSnap)
		net.Send(ply)
	end )

	hook.Add("JazzDialogFinished", "JazzRemoveDialogPVS", function(ply, script, mark)
		--delay by a bit so we can transition out
		timer.Simple(2, function() if IsValid(ply) then ply.JazzDialogPVS = nil end end)
	end)

	hook.Add("SetupPlayerVisibility", "JazzAddDialogPVS", function(ply, view)
		if ply.JazzDialogPVS then
			AddOriginToPVS(ply.JazzDialogPVS)
		end
	end )

	--set player in scene
	util.AddNetworkString("JazzPlayerInScene")

	net.Receive("JazzPlayerInScene", function(len, ply)
		ply:SetInScene(net.ReadBool(ply.InScene))
	end)

end

if not CLIENT then return end

hook.Add("JazzDialogFinished", "JazzCleanupScenes", function(ply, script, mark)
	--delay by a bit so we can transition out
	timer.Simple(2, function()
		if IsValid(ply) and istable(ply.JazzDialogProxy) then
			if IsValid(ply.JazzDialogProxy.Instance) then ply.JazzDialogProxy.Instance:Remove() end
			ply.JazzDialogProxy = nil
		end
	end)
end)

-- Fires an output on a named entity on the server
-- Try to avoid using this unless specifically needed for something
dialog.RegisterFunc("fire", function(d, entityName, inputName, delay, fireParams)
	if not entityName or not inputName then
		ErrorNoHalt("*fire <entityName> <inputName> [delay] [fireParams]* requires an entity name and input name!")
		return
	end

	net.Start("dialog_requestcommand")
		net.WriteString(entityName)
		net.WriteString(inputName)
		net.WriteFloat(delay or 0)
		net.WriteString(fireParams or "")
	net.SendToServer()
end)


local convardefaults = {
	["jazz_hub"] = "jazz_bar",
	["jazz_hub_outro"] = "jazz_outro",
	["jazz_hub_outro2"] = "jazz_outro2",
	["jazz_trolley"] = "default",
}
-- Requests a convar change for the server
-- Playing with fire
dialog.RegisterFunc("setconvar", function(d, convar, ...)

	if not hubtrolleybugme:GetBool() then return end

	local convar = isstring(convar) and string.lower(convar) or ""

	local value = next({ ... }) ~= nil and table.concat({ ... }, " ") or ""

	--get the value we want
	local selector = ents.FindByClass("jazz_hub_selector")[1]
	if not IsValid(selector) then return end
	local selectorHubInfo = string.Split(selector:GetHubInfo(),":")

	--find the bartender
	local cats, bartender = ents.FindByClass("jazz_cat"), nil
	for _, v in ipairs(cats) do
		if IsValid(v) and v:GetNPCID() == missions.NPC_CAT_BAR then
			bartender = v
			break
		end
	end

	--get the bartender to update the value she's currently holding
	local oldHubInfo = string.Split(bartender:GetHubInfo(),":")
	for k, v in pairs(convaraccepted) do
		if convar == k then
			if not value or value == "" then --no value provided, use selector's
				value = selectorHubInfo[v]
				if not value or value == "" then value = convardefaults[k] end --no selector's, use defaults
			end
			oldHubInfo[v] = value
			break
		end
	end

	bartender:SetHubInfo(table.concat(oldHubInfo,":"))

	--send it over
	net.Start("dialog_requestsetconvar")
		net.WriteEntity(LocalPlayer())
		net.WriteString(convar)
		net.WriteString(value)
	net.SendToServer()

end)

local function parsePosAng(...)
	local args = table.concat({ ... }, " ")
	local posang = string.Split(args, ";")
	local tblPosAng = {}

	if posang[1] and posang[1] ~= "" then
		tblPosAng.pos = Vector(string.Replace(posang[1], "setpos", ""))
	end
	if posang[2] then
		tblPosAng.ang = Angle(string.Replace(posang[2], "setang", ""))
		local fovtest = string.Split(string.TrimLeft(string.Replace(posang[2], "setang", ""))," ")
		if #fovtest > 3 then
			tblPosAng.fov = tonumber(string.Replace(fovtest[4],"fov",""))
		end
	end
	
	return tblPosAng
end

local function FindNPCByName(name)
	local lookid = missions.GetNPCID(name)
	local npcs = ents.FindByClass("jazz_cat")
	for _, v in pairs(npcs) do
		if v.GetNPCID and v:GetNPCID() == lookid then
			return v
		end
	end
	return nil
end

local sceneModels = {}
-- parenting doesn't wanna work nicely, so this list just keeps track of what's supposed to move with what
local sceneRoots = {}
-- rather than have to set the scene root for every model spawned, assume we just wanna use this entity
local defaultRoot = nil
-- locales are points defined in the hub map. This list keeps track of the ones we're using in the current scene.
local sceneLocales = {}
-- z snap is how far up or down a character will be adjusted on the Z axis in order to appear standing on the ground. 0 or less to disable
local zSnap = { {64} }
--[[ layers are different heights for potentially different ground levels. They each have their own zSnap.
	This allows us to, say, put one character on top of the bar while another character is seated at it.
	(zSnap on its own would either put both characters on top of the bar or both below it depending on how large it was set)
	layers are defined by the locale entity in order to remain flexible for map makers. If a necessary layer isn't defined there, it is assumed 0. 
	The first layer is always defined by the position of the locale entity (and is thus always 0). The rest are defined in relation to it. ]]
local layers = { {0} }
--TODO - cleanup: zSnap and layers are always utilized in matching pairs, should probably eventually put them together into one table of tables... of tables.

local function FindByName(name,skipPlayerCreate)
	local skipPlayerCreate = skipPlayerCreate or false
	if (not name) or name == "nil" then return nil end
	if name == "focus" then return dialog.GetFocus() end
	if IsValid(sceneModels[name]) then return sceneModels[name] end

	-- Lazy-create player object
	if name == "player" then
		if not skipPlayerCreate then
			local plyobj = CreatePlayerProxy()
			sceneModels[name] = plyobj
			g_funcs["setlook"]("setlook","player") --reset player look
			plyobj.gravity = true
			plyobj.layer = 1
			return plyobj
		else
			return sceneModels["player"]
		end
	end

	return FindNPCByName(name)
end

dialog.RegisterFunc("spawnplayer", function(d)
	FindByName("player")
end)

dialog.RegisterFunc("sceneroot", function(d, name)
	defaultRoot = sceneModels[name] or nil
end)

--these next two are more "in-dev" commands than actually meant to stay used. Ideally we get these values from the maps themselves.
--set force *only* for dev stuff, it overrides the values from the map!
dialog.RegisterFunc("zsnap", function(d, amount, layer, locale, force)
	local layer = tonumber(layer) or 1
	local locale = locale or 1
	if not zSnap[locale] then zSnap[locale] = {} end
	if force or not zSnap[locale][layer] or zSnap[locale][layer] == 64 then
		zSnap[locale][layer] = tonumber(amount) or 0
	end
	if not layers[locale] then layers[locale] = {} end
	layers[locale][layer] = layers[locale][layer] or 0
	--print("Wow look we set zSnap on layer "..layer.." at locale "..tostring(locale).." to "..zSnap[locale][layer])
end)

dialog.RegisterFunc("layer", function(d, depth, layer, locale, force)
	local layer = tonumber(layer) or 2
	local locale = locale or 1
	if not layers[locale] then layers[locale] = {} end
	if force or not layers[locale][layer] or layers[locale][layer] == 0 then
		layers[locale][layer] = tonumber(depth) or 0
	end
	if not zSnap[locale] then zSnap[locale] = {} end
	zSnap[locale][layer] = zSnap[locale][layer] or 64
	--print("Wow look we set layer "..layer.." at "..layers[locale][layer].." at locale "..tostring(locale))
end)

dialog.RegisterFunc("setgravity",function(d, ...)
	local props = {...}

	if table.IsEmpty(props) then return end

	local enabled = true
	
	--our last value is (assumed to be) a bool, use it for enabled
	if not IsValid(FindByName(props[#props])) then
		enabled = tobool(table.remove(props,#props))
	end

	for _, name in ipairs(props) do
		local prop = FindByName(name)
		if IsValid(prop) then
			prop.gravity = enabled
		end
	end
end)

--we want to run a series of commands concurrently. Not for plain text!
dialog.RegisterFunc("block",function(d, ...)
	local cmds = string.Split(table.concat({ ... }," "),"-->")
	for _, v in ipairs(cmds) do
		local str = string.Trim(v)
		--local comment, _, _ = string.find(str,"#")
		--if comment then str = string.Left(str,comment) end
		local tab = string.Split(str," ")
		if next(tab) ~= nil then
			local name = table.remove(tab,1)
			while name == "block" do
				name = table.remove(tab,1)
			end
			if g_funcs[name] then g_funcs[name](d,unpack(tab)) end
		end
	end
end)

local function GetPlayerOutfits(ply)
	local outfits = {}
	local parts = pac.GetLocalParts and pac.GetLocalParts() or pac.UniqueIDParts[ply:UniqueID()]
	if parts then
		for k, v in pairs(parts) do
			if not v:HasParent() then
				table.insert(outfits, v:ToTable())
			end
		end
	end

	return outfits
end

function CreatePlayerProxy()
	local ent = ManagedCSEnt("dialog_player_proxy", LocalPlayer():GetModel())
	ent:SetPos(LocalPlayer():GetPos())
	ent:SetAngles(LocalPlayer():GetAngles())
	ent:SetupBones()
	ent:SetNoDraw(false)
	ent:SetSkin(LocalPlayer():GetSkin())
	for bodygroup = 0, #LocalPlayer():GetBodyGroups() do
		ent:SetBodygroup(bodygroup,LocalPlayer():GetBodygroup(bodygroup))
	end
	
	function ent.GetPlayerColor()
		return LocalPlayer():GetPlayerColor()
	end

	LocalPlayer().JazzDialogProxy = ent
	function ent:GetName()
		return LocalPlayer():GetName()
	end

	sceneRoots[ent] = defaultRoot

	print("Creating player proxy")
	if pac then
		local actual = ent:Get()
		pac.SetupENT(actual)
		local outfits = GetPlayerOutfits(LocalPlayer())
		for k, v in pairs(outfits) do
			actual:AttachPACPart(v)
		end

		function actual:RenderOverride()
			pac.ForceRendering(true)
			pac.ShowEntityParts(self)
			pac.RenderOverride(self, "opaque")
			pac.RenderOverride(self, "translucent", true)
			self:DrawModel()
			pac.ForceRendering(false)
		end
	end

	ent:SetSequence("idle_all_01")
	return ent
end

local function removeSceneEntity(name)
	if IsValid(sceneModels[name]) then
		sceneModels[name]:SetNoDraw(true)
		sceneModels[name]:DrawShadow(false)
		sceneModels[name] = nil
	end
end

--don't let these be set as names for props, because they're very important elsewhere
local nononames = {
	["focus"] = true,
	["player"] = true,
	["nil"] = true,
	["true"] = true,
	["false"] = true,
	["BLOCKSTART"] = true,
	["BLOCKEND"] = true
}

dialog.RegisterFunc("spawn", function(d, name, mdl, root)
	local isdummy = mdl == "dummy"
	if isdummy then mdl = "models/props_interiors/vendingmachinesoda01a.mdl" end

	if nononames[name] or tonumber(name) then
		ErrorNoHalt("Attempted to use reserved name \"", name, "\" with spawn!")
		return
	end

	if IsValid(sceneModels[name]) then
		print("Scene model \""..name.."\" already exists, ignoring. Use *remove "..name.."* first if you really wanted to do this!")
		return
	end

	sceneModels[name] = ManagedCSEnt(name, mdl)
	sceneModels[name]:SetNoDraw(isdummy)
	sceneModels[name].IsDummy = isdummy
	sceneModels[name].gravity = true --gravity is enabled by default, prop will attempt to move to ground by +/-zSnap units
	sceneModels[name].layer = 1 --different layers can be used to give positioning more nuance than just zSnap alone can provide
	if root ~= nil then --funnily enough, this actually lets us set the root as nil (i.e. "nil")
		sceneRoots[sceneModels[name]] = sceneModels[root]
	else
		sceneRoots[sceneModels[name]] = defaultRoot
	end
end)

dialog.RegisterFunc("remove", function(d, ...)
	if table.IsEmpty({...}) then return end

	for _, name in ipairs({...}) do
		local prop = FindByName(name)
		if IsValid(prop) then
			--update children
			for k, v in pairs(sceneRoots) do
				if v == prop then
					sceneRoots[k] = nil
				end
			end
		end
		removeSceneEntity(name)
	end

end)

dialog.RegisterFunc("clear", function(d)
	ResetScene()
end)

dialog.RegisterFunc("player", function(d)
	return LocalPlayer():GetName()
end)

local shardtotal = GetConVar("jazz_total_shards")

dialog.RegisterFunc("shardtotal", function(d)
	if shardtotal then
		return shardtotal:GetString()
	else
		return "100"
	end
end)

dialog.RegisterFunc("wait", function(d, time)
	local time = tonumber(time) or 0
	local waittime = CurTime() + time
	while CurTime() < waittime do
		coroutine.yield()
	end
end)

dialog.RegisterFunc("txout", function(d, nowait)
	local isSpooky = dialog.GetParam("STYLE") == "horror"
	transitionOut(0, isSpooky, true, isSpooky)
	local nowait = tobool(nowait)

	while !nowait and isTransitioning() do
		coroutine.yield()
	end
end)

dialog.RegisterFunc("txin", function(d, nowait)
	local isSpooky = dialog.GetParam("STYLE") == "horror"

	transitionIn(0, isSpooky, true, isSpooky)
	local nowait = tobool(nowait)

	while !nowait and isTransitioning() do
		coroutine.yield()
	end
end)

dialog.RegisterFunc("hide", function(d, time)
	local time = tonumber(time) or 0
	local closetime = CurTime() + time

	while CurTime() < closetime do
		d.open = (closetime - CurTime()) / time
		coroutine.yield()
	end

	d.open = 0
end)

local function speakerset(name)
	local ent = FindByName(name,true)
	if name == "player" and (pac or not IsValid(ent)) then
		dialog.SetFocusProxy(LocalPlayer()) --TODO: remove this PAC conditional if/when PAC is supported nicely on the player proxy.
	else
		dialog.SetFocusProxy(ent)
	end
	dialog.SetPortraitOverride(nil)
	dialog.SetNameOverride("nil")
end

dialog.RegisterFunc("show", function(d, name, time)
	local time = tonumber(time) or 0
	if tonumber(name) then 
		time = tonumber(name)
	elseif name ~= nil then
		speakerset(name)
	end
	local closetime = CurTime() + time

	while CurTime() < closetime do
		d.open = 1 - (closetime - CurTime()) / time
		coroutine.yield()
	end

	d.open = 1
end)

dialog.RegisterFunc("setspeaker", function(d, name, skinid)
	skinid = skinid or nil
	if skinid ~= nil then SetSkinFunc(d, name, skinid) end
	speakerset(name)
end)

dialog.RegisterFunc("overrideportrait", function(d, name)
	local ent = FindByName(name)
	dialog.SetPortraitOverride(ent)
end)
dialog.RegisterFunc("overridename", function(d, name)
	dialog.SetNameOverride(name)
end)

dialog.RegisterFunc("setnpcid", function(d, name, npc)
	local prop = FindByName(name)
	if not IsValid(prop) then return end

	-- npc can be the name or npcid, we support both
	prop.JazzDialogID = tonumber(npc) or missions.GetNPCID(npc)
end)

dialog.RegisterFunc("setname", function(d, name, ...)
	local prop = FindByName(name)
	if not IsValid(prop) then return end

	prop.JazzDialogName = table.concat({...}," ")
end)

local view = {}


function util.IsInWorld( pos )
	local tr = { collisiongroup = COLLISION_GROUP_WORLD, output = {} }
	tr.start = pos
	tr.endpos = pos

	return not util.TraceLine( tr ).HitWorld
end

--attempt to prevent the camera clipping into the world
local function CamBoundsAdjust(tween)
	--eh, gotta work on this later
	if true then return end
	--false on setcamoffset, true on tweencamoffset
	local tween = tween or false
	local start = {}
	
	if tween then
		start.pos = view.goaloffset
		start.ang = view.goalrot
	else
		start.pos = view.offset
		start.ang = view.rot
	end

	if not (start.pos or start.ang) then return end

	local root = sceneRoots[view]
	if not IsValid(root) then return end
	local rootpos = root:GetPos()
	local rootang = root:GetAngles()

	local tab = {}
	tab.pos, tab.ang = LocalToWorld(start.pos,start.ang,rootpos,rootang)

	--first, if we're not in the world, don't bother
	if util.IsInWorld(tab.pos) then return end

	--rather than compare to the root itself, compare to the center of the root's rendering bounds
	local center, maxs = root:GetRenderBounds()
	center:Add(maxs)
	center:Div(2)
	center, _ = LocalToWorld(center,angle_zero,rootpos,rootang)
	print(rootpos,center)

	--[[TODO: probably gonna want to do more math than this at some point.
	Maybe check if moving the camera up some/angling it down a bit will make it move less
	(i.e. in cases where we're clipping into is displacement ground rather than a wall, etc.)]]
	
	local tr = util.TraceLine( {
		start = tab.pos,
		endpos = center
	} )

	--simply move the camera closer to its root, if we're not super close to it.
	if tr.Hit and tr.Fraction < .75 then
		tab.pos = tr.HitPos
	end

	if tween then
		view.goalpos = tab.pos
		--view.goalang = tab.ang
	else
		view.curpos = tab.pos
		--view.curang = tab.ang
	end
	-- Tell server to load in the specific origin into our PVS
	net.Start("dialog_requestpvs")
		net.WriteVector(tab.pos)
	net.SendToServer()
end

--figure out our view's world position, from its offset to its sceneroot

local function SceneRootToWorldCam(set)
	local set = set or false
	view = view or {}
	hook.Run("JazzNoDrawInScene")
	
	--our offset from our sceneroot is a vector, rotated by the sceneroot's angle
	local root = sceneRoots[view]
	local rootpos = vector_origin
	local rootang = angle_zero
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	local pos = view.offset or vector_origin
	local ang = view.rot or angle_zero


	local tab = {}
	tab.pos, tab.ang = LocalToWorld(pos,ang,rootpos,rootang)

	

	--we want to set the view's position in the world, rather than return the values
	if set then
		view.endtime = nil
		view.curpos = tab.pos
		view.curang = tab.ang
		-- Tell server to load in the specific origin into our PVS
		net.Start("dialog_requestpvs")
			net.WriteVector(tab.pos)
		net.SendToServer()
		CamBoundsAdjust(false)
		return
	end

	return tab
end

--figure out our view's relation to its scene root, from its world position

local function WorldToSceneRootCam(set)
	local set = set or false
	local view = view or {}
	hook.Run("JazzNoDrawInScene")

	--our offset from our sceneroot is a vector, rotated by the sceneroot's angle
	local root = sceneRoots[view]
	local rootpos = vector_origin
	local rootang = angle_zero
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	local pos = view.curpos
	local ang = view.curang

	local tab = {}
	tab.pos, tab.ang = WorldToLocal(pos,ang,rootpos,rootang)

	--we want to update the prop's offset to the scene root, rather than return the values
	if set then
		view.offset = tab.pos
		view.rot = tab.ang

		-- Tell server to load in the specific origin into our PVS
		net.Start("dialog_requestpvs")
			net.WriteVector(pos)
		net.SendToServer()
		return
	end

	return tab
end

local function groundAdjust(vec,root,pos,layer)
	local root = root or 1
	local pos = pos or vector_origin
	local layer = layer or 1
	
	local tr = util.TraceLine( {
		start = vec + Vector(0,0,zSnap[root][layer]),
		endpos = vec - Vector(0,0,zSnap[root][layer]),
		--using a function here is expensive let's gooo
		filter = function(ent)
			if ent:IsPlayer() then return false end
			if ent:IsNPC() then return false end
			if ent:IsNextBot() then return false end
			if ent:GetClass() == "jazz_cat" then return false end
			if ent:GetClass() == "jazz_door_eclipse" then return false end
			if ent:GetClass() == "jazz_shard_podium" then return false end
			if ent:IsSolid() then return true end
		end,
		mask = MASK_NPCSOLID
	} )
	--print("Here's where it all began: ",tr.StartPos)
	
	if tr.Hit then
		--print("We adjusted by "..tostring(tr.HitPos-vec) .."!")
		vec = Vector(tr.HitPos)
		vec.z = vec.z + pos.z
	end
	return vec
end


--figure out our world position, from our offset to the sceneroot

local function SceneRootToWorld(name, set)
	local set = set or false
	local prop = nil
	if isstring(name) then
		prop = FindByName(name)
	elseif IsValid(name) then
		prop = name
	end

	if not IsValid(prop) then return end
	
	local root = sceneRoots[prop]
	local rootpos = vector_origin
	local rootang = angle_zero
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	local parent = root
	local localename = parent and parent.Locale or 1

	--go up the parent chain to find our locale
	while localename == 1 and parent ~= nil do
		parent = sceneRoots[parent]
		localename = parent and parent.Locale or 1
	end

	--compare it to its layer
	--print("root to world before: ".. rootpos.z)
	if prop.layer and prop.layer > 1 then
		rootpos.z = rootpos.z + ( istable( layers[localename] ) and layers[localename][prop.layer] or 0 )
		--print("after: ".. rootpos.z)
	end

	local pos = Vector(prop.offset) or vector_origin
	local ang = prop.rot or angle_zero

	local tab = {}
	tab.pos,tab.ang = LocalToWorld(pos,ang,rootpos,rootang)

	--ground work
	if prop.gravity and istable( zSnap[localename] ) and (zSnap[localename][prop.layer or 1]) or 0 > 0 then
		--print("Hey this is a funny number:",prop.layer,zSnap[localename][prop.layer or 1])
		tab.pos = groundAdjust(tab.pos,localename,pos,prop.layer)
	end

	--we want to set the prop's position in the world, rather than return the values
	if set then
		prop:SetPos(tab.pos)
		prop:SetAngles(tab.ang)
		prop:SetupBones()
		--update children
		for k, v in pairs(sceneRoots) do
			if v == prop then
				if k == view then
					SceneRootToWorldCam(true)
				else
					SceneRootToWorld(k,true)
					v:SetupBones()
				end
			end
		end
		return
	end

	return tab
end

--figure out our relation to the scene root, from our world position

local function WorldToSceneRoot(name, set)
	local set = set or false
	local prop = nil
	if isstring(name) then
		prop = FindByName(name)
	elseif IsValid(name) then
		prop = name
	end
	if not IsValid(prop) then return end

	--our offset from our sceneroot is a vector, rotated by the sceneroot's angle
	local root = sceneRoots[prop]
	local rootpos = vector_origin
	local rootang = angle_zero
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	local parent = root
	local localename = parent and parent.Locale or 1

	--go up the parent chain to find our locale
	while localename == 1 and parent ~= nil do
		parent = sceneRoots[parent]
		localename = parent and parent.Locale or 1
	end

	--compare it to its layer
	--print("world to root before: ".. rootpos.z)
	if prop.layer and prop.layer > 1 then
		rootpos.z = rootpos.z - ( istable( layers[localename] ) and layers[localename][prop.layer] or 0 )
		--print("after: ".. rootpos.z)
	end

	local pos = prop:GetPos()
	local ang = prop:GetAngles()


	local tab = {}
	tab.pos, tab.ang = WorldToLocal(pos,ang,rootpos,rootang)

	--we want to update the prop's offset to the scene root, rather than return the values
	if set then
		prop.offset = tab.pos
		prop.rot = tab.ang
		--update children
		for k, v in pairs(sceneRoots) do
			if v == prop then
				if k == view then
					SceneRootToWorldCam(true)
				else
					SceneRootToWorld(k,true)
					v:SetupBones()
				end
			end
		end
		return
	end

	return tab
end

local cat_angle_fix = angle_zero --Angle(90,90,0) --set this to non zero if converting scenes from old models to new

dialog.RegisterFunc("setposang", function(d, name, ...)
	local prop = FindByName(name)
	if not IsValid(sceneModels[name]) then return end

	prop.endtime = nil
	local posang = parsePosAng(...)
	if posang.pos then
		prop:SetPos(posang.pos)
	end
	if posang.ang then
		prop:SetAngles(posang.ang)
	end
	prop:SetupBones()
	WorldToSceneRoot(name,true)
	if sceneRoots[prop] and RUN_CONVERSION then
		if string.find(name,"cat_") then
			print("\t*setoffset "..name.." setpos "..tostring(prop.offset)..";setang "..tostring(prop.rot+cat_angle_fix).."*")
		else
			print("\t*setoffset "..name.." setpos "..tostring(prop.offset)..";setang "..tostring(prop.rot).."*")
		end
	end
end)

--update this prop's offset to its current scene root
dialog.RegisterFunc("setoffset", function(d, name, ...)
	local prop = FindByName(name)
	if not IsValid(prop) then return end

	prop.endtime = nil
	local posang = parsePosAng(...)
	if posang.pos then
		prop.offset = posang.pos
	end
	if posang.ang then
		prop.rot = posang.ang
	end
	SceneRootToWorld(name,true)
end)

--update this prop's sceneroot, optionally setting a new offset as well
dialog.RegisterFunc("setroot", function(d, name, rootname, ...)
	local prop = FindByName(name)
	local root = FindByName(rootname)
	if not IsValid(prop) then return end

	if IsValid(root) then
		sceneRoots[prop] = root
		--avoid parenting infinite loop
		--first, an easy one. Make sure that we're not our own parent or grandparent
		if sceneRoots[root] == prop then
			sceneRoots[root] = nil
		end
		--don't allow parenting to view (too messy to try to do, if you want something to move with the view, use an object that you attach the view to)
		if sceneRoots[prop] == view then
			sceneRoots[prop] = nil
		end
		--keep an eye out for self great (and great great, etc.) grandparenting
		local grandpacheck = prop
		local count = table.Count(sceneRoots) + 1 --if we move around more than there's entries in the table, we're in a parental loop
		if IsValid(grandpacheck) then
			while count > 0 do
				local ent = sceneRoots[grandpacheck]
				if IsValid(ent) then
					grandpacheck = ent
					count = count - 1
				else break end
			end
		end
		if count <= 0 then
			ErrorNoHalt(name, ": It sounds funny I know, but it really is so, I'm my own Grandpa.\n")
			--not a whole lot we can do here but make sure we're not the culprit by breaking us out
			sceneRoots[prop] = nil
		end

	else
		sceneRoots[prop] = nil
	end

	prop.endtime = nil
	local posang = parsePosAng(...)
	if posang.pos then
		prop.offset = posang.pos
	end
	if posang.ang then
		prop.rot = posang.ang
	end
	if posang.pos or posang.ang then
		SceneRootToWorld(name,true)
	end
end)

net.Receive("dialog_returnlocale", function(len, ply)

	--if not IsValid(ply) then return end

	local name = net.ReadString()
	local locale = net.ReadString()
	--local ent = net.ReadEntity()
	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local newlayers = net.ReadTable()
	local newzSnap = net.ReadTable()

	for k, v in ipairs(newlayers) do
		if not layers[locale] then layers[locale] = {} end
		layers[locale][k] = v
	end


	for k, v in ipairs(newzSnap) do
		if not zSnap[locale] then zSnap[locale] = {} end
		zSnap[locale][k] = v
	end

	sceneLocales[locale.."pos"] = pos
	sceneLocales[locale.."ang"] = ang
	
	local ent = sceneModels[name]

	if IsValid(ent) then
		ent:SetPos(sceneLocales[locale.."pos"])
		ent:SetAngles(sceneLocales[locale.."ang"])
		ent.Locale = locale
		ent:SetupBones()
		WorldToSceneRoot(name,true)
	end

end )

dialog.RegisterFunc("setlocale", function(d, name, ...)
	local gotone = nil 
	local localetest = {...}
	for k, v in ipairs(localetest) do
		if sceneLocales[v.."pos"] and sceneLocales[v.."ang"] then
			gotone = k
			break
		end
	end
	if not gotone then
		net.Start("dialog_requestlocale")
			net.WriteString(tostring(name))
			local max = math.pow(2,maxLocalesUInt)
			net.WriteUInt(math.min(#localetest-1,max-1),maxLocalesUInt)
			for _, v in ipairs(localetest) do
				net.WriteString(tostring(v))
				max = max - 1
				if max <= 0 then break end
			end
		net.SendToServer()
	else
		--we've already got this locale, no need to network for it again
		local ent = sceneModels[name]
		if IsValid(ent) then
			ent:SetPos(sceneLocales[localetest[gotone].."pos"])
			ent:SetAngles(sceneLocales[localetest[gotone].."ang"])
			ent.Locale = localetest[gotone]
			ent:SetupBones()
			WorldToSceneRoot(name,true)
		end
	end
end)

dialog.RegisterFunc("setlayer",function(d, ...)

	local props = {...}

	if table.IsEmpty(props) then return end

	local layer = 1
	
	--our last value is (assumed to be) a number, use it for the layer
	if not IsValid(FindByName(props[#props])) then
		layer = tonumber(table.remove(props,#props)) or layer
	end

	for _, name in ipairs(props) do
		local prop = FindByName(name)
		if IsValid(prop) then
			prop.layer = layer
		end
	end
end)

dialog.RegisterFunc("tweenposang", function(d, name, time, ...)
	local prop = FindByName(name)
	if not IsValid(sceneModels[name]) then return end

	local posang = parsePosAng(...)

	prop.startpos = prop:GetPos()
	prop.goalpos = posang.pos or prop:GetPos()

	prop.startang = prop:GetAngles()
	prop.goalang = posang.ang or prop:GetAngles()

	prop.endtime = CurTime() + time
	prop.tweenlen = time

	local rootpos = vector_origin
	local rootang = angle_zero
	local root = sceneRoots[prop]
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	prop.goaloffset, prop.goalrot = WorldToLocal(posang.pos,posang.ang,rootpos,rootang)

	if sceneRoots[prop] and RUN_CONVERSION then
		if string.find(name,"cat_") then
			print("\t*tweenoffset "..name.." "..tostring(time).." setpos "..tostring(prop.goaloffset)..";setang "..tostring(prop.goalrot+cat_angle_fix).."*")
		else
			print("\t*tweenoffset "..name.." "..tostring(time).." setpos "..tostring(prop.goaloffset)..";setang "..tostring(prop.goalrot).."*")
		end
	end

end )

dialog.RegisterFunc("tweenoffset", function(d, name, time, ...)
	local prop = FindByName(name)
	if not IsValid(sceneModels[name]) then return end

	local posang = parsePosAng(...)

	local rootpos = vector_origin
	local rootang = angle_zero
	local root = sceneRoots[prop]
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	prop.goalpos, prop.goalang = LocalToWorld(posang.pos,posang.ang,rootpos,rootang)
	prop.startpos = prop:GetPos()
	prop.goaloffset = posang.pos or prop.offset

	prop.startang = prop:GetAngles()
	prop.goalrot = posang.ang or prop.rot

	prop.endtime = CurTime() + time
	prop.tweenlen = time
end )

--same thing, but we want to tween to a new root
dialog.RegisterFunc("tweenoffsetroot", function(d, name, time, newroot, ...)
	local prop = FindByName(name)
	if not IsValid(sceneModels[name]) then return end

	local posang = parsePosAng(...)

	sceneRoots[prop] = FindByName(newroot)
	local rootpos = vector_origin
	local rootang = angle_zero
	local root = sceneRoots[prop]
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	prop.goalpos, prop.goalang = LocalToWorld(posang.pos,posang.ang,rootpos,rootang)
	prop.startpos = prop:GetPos()
	prop.goaloffset = posang.pos or prop.offset

	prop.startang = prop:GetAngles()
	prop.goalrot = posang.ang or prop.rot

	prop.endtime = CurTime() + time
	prop.tweenlen = time
end )

dialog.RegisterFunc("setanim", function(d, name, anim, speed, finishIdleAnim)
	local prop = FindByName(name)
	if not IsValid(prop) then return end

	prop:SetSequence(anim)
	prop:SetPlaybackRate(tonumber(speed) or 1)

	prop.starttime = CurTime()

	-- If finish anim is specified, this animation won't loop and will return
	-- to the specified idle animation when finished
	prop.finishanim = finishIdleAnim
end)

dialog.RegisterFunc("setlook", function(d, name, pitch, yaw, roll)

	--[[Some useage notes:
			-Pitch to look down, +Pitch to look up
			-Yaw to look left, +Yaw to look right
			-Roll to tilt left, +Roll to tilt right

			if we've provided no value, we want to reset that part of the angle]]
	local x = tonumber(pitch) or 0
	local y = tonumber(yaw) or 0
	local z = (tonumber(roll) or 0) * -1

	local prop = FindByName(name)
	if not IsValid(prop) then return end

	local head = prop:LookupBone( "ValveBiped.Bip01_Head1" ) --default player/most NPC head bone

	if not head then
		head = prop:LookupBone( "rig_cat:j_head" ) --a cat is fine too

		--cats' X and Z are flipped relative to players'
		x = x * -1
		z = z * -1
	end

	if head then
		prop:ManipulateBoneAngles( head, Angle(z,x,y) )
		--print("Head at ",x,y,z,prop:GetManipulateBoneAngles(head))
	end

end)

dialog.RegisterFunc("setskin", function(d, name, skinid)
	SetSkinFunc(d, name, skinid)
end)
-- Abstracted out for use in both setskin and setspeaker
function SetSkinFunc(d, name, skinid)
	local skinid = skinid
	if not skinid and tonumber(name) then -- just a skinid, so setskin on the current speaker 
		skinid = name
		name = "focus"
	end
	skinid = tonumber(skinid) or 0
	local prop = FindByName(name)

	if IsValid(prop) then
		prop:SetSkin(skinid)
	end
end

dialog.RegisterFunc("setbodygroup", function(d, name, bodygroup, val)
	local name, bodygroup, val = name, bodygroup, tonumber(val)
	if not val then -- just a bodygroup, so setbodygroup on the current speaker 
		val = tonumber(bodygroup)
		bodygroup = name
		name = "focus"
	end

	local prop = FindByName(name)
	if IsValid(prop) and val then
		--support for both number and name
		if not tonumber(bodygroup) then
			if not tostring(bodygroup) then return end
			bodygroup = prop:FindBodygroupByName(bodygroup)
		else
			bodygroup = tonumber(bodygroup)
		end

		if bodygroup > -1 then prop:SetBodygroup(bodygroup,val) end
	end
end)

dialog.RegisterFunc("setscale", function(d, name, val)
	local name, val = name, tonumber(val)
	if not val then 
		if tonumber(name) or not name then -- just a scale (or nothing at all), so setscale on the current speaker
			val = tonumber(name)
			name = "focus"
		end
	end

	local prop = FindByName(name)
	if IsValid(prop) then
		if val then
			local scale = Vector(val,val,val)
			local mat = Matrix()
			mat:Scale(scale)
			prop:EnableMatrix("RenderMultiply", mat)
		else --no scale provided, reset instead
			prop:DisableMatrix("RenderMultiply")
		end
	end
end)

dialog.RegisterFunc("render", function(d, name, val)
	if val == nil then val = true end
	local val = tobool(val)
	local prop = FindByName(name)
	if IsValid(prop) then
		prop:SetNoDraw(not val)
		prop:DrawShadow(val)
	end
end)

--adding functionality to RUN_CONVERSION print to recognize if this is meant to be the first time the camera has been set to this root, and update accordingly
local camrootcount = 0

dialog.RegisterFunc("setcam", function(d, ...)
	local posang = parsePosAng(...)

	if !posang.pos or !posang.ang then
		view = nil
		sceneModels = {}
		return
	end

	view = view or {}
	view.endtime = nil
	view.curpos = posang.pos
	view.curang = posang.ang
	if posang.fov then view.fov = posang.fov end

	WorldToSceneRootCam(true)

	if IsValid(sceneRoots[view]) and RUN_CONVERSION then
		local str = "\t*setcamoffset setpos "..tostring(view.offset)..";setang "..tostring(view.rot)
		if camrootcount == 0 then
			local root = ""
			for name, v in pairs(sceneModels) do
				if v == sceneRoots[view] then root = name break end
			end
			if root ~= "" then str = string.Replace(str,"setcamoffset","setcamroot "..root) end
		end
		if posang.fov then str = str.." fov"..tostring(posang.fov) end
		camrootcount = camrootcount + 1
		print(str.."*")
	end

	-- Only create the player proxy if we modify the camera
	--FindByName("player")

	-- Tell server to load in the specific origin into our PVS
	--[[net.Start("dialog_requestpvs") --handled in WorldToSceneRootCam function call up above
		net.WriteVector(posang.pos)
	net.SendToServer()]]

end)

dialog.RegisterFunc("setcamroot", function(d, rootname, ...)
	local root = FindByName(rootname)
	local posang = parsePosAng(...)

	view = view or {}
	if posang.pos then
		view.offset = posang.pos
	end
		
	if posang.ang then
		view.rot = posang.ang
	end

	if posang.fov then 
		view.fov = posang.fov
	end

	if IsValid(root) then
		if sceneRoots[view] == root then
			camrootcount = camrootcount + 1
		else
			camrootcount = 0
			sceneRoots[view] = root
		end
		SceneRootToWorldCam(true)
	else
		sceneRoots[view] = nil
		camrootcount = 0
	end

	-- Only create the player proxy if we modify the camera
	--FindByName("player")

end)

--update the view's offset to its current scene root

dialog.RegisterFunc("setcamoffset", function(d, ...)
	local posang = parsePosAng(...)

	if !posang.pos or !posang.ang then
		view = nil
		sceneModels = {}
		return
	end

	view = view or {}
	view.endtime = nil
	view.offset = posang.pos
	view.rot = posang.ang
	if posang.fov then view.fov = posang.fov end

	SceneRootToWorldCam(true)

	-- Only create the player proxy if we modify the camera
	FindByName("player")

	-- Tell server to load in the specific origin into our PVS
	net.Start("dialog_requestpvs")
		net.WriteVector(view.curpos)
	net.SendToServer()

end)

dialog.RegisterFunc("tweencam", function(d, time, ...)
	local time = tonumber(time)
	local posang = parsePosAng(...)

	if !posang.pos or !posang.ang then
		view = nil
		sceneModels = {}
		return
	end

	if view then
		view.startpos = view.curpos
		view.startang = view.curang
		view.goalpos = posang.pos
		view.goalang = posang.ang
		view.endtime = CurTime() + time
		view.tweenlen = time
	else
		view = {}
		view.curpos = posang.pos
		view.curang = posang.ang
	end

	local rootpos = vector_origin
	local rootang = angle_zero
	local root = sceneRoots[view]
	if IsValid(root) then
		rootpos = root:GetPos()
		rootang = root:GetAngles()
	end

	view.goaloffset, view.goalrot = WorldToLocal(posang.pos,posang.ang,rootpos,rootang)
	CamBoundsAdjust(true)

	if sceneRoots[view] and RUN_CONVERSION then
		local str = "\t*tweencamoffset "..tostring(time).." setpos "..tostring(view.goaloffset)..";setang "..tostring(view.goalrot).."*"
		if camrootcount == 0 then
			local root = ""
			for name, v in pairs(sceneModels) do
				if v == sceneRoots[view] then root = name break end
			end
			if root ~= "" then
				str = string.Replace(str,"tweencamoffset","tweencamoffsetroot")
				str = string.Replace(str,"setpos",root.." setpos")
			end
		end 
		print(str)
	end
end)

dialog.RegisterFunc("tweencamoffset", function(d, time, ...)
	local time = tonumber(time)
	local posang = parsePosAng(...)
	local actiontime = CurTime()

	timer.Simple(0,function()
		local rootpos = vector_origin
		local rootang = angle_zero
		local root = sceneRoots[view]
		if IsValid(root) then
			root:SetupBones()
			rootpos = root:GetPos()
			rootang = root:GetAngles()
		end

		if !posang.pos or !posang.ang then return end

		if view then
			view.goalpos,view.goalang = LocalToWorld(posang.pos,posang.ang,rootpos,rootang)
			view.startpos = view.curpos
			view.goaloffset = posang.pos

			view.startang = view.curang
			view.goalrot = posang.ang

			view.endtime = actiontime + time
			view.tweenlen = time
		else
			view = {}
			view.curpos = posang.pos
			view.curang = posang.ang
			WorldToSceneRootCam(true)
		end
	end)
end)

--same thing, but we want to tween to a new root
dialog.RegisterFunc("tweencamoffsetroot", function(d, time, newroot, ...)
	local time = tonumber(time)
	local posang = parsePosAng(...)
	local actiontime = CurTime()

	timer.Simple(0,function()
		local oldroot = sceneRoots[view]
		sceneRoots[view] = FindByName(newroot)

		if IsValid(oldroot) and sceneRoots[view] == oldroot then
			camrootcount = camrootcount + 1
		else
			camrootcount = 0
		end


		local rootpos = vector_origin
		local rootang = angle_zero
		local root = sceneRoots[view]
		if IsValid(root) then
			root:SetupBones()
			rootpos = root:GetPos()
			rootang = root:GetAngles()
		end

		if !posang.pos or !posang.ang then return end

		if view then
			view.goalpos,view.goalang = LocalToWorld(posang.pos,posang.ang,rootpos,rootang)
			view.startpos = view.curpos
			view.goaloffset = posang.pos

			view.startang = view.curang
			view.goalrot = posang.ang

			view.endtime = actiontime + time
			view.tweenlen = time
		else
			view = {}
			view.curpos = posang.pos
			view.curang = posang.ang
			WorldToSceneRootCam(true)
		end
	end)
end)


dialog.RegisterFunc("setfov", function(d, fov)
	local fov = tonumber(fov)

	view = view or {}
	view.fov = fov
end)

dialog.RegisterFunc("setcamtarget", function(d, target, ...)
	--if it's blank, reset camera target
	if target == nil or target == "nil" then 
		view.target = nil
		view.targetoffset = nil
		return
	end
	local offset = table.concat({...}," ") or " "
	--if we have an offset but no target, leave current target and set new offset
	if tonumber(target) then
		offset = target .. " " .. offset
	else
		view.target = target
	end
	if next({...}) ~= nil then view.targetoffset = Vector(offset) end
end)

dialog.RegisterFunc("punch", function(d)
	LocalPlayer():ViewPunch(Angle(45, 0, 0))
end )

dialog.RegisterFunc("emitsound", function(d, snd, vol, pitch)
	local vol = tonumber(vol) or 1
	local pitch = (tonumber(pitch) or 1) * 100.0

	LocalPlayer():EmitSound(snd, 0, pitch, vol)
end )

--emitsound, but cut off if another is played/dialog is skipped
dialog.RegisterFunc("vocalize", function(d, snd, vol, pitch)
	local play = LocalPlayer()
	local vol = tonumber(vol) or 1
	local pitch = (tonumber(pitch) or 1) * 100.0

	if play.jazzvocal then play.jazzvocal:Stop() end

	play.jazzvocal = CreateSound(play,snd)

	if play.jazzvocal then
		play.jazzvocal:ChangePitch(pitch)
		play.jazzvocal:Play()
		play.jazzvocal:ChangeVolume(vol)
	end
end )

dialog.RegisterFunc("slam", function(d, ...)
	return table.concat({...}, " ")
end )

dialog.RegisterFunc("shake", function(d, time)
	util.ScreenShake(LocalPlayer():GetPos(), 8, 8, time or 1, 256)
end )

dialog.RegisterFunc("fadeblind", function(d, t)
	LocalPlayer():ScreenFade(SCREENFADE.IN, color_white, 2, tonumber(t) or 2)
end )

dialog.RegisterFunc("dsp", function(d, dspid)
	local dspid = tonumber(dspid) or 0
	LocalPlayer():SetDSP(dspid, true)
end )

dialog.RegisterFunc("stopsound", function(d)
	RunConsoleCommand("stopsound")
end )

dialog.RegisterFunc("ignite", function(d, name, attach)
	local prop = FindByName(name)

	if IsValid(prop) then
		game.AddParticles( "particles/fire_01.pcf" )
		PrecacheParticleSystem( "env_fire_small" )
		prop.burnfx = prop:CreateParticleEffect( "env_fire_small", attach or 0)
	end
end )

dialog.RegisterFunc("extinguish", function(d, name)
	local prop = FindByName(name)

	if IsValid(prop) and IsValid(prop.burnfx) then
		prop.burnfx:StopEmission()
	end
end )

function ResetScene()
	for k, v in pairs(sceneModels) do
		removeSceneEntity(k)
	end

	sceneModels = {}
	sceneRoots = {}
	defaultRoot = nil
	sceneLocales = {}
	zSnap = { {64} }
	layers = { {0} }
end

function ResetView(instant)
	local function reset()
		view = {}
		ResetScene()
	end

	//Only do the transition if we've actually overwritten something
	if table.Count(view) > 0 and not instant then
		local isSpooky = dialog.GetParam("STYLE") == "horror"
		local time = 0.5
		if not isTransitionedOut() then
			transitionOut(nil, isSpooky, nil, isSpooky)
			time = 1.5
		end
		timer.Simple(time, function()
			reset()
			transitionIn(nil, isSpooky, nil, isSpooky)
		end)
	else
		reset()
	end
end

local function viewOverwritten()
	return view and (view.curpos or view.fov or view.curang)
end

local function getTweenValues(obj)
	if obj.endtime then
		local p = 1 - math.Clamp((obj.endtime - CurTime()) / obj.tweenlen, 0, 1)

		local root = sceneRoots[obj]
		if IsValid(root) then
			local rootpos = root:GetPos()
			local rootang = root:GetAngles()

			--update our goals (in case our root moved)
			if obj.goaloffset then
				--obj.startpos = obj:GetPos()
				obj.goalpos, _ = LocalToWorld(obj.goaloffset, obj.goalrot or obj.goalang, rootpos, rootang)

				local parent = sceneRoots[obj]
				local localename = parent and parent.Locale or 1

				--go up the parent chain to find our locale
				while localename == 1 and parent ~= nil do
					parent = sceneRoots[parent]
					localename = parent and parent.Locale or 1
				end

				if obj.gravity and zSnap[localename][obj.layer or 1] > 0 then obj.goalpos = groundAdjust(obj.goalpos,localename,obj.goaloffset,obj.layer) end
			end

			if obj.goalrot then
				_, obj.goalang = LocalToWorld(obj.goaloffset or obj.goalpos, obj.goalrot, rootpos, rootang)
				--obj.startang = obj:GetAngles()
			end
		end

		local pos = LerpVector(p, obj.startpos, obj.goalpos)
		local ang = LerpAngle(p, obj.startang, obj.goalang)

		if p >= 1 then
			obj.endtime = nil
			obj.goaloffset = nil
			obj.goalpos = nil
			obj.goalrot = nil
			obj.goalang = nil
		end

		return pos, ang
	end

	return nil, nil
end

hook.Add("CalcView", "JazzDialogView", function(ply, origin, angles, fov, znear, zfar)
	
	hook.Run("JazzNoDrawInScene") --big ol' todo: find somewhere else to run this for checking if we're out of a scene

	--storing a copy local to prevent network spamming
	if ply.InScene == nil then ply.InScene = ply:GetInScene() end

	if not viewOverwritten() then 
		if ply.InScene then
			ply.InScene = false
			net.Start("JazzPlayerInScene")
				net.WriteBool(ply.InScene)
			net.SendToServer()
		end
		return 
	end

	if not ply.InScene then
		ply.InScene = true
		ply:SetInScene(true)
		net.Start("JazzPlayerInScene")
			net.WriteBool(ply.InScene)
		net.SendToServer()
	end

	-- I don't feel like re-simulating screen shake/view punch
	-- So just copy the difference between what would've been the player view and their actual eye pos
	-- And assume this is the result of those
	local offset = ply:EyePos() - origin
	local angoff = ply:EyeAngles() - angles

	-- Maybe do some tweening
	local newpos, newang = getTweenValues(view)
	if newpos and newang then
		view.curpos = newpos
		view.curang = newang
	end

	-- if we have a view target override, ignore everything else we just did for pitch/yaw and set it instead
	if view.target then
		local targetent = FindByName(view.target)
		if IsValid(targetent) then
			local targetpos, oldroll = Vector(targetent:GetPos()), view.curang.r or 0
			if isvector(view.targetoffset) then targetpos:Add(view.targetoffset) end
			targetpos:Sub(view.curpos)
			targetpos:Normalize()
			view.curang = targetpos:Angle()
			--use our old roll
			view.curang.r = oldroll
		end
	end

	-- If view/angles overwritten, re-apply cam shake
	view.origin = view.curpos and view.curpos + offset
	view.angles = view.curang and view.curang + angoff

	view.drawviewer = false

	if GetConVar("jazz_debug_sceneEditor_inCamera"):GetBool() == false then return end

	return view
end )

-- Hide drawing viewmodel if we're overriding their view in a dialog sequence
hook.Add("PreDrawViewModel", "JazzDisableDialogViewmodel", function(vm, ply, wep)
	if not viewOverwritten() then return end

	return true
end)

hook.Add("Think", "JazzTickClientsideAnims", function()
	for k, v in pairs(sceneModels) do
		if IsValid(v) then
			local time = CurTime() - (v.starttime or 0)
			local length = v:SequenceDuration(v:GetSequence())
			local p = v:GetPlaybackRate() * time / length

			v:SetCycle(p)

			-- Handle non-looping animations, reset to specified idle
			if p >= 1.0 and v.finishanim then
				v:SetSequence(v.finishanim)
				v:SetPlaybackRate(1.0)
				v.starttime = CurTime()
				v.finishanim = nil
			end

			-- Handle tweening
			local newpos, newang = getTweenValues(v)
			if newpos and newang then
				v:SetPos(newpos)
				v:SetAngles(newang)
				v:SetupBones()
				
				--update children
				for key, val in pairs(sceneRoots) do
					if val == v then
						if key == view then
							SceneRootToWorldCam(true)
						else
							local tab = SceneRootToWorld(key,false)
							if not key.goaloffset then
								key:SetPos(tab.pos)
							end
							if not key.goalrot then
								key:SetAngles(tab.ang)
							end
						end
					end
				end
			end
		end
	end
end )

-- Disable motion blur while in a dialog, as scene changes break it pretty bad
hook.Add("GetMotionBlurValues", "JazzDisableMblurDialg", function(h, v, f, r)
	if dialog.IsInDialog() then return 0, 0, 0, 0 end
end )


-- Background music

local bgmvolume = CreateClientConVar("jazz_music_volume", 1, true, false, "Controls music volume in Jazztroanuts cutscenes. 1 for full volume, 0 to mute.", 0, 1)

local bgmeta = {}

function bgmeta:OnReady(channel, err, errname)
	if not channel then
		self.failure = true
		ErrorNoHalt("Failed to play background music " .. self.song .. "\n" .. errname .. "\n")
		return
	end
	if channel.endtime then return end -- Already fading out

	channel:SetVolume(0)
	channel:EnableLooping(true)
	channel:Play()
	self.channel = channel
	self.fadetime = self.fadein + RealTime()
end

function bgmeta:Stop(fade)
	fade = fade or 0
	self.fadeout = fade
	self.fadetime = fade + RealTime()
end

function bgmeta:Update()
	if not IsValid(self.channel) then return not self.failure end

	local volume = 0
	if self.fadeout then
		local perc = self.fadeout > 0 and (self.fadetime - RealTime()) / self.fadeout or -1
		volume = math.min(perc, 1) * self.maxvol
	elseif self.fadein then
		local perc = self.fadein > 0 and (self.fadetime - RealTime()) / self.fadein or 0
		volume = math.min(1 - perc, 1) * self.maxvol
	end

	if volume < 0 then
		self.channel:Stop()
		return false
	end

	local focusmult = system.HasFocus() and 1 or 0
	self.channel:SetVolume(math.Clamp(volume * focusmult * bgmvolume:GetFloat(), 0, 1))
	return true
end

bgmeta.__index = bgmeta

local curBGMusic = nil
local activeMusic = {}
local function playBGMusic(song, volume, fadein)

	-- Stop any existing songs
	StopBGMusic(fadein)

	-- Construct our new song object
	local newsong = setmetatable({song = song, maxvol = volume, fadein = fadein }, bgmeta)
	sound.PlayFile(song, "noblock noplay", function(...) newsong:OnReady(...) end)

	-- add 2 list
	table.insert(activeMusic, newsong)
	curBGMusic = newsong
end

function StopBGMusic(fadeout)
	if not curBGMusic then return end

	curBGMusic:Stop(fadeout)
	curBGMusic = nil
end

hook.Add("Think", "JazzDialogBGMusicThink", function()
	for k, v in pairs(activeMusic) do
		if not v:Update() then
		   table.remove(activeMusic, k)
		end
	end
end )

dialog.RegisterFunc("bgmplay", function(d, song, volume, fadetime)
	playBGMusic(song, tonumber(volume) or 1.0, tonumber(fadetime) or 0.0)
end )

dialog.RegisterFunc("bgmstop", function(d, fadetime)
	StopBGMusic(fadetime)
end )

dialog.RegisterFunc("voiddisable", function(d, song, volume, fadetime)
	jazzvoid.SetShouldRender(false)
end )

dialog.RegisterFunc("drugson", function()
	drugs.Enable( true )
end)

dialog.RegisterFunc("drugsoff", function()
	drugs.Enable( false )
end)