include("shared.lua")

ENT.RenderGroup	= RENDERGROUP_TRANSLUCENT

local AttentionMarker = Material("materials/ui/jazztronauts/wtf.png", "smooth")
surface.CreateFont("BlackShardDoorCount", {
	font = "Palatino Linotype",
	extended = false,
	size = 50,
	weight = 500,
	antialias = false,
	shadow = true,
})

sound.Add( {
	name = "jazz_blackshard_door",
	channel = CHAN_STATIC,
	volume = 0.95,
	level = 65,
	pitch = 30,
	sound = "jazztronauts/blackshard_hum.wav"
} )
ENT.HumSoundPath = "jazz_blackshard_door"
ENT.CandleModel = Model("models/sunabouzu/gameplay_candle.mdl")
ENT.CandleRadiusX = 75
ENT.CandleRadiusY = 50
ENT.CandleEnts = {}
ENT.CandleFX = {}

function ENT:Initialize()
	self.MarkerName = "bad_boy" .. tostring(self)
	worldmarker.Register(self.MarkerName, AttentionMarker, 150)
	worldmarker.Update(self.MarkerName, self:GetPos() + Vector(0, 0, 50))

	-- Number counter
	self.CountMarkerName = "bad_boy_counter" .. tostring(self)
	worldmarker.Register(self.CountMarkerName, AttentionMarker, 150)
	worldmarker.Update(self.CountMarkerName, self:GetPos() + Vector(0, 0, 50))
	worldmarker.SetRenderFunction(self.CountMarkerName, EclipseDoorCountMarkerRender)
	worldmarker.markers[self.CountMarkerName].ShardsCollected = mapgen.GetTotalCollectedBlackShards()
	worldmarker.markers[self.CountMarkerName].ShardsRequired = mapgen.GetTotalRequiredBlackShards()

	-- Spawn candles around as an additional progress indicator
	self:SpawnShardCount()

	self:EmitSound(self.HumSoundPath, 75, 25, 1)
end

function ENT:OnRemove()
	self:StopSound(self.HumSoundPath)
end

function ENT:SpawnShardCount()
	local shardcount = mapgen.GetTotalCollectedBlackShards()
	local required = mapgen.GetTotalRequiredBlackShards()

	if not tobool(newgame.GetGlobal("encounter_1")) then return end
	self.CandleEnts = self.CandleEnts or {}
	self.CandleFX = self.CandleFX or {}

	for i=1, required do
		local p = i * 1.0 / required
		local ang = 2 * math.pi * p
		local candle = ManagedCSEnt("badboy_candle_" .. i, self.CandleModel)
		candle:SetNoDraw(false)
		candle:SetPos(self:GetPos() + Vector(math.cos(ang) * self.CandleRadiusX, math.sin(ang) * self.CandleRadiusY, -9))

		table.insert(self.CandleEnts, candle)

		hook.Add("JazzNoDrawInScene",candle,function()
			if (LocalPlayer():GetInScene() and dialog.GetParam("RENDER_DYNAMICENTS") ~= "true") or dialog.GetParam("RENDER_DYNAMICENTS") == "false" then
				candle:SetNoDraw(true)
			else
				candle:SetNoDraw(false)
			end
		end)
		
		if shardcount > 0 then
			shardcount = shardcount - 1
			local candlefx = CreateParticleSystem(candle:Get(),"jazzCandle",PATTACH_ABSORIGIN_FOLLOW,0,Vector(0, 0, 12)) --ParticleEffect("jazzCandle", candle:GetPos() + Vector(0, 0, 12), candle:GetAngles(), candle:Get() )
			table.insert(self.CandleFX, candlefx)

			hook.Add("JazzNoDrawInScene",candlefx,function()
				if (LocalPlayer():GetInScene() and dialog.GetParam("RENDER_DYNAMICENTS") ~= "true") or dialog.GetParam("RENDER_DYNAMICENTS") == "false" then
					candlefx:SetShouldDraw(false)
				else
					candlefx:SetShouldDraw(true)
				end
			end)
		end
	end
end

function ENT:UpdateWorldMarker()
	local dest = self:GetDestination()
	worldmarker.SetEnabled(self.MarkerName, dest != nil)
	worldmarker.SetEnabled(self.CountMarkerName, self.ShardsCollected and self.ShardsCollected > 0)
end

local oldSceneStatus = false

function ENT:Think()
	self:UpdateWorldMarker()

	self.ShardsCollected = mapgen.GetTotalCollectedBlackShards()
	self.ShardsRequired =  mapgen.GetTotalRequiredBlackShards()

	self:SetNextClientThink(CurTime() + 2)

	if oldSceneStatus ~= LocalPlayer():GetInScene() then
		if (LocalPlayer():GetInScene() and dialog.GetParam("RENDER_DYNAMICENTS") ~= "true") or dialog.GetParam("RENDER_DYNAMICENTS") == "false" then
			self:StopSound(self.HumSoundPath)
		else
			self:EmitSound(self.HumSoundPath, 75, 25, 1)
		end
	end

	oldSceneStatus = LocalPlayer():GetInScene()

	return true
end

function EclipseDoorCountMarkerRender(self, scrpos, visible)
	local dist2 = (EyePos() - self.pos):LengthSqr()
	local left = self.ShardsRequired - self.ShardsCollected
	local visible = visible - dist2 * 0.00000005
	local text = jazzloc.Localize((left == 1 and "jazz.blacksharddoor.one" or "jazz.blacksharddoor.remain"),left)
	draw.SimpleText(text, "BlackShardDoorCount", scrpos.x, scrpos.y, Color(200, 50, 50, visible * 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ENT:Draw()

	if (LocalPlayer():GetInScene() and dialog.GetParam("RENDER_DYNAMICENTS") ~= "true") or dialog.GetParam("RENDER_DYNAMICENTS") == "false" then return end

	self:DrawModel()

end