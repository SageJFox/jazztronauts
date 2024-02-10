include("shared.lua")

ENT.ScreenHeight = 0
ENT.ScreenWidth = ENT.ScreenHeight * 1.80
ENT.ScreenScale = .1

ENT.CommentOffset = Vector(-200, 12, 0)

ENT.BusWidth = 70
ENT.BusLength = 248

local destRTWidth = 256
local destRTHeight = 256
local screen_rt = irt.New("jazz_bus_destination_explore", destRTWidth, destRTHeight )

function ENT:Initialize()
	
end

function ENT:DrawRTScreen(dest)
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

function ENT:StartLaunchEffects()
	print("Starting clientside launch")
	self.IsLaunching = true
	self.StartLaunchTime = CurTime()
	LocalPlayer().LaunchingBus = self
end

function ENT:GetStartOffset()
	if not self.GetBreakTime or self:GetBreakTime() <= 0 then return 0 end
	return math.min(0, (CurTime() - self:GetBreakTime()) * 2000)
end

local dest = jazzloc.Localize("jazz.bus.bar")

function ENT:Draw()
	self:DrawRTScreen(dest)
	render.MaterialOverrideByIndex(2, screen_rt:GetUnlitMaterial())

	local offset = self:GetStartOffset()
	if offset < 0 then
		local offsetMat = Matrix()
		offsetMat:Translate(Vector(0, -offset, 0))
		self:EnableMatrix("RenderMultiply", offsetMat)
	else
		self:DisableMatrix("RenderMultiply")
	end

	self:DrawModel()
	render.MaterialOverrideByIndex(1, nil)
end

function ENT:Think()

end

function ENT:OnRemove()

end

net.Receive("jazz_bus_explore_voideffects", function(len, ply)
	local bus = net.ReadEntity()
	local startTime = net.ReadFloat()
	local nomusic = net.ReadBool()

	-- Queried elsewhere for certain effects
	if IsValid(bus) then
		bus.IsLaunching = true
	end

	local waitTime = math.max(0, startTime - CurTime())
	if not nomusic then
		timer.Simple(waitTime, function()
			if IsValid(bus) then
				surface.PlaySound(bus.VoidMusicName)
			end
		end )
	end

	local fadeWaitTime = waitTime + bus.VoidMusicFadeStart
	transitionOut(fadeWaitTime + 7)

	timer.Simple(fadeWaitTime, function()
		if IsValid(bus) and LocalPlayer():InVehicle() then
			local fadelength = bus.VoidMusicFadeEnd - bus.VoidMusicFadeStart
			LocalPlayer():ScreenFade(SCREENFADE.OUT, color_white, fadelength, 15)
		end
	end)
end )