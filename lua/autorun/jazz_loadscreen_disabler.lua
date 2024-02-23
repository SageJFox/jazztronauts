-- Fix loading screen not correctly getting reset when switching out of jazztronauts

local jazz_var = "sv_loadingurl"
local jazz_url = "asset://garrysmod/html/jazzload/"
local WORKSHOP_CACHE_PATH = "jazztronauts/cache"

local function ClearCache()
	local files = file.Find(WORKSHOP_CACHE_PATH .. "/*", "DATA")
	for _, v in pairs(files) do
		file.Delete(WORKSHOP_CACHE_PATH .. "/" .. v)
	end
end

hook.Add("Initialize", "jazz_disable_loadscreen", function()

	-- If we're literally in the jazztronauts gamemode, don't reset the loading url
	if jazz and jazz.GetVersion and jazz.GetVersion() ~= nil then
		--TODO: add support for gracefully switching our loading screens (whether user has changed branches or from us adding alternate styles)
		return
	end

	local convar = GetConVar(jazz_var)
	if convar then
		--TODO: We should store the original loadingurl and load it back here.
		if string.StartsWith(convar:GetString(), jazz_url) then
			RunConsoleCommand(jazz_var, "")
		end
	end

	-- Also clear the jazz cache of downloaded maps
	ClearCache()
end)
