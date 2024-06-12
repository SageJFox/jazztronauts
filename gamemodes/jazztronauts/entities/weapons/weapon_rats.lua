if SERVER then
	AddCSLuaFile()
end

SWEP.Base					= "weapon_basehold"
SWEP.PrintName				= jazzloc.Localize("jazz.weapon.rats")
SWEP.Slot					= 4
SWEP.Category				= "#jazz.weapon.category"
SWEP.Purpose				= "#jazz.weapon.rats.desc.short"
SWEP.WepSelectIcon			= Material( "entities/weapon_rats.png" )
SWEP.AutoSwitchFrom			= false

SWEP.ViewModel				= "models/weapons/c_pistol.mdl"
SWEP.WorldModel				= "models/weapons/w_pistol.mdl"

SWEP.UseHands				= true

SWEP.HoldType				= "pistol"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 2
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "weapons/airboat/airboat_gun_lastshot1.wav" )
SWEP.Primary.Automatic		= false

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo			= "none"

SWEP.Spawnable				= true
SWEP.RequestInfo			= {}

SWEP.SizeMultiplier			= 1
SWEP.FoV					= 90
SWEP.AntStrength			= false
local hullMins				= Vector(-2,-2,0)
local hullMaxs				= Vector(2,2,9)
local view					= Vector(0,0,8)
local origView				= Vector(0,0,64)	
local origViewCrouch		= Vector(0,0,28)

-- List this weapon in the store
local storeRats = jstore.Register(SWEP, 1 --[[100000]], { type = "tool" })


-- Ant Strength Upgrade
local rats_antstrength = jstore.Register("rats_antstrength", 15000, {
	name = jazzloc.Localize("jazz.weapon.rats.upgrade.antstrength"),
	--cat = jazzloc.Localize("jazz.weapon.rats"),
	desc = jazzloc.Localize("jazz.weapon.rats.upgrade.antstrength.desc"),
	type = "upgrade",
	requires = storeRats
})

function SWEP:Initialize()

	self.BaseClass.Initialize( self )
	self:SetWeaponHoldType( self.HoldType )
	local owner = self:GetOwner()
	if IsValid(owner) then
		self.FoV = owner:GetFOV()
	end

	self.LastThink = CurTime()

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
	self.AntStrength = unlocks.IsUnlocked("store", owner, rats_antstrength)
end

function SWEP:SetupDataTables()
	self.BaseClass.SetupDataTables( self )
end

function SWEP:Deploy()

	if SERVER then
		local owner = self:GetOwner()
		self.OldRunSpeed = owner:GetRunSpeed()
		self.OldWalkSpeed = owner:GetWalkSpeed()
		self.OldJumpPower = owner:GetJumpPower()
	end

	self.JumpMultiplier	= 1
	self.CrouchTime	= -1

	self:SendWeaponAnim(ACT_VM_IDLE)

	return true

end

function SWEP:DrawWeaponSelection(x, y, w, h, alpha)
	surface.SetDrawColor(255, 255, 255, alpha)
	if self.WepSelectIcon then
		surface.SetMaterial(self.WepSelectIcon)
	else
		surface.SetTexture("weapons/swep")
	end

	surface.DrawTexturedRectUV(x + w / 2 - 128, y + h / 2 - 64, 256, 128, 0, 0.25, 1, 0.75)
	self:PrintWeaponInfo(x + w + 20, y + h, alpha)
end

/*function SWEP:Cleanup()
	
end

function SWEP:DrawWorldModel()

	self:DrawModel()

	local ent = self:GetOwner()

	if not IsValid( ent ) then return end

end*/

function SWEP:DrawHUD()

end

function SWEP:Think()

	local owner = self:GetOwner()

	if IsValid(owner) then 
		if self.SizeMultiplier ~= owner.JazzSizeMultiplier then
			if self.SizeMultiplier == 1 or not owner:Alive() then
				owner.JazzSizeMultiplier = 1
				owner:ResetHull()
				owner:SetViewOffset(origView)
				owner:SetViewOffsetDucked(origViewCrouch)
				owner:SetStepSize(18)
				owner:SetRunSpeed(owner:GetRunSpeed()*4)
				owner:SetWalkSpeed(owner:GetWalkSpeed()*4)
				owner:SetSlowWalkSpeed(owner:GetSlowWalkSpeed()*4)
				owner:SetFOV(0)
			else
				owner.JazzSizeMultiplier = self.SizeMultiplier
				owner:SetHull(hullMins,hullMaxs)
				owner:SetHullDuck(hullMins,hullMaxs)
				owner:SetViewOffset(view)
				owner:SetViewOffsetDucked(view)
				owner:SetStepSize(2.25)
				owner:SetRunSpeed(owner:GetRunSpeed()/4)
				owner:SetWalkSpeed(owner:GetWalkSpeed()/4)
				owner:SetSlowWalkSpeed(owner:GetSlowWalkSpeed()/4)
				owner:SetFOV(self.FoV / 1.25)
			end
			owner:SetModelScale(owner.JazzSizeMultiplier,0.000001)
		end
	end
	self.LastThink = CurTime()
end

function SWEP:CanPrimaryAttack()

	return true

end

function SWEP:PrimaryAttack()

	if self.SizeMultiplier == 1 then
		self.SizeMultiplier = 0.125
	else self.SizeMultiplier = 1 end

	self:ShootEffects()
	self.BaseClass.PrimaryAttack( self )

end

function SWEP:ShootEffects()

	local owner = self:GetOwner()
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	if IsValid(owner) then
		owner:MuzzleFlash()
		owner:SetAnimation( PLAYER_ATTACK1 )
	end
end

function SWEP:Reload() return false end
function SWEP:CanSecondaryAttack() return false end

if CLIENT then 

	hook.Add("PrePlayerDraw", "JazzRatsPoseParamAdjust", function(ply,flags)

		if not IsValid(ply) then return end

		if ply.JazzSizeMultiplier and ply.JazzSizeMultiplier < 1 then

			--print("size mult:",ply.JazzSizeMultiplier)
			--print("pre:",ply:GetPoseParameter("move_x"),ply:GetPoseParameter("move_y"))
			ply:SetPoseParameter( "move_x", math.max( -1, math.min( 1, math.Remap( ply:GetPoseParameter("move_x"), 0, 1, -1, 1) / ply.JazzSizeMultiplier ) ) )
			ply:SetPoseParameter( "move_y", math.max( -1, math.min( 1, math.Remap( ply:GetPoseParameter("move_y"), 0, 1, -1, 1) / ply.JazzSizeMultiplier ) ) )
			--print("post:",ply:GetPoseParameter("move_x"),ply:GetPoseParameter("move_y"))
			ply:InvalidateBoneCache()

		end

	end)

else

	hook.Add("PostPlayerDeath", "JazzRatsPostDeathCleanup", function(ply)

		if not IsValid(ply) then return end

		ply.JazzSizeMultiplier = 1
		ply:SetModelScale(1,0.000001)
		ply:ResetHull()
		ply:SetViewOffset(origView)
		ply:SetViewOffsetDucked(origViewCrouch)
		ply:SetStepSize(18)

	end)

	hook.Add("AllowPlayerPickup","JazzRatsAdjust",function(ply, ent) 
		local wep = ply:GetWeapon("weapon_rats")
		if not wep then return end
		--we are small, and don't have ant strength
		if IsValid(ply) and IsValid(ent) and ply.JazzSizeMultiplier < 1 and not wep.AntStrength then
			local phy = ent:GetPhysicsObject()
			return IsValid(phy) and phy:GetMass() <= 3.5 --default weight is 35
		end
	end)

end