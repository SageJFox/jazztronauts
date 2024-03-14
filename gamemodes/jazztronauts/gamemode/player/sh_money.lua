AddCSLuaFile()

module( "jazzmoney", package.seeall )


local SharedPotConvar = CreateConVar("jazz_money_shared", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable a shared money pot. "
	.. "Everything a player earns affects the whole group, that each player can decide how they spend it. "
	.. "If false, reverts to the traditional \"what you earn is what you spend\". "
	.. "A shared pot is more engaging for cooperative group play, but if ya'll want to hate eachother then go ahead, turn it off.")

local spentTblName= "players_spent"
local earnTblName = "players_earned"

if SERVER then
	local money = include("sql.lua")

	-- Create the shared nettables on player $
	local spentTbl = nettable.Create(spentTblName, nettable.TRANSMIT_AUTO, 1.0)
	local earnTbl = nettable.Create(earnTblName, nettable.TRANSMIT_AUTO, 1.0)

	-- Get the total amount of money that's been earned
	local cacheTotal = nil
	function GetTotal(ignoreCache)
		if not ignoreCache and cacheTotal then return cacheTotal end
		cacheTotal = money.GetTotalEarned()
		return cacheTotal
	end

	-- Force an update to make sure everyone's client numbers are accurate
	local function UpdateTotal()
		GetTotal(true)

		-- Update nettable for playercounts
		local allNotes = money.GetAllNotes()
		for _, v in pairs(allNotes) do
			earnTbl[v.steamid] = v.earned
			spentTbl[v.steamid] = v.spent
		end
	end

	-- Get per-player money info (earned/spent)
	function GetPlayerMoney(ply)
		return money.GetNotes(ply)
	end

	-- Get the total number of players that participated in this session
	function GetTotalPlayers()
		return money.GetTotalPlayers()
	end

	function ChangeNotes(ply, amt, onlyearn)
		if isentity(ply) then ply = ply:SteamID64() end

		-- Change money, return if failed
		if not money.ChangeNotes(ply, amt, onlyearn) then return false end

		if amt > 0 or onlyearn then -- Earned, refresh total $ cache
			UpdateTotal(amt)
		else -- Spent, update this person's spent table
			spentTbl[ply] = GetPlayerMoney(ply).spent
		end
		return true
	end

	local HelpMsg = "Gives money to all players. Not affected by active multipliers. Negative values subtract.\n"
	.. 'If jazz_money_shared is 0, specify a player via SteamID64. The host can type "self" instead.\n'
	.. "Usage: jazz_money_add amount [self/SteamID64]"
	concommand.Add("jazz_money_add", function(ply, _, args)
		local amt = tonumber(args[1])

		if !amt then
			print(HelpMsg)
			return
		end

		local steamid64 = "-1"

		-- sets for everyone
		if IsShared() and !args[2] then
			if amt < 0 then
				local sel = "SELECT * FROM jazz_player_money WHERE earned = (SELECT MAX(earned) FROM jazz_player_money)"
				local res = jsql.Query(sel)[1]

				if tonumber(res.earned) < math.abs(amt) then
					print("Can't remove that much money!")
					return
				end

				steamid64 = res.steamid
			end

			ChangeNotes(steamid64, amt, true)
			return
		end


		if args[2] == "self" then
			if !ply or !IsValid(ply) then
				print("Couldn't find you!")
				return
			end
			steamid64 = ply:SteamID64()
		elseif tonumber(args[2]) then
			steamid64 = args[2]
		else
			print("Invalid player specified!")
			return
		end

		if not ChangeNotes(steamid64, amt) then
			print("Failure!")
		end
	end, nil, HelpMsg, { FCVAR_CHEAT } )

	UpdateTotal()

	-- Lua refresh do a full total update
	cvars.AddChangeCallback(SharedPotConvar:GetName(), function()
		UpdateTotal()
	end, "jazz_update_money")
end

AllPlayerMoney = AllPlayerMoney or {}
Total = Total or 0

-- Get note count for every single player
function GetAllNotes()
	return AllPlayerMoney
end

-- Whether or not the money is shared between players
function IsShared()
	return SharedPotConvar:GetBool()
end

-- Get how much money the given player has at their disposal
function GetNotes(ply)
	local mon = GetPlayerMoney(ply)
	local total = IsShared() and GetTotal() or (mon and mon.earned or 0)
	return total - (mon and mon.spent or 0)
end

if CLIENT then

	-- Get the total amount of money that's been earned
	function GetTotal()
		return Total
	end

	-- Get per-player money info (earned/spent)
	function GetPlayerMoney(ply)
		local id64 = isstring(ply) and ply or (IsValid(ply) and ply:SteamID64())
		return AllPlayerMoney[id64]
	end

end

-- Combine player earned and spent tables
local function updateEarned(changed, removed)
	local earnedTbl, spentTbl = nettable.Get(earnTblName), nettable.Get(spentTblName)
	local newTotal = 0
	for k, v in pairs(earnedTbl) do
		local earned, spent = earnedTbl[k], spentTbl[k]
		newTotal = newTotal + (earned or 0)

		if not earned or not spent then continue end

		AllPlayerMoney[k] = AllPlayerMoney[k] or {}
		AllPlayerMoney[k].earned = earned
		AllPlayerMoney[k].spent = spent
	end

	Total = newTotal
end

nettable.Hook(earnTblName, "jazzUpdateEarned", updateEarned)
nettable.Hook(spentTblName, "jazzUpdateEarned", updateEarned)
