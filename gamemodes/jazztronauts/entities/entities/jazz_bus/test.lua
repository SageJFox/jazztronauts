AddCSLuaFile()

--sounds used
sound.Add( {
	name = "jazz_bus_accelerate",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = { 95, 110 },
	sound = "vehicles/v8/v8_turbo_on_loop1.wav"
} )

sound.Add( {
	name = "jazz_bus_accelerate2",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = { 95, 110 },
	sound = "vehicles/v8/v8_rev_short_loop1.wav"
} )

sound.Add( {
	name = "jazz_bus_idle",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = { 95, 110 },
	sound = "vehicles/v8/v8_start_loop1.wav"
} )

-- use this function to set up any variables you're going to need, or attach any other weird shit to your model
function ENT:PreInit()
	self.Model			= Model( "models/sunabouzu/jazzbus.mdl" )
	self.HalfLength		= 300
	self.JazzSpeed		= 800 -- How fast to explore the jazz dimension

	self.RadioMusicName = "jazztronauts/music/que_chevere_radio_loop.wav"
	self.RadioModel = "models/props_lab/citizenradio.mdl"

	self.VoidMusicName = "jazztronauts/music/que_chevere_travel_fade.mp3"
	self.VoidMusicPreroll = 2.9 -- how many seconds it takes to get to the chorus
	self.VoidMusicFadeStart = 12.0
	self.VoidMusicFadeEnd   = 19.0
	
	self.SpectateCamOffset = Vector(0, 0, 110)

	self.CrashSound = { "vehicles/v8/vehicle_impact_heavy1.wav", 90, 150 }
	self.SkidSound = { "vehicles/v8/skid_normalfriction.wav", 90, 110 }
	self.EngineOffSound = { "vehicles/v8/v8_stop1.wav", 90, 110 }
	self.DingSound = { "jazztronauts/trolley/jazz_trolley_bell.wav", 90, 110 }

	if CLIENT then
		self.ScreenHeight = 0
		self.ScreenWidth = self.ScreenHeight * 1.80
		self.ScreenScale = .1

		self.CommentOffset = Vector(-200, 12, 0)

		self.BusWidth = 70
		self.BusLength = 248
	end
end

-- set up seats and their offsets.
-- use self:AttachSeat( vector pos, angle ang, string [model, default airboat seat], bool [nodraw, default false] ) for each seat
-- bus needs at least one seat!
function ENT:AttachSeats()
	for i=1, 10 do
		self:AttachSeat(Vector(40, i * 40 - 180, 80), Angle(0, 180, 0),"models/nova/jeep_seat.mdl")
		self:AttachSeat(Vector(-40, i * 40 - 180, 80), Angle(0, 180, 0),"models/nova/jeep_seat.mdl")
	end
end

--play those funky tunes
function ENT:AttachRadio()
	if self:GetHubBus() then return end

	local pos = self:LocalToWorld(Vector(40, -190, 40))
	local ang = self:LocalToWorldAngles(Angle(0, 150, 0))

	-- Make a "fake" version of the radio, the "real" one can be stolen.
	local ent = ents.Create("jazz_static_proxy")
	if IsValid(ent) then
		ent:SetModel(self.RadioModel)
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:SetParent(self)
		ent:Spawn()
		ent:Activate()
		self.Radio = ent
	end

	local radio_ent = ents.Create("prop_dynamic")
	if IsValid(radio_ent) then
		radio_ent:SetModel(self.RadioModel)
		radio_ent:SetPos(pos)
		radio_ent:SetAngles(ang)
		radio_ent:SetParent(ent)
		radio_ent:Spawn()
		radio_ent:Activate()
		radio_ent:SetNoDraw(not self:GetHubBus())
		self.RadioEnt = radio_ent

		-- Attach a looping audiozone
		if SERVER then
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			self.RadioMusic = CreateSound(ent, self.RadioMusicName, rf)
			hook.Add("EntityRemoved", "JazzBusRadioCheck", function(removed)
				if removed ~= radio_ent then return end
				self.RadioMusic:Stop()
				ent:Remove()
			end)
		end
	end
end

--what direction is forward?
function ENT:GetBusForward()
	return self:GetAngles():Right()
end
-- what constitutes the front and rear sides of the bus
function ENT:GetFront()
	return self:GetPos() + self:GetBusForward() * self.HalfLength
end

function ENT:GetRear()
	return self:GetPos() + self:GetBusForward() * -self.HalfLength
end

--given this angle for our spawn portals, return a rotation that puts us facing the right direction
function ENT:SpawnRotation(spawnang)
	if not isangle(spawnang) then return angle_zero end
	return spawnang
end

--how our position needs to be adjusted when spawning
function ENT:SpawnOffset(start)
	if self:GetHubBus() then
		return start + self:GetBusForward() * -self.LeadUp + Vector(0, 0, 40)
	else
		local spawnPos = start + LocalToWorld(Vector(0,0,-92),angle_zero,vector_origin,self:GetAngles()) --adjust from center of bus portal
		spawnPos = spawnPos + self:GetBusForward() * (-self.HalfLength - 20) + Vector(0, 0, 20) --stick us back into the wall
		return spawnPos
	end
end
--how our position needs to be adjusted for our initial goal
function ENT:GoalOffset(start)
	if self:GetHubBus() then
		return start
	else
		return self:GetFront()
	end
end

if SERVER then return end

-------------------------------------------------------------------------------
--------------------------------- CLIENT REALM---------------------------------
-------------------------------------------------------------------------------

surface.CreateFont( "SteamCommentFont", {
	font	  = "KG Shake it Off Chunky",
	size	  = 70,
	weight	= 700,
	antialias = true
})

surface.CreateFont( "SteamAuthorFont", {
	font	  = "Dancing Script",
	size	  = 65,
	weight	= 700,
	antialias = true
})

surface.CreateFont( "JazzDestinationFont", {
	font	  = "Dancing Script",
	size	  = 53,
	weight	= 700,
	antialias = true
})

-- drawing the destination
local destRTWidth = 256
local destRTHeight = 256
local screen_rt = irt.New("jazz_bus_destination_explore", destRTWidth, destRTHeight )

function ENT:DrawRTScreen(dest)
	local dest = dest or "LOLOLOLOLOLOLOLOLOLOLOL"
	screen_rt:Render(function()
		local c = HSVToColor(RealTime() * 20 % 360, .7, 0.4)
		render.Clear(c.r, c.g, c.b, 255)
		cam.Start2D()
			surface.SetFont("JazzDestinationFont")
			local w, h = surface.GetTextSize(dest)
			local mwidth = destRTWidth
			local mat = Matrix()
			if w > mwidth then
				mat:Scale(Vector(mwidth/w, 1, 1))
			else
				mat:Translate(Vector(mwidth/2 - w/2, 0, 0))
			end

			cam.PushModelMatrix(mat)
				draw.SimpleText(dest, "JazzDestinationFont", 0, h * -0.2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			cam.PopModelMatrix()
		cam.End2D()
	end)
end

local function ProgressString(col, total)
	if col == total then
		return total == 1 and jazzloc.Localize("jazz.shards.all1",total) or jazzloc.Localize("jazz.shards.all",total)
	end

	return jazzloc.Localize("jazz.shards.partial",col,total)
end

function ENT:DrawSideInfo()
	local ang = self.Entity:GetAngles()
	local pos = self.Entity:GetPos() - ang:Forward() * self.BusWidth
	pos = pos + ang:Up() * 76

	ang:RotateAroundAxis( ang:Forward(), 90 )
	ang:RotateAroundAxis( ang:Right(), 90 )

	//render.DrawLine( pos, pos + 8 * ang:Forward(), Color( 255, 0, 0 ), true )
	//render.DrawLine( pos, pos + 8 * -ang:Right(), Color( 0, 255, 0 ), true )
	//render.DrawLine( pos, pos + 8 * ang:Up(), Color( 0, 0, 255 ), true )

	pos = pos - ang:Forward() * self.ScreenScale * self.ScreenWidth / 2
	pos = pos - ang:Right() * self.ScreenScale * self.ScreenHeight / 2

	cam.Start3D2D(pos, ang, self.ScreenScale)
		if self.ThumbnailMat then
			surface.SetMaterial(self.ThumbnailMat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(-156, 0, 356, 356)
		end

		if self.Title then
			draw.SimpleText( self.Title, "SmallHeaderFont", 220, 160, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
		end
		draw.SimpleText( self:GetDestination(), "SelectMapFont", 220, 0, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

		if self:GetMapProgress() > 0 then
			local coll, total = self:FromProgressMask(self:GetMapProgress())
			local str = ProgressString(coll, total)
			local col = coll == total and Color(243, 235, 0, 255) or color_white
			draw.SimpleText(str, "SmallHeaderFont", 220, 195, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
		end

		if self:GetHubBus() and self.Description then
			local w = self.Description:GetWidth()
			local h = self.Description:GetHeight()
			local scaleOff = self.CommentOffset / self.ScreenScale
			self.Description:Draw(w/2 + scaleOff.x, scaleOff.y, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

	cam.End3D2D()
end

function ENT:DrawRearInfo()
	local ang = self.Entity:GetAngles()
	local pos = self.Entity:GetPos() - ang:Right() * self.BusLength
	pos = pos + ang:Up() * 80

	ang:RotateAroundAxis( ang:Forward(), 90 )
	ang:RotateAroundAxis( ang:Right(), 180 )


	//render.DrawLine( pos, pos + 8 * ang:Forward(), Color( 255, 0, 0 ), true )
	//render.DrawLine( pos, pos + 8 * -ang:Right(), Color( 0, 255, 0 ), true )
	//render.DrawLine( pos, pos + 8 * ang:Up(), Color( 0, 0, 255 ), true )

	cam.Start3D2D(pos, ang, self.ScreenScale)
		if self.BackBusComment then
			local w = self.BackBusComment:GetWidth()
			local h = self.BackBusComment:GetHeight()
			local scaleOff = self.CommentOffset / self.ScreenScale
			self.BackBusComment:Draw(0, 0, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

	cam.End3D2D()
end

-- drawing the bus itself
function ENT:Draw()
	--self:DrawRTScreen(self.dest)
	--render.MaterialOverrideByIndex(1, screen_rt:GetUnlitMaterial())

	local offset = self:GetStartOffset()
	if offset < 0 then
		local offsetMat = Matrix()
		offsetMat:Translate(Vector(0, -offset, 0))
		self:EnableMatrix("RenderMultiply", offsetMat)
	else
		self:DisableMatrix("RenderMultiply")
	end

	self:DrawModel()
	render.MaterialOverrideByIndex(0, nil)
	
	--if self:GetHubBus() then
		self:DrawSideInfo()
		self:DrawRearInfo()
	--end
end

--this is all hub bus from here

hook.Add( "GetMotionBlurValues", "BusLaunchBlur", function( horiz, vert, fwd, rot)
	local bus = LocalPlayer().LaunchingBus
	if !IsValid(bus) or not bus:GetHubBus() then return end

	fwd = fwd + (CurTime() - bus.StartLaunchTime) * 0.3
	return horiz, vert, fwd, rot
end )

hook.Add( "CalcView", "BusLaunchView", function(ply, pos, angles, fov )
	local bus = LocalPlayer().LaunchingBus
	if !IsValid(bus) or not bus:GetHubBus() then return end

	local view = {}

	view.origin = pos
	view.angles = angles
	view.fov = fov + (CurTime() - bus.StartLaunchTime) * 20

	return view
end )

local fadewhite = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

hook.Add( "RenderScreenspaceEffects", "BusLaunchScreenspaceEffects", function()
	local bus = LocalPlayer().LaunchingBus
	if !IsValid(bus) or not bus:GetHubBus() then return end

	local factor = math.max((CurTime() - bus.StartLaunchTime) * 0.2 - 0.2, 0)
	fadewhite["$pp_colour_brightness"] = factor
	fadewhite["$pp_colour_colour"] = 1 + factor
	DrawColorModify(fadewhite)
end )

net.Receive("jazz_bus_launcheffects", function(len, ply)
	local busEnt = net.ReadEntity()
	if IsValid(busEnt) and busEnt:GetHubBus() then
		busEnt:StartLaunchEffects()
	end

	--transitionOut(2.5)
end )