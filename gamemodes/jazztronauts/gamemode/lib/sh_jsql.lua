AddCSLuaFile()
if CLIENT then return end

module( 'jsql', package.seeall )

/*

*/
Tables = Tables or {}

-- Tables we already know exist, so we don't ask sqlite on every query
local ensured = {}

function Register(tblName, columns)
	Tables[tblName] = columns
end

-- Clear all registered tables
function Reset(tbl)
	if tbl then
		ensured[tbl] = nil
		sql.Query(string.format("DROP TABLE IF EXISTS %s", tbl))
	else
		for k, _ in pairs(Tables) do
			Reset(k)
		end
	end
end

-- Clear all registered tables except the ones given
function ResetExcept(tbls)
	PrintTable(tbls)
	for k, _ in pairs(Tables) do
		if table.HasValue(tbls, k) then continue end
		print("resettin' " .. k)
		Reset(k)
	end
end

local function ensureTable(tblName)
	if ensured[tblName] then return end

	local tbl = Tables[tblName]
	if not tbl then print("Invalid SQL table: ", tblName) end

	if not sql.TableExists(tblName) then
		Msg(string.format("Creating '%s' table...\n", tblName))
		print(string.format("CREATE TABLE %s (%s)", tblName, tbl))
		if sql.Query(string.format("CREATE TABLE %s (%s)", tblName, tbl)) == false then
			print("TABLE CREATION FAILED:")
			print(sql.LastError())
			return
		end
	end

	ensured[tblName] = true
end

local function ensureTables()
	for k, v in pairs(Tables) do
		ensureTable(k)
	end
end

function Query(tblName, cmd)
	if cmd == nil then
		cmd = tblName
		ensureTables()
	else
		ensureTable(tblName)
	end

	if cmd then
		local res = sql.Query(cmd)

		-- A query that drops tables means we need to check them again
		if string.find(cmd, "[Dd][Rr][Oo][Pp]") then
			ensured = {}
		end

		if res == false then
			print("QUERY FAILED: ")
			print(cmd)
			print(sql.LastError())
		end

		return res
	end
end