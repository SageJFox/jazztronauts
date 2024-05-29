module( "missions", package.seeall )

concommand.Add("jazz_debug_checkmissionprop", function(ply, cmd, args, argStr)

		if #args == 0 then
			MsgC("Format is ",Color(100,255,100),"jazz_debug_checkmissionprop [optional missionID] propname\n")
			Msg("Debug command for checking if a particular prop is accepted by any missions. Put in a mission ID to check a specific mission.\n" ..
			"Use full prop name (including models/ and .mdl) for accurate results!\n")
			return
		end

		local runtime = SysTime()
		local specific = tonumber(args[1])
		if specific then
			local mission = missions.GetMissionInfo(specific)
			local prop = string.lower(string.Trim(string.sub(argStr,5)))
			if mission then
				if mission.Filter(prop) then
					Msg("Mission #", specific)
					MsgC(Color(100,255,100), " accepts ")
					Msg(prop,"\n")
				else
					Msg("Mission #", specific)
					MsgC(Color(255,100,100), " doesn't accept ")
					Msg(prop,"\n")
				end
			else
				print("Invalid mission \"" .. specific .. "\"!")
			end
		else
			local prop = string.lower(string.Trim(argStr))
			local any = false
			Msg(prop)
			--PrintTable(missions.MissionList)
			for k, _ in pairs(missions.MissionList) do
				local minfo = GetMissionInfo(k)
				--PrintTable(minfo)
				if minfo.Filter(prop) then
					if not any then Msg(":\n") end
					MsgC(Color(100,255,100), "\t", minfo.Instructions, " (#", k, ") accepted!\n")
					any = true
				end
			end
			if not any then MsgC(Color(255,100,100), " not accepted by any mission!\n") end
		end
		print("Queue took ".. tostring((SysTime() - runtime) * 1000) .. "ms")
	end,
	nil, "Format is jazz_debug_checkmissionprop [optional missionID] propname\n" ..
	"Debug command for checking if a particular prop is accepted by any missions. Put in a mission ID to check a specific mission.\n" ..
	"Use full prop name (including models/ and .mdl) for accurate results!")

ResetMissions()

NPC_COMPUTER = 666
AddNPC("NPC_CAT_BAR", jazzloc.Localize("jazz.cat.bartender"), "models/andy/cats/cat_bartender.mdl")
AddNPC("NPC_CAT_SING", jazzloc.Localize("jazz.cat.singer"), "models/andy/cats/cat_singer.mdl")
AddNPC("NPC_CAT_PIANO", jazzloc.Localize("jazz.cat.pianist"), "models/andy/cats/cat_pianist.mdl")
AddNPC("NPC_CAT_CELLO", jazzloc.Localize("jazz.cat.cellist"), "models/andy/cats/cat_cellist.mdl")
AddNPC("NPC_NARRATOR", "", "models/npc/cat.mdl")
AddNPC("NPC_BAR", "")
AddNPC("NPC_CAT_VOID", jazzloc.Localize("jazz.cat.unknown"), "models/andy/basecat/cat_all.mdl")
AddNPC("NPC_CAT_ASH", jazzloc.Localize("jazz.cat.ash"), "models/andy/basecat/cat_all.mdl")

-- Utility function for giving a player a monetary reward
local function GrantMoney(amt)
	return function(ply)
		ply:ChangeNotes(amt * newgame.GetMultiplier()) --todo: if this is being affected by the multiplier, it should probably be re-given on subsequent resets?
	end
end

-- Utility function for unlocking something for the player
local function UnlockItem(lst, unlock)
	return function(ply)
		unlocks.Unlock(lst, ply, unlock)
	end
end

-- Combine multiple rewards
local function MultiReward(...)
	local funcs = {...}
	return function(ply)
		for _, v in pairs(funcs) do
			v(ply)
		end
	end
end

local function MatchesAny(mdl, tbl)
	for _, v in pairs(tbl) do
		if string.lower(mdl) == string.lower(v) then
			return true
		end
	end

	return false
end

local function MatchesAnyPartial(mdl, tbl)
	for _, v in pairs(tbl) do
		if string.match( string.lower(mdl), string.lower(v) ) then
			return true
		end
	end

	return false
end


local function oildrums(mdl)
	--[[return MatchesAny(mdl, {
			"models/props_c17/oildrum001_explosive.mdl",
			"models/props_c17/oildrum001.mdl",
			"models/props_phx/oildrum001_explosive.mdl",
			"models/props_phx/oildrum001.mdl"
		})]]
	return MatchesAny(mdl, {
			"models/props_phx/facepunch_barrel.mdl",
			--L4D
			"models/props_industrial/barrel_fuel.mdl",
			--ASW
			"models/swarm/barrel/barrel.mdl"
		}) or
		--drum, without weapons or the instrument (hopefully)
		(string.match(mdl, "drum") and
			not string.match(mdl, "fairground") and
			not string.match(mdl, "weapons") and 
			not string.match(mdl, "set") and 
			not string.match(mdl, "drummer"))
		end

local function gasoline(mdl)
	--gas can, gas pump
	return string.match(mdl, "gas") and
			(string.match(mdl, "can") or 
			(string.match(mdl, "pump") and not string.match(mdl, "_p%d+"))) -- L4D gas_pump_p<N>
end

local function propane(mdl)
	return	 string.match(mdl,"propane") or 
			(string.match(mdl,"canister") and not string.match(mdl,"chunk"))
end

local function fuel(mdl)
	return	oildrums(mdl) or
			gasoline(mdl) or
			propane(mdl)
end

local function beer(mdl)
	return MatchesAny(mdl, {
		"models/props/cs_militia/caseofbeer01.mdl",
		--TF2
		"models/props_trainyard/beer_keg001.mdl",
		"models/props_medical/beer_barrels.mdl",
		"models/player/items/taunts/beer_crate/beer_crate.mdl",
		"models/weapons/w_models/w_beer_stein.mdl"
	}) or 
	--bottle, without gibs, water bottle, or plastic bottle
	(string.match(mdl, "bottle") and
		not MatchesAnyPartial(mdl,{
			"chunk",
			"break",
			"water",
			"pill",
			"plastic",
			"frag"
		})
	) or 
	--beer cans
	(string.match(mdl, "beer") and string.match(mdl, "can")) or
	string.match(mdl, "molotov") or
	string.match(mdl, "molly") or
	--pass the whiskey
	string.match(mdl, "whiskey")

end

local function milk(mdl)
	return (string.match(mdl, "milk") and not MatchesAnyPartial(mdl, { "hat", "crate" } )) or
		   (string.match(mdl, "cow") and not MatchesAnyPartial(mdl,{ "cowboy", "cowl", "moscow", "cowmangler"})) or
			--these composite props have milk cartons/jugs in them, and are a lot more likely to show up than the individual models
			MatchesAny(mdl, {
				"models/props_junk/garbage128_composite001a.mdl",
				"models/props_junk/garbage128_composite001c.mdl",
				"models/props_junk/garbage128_composite001d.mdl",
				"models/props_junk/garbage256_composite001b.mdl"
			})
end

AddMission(0, NPC_CAT_CELLO, {

	-- User-friendly instructions for what the player should collect
	Instructions = "jazz.mission.drums",

	-- The accept function for what props count towards the mission
	-- Can be as broad or as specific as you want
	Filter = function(mdl)
		return oildrums(mdl)
	end,

	-- They need to collect 15 of em' to complete the mission.
	Count = 15,

	-- List of all missions that need to have been completed before this one becomes available
	-- Leave empty to be available immediately
	Prerequisites = nil,

	-- When they finish the mission, this function is called to give out a reward
	-- The 'GrantMoney' function returns a function that gives money
	OnCompleted = GrantMoney(5000)
})

AddMission(1, NPC_CAT_CELLO, {
	-- User-friendly instructions for what the player should collect
	Instructions = "jazz.mission.gasbeer",

	-- The accept function for what props count towards the mission
	-- Can be as broad or as specific as you want
	Filter = function(mdl)
		return gasoline(mdl) or beer(mdl)
	end,

	-- They need to collect 10 of em' to complete the mission.
	Count = 10,

	-- List of all missions that need to have been completed before this one becomes available
	Prerequisites = { IndexToMID(0, NPC_CAT_CELLO) },

	-- When they finish the mission, this function is called to give out a reward
	-- The 'GrantMoney' function returns a function that gives money
	OnCompleted = GrantMoney(10000)
})

AddMission(2, NPC_CAT_CELLO, {
	Instructions = "jazz.mission.chems",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			--"models/props_junk/garbage_plasticbottle001a.mdl",
			--"models/props_junk/garbage_plasticbottle002a.mdl",
			--"models/props_junk/garbage_plasticbottle003a.mdl",
			"models/props_junk/plasticbucket001a.mdl",
			"models/props_junk/glassjug01.mdl",
			"models/props_lab/crematorcase.mdl",
			--"models/props_lab/jar01a.mdl",
			--"models/props_lab/jar01b.mdl",
			"models/props/de_train/biohazardtank.mdl",
			"models/props/de_train/biohazardtank_dm_10.mdl",
			--TF2
			"models/props_farm/shelf_props01.mdl",
			"models/props_gameplay/foot_spray_can01.mdl",
		}) or
		MatchesAnyPartial(mdl,{
			"oil",
		}) or
		(string.match(mdl, "jar") and not string.match(mdl, "_ajar") ) or
		(string.match(mdl, "bottle") and MatchesAnyPartial(mdl, { "plastic", "flask", "pill" } ) ) or
		propane(mdl) or
		--ASW
		string.match(mdl, "biomass") 
	end,
	Count = 10,
	Prerequisites = { IndexToMID(1, NPC_CAT_CELLO)  },
	OnCompleted = GrantMoney(15000)
})

AddMission(3, NPC_CAT_CELLO, {
	-- User-friendly instructions for what the player should collect
	Instructions = "jazz.mission.paint",

	-- The accept function for what props count towards the mission
	-- Can be as broad or as specific as you want
	Filter = function(mdl)
		--paintcan, paint bucket, paint tool
		return string.match(mdl, "paint") and MatchesAnyPartial(mdl, { "can", "bucket", "tool" } )
	end,

	-- They need to collect 1 of em' to complete the mission.
	Count = 5,

	-- List of all missions that need to have been completed before this one becomes available
	Prerequisites = { IndexToMID(2, NPC_CAT_CELLO)  },

	-- When they finish the mission, this function is called to give out a reward
	-- The 'GrantMoney' function returns a function that gives money
	OnCompleted = GrantMoney(20000)
})

AddMission(4, NPC_CAT_CELLO, {
	Instructions = "jazz.mission.drk",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/kleiner.mdl",
			"models/player/kleiner.mdl",
			"models/kleiner_monitor.mdl"
		})
	end,
	Count = 1,
	Prerequisites = { IndexToMID(3, NPC_CAT_CELLO)  },
	OnCompleted = GrantMoney(25000)
})
--[[ --old mission 5, dialog mentions getting milk so this is ???
AddMission(5, NPC_CAT_CELLO, {
	Instructions = "jazz.mission.cactus",
	Filter = function(mdl)
		return mdl == "models/props_lab/cactus.mdl"
	end,
	Count = 1,
	Prerequisites = { IndexToMID(4, NPC_CAT_CELLO)  },
	OnCompleted = GrantMoney(30000)
})]]

AddMission(5, NPC_CAT_CELLO, {
	Instructions = "jazz.mission.milk",
	Filter = function(mdl) return milk(mdl) end,
	Count = 10,
	Prerequisites = { IndexToMID(4, NPC_CAT_CELLO)  },
	OnCompleted = GrantMoney(30000)
})

/*
===========================
	Bartender Missions
===========================
*/
AddMission(0, NPC_CAT_BAR, {
	Instructions = "jazz.mission.crates",
	Filter = function(mdl)
		return string.match(mdl, "crate") and not MatchesAnyPartial(mdl, { "chunk", "gib", "_p%d+" } ) -- CSS crates_fruit_p<N>
	end,
	Count = 10,
	Prerequisites = nil,
	OnCompleted = GrantMoney(5000)
})

AddMission(1, NPC_CAT_BAR, {
	Instructions = "jazz.mission.cars",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/buggy.mdl",
			"models/vehicle.mdl",
			--APCs
			"models/combine_apc.mdl",
			"models/combine_apc_dynamic.mdl",
			"models/combine_apc_wheelcollision.mdl",
			"models/combine_apc_destroyed_gib01.mdl",
			"models/props_vehicles/apc001.mdl",
			"models/props/de_piranesi/pi_apc.mdl",
			--we'll allow engines, Bartender wants parts afterall
			"models/props_c17/trappropeller_engine.mdl",
			"models/vehicle/vehicle_engine_block.mdl",
			--Ep1
			"models/vehicles/vehicle_van.mdl",
			--L4D
			"models/props_vehicles/trafficjam01.mdl",
			"models/props_waterfront/tour_bus.mdl",
			"models/destruction_tanker/destruction_tanker_cab.mdl",
			"models/destruction_tanker/pre_destruction_tanker_trailer.mdl",
			"models/destruction_tanker/destruction_tanker_front.mdl",
			"models/props_fairgrounds/kiddyland_ridecar.mdl",
			--Us!
			"models/sunabouzu/mg_tank.mdl"
		}) or
		(
			(
				MatchesAnyPartial(mdl, {
					--"car00",
					"van00",
					--"car_nuke",
					--"car_militia",
					"hatchback",
					"sedan",
					"bus0",
					"tractor", --technically includes portal 2 tractor beam stuff, but honestly if you're finding that you deserve it. Bartender *would* want those parts
					"ambulance",
					"vehicles/222",
					"jeep_us",
					"kubelwagen",
					"front_loader",
					"hmmwv", "humvee",
					"suv",
					"zapastl",
					"campervan",
					--fuck it, tanks too
					"boss_tank",
					"taunts/tank",
					"sherman_tank",
					"tiger_tank",
				} ) or
				--tanker, no train, destruction, etc.
				(string.match(mdl, "tanker") and not MatchesAnyPartial(mdl, { "train", "destruction", "debris", "boots" } ) ) or
				--police car, race car
				--(string.match(mdl, "car") and 
				--	(string.match(mdl, "police") or
				--	 string.match(mdl, "race"))) or
				--are we gonna regret this? probably
				(string.match(mdl,"car") and 
					not MatchesAnyPartial(mdl, {
						"cart",
						"card",
						"cargo",
						"carton",
						"carousel", "carosel",
						"carnival",
						"carved",
						"scarf",
						"carriage",
						"boxcar",
						"carb",
						"scare", "scary",
						"carentan",
						"carl",
						"toy",
						"coaster",
						"seat",
						"subway",
						"train",
						"tram",
						"mining",
						"bumper",
						"lift",
						"tarp",
						"c1_chargerexit",
						"car_int_dest", "car_wrecked_dest", "car_wrecked_dest", "cara_dest"
					})
				) or
				--truck, not truck sign or handtruck
				(string.match(mdl, "truck") and not MatchesAnyPartial(mdl, { "sign", "hand" } ) ) or
				--pickup, not powerup or item or etc.
				(string.match(mdl, "pickup") and not MatchesAnyPartial(mdl, { "powerup", "item", "emitter", "load", "swarm" } ) ) 
			) and
			--no glass/window/tire/wheel/gib
			not MatchesAnyPartial(mdl, { "window", "tire", "wheel", "glass", "gib" } )
		)
	end,
	Count = 10,
	Prerequisites = { IndexToMID(0, NPC_CAT_BAR)  },
	OnCompleted = GrantMoney(10000)
})

AddMission(2, NPC_CAT_BAR, {
	Instructions = "jazz.mission.melons",
	Filter = function(mdl)
		return string.match(mdl, "watermelon")
	end,
	Count = 10,
	Prerequisites = { IndexToMID(1, NPC_CAT_BAR)  },
	OnCompleted = GrantMoney(15000)
})

AddMission(3, NPC_CAT_BAR, {
	Instructions = "jazz.mission.propane",
	Filter = function(mdl)
		return propane(mdl)
	end,
	Count = 15,
	Prerequisites = { IndexToMID(2, NPC_CAT_BAR)  },
	OnCompleted = GrantMoney(20000)
})

AddMission(4, NPC_CAT_BAR, {
	Instructions = "jazz.mission.washers",
	Filter = function(mdl)
		return 
		--wash, without dishwasher or washington
		(string.match(mdl, "wash") and
			not MatchesAnyPartial(mdl, { "dish", "washington" } ) and 
			mdl ~= "models/props_street/window_washer_button.mdl"
		) or
		(string.match(mdl, "dryer") and mdl ~= "models/props_pipes/brick_dryer_pipes.mdl")
	end,
	Count = 5,
	Prerequisites = { IndexToMID(3, NPC_CAT_BAR)  },
	OnCompleted = GrantMoney(25000)
})

AddMission(5, NPC_CAT_BAR, {
	Instructions = "jazz.mission.antlions",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/antlion.mdl",
			"models/antlion_worker.mdl",
			"models/antlion_guard.mdl",
			"models/antlion_grub.mdl",
			"models/props_wasteland/antlionhill.mdl"
		}) or 
		string.match(mdl, "hive/nest")
	end,
	Count = 10,
	Prerequisites = { IndexToMID(4, NPC_CAT_BAR)  },
	OnCompleted = GrantMoney(30000)
})



/*
===========================
	Pianist Missions
===========================
*/
AddMission(0, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.chairs",
	Filter = function(mdl)
		return ((string.match(mdl, "chair") or string.match(mdl, "bench")) and not MatchesAnyPartial(mdl, { "chunk", "gib", "damage" })) or 
				 string.match(mdl, "seat") or
				(string.match(mdl, "stool") and not string.match(mdl, "toadstool")) or
				 string.match(mdl, "couch")
	end,
	Count = 5,
	Prerequisites = nil,
	OnCompleted = GrantMoney(5000)
})

AddMission(1, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.crabs",
	Filter = function(mdl)
		return string.match(mdl, "eadcrab") or --gets canisters and headcrabprep too (which is fine imo), leaving off the 'h' also gives us TF2 breadcrab
			MatchesAny(mdl, {
				--"models/headcrab.mdl",
				--"models/headcrabblack.mdl",
				--"models/headcrabclassic.mdl",

				-- Let em steal the heads off zombies
				"models/zombie/classic.mdl",
				"models/zombie/classic_torso.mdl",
				"models/zombie/poison.mdl",
				"models/zombie/fast.mdl",
				"models/gibs/fast_zombie_torso.mdl",
				"models/player/zombie_soldier.mdl",
				--ep2
				"models/zombie/zombie_soldier.mdl",
				"models/zombie/zombie_soldier_torso.mdl",
				"models/zombie/fast_torso.mdl",
				--hls
				"models/zombie.mdl",
				--"models/baby_headcrab.mdl"
		})
	end,
	Count = 10,
	Prerequisites = { IndexToMID(0, NPC_CAT_PIANO)  },
	OnCompleted = GrantMoney(10000)
})

AddMission(2, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.meals",
	Filter = function(mdl)
		return string.match(mdl, "watermelon") or 
			MatchesAny(mdl, {
				--"models/props_junk/garbage_takeoutcarton001a.mdl",
				--"models/food/burger.mdl",
				--"models/food/hotdog.mdl",
				--"models/props_junk/watermelon01.mdl",
				--"models/props_junk/food_pile01.mdl",
				--"models/props_junk/food_pile02.mdl",
				--"models/props_junk/food_pile03.mdl",
				--"models/props/cs_militia/food_stack.mdl"
				"models/props_lab/soupprep.mdl",
				"models/props_lab/headcrabprep.mdl",
				"models/props/cs_italy/it_mkt_container1a.mdl",
				"models/props/cs_italy/it_mkt_container3a.mdl",
				"models/props/de_inferno/crate_fruit_break.mdl",
				"models/props/de_inferno/crate_fruit_break_p1.mdl",
				"models/props/de_inferno/crates_fruit1.mdl",
				"models/props/de_inferno/crates_fruit1_p1.mdl",
				"models/props/de_inferno/crates_fruit2.mdl",
				"models/props/de_inferno/crates_fruit2_p1.mdl",
				--TF2
				"models/player/gibs/gibs_burger.mdl",
				"models/props_2fort/thermos.mdl",
				"models/props_halloween/pumpkin_loot.mdl",
				"models/props_medieval/medieval_meat.mdl"
			}) or
			MatchesAnyPartial(mdl, {
				"food", --gets a couple weird models like "boothfastfood" and "handrail_foodcourt" but noth worth filtering out these exact specific one-offs
				"carton", --includes milk cartons, cats love milk!
				--"fruit", --includes a lot of wood gibs from the orange crates
				"italy/orange",
				"banan", -- TF2 "banana" and CSS "bananna"
				"sandwich",
				"chocolate",
				"lunch",
				"halloween_medkit",
				"treat",
				"popcorn"
			}) or 
			(string.match(mdl, "items") and string.match(mdl, "plate")) or
			(string.match(mdl, "fridge") and not MatchesAnyPartial(mdl, { "door", "damaged" } ) ) or
			(string.match(mdl, "frige") and not MatchesAnyPartial(mdl, { "door", "damaged" } ) ) or --thanks Valve
			(string.match(mdl, "bread") and not MatchesAnyPartial(mdl, { "space", "spatula", "placement" } )
			) or
			milk(mdl) --see previous comment about cats and milk
	end,
	Count = 20,
	Prerequisites = { IndexToMID(1, NPC_CAT_PIANO)  },
	OnCompleted = GrantMoney(15000)
})

AddMission(3, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.vending",
	Filter = function(mdl)
		return string.match(mdl, "vending") and string.match(mdl, "machine")
	end,
	Count = 30,
	Prerequisites = { IndexToMID(2, NPC_CAT_PIANO)  },
	OnCompleted = GrantMoney(20000)
})

AddMission(4, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.horse",
	Filter = function(mdl)
		return string.match(mdl, "horse") and string.match(mdl, "statue")
	end,
	Count = 1,
	Prerequisites = { IndexToMID(3, NPC_CAT_PIANO)  },
	OnCompleted = GrantMoney(25000)
})

AddMission(5, NPC_CAT_PIANO, {
	Instructions = "jazz.mission.metropolice",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/police.mdl",
			"models/police_cheaple.mdl",
			"models/player/police.mdl",
			"models/player/police_fem.mdl"
		})
	end,
	Count = 3,
	Prerequisites = { IndexToMID(4, NPC_CAT_PIANO)  },
	OnCompleted = GrantMoney(30000)
})

/*
===========================
	Singer Missions
===========================
*/
AddMission(0, NPC_CAT_SING, {
	Instructions = "jazz.mission.documents",
	Filter = function(mdl)
		return MatchesAnyPartial(mdl, {
				"binder",
				"file",
				"filing", --not used in Valve props, but could be in custom stuff
				"folder",
				"mail"
			}) or
			--Too many "bookshelf" or "bookcase" have books to feel right excluding them
			(string.match(mdl, "book") and not MatchesAnyPartial(mdl, { "sign","stand" } ) ) or
			--Paper, not toilet paper, paper towel, or paper plate
			(string.match(mdl, "paper") and not MatchesAnyPartial(mdl, { "toilet", "towel", "plate" } ) )
	end,
	Count = 10,
	Prerequisites = nil,
	OnCompleted = GrantMoney(5000)
})

AddMission(1, NPC_CAT_SING, {
	Instructions = "jazz.mission.dolls",
	Filter = function(mdl) 
		--doll, not ragdoll or dollar
		return (string.match(mdl, "doll") and not MatchesAnyPartial(mdl, { "ragdoll", "dollar" } ) ) or
				string.match(mdl, "teddy")
	end,
	Count = 5,
	Prerequisites = { IndexToMID(0, NPC_CAT_SING)  },
	OnCompleted = GrantMoney(10000)
})

AddMission(2, NPC_CAT_SING, {
	Instructions = "jazz.mission.radiators",
	Filter = function(mdl)
		return	string.match(mdl, "radiator") or
				string.match(mdl, "_heater")
	end,
	Count = 15,
	Prerequisites = { IndexToMID(1, NPC_CAT_SING)  },
	OnCompleted = GrantMoney(15000)
})

AddMission(3, NPC_CAT_SING, {
	Instructions = "jazz.mission.plants",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/props/de_inferno/claypot03.mdl",
			"models/props/de_inferno/pot_big.mdl",
			--"models/props/de_inferno/potted_plant1.mdl",
			--"models/props/de_inferno/potted_plant2.mdl",
			--"models/props/de_inferno/potted_plant3.mdl",
			"models/props/cs_office/plant01.mdl",
			"models/props_lab/cactus.mdl",
			"models/props_junk/terracotta01.mdl",
			"models/props/de_tides/planter.mdl",
			"models/props_foliage/flower_barrel.mdl",
			"models/props/de_inferno/flower_barrel.mdl",
			"models/props_foliage/flower_barrel_dead.mdl",
			"models/props_frontline/flowerpot.mdl"
		}) or 
		string.match(mdl, "planter") or
		-- pot(ted) plant, no gibs
		(string.match(mdl, "plant") and string.match(mdl, "pot") and
			not (string.match(mdl, "gib") or string.match(mdl, "_p%d+")))
	end,
	Count = 10,
	Prerequisites = { IndexToMID(2, NPC_CAT_SING)  },
	OnCompleted = GrantMoney(20000)
})

AddMission(4, NPC_CAT_SING, {
	Instructions = "jazz.mission.alyx",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/alyx.mdl",
			"models/alyx_ep2.mdl",
			"models/alyx_interior.mdl",
			"models/alyx_intro.mdl",
			"models/player/alyx.mdl"
		})
	end,
	Count = 1,
	Prerequisites = { IndexToMID(3, NPC_CAT_SING)  },
	OnCompleted = GrantMoney(25000)
})

AddMission(5, NPC_CAT_SING, {
	Instructions = "jazz.mission.radios",
	Filter = function(mdl)
		return MatchesAny(mdl, {
			"models/props_radiostation/radio_antenna01.mdl",
		} ) or
		--radio, without station or radioactive
		(string.match(mdl, "radio") and not (MatchesAnyPartial(mdl, { "station", "radioactive", "radiology" } ) ) ) or 
		--get jukeboxes in here too
		(string.match(mdl, "juke") and string.match(mdl, "box"))
	end,
	Count = 10,
	Prerequisites = { IndexToMID(4, NPC_CAT_SING)  },
	OnCompleted = GrantMoney(30000)
})




