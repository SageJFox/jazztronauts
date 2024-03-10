AddCSLuaFile()
module( "newgame", package.seeall )

ENDING_CHEATED	 = 0
ENDING_ASH		 = 1
ENDING_ECLIPSE	 = 2

local nettbl = "jazz_newgame_info"
local glbtbl = "jazz_global_state"

concommand.Add("jazz_dump_globals", function()
	PrintTable(GetGlobalState())
end )

if SERVER then

	local ngsql = include("sql.lua")

	-- Network reset information once
	local tbl = nettable.Create(nettbl, nettable.TRANSMIT_ONCE)
	tbl["resets"] = ngsql.GetResetCount()

	-- Network global game state
	nettable.Create(glbtbl, nettable.TRANSMIT_AUTO)

	-- Reset the game, incrementing the reset counter and restarting from scratch
	-- Automatically reloads the tutorial map
	function ResetGame(endType)
		if not endType then
			ErrorNoHalt("Invalid ending type!")
			return
		end

		-- Mark every player that participated in this session
		-- #TODO: needed?

		-- Store this as a end-game reset
		local totalPlayers = jazzmoney.GetTotalPlayers()
		ngsql.AddResetInfo(endType, totalPlayers)

		-- Reset non-persistent sql stuff
		jsql.ResetExcept(GetPersistent())
		unlocks.ClearAll()

		-- Changelevel to intro again
		mapcontrol.Launch(mapcontrol.GetIntroMap())
	end

	-- Return information about every single reset
	function GetResets()
		return ngsql.GetResets()
	end

	function SetGlobal(key, value)
		ngsql.SetGlobal(key, value)
		UpdateNetworkState()
	end

	function UpdateNetworkState()
		nettable.Set(glbtbl, ngsql.GetGlobalState() or {})
	end

	UpdateNetworkState()
end

-- How many times the game has been finished and restarted
function GetResetCount()
	return (nettable.Get(nettbl) or {}).resets or 0
end

if SERVER then
	util.AddNetworkString("JazzRoadtripMultiplier")
	util.AddNetworkString("JazzRoadtripTotals")
end
multiplier = 1
roadtripcollected = 0
roadtriptotal = 0

-- Get the current active money multiplier
function GetMultiplier()

	if SERVER then 
		multiplier = progress.RoadtripMultiplier()
		net.Start("JazzRoadtripMultiplier")
			net.WriteFloat( multiplier )
		net.Broadcast()
	end
	return GetResetCount() + multiplier
end

if CLIENT then
	net.Receive("JazzRoadtripMultiplier",function(len,ply)
		multiplier = net.ReadFloat()
	end)
end
-- Get the current Roadtrip totals
function GetRoadtripTotals()

	if SERVER then 
		roadtripcollected, roadtriptotal = progress.RoadtripTotals()
		if roadtripcollected and roadtriptotal then
			net.Start("JazzRoadtripTotals")
				net.WriteUInt( roadtripcollected, 10 ) --up to 1023
				net.WriteUInt( roadtriptotal, 10 ) --up to 1023
			net.Broadcast()
		end
	end
	return roadtripcollected, roadtriptotal
end

if CLIENT then
	net.Receive("JazzRoadtripTotals",function(len,ply)
		roadtripcollected = net.ReadUInt(10)
		roadtriptotal = net.ReadUInt(10)
	end)
end

if SERVER then
	gameevent.Listen( "OnRequestFullUpdate" )
	hook.Add( "OnRequestFullUpdate", "JazzRoadtrip", function() --get our roadtrip status over to the client
		GetMultiplier()
		GetRoadtripTotals()
	end )
end

-- Get the current active money multiplier base value
function GetMultiplierBase()
	return GetResetCount()
end

-- Get the current active money multiplier extra value
function GetMultiplierExtra(truncate)
	local truncate = truncate or false 

	local mult = GetMultiplier() - GetResetCount()

	if truncate then mult = math.Round(mult * 10) / 10 end

	return mult
end

-- Get the global state table
function GetGlobalState()
	return nettable.Get(glbtbl) or {}
end

-- Get some piece of persistent global state
function GetGlobal(key)
	return GetGlobalState()[key]
end

