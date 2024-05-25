AddCSLuaFile()

module( "jazzloc", package.seeall )

if CLIENT then
	MaterialLocMap = MaterialLocMap or {}
	MaterialSystemReady = MaterialSystemReady or false
	DummyTestMaterial = CreateMaterial("jazz_dummy_localization_material", "UnlitGeneric", {
		["$basetexture"] = "color/white"
	})

	Localize = function(...)
	
		local arg = {...}
		local strang = ""
		local strtable = arg
		if isstring(arg[1]) then
			strang = tostring(table.remove(strtable,1))
		elseif istable(arg[1]) then
			strtable = arg[1]
			strang = tostring(table.remove(strtable,1))
		else
			error("jazzloc.Localize needs strings or a table of strings, recieved " .. type(arg[1]) )
		end

		--see if we have a Jazztronauts specific override for a default localization string
		--(also technically lets us leave the "jazz." off of our strings in the code if we wanted to)
		local jazzitup = "jazz."..strang
		if not (jazzitup == language.GetPhrase(jazzitup)) then
			strang = jazzitup
		end
		strang = language.GetPhrase(strang)
		
		for i,v in ipairs(strtable) do
			strang = string.Replace(strang,"%"..i.."%",Localize(tostring(v)))
		end
		
		return strang
		
	end

	local articlesEN = {
		"a ",
		"an ",
		"the ",
	}

	--strip the leading article from a localization
	LocalizeNoArticle = function(...)
		local basestr = jazzloc.Localize(...)
		local lang = GetConVar("gmod_language"):GetString()
		if lang == "en" or lang == "en-pt" or GetConVar("english"):GetBool() then
			for _, v in ipairs(articlesEN) do
				local start, fin, _ = string.find(string.lower(basestr),"^"..v)
				if start ~= nil then
					basestr = string.sub(basestr,fin+1)
					break
				end
			end
			return basestr
		end
	end

	local function loadTexture(texturepath)
		DummyTestMaterial:SetTexture("$basetexture", texturepath)
		local texture = DummyTestMaterial:GetTexture("$basetexture")

		return texture and not texture:IsError() and not texture:IsErrorTexture() and texture or nil
	end

	local function doLocalizeMaterial(matpath)
		assert(MaterialLocMap[matpath])
		local matinfo = MaterialLocMap[matpath]

		-- Lua starts before the material system is ready and can cause a crash
		if not MaterialSystemReady then
			return
		end

		-- Fill out metadata if this material isn't in the system yet
		if not matinfo.orig_name then
			local mat = Material(matpath)
			local basetexture = mat:GetTexture("$basetexture")
					
			--print("LocalizeMaterial(" .. matpath .. ") = " .. tostring(mat))
			matinfo.material  = mat
			matinfo.texture   = basetexture
			matinfo.orig_name = basetexture and basetexture:GetName() or nil
		end


		if matinfo.orig_name then

			-- Build the translated name of the base texture based on our current language
			local lang = string.lower(GetConVar("gmod_language"):GetString())
			local translated = matinfo.orig_name .. "_" .. string.lower(lang)
			local currentName = matinfo.texture and string.lower(matinfo.texture:GetName()) or nil
			local mat = matinfo.material

			-- Check if we even need to translate anything
			if currentName == translated or (lang == "en" and currentName == matinfo.orig_name) then
				--print("Texture is already the correct translation")
				return
			end

			-- Try loading the translated texture, and only if it succeeds do we override the base material
			local new_texture = loadTexture(translated)
			if new_texture then
				print("Localizing " .. mat:GetName() .. ": " .. matinfo.orig_name .. " -> " .. translated)

			-- Check if we need to revert
			elseif currentName != matinfo.orig_name then
				new_texture = loadTexture(matinfo.orig_name)
				print("Reverting to original texture for " .. mat:GetName() .. ": " .. tostring(currentName) .. " -> " .. tostring(matinfo.orig_name))
			else
				--print("No translation found for " .. mat:GetName() .. ": " .. matinfo.orig_name .. " -> " .. translated)
			end

			-- Apply the new texture
			if new_texture then
				matinfo.material:SetTexture("$basetexture", new_texture)
				matinfo.texture = new_texture
			end
		end
	end

	LocalizeMaterial = function(matpath)
		-- print("LocalizeMaterial(" .. matpath .. ")")
	
		-- Add to system, but don't fill out metadata until material system initialized
		if not MaterialLocMap[matpath] then
			MaterialLocMap[matpath] = {}
		end

		doLocalizeMaterial(matpath)

	end

	RefreshMaterials = function()
		for matpath, _ in pairs(MaterialLocMap) do
			doLocalizeMaterial(matpath)
		end
	end

	-- Refresh after material system initialized
	timer.Simple(0, function()
		MaterialSystemReady = true
		print("Initialized material system, refreshing localized materials")
		RefreshMaterials()
	end )

	-- Refresh on language change
	cvars.AddChangeCallback("gmod_language", RefreshMaterials, "jazz_localization_listener")

	-- Refresh on concommand
	concommand.Add("jazz_loc_refreshmats", function()
		RefreshMaterials()
	end )

	
else --no localization on server, so we'll just tack on the arguments to the localization token there

	Localize = function(...)
	
		local arg = {...}
		local strang = tostring(table.remove(arg,1))
		
		for i,v in ipairs(arg) do
			strang = strang..","..tostring(v)
		end
		
		return strang
		
	end

end

function AddSeperators(amount)

	local formatted = amount
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end

	return formatted

end

--Roman Numeral Conversion

local numerals = {
	{"I","V"}, --    1, 5
	{"X","L"}, --   10, 50
	{"C","D"}, --  100, 500
	{"M"}      -- 1000*
}

--Overbars represent value * 1000
local overbar = "̅"
--fun fact, it's doubtful that overbars were actually used by the Romans. But then, "Roman Numerals" weren't really standardized like they are now.
--(You probably could very easily see IIII back in the day.)
--I sorta suspected this before reading up on it. The fact that they were so... *neat* fitting with the comma separators we use for Arabic Numbers these days was suspicious to me.
--Plus, who really needed to count over 3999 in 12 AD? Simpler times.
--Anyway, history disclaimer aside, they look nice, especially for what we wanna use them for, and hopefully won't come up often regardless.
--Speaking of hopefully and looking nice, *hopefully* they actually work in GMod text. Console doesn't display them particularly well.

local one_func = function(digit, bars, small)
	local digit, bars = digit, bars
	if small then --M vs I̅
		bars = bars - 1
		if digit == 1 then digit = 4 end
	end
	return numerals[digit][1] .. string.rep(overbar,bars)
end

local fivefunc = function(digit, bars)
	--5 is always big (>3) so no need to consider it
	return numerals[digit][2] .. string.rep(overbar,bars)
end

--individual digit processing. The pattern is the same for 1s, 10s, and 100s places, just different characters used
local numeralfuncs = {
	[0] = function() return "" end,
	[1] = one_func,
	[2] = function(digit, bars, small) return string.rep(one_func(digit, bars, small),2) end, --double 1
	[3] = function(digit, bars, small) return string.rep(one_func(digit, bars, small),3) end, --triple 1
	[4] = function(digit, bars) return one_func(digit, bars) .. fivefunc(digit, bars) end, -- 1, 5
	[5] = fivefunc,
	[6] = function(digit, bars) return fivefunc(digit, bars) .. one_func(digit, bars) end, -- 5, 1
	[7] = function(digit, bars) return fivefunc(digit, bars) .. string.rep(one_func(digit, bars),2) end, -- 5, 2
	[8] = function(digit, bars) return fivefunc(digit, bars) .. string.rep(one_func(digit, bars),3) end, -- 5, 3
	[9] = function(digit, bars) return one_func(digit, bars) .. numerals[digit + 1][1] .. string.rep(overbar,bars) -- 1 of this set, followed by 1 of next set
	end,
}

function RomanNumerals(digits)

	if not tonumber(digits) then ErrorNoHaltWithStack(digits," isn't a number!") return digits end

	local str = ""

	--okay stay with me here. First, numerals don't handle negatives or decimals so make sure we don't have those.
	local digits = math.floor(math.abs(tonumber(digits)))

	--we wanna check our digits in triplets, so we're using the comma function to split it up, and reversing the table
	local groups = table.Reverse(string.Split(string.Comma(digits),","))

	--so now we have a list of our number split into sections of ones, thousands, millions, etc.

	--the index of this table is the number of overbars the section will need (minus one, since lua tables start at 1), if...
	--...its value is greater than three and it's in the thousands or more place (since we use "M" for up to the 3000s, before switching to overbars for 4000 and beyond)

	--we also don't have to worry about going out of bounds on our numerals table, because it will only naturally go up to 3, and we only go to index 4 manually on 9s
	for k, v in ipairs(groups) do

		local substr = ""

		--processing each digit
		for digit = 1, #v do

			local val = tonumber(v[#v + 1 - digit]) --this reverses our processing so we start at the rightmost digit and work left

			--previously discussed overbar caveat with values of 1, 2, and 3
			local small = tonumber(v) <= 3
			if k == 1 then small = false end

			--run our conversion function, and put it on our triplet
			substr = numeralfuncs[val](digit,k - 1,small) .. substr

		end

		--slap it onto the begining of the whole number
		str = substr .. str

	end

	return str
end

--[[
if SERVER then return end
local testtime = SysTime()
local printtest = function(x) print(x,RomanNumerals(x)) end
local test = 1000
repeat
	local digits = math.random(7)
	local num = ""
	repeat
		num = num .. math.random(0,9)
		digits = digits - 1
	until (digits < 1)
	printtest(num)
	test = test - 1
until (test < 1)
print("1,000 cycles with randomizer took:",(SysTime() - testtime) * 1000,"ms")--]]
--[[
local test = 10000000000
repeat
	printtest(test)
	test = test - 1
until (test < 9999999001)
print("1,000 cycles with 10 digits each took:",(SysTime() - testtime) * 1000,"ms")--]]