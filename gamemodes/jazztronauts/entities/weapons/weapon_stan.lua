if SERVER then
	AddCSLuaFile()
end
local newring = CreateClientConVar("jazz_stan_newring","1",true,false,"How Stan will utilize new skull orbiting behavior. Options are:\n"..
"\t0 - Only use old behavior: Stan will form one continuous (and eventually clipping) ring.\n"..
"\t1 - Only use new behavior: Stan will form multiple rings (of a maximum of 7 skulls) as needed.\n"..
"\t2 - Stan will use old behavior normally, new behavior when Teleporter Lock-On unlock is purchased.",0,2)

SWEP.Base					= "weapon_basehold"
SWEP.PrintName				= jazzloc.Localize("jazz.weapon.stan")
SWEP.Slot					= 3
SWEP.Category				= "#jazz.weapon.category"
SWEP.Purpose				= jazzloc.Localize("jazz.weapon.stan.desc.short")
SWEP.AutoSwitchFrom			= false

SWEP.WepSelectIcon = "s"
SWEP.WepSelectColor = Color(196,0,0)
SWEP.AutoIconAngle = Angle(45, 90, 0)

SWEP.ViewModel				= "models/weapons/c_stan.mdl"
SWEP.WorldModel				= "models/Gibs/HGIBS.mdl"

SWEP.UseHands				= true

SWEP.HoldType				= "magic"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 0.1
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "weapons/357/357_fire2.wav" )
SWEP.Primary.Automatic		= false

SWEP.Secondary.Delay		= 0.5
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo			= "none"
SWEP.Secondary.Automatic	= false


local DefaultTeleportDistance	= 256
local DefaultProngCount			= 2
local DefaultSpeed				= 300
local teleMarker				= Material("materials/ui/jazztronauts/pentergram.png", "smooth")
local teleMarkerRotSpeed		= -90
local teleMarkerRotSpeedSel		= 360

SWEP.Spawnable				= true
SWEP.RequestInfo			= {}
SWEP.TeleportDistance		= DefaultTeleportDistance
SWEP.ProngCount				= DefaultProngCount
SWEP.SpeedRate				= DefaultSpeed
SWEP.TopSpeed				= 2000
SWEP.TeleportLockOnLevel	= 0
SWEP.TeleportDestTarget		= nil


-- List this weapon in the store
local storeStan = jstore.Register(SWEP, 4000, {
	desc = jazzloc.Localize("jazz.weapon.stan.desc"), -- don't use the short one
	type = "tool"
})

-- Create 3 items to be purchased one after the other that control range
local storeRange = jstore.RegisterSeries("stan_range", 2000, 10, {
	name = jazzloc.Localize("jazz.weapon.stan.upgrade.range"),
	requires = storeStan,
	desc = jazzloc.Localize("jazz.weapon.stan.upgrade.range.desc"),
	type = "upgrade",
	priceMultiplier = 2,
})
local storeSpeed = jstore.RegisterSeries("stan_speed", 1000, 10, {
	name = jazzloc.Localize("jazz.weapon.stan.upgrade.speed"),
	requires = storeStan,
	desc = jazzloc.Localize("jazz.weapon.stan.upgrade.speed.desc"),
	type = "upgrade",
	priceMultiplier = 2,
})
local storeTeleport = jstore.RegisterSeries("stan_teleport", 25000, 2, {
	name = jazzloc.Localize("jazz.weapon.stan.upgrade.teleport"),
	--cat = jazzloc.Localize("jazz.weapon.stan"),
	requires = storeStan,
	desc = function(num)
		local num = num or 1
		return jazzloc.Localize( "jazz.weapon.stan.upgrade.teleport.desc" .. tostring(num) )
	end,
	type = "upgrade",
	priceMultiplier = 10,
})

if CLIENT then

	surface.CreateFont( "JazzStanMarkersSymbols", {
		font = "Agathodaimon",
		size = 25,
		weight = 500,
		antialias = true,
	} )

	surface.CreateFont( "JazzStanMarkers", {
		font	  = "KG Red Hands",
		size	  = 25,
		weight	= 500,
		antialias = true
	})

	local screenSize = ScreenScale(16)

	function stanmarkerspin(self, scrpos, visible)
		self.transcribed = self.transcribed or {}
		local text = jazzloc.Localize(self.label) or ""
		local fadein = isnumber(self.starttime) and math.min(1,(CurTime() - self.starttime) / 2) or 1 --we're always visible, so fade in over 2 seconds instead
		if fadein < 0.01 then table.Empty(self.transcribed) end

		--rotate our main marker
		surface.SetDrawColor( 255, 255, 255, Lerp(math.sqrt(fadein),0,255) )
		surface.SetMaterial(self.icon)
		local size = screenSize
		if self.big then size = size * 2 end
		surface.DrawTexturedRectRotated(scrpos.x, scrpos.y, size, size, (CurTime() + util.SharedRandom(text,0,180) ) % (360 / math.abs(self.rotspeed)) * self.rotspeed)
		surface.SetTextColor( 159, 22, 0, Lerp(math.sqrt(fadein),0,255) )
		surface.SetFont("JazzStanMarkers")

		--write our name, if we have one
		--start with runes that randomly convert to regular characters as we fade in
		local w, _ = surface.GetTextSize(text)
		surface.SetTextPos(scrpos.x - w/2, scrpos.y + size/2)
		local scribed, numbah = 0, false
		for char = 1, #text do
			if self.transcribed[char] then scribed = scribed + 1 end
			surface.SetFont((self.transcribed[char] or tonumber(text[char]) ) and "JazzStanMarkers" or "JazzStanMarkersSymbols")
			--unfortunately, our rune font is only letters (and some character modifiers). This tries to at least somewhat handle the other stuff better
			local drawtext = string.sub( text, char, char )
			if not self.transcribed[char] then
				--get fancy with roman numerals for numbers (we excluded them from the rune font already)
				if tonumber(drawtext) then
					if not numbah and tonumber(drawtext) ~= 0 then
						drawtext = jazzloc.RomanNumerals(table.concat(string.Explode("%D",text,true))) --this smashes all the numbers in it together into one, but, who cares
						numbah = true
					else
						drawtext = ""
					end
				-- turn underscores into spaces
				elseif drawtext == "_" then
					drawtext = " "
				-- convert our character to A-Z, in a way that is consistent per character
				elseif string.find(drawtext,"%A") then
					drawtext = utf8.char((utf8.codepoint(drawtext)[1] % 26) + 65)
				end
			end
			surface.DrawText( drawtext )
			if fadein >= 1 then self.transcribed[char] = true end --make sure they're all converted if we're fully faded in
		end
		--randomly transcribe characters as we fade in
		local runs = -3
		if fadein < 1 then
			while scribed / (#text * 2) + 0.5 < fadein and runs < #self.transcribed do
				local k = math.random(#text)
				if self.transcribed[k] then
					--we don't wanna risk spending a *long* time on this as we get more transcribed, we can always try again next frame
					runs = runs + 1
				else
					self.transcribed[k] = true
					scribed = scribed + 1
				end
			end
		end
	end

else
	util.AddNetworkString("JazzStanTeleportDestTarget")
end

net.Receive("JazzStanTeleportDestTarget",function(len,ply)
	local self = net.ReadEntity()
	local teleportdesttarget = net.ReadEntity()
	if not IsValid(self) then return end
	local owner = self:GetOwner()
	if IsValid(owner) and self.TeleportLockOnLevel > 0 then
		--clear the effects for the old one
		if CLIENT then
			if IsValid(self.TeleportDestTarget) and worldmarker.markers[self.TeleportDestTarget] then
				worldmarker.markers[self.TeleportDestTarget].rotspeed = teleMarkerRotSpeed
				worldmarker.markers[self.TeleportDestTarget].big = false
			end
		end
		if (SERVER and owner == ply) or CLIENT then
			if self.TeleportDestTarget == teleportdesttarget then self.TeleportDestTarget = nil return end --deselect
			self.TeleportDestTarget = teleportdesttarget
		end
	end
end)


local markerAdjust = Vector(0,0,36)

function SWEP:Initialize()

	self.BaseClass.Initialize( self )
	self:SetWeaponHoldType( self.HoldType )

	self.speed = 0
	self.offset = 0
	self.open = 0
	self.glow = 0
	self.lasttime = CurTime()
	self.hitpos = Vector(0,0,0)

	self.Hum = CreateSound(self, "ambient/machines/machine6.wav")
	self.BeamLoop1 = CreateSound(self, "ambient/machines/machine_whine1.wav")

	hook.Add( "OnUnlocked", self, function( self, list_name, key, ply )
		local baseKey = jstore.GetSeriesBase(key)
		if ply == self:GetOwner() and (storeRange == baseKey or storeSpeed == baseKey or string.find(key, "stan_teleport")) then
			self:SetUpgrades()
		end
	end )

	if CLIENT then
		self:SetUpgrades()
	end
end

function SWEP:OwnerChanged()
	self:SetUpgrades()
end

-- Query and apply current upgrade settings to this weapon
function SWEP:SetUpgrades()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local rangeLevel = jstore.GetSeries(owner, storeRange)
	self.TeleportDistance = DefaultTeleportDistance * math.max(1,rangeLevel) + math.pow(rangeLevel, 2) * 300

	local speedLevel = jstore.GetSeries(owner, storeSpeed)
	self.SpeedRate = DefaultSpeed + speedLevel * 300

	self.TeleportLockOnLevel = jstore.GetSeries(owner, storeTeleport)

	-- # of skulls == # of upgrades
	self.ProngCount = DefaultProngCount + rangeLevel + speedLevel + self.TeleportLockOnLevel
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool",0,"TeleSuccess")
	self.BaseClass.SetupDataTables( self )
end

function SWEP:Deploy()


	local vm = self:GetOwner():GetViewModel()
	local depseq = IsValid(vm) and vm:LookupSequence( "anim_deploy" ) or nil
	if depseq then
		vm:SendViewModelMatchingSequence( depseq )
		--vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
		vm:SetPlaybackRate( 1.5 )
	end

	--make/update markers for all info_teleport_destinations
	if CLIENT and self.TeleportLockOnLevel > 0 then
		local teledests = ents.FindByClass( "jazz_stanteleportmarker" )
		for _, v in ipairs(teledests) do
			if v:GetLevel() > self.TeleportLockOnLevel or v:GetBusMarker() then continue end
			local istarget = v == self.TeleportDestTarget
			worldmarker.Register(v, teleMarker, 20, true)
			worldmarker.markers[v].label = v:GetDestinationName()
			worldmarker.markers[v].starttime = istarget and 0 or CurTime()
			worldmarker.markers[v].rotspeed = istarget and teleMarkerRotSpeedSel or teleMarkerRotSpeed
			worldmarker.markers[v].big = istarget
			worldmarker.SetRenderFunction(v, stanmarkerspin)
			worldmarker.SetEnabled(v,true)
			local pos = Vector(v:GetPos())
			pos:Add(markerAdjust)
			worldmarker.Update(v, pos)
		end
	end

	return true

end

function SWEP:StartPrimaryAttack()


	if CLIENT then

		--self:GetOwner():EmitSound( self.Primary.Sound, 50, 140 )
		--self.Hum:Play()

	end

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	--self:GetOwner():MuzzleFlash()
	--self:GetOwner():SetAnimation( PLAYER_ATTACK1 )


	//print("Starting to attack")

end

function SWEP:SecondaryAttack()
	if CLIENT then
		if self.TeleportLockOnLevel < 1 then return end
		local owner = self:GetOwner()
		if not owner then return end
		for _, v in ipairs(ents.FindByClass("jazz_stanteleportmarker")) do
			if v:GetLevel() > self.TeleportLockOnLevel or v:GetBusMarker() then continue end
			local screenloc = v:GetPos()
			screenloc:Add(markerAdjust)
			local telemark = screenloc:ToScreen()
			if math.abs(ScrW() / 2 - telemark.x) <= 24 and math.abs(ScrH() / 2 - telemark.y) <= 24 then
				if self.TeleportDestTarget == v then break end
				if IsValid(self.TeleportDestTarget) then
					worldmarker.markers[self.TeleportDestTarget].rotspeed = teleMarkerRotSpeed
					worldmarker.markers[self.TeleportDestTarget].big = false
				end
				worldmarker.markers[v].starttime = 0
				worldmarker.markers[v].rotspeed = teleMarkerRotSpeedSel
				worldmarker.markers[v].big = true
				self.TeleportDestTarget = v
				net.Start("JazzStanTeleportDestTarget")
					net.WriteEntity(self)
					net.WriteEntity(v)
				net.SendToServer()
				owner:EmitSound( Sound( "buttons/button6.wav" ), 100, 70 )
				return
			end
		end
		--nothing picked, just remove
		local teledest = self.TeleportDestTarget
		if IsValid(teledest) and worldmarker.markers[teledest] then
			worldmarker.markers[teledest].rotspeed = teleMarkerRotSpeed
			worldmarker.markers[teledest].big = false
			self.TeleportDestTarget = nil
			net.Start("JazzStanTeleportDestTarget")
				net.WriteEntity(self)
				net.WriteEntity(nil)
			net.SendToServer()
			owner:EmitSound( Sound( "buttons/button8.wav" ), 100, 70 )
		end
	end
end

function SWEP:StopPrimaryAttack()

	//print("Stopping attack")

	local vm = self:GetOwner():GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "anim_deploy" ) )
	--vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
	vm:SetPlaybackRate( 1 )

end

function SWEP:Cleanup()

	if CLIENT then
		self.Hum:Stop()
		self.BeamLoop1:Stop()

		local teledests = ents.FindByClass( "jazz_stanteleportmarker" )
		for _, v in ipairs(teledests) do
			if v:GetBusMarker() then continue end
			if worldmarker.markers[v] then
				--if v ~= self.TeleportDestTarget or not IsValid(self:GetOwner()) or not self:GetOwner():Alive() then
					worldmarker.SetEnabled(v,false)
					worldmarker.markers[v].starttime = nil
				--end
			end
		end
	end

end

function SWEP:DrawWorldModel()

	self:DrawModel()

end


local shiver = {}
local MatFlare = Material("effects/blueflare1")
local MaxPerRing = 7
local checkRings = function(self) return math.Round(newring:GetFloat()) == 0 or (math.Round(newring:GetFloat()) == 2 and self.TeleportLockOnLevel < 1) end

function SWEP:PostDrawViewModel(viewmodel, weapon, ply)

	local hands = ply:GetHands()
	if not IsValid(hands) then return end
	local atBone = hands:LookupBone( "ValveBiped.Bip01_R_Hand" )

	if not atBone then return end

	local pos, ang = hands:GetBonePosition( atBone )
	local mtx = Matrix()

	pos = pos + ang:Forward()

	mtx:SetAngles( ang )
	mtx:SetTranslation( pos )

	self.offset = self.offset + self.speed * RealFrameTime()
	self.offset = math.NormalizeAngle(self.offset)

	local r = self.offset + UnPredictedCurTime() * 15
	local lastfullrow = math.floor(self.ProngCount / MaxPerRing) * MaxPerRing
	for i=1, self.ProngCount do
		if checkRings(self) then
			self:AddProng( i, mtx, r + i * (360/self.ProngCount) )
		else
			local sides = 360 / MaxPerRing
			if i > lastfullrow then sides = 360 / (self.ProngCount - lastfullrow) end
			self:AddProng( i, mtx, r + i * sides )
		end
	end

	render.SetMaterial( MatFlare )
	local s = math.cos( CurTime() * 5 ) * 5 + 20
	local s2 = math.cos( CurTime() * 8 ) * 5 + 10
	local s3 = math.cos( CurTime() * 3 ) * 8 + 5
	render.DrawSprite( pos, s, s, Color(255,0,0) )
	render.DrawSprite( pos, s2, s2, Color(255,0,0) )
	render.DrawSprite( pos, s3, s3, Color(255,0,0) )

end

function SWEP:PreDrawViewModel(viewmodel, weapon, ply)



end


function SWEP:Reload() return false end

--Uncomment to cycle through number of prongs with Reload (comment out regular function above)

--[[local ReloadTime = 0

function SWEP:Reload()
	if CurTime() - ReloadTime < .25 then return end
	if self.ProngCount < 28 then
		self.ProngCount = self.ProngCount + 1
	else
		self.ProngCount = 2
	end
	self:UpdateProngs()
	ReloadTime = CurTime()
end

function SWEP:UpdateProngs()
	if SERVER then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local hands = ply:GetHands()
	if not IsValid(hands) then return end
	local atBone = hands:LookupBone( "ValveBiped.Bip01_R_Hand" )

	if not atBone then return end

	local pos, ang = hands:GetBonePosition( atBone )
	local mtx = Matrix()

	pos = pos + ang:Forward()

	mtx:SetAngles( ang )
	mtx:SetTranslation( pos )

	self.offset = self.offset + self.speed * RealFrameTime()
	self.offset = math.NormalizeAngle(self.offset)

	local r = self.offset + UnPredictedCurTime() * 15
	local lastfullrow = math.floor(self.ProngCount / MaxPerRing) * MaxPerRing
	for i=1, self.ProngCount do

		local oldskull = _ENTITY_POOL["gun_prong_" .. i .. "models/Gibs/HGIBS.mdl"]
		if IsValid(oldskull) then oldskull:Remove() end
		_ENTITY_POOL["gun_prong_" .. i .. "models/Gibs/HGIBS.mdl"] = nil

		--self:AddProng( i, mtx, r + i * (360/self.ProngCount) )
		local sides = 360 / MaxPerRing
		if i > lastfullrow then sides = 360 / (self.ProngCount - lastfullrow) end
		self:AddProng( i, mtx, r + i * sides )

	end
end--]]


function SWEP:AddProng( id, mtx, rot )

	shiver[id] = shiver[id] or {}
	shiver[id].amt = shiver[id].amt or 0
	shiver[id].again = shiver[id].again or (CurTime() + (.5 + math.random() * 3))

	if shiver[id].again < CurTime() then
		shiver[id].again = CurTime() + (.5 + math.random() * 3)
		shiver[id].amt = 1
	end

	shiver[id].amt = math.max( shiver[id].amt - FrameTime() * 2, 0 )

	local ent = ManagedCSEnt( "gun_prong_" .. id, "models/Gibs/HGIBS.mdl" )
	ent:SetNoDraw( true )
	ent:SetLOD(0)

	local a = (EyePos() - mtx:GetTranslation()):GetNormal():Angle()

	local out = math.pow( math.sin( self.open * math.pi / 2 ), 2 )
	local lmtx = Matrix()
	lmtx:SetScale( Vector( 0.2, 0.2, 0.2 ) )
	local spiral = checkRings(self) and 1 or math.ceil(id / MaxPerRing)
	lmtx:Rotate( Angle( 0, 0, rot + spiral * 20 ) )
	lmtx:Translate( Vector( -10 * spiral, out * 30 + 20, 0 ) + VectorRand() * shiver[id].amt )

	lmtx:Rotate( Angle(90 * self.glow, math.sin( CurTime() + id * 2 ) * 10 + 180, 180 -90 * (1-self.open) ) )

	lmtx:Scale( Vector(2,2,2) )

	local transformed = mtx * lmtx
	local tpos = transformed:GetTranslation()
	ent:EnableMatrix( "RenderMultiply", transformed )
	ent:DrawModel()

	local col = Color(255,20,0)
	local size = self.glow > .75 and 20 or 10
	col.r = col.r * self.glow
	col.g = col.g * self.glow
	col.b = col.b * self.glow

	render.SetMaterial( MatFlare )
	render.DrawSprite( tpos, size, size, col )

	if self.glow > .1 then
		gfx.renderBeam( tpos, self.hitpos, col, col, math.random(10,20) )
	end

end

function SWEP:ViewModelDrawn( viewmodel )

end

function SWEP:TestPlayerLocation( pos )

	local mins, maxs = self:GetOwner():GetCollisionBounds()
	local tr = util.TraceHull( {
		start = pos,
		endpos = pos,
		mins = mins,
		maxs = maxs,
	} )

	if tr.StartSolid then return false end
	return true

end

function SWEP:TraceFragments( start, endpos )

	local owner = self:GetOwner()
	local fragments = {}
	local dir = (endpos - start)
	local normal = dir:GetNormal()
	local length = dir:Length()

	local primary = util.TraceLine( {
		start = start,
		endpos = endpos,
		mask = MASK_PLAYERSOLID_BRUSHONLY,
		--collisiongroup = COLLISION_GROUP_WEAPON
		filter = owner,
	} )

	local remaining = length * (1 - primary.Fraction)
	debugoverlay.Sphere(primary.HitPos, 10, 0)
	if primary.Hit and remaining > 0 then

		normal = -primary.HitNormal

		table.insert(fragments, { start = start, endpos = primary.HitPos, tr = primary } )
		local secondary = util.TraceLine( {
			start = primary.HitPos + normal * 2,
			mask = MASK_PLAYERSOLID_BRUSHONLY,
			endpos = primary.HitPos + normal * remaining,
		} )

		if secondary.StartSolid then

			local secondary_end = primary.HitPos + normal * remaining * secondary.FractionLeftSolid
			debugoverlay.Sphere(secondary_end, 15, 0, Color(0, 0, 255), true)

			table.insert(fragments, { start = primary.HitPos, endpos = secondary_end, tr = secondary } )
			remaining = remaining * (1 - secondary.FractionLeftSolid)

			if remaining == 0 then return fragments end
			local mins, maxs = owner:GetCollisionBounds()
			local tertiary = util.TraceHull( {
				start = secondary_end + normal * 2,
				endpos = secondary_end + normal * remaining,
				mask = MASK_PLAYERSOLID,
				--collisiongroup = COLLISION_GROUP_WEAPON
				filter = owner,
				mins = mins,
				maxs = maxs,
			} )
			debugoverlay.SweptBox(tertiary.StartPos, tertiary.HitPos, mins, maxs, Angle(0,0,0), 0.1)
			debugoverlay.Sphere(tertiary.HitPos, 15, 0.1, Color(255, 0, 0), true)
			if bit.band( util.PointContents( tertiary.HitPos ), CONTENTS_SOLID ) == 0 then


				local backtrace = util.TraceHull( {
					start = tertiary.HitPos,
					endpos = secondary_end + normal * 2,
					mask = MASK_PLAYERSOLID,
					mins = mins,
					maxs = maxs,
				} )

				debugoverlay.SweptBox(tertiary.HitPos, backtrace.HitPos, mins, maxs, Angle(0,0,0), 0.1, Color(255, 255, 0))
				debugoverlay.Sphere(backtrace.HitPos, 15, 0.11, Color(0, 255, 255), true)
				debugoverlay.Sphere(backtrace.StartPos, 15, 0.11, Color(255, 55, 155), true)

				if self:TestPlayerLocation( backtrace.HitPos ) then

					table.insert(fragments, { start = secondary_end, endpos = backtrace.HitPos, tr = tertiary } )

				end

			end

		end

	end

	return fragments

end

local lasermat = Material("effects/laser1.vmt")
function SWEP:DrawHUD()

	local owner = self:GetOwner()
	if IsValid(owner) and owner:InVehicle() and not owner:GetAllowWeaponsInVehicle() then return end

	cam.Start3D()
	cam.IgnoreZ(true)

	local b,e = pcall(function()
		if IsValid(self.TeleportDestTarget) then return end

		local viewmodel = owner:GetViewModel(0)
		local hands = LocalPlayer():GetHands()
		local atpos = nil
		if IsValid(hands) then
			local atBone = hands:LookupBone( "ValveBiped.Bip01_R_Hand" )
			atpos, _ = hands:GetBonePosition( atBone or 1 )
		end
		local distance = self.TeleportDistance
		local viewdir = owner:GetAimVector()
		local startpos = owner:GetShootPos()
		local endpos = startpos + viewdir * distance

		local origin = atpos or (owner:GetPos() + (owner:Crouching() and owner:GetViewOffsetDucked() or owner:GetViewOffset()))

		local fragments = self:TraceFragments( startpos, endpos )
		if #fragments ~= 3 then return end

		local function projected( origin, pos, normal )
			local projection = normal or (endpos - origin):GetNormal()
			return origin + math.max( (pos - origin):Dot(projection), 0 ) * projection
		end

		local colors = {
			Color(255,0,0),
			Color(255,100,0),
			Color(100,100,0)
		}

		local root2 = math.sqrt(2)
		local views = {}

		local frag = fragments[1]
		local fragnormal = frag.tr.HitNormal
		local ifragnormal = -fragnormal
		local angle = fragnormal:Angle()

		local step = (360/5)
		for i=1, 5 do
			local r = 50
			local a = (step * i - 18) * DEG_2_RAD
			table.insert( views, frag.endpos - angle:Right() * math.cos(a) * r + angle:Up() * math.sin(a) * r )
		end

		local indices = {
			{1,3},
			{3,5},
			{5,2},
			{2,4},
			{4,1},
		}

		for i=1, #fragments do

			local frag = fragments[i]

			for _, view in pairs(views) do
				gfx.renderBeam( projected( view, frag.start, ifragnormal ), projected( view, frag.endpos, ifragnormal ), colors[i], Color(0,0,0), 20 )
			end

			if i == 2 then
				for _, id in pairs(indices) do
					gfx.renderBeam( projected( views[id[1]], frag.start, ifragnormal ), projected( views[id[2]], frag.start, ifragnormal ), colors[i], colors[i], 20 )
				end
			end

			local altcolor = Color(colors[i].r, colors[i].g, colors[i].b, colors[i].a)
			local frac = ((i-1) / 2)
			local v = Lerp(frac,1,.3)
			altcolor.r = altcolor.r * v
			altcolor.g = altcolor.g * v
			altcolor.b = altcolor.b * v

			if i == 3 then altcolor.g = altcolor.g + 20 end

			render.SetMaterial( lasermat )
			render.StartBeam( 370 / 10 )

			for j=0, 370, 10 do

				local r = 50
				local a0 = (j - 90) * DEG_2_RAD
				local pos = frag.endpos - angle:Right() * math.cos(a0) * r + angle:Up() * math.sin(a0) * r
				render.AddBeam(
					projected( pos, frag.endpos, ifragnormal ),
					20 + self.glow * 100,
					i,
					altcolor
				)

			end

			render.EndBeam()

		end

	end)

	cam.End3D()

	if not b then print(e) end

	local sub = math.max(self.glow - .5, 0) * 2

	surface.SetDrawColor(255,0,0,255 * math.pow(sub, 3))
	surface.DrawRect( 0, 0, ScrW(), ScrH() )

end

function SWEP:CalcViewModelView( viewmodel, oldpos, oldang, pos, ang )

	pos = pos + VectorRand() * self.glow * .2
	ang.p = ang.p + math.random() * self.glow * 2
	ang.y = ang.y + math.random() * self.glow * 2
	ang.r = ang.r + math.random() * self.glow * 2

	--pos = pos + ang:Forward() * 18

	return pos, ang

end

function SWEP:CalcView( ply, pos, ang, fov )
	local view = {}

	local diff = 180 - fov
	fov = math.max(fov - math.pow(self.glow,4) * diff, 0)

	return pos, ang, fov
end

function SWEP:TeleportFX(owner)
	owner:EmitSound( Sound( "beams/beamstart5.wav" ), 100, 70 )
	owner:EmitSound( Sound( "beamstart7.wav" ), 70, 40 )
	self:SetTeleSuccess(true)
end

function SWEP:TeleportFailedFX(owner)
	owner:EmitSound( Sound( "buttons/button8.wav" ), 100, 70 )
	owner:EmitSound( Sound( "buttons/combine_button_locked.wav" ), 70, 40 )
	self:SetTeleSuccess(false)
	--todo: probably slap a message on the screen that we failed because the location wasn't clear
	print("Teleport failed!")
end

--Check singleplayer

function SWEP:Teleport()

	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	local distance = self.TeleportDistance
	local viewdir = owner:GetAimVector()
	local startpos = owner:GetShootPos()
	local endpos = startpos + viewdir * distance
	local fragments = self:TraceFragments( startpos, endpos )

	if #fragments ~= 3 and not IsValid(self.TeleportDestTarget) then
		if SERVER then owner:EmitSound( Sound( "buttons/button10.wav" ), 100, 100 ) end
		return
	end

	if SERVER then
		if IsValid(self.TeleportDestTarget) then
			self:SetTeleSuccess(nil)
			local target = self.TeleportDestTarget:GetDestination()
			if IsValid(target) then
				--make sure that there's room at the destination
				if self:TestPlayerLocation(target:GetPos()) or
					target:GetClass() == "info_teleport_destination" or --sometimes the location check fails, but if it's one of these it should be valid anyway
					self.TeleportDestTarget:GetLevel() > 1 then --these are spawns and sky_camera, both of which should just be clear
						owner:SetPos( target:GetPos() )
						self:TeleportFX(owner)
				end
				if self.TeleportDestTarget:GetDucked() then --let the entity handle this for us
					target:Fire("TeleportEntity","!activator",0,owner,self)
					self:TeleportFX(owner)
				end
				--clear out tele destination (either we teleported or it failed)
				self.TeleportDestTarget = nil
				net.Start("JazzStanTeleportDestTarget")
					net.WriteEntity(self)
					net.WriteEntity(nil)
				net.Send(owner)
				if self:GetTeleSuccess() then return end
			end
		elseif #fragments == 3 then
			owner:SetPos( fragments[3].endpos )
			self:TeleportFX(owner)
			return
		end
		self:TeleportFailedFX(owner) --no teleport happened, we got got
	end

	if CLIENT and self:IsCarriedByLocalPlayer() then
		LocalPlayer():ScreenFade(SCREENFADE.IN, Color(255, 0, 0, 128), 1, 0)
	end

end

function SWEP:DoLight()
	if SERVER then return end

	local dlight = DynamicLight(self:EntIndex())
	if dlight then
		dlight.pos = self:GetPos()

		dlight.r = (self.speed / self.TopSpeed) * 255
		dlight.g = 0
		dlight.b = 0
		dlight.brightness = 4
		dlight.Size = 128
		dlight.DieTime = CurTime() + 1
	end
end

function SWEP:Think()
	self.speed = self.speed or 0
	self.offset = self.offset or 0
	self.open = self.open or 0
	self.glow = self.glow or 0
	self.lasttime = self.lasttime or CurTime()
	self.hitpos = self.hitpos or Vector(0,0,0)

	local dt = ( CurTime() - self.lasttime )
	local speedrate = self.SpeedRate --3850 --750
	local openrate = 4
	local topspeed = self.TopSpeed

	if not self:IsPrimaryAttacking() then
		speedrate = 750
	end

	if dt <= 0 then return end

	if self.speed > 0 then
		self:DoLight()
	end

	if self:IsPrimaryAttacking() then
		if CLIENT and self.open == 0 then

			self:EmitSound( Sound( "npc/roller/blade_out.wav" ), 80, 130 )

		end

		if self.open < 1 then

			self.open = math.min( self.open + dt * openrate, 1 )

			if CLIENT and self.open == 1 then
				self.Hum:Play()
				self.BeamLoop1:Play()
			end

		elseif self.speed < topspeed then

			self.speed = math.min( self.speed + dt * speedrate, topspeed )

			if self.speed == topspeed then
				--if CLIENT then self.BeamLoop1:Play() end
				self:Teleport()
				self:StopPrimaryAttacking()
			end

		end

		if not self:CanTeleport() then
			self:StopPrimaryAttacking()
		end
	else

		if self.speed > 0 then

			if self.speed == topspeed then
				--if CLIENT then self.BeamLoop1:Stop() end
				--if SERVER then self:GetOwner():EmitSound( Sound( "ambient/explosions/explode_7.wav" ), 100, 180 ) end
			end

			self.speed = math.max( self.speed - dt * speedrate, 0 )

		else

			if CLIENT and self.open == 1 then
				self.Hum:Stop()
				self.BeamLoop1:Stop()
				self:EmitSound( Sound( "npc/roller/blade_in.wav" ), 100, 120 )
			end

			self.open = math.max( self.open - dt * openrate, 0 )

		end

	end

	if CLIENT and self.open == 1 then

		self.Hum:ChangePitch(50 + self.speed / 10)
		self.BeamLoop1:ChangePitch(50 + self.speed / 10)

		--util.ScreenShake(LocalPlayer():GetPos(), math.pow(self.glow, 4), 8, 0.02, 100)

	end

	self.glow = self.speed / topspeed

	if SERVER then
		--print( self.speed )
	end

	self.lasttime = CurTime()

	local owner = self:GetOwner()
	local pos = owner:GetShootPos()
	local dir = owner:GetAimVector()
	local tr = util.TraceLine( {
		start = pos,
		endpos = pos + dir * 100000,
		mask = MASK_SOLID,
		collisiongroup = COLLISION_GROUP_WEAPON
	} )

	self.hitpos = tr.HitPos

end

function SWEP:CanTeleport()
	if CLIENT and not self:IsCarriedByLocalPlayer() then return true end

	if self.TeleportDestTarget then return true end

	local owner = self:GetOwner()
	local distance = self.TeleportDistance
	local viewdir = owner:GetAimVector()
	local startpos = owner:GetShootPos()
	local endpos = startpos + viewdir * distance
	local fragments = self:TraceFragments( startpos, endpos )
	return #fragments == 3

end

function SWEP:CanPrimaryAttack()

	return self.open == 0 and self:CanTeleport()

end

function SWEP:PrimaryAttack()

	self.BaseClass.PrimaryAttack( self )

end

function SWEP:ShootEffects()

	local owner = self:GetOwner()
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )

end

function SWEP:CanSecondaryAttack() return self.TeleportLockOnLevel end
