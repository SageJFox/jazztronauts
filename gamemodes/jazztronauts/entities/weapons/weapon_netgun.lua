if SERVER then
	AddCSLuaFile()
end

SWEP.Base					= "weapon_basehold"
SWEP.PrintName				= jazzloc.Localize("jazz.weapon.net")
SWEP.Slot					= 4
SWEP.Category				= "#jazz.weapon.category"
SWEP.Purpose				= "#jazz.weapon.net.desc.short"
SWEP.WepSelectIcon			= Material( "entities/weapon_netgun.png" )
SWEP.AutoSwitchFrom			= false

SWEP.ViewModel				= "models/weapons/c_shotgun.mdl"
SWEP.WorldModel				= "models/weapons/w_netgun.mdl"

SWEP.UseHands				= true

SWEP.HoldType				= "shotgun"

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

SWEP.Primary.Delay			= 2
SWEP.Primary.ClipSize		= 3
SWEP.Primary.DefaultClip	= 3
SWEP.Primary.Ammo			= "none"
SWEP.Primary.Sound			= Sound( "garrysmod/balloon_pop_cute.wav" )
SWEP.Primary.Automatic		= false

SWEP.cost = 1

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Ammo			= "none"

SWEP.Spawnable				= true
SWEP.RequestInfo			= {}

-- List this weapon in the store
--local storeNet = jstore.Register(SWEP, 1 --[[100000]], { type = "tool" })


function SWEP:Initialize()

	self.BaseClass.Initialize( self )
	self:SetWeaponHoldType( self.HoldType )
	local owner = self:GetOwner()

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
end

function SWEP:SetupDataTables()
	self.BaseClass.SetupDataTables( self )
end

function SWEP:Deploy()

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

/*
function SWEP:Think()

	self.LastThink = CurTime()
end
--*/

function SWEP:CanPrimaryAttack()

	return true

end

function SWEP:PrimaryAttack()

	local owner = self:GetOwner()
	if not IsValid(owner) or jazzmoney.GetNotes(owner) < self.cost then return end

	if SERVER then jazzmoney.ChangeNotes( owner, -self.cost ) end
	self:ShootEffects()
	self.BaseClass.PrimaryAttack( self )
	self:SetNextPrimaryFire( CurTime() + 2.5 )
	self:ThrowNet()
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

function SWEP:ThrowNet()
	local owner = self:GetOwner()

	if ( not owner:IsValid() ) then return end

	self:EmitSound( self.Primary.Sound )
 
	if CLIENT then return end

	local ent = ents.Create( "jazz_projectile_net" )

	if not ent:IsValid() then return end

	local aimvec = owner:GetAimVector()
	local pos = aimvec * 16
	pos:Add( owner:EyePos() )

	ent:SetPos( pos )
	ent:SetOwner(owner)
	ent:SetAngles( owner:EyeAngles() )
	ent:Spawn()
 
	local phys = ent:GetPhysicsObject()
	if not phys:IsValid() then ent:Remove() return end
 
	aimvec:Mul( 5000 )
	--aimvec:Add( VectorRand( -10, 10 ) )
	phys:ApplyForceCenter( aimvec )
end