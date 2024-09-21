AddCSLuaFile()
DEFINE_BASECLASS( "player_sandbox" )

local PLAYER = {}

PLAYER.DisplayName			= "Hub Class"

PLAYER.WalkSpeed			= 200		-- How fast to move when not running
PLAYER.RunSpeed				= 300		-- How fast to move when running
PLAYER.SlowWalkSpeed		= 150		-- How fast to move when slow walking
PLAYER.CrouchedWalkSpeed	= 0.2		-- Multiply move speed by this when crouching
PLAYER.DuckSpeed			= 0.3		-- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed			= 0.3		-- How fast to go from ducking, to not ducking
PLAYER.JumpPower			= 200		-- How powerful our jump should be
PLAYER.CanUseFlashlight	 = true		-- Can we use the flashlight
PLAYER.MaxHealth			= 100		-- Max health we can have
PLAYER.StartHealth			= 100		-- How much health we start with
PLAYER.StartArmor			= 0			-- How much armour we start with
PLAYER.DropWeaponOnDie		= false		-- Do we drop our weapon when we die
PLAYER.TeammateNoCollide	= false		-- Overwritten in ShouldCollide. See hook for more info.
PLAYER.AvoidPlayers			= false		-- Automatically swerves around other players
PLAYER.JazzSizeMultiplier	= 1			-- player size multiplier (Jazztronauts)


function PLAYER:SetupDataTables()
	BaseClass.SetupDataTables( self )
	self.Player:NetworkVar( "Int", "Notes" )
	self.Player:NetworkVar("Bool", "InScene")
end

function PLAYER:Spawn()
	BaseClass.Spawn(self)
	self.Player.JazzSizeMultiplier = 1
	self.Player:SetCustomCollisionCheck(true)
end

function PLAYER:SetJazzSizeMultiplier(multi)
	self.Player.JazzSizeMultiplier = multi
end
function PLAYER:GetJazzSizeMultiplier()
	return self.Player.JazzSizeMultiplier
end

function PLAYER:ShouldDrawLocal()
	
	if not (istable(self.Player.JazzDialogProxy) and IsValid(self.Player.JazzDialogProxy.Instance)) then return BaseClass.ShouldDrawLocal(self) end

end

--
-- Called on spawn to give the player their default loadout
--
function PLAYER:Loadout()

	self.Player:RemoveAllAmmo()
	self.Player:SwitchToDefaultWeapon()

end

local meta = FindMetaTable("Player")
function meta:ChangeNotes(delta)
	return jazzmoney.ChangeNotes(self, delta)
end

function meta:GetNotes()
	return jazzmoney.GetNotes(self)
end

--
-- Reproduces the jump boost from HL2 singleplayer
--
local JUMPING

function PLAYER:StartMove( move )

	-- Only apply the jump boost in FinishMove if the player has jumped during this frame
	-- Using a global variable is safe here because nothing else happens between SetupMove and FinishMove
	if bit.band( move:GetButtons(), IN_JUMP ) ~= 0 and bit.band( move:GetOldButtons(), IN_JUMP ) == 0 and self.Player:OnGround() then
		JUMPING = true
	end

end

function PLAYER:FinishMove( move )

	-- If the player has jumped this frame
	if ( JUMPING ) then
		-- Get their orientation
		local forward = move:GetAngles()
		forward.p = 0
		forward = forward:Forward()

		-- Compute the speed boost

		-- HL2 normally provides a much weaker jump boost when sprinting
		-- For some reason this never applied to GMod, so we won't perform
		-- this check here to preserve the "authentic" feeling
		local speedBoostPerc = ( ( not self.Player:Crouching() ) and 0.5 ) or 0.1

		local speedAddition = math.abs( move:GetForwardSpeed() * speedBoostPerc )
		local maxSpeed = move:GetMaxSpeed() * ( 1 + speedBoostPerc )
		local newSpeed = speedAddition + move:GetVelocity():Length2D()

		--[[lol, lul-- Clamp it to make sure they can't bunnyhop to ludicrous speed
		if newSpeed > maxSpeed then
			speedAddition = speedAddition - ( newSpeed - maxSpeed )
		end]]

		-- Reverse it if the player is running backwards
		if move:GetVelocity():Dot( forward ) < 0 then
			speedAddition = -speedAddition
		end

		-- Apply the speed boost
		move:SetVelocity( forward * speedAddition + move:GetVelocity() )
	end

	JUMPING = nil

end

if CLIENT then
	-- Clientside only version of player:Lock()
	function meta:JazzLock(lock)
		self.JazzIsCurrentlyLocked = lock
		self.JazzLastLockAngles = lock and (self.JazzLastLockAngles or self:EyeAngles())
	end

	hook.Add("StartCommand", "JazzLockPlayer", function(ply, usercmd)
		if not ply.JazzIsCurrentlyLocked then return end

		ply.JazzLastLockAngles = ply.JazzLastLockAngles or usercmd:GetViewAngles()
		usercmd:ClearMovement()
		usercmd:SetViewAngles(ply.JazzLastLockAngles)
	end )
end

-- Turns out TeammateNoCollide is really funky. Zombies can't attack you (among other oddities)
-- So just manually check collision here for players
hook.Add("ShouldCollide", "JazzPlayerCollide", function(ent1, ent2)
	if not (ent1:IsPlayer() and ent2:IsPlayer()) then return end
	if cvars.Bool("jazz_pvp") then return end
	return false
end )

-- Called from JazzPlayerSpawnLogic and player_pvp callback
-- By now we're certain ply1 is really a player, and player collision is on
hook.Add("JazzPlayerOnPlayer", "JazzPlayerCollideUnstuck", function(ply1, spawn)
	local function checkPlayer()
		local pos = ply1:GetPos()
		local min,max = ply1:GetCollisionBounds()
		return util.TraceHull({
			start = pos,
			endpos = pos,
			mins = min,
			maxs = max,
			filter = ply1,
			ignoreworld = true,
			mask = MASK_PLAYERSOLID
		})
	end

	-- determine who we could be stuck on
	local ply2 = false
	if IsValid(spawn) and spawn:IsPlayer() then ply2 = spawn end
	-- it's possible they didn't spawn *on* a player, but one happened to be standing there
	if !ply2 then
		local initTrace = checkPlayer()
		if initTrace.Hit then ply2 = initTrace.Entity end
	end
	-- if we've got nothing, probably safe to check out
	if !ply2 then return end

	-- stops everything and lets them collide again
	local function WrapItUp()
		hook.Remove("ShouldCollide", "JazzUnstuckCollision")
		hook.Remove("Think", "JazzUnstuckLoop")
	end

	-- make sure everyone's still here, stop if not
	local function StillValid()
		if ply1:IsValid() and ply2:IsValid() then
			return true
		end

		WrapItUp()
		return false
	end

	-- constantly checks if they're still in each other, stop once they aren't
	hook.Add("Think", "JazzUnstuckLoop", function()
		if not StillValid() then return end
		if not checkPlayer().Hit then WrapItUp() end
	end)

	-- stop them from colliding
	hook.Add("ShouldCollide", "JazzUnstuckCollision", function(ent1, ent2)
		if not StillValid() then return end

		-- both ents should equal one of the players
		if not (ent1 == ply1 or ent2 == ply1) then return end
		if not (ent1 == ply2 or ent2 == ply2) then return end

		return false
	end)
end)

if SERVER then
	local jazzafktotaltime = CreateConVar("jazz_afk_time",90,FCVAR_ARCHIVE,"How long (in seconds) a player can be idle before a trolley will consider them AFK and force them into a seat if other players are waiting. Set to 0 or below to disable.\n"
	.."Note: This time is doubled for players currently in scenes")
	
	--clear AFK marks if it's been disabled
	cvars.AddChangeCallback("jazz_afk_time", function(name, old, value)
		if tonumber(value) <= 0 then
			for _, v in ipairs(player.GetHumans()) do
				v.JazzAFK = nil
			end
		end
	end)
	
	--should we make this networked and do Clientside stuff like "OnKeyCodeReleased" (for panels) or "ChatTextChanged"?
	JazzAFKThinkTime = CurTime()
	--player has pushed/released a button, they can't be afk
	hook.Add("PlayerButtonDown","JazzAFKChecker",function(ply,button)
		ply.JazzAFKTime = CurTime()
		ply.JazzAFK = nil
	end)
	hook.Add("PlayerButtonUp","JazzAFKChecker",function(ply,button)
		ply.JazzAFKTime = CurTime()
		ply.JazzAFK = nil
	end)
	
	--player has chatted, they can't be afk
	hook.Add("PlayerSay","JazzAFKChecker",function(ply,text,teamChat)
		ply.JazzAFKTime = CurTime()
		ply.JazzAFK = nil
	end)

	hook.Add("Think","JazzAFKChecker",function()
		if CurTime() - JazzAFKThinkTime < .1 then return end --only run 10/sec max
		JazzAFKThinkTime = CurTime()

		for _, v in ipairs(player.GetHumans()) do
			if not v.JazzAFKTime then v.JazzAFKTime = CurTime() continue end
			--check if their view has changed since the last check (mouse movement, as best as we can get it)
			if isvector(v.LastFrameAim) and not v.LastFrameAim:IsEqualTol(v:GetAimVector(),0.001) then
				v.JazzAFKTime = CurTime()
				v.JazzAFK = nil
				v.LastFrameAim = v:GetAimVector()
				continue
			end
			v.LastFrameAim = v:GetAimVector()

			--if none of our non-afk checks have happened in the past X seconds, they're afk
			--give double the time limit to players in scenes (they won't be moving their view at all, and might not be pushing buttons for longer)
			if CurTime() - v.JazzAFKTime - ( v:GetInScene() and jazzafktotaltime:GetFloat() or 0 ) > jazzafktotaltime:GetFloat() then
				v.JazzAFK = true
			end
			--print(v.JazzAFK)
		end
	end)
end

player_manager.RegisterClass( "player_hub", PLAYER, "player_sandbox" )
