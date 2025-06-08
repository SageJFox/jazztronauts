-- The Hole the bus makes when it blows through the wall.
AddCSLuaFile()
AddCSLuaFile("cl_voidrender.lua")
if CLIENT then include("cl_voidrender.lua") end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Model = "models/sunabouzu/bus_breakableWall.mdl"

ENT.GibModels = {}
for i=1, 37 do
	local path = "models/sunabouzu/gib_bus_breakablewall_gib" .. i .. ".mdl"
	util.PrecacheModel(path)
	table.insert(ENT.GibModels, path)
end

ENT.VoidModels = {
	"models/jazztronauts/zak/Boneless_Kleiner.mdl",
	"models/Gibs/HGIBS.mdl",
	"models/props_junk/ravenholmsign.mdl",
	"models/props_interiors/BathTub01a.mdl",
	"models/props_junk/wood_crate001a.mdl",
	"models/props_lab/cactus.mdl",
	"models/props_junk/trashdumpster01a.mdl"
}

ENT.VoidSpeedTunnelModel = "models/sunabouzu/bustunnel.mdl"
ENT.VoidSphereModel = "models/hunter/misc/sphere375x375.mdl"
ENT.VoidBorderModel = "models/sunabouzu/bus_brokenwall.mdl"
ENT.VoidRoadModel = "models/sunabouzu/jazzroad.mdl"
ENT.VoidTunnelModel = "models/sunabouzu/jazztunnel.mdl"

ENT.BackgroundHumSound = "ambient/levels/citadel/zapper_ambient_loop1.wav"

ENT.RTSize = 1024
ENT.Size = 184

local zbumpMat = Matrix()
zbumpMat:Translate(Vector(0, -2, 0))
zbumpMat:Scale(Vector(1, 1, 1) * .9)
ENT.ZBump = zbumpMat

if SERVER then
	lastBusEnts = lastBusEnts or {}
	concommand.Add("jazz_call_bus", function(ply, cmd, args, argstr)
		local eyeTr = ply:GetEyeTrace()
		local pos = eyeTr.HitPos
		local ang = eyeTr.HitNormal:Angle()

		mapcontrol.SpawnExitBus(pos, ang)
	end, nil, nil, { FCVAR_CHEAT } )
end

function ENT:Initialize()

	if SERVER then
		self:SetModel(self.Model)
		self:PrecacheGibs() -- Probably isn't necessary
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	end

	self:DrawShadow(false)
	-- portals straight up and down flip opposite one another, flip the exit back
	if self:GetIsExit() then
		local adjust = self:GetAngles()
		if adjust.z % 360 == 90 then
			adjust.y = adjust.y + 180
			self:SetAngles(adjust)
		end
	end

	if CLIENT then

		-- Take a snapshot of the surface that's about to be destroyed
		self:StoreSurfaceMaterial()

		-- Create all the gibs beforehand, get them ready to go (but hide them for now)
		self.Gibs = {}
		for _, v in pairs(self.GibModels) do
			local gib = ents.CreateClientProp(v)
			gib:SetModel(v)
			gib:SetPos(self:GetPos())
			gib:SetAngles(self:GetAngles())
			gib:Spawn()
			gib:PhysicsInit(SOLID_VPHYSICS)
			gib:SetSolid(SOLID_VPHYSICS)
			gib:SetCollisionGroup(self:GetIsExit() and COLLISION_GROUP_IN_VEHICLE or COLLISION_GROUP_WORLD)
			gib:SetNoDraw(true)
			gib:GetPhysicsObject():SetMass(500)
			gib:SetMaterial(self.WallMaterial, true)
			table.insert(self.Gibs, gib)
		end

		-- Also get the void props ready too
		self.VoidProps = {}
		for k, v in pairs(self.VoidModels) do
			local mdl = ManagedCSEnt("jazz_voidprop_" .. k, v)
			mdl:SetNoDraw(true)
			table.insert(self.VoidProps, mdl)
		end

		self.VoidSphere = ManagedCSEnt("jazz_void_sphere", self.VoidSphereModel)
		self.VoidSphere:SetNoDraw(true)
		self.VoidSphere:Spawn()

		self.VoidBorder = ManagedCSEnt("jazz_void_border", self.VoidBorderModel)
		self.VoidBorder:SetNoDraw(true)
		self.VoidBorder:Spawn()

		self.VoidRoad = ManagedCSEnt("jazz_void_road", self.VoidRoadModel)
		self.VoidRoad:SetNoDraw(true)
		self.VoidRoad:SetSkin(1)
		self.VoidRoad:Spawn()

		self.VoidTunnel = ManagedCSEnt("jazz_void_tunnel", self.VoidTunnelModel)
		self.VoidTunnel:SetNoDraw(true)
		self.VoidTunnel:Spawn()

		self.BackgroundHum = CreateSound(self, self.BackgroundHumSound)

		-- Hook into when the void renders so we can insert our props into it
		hook.Add("JazzDrawVoid", self, function(self) self:OnPortalRendered() end)
		hook.Add("JazzDrawVoidOffset", self, function(self) self:OnPortalRenderedOffset() end)

		timer.Simple(0,function() -- wait a tick to make sure the other part's valid
			if not IsValid(self) or not self:GetIsExit() then return end
			for _, v in ipairs(ents.FindByClass("jazz_bus_portal")) do
				if not IsValid(v) or v == self then continue end
				if not v:GetIsExit() and math.abs( self:GetCreationTime() - v:GetCreationTime() ) < 0.1 then
					self.roadDist = self:GetPos():Distance(v:GetPos())
					break
				end
			end
		end)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Bus")
	self:NetworkVar("Bool", 1, "IsExit") -- Are we the exit from the map into the void?
end

function ENT:OnRemove()
	if self.BackgroundHum then
		self.BackgroundHum:Stop()
		self.BackgroundHum = nil
	end

	if self.Gibs then
		for _, v in pairs(self.Gibs) do
			if IsValid(v) then v:Remove() end
		end
	end
end

-- Test which side the given point is of the portal
function ENT:DistanceToVoid(pos, dontflip)
	local dir = pos - self:GetPos()
	local fwd = self:GetAngles():Right()
	local mult = (!dontflip and self:GetIsExit() and -1) or 1

	return fwd:Dot(dir) * mult
end


-- Break if the front of the bus has breached our plane of existence
function ENT:ShouldBreak()
	if !IsValid(self:GetBus()) then return false end
	local busFront = self:GetBus():GetFront()

	return self:DistanceToVoid(busFront) > 1
end


if SERVER then return end

local buscount = 0

-- Render the wall we're right next to so we can break it
function ENT:StoreSurfaceMaterial()

	-- If the surface material is already a special material, set ourselves to it
	local tr = util.QuickTrace(self:GetPos(), self:GetAngles():Right() * -10, self)
	if tr.HitWorld then

		-- Lookup to see if this brushid has been taken
		local isVoided = false -- nerd furry
		for k, v in pairs(snatch.removed_brushes) do
			if v:ContainsPoint(tr.HitPos) then
				isVoided = true
				break
			end
		end

		-- If it has, then set our whole border material to it
		-- (since the underlying texture is this one anyway)
		if isVoided then
			self.WallMaterial = "!" .. jazzvoid.GetVoidOverlay():GetName()
			self.IsOnVoidWall = true
			return
		end
	end

	-- Create (or retrieve) the render target
	local matname = "bus" .. (buscount % 2 == 0 and "" or "2") .. "_wall" .. (self:GetIsExit() and "_exit" or "")
	if not self:GetIsExit() then buscount = buscount + 1 end
	local voidrt = irt.New(matname, self.RTSize, self.RTSize)
	voidrt:EnableDepth(true, true)
	voidrt:EnableMipmap(true)
	voidrt:EnableAnisotropy(true)
	voidrt:Render(function()
		-- Setup virtual camera location to be centered
		local pos = self.Size / 2
		local viewang = self:GetAngles()
		viewang:RotateAroundAxis(viewang:Up(), 90)
		debugoverlay.Axis(self:GetPos() + viewang:Forward() * -5,viewang,16,20,true)
		debugoverlay.Cross(self:GetPos(),5,20,Color(255,255,255),true)
		debugoverlay.Cross(self:GetPos() - viewang:Right() * pos,5,20,Color(255,0,255),true)
		debugoverlay.Cross(self:GetPos() + viewang:Right() * pos,5,20,Color(255,255,0),true)
		debugoverlay.Cross(self:GetPos() - viewang:Up() * pos,5,20,Color(0,255,255),true)
		debugoverlay.Cross(self:GetPos() + viewang:Up() * pos,5,20,Color(128,0,255),true)
		-- Render away
		local tab = {
			origin = self:GetPos() + viewang:Forward() * -5,
			angles = viewang,
			drawviewmodel = false,
			x = 0,
			y = 0,
			w = ScrW(),
			h = ScrH(),
			ortho = { left = -pos,
				right = pos,
				top = -pos,
				bottom = pos },
			bloomtone = false,
			dopostprocess = false,
		}
		--TODO FIXME BUGBUG WORKAROUND check for GMod updates fixing this issue in future
		if BRANCH == "x86-64" and viewang:Forward():Dot(-tab.origin) > 0 then --64-bit branch has a bug with ortho cameras and the map origin being in view, don't use that
			-- a rough, non-orthographic approximation of something halfway decent
			print((self:GetIsExit() and "Exit RT" or "Entrance RT") .. " switched to non-orthographic")
			tab.ortho = nil
			tab.origin = self:GetPos() + viewang:Forward() * -64
			tab.fov = 110
		end
		--don't draw stops on the RT
		local stops = ents.FindByClass("jazz_bus_marker")
		for _, v in ipairs(stops) do if not IsValid(v) then return end v:SetNoDraw(true) end
		render.RenderView( tab )
		--we *could* store its initial state and restore that, but, we never mess with nodraw elsewhere, so why bother
		for _, v in ipairs(stops) do if not IsValid(v) then return end  v:SetNoDraw(false) end
	end )

	local wallMaterial = CreateMaterial(matname, "UnlitGeneric", { ["$nocull"] = 1})
	wallMaterial:SetTexture("$basetexture", voidrt:GetTarget())
	self.WallMaterial = "!" .. wallMaterial:GetName()

end

local function GetExitPortal()
	local bus = IsValid(LocalPlayer():GetVehicle()) and LocalPlayer():GetVehicle():GetParent() or nil
	if !IsValid(bus) or !bus:GetClass() == "jazz_bus" then return nil end

	return bus.ExitPortal
end

local function IsInExitPortal()
	local exitPortal = GetExitPortal()
	if !IsValid(exitPortal) then return false end

	-- If the local player's view is past the portal 'plane', ONLY render the jazz dimension
	return exitPortal:DistanceToVoid(LocalPlayer():EyePos()) > 0
end

function ENT:Think()
	-- Break when the distance of the bus's front makes it past our portal plane
	if !self.Broken then
		self.Broken = self:ShouldBreak()

		if self.Broken then
			self:OnBroken()
		end
	end

	-- This logic is for the exit view only
	if self:GetIsExit() then
		-- Mark the exact time when the client's eyes went into the void
		if self.Broken and IsInExitPortal() and !self.VoidTime then
			if self:DistanceToVoid(LocalPlayer():EyePos(), true) < 0 then
				self.VoidTime = CurTime()
				//self:GetBus().JazzSpeed = self:GetBus():GetVelocity():Length()
			end
		end

		-- Bus have not have networked, but we need a way to go from Bus -> Portal
		-- Just set a value on the bus entity that points to us
		if IsValid(self:GetBus()) then
			self:GetBus().ExitPortal = self
		end
	end

	-- Insert into the local list of portals to render this frame
	local ply = LocalPlayer()
	ply.ActiveBusPortals = ply.ActiveBusPortals or {}
	table.insert(ply.ActiveBusPortals, self)
end

function ENT:GetPortalPosAng()
	local angles = self:GetAngles()

	local pos = self:GetPos()

	return pos, angles
end

function ENT:OnPortalRendered()
	render.SetBlend(self:GetFadeAmount())

	self:DrawInteriorDoubles()

	render.SetBlend(1)
end

function ENT:OnPortalRenderedOffset()
	self:DrawInsidePortal()
end

-- Get the opacity for everything in the void
-- Let's us fade in non-abruptly
function ENT:GetFadeAmount()
	return math.min(1, (CurTime() - self:GetCreationTime()) / 2)
end

function ENT:DrawInsidePortal()

	-- Define our own lighting environment for this
	render.SuppressEngineLighting(true)

	jazzvoid.SetupVoidLighting(self)

	local portalPos, portalAng = self:GetPortalPosAng()
	local center = self:GetPos() --+ portalAng:Up() * self.Size/2
	local ang = Angle(portalAng)
	ang:RotateAroundAxis(ang:Up(), -90)

	-- Draw a few random floating props in the void
	local num_props = 10
	for i = 1, num_props do

		local distZ = i * 120
		local virtual_prop_num = i
		if self:GetIsExit() then
			-- Get distance travelled into the void so we can do some wrap around magic
			local spacing = 500
			local dist = self:GetJazzVoidViewDistance()
			local prop_wrap = math.floor((dist - (i * spacing)) / (num_props * spacing)) + 1
			virtual_prop_num = prop_wrap * num_props + i
			distZ = i * spacing + prop_wrap * num_props * spacing
		end

		-- Lifehack: SharedRandom is a nice stateless random function
		local randX = util.SharedRandom("prop", -500, 500, virtual_prop_num)
		local randY = util.SharedRandom("prop", -500, 500, -virtual_prop_num)

		local offset = portalAng:Right() * (-200 - distZ)
		offset = offset + portalAng:Up() * randY
		offset = offset + portalAng:Forward() * randX

		-- Subtle twists and turns, totally arbitrary
		local angOffset = Angle(
			randX + CurTime()*randX/50,
			randY + CurTime()*randY/50,
			math.sin(randX + randY) * 360 + CurTime() * 10)

		-- Just go through the list of props, looping back
		local mdl = self.VoidProps[(i % #self.VoidProps) + 1]
		//debugoverlay.Sphere(center + offset, 10, 0, Color( 255, 255, 255 ), true)
		mdl:SetPos(center + offset)
		mdl:SetAngles(ang + angOffset)
		mdl:SetupBones() -- Since we're drawing in multiple locations
		mdl:DrawModel()
	end

	-- If we're the exit portal, draw the gibs floating into space
	if self:GetIsExit() and self.Broken then
		if CurTime() - self.BreakTime < 45 then
			for _, gib in pairs(self.Gibs) do
				if IsValid(gib) then gib:DrawModel() end
			end
		end
	end


	render.SuppressEngineLighting(false)
end

--vertices of road edges, relative to road's origin

local vertices = {
	[1] = Vector(-77.1566,0,0), --topside
	[2] = Vector(77.1566,0,-2.03954), --underside
	--note: this number is getting rounded when the actual quads are being drawn, however, our refraction effect makes it pretty much impossible to see this slight mismatch
	[3] = 77.1566 * 2	--width
}

local UVs = {
	[1] = 0.00387, --U start
	[2] = 1, --V start
	[3] = 0.99613, --U end
	--[4] = 0 --V end (determined by segment length)
}

local roadMat = Material("models/sunabouzu/jazzroad_static")
local roadMatUnder = Material("models/sunabouzu/jazzroad02")
local roadMatMove = Material("models/sunabouzu/jazzroad")

-- Draws doubles of things that are in the normal world too
-- (eg. the Bus, seats, other players, etc.)

function ENT:DrawInteriorDoubles()
	local portalPos, portalAng = self:GetPortalPosAng()

	-- Define our own lighting environment for this
	render.SuppressEngineLighting(true)
	jazzvoid.SetupVoidLighting(self)

	-- Draw background
	render.FogMode(MATERIAL_FOG_NONE) -- Disable fog so we can get those deep colors

	self.VoidTunnel:SetPos(portalPos - portalAng:Up() * self.Size/2)
	self.VoidTunnel:SetAngles(portalAng)
	self.VoidTunnel:SetupBones()
	self.VoidTunnel:SetModelScale(0.34)

	-- First draw with default material but darkened
	render.SetColorModulation(55/255.0, 55/255.0, 55/255.0)
	self.VoidTunnel:SetMaterial("")
	//self.VoidTunnel:DrawModel()
	render.SetColorModulation(1, 1, 1)

	-- Now two more times with each of sun's groovy additive jazz materials
	//self.VoidTunnel:SetMaterial("sunabouzu/jazzlake01")
	//self.VoidTunnel:DrawModel()

	-- Blend in so it doesn't all of a sudden pop into the jazz void

	self.VoidTunnel:SetMaterial("sunabouzu/jazzlake02")
	self.VoidTunnel:DrawModel()

	-- Draw a fixed border to make it look like cracks in the wall
	-- Disable fog for this, we want it to be seamless
	if self.Broken then
		render.OverrideDepthEnable(true, true)
		render.FogMode(MATERIAL_FOG_NONE)
		self.VoidBorder:SetPos(self:GetPos())
		self.VoidBorder:SetAngles(self:GetAngles())
		self.VoidBorder:SetMaterial(self.WallMaterial)
		self.VoidBorder:SetupBones()
		self.VoidBorder:DrawModel()

		-- Additional overlay pass
		if self.IsOnVoidWall then
			local _, overlay = jazzvoid.GetVoidOverlay()
			self.VoidBorder:SetMaterial(overlay:GetName())
			self.VoidBorder:DrawModel()
		end

		render.FogMode(MATERIAL_FOG_LINEAR)
		render.OverrideDepthEnable(false)
	end


	render.FogMode(MATERIAL_FOG_LINEAR)

	-- Draw the wiggly wobbly road into the distance
	self.VoidRoad:SetPos(portalPos - portalAng:Up() * self.Size/2)
	self.VoidRoad:SetAngles(portalAng)
	self.VoidRoad:SetupBones()
	self.VoidRoad:DrawModel()

	--Draw a connection between the two roads

	if IsValid(self.VoidRoad) and isnumber(self.roadDist) then
		--topside
		local pos, ang = self.VoidRoad:LocalToWorld( vertices[1] ), self.VoidRoad:GetAngles()
	
		cam.Start3D2D( pos, ang, 1 )
			surface.SetMaterial( self.Broken and IsValid(self:GetBus()) and self:GetBus().IsLaunching and roadMatMove or roadMat )
			surface.SetDrawColor( color_white )
			surface.DrawTexturedRectUV( 0, 0, vertices[3], self.roadDist, UVs[1], UVs[2], UVs[3], -self.roadDist / vertices[3] )
			--debugoverlay.Axis( self.VoidRoad:GetPos(), self.VoidRoad:GetAngles(), 32, 1, true )
			--debugoverlay.Axis( pos, ang, 100, 1, true )
		cam.End3D2D()
		
		--bottom
		pos = self.VoidRoad:LocalToWorld( vertices[2] )
		ang:RotateAroundAxis(self.VoidRoad:GetAngles():Forward(),180)
		ang:RotateAroundAxis(self.VoidRoad:GetAngles():Up(),180)

		cam.Start3D2D( pos, ang, 1 )
			surface.SetMaterial( roadMatUnder )
			surface.SetDrawColor( color_white )
			surface.DrawTexturedRectUV( 0, 0, vertices[3], self.roadDist, UVs[1], UVs[2], UVs[3], -self.roadDist / vertices[3] )
			--debugoverlay.Axis( self.VoidRoad:GetPos(), self.VoidRoad:GetAngles(), 32, 1, true )
			--debugoverlay.Axis( pos, ang, 100, 1, true )
		cam.End3D2D()

	end


	-- Render speedy tunnel
	if self.Broken and self:GetIsExit() and IsValid(self:GetBus()) and self:GetBus().IsLaunching then
		local mat = Matrix()
		mat:SetScale(Vector(8, 1, 8))
		local SpeedTunnel = ManagedCSEnt("bus_portal_speedtunnel", self.VoidSpeedTunnelModel)
		SpeedTunnel:SetNoDraw(true)
		SpeedTunnel:SetPos(portalPos - portalAng:Up() * self.Size/2)
		SpeedTunnel:SetAngles(portalAng)
		SpeedTunnel:EnableMatrix("RenderMultiply", mat)
		SpeedTunnel:DrawModel()
	end



	-- Draw bus
	if IsValid(self:GetBus()) then
		self:GetBus():Draw()
		if self:GetIsExit() then -- Don't render the empty seats because the bus is doing some matrix magic on enter
			local childs = self:GetBus():GetChildren()
			for _, v in pairs(childs) do
				v:DrawModel()
			end
		end
	end

	-- Draw players (only applies if exiting)
	-- NOTE: Usually this is a bad idea, but legitimately every single player should be in the bus
	if self:GetIsExit() then
		for _, ply in pairs(player.GetAll()) do
			local seat = ply:GetVehicle()
			if IsValid(seat) and seat:GetParent() == self:GetBus() then
				ply:DrawModel()
			end
		end
	end

	render.SuppressEngineLighting(false)
end

-- Right when we switch over to the jazz dimension, the bus will stop moving
-- So we immediately start 'virtually' moving through the jazz dimension instead
-- IDEALLY I'D LIKE TO RETURN A VIEW MATRIX, BUT GMOD DOESN'T HANDLE THAT VERY WELL
function ENT:GetJazzVoidViewDistance()
	local bus = self:GetBus()
	if !self.VoidTime or !IsValid(bus) then return 0 end

	-- Counteract remaining bus movement
	local busOff = self:DistanceToVoid(EyePos())

	local t = CurTime() - self.VoidTime
	return (bus.JazzSpeed * 3 * t - busOff)

end

function ENT:GetJazzVoidView()
	local bus = self:GetBus()
	if !IsValid(bus) then return Vector() end
	return bus:GetBusForward() * self:GetJazzVoidViewDistance()
end

function ENT:OnBroken()
	self.BreakTime = CurTime()

	-- Draw and wake up every gib
	for _, gib in pairs(self.Gibs) do

		local phys = gib:GetPhysicsObject()

		-- Gibs are manually drawn for exit portal (they're in the void)
		if !self:GetIsExit() then
			gib:SetNoDraw(false)
		elseif IsValid(phys) then
			phys:EnableGravity(false)
		end
		if IsValid(phys) then
			phys:Wake()
			local mult = self:GetIsExit() and -2 or 1 -- Break INTO the void, not out of
			local force = math.random(400, 900) * mult
			phys:SetVelocity(self:GetAngles():Right() * force + VectorRand() * 100)
			phys:AddAngleVelocity(VectorRand() * 100)
		end
	end

	-- Effects
	local center = self:GetPos()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Right(), 90)

	local ed = EffectData()
	ed:SetScale(10)
	ed:SetMagnitude(30)
	ed:SetEntity(self)
	ed:SetOrigin(center)
	ed:SetAngles(ang)

	util.Effect("HelicopterMegaBomb", ed)

	self:EmitSound("ambient/machines/wall_crash1.wav", 110)
	self:EmitSound("ambient/machines/thumper_hit.wav", 110)

	util.ScreenShake(self:GetPos(), 15, 3, 3, 1000)

	local ed2 = EffectData()
	ed2:SetStart(self:GetPos())
	ed2:SetOrigin(self:GetPos())
	ed2:SetScale(100)
	ed2:SetMagnitude(100)
	ed2:SetNormal(self:GetAngles():Right())

	-- TODO: Glue these to the bus's two front wheels
	util.Effect("ManhackSparks", ed2, true, true)

	self.BackgroundHum:SetSoundLevel(60)
	self.BackgroundHum:Play()

	-- Start rendering the portal view
	self.RenderView = true
end

function ENT:DrawPortal()
	if !self.RenderView then return end

	-- Don't bother rendering if the eyes are behind the plane anyway
	if self:DistanceToVoid(EyePos(), true) < 0 then return end
	self.DrawingPortal = true
	local lastclip = render.EnableClipping(false)
	render.SetStencilEnable(true)
		render.SetStencilWriteMask(255)
		render.SetStencilTestMask(255)
		render.ClearStencil()

		-- First, draw where we cut out the world
		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_REPLACE)

		-- Push this slightly outward to prevent z fighting with the surface
		self:EnableMatrix("RenderMultiply", self.ZBump)
		self:DrawModel()
		self:DisableMatrix("RenderMultiply")

		-- Second, draw the interior
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.ClearBuffersObeyStencil(55, 0, 55, 255, true)

		cam.Start2D()
			render.DrawTextureToScreen(jazzvoid.GetVoidTexture())
		cam.End2D()


		-- Draw into the depth buffer for the interior to prevent
		-- Props from going through
		render.OverrideColorWriteEnable(true, false)
			self:DrawModel()
		render.OverrideColorWriteEnable(false, false)

	render.SetStencilEnable(false)
	render.EnableClipping(lastclip)

	self.DrawingPortal = false
end

function ENT:Draw()
	if !self.RenderView then return end
	if !self.DrawingPortal then return end
	self:DrawModel()
end



-- PostRender and PostDrawOpaqueRenderables are what draws the stencil portal in the world
hook.Add("PostRender", "JazzClearExteriorVoidList", function()
	local portals = LocalPlayer().ActiveBusPortals
	if !portals then return end

	table.Empty(portals)
end )

hook.Add("PreDrawTranslucentRenderables", "JazzBusDrawExteriorVoid", function(depth, sky)
	local portals = LocalPlayer().ActiveBusPortals
	if !portals then return end

	for _, v in pairs(portals) do
		if IsValid(v) and v.DrawPortal then
			v:DrawPortal()
		end
	end
end )

-- Override PreDraw*Renderables to not draw _anything_ if we're inside the portal
hook.Add("PreDrawOpaqueRenderables", "JazzHaltWorldRender", function(depth, sky)
	if IsInExitPortal() then return true end
end )
hook.Add("PreDrawTranslucentRenderables", "JazzHaltWorldRender", function()
	if IsInExitPortal() then return true end
end )
hook.Add("PreDrawSkyBox", "JazzHaltSkyRender", function()
	if IsInExitPortal() then return true end
end)

-- Totally overrwrite the world with the custom void world
hook.Add("PreDrawEffects", "JazzDrawPortalWorld", function()
	jazzvoid.void_view_offset = Vector()
	local exitPortal = GetExitPortal()
	if !IsValid(exitPortal) then return end

	--start rolling
	if IsValid(exitPortal.VoidRoad) and exitPortal.VoidRoad:GetSkin() == 1 then exitPortal.VoidRoad:SetSkin(0) end

	-- If the local player's view is past the portal 'plane', ONLY render the jazz dimension
	local origin = EyePos()
	local angles = EyeAngles()

	if exitPortal:DistanceToVoid(origin) > 0 then

		local voffset = exitPortal:GetJazzVoidView()
		jazzvoid.void_view_offset = voffset
		jazzvoid.UpdateVoidTexture(origin, angles)

		render.Clear(55, 0, 55, 255, true, true) -- Dump anything that was rendered
		cam.Start2D()
			render.DrawTextureToScreen(jazzvoid.GetVoidTexture())
		cam.End2D()
	end
end )
