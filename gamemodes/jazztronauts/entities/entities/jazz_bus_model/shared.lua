--dummy model of the trolley with a destination screen for use in map scenes so people don't think they need to install CSS

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.PrintName		= "#jazz_bus"
ENT.Author			= ""
ENT.Information		= ""
ENT.Category		= "#jazz.weapon.category"
ENT.Spawnable		= true
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/matt/jazz_trolley.mdl" )
ENT.Editable		= true

function ENT:Initialize()

	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	local phys = self:GetPhysicsObject()
	if phys then
		phys:EnableGravity( false )
		phys:EnableMotion( false )
		phys:Wake()
	end

end

function ENT:SetupDataTables()
	self:NetworkVar("String",	0, "Destination",	{ KeyName = "destination",	Edit = { type = "Generic",	order = 1 } } )
end

function ENT:KeyValue( key, value )
	if key == "destination" then self:SetDestination(tostring(value)) end
end

if CLIENT then
	
	local destRTWidth = 256
	local destRTHeight = 256
	local screen_rt = irt.New("jazz_bus_destination", destRTWidth, destRTHeight )

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

	function ENT:Draw()
		self:DrawRTScreen(jazzloc.Localize(self:GetDestination()))
		render.MaterialOverrideByIndex(1, screen_rt:GetUnlitMaterial())
		self:DrawModel()
		render.MaterialOverrideByIndex(0, nil)
	end

end