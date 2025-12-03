AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Model = "models/sunabouzu/shard_tank.mdl"

ENT.AnimationActivated = false
ENT.PodiumRadius = 100
ENT.PodiumArc = 130
ENT.PodiumRotation = 0
ENT.UseApproach = false

-- Default model's expected RT material index (can change on model edits!)
local rtmatdefault = 3

util.PrecacheModel("models/sunabouzu/jazzshard.mdl")

function ENT:SetupDataTables()
	self:NetworkVar("Int", "CollectedShards")
	self:NetworkVar("Int", "RTMat")
	self:NetworkVar("Int", "ApproachRadius")
	self:NetworkVar("Int", "FillSeq")
	self:NetworkVar("Int", "AnimShardRate")
	self:NetworkVar("Bool", "DisableDrop")
	self:NetworkVar("Int", "DropHeight")
	self:NetworkVar("Int", "LiquidBottom")
	self:NetworkVar("Int", "LiquidHeight")
	-- I really hate doing this but I can't find another way that consistently works
	self:NetworkVar("String", "TankIncreaseSound")
	self:NetworkVar("String", "TankAmbientSound")
	self:NetworkVar("Float", "TankIncreaseSoundVolume")
	self:NetworkVar("Int", "TankIncreaseSoundLow")
	self:NetworkVar("Int", "TankIncreaseSoundHigh")
	if SERVER then
		self:SetRTMat(rtmatdefault)
		self:SetApproachRadius(300)
		self:SetFillSeq(1) --self:LookupSequence("Fill_Tank")) --doesn't wanna load properly from this
		self:SetAnimShardRate(8)
		self:SetDisableDrop(false)
		self:SetDropHeight(400)
		self:SetLiquidBottom(10)
		self:SetLiquidHeight(110)
		self:SetTankIncreaseSound("jazztronauts/jazz_tank_choir.wav")
		self:SetTankIncreaseSoundVolume(1)
		self:SetTankIncreaseSoundLow(50)
		self:SetTankIncreaseSoundHigh(75)
		self:SetTankAmbientSound("ambient/water/water_in_boat1.wav")
	end
end

local outputs =
{
	"OnOccupied",
	"OnUnoccupied"
}

function ENT:KeyValue(key, value)

	if key == "model" then
		self.Model = value
	elseif key == "skin" then
		local val = tonumber(value)
		if not val then return end
		self:SetSkin(val)
	elseif key == "rtmat" then
		self:SetRTMat(tonumber(value) or rtmatdefault)
	elseif key == "ApproachRadius" then
		self:SetApproachRadius(tonumber(value) or 300)
	elseif key == "PodiumRadius" then
		self.PodiumRadius = tonumber(value) or 100
	elseif key == "PodiumArc" then
		self.PodiumArc = tonumber(value) or self.PodiumArc
	elseif key == "PodiumRotation" then
		self.PodiumRotation = tonumber(value) or 0
	elseif key == "UseApproach" then
		self.UseApproach = tobool(value)
	elseif key == "DefaultAnim" then
		if value == "" then value = "Fill_Tank" end
		--Delay so model can get set properly
		timer.Simple(0, function()
			if not IsValid(self) then return end
			self:SetFillSeq(self:LookupSequence(value))
		end)
	elseif key == "DisableDrop" then
		self:SetDisableDrop(tobool(value))
	elseif key == "DropHeight" then
		self:SetDropHeight(tonumber(value) or 400)
	elseif key == "AnimShardRate" then
		self:SetAnimShardRate(tonumber(value) or 8)
	elseif key == "LiquidBottom" then
		self:SetLiquidBottom(tonumber(value) or 10)
	elseif key == "LiquidHeight" then
		self:SetLiquidHeight(tonumber(value) or 110)
	elseif key == "TankIncreaseSound" then
		self:SetTankIncreaseSound(value)
	elseif key == "TankIncreaseSoundVolume" then
		local val = tonumber(value)
		if not val then return end
		self:SetTankIncreaseSoundVolume(val)
	elseif key == "TankIncreaseSoundLow" then
		local val = tonumber(value)
		if not val then return end
		self:SetTankIncreaseSoundLow(val)
	elseif key == "TankIncreaseSoundHigh" then
		local val = tonumber(value)
		if not val then return end
		self:SetTankIncreaseSoundHigh(val)
	elseif key == "TankAmbientSound" then
		self:SetTankAmbientSound(value)
	end

	if table.HasValue(outputs, key) then
		self:StoreOutput(key, value)
	end

end

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)

		if IsValid(phys) then
			phys:EnableMotion(false)
		end
		self:PhysicsInitShadow(false,false)
		self:SetSequence(self:GetFillSeq())

		self:SetCollectedShards(progress.GetMapShardCount())

		local ended = tobool(newgame.GetGlobal("ended"))

		-- If above shard threshold, spawn the group vote to start endgame
		if progress.GetMapShardCount() >= mapgen.GetTotalRequiredShards() or ended then
			local voter = ents.Create("jazz_vote_podiums")
			voter:SetKeyValue("PodiumRadius", self.PodiumRadius)
			voter:SetKeyValue("ApproachRadius", self:GetApproachRadius())
			voter:SetKeyValue("Friendly", "1")
			voter:SetPos(self:GetPos())
			if not self.UseApproach then
				voter.PodiumSemiAngle = math.rad(self:GetAngles().y + self.PodiumRotation)
			end
			voter.PodiumSemiCircle = math.rad(self.PodiumArc)
			voter.RequiresPercentage = true
			voter:Spawn()
			voter:Activate()
			voter:StoreActivatedCallback(function(who_found)
				self:OnStartTravel()
			end )

			self.EndgameVoter = voter
		end
	end

	function ENT:OnStartTravel()
		local ending, isended = newgame.GetGlobal("ending"), tobool(newgame.GetGlobal("ended"))
		if not isended then
			self:StartEndgameDialog()
		else -- NG+ Reset
			newgame.ResetGame(tonumber(ending) or newgame.ENDING_CHEATED)
		end
	end

	function ENT:StartEndgameDialog()
		local diag = ents.Create("jazz_dialog")
		diag:SetPos(self:GetPos())
		diag:SetKeyValue("script", "normal_ending_bartransition.begin")
		diag:SetKeyValue("spawnflags", "1") -- send to everybody
		diag:SetFinishedCallback(function()
			newgame.SetGlobal("ending", newgame.ENDING_ASH)
			mapcontrol.Launch(mapcontrol.GetEndMaps()[newgame.ENDING_ASH])
		end )
		diag:Spawn()
		diag:Activate()
		diag:Fire("Start")
	end

else
	ENT.TankSplashSounds = {
		"ambient/water/water_splash1.wav",
		"ambient/water/water_splash2.wav",
		"ambient/water/water_splash3.wav"
	}

	ENT.FinishedAnimation = false
	ENT.DisableDrop = false
	ENT.AnimationStartShards = 0
	ENT.AnimShardCount = 0
	ENT.AnimShardRate = 8 --shards per second to drop into shard soup
	ENT.LiquidBottom = 10
	ENT.LiquidHeight = 110
	ENT.TankIncreaseSoundVolume = 1
	ENT.TankIncreaseSoundLow = 50
	ENT.TankIncreaseSoundHigh = 75

	ENT.GoalCompletePercent = 0

	local sizeX = 256
	local sizeY = 256
	local screen_rt = irt.New("jazz_shardtank_screen", sizeX, sizeY)

	surface.CreateFont( "JazzShardTankFont", {
		font = "KG Shake it Off Chunky",
		extended = false,
		size = 65,
		weight = 500,
		antialias = true,
	} )

	surface.CreateFont( "JazzShardTankSubtextFont", {
		font = "KG Shake it Off Chunky",
		extended = false,
		size = 25,
		weight = 500,
		antialias = true,
	} )

	function ENT:Initialize()
		--Delay so model can get set properly
		timer.Simple(0, function()
			self:SetSequence(self:GetFillSeq())
		end)
		--not changing once set so no need to constantly fetch these
		self.RTMat = self:GetRTMat()
		self.ApproachRadius = self:GetApproachRadius()
		self.DisableDrop = self:GetDisableDrop()
		self.DropHeight = self:GetDropHeight()
		self.AnimShardRate = math.max(1, self:GetAnimShardRate())
		self.LiquidBottom = self:GetLiquidBottom()
		self.LiquidHeight = self:GetLiquidHeight()
		self.TankIncreaseSoundVolume = self:GetTankIncreaseSoundVolume()
		self.TankIncreaseSoundLow = self:GetTankIncreaseSoundLow()
		self.TankIncreaseSoundHigh = self:GetTankIncreaseSoundHigh() - self.TankIncreaseSoundLow
	end

	function ENT:CheckSound()

		if not self.TankAmbient then
			self.TankAmbient = CreateSound(self, self:GetTankAmbientSound())
			self.TankAmbient:SetSoundLevel(50)
			self.TankAmbient:Play()
			self.TankAmbient:ChangePitch(45)
			self.TankAmbient:ChangeVolume(0)
		end

		if not self.TankFill then
			self.TankFill = CreateSound(self, self:GetTankIncreaseSound())
			self.TankFill:SetSoundLevel(60)
			self.TankFill:Play()
			//self.TankFill:ChangePitch(45)
			self.TankFill:ChangeVolume(0)
		end
	end

	function ENT:OnRemove()
		if self.TankAmbient then
			self.TankAmbient:Stop()
			self.TankAmbient = nil
		end

		if self.TankFill then
			self.TankFill:Stop()
			self.TankFill = nil
		end
	end

	function ENT:GetCollectedShardCount()
		return self.AnimShardCount
	end

	function ENT:GetLiquidLevel()
		return self:GetPos() + Vector(0, 0, self.LiquidBottom + self:GetCompletePercent() * self.LiquidHeight)
	end

	function ENT:GetCompletePercent()
		local c = self:GetCollectedShardCount()
		local t = mapgen.GetTotalRequiredShards()

		return c * 1.0 / t
	end

	function ENT:DoShardAnimation(delay, last)
		coroutine.wait(delay)
		if not self.DisableDrop then
			local shard = ManagedCSEnt("jazz_shardtank_" .. delay, "models/sunabouzu/jazzshard.mdl")
			shard:SetNoDraw(false)
			shard:SetPos(self:GetPos() + Vector(0, 0, self.DropHeight))
			shard:SetAngles(AngleRand())
			local t = 0
			local endt = 1.0
			while t < endt do
				t = t + FrameTime()
				local p = t / endt
				local pos = self.DropHeight * (1 - math.pow(p, 2))

				shard:SetPos(self:GetPos() + Vector(0, 0, pos))
				coroutine.yield()
			end

			shard:SetNoDraw(true)
		end

		self.AnimShardCount = math.Approach(self.AnimShardCount, self:GetCollectedShards(), 1)

		local waterLevel = self:GetLiquidLevel()

		local completePerc = self:GetCompletePercent()
		if self.TankAmbient then
			self.TankAmbient:ChangeVolume(math.min(0.8, completePerc * 4))
		end

		if self.TankFill then
			self.TankFill:ChangeVolume(self.TankIncreaseSoundVolume)
			self.TankFill:ChangePitch(self.TankIncreaseSoundLow + completePerc * self.TankIncreaseSoundHigh)

			if last then
				self.TankFill:ChangeVolume(0.0, 4)
			end
		end

		if self.DisableDrop then return end
		-- Sound effects
		self:EmitSound(table.Random(self.TankSplashSounds), 75, 100, 0.3)

		-- Splash effect
		local effectdata = EffectData()
		effectdata:SetOrigin( waterLevel )
		effectdata:SetMagnitude(4)
		effectdata:SetScale(0.25)
		effectdata:SetRadius(0.25)
		effectdata:SetEntity(self)
		util.Effect("ElectricSpark", effectdata)

	end

	function ENT:DoAllShardAnimation()
		local curShards = self.AnimShardCount
		local numShards = self:GetCollectedShards()
		local numIterations = 0

		self.AnimCoroutines = self.AnimCoroutines or {}
		while curShards != numShards do
			curShards = math.Approach(curShards, numShards, 1)
			numIterations = numIterations + 1

			local delay = numIterations / self.AnimShardRate
			local co = coroutine.create(self.DoShardAnimation)
			table.insert(self.AnimCoroutines, co)
			coroutine.resume(co, self, delay, curShards == numShards)
		end
	end

	function ENT:TickAnimCoroutines()
		if not self.AnimCoroutines then return end
		for i=#self.AnimCoroutines, 1, -1 do
			local co = self.AnimCoroutines[i]
			local succ, err
			succ = coroutine.status(co) != "dead"
			if succ then
				succ, err = coroutine.resume(co)
			end

			if not succ then
				if err then ErrorNoHalt(err) end
				table.remove(self.AnimCoroutines, i)
			end
		end
	end

	function ENT:ShouldActivate()
		local dist2 = (LocalPlayer():EyePos() - self:GetPos()):LengthSqr()

		return dist2 < math.pow(self.ApproachRadius, 2)
	end

	function ENT:Think()
		if not self.AnimationActivated then
			if not self:ShouldActivate() then
				return
			else
				self.AnimationActivated = true
			end
		end

		if not self.AnimCoroutines or #self.AnimCoroutines == 0 then
			if self.AnimShardCount != self:GetCollectedShards() then
				self:DoAllShardAnimation()
			end
		end
		self:TickAnimCoroutines()
		self:CheckSound()

		self.GoalCompletePercent = Lerp(FrameTime() * 1, self.GoalCompletePercent or 0, self:GetCompletePercent())
		self:SetCycle(self.GoalCompletePercent + math.sin(CurTime() * 2) * 0.007)

		//self.AnimShardCount = math.Approach(self.AnimShardCount, self:GetCollectedShards(), 1)
	end

	local MSqueeze = Matrix()
	function ENT:DrawRTScreen()
		screen_rt:Render(function()
			local c = HSVToColor(math.fmod(CurTime() * 40, 360), 0.8, 0.5)
			local collected = self:GetCollectedShardCount()
			render.Clear(c.r, c.g, c.b, 255)
			cam.Start2D()
				local ctext =  jazzloc.Localize(collected == 1 and "jazz.tank.shard" or "jazz.tank.shards", collected)
				local ntext = newgame.GetGlobal("ended") and jazzloc.Localize("jazz.tank.newgameplus") or jazzloc.Localize("jazz.tank.need", mapgen.GetTotalRequiredShards())
				surface.SetFont("JazzShardTankFont")
				ctext = string.Trim(ctext)
				local tw, th = surface.GetTextSize(ctext)
				MSqueeze:Identity()
				MSqueeze:Translate(Vector(sizeX/2, 0, 0))
				MSqueeze:Scale(Vector(math.min(1, sizeX/tw), 1, 1))
				MSqueeze:Translate(Vector(-sizeX/2, 0, 0))
				cam.PushModelMatrix(MSqueeze, true)
					draw.SimpleText(ctext, "JazzShardTankFont", sizeX / 2, sizeY / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				cam.PopModelMatrix()

				draw.SimpleText(ntext, "JazzShardTankSubtextFont", sizeX / 2, sizeY / 1.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End2D()
		end)
	end

	function ENT:Draw()
		if self.RTMat < 0 then
			self:DrawModel()
			return
		end
		self:DrawRTScreen()
		render.MaterialOverrideByIndex(self.RTMat, screen_rt:GetUnlitMaterial())
		self:DrawModel()
		render.MaterialOverrideByIndex(self.RTMat, nil)
	end
end