-- THIS IS AN EXACT CLONE OF CTLD by Ciribob, with added code to remove mist dependancies and add some automation.
-- custom DSMC code is at bottom!
-- and a few spots in between (alt.sanity)

local ModuleName  	= "TRPS_inj"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0018"
local Date			= "06/06/2020"


--[[
    Combat Troop and Logistics Drop

    Allows Huey, Mi-8 and C130 to transport troops internally and Helicopters to transport Logistic / Vehicle units to the field via sling-loads
    without requiring external mods.

    Supports all of the original CTTS functionality such as AI auto troop load and unload as well as group spawning and preloading of troops into units.

    Supports deployment of Auto Lasing JTAC to the field

    See https://github.com/ciribob/CTLD for a user manual and the latest version

	Contributors:
	    - Steggles - https://github.com/Bob7heBuilder
	    - mvee - https://github.com/mvee
	    - jmontleon - https://github.com/jmontleon
	    - emilianomolina - https://github.com/emilianomolina

    Version: 1.73 - 15/04/2018
      - Allow minimum distance from friendly logistics to be set
 ]]

TRPS = {} -- DONT REMOVE!

-- ************************************************************************
-- *********************  USER CONFIGURATION ******************************
-- ************************************************************************
TRPS.useNameCoding = false -- true, added by Chromium. if set, the automatic preload of infantries in APC & IFV vehicles will use group name tag to define which time of squad is loaded.

TRPS.soldierWeight = 110 -- single soldier weight, added by Chromium

TRPS.staticBugWorkaround = false --  DCS had a bug where destroying statics would cause a crash. If this happens again, set this to TRUE

TRPS.disableAllSmoke = false -- if true, all smoke is diabled at pickup and drop off zones regardless of settings below. Leave false to respect settings below

--TRPS.hoverPickup = --[[TRPShoverPickup_main or]] false --  if set to false you can load crates with the F10 menu instead of hovering... Only if not using real crates!

TRPS.enableCrates = true -- if false, Helis will not be able to spawn or unpack crates so will be normal CTTS
TRPS.slingLoad = TRPSslingLoad_main or false -- if false, crates can be used WITHOUT slingloading, by hovering above the crate, simulating slingloading but not the weight...
-- There are some bug with Sling-loading that can cause crashes, if these occur set slingLoad to false
-- to use the other method.
TRPS.unpackRestriction = false -- if false, you can unpack in logistic zone

TRPS.enableSmokeDrop = true -- if false, helis and c-130 will not be able to drop smoke

TRPS.maxExtractDistance = 125 -- max distance from vehicle to troops to allow a group extraction
TRPS.maximumDistanceLogistic = 200 -- max distance from vehicle to logistics to allow a loading or spawning operation 
TRPS.maximumSearchDistance = 4000 -- max distance for troops to search for enemy
TRPS.maximumMoveDistance = 2000 -- max distance for troops to move from drop point if no enemy is nearby

TRPS.minimumDeployDistance = 1000 -- minimum distance from a friendly pickup zone where you can deploy a crate

TRPS.numberOfTroops = 10 -- default number of troops to load on a transport heli or C-130 
							-- also works as maximum size of group that'll fit into a helicopter unless overridden
TRPS.enableFastRopeInsertion = true -- allows you to drop troops by fast rope
TRPS.fastRopeMaximumHeight = 18.28 -- in meters which is 60 ft max fast rope (not rappell) safe height

TRPS.vehiclesForTransportRED = { "BRDM-2", "BTR_D" } -- vehicles to load onto Il-76 - Alternatives {"Strela-1 9P31","BMP-1"}
TRPS.vehiclesForTransportBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament" } -- vehicles to load onto c130 - Alternatives {"M1128 Stryker MGS","M1097 Avenger"}

TRPS.aaLaunchers = 3 -- controls how many launchers to add to the kub/buk when its spawned.
TRPS.hawkLaunchers = 5 -- controls how many launchers to add to the hawk when its spawned.

TRPS.spawnRPGWithCoalition = true --spawns a friendly RPG unit with Coalition forces
TRPS.spawnStinger = true -- spawns a stinger / igla soldier with a group of 6 or more soldiers!

TRPS.enabledFOBBuilding = true -- if true, you can load a crate INTO a C-130 than when unpacked creates a Forward Operating Base (FOB) which is a new place to spawn (crates) and carry crates from
-- In future i'd like it to be a FARP but so far that seems impossible...
-- You can also enable troop Pickup at FOBS

TRPS.cratesRequiredForFOB = 1 -- The amount of crates required to build a FOB. Once built, helis can spawn crates at this outpost to be carried and deployed in another area.  -- MOD LTOD TEST
-- The large crates can only be loaded and dropped by large aircraft, like the C-130 and listed in TRPS.vehicleTransportEnabled
-- Small FOB crates can be moved by helicopter. The FOB will require TRPS.cratesRequiredForFOB larges crates and small crates are 1/3 of a large fob crate
-- To build the FOB entirely out of small crates you will need TRPS.cratesRequiredForFOB * 3

TRPS.troopPickupAtFOB = true -- if true, troops can also be picked up at a created FOB

TRPS.buildTimeFOB = 120 --time in seconds for the FOB to be built

TRPS.crateWaitTime = 5 -- time in seconds to wait before you can spawn another crate

TRPS.forceCrateToBeMoved = false -- a crate must be picked up at least once and moved before it can be unpacked. Helps to reduce crate spam

TRPS.radioSound = "beacon.ogg" -- the name of the sound file to use for the FOB radio beacons. If this isnt added to the mission BEACONS WONT WORK!
TRPS.radioSoundFC3 = "beaconsilent.ogg" -- name of the second silent radio file, used so FC3 aircraft dont hear ALL the beacon noises... :)

TRPS.deployedBeaconBattery = 90 -- the battery on deployed beacons will last for this number minutes before needing to be re-deployed

TRPS.enabledRadioBeaconDrop = true -- if its set to false then beacons cannot be dropped by units

TRPS.allowRandomAiTeamPickups = false -- Allows the AI to randomize the loading of infantry teams (specified below) at pickup zones

-- Simulated Sling load configuration

-- TRPS.minimumHoverHeight = 7.5 -- Lowest allowable height for crate hover
-- TRPS.maximumHoverHeight = 12.0 -- Highest allowable height for crate hover
-- TRPS.maxDistanceFromCrate = 5.5 -- Maximum distance from from crate for hover
--TRPS.hoverTime = 10 -- Time to hold hover above a crate for loading in seconds

-- end of Simulated Sling load configuration

-- AA SYSTEM CONFIG --
-- Sets a limit on the number of active AA systems that can be built for RED.
-- A system is counted as Active if its fully functional and has all parts
-- If a system is partially destroyed, it no longer counts towards the total
-- When this limit is hit, a player will still be able to get crates for an AA system, just unable
-- to unpack them

TRPS.AASystemLimitRED = 20 -- Red side limit

TRPS.AASystemLimitBLUE = 20 -- Blue side limit

--END AA SYSTEM CONFIG --

-- ***************** JTAC CONFIGURATION *****************

TRPS.laser_codes = { 1511, 1113, 1688} -- Put here the available laser codes. The first value is the default for RED and the second for BLUE
TRPS.deployedJTACs = {} --Store deployed JTAC units here
TRPS.JTACCommandMenuPath = {}

TRPS.JTAC_LIMIT_RED = 10 -- max number of JTAC Crates for the RED Side
TRPS.JTAC_LIMIT_BLUE = 10 -- max number of JTAC Crates for the BLUE Side

TRPS.JTAC_dropEnabled = true -- allow JTAC Crate spawn from F10 menu

TRPS.JTAC_maxDistance = 10000 -- How far a JTAC can "see" in meters (with Line of Sight)

TRPS.JTAC_smokeOn_RED = true -- enables marking of target with smoke for RED forces
TRPS.JTAC_smokeOn_BLUE = true -- enables marking of target with smoke for BLUE forces

TRPS.JTAC_smokeColour_RED = 4 -- RED side smoke colour -- Green = 0 , Red = 1, White = 2, Orange = 3, Blue = 4
TRPS.JTAC_smokeColour_BLUE = 1 -- BLUE side smoke colour -- Green = 0 , Red = 1, White = 2, Orange = 3, Blue = 4
TRPS.JTAC_smokeColous = {"Green", "Red", "White", "Orange", "Blue", "No smoke"}

TRPS.JTAC_jtacStatusF10 = true -- enables F10 JTAC Status menu

TRPS.JTAC_location = true -- shows location of target in JTAC message

TRPS.JTAC_lock = "all" -- "vehicle" OR "troop" OR "all" forces JTAC to only lock vehicles or troops or all ground units



--------------- CUSTOM DSMC Code // MIST DEPENDANCIES ---------------

-- from mist cloned functions
local trpsGpId 				= 57000
local trpsUnitId 			= 57000
local trpsDynAddIndex 		= {[' air '] = 0, [' hel '] = 0, [' gnd '] = 0, [' bld '] = 0, [' static '] = 0, [' shp '] = 0}
local trpsAddedObjects 		= {}  -- da mist
local trpsAddedGroups 		= {}  -- da mist


TRPS.tblObjectshapeNames = {
    ["Landmine"] = "landmine",
    ["FARP CP Blindage"] = "kp_ug",
    ["FARP Ammo Dump Coating"] = "SetkaKP",   
    ["FARP Fuel Depot"] = "GSM Rus",     
    ["FARP Tent"] = "PalatkaB",    
    ["Subsidiary structure C"] = "saray-c",
    ["Barracks 2"] = "kazarma2",
    ["Small house 2C"] = "dom2c",
    ["Military staff"] = "aviashtab",
    ["Tech hangar A"] = "ceh_ang_a",
    ["Oil derrick"] = "neftevyshka",
    ["Tech combine"] = "kombinat",
    ["Garage B"] = "garage_b",
    ["Airshow_Crowd"] = "Crowd1",
    ["Hangar A"] = "angar_a",
    ["Repair workshop"] = "tech",
    ["Subsidiary structure D"] = "saray-d",
    ["Small house 1C area"] = "dom2c-all",
    ["Tank 2"] = "airbase_tbilisi_tank_01",
    ["Boiler-house A"] = "kotelnaya_a",
    ["Workshop A"] = "tec_a",
    ["Small werehouse 1"] = "s1",
    ["Garage small B"] = "garagh-small-b",
    ["Small werehouse 4"] = "s4",
    ["Shop"] = "magazin",
    ["Subsidiary structure B"] = "saray-b",
    ["Coach cargo"] = "wagon-gruz",
    ["Electric power box"] = "tr_budka",
    ["Tank 3"] = "airbase_tbilisi_tank_02",
    ["Red_Flag"] = "H-flag_R",
    ["Container red 3"] = "konteiner_red3",
    ["Garage A"] = "garage_a",
    ["Hangar B"] = "angar_b",
    ["Black_Tyre"] = "H-tyre_B",
    ["Cafe"] = "stolovaya",
    ["Restaurant 1"] = "restoran1",
    ["Subsidiary structure A"] = "saray-a",
    ["Container white"] = "konteiner_white",
    ["Warehouse"] = "sklad",
    ["Tank"] = "bak",
    ["Railway crossing B"] = "pereezd_small",
    ["Subsidiary structure F"] = "saray-f",
    ["Farm A"] = "ferma_a",
    ["Small werehouse 3"] = "s3",
    ["Water tower A"] = "wodokachka_a",
    ["Railway station"] = "r_vok_sd",
    ["Coach a tank blue"] = "wagon-cisterna_blue",
    ["Supermarket A"] = "uniwersam_a",
    ["Coach a platform"] = "wagon-platforma",
    ["Garage small A"] = "garagh-small-a",
    ["TV tower"] = "tele_bash",
    ["Comms tower M"] = "tele_bash_m",
    ["Small house 1A"] = "domik1a",
    ["Farm B"] = "ferma_b",
    ["GeneratorF"] = "GeneratorF",
    ["Cargo1"] = "ab-212_cargo",
    ["Container red 2"] = "konteiner_red2",
    ["Subsidiary structure E"] = "saray-e",
    ["Coach a passenger"] = "wagon-pass",
    ["Black_Tyre_WF"] = "H-tyre_B_WF",
    ["Electric locomotive"] = "elektrowoz",
    ["Shelter"] = "ukrytie",
    ["Coach a tank yellow"] = "wagon-cisterna_yellow",
    ["Railway crossing A"] = "pereezd_big",
    [".Ammunition depot"] = "SkladC",
    ["Small werehouse 2"] = "s2",
    ["Windsock"] = "H-Windsock_RW",
    ["Shelter B"] = "ukrytie_b",
    ["Fuel tank"] = "toplivo-bak",
    ["Locomotive"] = "teplowoz",
    [".Command Center"] = "ComCenter",
    ["Pump station"] = "nasos",
    ["Black_Tyre_RF"] = "H-tyre_B_RF",
    ["Coach cargo open"] = "wagon-gruz-otkr",
    ["Subsidiary structure 3"] = "hozdomik3",
    ["White_Tyre"] = "H-tyre_W",
    ["Subsidiary structure G"] = "saray-g",
    ["Container red 1"] = "konteiner_red1",
    ["Small house 1B area"] = "domik1b-all",
    ["Subsidiary structure 1"] = "hozdomik1",
    ["Container brown"] = "konteiner_brown",
    ["Small house 1B"] = "domik1b",
    ["Subsidiary structure 2"] = "hozdomik2",
    ["Chemical tank A"] = "him_bak_a",
    ["WC"] = "WC",
    ["Small house 1A area"] = "domik1a-all",
    ["White_Flag"] = "H-Flag_W",
    ["Airshow_Cone"] = "Comp_cone",
}







function TRPS.zoneToVec3(zone)
    local new = {}
	if type(zone) == 'table' then
		if zone.point then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
		elseif zone.x and zone.y and zone.z then
			return zone
		end
		return new
	elseif type(zone) == 'string' then
		zone = trigger.misc.getZone(zone)
		if zone then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
			return new
		end
	end
end

function TRPS.round(num, idp)
    local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function TRPS.getPayload(unitName)
    -- refactor to search by groupId and allow groupId and groupName as inputs
	local unitTbl = Unit.getByName(unitName)
	local unitId = unitTbl:getID()
	local gpTbl = unitTbl:getGroup()
	local gpId = gpTbl:getID()

	if gpId and unitId then
		for coa_name, coa_data in pairs(env.mission.coalition) do
			if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
				if coa_data.country then --there is a country table
					for cntry_id, cntry_data in pairs(coa_data.country) do
						for obj_type_name, obj_type_data in pairs(cntry_data) do
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
									for group_num, group_data in pairs(obj_type_data.group) do
										if group_data and group_data.groupId == gpId then
											for unitIndex, unitData in pairs(group_data.units) do --group index
												if unitData.unitId == unitId then
													return unitData.payload
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		if debugProcessDetail then
			env.info(ModuleName .. " getPayload error, no gId or unitId")
		end	
		return false
	end
	return
end

function TRPS.deepCopy(object)
    local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

function TRPS.dynAdd(newGroup)
    local cntry = newGroup.country
	if newGroup.countryId then
		cntry = newGroup.countryId
	end

	local groupType = newGroup.category
	local newCountry = ''
	-- validate data
	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
	end

	if newCountry == '' then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAdd Country not found")
		end		
		return false
	end

	local newCat = ''
	for catName, catId in pairs(Unit.Category) do
		if type(groupType) == 'string' then
			if tostring(catName) == string.upper(groupType) then
				newCat = catName
			end
		elseif type(groupType) == 'number' then
			if catId == groupType then
				newCat = catName
			end
		end

		if catName == 'GROUND_UNIT' and (string.upper(groupType) == 'VEHICLE' or string.upper(groupType) == 'GROUND') then
			newCat = 'GROUND_UNIT'
		elseif catName == 'AIRPLANE' and string.upper(groupType) == 'PLANE' then
			newCat = 'AIRPLANE'
		end
	end
	local typeName
	if newCat == 'GROUND_UNIT' then
		typeName = ' gnd '
	elseif newCat == 'AIRPLANE' then
		typeName = ' air '
	elseif newCat == 'HELICOPTER' then
		typeName = ' hel '
	elseif newCat == 'SHIP' then
		typeName = ' shp '
	elseif newCat == 'BUILDING' then
		typeName = ' bld '
	end
	if newGroup.clone or not newGroup.groupId then
		trpsDynAddIndex[typeName] = trpsDynAddIndex[typeName] + 1
		trpsGpId = trpsGpId + 1
		newGroup.groupId = trpsGpId
	end
	if newGroup.groupName or newGroup.name then
		if newGroup.groupName then
			newGroup.name = newGroup.groupName
		elseif newGroup.name then
			newGroup.name = newGroup.name
		end
	end

	if newGroup.clone or not newGroup.name then
		newGroup.name = tostring(newCountry .. tostring(typeName) .. trpsDynAddIndex[typeName])
	end

	if not newGroup.hidden then
		newGroup.hidden = false
	end

	if not newGroup.visible then
		newGroup.visible = false
	end

	if (newGroup.start_time and type(newGroup.start_time) ~= 'number') or not newGroup.start_time then
		if newGroup.startTime then
			newGroup.start_time = TRPS.round(newGroup.startTime)
		else
			newGroup.start_time = 0
		end
	end

    for unitIndex, unitData in pairs(newGroup.units) do
        local originalName = newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name
        if newGroup.clone or not unitData.unitId then
            trpsUnitId = trpsUnitId + 1
            newGroup.units[unitIndex].unitId = trpsUnitId
        end
        if newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name then
            if newGroup.units[unitIndex].unitName then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].unitName
            elseif newGroup.units[unitIndex].name then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].name
            end
        end
        if newGroup.clone or not unitData.name then
            newGroup.units[unitIndex].name = tostring(newGroup.name .. ' unit' .. unitIndex)
        end

        if not unitData.skill then
            newGroup.units[unitIndex].skill = 'Random'
        end

        if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
            if newGroup.units[unitIndex].alt_type and newGroup.units[unitIndex].alt_type ~= 'BARO' or not newGroup.units[unitIndex].alt_type then
                newGroup.units[unitIndex].alt_type = 'RADIO'
            end
            if not unitData.speed then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].speed = 60
                end
            end
            if not unitData.payload then
                newGroup.units[unitIndex].payload = TRPS.getPayload(originalName)
            end
            if not unitData.alt then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].alt = 2000
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].alt = 500
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 60
                end
            end
            
        elseif newCat == 'GROUND_UNIT' then
            if nil == unitData.playerCanDrive then
                unitData.playerCanDrive = true
            end
        
        end
        trpsAddedObjects[#trpsAddedObjects + 1] = TRPS.deepCopy(newGroup.units[unitIndex])
    end


    --[[ OLD
	for unitIndex, unitData in pairs(newGroup.units) do
		local originalName = newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name
		if newGroup.clone or not unitData.unitId then
			trpsUnitId = trpsUnitId + 1
			newGroup.units[unitIndex].unitId = trpsUnitId
		end
		if newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name then
			if newGroup.units[unitIndex].unitName then
				newGroup.units[unitIndex].name = newGroup.units[unitIndex].unitName
			elseif newGroup.units[unitIndex].name then
				newGroup.units[unitIndex].name = newGroup.units[unitIndex].name
			end
		end
		if newGroup.clone or not unitData.name then
			newGroup.units[unitIndex].name = tostring(newGroup.name .. ' unit' .. unitIndex)
		end

		if not unitData.skill then
			newGroup.units[unitIndex].skill = 'Random'
		end

		if not unitData.alt then
			if newCat == 'AIRPLANE' then
				newGroup.units[unitIndex].alt = 2000
				newGroup.units[unitIndex].alt_type = 'RADIO'
				newGroup.units[unitIndex].speed = 150
			elseif newCat == 'HELICOPTER' then
				newGroup.units[unitIndex].alt = 500
				newGroup.units[unitIndex].alt_type = 'RADIO'
				newGroup.units[unitIndex].speed = 60
			end


		end

		if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
			if newGroup.units[unitIndex].alt_type and newGroup.units[unitIndex].alt_type ~= 'BARO' or not newGroup.units[unitIndex].alt_type then
				newGroup.units[unitIndex].alt_type = 'RADIO'
			end
			if not unitData.speed then
				if newCat == 'AIRPLANE' then
					newGroup.units[unitIndex].speed = 150
				elseif newCat == 'HELICOPTER' then
					newGroup.units[unitIndex].speed = 60
				end
			end
			if not unitData.payload then
				newGroup.units[unitIndex].payload = TRPS.getPayload(originalName)
			end
		end
		trpsAddedObjects[#trpsAddedObjects + 1] = TRPS.deepCopy(newGroup.units[unitIndex])
    end
    --]]--
	trpsAddedGroups[#trpsAddedGroups + 1] = TRPS.deepCopy(newGroup)
	if newGroup.route and not newGroup.route.points then
		if not newGroup.route.points and newGroup.route[1] then
			local copyRoute = newGroup.route
			newGroup.route = {}
			newGroup.route.points = copyRoute
		end
	end
	newGroup.country = newCountry

	-- sanitize table
	newGroup.groupName = nil
	newGroup.clone = nil
	newGroup.category = nil
	newGroup.country = nil

	newGroup.tasks = {}

	for unitIndex, unitData in pairs(newGroup.units) do
		newGroup.units[unitIndex].unitName = nil
	end

	coalition.addGroup(country.id[newCountry], Unit.Category[newCat], newGroup)

	return newGroup

end

function TRPS.dynAddStatic(newObj)

	if newObj.units and newObj.units[1] then 
		for entry, val in pairs(newObj.units[1]) do
			if newObj[entry] and newObj[entry] ~= val or not newObj[entry] then
				newObj[entry] = val
			end
		end
	end
	--log:info(newObj)

	local cntry = newObj.country
	if newObj.countryId then
		cntry = newObj.countryId
	end

	local newCountry = ''

	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
    end

	if newCountry == '' then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic Country not found")
		end
		return false
    end

	if newObj.clone or not newObj.groupId then
		trpsGpId = trpsGpId + 1
		newObj.groupId = trpsGpId
    end
 
	if newObj.clone or not newObj.unitId then -- 2
		trpsUnitId = trpsUnitId + 1
		newObj.unitId = trpsUnitId
	end

   -- newObj.name = newObj.unitName
	if newObj.clone or not newObj.name then
		trpsDynAddIndex[' static '] = trpsDynAddIndex[' static '] + 1
		newObj.name = (newCountry .. ' static ' .. trpsDynAddIndex[' static '])
    end

	if not newObj.dead then
		newObj.dead = false
	end

	if not newObj.heading then
		newObj.heading = math.random(360)
	end
	
	if newObj.categoryStatic then
		newObj.category = newObj.categoryStatic
	end
	if newObj.mass then
		newObj.category = 'Cargos'
	end
	
	if newObj.shapeName then
		newObj.shape_name = newObj.shapeName
    end
	if not newObj.shape_name then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic shape not found")
		end
		if TRPS.tblObjectshapeNames[newObj.type] then
			newObj.shape_name = TRPS.tblObjectshapeNames[newObj.type]
		end
    end
	
	trpsAddedObjects[#trpsAddedObjects + 1] = TRPS.deepCopy(newObj)
	if newObj.x and newObj.y and newObj.type and type(newObj.x) == 'number' and type(newObj.y) == 'number' and type(newObj.type) == 'string' then

        --log:info('addStaticObject')
		coalition.addStaticObject(country.id[newCountry], newObj)
  
		return newObj
	end
	
	if debugProcessDetail then
		env.info(ModuleName .. " dynAddStatic Failed to add static object due to missing or incorrect value")
    end	

	return false
end

function TRPS.vecmag(vec)
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end

function TRPS.vecsub(vec1, vec2)
	return {x = vec1.x - vec2.x, y = vec1.y - vec2.y, z = vec1.z - vec2.z}
end

function TRPS.vecdp(vec1, vec2)
	return vec1.x*vec2.x + vec1.y*vec2.y + vec1.z*vec2.z
end

function TRPS.getNorthCorrection(gPoint)	--gets the correction needed for true north
	local point = TRPS.deepCopy(gPoint)
	if not point.z then --Vec2; convert to Vec3
		point.z = point.y
		point.y = 0
	end
	local lat, lon = coord.LOtoLL(point)
	local north_posit = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north_posit.z - point.z, north_posit.x - point.x)
end

function TRPS.getHeading(unit, rawHeading)
	local unitpos = unit:getPosition()
	if unitpos then
		local Heading = math.atan2(unitpos.x.z, unitpos.x.x)
		if not rawHeading then
			Heading = Heading + TRPS.getNorthCorrection(unitpos.p)
		end
		if Heading < 0 then
			Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
		end
		return Heading
	end
end

function TRPS.makeVec3(vec, y)
	if not vec.z then
		if vec.alt and not y then
			y = vec.alt
		elseif not y then
			y = 0
		end
		return {x = vec.x, y = y, z = vec.y}
	else
		return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
	end
end

function TRPS.getDir(vec, point)
	local dir = math.atan2(vec.z, vec.x)
	if point then
		dir = dir + TRPS.getNorthCorrection(point)
	end
	if dir < 0 then
		dir = dir + 2 * math.pi	-- put dir in range of 0 to 2*pi
	end
	return dir
end

function TRPS.toDegree(angle)
	return angle*180/math.pi
end

function TRPS.tostringLL(lat, lon, acc, DMS)

	local latHemi, lonHemi
	if lat > 0 then
		latHemi = 'N'
	else
		latHemi = 'S'
	end

	if lon > 0 then
		lonHemi = 'E'
	else
		lonHemi = 'W'
	end

	lat = math.abs(lat)
	lon = math.abs(lon)

	local latDeg = math.floor(lat)
	local latMin = (lat - latDeg)*60

	local lonDeg = math.floor(lon)
	local lonMin = (lon - lonDeg)*60

	if DMS then	-- degrees, minutes, and seconds.
		local oldLatMin = latMin
		latMin = math.floor(latMin)
		local latSec = TRPS.round((oldLatMin - latMin)*60, acc)

		local oldLonMin = lonMin
		lonMin = math.floor(lonMin)
		local lonSec = TRPS.round((oldLonMin - lonMin)*60, acc)

		if latSec == 60 then
			latSec = 0
			latMin = latMin + 1
		end

		if lonSec == 60 then
			lonSec = 0
			lonMin = lonMin + 1
		end

		local secFrmtStr -- create the formatting string for the seconds place
		if acc <= 0 then	-- no decimal place.
			secFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			secFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi

	else	-- degrees, decimal minutes.
		latMin = TRPS.round(latMin, acc)
		lonMin = TRPS.round(lonMin, acc)

		if latMin == 60 then
			latMin = 0
			latDeg = latDeg + 1
		end

		if lonMin == 60 then
			lonMin = 0
			lonDeg = lonDeg + 1
		end

		local minFrmtStr -- create the formatting string for the minutes place
		if acc <= 0 then	-- no decimal place.
			minFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi

	end
end

function TRPS.ground_buildWP(point, overRideForm, overRideSpeed)

	local wp = {}
	wp.x = point.x

	if point.z then
		wp.y = point.z
	else
		wp.y = point.y
	end
	local form, speed

	if point.speed and not overRideSpeed then
		wp.speed = point.speed
	elseif type(overRideSpeed) == 'number' then
		wp.speed = overRideSpeed
	else
		wp.speed = TRPS.kmphToMps(20)
	end

	if point.form and not overRideForm then
		form = point.form
	else
		form = overRideForm
	end

	if not form then
		wp.action = 'Cone'
	else
		form = string.lower(form)
		if form == 'off_road' or form == 'off road' then
			wp.action = 'Off Road'
		elseif form == 'on_road' or form == 'on road' then
			wp.action = 'On Road'
		elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
			wp.action = 'Rank'
		elseif form == 'cone' then
			wp.action = 'Cone'
		elseif form == 'diamond' then
			wp.action = 'Diamond'
		elseif form == 'vee' then
			wp.action = 'Vee'
		elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
			wp.action = 'EchelonL'
		elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
			wp.action = 'EchelonR'
		else
			wp.action = 'Cone' -- if nothing matched
		end
	end

	wp.type = 'Turning Point'

	return wp

end

function TRPS.kmphToMps(kmph)
	return kmph/3.6
end

function TRPS.tostringMGRS(MGRS, acc)
	if acc == 0 then
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph
	else
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph .. ' ' .. string.format('%0' .. acc .. 'd', TRPS.round(MGRS.Easting/(10^(5-acc)), 0))
		.. ' ' .. string.format('%0' .. acc .. 'd', TRPS.round(MGRS.Northing/(10^(5-acc)), 0))
	end
end




-- ***************** Pickup, dropoff and waypoint zones *****************

-- Available colors (anything else like "none" disables smoke): "green", "red", "white", "orange", "blue", "none",

-- Use any of the predefined names or set your own ones

-- You can add number as a third option to limit the number of soldier or vehicle groups that can be loaded from a zone.
-- Dropping back a group at a limited zone will add one more to the limit

-- If a zone isn't ACTIVE then you can't pickup from that zone until the zone is activated by TRPS.activatePickupZone
-- using the Mission editor

-- You can pickup from a SHIP by adding the SHIP UNIT NAME instead of a zone name

-- Side - Controls which side can load/unload troops at the zone

-- Flag Number - Optional last field. If set the current number of groups remaining can be obtained from the flag value

--pickupZones = { "Zone name or Ship Unit Name", "smoke color", "limit (-1 unlimited)", "ACTIVE (yes/no)", "side (0 = Both sides / 1 = Red / 2 = Blue )", flag number (optional) }
TRPS.pickupZones = {
    { "pickzone1", "none", -1, "yes", 0 },
    { "pickzone2", "none", -1, "yes", 0 },
    { "pickzone3", "none", -1, "yes", 0 },
    { "pickzone4", "none", -1, "yes", 0 },
    { "pickzone5", "none", -1, "yes", 0 },
    { "pickzone6", "none", -1, "yes", 0 },
    { "pickzone7", "none", -1, "yes", 0 },
    { "pickzone8", "none", -1, "yes", 0 },
    { "pickzone9", "none", 5, "yes", 1 }, -- limits pickup zone 9 to 5 groups of soldiers or vehicles, only red can pick up
    { "pickzone10", "none", 10, "yes", 2 },  -- limits pickup zone 10 to 10 groups of soldiers or vehicles, only blue can pick up

    { "pickzone11", "blue", 20, "no", 2 },  -- limits pickup zone 11 to 20 groups of soldiers or vehicles, only blue can pick up. Zone starts inactive!
    { "pickzone12", "red", 20, "no", 1 },  -- limits pickup zone 11 to 20 groups of soldiers or vehicles, only blue can pick up. Zone starts inactive!
    { "pickzone13", "none", -1, "yes", 0 },
    { "pickzone14", "none", -1, "yes", 0 },
    { "pickzone15", "none", -1, "yes", 0 },
    { "pickzone16", "none", -1, "yes", 0 },
    { "pickzone17", "none", -1, "yes", 0 },
    { "pickzone18", "none", -1, "yes", 0 },
    { "pickzone19", "none", 5, "yes", 0 },
    { "pickzone20", "none", 10, "yes", 0, 1000 }, -- optional extra flag number to store the current number of groups available in

    { "USA Carrier", "blue", 10, "yes", 0, 1001 }, -- instead of a Zone Name you can also use the UNIT NAME of a ship
}


-- dropOffZones = {"name","smoke colour",0,side 1 = Red or 2 = Blue or 0 = Both sides}
TRPS.dropOffZones = {
    { "dropzone1", "green", 2 },
    { "dropzone2", "blue", 2 },
    { "dropzone3", "orange", 2 },
    { "dropzone4", "none", 2 },
    { "dropzone5", "none", 1 },
    { "dropzone6", "none", 1 },
    { "dropzone7", "none", 1 },
    { "dropzone8", "none", 1 },
    { "dropzone9", "none", 1 },
    { "dropzone10", "none", 1 },
}


--wpZones = { "Zone name", "smoke color",  "ACTIVE (yes/no)", "side (0 = Both sides / 1 = Red / 2 = Blue )", }
TRPS.wpZones = {
    { "wpzone1", "green","yes", 2 },
    { "wpzone2", "blue","yes", 2 },
    { "wpzone3", "orange","yes", 2 },
    { "wpzone4", "none","yes", 2 },
    { "wpzone5", "none","yes", 2 },
    { "wpzone6", "none","yes", 1 },
    { "wpzone7", "none","yes", 1 },
    { "wpzone8", "none","yes", 1 },
    { "wpzone9", "none","yes", 1 },
    { "wpzone10", "none","no", 0 }, -- Both sides as its set to 0
}


-- ******************** Transports names **********************

-- Use any of the predefined names or set your own ones
TRPS.transportPilotNames = {
    "helicargo1",
    "helicargo2",
    "helicargo3",
    "helicargo4",
    "helicargo5",
    "helicargo6",
    "helicargo7",
    "helicargo8",
    "helicargo9",
    "helicargo10",
    "helicargo11",
    "helicargo12",
    "helicargo13",
    "helicargo14",
    "helicargo15",
    "helicargo16",
    "helicargo17",
    "helicargo18",
    "helicargo19",
    "helicargo20",
    "helicargo21",
    "helicargo22",
    "helicargo23",
    "helicargo24",
    "helicargo25",
    "MEDEVAC #1",
    "MEDEVAC #2",
    "MEDEVAC #3",
    "MEDEVAC #4",
    "MEDEVAC #5",
    "MEDEVAC #6",
    "MEDEVAC #7",
    "MEDEVAC #8",
    "MEDEVAC #9",
    "MEDEVAC #10",
    "MEDEVAC #11",
    "MEDEVAC #12",
    "MEDEVAC #13",
    "MEDEVAC #14",
    "MEDEVAC #15",
    "MEDEVAC #16",
    "MEDEVAC RED #1",
    "MEDEVAC RED #2",
    "MEDEVAC RED #3",
    "MEDEVAC RED #4",
    "MEDEVAC RED #5",
    "MEDEVAC RED #6",
    "MEDEVAC RED #7",
    "MEDEVAC RED #8",
    "MEDEVAC RED #9",
    "MEDEVAC RED #10",
    "MEDEVAC RED #11",
    "MEDEVAC RED #12",
    "MEDEVAC RED #13",
    "MEDEVAC RED #14",
    "MEDEVAC RED #15",
    "MEDEVAC RED #16",
    "MEDEVAC RED #17",
    "MEDEVAC RED #18",
    "MEDEVAC RED #19",
    "MEDEVAC RED #20",
    "MEDEVAC RED #21",
    "MEDEVAC BLUE #1",
    "MEDEVAC BLUE #2",
    "MEDEVAC BLUE #3",
    "MEDEVAC BLUE #4",
    "MEDEVAC BLUE #5",
    "MEDEVAC BLUE #6",
    "MEDEVAC BLUE #7",
    "MEDEVAC BLUE #8",
    "MEDEVAC BLUE #9",
    "MEDEVAC BLUE #10",
    "MEDEVAC BLUE #11",
    "MEDEVAC BLUE #12",
    "MEDEVAC BLUE #13",
    "MEDEVAC BLUE #14",
    "MEDEVAC BLUE #15",
    "MEDEVAC BLUE #16",
    "MEDEVAC BLUE #17",
    "MEDEVAC BLUE #18",
    "MEDEVAC BLUE #19",
    "MEDEVAC BLUE #20",
    "MEDEVAC BLUE #21",

    -- *** AI transports names (different names only to ease identification in mission) ***

    -- Use any of the predefined names or set your own ones

    "transport1",
    "transport2",
    "transport3",
    "transport4",
    "transport5",
    "transport6",
    "transport7",
    "transport8",
    "transport9",
    "transport10",

    "transport11",
    "transport12",
    "transport13",
    "transport14",
    "transport15",
    "transport16",
    "transport17",
    "transport18",
    "transport19",
    "transport20",
	"transport21",
    "transport22",
    "transport23",
    "transport24",
    "transport25",
	
    "APC Mech Inf",
    "APC Mech Inf #001",
    "APC Mech Inf #002",
    "APC Mech Inf #003",
    "APC Mech Inf #004",
    "APC Mech Inf #005",
    "APC Mech Inf #006",
    "APC Mech Inf #007",
    "APC Mech Inf #008",
    "APC Mech Inf #009",
    "APC Mech Inf #010",
    "APC Mech Inf #011",
    "APC Mech Inf #012",
    "APC Mech Inf #013",
    "APC Mech Inf #014",
    "APC Mech Inf #015",
    "APC Mech Inf #016",
    "APC Mech Inf #017",
    "APC Mech Inf #018",
    "APC Mech Inf #019",
    "APC Mech Inf #020",
}





-- *************** Optional Extractable GROUPS *****************

-- Use any of the predefined names or set your own ones

TRPS.extractableGroups = {
    "extract1",
    "extract2",
    "extract3",
    "extract4",
    "extract5",
    "extract6",
    "extract7",
    "extract8",
    "extract9",
    "extract10",

    "extract11",
    "extract12",
    "extract13",
    "extract14",
    "extract15",
    "extract16",
    "extract17",
    "extract18",
    "extract19",
    "extract20",

    "extract21",
    "extract22",
    "extract23",
    "extract24",
    "extract25",
    
    "Dropped Group 1",
    "Dropped Group 2",
    "Dropped Group 3",
    "Dropped Group 4",
    "Dropped Group 5",
    "Dropped Group 6",
    "Dropped Group 7",
    "Dropped Group 8",
    "Dropped Group 9",
    "Dropped Group 10",
    
    "Dropped Group 11",
    "Dropped Group 12",
    "Dropped Group 13",
    "Dropped Group 14",
    "Dropped Group 15",
    "Dropped Group 16",
    "Dropped Group 17",
    "Dropped Group 18",
    "Dropped Group 19",
    "Dropped Group 20",
    
    "RifleSquad1",
    "RifleSquad2",
    "RifleSquad3",
    "RifleSquad4",
    "RifleSquad5",
    "RifleSquad6",
    "RifleSquad7",
    "RifleSquad8",
    "RifleSquad9",
    "RifleSquad10",
    
    "RifleSquad11",
    "RifleSquad12",
    "RifleSquad13",
    "RifleSquad14",
    "RifleSquad15",
    "RifleSquad16",
    "RifleSquad17",
    "RifleSquad18",
    "RifleSquad19",
    "RifleSquad20",
    
    "RifleSquad21",
    "RifleSquad22",
    "RifleSquad23",
    "RifleSquad24",
    "RifleSquad25",
    "RifleSquad26",
    "RifleSquad27",
    "RifleSquad28",
    "RifleSquad29",
    "RifleSquad30",
    
    "WpnsSquad1",
    "WpnsSquad2",
    "WpnsSquad3",
    "WpnsSquad4",
    "WpnsSquad5",
    "WpnsSquad6",
    "WpnsSquad7",
    "WpnsSquad8",
    "WpnsSquad9",
    "WpnsSquad10",
    
    "WpnsSquad11",
    "WpnsSquad12",
    "WpnsSquad13",
    "WpnsSquad14",
    "WpnsSquad15",
    "WpnsSquad16",
    "WpnsSquad17",
    "WpnsSquad18",
    "WpnsSquad19",
    "WpnsSquad20",

    "ReconSquad1",
    "ReconSquad2",
    "ReconSquad3",
    "ReconSquad4",
    "ReconSquad5",
    "ReconSquad6",
    "ReconSquad7",
    "ReconSquad8",
    "ReconSquad9",
    "ReconSquad10",
    
    "ReconSquad11",
    "ReconSquad12",
    "ReconSquad13",
    "ReconSquad14",
    "ReconSquad15",
    "ReconSquad16",
    "ReconSquad17",
    "ReconSquad18",
    "ReconSquad19",
    "ReconSquad20",
    
    "MortarSquad1",
    "MortarSquad2",
    "MortarSquad3",
    "MortarSquad4",
    "MortarSquad5",
    "MortarSquad6",
    "MortarSquad7",
    "MortarSquad8",
    "MortarSquad9",
    "MortarSquad10",
    
    "Inf Rifle Squad",
    "Inf Rifle Squad #001",
    "Inf Rifle Squad #002",
    "Inf Rifle Squad #003",
    "Inf Rifle Squad #004",
    "Inf Rifle Squad #005",
    "Inf Rifle Squad #006",
    "Inf Rifle Squad #007",
    "Inf Rifle Squad #008",
    "Inf Rifle Squad #009",
    "Inf Rifle Squad #010",
    "Inf Rifle Squad #011",
    "Inf Rifle Squad #012",
    "Inf Rifle Squad #013",
    "Inf Rifle Squad #014",
    "Inf Rifle Squad #015",
    "Inf Rifle Squad #016",
    "Inf Rifle Squad #017",
    "Inf Rifle Squad #018",
    "Inf Rifle Squad #019",
    "Inf Rifle Squad #020",

    -- "holder",
    -- "holder #001",
    -- "holder #002",
    -- "holder #003",
    -- "holder #004",
    -- "holder #005",
    -- "holder #006",
    -- "holder #007",
    -- "holder #008",
    -- "holder #009",
    -- "holder #010",
    -- "holder #011",
    -- "holder #012",
    -- "holder #013",
    -- "holder #014",
    -- "holder #015",
    -- "holder #016",
    -- "holder #017",
    -- "holder #018",
    -- "holder #019",
    -- "holder #020",
}

-- ************** Logistics UNITS FOR CRATE SPAWNING ******************

-- Use any of the predefined names or set your own ones
-- When a logistic unit is destroyed, you will no longer be able to spawn crates

TRPS.logisticUnits = {
    "logistic1",
    "logistic2",
    "logistic3",
    "logistic4",
    "logistic5",
    "logistic6",
    "logistic7",
    "logistic8",
    "logistic9",
    "logistic10",
}

-- ************** UNITS ABLE TO TRANSPORT VEHICLES ******************
-- Add the model name of the unit that you want to be able to transport and deploy vehicles
-- units db has all the names or you can extract a mission.miz file by making it a zip and looking
-- in the contained mission file
TRPS.vehicleTransportEnabled = {
    "76MD", -- the il-76 mod doesnt use a normal - sign so il-76md wont match... !!!! GRR
    "C-130",
}


-- ************** Maximum Units SETUP for UNITS ******************

-- Put the name of the Unit you want to limit group sizes too
-- i.e
-- ["UH-1H"] = 10,
--
-- Will limit UH1 to only transport groups with a size 10 or less
-- Make sure the unit name is exactly right or it wont work

TRPS.unitLoadLimits = {

    -- Remove the -- below to turn on options
	["UH-1H"] = 10,
    ["Mi-8MTV2"] = 20, -- check if ok
	["SA342Mistral"] = 4,
    ["SA342L"] = 4,
    ["SA342M"] = 4,
	["SA342Minigun"] = 4,
	["Ka-50"] = 0,

}


-- ************** Allowable actions for UNIT TYPES ******************

-- Put the name of the Unit you want to limit actions for
-- NOTE - the unit must've been listed in the transportPilotNames list above
-- This can be used in conjunction with the options above for group sizes
-- By default you can load both crates and troops unless overriden below
-- i.e
-- ["UH-1H"] = {crates=true, troops=false},
--
-- Will limit UH1 to only transport CRATES but NOT TROOPS
--
-- ["SA342Mistral"] = {crates=false, troops=true},
-- Will allow Mistral Gazelle to only transport crates, not troops

TRPS.unitActions = {

    -- Remove the -- below to turn on options
    --["SA342Mistral"] = {crates=true, troops=true},
    --["SA342L"] = {crates=false, troops=true},
    --["SA342M"] = {crates=false, troops=true},
    ["Ka-50"] = {crates=true, troops=false},

}

-- ************** INFANTRY GROUPS FOR PICKUP ******************
-- Unit Types
-- inf is normal infantry
-- mg is M249
-- at is RPG-16
-- aa is Stinger or Igla
-- mortar is a 2B11 mortar unit
-- You must add a name to the group for it to work
-- You can also add an optional coalition side to limit the group to one side
-- for the side - 2 is BLUE and 1 is RED
TRPS.loadableGroups = {
    {name = "Standard Group", inf = 6, mg = 2, at = 2 }, -- will make a loadable group with 5 infantry, 2 MGs and 2 anti-tank for both coalitions
    {name = "Anti Air", inf = 2, aa = 3  },
    {name = "Anti Tank", inf = 2, at = 6  },
    {name = "Mortar Squad", mortar = 6 },
    -- {name = "Mortar Squad Red", inf = 2, mortar = 5, side =1 }, --would make a group loadable by RED only
}

-- ************** SPAWNABLE CRATES ******************
-- Weights must be unique as we use the weight to change the cargo to the correct unit
-- when we unpack
--
TRPS.spawnableCrates = {
    -- name of the sub menu on F10 for spawning crates
    ["Ground Forces"] = {
        --crates you can spawn
        -- weight in KG
        -- Desc is the description on the F10 MENU
        -- unit is the model name of the unit to spawn
        -- cratesRequired - if set requires that many crates of the same type within 100m of each other in order build the unit
        -- side is optional but 2 is BLUE and 1 is RED
        -- dont use that option with the HAWK Crates
        { weight = 500, desc = "HMMWV - TOW", unit = "M1045 HMMWV TOW", side = 2 },
        { weight = 505, desc = "HMMWV - MG", unit = "M1043 HMMWV Armament", side = 2 },

        { weight = 510, desc = "BTR-D", unit = "BTR_D", side = 1 },
        { weight = 515, desc = "BRDM-2", unit = "BRDM-2", side = 1 },

        { weight = 520, desc = "Soldier - JTAC", unit = "Soldier stinger", side = 2, }, -- used as jtac and unarmed, not on the crate list if JTAC is disabled    -- "HMMWV - JTAC", unit = "Hummer", side = 2, 
        { weight = 525, desc = "Infantry - JTAC", unit = "Igla manpad INS", side = 1, }, -- used as jtac and unarmed, not on the crate list if JTAC is disabled

        { weight = 100, desc = "2B11 Mortar", unit = "2B11 mortar" },

        { weight = 250, desc = "SPH 2S19 Msta", unit = "SAU Msta", side = 1, cratesRequired = 3 },
        { weight = 255, desc = "M-109", unit = "M-109", side = 2, cratesRequired = 3 },

        { weight = 252, desc = "Ural-375 Ammo Truck", unit = "Ural-375", side = 1, cratesRequired = 2 },
        { weight = 253, desc = "M-818 Ammo Truck", unit = "M 818", side = 2, cratesRequired = 2 },

        { weight = 800, desc = "FOB Crate - Small", unit = "FOB-SMALL" }, -- Builds a FOB! - requires 3 * TRPS.cratesRequiredForFOB
    },
    ["FARP Support"] = {
        { weight = 280, desc = "SKP Command", unit = "SKP-11", side = 1},
        { weight = 282, desc = "Ural Ammo", unit = "Ural-4320T", side = 1},
        { weight = 284, desc = "Zil Electricity", unit = "ZiL-131 APA-80", side = 1},
        { weight = 286, desc = "ATZ Fuel", unit = "ATZ-10", side = 1},
        
        { weight = 281, desc = "HMMWV Command", unit = "Hummer", side = 2},
        { weight = 283, desc = "M818 Ammo", unit = "M 818", side = 2},
        -- { weight = 285, desc = "M818 Electricity", unit = "M 818", side = 2},
        { weight = 287, desc = "HEMTT Fuel", unit = "M978 HEMTT Tanker", side = 2},
    },
    ["AA Crates"] = {
        { weight = 50, desc = "Stinger", unit = "Stinger manpad", side = 2 },
        { weight = 55, desc = "Igla", unit = "SA-18 Igla manpad", side = 1 },

        -- HAWK System
        { weight = 540, desc = "HAWK Launcher", unit = "Hawk ln", side = 2},
        { weight = 545, desc = "HAWK Search Radar", unit = "Hawk sr", side = 2 },
        { weight = 550, desc = "HAWK Track Radar", unit = "Hawk tr", side = 2 },
        { weight = 551, desc = "HAWK PCP", unit = "Hawk pcp" , side = 2 }, -- Remove this if on 1.2
        { weight = 552, desc = "HAWK Repair", unit = "HAWK Repair" , side = 2 },
        -- End of HAWK

        -- KUB SYSTEM
        { weight = 560, desc = "KUB Launcher", unit = "Kub 2P25 ln", side = 1},
        { weight = 565, desc = "KUB Radar", unit = "Kub 1S91 str", side = 1 },
        { weight = 570, desc = "KUB Repair", unit = "KUB Repair", side = 1},
        -- End of KUB

        -- BUK System
        --        { weight = 575, desc = "BUK Launcher", unit = "SA-11 Buk LN 9A310M1"},
        --        { weight = 580, desc = "BUK Search Radar", unit = "SA-11 Buk SR 9S18M1"},
        --        { weight = 585, desc = "BUK CC Radar", unit = "SA-11 Buk CC 9S470M1"},
        --        { weight = 590, desc = "BUK Repair", unit = "BUK Repair"},
        -- END of BUK

        { weight = 595, desc = "Early Warning Radar", unit = "1L13 EWR", side = 1 }, -- cant be used by BLUE coalition

        { weight = 405, desc = "Strela-1 9P31", unit = "Strela-1 9P31", side = 1, cratesRequired = 3 },
        { weight = 400, desc = "M1097 Avenger", unit = "M1097 Avenger", side = 2, cratesRequired = 3 },

    },
}

-- if the unit is on this list, it will be made into a JTAC when deployed
TRPS.jtacUnitTypes = {
    "Igla manpad INS", "Soldier stinger" -- there are some wierd encoding issues so if you write SKP-11 it wont match as the - sign is encoded differently...
}


TRPS.nextUnitId = 1;
TRPS.getNextUnitId = function()
    TRPS.nextUnitId = TRPS.nextUnitId + 1

    return TRPS.nextUnitId
end

TRPS.nextGroupId = 1;

TRPS.getNextGroupId = function()
    TRPS.nextGroupId = TRPS.nextGroupId + 1

    return TRPS.nextGroupId
end

-- ***************************************************************
-- **************** Mission Editor Functions *********************
-- ***************************************************************


-----------------------------------------------------------------
-- Spawn group at a trigger and set them as extractable. Usage:
-- TRPS.spawnGroupAtTrigger("groupside", number, "triggerName", radius)
-- Variables:
-- "groupSide" = "red" for Russia "blue" for USA
-- _number = number of groups to spawn OR Group description
-- "triggerName" = trigger name in mission editor between commas
-- _searchRadius = random distance for units to move from spawn zone (0 will leave troops at the spawn position - no search for enemy)
--
-- Example: TRPS.spawnGroupAtTrigger("red", 2, "spawn1", 1000)
--
-- This example will spawn 2 groups of russians at the specified point
-- and they will search for enemy or move randomly withing 1000m
-- OR
--
-- TRPS.spawnGroupAtTrigger("blue", {mg=1,at=2,aa=3,inf=4,mortar=5},"spawn2", 2000)
-- Spawns 1 machine gun, 2 anti tank, 3 anti air, 4 standard soldiers and 5 mortars
--
function TRPS.spawnGroupAtTrigger(_groupSide, _number, _triggerName, _searchRadius)
    local _spawnTrigger = trigger.misc.getZone(_triggerName) -- trigger to use as reference position

    if _spawnTrigger == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find trigger called " .. _triggerName, 10)
        return
    end

    local _country
    if _groupSide == "red" then
        _groupSide = 1
        _country = 0
    elseif _groupSide == "blue" then
        _groupSide = 2
        _country = 2
    else
        _groupSide = 0
        _country = 0       
    end

    if _searchRadius < 0 then
        _searchRadius = 0
    end

    local _pos2 = { x = _spawnTrigger.point.x, y = _spawnTrigger.point.z }
    local _alt = land.getHeight(_pos2)
    local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

    local _groupDetails = TRPS.generateTroopTypes(_groupSide, _number, _country)

    local _droppedTroops = TRPS.spawnDroppedGroup(_pos3, _groupDetails, false, _searchRadius);

    if _groupSide == 1 then
        table.insert(TRPS.droppedTroopsRED, _droppedTroops:getName())
    elseif _groupSide == 2 then
        table.insert(TRPS.droppedTroopsBLUE, _droppedTroops:getName())
    else 
        table.insert(TRPS.droppedTroopsNEUTRAL, _droppedTroops:getName())
    end
end


-----------------------------------------------------------------
-- Spawn group at a Vec3 Point and set them as extractable. Usage:
-- TRPS.spawnGroupAtPoint("groupside", number,Vec3 Point, radius)
-- Variables:
-- "groupSide" = "red" for Russia "blue" for USA
-- _number = number of groups to spawn OR Group Description
-- Vec3 Point = A vec3 point like {x=1,y=2,z=3}. Can be obtained from a unit like so: Unit.getName("Unit1"):getPoint()
-- _searchRadius = random distance for units to move from spawn zone (0 will leave troops at the spawn position - no search for enemy)
--
-- Example: TRPS.spawnGroupAtPoint("red", 2, {x=1,y=2,z=3}, 1000)
--
-- This example will spawn 2 groups of russians at the specified point
-- and they will search for enemy or move randomly withing 1000m
-- OR
--
-- TRPS.spawnGroupAtPoint("blue", {mg=1,at=2,aa=3,inf=4,mortar=5}, {x=1,y=2,z=3}, 2000)
-- Spawns 1 machine gun, 2 anti tank, 3 anti air, 4 standard soldiers and 5 mortars
function TRPS.spawnGroupAtPoint(_groupSide, _number, _point, _searchRadius)

    local _country
    if _groupSide == "red" then
        _groupSide = 1
        _country = 0
    elseif _groupSide == "blue" then
        _groupSide = 2
        _country = 2
    else
        _groupSide = 0
        _country = 0       
    end

    if _searchRadius < 0 then
        _searchRadius = 0
    end

    local _groupDetails = TRPS.generateTroopTypes(_groupSide, _number, _country)

    local _droppedTroops = TRPS.spawnDroppedGroup(_point, _groupDetails, false, _searchRadius);

    if _groupSide == 1 then
        table.insert(TRPS.droppedTroopsRED, _droppedTroops:getName())
    elseif _groupSide == 2 then
        table.insert(TRPS.droppedTroopsBLUE, _droppedTroops:getName())
    else 
        table.insert(TRPS.droppedTroopsNEUTRAL, _droppedTroops:getName())
    end
end


-- Preloads a transport with troops or vehicles
-- replaces any troops currently on board
function TRPS.preLoadTransport(_unitName, _number, _troops)

    local _unit = TRPS.getTransportUnit(_unitName)

    if _unit ~= nil then

        -- will replace any units currently on board
        --        if not TRPS.troopsOnboard(_unit,_troops)  then
        TRPS.loadTroops(_unit, _troops, _number)
        --        end
    end
end


-- Continuously counts the number of crates in a zone and sets the value of the passed in flag
-- to the count amount
-- This means you can trigger actions based on the count and also trigger messages before the count is reached
-- Just pass in the zone name and flag number like so as a single (NOT Continuous) Trigger
-- This will now work for Mission Editor and Spawned Crates
-- e.g. TRPS.cratesInZone("DropZone1", 5)
function TRPS.cratesInZone(_zone, _flagNumber)
    local _triggerZone = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _zonePos = TRPS.zoneToVec3(_zone)

    --ignore side, if crate has been used its discounted from the count
    local _crateTables = { TRPS.spawnedCratesRED, TRPS.spawnedCratesBLUE, TRPS.spawnedCratesNEUTRAL, TRPS.missionEditorCargoCrates }

    local _crateCount = 0

    for _, _crates in pairs(_crateTables) do

        for _crateName, _dontUse in pairs(_crates) do

            --get crate
            local _crate = TRPS.getCrateObject(_crateName)

            --in air seems buggy with crates so if in air is true, get the height above ground and the speed magnitude
            if _crate ~= nil and _crate:getLife() > 0
                    and (TRPS.inAir(_crate) == false) then

                local _dist = TRPS.getDistance(_crate:getPoint(), _zonePos)

                if _dist <= _triggerZone.radius then
                    _crateCount = _crateCount + 1
                end
            end
        end
    end

    --set flag stuff
    trigger.action.setUserFlag(_flagNumber, _crateCount)

    -- env.info("FLAG ".._flagNumber.." crates ".._crateCount)

    --retrigger in 5 seconds
    timer.scheduleFunction(function(_args)

        TRPS.cratesInZone(_args[1], _args[2])
    end, { _zone, _flagNumber }, timer.getTime() + 5)
end

-- Creates an extraction zone
-- any Soldiers (not vehicles) dropped at this zone by a helicopter will disappear
-- and be added to a running total of soldiers for a set flag number
-- The idea is you can then drop say 20 troops in a zone and trigger an action using the mission editor triggers
-- and the flag value
--
-- The TRPS.createExtractZone function needs to be called once in a trigger action do script.
-- if you dont want smoke, pass -1 to the function.
--Green = 0 , Red = 1, White = 2, Orange = 3, Blue = 4, NO SMOKE = -1
--
-- e.g. TRPS.createExtractZone("extractzone1", 2, -1) will create an extraction zone at trigger zone "extractzone1", store the number of troops dropped at
-- the zone in flag 2 and not have smoke
--
--
--
function TRPS.createExtractZone(_zone, _flagNumber, _smoke)
    local _triggerZone = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _pos2 = { x = _triggerZone.point.x, y = _triggerZone.point.z }
    local _alt = land.getHeight(_pos2)
    local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

    trigger.action.setUserFlag(_flagNumber, 0) --start at 0

    local _details = { point = _pos3, name = _zone, smoke = _smoke, flag = _flagNumber, radius = _triggerZone.radius}

    TRPS.extractZones[_zone.."-".._flagNumber] =  _details

    if _smoke ~= nil and _smoke > -1 then

        local _smokeFunction

        _smokeFunction = function(_args)

            local _extractDetails = TRPS.extractZones[_zone.."-".._flagNumber]
            -- check zone is still active
            if _extractDetails == nil then
                -- stop refreshing smoke, zone is done
                return
            end


            trigger.action.smoke(_args.point, _args.smoke)
            --refresh in 5 minutes
            timer.scheduleFunction(_smokeFunction, _args, timer.getTime() + 300)
        end

        --run local function
        _smokeFunction(_details)
    end
end


-- Removes an extraction zone
--
-- The smoke will take up to 5 minutes to disappear depending on the last time the smoke was activated
--
-- The TRPS.removeExtractZone function needs to be called once in a trigger action do script.
--
-- e.g. TRPS.removeExtractZone("extractzone1", 2) will remove an extraction zone at trigger zone "extractzone1"
-- that was setup with flag 2
--
--
--
function TRPS.removeExtractZone(_zone,_flagNumber)

    local _extractDetails = TRPS.extractZones[_zone.."-".._flagNumber]

    if _extractDetails ~= nil then
        --remove zone
        TRPS.extractZones[_zone.."-".._flagNumber] = nil

    end
end

-- CONTINUOUS TRIGGER FUNCTION
-- This function will count the current number of extractable RED and BLUE
-- GROUPS in a zone and store the values in two flags
-- A group is only counted as being in a zone when the leader of that group
-- is in the zone
-- Use: TRPS.countDroppedGroupsInZone("Zone Name", flagBlue, flagRed)
function TRPS.countDroppedGroupsInZone(_zone, _blueFlag, _redFlag)

    local _triggerZone = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _zonePos = TRPS.zoneToVec3(_zone)

    local _redCount = 0;
    local _blueCount = 0;

    local _allGroups = {TRPS.droppedTroopsRED,TRPS.droppedTroopsBLUE,TRPS.droppedTroopsNEUTRAL,TRPS.droppedVehiclesRED,TRPS.droppedVehiclesBLUE,TRPS.droppedVehiclesNEUTRAL}
    for _, _extractGroups in pairs(_allGroups) do
        for _,_groupName  in pairs(_extractGroups) do
            local _groupUnits = TRPS.getGroup(_groupName)

            if #_groupUnits > 0 then
                local _zonePos =TRPS.zoneToVec3(_zone)
                local _dist = TRPS.getDistance(_groupUnits[1]:getPoint(), _zonePos)

                if _dist <= _triggerZone.radius then

                    if (_groupUnits[1]:getCoalition() == 1) then
                        _redCount = _redCount + 1;
                    else
                        _blueCount = _blueCount + 1;
                    end
                end
            end
        end
    end
    --set flag stuff
    trigger.action.setUserFlag(_blueFlag, _blueCount)
    trigger.action.setUserFlag(_redFlag, _redCount)

    --  env.info("Groups in zone ".._blueCount.." ".._redCount)

end

-- CONTINUOUS TRIGGER FUNCTION
-- This function will count the current number of extractable RED and BLUE
-- UNITS in a zone and store the values in two flags

-- Use: TRPS.countDroppedUnitsInZone("Zone Name", flagBlue, flagRed)
function TRPS.countDroppedUnitsInZone(_zone, _blueFlag, _redFlag)

    local _triggerZone = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _zonePos = TRPS.zoneToVec3(_zone)

    local _redCount = 0;
    local _blueCount = 0;

    local _allGroups = {TRPS.droppedTroopsRED,TRPS.droppedTroopsBLUE,TRPS.droppedTroopsNEUTRAL,TRPS.droppedVehiclesRED,TRPS.droppedVehiclesBLUE,TRPS.droppedVehiclesNEUTRAL}

    for _, _extractGroups in pairs(_allGroups) do
        for _,_groupName  in pairs(_extractGroups) do
            local _groupUnits = TRPS.getGroup(_groupName)

            if #_groupUnits > 0 then

                local _zonePos = TRPS.zoneToVec3(_zone)
                for _,_unit in pairs(_groupUnits) do
                    local _dist = TRPS.getDistance(_unit:getPoint(), _zonePos)

                    if _dist <= _triggerZone.radius then

                        if (_unit:getCoalition() == 1) then
                            _redCount = _redCount + 1;
                        else
                            _blueCount = _blueCount + 1;
                        end
                    end
                end
            end
        end
    end


    --set flag stuff
    trigger.action.setUserFlag(_blueFlag, _blueCount)
    trigger.action.setUserFlag(_redFlag, _redCount)

    --  env.info("Units in zone ".._blueCount.." ".._redCount)
end


-- Creates a radio beacon on a random UHF - VHF and HF/FM frequency for homing
-- This WILL NOT WORK if you dont add beacon.ogg and beaconsilent.ogg to the mission!!!
-- e.g. TRPS.createRadioBeaconAtZone("beaconZone","red", 1440,"Waypoint 1") will create a beacon at trigger zone "beaconZone" for the Red side
-- that will last 1440 minutes (24 hours ) and named "Waypoint 1" in the list of radio beacons
--
-- e.g. TRPS.createRadioBeaconAtZone("beaconZoneBlue","blue", 20) will create a beacon at trigger zone "beaconZoneBlue" for the Blue side
-- that will last 20 minutes
function TRPS.createRadioBeaconAtZone(_zone, _coalition, _batteryLife, _name)
    local _triggerZone = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _zonePos = TRPS.zoneToVec3(_zone)

    TRPS.beaconCount = TRPS.beaconCount + 1

    if _name == nil or _name == "" then
        _name = "Beacon #" .. TRPS.beaconCount
    end

    if _coalition == "red" then
        TRPS.createRadioBeacon(_zonePos, 1, 0, _name, _batteryLife) --1440
    else
        TRPS.createRadioBeacon(_zonePos, 2, 2, _name, _batteryLife) --1440
    end
end


-- Activates a pickup zone
-- Activates a pickup zone when called from a trigger
-- EG: TRPS.activatePickupZone("pickzone3")
-- This is enable pickzone3 to be used as a pickup zone for the team set
function TRPS.activatePickupZone(_zoneName)
    local _triggerZone = trigger.misc.getZone(_zoneName) -- trigger to use as reference position

    if _triggerZone == nil then
        local _ship = TRPS.getTransportUnit(_triggerZone)

        if _ship then
            local _point = _ship:getPoint()
            _triggerZone = {}
            _triggerZone.point = _point
        end

    end

    if _triggerZone == nil  then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone or ship called " .. _zoneName, 10)

    end

    for _, _zoneDetails in pairs(TRPS.pickupZones) do

        if _zoneName == _zoneDetails[1] then

            --smoke could get messy if designer keeps calling this on an active zone, check its not active first
            if _zoneDetails[4] == 1 then
                -- they might have a continuous trigger so i've hidden the warning
                --trigger.action.outText("TRPS.lua ERROR: Pickup Zone already active: " .. _zoneName, 10)
                return
            end

            _zoneDetails[4] = 1 --activate zone

            if TRPS.disableAllSmoke == true then --smoke disabled
            return
            end

            if _zoneDetails[2] >= 0 then

                -- Trigger smoke marker
                -- This will cause an overlapping smoke marker on next refreshsmoke call
                -- but will only happen once
                local _pos2 = { x = _triggerZone.point.x, y = _triggerZone.point.z }
                local _alt = land.getHeight(_pos2)
                local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

                trigger.action.smoke(_pos3, _zoneDetails[2])
            end
        end
    end
end


-- Deactivates a pickup zone
-- Deactivates a pickup zone when called from a trigger
-- EG: TRPS.deactivatePickupZone("pickzone3")
-- This is disables pickzone3 and can no longer be used to as a pickup zone
-- These functions can be called by triggers, like if a set of buildings is used, you can trigger the zone to be 'not operational'
-- once they are destroyed
function TRPS.deactivatePickupZone(_zoneName)

    local _triggerZone = trigger.misc.getZone(_zoneName) -- trigger to use as reference position

    if _triggerZone == nil then
        local _ship = TRPS.getTransportUnit(_triggerZone)

        if _ship then
            local _point = _ship:getPoint()
            _triggerZone = {}
            _triggerZone.point = _point
        end

    end

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zoneName, 10)
        return
    end

    for _, _zoneDetails in pairs(TRPS.pickupZones) do

        if _zoneName == _zoneDetails[1] then

            -- i'd just ignore it if its already been deactivated
            --            if _zoneDetails[4] == 0 then --this really needed??
            --            trigger.action.outText("TRPS.lua ERROR: Pickup Zone already deactiveated: " .. _zoneName, 10)
            --            return
            --            end

            _zoneDetails[4] = 0 --deactivate zone
        end
    end
end

-- Change the remaining groups currently available for pickup at a zone
-- e.g. TRPS.changeRemainingGroupsForPickupZone("pickup1", 5) -- adds 5 groups
-- TRPS.changeRemainingGroupsForPickupZone("pickup1", -3) -- remove 3 groups
function TRPS.changeRemainingGroupsForPickupZone(_zoneName, _amount)
    local _triggerZone = trigger.misc.getZone(_zoneName) -- trigger to use as reference position

    if _triggerZone == nil then
        local _ship = TRPS.getTransportUnit(_triggerZone)

        if _ship then
            local _point = _ship:getPoint()
            _triggerZone = {}
            _triggerZone.point = _point
        end

    end

    if _triggerZone == nil  then
        trigger.action.outText("TRPS.lua TRPS.changeRemainingGroupsForPickupZone ERROR: Cant find zone called " .. _zoneName, 10)
        return
    end

    for _, _zoneDetails in pairs(TRPS.pickupZones) do

        if _zoneName == _zoneDetails[1] then
            TRPS.updateZoneCounter(_zoneName, _amount)
        end
    end


end

-- Activates a Waypoint zone
-- Activates a Waypoint zone when called from a trigger
-- EG: TRPS.activateWaypointZone("pickzone3")
-- This means that troops dropped within the radius of the zone will head to the center
-- of the zone instead of searching for troops
function TRPS.activateWaypointZone(_zoneName)
    local _triggerZone = trigger.misc.getZone(_zoneName) -- trigger to use as reference position


    if _triggerZone == nil  then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone  called " .. _zoneName, 10)

        return
    end

    for _, _zoneDetails in pairs(TRPS.wpZones) do

        if _zoneName == _zoneDetails[1] then

            --smoke could get messy if designer keeps calling this on an active zone, check its not active first
            if _zoneDetails[3] == 1 then
                -- they might have a continuous trigger so i've hidden the warning
                --trigger.action.outText("TRPS.lua ERROR: Pickup Zone already active: " .. _zoneName, 10)
                return
            end

            _zoneDetails[3] = 1 --activate zone

            if TRPS.disableAllSmoke == true then --smoke disabled
            return
            end

            if _zoneDetails[2] >= 0 then

                -- Trigger smoke marker
                -- This will cause an overlapping smoke marker on next refreshsmoke call
                -- but will only happen once
                local _pos2 = { x = _triggerZone.point.x, y = _triggerZone.point.z }
                local _alt = land.getHeight(_pos2)
                local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

                trigger.action.smoke(_pos3, _zoneDetails[2])
            end
        end
    end
end


-- Deactivates a Waypoint zone
-- Deactivates a Waypoint zone when called from a trigger
-- EG: TRPS.deactivateWaypointZone("wpzone3")
-- This  disables wpzone3 so that troops dropped in this zone will search for troops as normal
-- These functions can be called by triggers
function TRPS.deactivateWaypointZone(_zoneName)

    local _triggerZone = trigger.misc.getZone(_zoneName)

    if _triggerZone == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zoneName, 10)
        return
    end

    for _, _zoneDetails in pairs(TRPS.pickupZones) do

        if _zoneName == _zoneDetails[1] then

            _zoneDetails[3] = 0 --deactivate zone
        end
    end
end

-- Continuous Trigger Function
-- Causes an AI unit with the specified name to unload troops / vehicles when
-- an enemy is detected within a specified distance
-- The enemy must have Line or Sight to the unit to be detected
function TRPS.unloadInProximityToEnemy(_unitName,_distance)

    local _unit = TRPS.getTransportUnit(_unitName)

    if _unit ~= nil and _unit:getPlayerName() == nil then

        -- no player name means AI!
        -- the findNearest visible enemy you'd want to modify as it'll find enemies quite far away
        -- limited by  TRPS.JTAC_maxDistance
        local _nearestEnemy = TRPS.findNearestVisibleEnemy(_unit,"all",_distance)

        if _nearestEnemy ~= nil then

            if TRPS.troopsOnboard(_unit, true) then
                TRPS.deployTroops(_unit, true)
                return true
            end

            if TRPS.unitCanCarryVehicles(_unit) and TRPS.troopsOnboard(_unit, false) then
                TRPS.deployTroops(_unit, false)
                return true
            end
        end
    end

    return false

end



-- Unit will unload any units onboard if the unit is on the ground
-- when this function is called
function TRPS.unloadTransport(_unitName)

    local _unit = TRPS.getTransportUnit(_unitName)

    if _unit ~= nil  then

        if TRPS.troopsOnboard(_unit, true) then
            TRPS.unloadTroops({_unitName,true})
        end

        if TRPS.unitCanCarryVehicles(_unit) and TRPS.troopsOnboard(_unit, false) then
            TRPS.unloadTroops({_unitName,false})
        end
    end

end

-- Loads Troops and Vehicles from a zone or picks up nearby troops or vehicles
function TRPS.loadTransport(_unitName)

    local _unit = TRPS.getTransportUnit(_unitName)

    if _unit ~= nil  then

        TRPS.loadTroopsFromZone({ _unitName, true,"",true })

        if TRPS.unitCanCarryVehicles(_unit)  then
            TRPS.loadTroopsFromZone({ _unitName, false,"",true })
        end

    end

end

-- adds a callback that will be called for many actions ingame
function TRPS.addCallback(_callback)

    table.insert(TRPS.callbacks,_callback)

end

-- Spawns a sling loadable crate at a Trigger Zone
--
-- Weights can be found in the TRPS.spawnableCrates list
-- e.g. TRPS.spawnCrateAtZone("red", 500,"triggerzone1") -- spawn a humvee at triggerzone 1 for red side
-- e.g. TRPS.spawnCrateAtZone("blue", 505,"triggerzone1") -- spawn a tow humvee at triggerzone1 for blue side
--
function TRPS.spawnCrateAtZone(_side, _weight,_zone)
    local _spawnTrigger = trigger.misc.getZone(_zone) -- trigger to use as reference position

    if _spawnTrigger == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find zone called " .. _zone, 10)
        return
    end

    local _crateType = TRPS.crateLookupTable[tostring(_weight)]

    if _crateType == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find crate with weight " .. _weight, 10)
        return
    end

    local _country
    if _side == "red" then
        _side = 1
        _country = 0
    else
        _side = 2
        _country = 2
    end

    local _pos2 = { x = _spawnTrigger.point.x, y = _spawnTrigger.point.z }
    local _alt = land.getHeight(_pos2)
    local _point = { x = _pos2.x, y = _alt, z = _pos2.y }

    local _unitId = TRPS.getNextUnitId()

    local _name = string.format("%s #%i", _crateType.desc, _unitId)

    local _spawnedCrate = TRPS.spawnCrateStatic(_country, _unitId, _point, _name, _crateType.weight,_side)

end

-- Spawns a sling loadable crate at a Point
--
-- Weights can be found in the TRPS.spawnableCrates list
-- Points can be made by hand or obtained from a Unit position by Unit.getByName("PilotName"):getPoint()
-- e.g. TRPS.spawnCrateAtZone("red", 500,{x=1,y=2,z=3}) -- spawn a humvee at triggerzone 1 for red side at a specified point
-- e.g. TRPS.spawnCrateAtZone("blue", 505,{x=1,y=2,z=3}) -- spawn a tow humvee at triggerzone1 for blue side at a specified point
--
--
function TRPS.spawnCrateAtPoint(_side, _weight,_point)


    local _crateType = TRPS.crateLookupTable[tostring(_weight)]

    if _crateType == nil then
        trigger.action.outText("TRPS.lua ERROR: Cant find crate with weight " .. _weight, 10)
        return
    end

    local _country
    if _side == "red" then
        _side = 1
        _country = 0
    else
        _side = 2
        _country = 2
    end

    local _unitId = TRPS.getNextUnitId()

    local _name = string.format("%s #%i", _crateType.desc, _unitId)

    local _spawnedCrate = TRPS.spawnCrateStatic(_country, _unitId, _point, _name, _crateType.weight,_side)

end

-- ***************************************************************
-- **************** BE CAREFUL BELOW HERE ************************
-- ***************************************************************

--- Tells TRPS What multipart AA Systems there are and what parts they need
-- A New system added here also needs the launcher added
TRPS.AASystemTemplate = {

    {
        name = "HAWK AA System",
        count = 4,
        parts = {
            {name = "Hawk ln", desc = "HAWK Launcher", launcher = true},
            {name = "Hawk tr", desc = "HAWK Track Radar"},
            {name = "Hawk sr", desc = "HAWK Search Radar"},
            {name = "Hawk pcp", desc = "HAWK PCP"},
        },
        repair = "HAWK Repair",
    },
    {
        name = "BUK AA System",
        count = 3,
        parts = {
            {name = "SA-11 Buk LN 9A310M1", desc = "BUK Launcher" , launcher = true},
            {name = "SA-11 Buk CC 9S470M1", desc = "BUK CC Radar"},
            {name = "SA-11 Buk SR 9S18M1", desc = "BUK Search Radar"},
        },
        repair = "BUK Repair",
    },
    {
        name = "KUB AA System",
        count = 2,
        parts = {
            {name = "Kub 2P25 ln", desc = "KUB Launcher", launcher = true},
            {name = "Kub 1S91 str", desc = "KUB Radar"},
        },
        repair = "KUB Repair",
    },
}

TRPS.FARPsupportTemplate = {
    {
        name = "FARP_red",
        count = 4,
        parts = {
            {name = "SKP-11", desc = "SKP Command"},
            {name = "Ural-4320T", desc = "Ural Ammo"},
            {name = "ATZ-10", desc = "ATZ Fuel"},
            {name = "ZiL-131 APA-80", desc = "Zil Electricity"},
        },
    },
    {
        name = "FARP_blue",
        count = 3,
        parts = {
            {name = "Hummer", desc = "HMMWV Command"},
            {name = "M 818", desc = "M818 Ammo"},
            {name = "M978 HEMTT Tanker", desc = "HEMTT Fuel"},
            -- {name = "M 818", desc = "M818 Electricity"},
        },
    },    
}

TRPS.crateWait = {}
TRPS.crateMove = {}

---------------- INTERNAL FUNCTIONS ----------------
function TRPS.getTransportUnit(_unitName)

    if _unitName == nil then
        return nil
    end

    local _heli = Unit.getByName(_unitName)

    if _heli ~= nil and _heli:isActive() and _heli:getLife() > 0 then

        return _heli
    end

    return nil
end

function TRPS.spawnCrateStatic(_country, _unitId, _point, _name, _weight,_side)

    local _crate
    local _spawnedCrate

    if TRPS.staticBugWorkaround and TRPS.slingLoad == false then
        local _groupId = TRPS.getNextGroupId()
        local _groupName = "Crate Group #".._groupId

        local _group = {
            ["visible"] = false,
           -- ["groupId"] = _groupId,
            ["hidden"] = false,
            ["units"] = {},
            --        ["y"] = _positions[1].z,
            --        ["x"] = _positions[1].x,
            ["name"] = _groupName,
            ["task"] = {},
        }

        _group.units[1] = TRPS.createUnit(_point.x , _point.z , 0, {type="UAZ-469",name=_name,unitId=_unitId})

        _group.category = Group.Category.GROUND;
        _group.country = _country;

        local _spawnedGroup = Group.getByName(TRPS.dynAdd(_group).name)

        -- Turn off AI
        trigger.action.setGroupAIOff(_spawnedGroup)

        _spawnedCrate = Unit.getByName(_name)
    else

        if TRPS.slingLoad then
            _crate = {
                ["category"] = "Cargos", --now plurar
                ["shape_name"] = "bw_container_cargo", --new slingloadable container
                ["type"] = "container_cargo", --new type
               -- ["unitId"] = _unitId,
                ["y"] = _point.z,
                ["x"] = _point.x,
                ["mass"] = _weight,
                ["name"] = _name,
                ["canCargo"] = true,
                ["heading"] = 0,
                ["effectTransparency"] = 1,
                ["effectPreset"] = "1",
                ["rate"] = 100,                
                --            ["displayName"] = "name 2", -- getCargoDisplayName function exists but no way to set the variable
                --            ["DisplayName"] = "name 2",
                --            ["cargoDisplayName"] = "cargo123",
                --            ["CargoDisplayName"] = "cargo123",
            }
        
--[[ Placeholder for different type of cargo containers. Let's say pipes and trunks, fuel for FOB building
                        ["shape_name"] = "ab-212_cargo",
			["type"] = "uh1h_cargo" --new type for the container previously used
			
			["shape_name"] = "ammo_box_cargo",
                        ["type"] = "ammo_cargo",
			
			["shape_name"] = "barrels_cargo",
                        ["type"] = "barrels_cargo",

                        ["shape_name"] = "bw_container_cargo",
                        ["type"] = "container_cargo",
			
                        ["shape_name"] = "f_bar_cargo",
                        ["type"] = "f_bar_cargo",
			
			["shape_name"] = "fueltank_cargo",
                        ["type"] = "fueltank_cargo",
			
			["shape_name"] = "iso_container_cargo",
			["type"] = "iso_container",
			
			["shape_name"] = "iso_container_small_cargo",
			["type"] = "iso_container_small",
			
			["shape_name"] = "oiltank_cargo",
                        ["type"] = "oiltank_cargo",
                        
			["shape_name"] = "pipes_big_cargo",
                        ["type"] = "pipes_big_cargo",			
			
			["shape_name"] = "pipes_small_cargo",
			["type"] = "pipes_small_cargo",
			
			["shape_name"] = "tetrapod_cargo",
			["type"] = "tetrapod_cargo",
			
			["shape_name"] = "trunks_long_cargo",
			["type"] = "trunks_long_cargo",
			
			["shape_name"] = "trunks_small_cargo",
			["type"] = "trunks_small_cargo",
]]--
	    else	
			_crate = {
                ["category"] = "Cargos", --now plurar
                ["shape_name"] = "bw_container_cargo", --new slingloadable container
                ["type"] = "container_cargo", --new type
               -- ["unitId"] = _unitId,
                ["y"] = _point.z,
                ["x"] = _point.x,
                ["mass"] = _weight,
                ["name"] = _name,
                ["canCargo"] = true,
                ["heading"] = 0,
                ["effectTransparency"] = 1,
                ["effectPreset"] = "1",
                ["rate"] = 100,
				}
        --[[    _crate = {
                ["shape_name"] = "GeneratorF",
                ["type"] = "GeneratorF",
             --   ["unitId"] = _unitId,
                ["y"] = _point.z,
                ["x"] = _point.x,
                ["name"] = _name,
                ["category"] = "Fortifications",
                ["canCargo"] = false,
                ["heading"] = 0,
            }
			]]--
        end

        _crate["country"] = _country
        TRPS.dynAddStatic(_crate)
        _spawnedCrate = StaticObject.getByName(_crate["name"])
    end


    local _crateType = TRPS.crateLookupTable[tostring(_weight)]

    if _side == 1 then
        TRPS.spawnedCratesRED[_name] =_crateType
    elseif _side == 2 then
        TRPS.spawnedCratesBLUE[_name] = _crateType
    else
        TRPS.spawnedCratesNEUTRAL[_name] = _crateType
    end

    return _spawnedCrate
end

function TRPS.spawnFOBCrateStatic(_country, _unitId, _point, _name)

    local _crate = {
        ["category"] = "Fortifications",
        ["shape_name"] = "konteiner_red1",
        ["type"] = "Container red 1",
     --   ["unitId"] = _unitId,
        ["y"] = _point.z,
        ["x"] = _point.x,
        ["name"] = _name,
        ["canCargo"] = false,
        ["heading"] = 0,
    }

    _crate["country"] = _country

    TRPS.dynAddStatic(_crate)

    local _spawnedCrate = StaticObject.getByName(_crate["name"])
    --local _spawnedCrate = coalition.addStaticObject(_country, _crate)

    return _spawnedCrate
end


function TRPS.spawnFOB(_country, _unitId, _point, _name)

    local _crate = {
        ["category"] = "Fortifications",
        ["type"] = "outpost",
      --  ["unitId"] = _unitId,
        ["y"] = _point.z,
        ["x"] = _point.x,
        ["name"] = _name,
        ["canCargo"] = false,
        ["heading"] = 0,
    }

    _crate["country"] = _country
    TRPS.dynAddStatic(_crate)

    local _spawnedCrate = StaticObject.getByName(_crate["name"])
    --local _spawnedCrate = coalition.addStaticObject(_country, _crate)

    local _id = TRPS.getNextUnitId()

    local _tower = {
        ["type"] = "house2arm",
     --   ["unitId"] = _id,
        ["rate"] = 100,
        ["y"] = _point.z + -36.57142857,
        ["x"] = _point.x + 14.85714286,
        ["name"] = "FOB Watchtower #" .. _id,
        ["category"] = "Fortifications",
        ["canCargo"] = false,
        ["heading"] = 0,
    }
    --coalition.addStaticObject(_country, _tower)
    _tower["country"] = _country

    TRPS.dynAddStatic(_tower)


    local _id = TRPS.getNextUnitId()

    --[[
    local _farp = {
        ["type"] = "FARP",
     --   ["unitId"] = _id,
        ["y"] = _point.z + 150,
        ["x"] = _point.x + 150,
        ["name"] = "FOB FARP #" .. _id,
        ["category"] = "Heliports",
        ["heliport_modulation"] = 0,
        ["heliport_frequency"] = 127.5,
        ["heliport_callsign_id"] = 1,
    }
    --coalition.addStaticObject(_country, _tower)
    _farp["country"] = _country

    TRPS.dynAddStatic(_farp)
    ]]--

    return _spawnedCrate
end


function TRPS.spawnCrate(_arguments)

    local _status, _err = pcall(function(_args)

        -- use the cargo weight to guess the type of unit as no way to add description :(

        local _crateType = TRPS.crateLookupTable[tostring(_args[2])]
        local _heli = TRPS.getTransportUnit(_args[1])

        if _crateType ~= nil and _heli ~= nil and TRPS.inAir(_heli) == false then

            if TRPS.inLogisticsZone(_heli) == false then

                TRPS.displayMessageToGroup(_heli, "You are not close enough to friendly logistics to get a crate!", 10)

                return
            end

            if TRPS.isJTACUnitType(_crateType.unit) then

                local _limitHit = false

                if _heli:getCoalition() == 1 then

                    if TRPS.JTAC_LIMIT_RED == 0 then
                        _limitHit = true
                    else
                        TRPS.JTAC_LIMIT_RED = TRPS.JTAC_LIMIT_RED - 1
                    end
                else
                    if TRPS.JTAC_LIMIT_BLUE == 0 then
                        _limitHit = true
                    else
                        TRPS.JTAC_LIMIT_BLUE = TRPS.JTAC_LIMIT_BLUE - 1
                    end
                end

                if _limitHit then
                    TRPS.displayMessageToGroup(_heli, "No more JTAC Crates Left!", 10)
                    return
                end
            end

            local _position = _heli:getPosition()

            -- check crate spam
            if _heli:getPlayerName() ~= nil and TRPS.crateWait[_heli:getPlayerName()] and  TRPS.crateWait[_heli:getPlayerName()] > timer.getTime() then

                TRPS.displayMessageToGroup(_heli,"Sorry you must wait "..(TRPS.crateWait[_heli:getPlayerName()]  - timer.getTime()).. " seconds before you can get another crate", 20)
                return
            end

            if _heli:getPlayerName() ~= nil then
                TRPS.crateWait[_heli:getPlayerName()] = timer.getTime() + TRPS.crateWaitTime
            end
                --   trigger.action.outText("Spawn Crate".._args[1].." ".._args[2],10)

            local _heli = TRPS.getTransportUnit(_args[1])

            local _point = TRPS.getPointAt12Oclock(_heli, 30)

            local _unitId = TRPS.getNextUnitId()

            local _side = _heli:getCoalition()

            local _name = string.format("%s #%i", _crateType.desc, _unitId)

            local _spawnedCrate = TRPS.spawnCrateStatic(_heli:getCountry(), _unitId, _point, _name, _crateType.weight,_side)

            -- add to move table
            TRPS.crateMove[_name] = _name

            TRPS.displayMessageToGroup(_heli, string.format("A %s crate weighing %s kg has been brought out and is at your 12 o'clock ", _crateType.desc, _crateType.weight), 20)

        else
            env.info("Couldn't find crate item to spawn")
        end
    end, _arguments)

    if (not _status) then
        env.error(string.format("TRPS ERROR: %s", _err))
    end
end

function TRPS.getPointAt12Oclock(_unit, _offset)

    local _position = _unit:getPosition()
    local _angle = math.atan2(_position.x.z, _position.x.x)
    local _xOffset = math.cos(_angle) * _offset
    local _yOffset = math.sin(_angle) * _offset

    local _point = _unit:getPoint()
    return { x = _point.x + _xOffset, z = _point.z + _yOffset, y = _point.y }
end

function TRPS.troopsOnboard(_heli, _troops)

    if TRPS.inTransitTroops[_heli:getName()] ~= nil then

        local _onboard = TRPS.inTransitTroops[_heli:getName()]

        if _troops then

            if _onboard.troops ~= nil and _onboard.troops.units ~= nil and #_onboard.troops.units > 0 then
                return true
            else
                return false
            end
        else

            if _onboard.vehicles ~= nil and _onboard.vehicles.units ~= nil and #_onboard.vehicles.units > 0 then
                return true
            else
                return false
            end
        end

    else
        return false
    end
end

-- if its dropped by AI then there is no player name so return the type of unit
function TRPS.getPlayerNameOrType(_heli)

    if _heli:getPlayerName() == nil then

        return _heli:getTypeName()
    else
        return _heli:getPlayerName()
    end
end

function TRPS.inExtractZone(_heli)

    local _heliPoint = _heli:getPoint()

    for _, _zoneDetails in pairs(TRPS.extractZones) do

        --get distance to center
        local _dist = TRPS.getDistance(_heliPoint, _zoneDetails.point)

        if _dist <= _zoneDetails.radius then
            return _zoneDetails
        end
    end

    return false
end

-- safe to fast rope if speed is less than 0.5 Meters per second
function TRPS.safeToFastRope(_heli)

    if TRPS.enableFastRopeInsertion == false then
        return false
    end

    --landed or speed is less than 8 km/h and height is less than fast rope height
    if (TRPS.inAir(_heli) == false or (TRPS.heightDiff(_heli) <= TRPS.fastRopeMaximumHeight + 3.0 and TRPS.vecmag(_heli:getVelocity()) < 2.2)) then
        return true
    end
end

function TRPS.metersToFeet(_meters)

    local _feet = _meters * 3.2808399

    return TRPS.round(_feet)
end

function TRPS.inAir(_heli)

    if _heli:inAir() == false then
        return false
    end

    -- less than 5 cm/s a second so landed
    -- BUT AI can hold a perfect hover so ignore AI
    if TRPS.vecmag(_heli:getVelocity()) < 0.05 and _heli:getPlayerName() ~= nil then
        return false
    end
    return true
end

function TRPS.deployTroops(_heli, _troops)

    local _onboard = TRPS.inTransitTroops[_heli:getName()]

    -- deloy troops
    if _troops then
        if _onboard.troops ~= nil and #_onboard.troops.units > 0 then
            if TRPS.inAir(_heli) == false or TRPS.safeToFastRope(_heli) then

                -- check we're not in extract zone
                local _extractZone = TRPS.inExtractZone(_heli)

                if _extractZone == false then

                    local _droppedTroops = TRPS.spawnDroppedGroup(_heli:getPoint(), _onboard.troops, false)

                    if _heli:getCoalition() == 1 then

                        table.insert(TRPS.droppedTroopsRED, _droppedTroops:getName())
                    elseif _heli:getCoalition() == 2 then

                        table.insert(TRPS.droppedTroopsBLUE, _droppedTroops:getName())

                    else
                        
                        table.insert(TRPS.droppedTroopsNEUTRAL, _droppedTroops:getName())
                    end

                    TRPS.inTransitTroops[_heli:getName()].troops = nil
					
					local _weightkg = TRPS.checkInternalWeight(_heli)
					local _weightlbs = math.floor(_weightkg * 2.20462)
					trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
					TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					
                    if TRPS.inAir(_heli) then
                        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " troops fast-ropped from " .. _heli:getTypeName() .. " into combat", 10)
                    else
                        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " troops dropped from " .. _heli:getTypeName() .. " into combat", 10)
                    end

                    TRPS.processCallback({unit = _heli, unloaded = _droppedTroops, action = "dropped_troops"})
	

                else
                    --extract zone!
                    local _droppedCount = trigger.misc.getUserFlag(_extractZone.flag)

                    _droppedCount = (#_onboard.troops.units) + _droppedCount

                    trigger.action.setUserFlag(_extractZone.flag, _droppedCount)

                    TRPS.inTransitTroops[_heli:getName()].troops = nil
					
					local _weightkg = TRPS.checkInternalWeight(_heli)
					local _weightlbs = math.floor(_weightkg * 2.20462)
					trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
					TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					  
                    if TRPS.inAir(_heli) then
                        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " troops fast-ropped from " .. _heli:getTypeName() .. " into " .. _extractZone.name, 10)
                    else
                        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " troops dropped from " .. _heli:getTypeName() .. " into " .. _extractZone.name, 10)
                    end
                end
            else
                TRPS.displayMessageToGroup(_heli, "Too high or too fast to drop troops into combat! Hover below " .. TRPS.metersToFeet(TRPS.fastRopeMaximumHeight) .. " feet or land.", 10)
            end
        end

    else
        if TRPS.inAir(_heli) == false then
            if _onboard.vehicles ~= nil and #_onboard.vehicles.units > 0 then

                local _droppedVehicles = TRPS.spawnDroppedGroup(_heli:getPoint(), _onboard.vehicles, true)

                if _heli:getCoalition() == 1 then

                    table.insert(TRPS.droppedVehiclesRED, _droppedVehicles:getName())
                elseif _heli:getCoalition() == 2 then
                
                    table.insert(TRPS.droppedVehiclesBLUE, _droppedVehicles:getName())
                
                else



                    table.insert(TRPS.droppedVehiclesNEUTRAL, _droppedVehicles:getName())
                end

                TRPS.inTransitTroops[_heli:getName()].vehicles = nil

                TRPS.processCallback({unit = _heli, unloaded = _droppedVehicles, action = "dropped_vehicles"})
				
				local _weightkg = TRPS.checkInternalWeight(_heli)
				local _weightlbs = math.floor(_weightkg * 2.20462)
				trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
				TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					
                trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " dropped vehicles from " .. _heli:getTypeName() .. " into combat", 10)
            end
        end
    end

end

function TRPS.insertIntoTroopsArray(_troopType,_count,_troopArray)

    for _i = 1, _count do
        local _unitId = TRPS.getNextUnitId()
        table.insert(_troopArray, { type = _troopType, unitId = _unitId, name = string.format("Dropped %s #%i", _troopType, _unitId) })
    end

    return _troopArray

end


function TRPS.generateTroopTypes(_side, _countOrTemplate, _country)

    local _troops = {}

    if type(_countOrTemplate) == "table" then

        if _countOrTemplate.aa then
            if _side == 2 then
                _troops = TRPS.insertIntoTroopsArray("Stinger manpad",_countOrTemplate.aa,_troops)
            else
                _troops = TRPS.insertIntoTroopsArray("SA-18 Igla manpad",_countOrTemplate.aa,_troops)
            end
        end

        if _countOrTemplate.inf then
            if _side == 2 then
                _troops = TRPS.insertIntoTroopsArray("Soldier M4",_countOrTemplate.inf,_troops)
            else
                _troops = TRPS.insertIntoTroopsArray("Soldier AK",_countOrTemplate.inf,_troops)
            end
        end

        if _countOrTemplate.mg then
            _troops = TRPS.insertIntoTroopsArray("Soldier M249",_countOrTemplate.mg,_troops)
        end

        if _countOrTemplate.at then
            _troops = TRPS.insertIntoTroopsArray("Paratrooper RPG-16",_countOrTemplate.at,_troops)
        end

        if _countOrTemplate.mortar then
            _troops = TRPS.insertIntoTroopsArray("2B11 mortar",_countOrTemplate.mortar,_troops)
        end

    else
        for _i = 1, _countOrTemplate do

            local _unitType = "Soldier AK"

            if _side == 2 then
                _unitType = "Soldier M4"

                if _i <= 5 and TRPS.spawnStinger then
                    _unitType = "Stinger manpad"
                end
                if _i <= 4 and TRPS.spawnRPGWithCoalition then
                    _unitType = "Paratrooper RPG-16"
                end
                if _i <= 2 then
                    _unitType = "Soldier M249"
                end
            else
                _unitType = "Infantry AK"
                if _i <= 5 and TRPS.spawnStinger then
                    _unitType = "SA-18 Igla manpad"
                end
                if _i <= 4 then
                    _unitType = "Paratrooper RPG-16"
                end
                if _i <= 2 then
                    _unitType = "Paratrooper AKS-74"
                end
            end

            local _unitId = TRPS.getNextUnitId()

            _troops[_i] = { type = _unitType, unitId = _unitId, name = string.format("Dropped %s #%i", _unitType, _unitId) }
        end
    end

    local _groupId = TRPS.getNextGroupId()
    local _details = { units = _troops, groupId = _groupId, groupName = string.format("Dropped Group %i", _groupId), side = _side, country = _country }

    return _details
end

--Special F10 function for players for troops
function TRPS.unloadExtractTroops(_args)

    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then
        return false
    end


    local _extract = nil
    if not TRPS.inAir(_heli) then
        if _heli:getCoalition() == 1 then
            _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsRED)
        elseif _heli:getCoalition() == 2 then
            _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsBLUE)
        else
            _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsNEUTRAL)
        end

    end

    if _extract ~= nil and not TRPS.troopsOnboard(_heli, true) then
        -- search for nearest troops to pickup
        return TRPS.extractTroops({_heli:getName(), true})
    else
        return TRPS.unloadTroops({_heli:getName(),true,true})
    end


end

-- load troops onto vehicle
function TRPS.loadTroops(_heli, _troops, _numberOrTemplate)

    -- load troops + vehicles if c130 or herc
    -- "M1045 HMMWV TOW"
    -- "M1043 HMMWV Armament"
    local _onboard = TRPS.inTransitTroops[_heli:getName()]

    --number doesnt apply to vehicles
    if _numberOrTemplate == nil  or (type(_numberOrTemplate) ~= "table" and type(_numberOrTemplate) ~= "number")  then
        _numberOrTemplate = TRPS.numberOfTroops
    end

    if _onboard == nil then
        _onboard = { troops = {}, vehicles = {} }
    end

    local _list
    if _heli:getCoalition() == 1 then
        _list = TRPS.vehiclesForTransportRED
    else
        _list = TRPS.vehiclesForTransportBLUE
    end

    if _troops then

        _onboard.troops = TRPS.generateTroopTypes(_heli:getCoalition(), _numberOrTemplate, _heli:getCountry())

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " loaded troops into " .. _heli:getTypeName(), 10)

        TRPS.processCallback({unit = _heli, onboard = _onboard.troops, action = "load_troops"})	
		
    else

        _onboard.vehicles = TRPS.generateVehiclesForTransport(_heli:getCoalition(), _heli:getCountry())

        local _count = #_list
        TRPS.processCallback({unit = _heli, onboard = _onboard.vehicles, action = "load_vehicles"})
        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " loaded " .. _count .. " vehicles into " .. _heli:getTypeName(), 10)
    end

    TRPS.inTransitTroops[_heli:getName()] = _onboard
	
	local _weightkg = TRPS.checkInternalWeight(_heli)
	local _weightlbs = math.floor(_weightkg * 2.20462)
	trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
	TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
	
end

function TRPS.generateVehiclesForTransport(_side, _country)

    local _vehicles = {}
    local _list
    if _side == 1 then
        _list = TRPS.vehiclesForTransportRED
    else
        _list = TRPS.vehiclesForTransportBLUE
    end


    for _i, _type in ipairs(_list) do

        local _unitId = TRPS.getNextUnitId()

        _vehicles[_i] = { type = _type, unitId = _unitId, name = string.format("Dropped %s #%i", _type, _unitId) }
    end


    local _groupId = TRPS.getNextGroupId()
    local _details = { units = _vehicles, groupId = _groupId, groupName = string.format("Dropped Group %i", _groupId), side = _side, country = _country }

    return _details
end

function TRPS.loadUnloadFOBCrate(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return
    end

    if TRPS.inAir(_heli) == true then
        return
    end


    local _side = _heli:getCoalition()

    local _inZone = TRPS.inLogisticsZone(_heli)
    local _crateOnboard = TRPS.inTransitFOBCrates[_heli:getName()] ~= nil

    if _inZone == false and _crateOnboard == true then

        TRPS.inTransitFOBCrates[_heli:getName()] = nil

        local _position = _heli:getPosition()

        --try to spawn at 6 oclock to us
        local _angle = math.atan2(_position.x.z, _position.x.x)
        local _xOffset = math.cos(_angle) * -60
        local _yOffset = math.sin(_angle) * -60

        local _point = _heli:getPoint()

        local _side = _heli:getCoalition()

        local _unitId = TRPS.getNextUnitId()

        local _name = string.format("FOB Crate #%i", _unitId)

        local _spawnedCrate = TRPS.spawnFOBCrateStatic(_heli:getCountry(), TRPS.getNextUnitId(), { x = _point.x + _xOffset, z = _point.z + _yOffset }, _name)

        if _side == 1 then
            TRPS.droppedFOBCratesRED[_name] = _name
        elseif _side == 2 then
            TRPS.droppedFOBCratesBLUE[_name] = _name
        else
            TRPS.droppedFOBCratesNEUTRAL[_name] = _name
        end
        
        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " delivered a FOB Crate", 10)
		
		local _weightkg = TRPS.checkInternalWeight(_heli)
		local _weightlbs = math.floor(_weightkg * 2.20462)
		trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
		TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					
        TRPS.displayMessageToGroup(_heli, "Delivered FOB Crate 60m at 6'oclock to you", 10)

    elseif _inZone == true and _crateOnboard == true then

        TRPS.displayMessageToGroup(_heli, "FOB Crate dropped back to base", 10)
		
        TRPS.inTransitFOBCrates[_heli:getName()] = nil
		
		local _weightkg = TRPS.checkInternalWeight(_heli)
		local _weightlbs = math.floor(_weightkg * 2.20462)
		trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg ) 
        TRPS.displayMessageToGroup(_heli, "FOB Crate Loaded", 10)

        TRPS.inTransitFOBCrates[_heli:getName()] = true
        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " loaded a FOB Crate ready for delivery!", 10)
		
		local _weightkg = TRPS.checkInternalWeight(_heli)
		local _weightlbs = math.floor(_weightkg * 2.20462)
		trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
		TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
		
    else

        -- nearest Crate
        local _crates = TRPS.getCratesAndDistance(_heli)
        local _nearestCrate = TRPS.getClosestCrate(_heli, _crates, "FOB")

        if _nearestCrate ~= nil and _nearestCrate.dist < 150 then

            TRPS.displayMessageToGroup(_heli, "FOB Crate Loaded", 10)
            TRPS.inTransitFOBCrates[_heli:getName()] = true
            trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " loaded a FOB Crate ready for delivery!", 10)
			
			local _weightkg = TRPS.checkInternalWeight(_heli)
			local _weightlbs = math.floor(_weightkg * 2.20462)
			trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
			TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					
            if _side == 1 then
                TRPS.droppedFOBCratesRED[_nearestCrate.crateUnit:getName()] = nil
            elseif _side == 2 then
                TRPS.droppedFOBCratesBLUE[_nearestCrate.crateUnit:getName()] = nil
            else
                TRPS.droppedFOBCratesNEUTRAL[_nearestCrate.crateUnit:getName()] = nil
            end

            --remove
            _nearestCrate.crateUnit:destroy()

        else
            TRPS.displayMessageToGroup(_heli, "There are no friendly logistic units nearby to load a FOB crate from!", 10)
        end
    end
end

function TRPS.loadTroopsFromZone(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _troops = _args[2]
    local _groupTemplate = _args[3] or ""
    local _allowExtract = _args[4]

    if _heli == nil then
        return false
    end

    local _zone = TRPS.inPickupZone(_heli)

    if TRPS.troopsOnboard(_heli, _troops) then

        if _troops then
            TRPS.displayMessageToGroup(_heli, "You already have troops onboard.", 10)
        else
            TRPS.displayMessageToGroup(_heli, "You already have vehicles onboard.", 10)
        end

        return false
    end

    local _extract

    if _allowExtract then
        -- first check for extractable troops regardless of if we're in a zone or not
        if _troops then
            if _heli:getCoalition() == 1 then
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsRED)
            elseif _heli:getCoalition() == 2 then
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsBLUE)
            else
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsNEUTRAL)
            end
                 
        else

            if _heli:getCoalition() == 1 then
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesRED)
            elseif _heli:getCoalition() == 21 then
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesBLUE)
            else
                _extract = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesNEUTRAL)
            end
        end
    end

    if _extract ~= nil then
        -- search for nearest troops to pickup
        return TRPS.extractTroops({_heli:getName(), _troops})
    elseif _zone.inZone == true then

        if _zone.limit - 1 >= 0 then
            -- decrease zone counter by 1
            TRPS.updateZoneCounter(_zone.index, -1)

            TRPS.loadTroops(_heli, _troops,_groupTemplate)

            return true
        else
            TRPS.displayMessageToGroup(_heli, "This area has no more reinforcements available!", 20)

            return false
        end

    else
        if _allowExtract then
            TRPS.displayMessageToGroup(_heli, "You are not in a pickup zone and no one is nearby to extract", 10)
        else
            TRPS.displayMessageToGroup(_heli, "You are not in a pickup zone", 10)
        end

        return false
    end
end



function TRPS.unloadTroops(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return false
    end

    local _zone = TRPS.inPickupZone(_heli)
    if not TRPS.troopsOnboard(_heli, _troops)  then

        TRPS.displayMessageToGroup(_heli, "No one to unload", 10)

        return false
    else

        -- troops must be onboard to get here
        if _zone.inZone == true  then

            if _troops then
                TRPS.displayMessageToGroup(_heli, "Dropped troops back to base", 20)

                TRPS.processCallback({unit = _heli, unloaded = TRPS.inTransitTroops[_heli:getName()].troops, action = "unload_troops_zone"})

                TRPS.inTransitTroops[_heli:getName()].troops = nil
				
				local _weightkg = TRPS.checkInternalWeight(_heli)
				local _weightlbs = math.floor(_weightkg * 2.20462)
				trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
				TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)

            else
                TRPS.displayMessageToGroup(_heli, "Dropped vehicles back to base", 20)

                TRPS.processCallback({unit = _heli, unloaded = TRPS.inTransitTroops[_heli:getName()].vehicles, action = "unload_vehicles_zone"})

                TRPS.inTransitTroops[_heli:getName()].vehicles = nil
				
				local _weightkg = TRPS.checkInternalWeight(_heli)
				local _weightlbs = math.floor(_weightkg * 2.20462)
				trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
				TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
				
            end

            -- increase zone counter by 1
            TRPS.updateZoneCounter(_zone.index, 1)

            return true

        elseif _zone.inZone == false and TRPS.troopsOnboard(_heli, _troops)  then

            return TRPS.deployTroops(_heli, _troops)
        end
    end

end

function TRPS.extractTroops(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _heli == nil then
        return false
    end

    if TRPS.inAir(_heli) then
        return false
    end

    if  TRPS.troopsOnboard(_heli, _troops)  then
        if _troops then
            TRPS.displayMessageToGroup(_heli, "You already have troops onboard.", 10)
        else
            TRPS.displayMessageToGroup(_heli, "You already have vehicles onboard.", 10)
        end

        return false
    end

    local _onboard = TRPS.inTransitTroops[_heli:getName()]

    if _onboard == nil then
        _onboard = { troops = nil, vehicles = nil }
    end

    local _extracted = false

    if _troops then

        local _extractTroops

        if _heli:getCoalition() == 1 then
            _extractTroops = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsRED)
        else
            _extractTroops = TRPS.findNearestGroup(_heli, TRPS.droppedTroopsBLUE)
        end


        if _extractTroops ~= nil then

            local _limit = TRPS.getTransportLimit(_heli:getTypeName())

            local _size =  #_extractTroops.group:getUnits()

            if _limit < #_extractTroops.group:getUnits() then

                TRPS.displayMessageToGroup(_heli, "Sorry - The group of ".._size.." is too large to fit. \n\nLimit is ".._limit.." for ".._heli:getTypeName(), 20)

                return
            end


            _onboard.troops = _extractTroops.details

            trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " extracted troops in " .. _heli:getTypeName() .. " from combat", 10)

            if _heli:getCoalition() == 1 then
                TRPS.droppedTroopsRED[_extractTroops.group:getName()] = nil
            elseif _heli:getCoalition() == 2 then
                TRPS.droppedTroopsBLUE[_extractTroops.group:getName()] = nil
            else
                TRPS.droppedTroopsNEUTRAL[_extractTroops.group:getName()] = nil
            end
       
		
			-- local _heliName = _heli:getName()
			-- if _heliName then
				-- local number = #_extractTroops.group:getUnits()
				-- if number then
					-- local weight = TRPS.soldierWeight * number
					-- --CARGOWEIGHT adjust here
					-- trigger.action.setUnitInternalCargo(_heliName, weight)
					-- env.info(ModuleName .. " extractTroops set cargo " .. tostring(weight) .. " kg")
					-- local _weightkg = TRPS.checkInternalWeight(_heli)
					-- local _weightlbs = math.floor(_weightkg * 2.20462)
					-- trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
					-- TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
				-- else
					-- env.info(ModuleName .. " extractTroops no unit number for cargo")				
				-- end
			-- end	

            TRPS.processCallback({unit = _heli, extracted = _extractTroops, action = "extract_troops"})

            --remove
            _extractTroops.group:destroy()

            _extracted = true
        else
            _onboard.troops = nil
            TRPS.displayMessageToGroup(_heli, "No extractable troops nearby!", 20)
        end

    else

        local _extractVehicles


        if _heli:getCoalition() == 1 then

            _extractVehicles = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesRED)
        elseif _heli:getCoalition() == 1 then

            _extractVehicles = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesBLUE)
        else
        
            _extractVehicles = TRPS.findNearestGroup(_heli, TRPS.droppedVehiclesNEUTRAL)
        
        end

        if _extractVehicles ~= nil then
            _onboard.vehicles = _extractVehicles.details

            if _heli:getCoalition() == 1 then

                TRPS.droppedVehiclesRED[_extractVehicles.group:getName()] = nil
            elseif _heli:getCoalition() == 2 then

                TRPS.droppedVehiclesBLUE[_extractVehicles.group:getName()] = nil
            else
            
                TRPS.droppedVehiclesNEUTRAL[_extractVehicles.group:getName()] = nil
            end

            trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " extracted vehicles in " .. _heli:getTypeName() .. " from combat", 10)

            TRPS.processCallback({unit = _heli, extracted = _extractVehicles, action = "extract_vehicles"})
            --remove
            _extractVehicles.group:destroy()
            _extracted = true

        else
            _onboard.vehicles = nil
            TRPS.displayMessageToGroup(_heli, "No extractable vehicles nearby!", 20)
        end
    end

    TRPS.inTransitTroops[_heli:getName()] = _onboard
	
	local _weightkg = TRPS.checkInternalWeight(_heli)
	local _weightlbs = math.floor(_weightkg * 2.20462)
	trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
	TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)

    return _extracted
end


function TRPS.checkTroopStatus(_args)

    --list onboard troops, if c130
    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then
        return
    end

    local _onboard = TRPS.inTransitTroops[_heli:getName()]

    if _onboard == nil then

        if TRPS.inTransitFOBCrates[_heli:getName()] == true then
            TRPS.displayMessageToGroup(_heli, "1 FOB Crate Onboard", 10)
        else
            TRPS.displayMessageToGroup(_heli, "No troops onboard", 10)
        end


    else
        local _troops = _onboard.troops
        local _vehicles = _onboard.vehicles

        local _txt = ""

        if _troops ~= nil and _troops.units ~= nil and #_troops.units > 0 then
            _txt = _txt .. " " .. #_troops.units .. " troops onboard\n"
        end

        if _vehicles ~= nil and _vehicles.units ~= nil and #_vehicles.units > 0 then
            _txt = _txt .. " " .. #_vehicles.units .. " vehicles onboard\n"
        end

        if TRPS.inTransitFOBCrates[_heli:getName()] == true then
            _txt = _txt .. " 1 FOB Crate oboard\n"
        end

        if _txt ~= "" then
            TRPS.displayMessageToGroup(_heli, _txt, 10)
        else
            if TRPS.inTransitFOBCrates[_heli:getName()] == true then
                TRPS.displayMessageToGroup(_heli, "1 FOB Crate Onboard", 10)
            else
                TRPS.displayMessageToGroup(_heli, "No troops onboard", 10)
            end
        end
    end
end

-- Removes troops from transport when it dies
function TRPS.checkTransportStatus()

    timer.scheduleFunction(TRPS.checkTransportStatus, nil, timer.getTime() + 3)

    for _, _name in ipairs(TRPS.transportPilotNames) do

        local _transUnit = TRPS.getTransportUnit(_name)

        if _transUnit == nil then
            TRPS.inTransitTroops[_name] = nil
            TRPS.inTransitFOBCrates[_name] = nil
            TRPS.inTransitSlingLoadCrates[_name] = nil
        end
    end
end

-- function dump(o)
   -- if type(o) == 'table' then
      -- local s = '{ '
      -- for k,v in pairs(o) do
         -- if type(k) ~= 'number' then k = '"'..k..'"' end
         -- s = s .. '['..k..'] = ' .. dump(v) .. ','
      -- end
      -- return s .. '} '
   -- else
      -- return tostring(o)
   -- end
-- end
--TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. TRPS.checkInternalWeight(_heli:getName()) .. "kg", 20, false)
--CARGOWEIGHT adjust here
--sanity addition
function TRPS.checkInternalWeight(_group) --_heli  --I think in most cases I will aleady have the heli name so just passing that
	--local _name = _heli:getName()				  --alternative if I need to pass the unit instead
	--Get the number of troops in the helicopter
	--TRPS.troopsOnboard(_heli, _troops)
	if (TRPS.troopsOnboard(_group, true) == false) and  (TRPS.troopsOnboard(_group, false) == false) then   
		_TroopWeight = 0
		env.info("no troops or vics onboard")
	else
		local _onboard = TRPS.inTransitTroops[_group:getName()]
		--env.info(dump(_onboard))
		--if _onboard[1] ~= nil then
			local number = #_onboard.troops.units
			if number then
				_TroopWeight = TRPS.soldierWeight * number
				--env.info("Internal troop weight found ".. _TroopWeight)
			else
				env.info("checkInternalWeight ran but failed to get valid data")
				_TroopWeight = 0
			end
		--end
	end
    
	--check if a FOB crate is loaded
	if TRPS.inTransitFOBCrates[_group:getName()] == nil then
		_FOBWeight = 0
	else
		_FOBWeight = 800
	end
	
	--check if any other crate is loaded		
	if TRPS.inTransitSlingLoadCrates[_group:getName()] == nil then
		_CrateWeight = 0
	else
		local _currentCrate =  TRPS.deepCopy(TRPS.inTransitSlingLoadCrates[_group:getName()])
		_CrateWeight = _currentCrate.weight
	end


	if _TroopWeight and _FOBWeight and _CrateWeight then
		_cargoweight = _TroopWeight + _FOBWeight + _CrateWeight	
	else
		env.info("Something went wrong calculating current cargo weight")
		_cargoweight = 0
	end		
	
    return _cargoweight

end


--[[
function TRPS.checkHoverStatus()
    -- env.info("checkHoverStatus")
    timer.scheduleFunction(TRPS.checkHoverStatus, nil, timer.getTime() + 1.0)

    local _status, _result = pcall(function()

        for _, _name in ipairs(TRPS.transportPilotNames) do

            local _reset = true
            local _transUnit = TRPS.getTransportUnit(_name)

            --only check transports that are hovering and not planes
            if _transUnit ~= nil and TRPS.inTransitSlingLoadCrates[_name] == nil and TRPS.inAir(_transUnit) and TRPS.unitCanCarryVehicles(_transUnit) == false then

                local _crates = TRPS.getCratesAndDistance(_transUnit)

                for _, _crate in pairs(_crates) do
                    --   env.info("CRATE: ".._crate.crateUnit:getName().. " ".._crate.dist)
                    if _crate.dist < TRPS.maxDistanceFromCrate and _crate.details.unit ~= "FOB" then

                        --check height!
                        local _height = _transUnit:getPoint().y - _crate.crateUnit:getPoint().y
                        --env.info("HEIGHT " .. _name .. " " .. _height .. " " .. _transUnit:getPoint().y .. " " .. _crate.crateUnit:getPoint().y)
                        --  TRPS.heightDiff(_transUnit)
                        --env.info("HEIGHT ABOVE GROUD ".._name.." ".._height.." ".._transUnit:getPoint().y.." ".._crate.crateUnit:getPoint().y)

                        if _height > TRPS.minimumHoverHeight and _height <= TRPS.maximumHoverHeight then

                            local _time = TRPS.hoverStatus[_transUnit:getName()]

                            if _time == nil then
                                TRPS.hoverStatus[_transUnit:getName()] = TRPS.hoverTime
                                _time = TRPS.hoverTime
                            else
                                _time = TRPS.hoverStatus[_transUnit:getName()] - 1
                                TRPS.hoverStatus[_transUnit:getName()] = _time
                            end

                            if _time > 0 then
                                TRPS.displayMessageToGroup(_transUnit, "Hovering above " .. _crate.details.desc .. " crate. \n\nHold hover for " .. _time .. " seconds! \n\nIf the countdown stops you're too far away!", 10,true)
                            else
                                TRPS.hoverStatus[_transUnit:getName()] = nil
                                TRPS.displayMessageToGroup(_transUnit, "Loaded  " .. _crate.details.desc .. " crate!", 10,true)

                                --crates been moved once!
                                TRPS.crateMove[_crate.crateUnit:getName()] = nil

                                if _transUnit:getCoalition() == 1 then
                                    TRPS.spawnedCratesRED[_crate.crateUnit:getName()] = nil
                                else
                                    TRPS.spawnedCratesBLUE[_crate.crateUnit:getName()] = nil
                                end

                                _crate.crateUnit:destroy()

                                TRPS.inTransitSlingLoadCrates[_name] = _crate.details
                            end

                            _reset = false

                            break
                        elseif _height <= TRPS.minimumHoverHeight then
                            TRPS.displayMessageToGroup(_transUnit, "Too low to hook " .. _crate.details.desc .. " crate.\n\nHold hover for " .. TRPS.hoverTime .. " seconds", 5,true)
                            break
                        else
                            TRPS.displayMessageToGroup(_transUnit, "Too high to hook " .. _crate.details.desc .. " crate.\n\nHold hover for " .. TRPS.hoverTime .. " seconds", 5, true)
                            break
                        end
                    end
                end
            end

            if _reset then
                TRPS.hoverStatus[_name] = nil
            end
        end
    end)

    if (not _status) then
        env.error(string.format("TRPS ERROR: %s", _result))
    end
end
]]--

function TRPS.loadNearbyCrate(_name)
    local _transUnit = TRPS.getTransportUnit(_name)

    if _transUnit ~= nil  then

        if TRPS.inAir(_transUnit) then
            TRPS.displayMessageToGroup(_transUnit, "You must land before you can load a crate!", 10,true)
            return
        end

        if TRPS.inTransitSlingLoadCrates[_name] == nil then
            local _crates = TRPS.getCratesAndDistance(_transUnit)

            for _, _crate in pairs(_crates) do

                if _crate.dist < 50.0 then
                    TRPS.displayMessageToGroup(_transUnit, "Loaded  " .. _crate.details.desc .. " crate!", 10,true)

                    if _transUnit:getCoalition() == 1 then
                        TRPS.spawnedCratesRED[_crate.crateUnit:getName()] = nil
                    elseif _transUnit:getCoalition() == 2 then
                        TRPS.spawnedCratesBLUE[_crate.crateUnit:getName()] = nil
                    else
                        TRPS.spawnedCratesNEUTRAL[_crate.crateUnit:getName()] = nil
                    end

                    TRPS.crateMove[_crate.crateUnit:getName()] = nil

                    _crate.crateUnit:destroy()

                    local _copiedCrate = TRPS.deepCopy(_crate.details)

                    TRPS.inTransitSlingLoadCrates[_name] = _copiedCrate
					
					local _weightkg = TRPS.checkInternalWeight(_transUnit)
					local _weightlbs = math.floor(_weightkg * 2.20462)
					trigger.action.setUnitInternalCargo(_name, _weightkg )
					TRPS.displayMessageToGroup(_transUnit, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
					
					-- trigger.action.setUnitInternalCargo(_name, TRPS.checkInternalWeight(_transUnit))
					-- TRPS.displayMessageToGroup(_transUnit, "Your internal cargo weight is now ".. TRPS.checkInternalWeight(_transUnit) .. "kg", 20, false)
                    return
                end
            end

            TRPS.displayMessageToGroup(_transUnit, "No Crates within 50m to load!", 10,true)

        else
            -- crate onboard

            local _currentCrate =  TRPS.deepCopy(TRPS.inTransitSlingLoadCrates[_name])

            TRPS.displayMessageToGroup(_transUnit, "You already have a ".._currentCrate.desc.." crate onboard!", 10,true)
        end
    end


end

--recreates beacons to make sure they work!
function TRPS.refreshRadioBeacons()

    timer.scheduleFunction(TRPS.refreshRadioBeacons, nil, timer.getTime() + 30)


    for _index, _beaconDetails in ipairs(TRPS.deployedRadioBeacons) do

        --trigger.action.outTextForCoalition(_beaconDetails.coalition,_beaconDetails.text,10)
        if TRPS.updateRadioBeacon(_beaconDetails) == false then

            --search used frequencies + remove, add back to unused

            for _i, _freq in ipairs(TRPS.usedUHFFrequencies) do
                if _freq == _beaconDetails.uhf then

                    table.insert(TRPS.freeUHFFrequencies, _freq)
                    table.remove(TRPS.usedUHFFrequencies, _i)
                end
            end

            for _i, _freq in ipairs(TRPS.usedVHFFrequencies) do
                if _freq == _beaconDetails.vhf then

                    table.insert(TRPS.freeVHFFrequencies, _freq)
                    table.remove(TRPS.usedVHFFrequencies, _i)
                end
            end

            for _i, _freq in ipairs(TRPS.usedFMFrequencies) do
                if _freq == _beaconDetails.fm then

                    table.insert(TRPS.freeFMFrequencies, _freq)
                    table.remove(TRPS.usedFMFrequencies, _i)
                end
            end

            --clean up beacon table
            table.remove(TRPS.deployedRadioBeacons, _index)
        end
    end
end

function TRPS.getClockDirection(_heli, _crate)

    -- Source: Helicopter Script - Thanks!

    local _position = _crate:getPosition().p -- get position of crate
    local _playerPosition = _heli:getPosition().p -- get position of helicopter
    local _relativePosition = TRPS.vecsub(_position, _playerPosition)

    local _playerHeading = TRPS.getHeading(_heli) -- the rest of the code determines the 'o'clock' bearing of the missile relative to the helicopter

    local _headingVector = { x = math.cos(_playerHeading), y = 0, z = math.sin(_playerHeading) }

    local _headingVectorPerpendicular = { x = math.cos(_playerHeading + math.pi / 2), y = 0, z = math.sin(_playerHeading + math.pi / 2) }

    local _forwardDistance = TRPS.vecdp(_relativePosition, _headingVector)

    local _rightDistance = TRPS.vecdp(_relativePosition, _headingVectorPerpendicular)

    local _angle = math.atan2(_rightDistance, _forwardDistance) * 180 / math.pi

    if _angle < 0 then
        _angle = 360 + _angle
    end
    _angle = math.floor(_angle * 12 / 360 + 0.5)
    if _angle == 0 then
        _angle = 12
    end

    return _angle
end


function TRPS.getCompassBearing(_ref, _unitPos)

    _ref = TRPS.makeVec3(_ref, 0) -- turn it into Vec3 if it is not already.
    _unitPos = TRPS.makeVec3(_unitPos, 0) -- turn it into Vec3 if it is not already.

    local _vec = { x = _unitPos.x - _ref.x, y = _unitPos.y - _ref.y, z = _unitPos.z - _ref.z }

    local _dir = TRPS.getDir(_vec, _ref)

    local _bearing = TRPS.round(TRPS.toDegree(_dir), 0)

    return _bearing
end

function TRPS.listNearbyCrates(_args)
    local _message = ""

    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then

        return -- no heli!
    end
    local _crates = TRPS.getCratesAndDistance(_heli)

    --sort
    local _sort = function( a,b ) return a.dist < b.dist end
    table.sort(_crates,_sort)

    for _, _crate in pairs(_crates) do

        if _crate.dist < 1000 and _crate.details.unit ~= "FOB" then
            _message = string.format("%s\n%s crate - kg %i - %i m - %d o'clock", _message, _crate.details.desc, _crate.details.weight, _crate.dist, TRPS.getClockDirection(_heli, _crate.crateUnit))
        end
    end


    local _fobMsg = ""
    for _, _fobCrate in pairs(_crates) do

        if _fobCrate.dist < 1000 and _fobCrate.details.unit == "FOB" then
            _fobMsg = _fobMsg .. string.format("FOB Crate - %d m - %d o'clock\n", _fobCrate.dist, TRPS.getClockDirection(_heli, _fobCrate.crateUnit))
        end
    end

    if _message ~= "" or _fobMsg ~= "" then

        local _txt = ""

        if _message ~= "" then
            _txt = "Nearby Crates:\n" .. _message
        end

        if _fobMsg ~= "" then

            if _message ~= "" then
                _txt = _txt .. "\n\n"
            end

            _txt = _txt .. "Nearby FOB Crates (Not Slingloadable):\n" .. _fobMsg
        end

        TRPS.displayMessageToGroup(_heli, _txt, 20)

    else
        --no crates nearby

        local _txt = "No Nearby Crates"

        TRPS.displayMessageToGroup(_heli, _txt, 20)
    end
end


function TRPS.listFOBS(_args)

    local _msg = "FOB Positions:"

    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then

        return -- no heli!
    end

    -- get fob positions

    local _fobs = TRPS.getSpawnedFobs(_heli)

    -- now check spawned fobs
    for _, _fob in ipairs(_fobs) do
        _msg = string.format("%s\nFOB @ %s", _msg, TRPS.getFOBPositionString(_fob))
    end

    if _msg == "FOB Positions:" then
        TRPS.displayMessageToGroup(_heli, "Sorry, there are no active FOBs!", 20)
    else
        TRPS.displayMessageToGroup(_heli, _msg, 20)
    end
end

function TRPS.getFOBPositionString(_fob)

    local _lat, _lon = coord.LOtoLL(_fob:getPosition().p)

    local _latLngStr = TRPS.tostringLL(_lat, _lon, 3, false)

    local _message = _latLngStr

    local _beaconInfo = TRPS.fobBeacons[_fob:getName()]

    if _beaconInfo ~= nil then
        _message = string.format("%s - %.2f KHz ", _message, _beaconInfo.vhf / 1000)
        _message = string.format("%s - %.2f MHz ", _message, _beaconInfo.uhf / 1000000)
        _message = string.format("%s - %.2f MHz ", _message, _beaconInfo.fm / 1000000)
    end

    return _message
end


function TRPS.displayMessageToGroup(_unit, _text, _time,_clear)

    local _groupId = TRPS.getGroupId(_unit)
    if _groupId then
        if _clear == true then
            trigger.action.outTextForGroup(_groupId, _text, _time,_clear)
        else
            trigger.action.outTextForGroup(_groupId, _text, _time)
        end
    end
end

function TRPS.heightDiff(_unit)

    local _point = _unit:getPoint()

    -- env.info("heightunit " .. _point.y)
    --env.info("heightland " .. land.getHeight({ x = _point.x, y = _point.z }))

    return _point.y - land.getHeight({ x = _point.x, y = _point.z })
end

--includes fob crates!
function TRPS.getCratesAndDistance(_heli)
    local _crates = {}

    local _allCrates
    if _heli:getCoalition() == 1 then
        _allCrates = TRPS.spawnedCratesRED
    elseif _heli:getCoalition() == 2 then
        _allCrates = TRPS.spawnedCratesBLUE
    else
        _allCrates = TRPS.spawnedCratesNEUTRAL
    end

    for _crateName, _details in pairs(_allCrates) do
        --get crate
        local _crate = TRPS.getCrateObject(_crateName)

        --in air seems buggy with crates so if in air is true, get the height above ground and the speed magnitude
        if _crate ~= nil and _crate:getLife() > 0
                and (TRPS.inAir(_crate) == false) then

            local _dist = TRPS.getDistance(_crate:getPoint(), _heli:getPoint())     
            local _crateDetails = { crateUnit = _crate, dist = _dist, details = _details }

            table.insert(_crates, _crateDetails)
        end
    end

    local _fobCrates
    if _heli:getCoalition() == 1 then
        _fobCrates = TRPS.droppedFOBCratesRED
    elseif _heli:getCoalition() == 2 then
        _fobCrates = TRPS.droppedFOBCratesBLUE
    else
        _fobCrates = TRPS.droppedFOBCratesNEUTRAL
    end

    for _crateName, _details in pairs(_fobCrates) do

        --get crate
        local _crate = TRPS.getCrateObject(_crateName)

        if _crate ~= nil and _crate:getLife() > 0 then

            local _dist = TRPS.getDistance(_crate:getPoint(), _heli:getPoint())

            local _crateDetails = { crateUnit = _crate, dist = _dist, details = { unit = "FOB" }, }

            table.insert(_crates, _crateDetails)
        end
    end

    return _crates
    
end


function TRPS.getClosestCrate(_heli, _crates, _type)

    local _closetCrate = nil
    local _shortestDistance = -1
    local _distance = 0

    for _, _crate in pairs(_crates) do

        if (_crate.details.unit == _type or _type == nil) then
            _distance = _crate.dist

            if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then
                _shortestDistance = _distance
                _closetCrate = _crate
            end
        end
    end

    return _closetCrate
end

function TRPS.findNearestAASystem(_heli,_aaSystem)

    local _closestHawkGroup = nil
    local _shortestDistance = -1
    local _distance = 0

    for _groupName, _hawkDetails in pairs(TRPS.completeAASystems) do

        local _hawkGroup = Group.getByName(_groupName)

        if _hawkGroup ~= nil and _hawkGroup:getCoalition() == _heli:getCoalition() and _hawkDetails[1].system.name == _aaSystem.name then

            local _units = _hawkGroup:getUnits()

            for _, _leader in pairs(_units) do

                if _leader ~= nil and _leader:getLife() > 0 then

                    _distance = TRPS.getDistance(_leader:getPoint(), _heli:getPoint())

                    if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then
                        _shortestDistance = _distance
                        _closestHawkGroup = _hawkGroup
                    end

                    break
                end
            end
        end
    end

    if _closestHawkGroup ~= nil then

        return { group = _closestHawkGroup, dist = _shortestDistance }
    end
    return nil
end

function TRPS.getCrateObject(_name)
    local _crate

    if TRPS.staticBugWorkaround then
        _crate  = Unit.getByName(_name)
    else
        _crate = StaticObject.getByName(_name)
    end

    return _crate
end

function TRPS.unpackCrates(_arguments)

    local _status, _err = pcall(function(_args)

        -- trigger.action.outText("Unpack Crates".._args[1],10)

        local _heli = TRPS.getTransportUnit(_args[1])

        if _heli ~= nil and TRPS.inAir(_heli) == false then

            local _crates = TRPS.getCratesAndDistance(_heli)
            local _crate = TRPS.getClosestCrate(_heli, _crates)

			if TRPS.unpackRestriction == true then
				if TRPS.inLogisticsZone(_heli) == true  or  TRPS.farEnoughFromLogisticZone(_heli) == false then

					TRPS.displayMessageToGroup(_heli, "You can't unpack that here! Take it to where it's needed!", 20)

					return
				end
			end



            if _crate ~= nil and _crate.dist < 750
                    and (_crate.details.unit == "FOB" or _crate.details.unit == "FOB-SMALL") then

                TRPS.unpackFOBCrates(_crates, _heli)

                return

            elseif _crate ~= nil and _crate.dist < 200 then

                if TRPS.forceCrateToBeMoved and TRPS.crateMove[_crate.crateUnit:getName()] then
                    TRPS.displayMessageToGroup(_heli,"Sorry you must move this crate before you unpack it!", 20)
                    return
                end


                local _aaTemplate = TRPS.getAATemplate(_crate.details.unit)
                local _farpTemplate = TRPS.getFARPTemplate(_crate.details.unit)

                if _aaTemplate then

                    if _crate.details.unit == _aaTemplate.repair then
                        TRPS.repairAASystem(_heli, _crate,_aaTemplate)
                    else
                        TRPS.unpackAASystem(_heli, _crate, _crates,_aaTemplate)
                    end

                    return -- stop processing
                    -- is multi crate?

                elseif _farpTemplate then

                    TRPS.unpackFARPSystem(_heli, _crate, _crates, _farpTemplate)

                    return -- stop processing
                    -- is multi crate?                    
                
                elseif _crate.details.cratesRequired ~= nil and _crate.details.cratesRequired > 1 then
                    -- multicrate

                    TRPS.unpackMultiCrate(_heli, _crate, _crates)

                    return

                else
                    -- single crate
                    local _cratePoint = _crate.crateUnit:getPoint()
                    local _crateName = _crate.crateUnit:getName()

                    -- TRPS.spawnCrateStatic( _heli:getCoalition(),TRPS.getNextUnitId(),{x=100,z=100},_crateName,100)

                    --remove crate
                  --  if TRPS.slingLoad == false then
                        _crate.crateUnit:destroy()
                   -- end

                    local _spawnedGroups = TRPS.spawnCrateGroup(_heli, { _cratePoint }, { _crate.details.unit })

                    if _heli:getCoalition() == 1 then
                        TRPS.spawnedCratesRED[_crateName] = nil
                    elseif _heli:getCoalition() == 2 then
                        TRPS.spawnedCratesBLUE[_crateName] = nil
                    else
                        TRPS.spawnedCratesNEUTRAL[_crateName] = nil
                    end

                    TRPS.processCallback({unit = _heli, crate = _crate , spawnedGroup = _spawnedGroups, action = "unpack"})

                    if _crate.details.unit == "1L13 EWR" then
                        TRPS.addEWRTask(_spawnedGroups)

                        --       env.info("Added EWR")
                    end


                    trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " successfully deployed " .. _crate.details.desc .. " to the field", 10)

                    if TRPS.isJTACUnitType(_crate.details.unit) and TRPS.JTAC_dropEnabled then
						local _side = _heli:getCoalition()
                        local _code = TRPS.jtacGetLaserCodeBySide(_side)					

                        TRPS.CreateJTAC(_spawnedGroups:getName(), _code)
                        TRPS.addRETURNFIREOption(_spawnedGroups)
                    end
                end

            else

                TRPS.displayMessageToGroup(_heli, "No friendly crates close enough to unpack", 20)
            end
        end
    end, _arguments)

    if (not _status) then
        env.error(string.format("TRPS ERROR: %s", _err))
    end
end


-- builds a fob!
function TRPS.unpackFOBCrates(_crates, _heli)
	
	if TRPS.unpackRestriction == true then
		if TRPS.inLogisticsZone(_heli) == true then
			TRPS.displayMessageToGroup(_heli, "You can't unpack that here! Take it to where it's needed!", 20)
			return
		end
	end

    -- unpack multi crate
    local _nearbyMultiCrates = {}

    local _bigFobCrates = 0
    local _smallFobCrates = 0
    local _totalCrates = 0

    for _, _nearbyCrate in pairs(_crates) do

        if _nearbyCrate.dist < 750  then

            if  _nearbyCrate.details.unit == "FOB" then
                _bigFobCrates = _bigFobCrates + 1
                table.insert(_nearbyMultiCrates, _nearbyCrate)
            elseif _nearbyCrate.details.unit == "FOB-SMALL" then
                _smallFobCrates = _smallFobCrates + 1
                table.insert(_nearbyMultiCrates, _nearbyCrate)
            end

            --catch divide by 0
            if _smallFobCrates > 0 then
                _totalCrates = _bigFobCrates + (_smallFobCrates/3.0)
            else
                _totalCrates = _bigFobCrates
            end

            if _totalCrates >= TRPS.cratesRequiredForFOB then
                break
            end
        end
    end

    --- check crate count
    if _totalCrates >= TRPS.cratesRequiredForFOB then

        -- destroy crates

        local _points = {}

        for _, _crate in pairs(_nearbyMultiCrates) do

            if _heli:getCoalition() == 1 then
                TRPS.droppedFOBCratesRED[_crate.crateUnit:getName()] = nil
                TRPS.spawnedCratesRED[_crate.crateUnit:getName()] = nil
            elseif _heli:getCoalition() == 2 then
                TRPS.droppedFOBCratesBLUE[_crate.crateUnit:getName()] = nil
                TRPS.spawnedCratesBLUE[_crate.crateUnit:getName()] = nil
            else
                TRPS.droppedFOBCratesNEUTRAL[_crate.crateUnit:getName()] = nil
                TRPS.spawnedCratesNEUTRAL[_crate.crateUnit:getName()] = nil                
            end

            table.insert(_points, _crate.crateUnit:getPoint())

            --destroy
            _crate.crateUnit:destroy()
        end

        local _centroid = TRPS.getCentroid(_points)

        timer.scheduleFunction(function(_args)

            local _unitId = TRPS.getNextUnitId()
            local _name = "Deployed FOB #" .. _unitId

            local _fob = TRPS.spawnFOB(_args[2], _unitId, _args[1], _name)

            --make it able to deploy crates
            table.insert(TRPS.logisticUnits, _fob:getName())

            TRPS.beaconCount = TRPS.beaconCount + 1

            local _radioBeaconName = "FOB Beacon #" .. TRPS.beaconCount

            local _radioBeaconDetails = TRPS.createRadioBeacon(_args[1], _args[3], _args[2], _radioBeaconName, nil, true)

            TRPS.fobBeacons[_name] = { vhf = _radioBeaconDetails.vhf, uhf = _radioBeaconDetails.uhf, fm = _radioBeaconDetails.fm }

            if TRPS.troopPickupAtFOB == true then

                table.insert(TRPS.builtFOBS, _fob:getName())

                trigger.action.outTextForCoalition(_args[3], "Finished building FOB! Crates and Troops can now be picked up.", 10)
            else
                trigger.action.outTextForCoalition(_args[3], "Finished building FOB! Crates can now be picked up.", 10)
            end
        end, { _centroid, _heli:getCountry(), _heli:getCoalition() }, timer.getTime() + TRPS.buildTimeFOB)

        local _txt = string.format("%s started building FOB using %d FOB crates, it will be finished in %d seconds.\nPosition marked with smoke.", TRPS.getPlayerNameOrType(_heli), _totalCrates, TRPS.buildTimeFOB)

        TRPS.processCallback({unit = _heli, position = _centroid, action = "fob"})

        trigger.action.smoke(_centroid, trigger.smokeColor.Green)

        trigger.action.outTextForCoalition(_heli:getCoalition(), _txt, 10)
    else
        local _txt = string.format("Cannot build FOB!\n\nIt requires %d Large FOB crates ( 3 small FOB crates equal 1 large FOB Crate) and there are the equivalent of %d large FOB crates nearby\n\nOr the crates are not within 750m of each other", TRPS.cratesRequiredForFOB, _totalCrates)
        TRPS.displayMessageToGroup(_heli, _txt, 20)
    end
end

--unloads the sling crate when the helicopter is on the ground or between 4.5 - 10 meters
function TRPS.dropSlingCrate(_args)
    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then
        return -- no heli!
    end

    local _currentCrate = TRPS.inTransitSlingLoadCrates[_heli:getName()]

    if _currentCrate == nil then

        TRPS.displayMessageToGroup(_heli, "You are not currently transporting any crates. \n\nTo Pickup a crate - land and use F10 Crate Commands to load one.", 10)

    else

        local _heli = TRPS.getTransportUnit(_args[1])

        local _point = _heli:getPoint()

        local _unitId = TRPS.getNextUnitId()

        local _side = _heli:getCoalition()

        local _name = string.format("%s #%i", _currentCrate.desc, _unitId)


        local _heightDiff = TRPS.heightDiff(_heli)

        if TRPS.inAir(_heli) == false or _heightDiff <= 7.5 then
            TRPS.displayMessageToGroup(_heli, _currentCrate.desc .. " crate has been safely unhooked and is at your 12 o'clock", 10)
            _point = TRPS.getPointAt12Oclock(_heli, 30)
            --        elseif _heightDiff > 40.0 then
            --            TRPS.inTransitSlingLoadCrates[_heli:getName()] = nil
            --            TRPS.displayMessageToGroup(_heli, "You were too high! The crate has been destroyed", 10)
            --            return
        elseif _heightDiff > 7.5 and _heightDiff <= 40.0 then
            TRPS.displayMessageToGroup(_heli, _currentCrate.desc .. " crate has been safely dropped below you", 10)
        else -- _heightDiff > 40.0
        TRPS.inTransitSlingLoadCrates[_heli:getName()] = nil
        TRPS.displayMessageToGroup(_heli, "You were too high! The crate has been destroyed", 10)
        return
        end


        --remove crate from cargo
        TRPS.inTransitSlingLoadCrates[_heli:getName()] = nil
		
		local _weightkg = TRPS.checkInternalWeight(_heli)
		local _weightlbs = math.floor(_weightkg * 2.20462)
		trigger.action.setUnitInternalCargo(_heli:getName(), _weightkg )
		TRPS.displayMessageToGroup(_heli, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
			
        local _spawnedCrate = TRPS.spawnCrateStatic(_heli:getCountry(), _unitId, _point, _name, _currentCrate.weight,_side)
    end
end

-- shows the status of the current simulated cargo status
function TRPS.slingCargoStatus(_args)
    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli == nil then
        return -- no heli!
    end

    local _currentCrate = TRPS.inTransitSlingLoadCrates[_heli:getName()]

    if _currentCrate == nil then
        TRPS.displayMessageToGroup(_heli, "You are not currently transporting any crates. \n\nTo Pickup a crate, land near the crate and load it using the menu", 10)
    else
        TRPS.displayMessageToGroup(_heli, "Currently Transporting: " .. _currentCrate.desc --[[.. " \n\nTo Pickup a crate, hover for 10 seconds above the crate"]], 10)
    end
end

--spawns a radio beacon made up of two units,
-- one for VHF and one for UHF
-- The units are set to to NOT engage
function TRPS.createRadioBeacon(_point, _coalition, _country, _name, _batteryTime, _isFOB)

    local _uhfGroup = TRPS.spawnRadioBeaconUnit(_point, _country, "UHF")
    local _vhfGroup = TRPS.spawnRadioBeaconUnit(_point, _country, "VHF")
    local _fmGroup = TRPS.spawnRadioBeaconUnit(_point, _country, "FM")

    local _freq = TRPS.generateADFFrequencies()

    --create timeout
    local _battery

    if _batteryTime == nil then
        _battery = timer.getTime() + (TRPS.deployedBeaconBattery * 60)
    else
        _battery = timer.getTime() + (_batteryTime * 60)
    end

    local _lat, _lon = coord.LOtoLL(_point)

    local _latLngStr = TRPS.tostringLL(_lat, _lon, 3, false)

    local _message = _name

    if _isFOB then
        --  _message = "FOB " .. _message
        _battery = -1 --never run out of power!
    end

    _message = _message .. " - " .. _latLngStr

    --  env.info("GEN UHF: ".. _freq.uhf)
    --  env.info("GEN VHF: ".. _freq.vhf)

    _message = string.format("%s - %.2f KHz", _message, _freq.vhf / 1000)

    _message = string.format("%s - %.2f MHz", _message, _freq.uhf / 1000000)

    _message = string.format("%s - %.2f MHz ", _message, _freq.fm / 1000000)



    local _beaconDetails = {
        vhf = _freq.vhf,
        vhfGroup = _vhfGroup:getName(),
        uhf = _freq.uhf,
        uhfGroup = _uhfGroup:getName(),
        fm = _freq.fm,
        fmGroup = _fmGroup:getName(),
        text = _message,
        battery = _battery,
        coalition = _coalition,
    }
    TRPS.updateRadioBeacon(_beaconDetails)

    table.insert(TRPS.deployedRadioBeacons, _beaconDetails)

    return _beaconDetails
end

function TRPS.generateADFFrequencies()

    if #TRPS.freeUHFFrequencies <= 3 then
        TRPS.freeUHFFrequencies = TRPS.usedUHFFrequencies
        TRPS.usedUHFFrequencies = {}
    end

    --remove frequency at RANDOM
    local _uhf = table.remove(TRPS.freeUHFFrequencies, math.random(#TRPS.freeUHFFrequencies))
    table.insert(TRPS.usedUHFFrequencies, _uhf)


    if #TRPS.freeVHFFrequencies <= 3 then
        TRPS.freeVHFFrequencies = TRPS.usedVHFFrequencies
        TRPS.usedVHFFrequencies = {}
    end

    local _vhf = table.remove(TRPS.freeVHFFrequencies, math.random(#TRPS.freeVHFFrequencies))
    table.insert(TRPS.usedVHFFrequencies, _vhf)

    if #TRPS.freeFMFrequencies <= 3 then
        TRPS.freeFMFrequencies = TRPS.usedFMFrequencies
        TRPS.usedFMFrequencies = {}
    end

    local _fm = table.remove(TRPS.freeFMFrequencies, math.random(#TRPS.freeFMFrequencies))
    table.insert(TRPS.usedFMFrequencies, _fm)

    return { uhf = _uhf, vhf = _vhf, fm = _fm }
    --- return {uhf=_uhf,vhf=_vhf}
end



function TRPS.spawnRadioBeaconUnit(_point, _country, _type)

    local _groupId = TRPS.getNextGroupId()

    local _unitId = TRPS.getNextUnitId()

    local _radioGroup = {
        ["visible"] = false,
       -- ["groupId"] = _groupId,
        ["hidden"] = false,
        ["units"] = {
            [1] = {
                ["y"] = _point.z,
                ["type"] = "TACAN_beacon",
                ["name"] = _type .. " Radio Beacon Unit #" .. _unitId,
             --   ["unitId"] = _unitId,
                ["heading"] = 0,
                ["playerCanDrive"] = true,
                ["skill"] = "Excellent",
                ["x"] = _point.x,
            }
        },
        --        ["y"] = _positions[1].z,
        --        ["x"] = _positions[1].x,
        ["name"] = _type .. " Radio Beacon Group #" .. _groupId,
        ["task"] = {},
        ["category"] = Group.Category.GROUND,
        ["country"] = _country
    }

    -- return coalition.addGroup(_country, Group.Category.GROUND, _radioGroup)
    return Group.getByName(TRPS.dynAdd(_radioGroup).name)
end

function TRPS.updateRadioBeacon(_beaconDetails)

    local _vhfGroup = Group.getByName(_beaconDetails.vhfGroup)

    local _uhfGroup = Group.getByName(_beaconDetails.uhfGroup)

    local _fmGroup = Group.getByName(_beaconDetails.fmGroup)

    local _radioLoop = {}

    if _vhfGroup ~= nil and _vhfGroup:getUnits() ~= nil and #_vhfGroup:getUnits() == 1 then
        table.insert(_radioLoop, { group = _vhfGroup, freq = _beaconDetails.vhf, silent = false, mode = 0 })
    end

    if _uhfGroup ~= nil and _uhfGroup:getUnits() ~= nil and #_uhfGroup:getUnits() == 1 then
        table.insert(_radioLoop, { group = _uhfGroup, freq = _beaconDetails.uhf, silent = true, mode = 0 })
    end

    if _fmGroup ~= nil and _fmGroup:getUnits() ~= nil and #_fmGroup:getUnits() == 1 then
        table.insert(_radioLoop, { group = _fmGroup, freq = _beaconDetails.fm, silent = false, mode = 1 })
    end

    local _batLife = _beaconDetails.battery - timer.getTime()

    if (_batLife <= 0 and _beaconDetails.battery ~= -1) or #_radioLoop ~= 3 then
        -- ran out of batteries

        if _vhfGroup ~= nil then
            _vhfGroup:destroy()
        end
        if _uhfGroup ~= nil then
            _uhfGroup:destroy()
        end
        if _fmGroup ~= nil then
            _fmGroup:destroy()
        end

        return false
    end

    --fobs have unlimited battery life
    --    if _battery ~= -1 then
    --        _text = _text.." "..TRPS.round(_batLife).." seconds of battery"
    --    end

    for _, _radio in pairs(_radioLoop) do

        local _groupController = _radio.group:getController()

        local _sound = TRPS.radioSound
        if _radio.silent then
            _sound = TRPS.radioSoundFC3
        end

        _sound = "l10n/DEFAULT/".._sound

        _groupController:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD)

        trigger.action.radioTransmission(_sound, _radio.group:getUnit(1):getPoint(), _radio.mode, false, _radio.freq, 1000)
        --This function doesnt actually stop transmitting when then sound is false. My hope is it will stop if a new beacon is created on the same
        -- frequency... OR they fix the bug where it wont stop.
        --        end

        --
    end

    return true

    --  trigger.action.radioTransmission(TRPS.radioSound, _point, 1, true, _frequency, 1000)
end

function TRPS.listRadioBeacons(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _message = ""

    if _heli ~= nil then

        for _x, _details in pairs(TRPS.deployedRadioBeacons) do

            if _details.coalition == _heli:getCoalition() then
                _message = _message .. _details.text .. "\n"
            end
        end

        if _message ~= "" then
            TRPS.displayMessageToGroup(_heli, "Radio Beacons:\n" .. _message, 20)
        else
            TRPS.displayMessageToGroup(_heli, "No Active Radio Beacons", 20)
        end
    end
end

function TRPS.dropRadioBeacon(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _message = ""

    if _heli ~= nil and TRPS.inAir(_heli) == false then

        --deploy 50 m infront
        --try to spawn at 12 oclock to us
        local _point = TRPS.getPointAt12Oclock(_heli, 50)

        TRPS.beaconCount = TRPS.beaconCount + 1
        local _name = "Beacon #" .. TRPS.beaconCount

        local _radioBeaconDetails = TRPS.createRadioBeacon(_point, _heli:getCoalition(), _heli:getCountry(), _name, nil, false)

        -- mark with flare?

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " deployed a Radio Beacon.\n\n" .. _radioBeaconDetails.text, 20)

    else
        TRPS.displayMessageToGroup(_heli, "You need to land before you can deploy a Radio Beacon!", 20)
    end
end

--remove closet radio beacon
function TRPS.removeRadioBeacon(_args)

    local _heli = TRPS.getTransportUnit(_args[1])
    local _message = ""

    if _heli ~= nil and TRPS.inAir(_heli) == false then

        -- mark with flare?

        local _closetBeacon = nil
        local _shortestDistance = -1
        local _distance = 0

        for _x, _details in pairs(TRPS.deployedRadioBeacons) do

            if _details.coalition == _heli:getCoalition() then

                local _group = Group.getByName(_details.vhfGroup)

                if _group ~= nil and #_group:getUnits() == 1 then

                    _distance = TRPS.getDistance(_heli:getPoint(), _group:getUnit(1):getPoint())
                    if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then
                        _shortestDistance = _distance
                        _closetBeacon = _details
                    end
                end
            end
        end

        if _closetBeacon ~= nil and _shortestDistance then
            local _vhfGroup = Group.getByName(_closetBeacon.vhfGroup)

            local _uhfGroup = Group.getByName(_closetBeacon.uhfGroup)

            local _fmGroup = Group.getByName(_closetBeacon.fmGroup)

            if _vhfGroup ~= nil then
                _vhfGroup:destroy()
            end
            if _uhfGroup ~= nil then
                _uhfGroup:destroy()
            end
            if _fmGroup ~= nil then
                _fmGroup:destroy()
            end

            trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " removed a Radio Beacon.\n\n" .. _closetBeacon.text, 20)
        else
            TRPS.displayMessageToGroup(_heli, "No Radio Beacons within 500m.", 20)
        end

    else
        TRPS.displayMessageToGroup(_heli, "You need to land before remove a Radio Beacon", 20)
    end
end

-- gets the center of a bunch of points!
-- return proper DCS point with height
function TRPS.getCentroid(_points)
    local _tx, _ty = 0, 0
    for _index, _point in ipairs(_points) do
        _tx = _tx + _point.x
        _ty = _ty + _point.z
    end

    local _npoints = #_points

    local _point = { x = _tx / _npoints, z = _ty / _npoints }

    _point.y = land.getHeight({ _point.x, _point.z })

    return _point
end

function TRPS.getAATemplate(_unitName)

    for _,_system in pairs(TRPS.AASystemTemplate) do

        if _system.repair == _unitName then
            return _system
        end

        for _,_part in pairs(_system.parts) do

            if _unitName == _part.name  then
                return _system
            end
        end
    end

    return nil

end

function TRPS.getFARPTemplate(_unitName)

    for _,_system in pairs(TRPS.FARPsupportTemplate) do
        for _,_part in pairs(_system.parts) do

            if _unitName == _part.name  then
                return _system
            end
        end
    end

    return nil

end

function TRPS.getLauncherUnitFromAATemplate(_aaTemplate)
    for _,_part in pairs(_aaTemplate.parts) do

        if _part.launcher then
            return _part.name
        end
    end

    return nil
end

function TRPS.rearmAASystem(_heli, _nearestCrate, _nearbyCrates, _aaSystemTemplate)

    -- are we adding to existing aa system?
    -- check to see if the crate is a launcher
    if TRPS.getLauncherUnitFromAATemplate(_aaSystemTemplate) == _nearestCrate.details.unit then

        -- find nearest COMPLETE AA system
        local _nearestSystem = TRPS.findNearestAASystem(_heli, _aaSystemTemplate)

        if _nearestSystem ~= nil and _nearestSystem.dist < 300 then

            local _uniqueTypes = {} -- stores each unique part of system
            local _types = {}
            local _points = {}

            local _units = _nearestSystem.group:getUnits()

            if _units ~= nil and #_units > 0 then

                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then

                        --this allows us to count each type once
                        _uniqueTypes[_units[x]:getTypeName()] = _units[x]:getTypeName()

                        table.insert(_points, _units[x]:getPoint())
                        table.insert(_types, _units[x]:getTypeName())
                    end
                end
            end

            -- do we have the correct number of unique pieces and do we have enough points for all the pieces
            if TRPS.countTableEntries(_uniqueTypes) == _aaSystemTemplate.count and #_points >= _aaSystemTemplate.count then

                -- rearm aa system
                -- destroy old group
                TRPS.completeAASystems[_nearestSystem.group:getName()] = nil

                _nearestSystem.group:destroy()

                local _spawnedGroup = TRPS.spawnCrateGroup(_heli, _points, _types)

                TRPS.completeAASystems[_spawnedGroup:getName()] = TRPS.getAASystemDetails(_spawnedGroup, _aaSystemTemplate)

                TRPS.processCallback({unit = _heli, crate =  _nearestCrate , spawnedGroup = _spawnedGroup, action = "rearm"})

                trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " successfully rearmed a full ".._aaSystemTemplate.name.." in the field", 10)

                if _heli:getCoalition() == 1 then
                    TRPS.spawnedCratesRED[_nearestCrate.crateUnit:getName()] = nil
                elseif _heli:getCoalition() == 2 then
                    TRPS.spawnedCratesBLUE[_nearestCrate.crateUnit:getName()] = nil
                else
                    TRPS.spawnedCratesNEUTRAL[_nearestCrate.crateUnit:getName()] = nil
                end

                -- remove crate
           --     if TRPS.slingLoad == false then
                    _nearestCrate.crateUnit:destroy()
              --  end

                return true -- all done so quit
            end
        end
    end

    return false
end

function TRPS.getAASystemDetails(_hawkGroup,_aaSystemTemplate)

    local _units = _hawkGroup:getUnits()

    local _hawkDetails = {}

    for _, _unit in pairs(_units) do
        table.insert(_hawkDetails, { point = _unit:getPoint(), unit = _unit:getTypeName(), name = _unit:getName(), system =_aaSystemTemplate})
    end

    return _hawkDetails
end

function TRPS.countTableEntries(_table)

    if _table == nil then
        return 0
    end


    local _count = 0

    for _key, _value in pairs(_table) do

        _count = _count + 1
    end

    return _count
end

function TRPS.unpackAASystem(_heli, _nearestCrate, _nearbyCrates,_aaSystemTemplate)

    if TRPS.rearmAASystem(_heli, _nearestCrate, _nearbyCrates,_aaSystemTemplate) then
        -- rearmed hawk
        return
    end

    -- are there all the pieces close enough together
    local _systemParts = {}

    --initialise list of parts
    for _,_part in pairs(_aaSystemTemplate.parts) do
        _systemParts[_part.name] = {name = _part.name,desc = _part.desc,found = false}
    end

    -- find all nearest crates and add them to the list if they're part of the AA System
    for _, _nearbyCrate in pairs(_nearbyCrates) do

        if _nearbyCrate.dist < 500 then

            if _systemParts[_nearbyCrate.details.unit] ~= nil and _systemParts[_nearbyCrate.details.unit].found == false  then
                local _foundPart = _systemParts[_nearbyCrate.details.unit]

                _foundPart.found = true
                _foundPart.crate = _nearbyCrate

                _systemParts[_nearbyCrate.details.unit] = _foundPart
            end
        end
    end

    local _count = 0
    local _txt = ""

    local _posArray = {}
    local _typeArray = {}
    for _name, _systemPart in pairs(_systemParts) do

        if _systemPart.found == false then
            _txt = _txt.."Missing ".._systemPart.desc.."\n"
        else

            local _launcherPart = TRPS.getLauncherUnitFromAATemplate(_aaSystemTemplate)

            --handle multiple launchers from one crate
            if (_name == "Hawk ln" and TRPS.hawkLaunchers > 1)
                    or (_launcherPart == _name and TRPS.aaLaunchers  > 1) then

                --add multiple launcher
                local _launchers = TRPS.aaLaunchers

                if _name == "Hawk ln" then
                    _launchers = TRPS.hawkLaunchers
                end

                for _i = 1, _launchers do

                    -- spawn in a circle around the crate
                    local _angle = math.pi * 2 * (_i - 1) / _launchers
                    local _xOffset = math.cos(_angle) * 12
                    local _yOffset = math.sin(_angle) * 12

                    local _point = _systemPart.crate.crateUnit:getPoint()

                    _point = { x = _point.x + _xOffset, y = _point.y, z = _point.z + _yOffset }

                    table.insert(_posArray, _point)
                    table.insert(_typeArray, _name)
                end
            else
                table.insert(_posArray, _systemPart.crate.crateUnit:getPoint())
                table.insert(_typeArray, _name)
            end
        end
    end

    local _activeLaunchers = TRPS.countCompleteAASystems(_heli)

    local _allowed = TRPS.getAllowedAASystems(_heli)

    --env.info("Active: ".._activeLaunchers.." Allowed: ".._allowed)

    if _activeLaunchers + 1 > _allowed then
        trigger.action.outTextForCoalition(_heli:getCoalition(), "Out of parts for AA Systems. Current limit is ".._allowed.." \n", 10)
        return
    end

    if _txt ~= ""  then
        TRPS.displayMessageToGroup(_heli, "Cannot build ".._aaSystemTemplate.name.."\n" .. _txt .. "\n\nOr the crates are not close enough together", 20)
        return
    else

        -- destroy crates
        for _name, _systemPart in pairs(_systemParts) do

            if _heli:getCoalition() == 1 then
                TRPS.spawnedCratesRED[_systemPart.crate.crateUnit:getName()] = nil
            elseif _heli:getCoalition() == 2 then
                TRPS.spawnedCratesBLUE[_systemPart.crate.crateUnit:getName()] = nil
            else
                TRPS.spawnedCratesNEUTRAL[_systemPart.crate.crateUnit:getName()] = nil
            end

            --destroy
           -- if TRPS.slingLoad == false then
                _systemPart.crate.crateUnit:destroy()
            --end
        end

        -- HAWK / BUK READY!
        local _spawnedGroup = TRPS.spawnCrateGroup(_heli, _posArray, _typeArray)

        TRPS.completeAASystems[_spawnedGroup:getName()] = TRPS.getAASystemDetails(_spawnedGroup,_aaSystemTemplate)

        TRPS.processCallback({unit = _heli, crate = _nearestCrate , spawnedGroup = _spawnedGroup, action = "unpack"})

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " successfully deployed a full ".._aaSystemTemplate.name.." to the field. \n\nAA Active System limit is: ".._allowed.."\nActive: "..(_activeLaunchers+1), 10)

    end
end

function TRPS.unpackFARPSystem(_heli, _nearestCrate, _nearbyCrates,_farpSystemTemplate)

    -- are there all the pieces close enough together
    local _systemParts = {}

    --initialise list of parts
    for _,_part in pairs(_farpSystemTemplate.parts) do
        _systemParts[_part.name] = {name = _part.name,desc = _part.desc,found = false}
    end

    -- find all nearest crates and add them to the list if they're part of the AA System
    for _, _nearbyCrate in pairs(_nearbyCrates) do

        if _nearbyCrate.dist < 500 then

            if _systemParts[_nearbyCrate.details.unit] ~= nil and _systemParts[_nearbyCrate.details.unit].found == false  then
                local _foundPart = _systemParts[_nearbyCrate.details.unit]

                _foundPart.found = true
                _foundPart.crate = _nearbyCrate

                _systemParts[_nearbyCrate.details.unit] = _foundPart
            end
        end
    end

    local _count = 0
    local _txt = ""

    local _posArray = {}
    local _typeArray = {}
    for _name, _systemPart in pairs(_systemParts) do

        if _systemPart.found == false then
            _txt = _txt.."Missing ".._systemPart.desc.."\n"
        else
            table.insert(_posArray, _systemPart.crate.crateUnit:getPoint())
            table.insert(_typeArray, _name)
        end
    end

    if _txt ~= ""  then
        TRPS.displayMessageToGroup(_heli, "Cannot build ".._farpSystemTemplate.name.."\n" .. _txt .. "\n\nOr the crates are not close enough together", 20)
        return
    else

        -- destroy crates
        for _name, _systemPart in pairs(_systemParts) do

            if _heli:getCoalition() == 1 then
                TRPS.spawnedCratesRED[_systemPart.crate.crateUnit:getName()] = nil
            elseif _heli:getCoalition() == 2 then
                TRPS.spawnedCratesBLUE[_systemPart.crate.crateUnit:getName()] = nil
            else
                TRPS.spawnedCratesNEUTRAL[_systemPart.crate.crateUnit:getName()] = nil
            end

            -- DSMC addition to track old crates
            if tblDeadUnits then
                tblDeadUnits[#tblDeadUnits + 1] = {unitId = _systemPart.crate.crateUnit:getID(), objCategory = 6}
            end
            
            --destroy
           -- if TRPS.slingLoad == false then
            _systemPart.crate.crateUnit:destroy()
            --end
        end

        -- FARP UNITS READY!
        local _spawnedGroup = TRPS.spawnCrateGroup(_heli, _posArray, _typeArray)

        --TRPS.completeAASystems[_spawnedGroup:getName()] = TRPS.getAASystemDetails(_spawnedGroup,_farpSystemTemplate)

        TRPS.processCallback({unit = _heli, crate = _nearestCrate , spawnedGroup = _spawnedGroup, action = "unpack"})

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " successfully deployed a full ".._farpSystemTemplate.name.." to the field.", 10)

    end
end

--count the number of captured cities, sets the amount of allowed AA Systems
function TRPS.getAllowedAASystems(_heli)

    if _heli:getCoalition() == 1 then
        return TRPS.AASystemLimitBLUE
    else
        return TRPS.AASystemLimitRED
    end


end


function TRPS.countCompleteAASystems(_heli)

    local _count = 0

    for _groupName, _hawkDetails in pairs(TRPS.completeAASystems) do

        local _hawkGroup = Group.getByName(_groupName)

        if _hawkGroup ~= nil and _hawkGroup:getCoalition() == _heli:getCoalition() then

            local _units = _hawkGroup:getUnits()

            if _units ~=nil and #_units > 0 then
                --get the system template
                local _aaSystemTemplate = _hawkDetails[1].system

                local _uniqueTypes = {} -- stores each unique part of system
                local _types = {}
                local _points = {}

                if _units ~= nil and #_units > 0 then

                    for x = 1, #_units do
                        if _units[x]:getLife() > 0 then

                            --this allows us to count each type once
                            _uniqueTypes[_units[x]:getTypeName()] = _units[x]:getTypeName()

                            table.insert(_points, _units[x]:getPoint())
                            table.insert(_types, _units[x]:getTypeName())
                        end
                    end
                end

                -- do we have the correct number of unique pieces and do we have enough points for all the pieces
                if TRPS.countTableEntries(_uniqueTypes) == _aaSystemTemplate.count and #_points >= _aaSystemTemplate.count then
                    _count = _count +1
                end
            end
        end
    end

    return _count
end


function TRPS.repairAASystem(_heli, _nearestCrate,_aaSystem)

    -- find nearest COMPLETE AA system
    local _nearestHawk = TRPS.findNearestAASystem(_heli,_aaSystem)



    if _nearestHawk ~= nil and _nearestHawk.dist < 300 then

        local _oldHawk = TRPS.completeAASystems[_nearestHawk.group:getName()]

        --spawn new one

        local _types = {}
        local _points = {}

        for _, _part in pairs(_oldHawk) do
            table.insert(_points, _part.point)
            table.insert(_types, _part.unit)
        end

        --remove old system
        TRPS.completeAASystems[_nearestHawk.group:getName()] = nil
        _nearestHawk.group:destroy()

        local _spawnedGroup = TRPS.spawnCrateGroup(_heli, _points, _types)

        TRPS.completeAASystems[_spawnedGroup:getName()] = TRPS.getAASystemDetails(_spawnedGroup,_aaSystem)

        TRPS.processCallback({unit = _heli, crate = _nearestCrate , spawnedGroup = _spawnedGroup, action = "repair"})

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " successfully repaired a full ".._aaSystem.name.." in the field", 10)

        if _heli:getCoalition() == 1 then
            TRPS.spawnedCratesRED[_nearestCrate.crateUnit:getName()] = nil
        elseif _heli:getCoalition() == 2 then
            TRPS.spawnedCratesBLUE[_nearestCrate.crateUnit:getName()] = nil
        else
            TRPS.spawnedCratesNEUTRAL[_nearestCrate.crateUnit:getName()] = nil
        end

        -- remove crate
       -- if TRPS.slingLoad == false then
            _nearestCrate.crateUnit:destroy()
       -- end

    else
        TRPS.displayMessageToGroup(_heli, "Cannot repair  ".._aaSystem.name..". No damaged ".._aaSystem.name.." within 300m", 10)
    end
end

function TRPS.unpackMultiCrate(_heli, _nearestCrate, _nearbyCrates)

    -- unpack multi crate
    local _nearbyMultiCrates = {}

    for _, _nearbyCrate in pairs(_nearbyCrates) do

        if _nearbyCrate.dist < 300 then

            if _nearbyCrate.details.unit == _nearestCrate.details.unit then

                table.insert(_nearbyMultiCrates, _nearbyCrate)

                if #_nearbyMultiCrates == _nearestCrate.details.cratesRequired then
                    break
                end
            end
        end
    end

    --- check crate count
    if #_nearbyMultiCrates == _nearestCrate.details.cratesRequired then

        local _point = _nearestCrate.crateUnit:getPoint()

        -- destroy crates
        for _, _crate in pairs(_nearbyMultiCrates) do

            if _point == nil then
                _point = _crate.crateUnit:getPoint()
            end

            if _heli:getCoalition() == 1 then
                TRPS.spawnedCratesRED[_crate.crateUnit:getName()] = nil
            elseif _heli:getCoalition() == 2 then
                TRPS.spawnedCratesBLUE[_crate.crateUnit:getName()] = nil
            else
                TRPS.spawnedCratesNEUTRAL[_crate.crateUnit:getName()] = nil
            end

            --destroy
         --   if TRPS.slingLoad == false then
                _crate.crateUnit:destroy()
         --   end
        end


        local _spawnedGroup = TRPS.spawnCrateGroup(_heli, { _point }, { _nearestCrate.details.unit })

        TRPS.processCallback({unit = _heli, crate =  _nearestCrate , spawnedGroup = _spawnedGroup, action = "unpack"})

        local _txt = string.format("%s successfully deployed %s to the field using %d crates", TRPS.getPlayerNameOrType(_heli), _nearestCrate.details.desc, #_nearbyMultiCrates)

        trigger.action.outTextForCoalition(_heli:getCoalition(), _txt, 10)

    else

        local _txt = string.format("Cannot build %s!\n\nIt requires %d crates and there are %d \n\nOr the crates are not within 300m of each other", _nearestCrate.details.desc, _nearestCrate.details.cratesRequired, #_nearbyMultiCrates)

        TRPS.displayMessageToGroup(_heli, _txt, 20)
    end
end


function TRPS.spawnCrateGroup(_heli, _positions, _types)

    local _id = TRPS.getNextGroupId()

    local _groupName = _types[1] .. "  #" .. _id

    local _side = _heli:getCoalition()

    local _group = {
        ["visible"] = false,
       -- ["groupId"] = _id,
        ["hidden"] = false,
        ["units"] = {},
        --        ["y"] = _positions[1].z,
        --        ["x"] = _positions[1].x,
        ["name"] = _groupName,
        ["task"] = {},
    }

    if #_positions == 1 then

        local _unitId = TRPS.getNextUnitId()
        local _details = { type = _types[1], unitId = _unitId, name = string.format("Unpacked %s #%i", _types[1], _unitId) }

        _group.units[1] = TRPS.createUnit(_positions[1].x + 5, _positions[1].z + 5, 120, _details)

    else

        for _i, _pos in ipairs(_positions) do

            local _unitId = TRPS.getNextUnitId()
            local _details = { type = _types[_i], unitId = _unitId, name = string.format("Unpacked %s #%i", _types[_i], _unitId) }

            _group.units[_i] = TRPS.createUnit(_pos.x + 5, _pos.z + 5, 120, _details)
        end
    end

    _group.category = Group.Category.GROUND
    _group.country = _heli:getCountry()

    local _spawnedGroup = Group.getByName(TRPS.dynAdd(_group).name)

    --local _spawnedGroup = coalition.addGroup(_heli:getCountry(), Group.Category.GROUND, _group)

    --activate by moving and so we can set ROE and Alarm state

    local _dest = _spawnedGroup:getUnit(1):getPoint()
    _dest = { x = _dest.x + 0.5, _y = _dest.y + 0.5, z = _dest.z + 0.5 }

    TRPS.orderGroupToMoveToPoint(_spawnedGroup:getUnit(1), _dest)

    return _spawnedGroup
end



-- spawn normal group
function TRPS.spawnDroppedGroup(_point, _details, _spawnBehind, _maxSearch)

    local _groupName = _details.groupName

    local _group = {
        ["visible"] = false,
      --  ["groupId"] = _details.groupId,
        ["hidden"] = false,
        ["units"] = {},
        --        ["y"] = _positions[1].z,
        --        ["x"] = _positions[1].x,
        ["name"] = _groupName,
        ["task"] = {},
    }


    if _spawnBehind == false then

        -- spawn in circle around heli

        local _pos = _point

        for _i, _detail in ipairs(_details.units) do

            local _angle = math.pi * 2 * (_i - 1) / #_details.units
            local _xOffset = math.cos(_angle) * 30
            local _yOffset = math.sin(_angle) * 30

            _group.units[_i] = TRPS.createUnit(_pos.x + _xOffset, _pos.z + _yOffset, _angle, _detail)
        end

    else

        local _pos = _point

        --try to spawn at 6 oclock to us
        local _angle = math.atan2(_pos.z, _pos.x)
        local _xOffset = math.cos(_angle) * -30
        local _yOffset = math.sin(_angle) * -30


        for _i, _detail in ipairs(_details.units) do
            _group.units[_i] = TRPS.createUnit(_pos.x + (_xOffset + 10 * _i), _pos.z + (_yOffset + 10 * _i), _angle, _detail)
        end
    end

    _group.category = Group.Category.GROUND;
    _group.country = _details.country;

    local _spawnedGroup = Group.getByName(TRPS.dynAdd(_group).name)

    --local _spawnedGroup = coalition.addGroup(_details.country, Group.Category.GROUND, _group)


    -- find nearest enemy and head there
    if _maxSearch == nil then
        _maxSearch = TRPS.maximumSearchDistance
    end

    local _wpZone = TRPS.inWaypointZone(_point,_spawnedGroup:getCoalition())

    if _wpZone.inZone then
        TRPS.orderGroupToMoveToPoint(_spawnedGroup:getUnit(1), _wpZone.point)
        --env.info("Heading to waypoint - In Zone ".._wpZone.name)
    else
        local _enemyPos = TRPS.findNearestEnemy(_details.side, _point, _maxSearch)

        TRPS.orderGroupToMoveToPoint(_spawnedGroup:getUnit(1), _enemyPos)
    end

    return _spawnedGroup
end

function TRPS.findNearestEnemy(_side, _point, _searchDistance)

    local _closestEnemy = nil

    local _groups

    local _closestEnemyDist = _searchDistance

    local _heliPoint = _point

    if _side == 2 then
        _groups = coalition.getGroups(1, Group.Category.GROUND)
    else
        _groups = coalition.getGroups(2, Group.Category.GROUND)
    end

    for _, _group in pairs(_groups) do

        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then

                local _leader = nil

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then
                        _leader = _units[x]
                        break
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = TRPS.getDistance(_heliPoint, _leaderPos)
                    if _dist < _closestEnemyDist then
                        _closestEnemyDist = _dist
                        _closestEnemy = _leaderPos
                    end
                end
            end
        end
    end


    -- no enemy - move to random point
    if _closestEnemy ~= nil then

        -- env.info("found enemy")
        return _closestEnemy
    else

        local _x = _heliPoint.x + math.random(0, TRPS.maximumMoveDistance) - math.random(0, TRPS.maximumMoveDistance)
        local _z = _heliPoint.z + math.random(0, TRPS.maximumMoveDistance) - math.random(0, TRPS.maximumMoveDistance)
        local _y = _heliPoint.y + math.random(0, TRPS.maximumMoveDistance) - math.random(0, TRPS.maximumMoveDistance)

        return { x = _x, z = _z,y=_y }
    end
end

function TRPS.findNearestGroup(_heli, _groups)

    local _closestGroupDetails = {}
    local _closestGroup = nil

    local _closestGroupDist = TRPS.maxExtractDistance

    local _heliPoint = _heli:getPoint()

    for _, _groupName in pairs(_groups) do

        local _group = Group.getByName(_groupName)

        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then

                local _leader = nil

                local _groupDetails = { groupId = _group:getID(), groupName = _group:getName(), side = _group:getCoalition(), units = {} }

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then

                        if _leader == nil then
                            _leader = _units[x]
                            -- set country based on leader
                            _groupDetails.country = _leader:getCountry()
                        end

                        local _unitDetails = { type = _units[x]:getTypeName(), unitId = _units[x]:getID(), name = _units[x]:getName() }

                        table.insert(_groupDetails.units, _unitDetails)
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = TRPS.getDistance(_heliPoint, _leaderPos)
                    if _dist < _closestGroupDist then
                        _closestGroupDist = _dist
                        _closestGroupDetails = _groupDetails
                        _closestGroup = _group
                    end
                end
            end
        end
    end


    if _closestGroup ~= nil then

        return { group = _closestGroup, details = _closestGroupDetails }
    else

        return nil
    end
end


function TRPS.createUnit(_x, _y, _angle, _details)

    local _newUnit = {
        ["y"] = _y,
        ["type"] = _details.type,
        ["name"] = _details.name,
      --  ["unitId"] = _details.unitId,
        ["heading"] = _angle,
        ["playerCanDrive"] = true,
        ["skill"] = "Excellent",
        ["x"] = _x,
    }

    return _newUnit
end

function TRPS.addEWRTask(_group)

    -- delayed 2 second to work around bug
    timer.scheduleFunction(function(_ewrGroup)
        local _grp = TRPS.getAliveGroup(_ewrGroup)

        if _grp ~= nil then
            local _controller = _grp:getController();
            local _EWR = {
                id = 'EWR',
                auto = true,
                params = {
                }
            }
            _controller:setTask(_EWR)
        end
    end
        , _group:getName(), timer.getTime() + 2)

end

function TRPS.addRETURNFIREOption(_group)

    -- delayed 2 second to work around bug
    timer.scheduleFunction(function(_jtacGroup)
        local _grp = TRPS.getAliveGroup(_jtacGroup)

        if _grp ~= nil then
            local _controller = _grp:getController();
            _controller:setOption(AI.Option.Ground.id.ROE, 3)
        end
    end
        , _group:getName(), timer.getTime() + 2)

end

function TRPS.orderGroupToMoveToPoint(_leader, _destination)

    local _group = _leader:getGroup()

    local _path = {}
    table.insert(_path, TRPS.ground_buildWP(_leader:getPoint(), 'Off Road', 50))
    table.insert(_path, TRPS.ground_buildWP(_destination, 'Off Road', 50))

    local _mission = {
        id = 'Mission',
        params = {
            route = {
                points =_path
            },
        },
    }


    -- delayed 2 second to work around bug
    timer.scheduleFunction(function(_arg)
        local _grp = TRPS.getAliveGroup(_arg[1])

        if _grp ~= nil then
            local _controller = _grp:getController();
            Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)
            Controller.setOption(_controller, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
            _controller:setTask(_arg[2])
        end
    end
        , {_group:getName(), _mission}, timer.getTime() + 2)

end

-- are we in pickup zone
function TRPS.inPickupZone(_heli)

    if TRPS.inAir(_heli) then
        return { inZone = false, limit = -1, index = -1 }
    end

    local _heliPoint = _heli:getPoint()

    for _i, _zoneDetails in pairs(TRPS.pickupZones) do

        local _triggerZone = trigger.misc.getZone(_zoneDetails[1])

        if _triggerZone == nil then
            local _ship = TRPS.getTransportUnit(_zoneDetails[1])

            if _ship then
                local _point = _ship:getPoint()
                _triggerZone = {}
                _triggerZone.point = _point
                _triggerZone.radius = 200 -- should be big enough for ship
            end

        end

        if _triggerZone ~= nil then

            --get distance to center

            local _dist = TRPS.getDistance(_heliPoint, _triggerZone.point)

            if _dist <= _triggerZone.radius then
                local _heliCoalition = _heli:getCoalition()
                if _zoneDetails[4] == 1 and (_zoneDetails[5] == _heliCoalition or _zoneDetails[5] == 0) then
                    return { inZone = true, limit = _zoneDetails[3], index = _i }
                end
            end
        end
    end

    local _fobs = TRPS.getSpawnedFobs(_heli)

    -- now check spawned fobs
    for _, _fob in ipairs(_fobs) do

        --get distance to center

        local _dist = TRPS.getDistance(_heliPoint, _fob:getPoint())

        if _dist <= 150 then
            return { inZone = true, limit = 10000, index = -1 };
        end
    end



    return { inZone = false, limit = -1, index = -1 };
end

function TRPS.getSpawnedFobs(_heli)

    local _fobs = {}

    for _, _fobName in ipairs(TRPS.builtFOBS) do

        local _fob = StaticObject.getByName(_fobName)

        if _fob ~= nil and _fob:isExist() and _fob:getCoalition() == _heli:getCoalition() and _fob:getLife() > 0 then

            table.insert(_fobs, _fob)
        end
    end

    return _fobs
end

-- are we in a dropoff zone
function TRPS.inDropoffZone(_heli)

    if TRPS.inAir(_heli) then
        return false
    end

    local _heliPoint = _heli:getPoint()

    for _, _zoneDetails in pairs(TRPS.dropOffZones) do

        local _triggerZone = trigger.misc.getZone(_zoneDetails[1])

        if _triggerZone ~= nil and (_zoneDetails[3] == _heli:getCoalition() or _zoneDetails[3]== 0) then

            --get distance to center

            local _dist = TRPS.getDistance(_heliPoint, _triggerZone.point)

            if _dist <= _triggerZone.radius then
                return true
            end
        end
    end

    return false
end

-- are we in a waypoint zone
function TRPS.inWaypointZone(_point,_coalition)

    for _, _zoneDetails in pairs(TRPS.wpZones) do

        local _triggerZone = trigger.misc.getZone(_zoneDetails[1])

        --right coalition and active?
        if _triggerZone ~= nil and (_zoneDetails[4] == _coalition or _zoneDetails[4]== 0) and _zoneDetails[3] == 1 then

            --get distance to center

            local _dist = TRPS.getDistance(_point, _triggerZone.point)

            if _dist <= _triggerZone.radius then
                return {inZone = true, point = _triggerZone.point, name = _zoneDetails[1]}
            end
        end
    end

    return {inZone = false}
end

-- are we near friendly logistics zone
function TRPS.inLogisticsZone(_heli)

    if TRPS.inAir(_heli) then
        return false
    end

    local _heliPoint = _heli:getPoint()

    for _, _name in pairs(TRPS.logisticUnits) do
		
		local _logistic = nil
		_logistic = Airbase.getByName(_name)
		if not _logistic then
			_logistic = StaticObject.getByName(_name) 
		end

		if _logistic then
			local coaTest = _logistic:getCoalition()
			

			if _logistic ~= nil and _logistic:getCoalition() == _heli:getCoalition() then
				--get distance
				local _dist = TRPS.getDistance(_heliPoint, _logistic:getPoint())

				if _dist <= TRPS.maximumDistanceLogistic then
					return true
					
				end
			end
		end
    end

    return false
end

-- are far enough from a friendly logistics zone
function TRPS.farEnoughFromLogisticZone(_heli)

    if TRPS.inAir(_heli) then
        return false
    end

    local _heliPoint = _heli:getPoint()

    local _farEnough = true

    for _, _name in pairs(TRPS.logisticUnits) do

		local _logistic = nil
		_logistic = Airbase.getByName(_name)
		if not _logistic then
			_logistic = StaticObject.getByName(_name) 
		end

        if _logistic ~= nil and _logistic:getCoalition() == _heli:getCoalition() then

            --get distance
            local _dist = TRPS.getDistance(_heliPoint, _logistic:getPoint())
            -- env.info("DIST ".._dist)
            if _dist <= TRPS.minimumDeployDistance then
                -- env.info("TOO CLOSE ".._dist)
                _farEnough = false
            end
        end
    end

    return _farEnough
end

function TRPS.refreshSmoke()

    if TRPS.disableAllSmoke == true then
        return
    end

    for _, _zoneGroup in pairs({ TRPS.pickupZones, TRPS.dropOffZones }) do

        for _, _zoneDetails in pairs(_zoneGroup) do

            local _triggerZone = trigger.misc.getZone(_zoneDetails[1])

            if _triggerZone == nil then
                local _ship = TRPS.getTransportUnit(_triggerZone)

                if _ship then
                    local _point = _ship:getPoint()
                    _triggerZone = {}
                    _triggerZone.point = _point
                end

            end


            --only trigger if smoke is on AND zone is active
            if _triggerZone ~= nil and _zoneDetails[2] >= 0 and _zoneDetails[4] == 1 then

                -- Trigger smoke markers

                local _pos2 = { x = _triggerZone.point.x, y = _triggerZone.point.z }
                local _alt = land.getHeight(_pos2)
                local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

                trigger.action.smoke(_pos3, _zoneDetails[2])
            end
        end
    end

    --waypoint zones
    for _, _zoneDetails in pairs(TRPS.wpZones) do

        local _triggerZone = trigger.misc.getZone(_zoneDetails[1])

        --only trigger if smoke is on AND zone is active
        if _triggerZone ~= nil and _zoneDetails[2] >= 0 and _zoneDetails[3] == 1 then

            -- Trigger smoke markers

            local _pos2 = { x = _triggerZone.point.x, y = _triggerZone.point.z }
            local _alt = land.getHeight(_pos2)
            local _pos3 = { x = _pos2.x, y = _alt, z = _pos2.y }

            trigger.action.smoke(_pos3, _zoneDetails[2])
        end
    end


    --refresh in 5 minutes
    timer.scheduleFunction(TRPS.refreshSmoke, nil, timer.getTime() + 300)
end

function TRPS.dropSmoke(_args)

    local _heli = TRPS.getTransportUnit(_args[1])

    if _heli ~= nil then

        local _colour = ""

        if _args[2] == trigger.smokeColor.Red then

            _colour = "RED"
        elseif _args[2] == trigger.smokeColor.Blue then

            _colour = "BLUE"
        elseif _args[2] == trigger.smokeColor.Green then

            _colour = "GREEN"
        elseif _args[2] == trigger.smokeColor.Orange then

            _colour = "ORANGE"
        end

        local _point = _heli:getPoint()

        local _pos2 = { x = _point.x, y = _point.z }
        local _alt = land.getHeight(_pos2)
        local _pos3 = { x = _point.x, y = _alt, z = _point.z }

        trigger.action.smoke(_pos3, _args[2])

        trigger.action.outTextForCoalition(_heli:getCoalition(), TRPS.getPlayerNameOrType(_heli) .. " dropped " .. _colour .. " smoke ", 10)
    end
end

function TRPS.unitCanCarryVehicles(_unit)

    local _type = string.lower(_unit:getTypeName())

    for _, _name in ipairs(TRPS.vehicleTransportEnabled) do
        local _nameLower = string.lower(_name)
        if string.match(_type, _nameLower) then
            return true
        end
    end

    return false
end

function TRPS.isJTACUnitType(_type)

    _type = string.lower(_type)

    for _, _name in ipairs(TRPS.jtacUnitTypes) do
        local _nameLower = string.lower(_name)
        if string.match(_type, _nameLower) then
            return true
        end
    end

    return false
end

function TRPS.updateZoneCounter(_index, _diff)

    if TRPS.pickupZones[_index] ~= nil then

        TRPS.pickupZones[_index][3] = TRPS.pickupZones[_index][3] + _diff

        if TRPS.pickupZones[_index][3] < 0 then
            TRPS.pickupZones[_index][3] = 0
        end

        if TRPS.pickupZones[_index][6] ~= nil then
            trigger.action.setUserFlag(TRPS.pickupZones[_index][6], TRPS.pickupZones[_index][3])
        end
        --  env.info(TRPS.pickupZones[_index][1].." = " ..TRPS.pickupZones[_index][3])
    end
end

function TRPS.processCallback(_callbackArgs)

    for _, _callback in pairs(TRPS.callbacks) do

        local _status, _result = pcall(function()

            _callback(_callbackArgs)

        end)

        if (not _status) then
            env.error(string.format("TRPS Callback Error: %s", _result))
        end
    end
end


-- checks the status of all AI troop carriers and auto loads and unloads troops
-- as long as the troops are on the ground
function TRPS.checkAIStatus()

    timer.scheduleFunction(TRPS.checkAIStatus, nil, timer.getTime() + 2)


    for _, _unitName in pairs(TRPS.transportPilotNames) do
        local status, error = pcall(function()

            local _unit = TRPS.getTransportUnit(_unitName)

            -- no player name means AI!
            if _unit ~= nil and _unit:getPlayerName() == nil then
                local _zone = TRPS.inPickupZone(_unit)
                --  env.error("Checking.. ".._unit:getName())
                if _zone.inZone == true and not TRPS.troopsOnboard(_unit, true) then
                    --   env.error("in zone, loading.. ".._unit:getName())

                    if TRPS.allowRandomAiTeamPickups == true then
                        -- Random troop pickup implementation
                        local _team = nil
                        if _unit:getCoalition() == 1 then
                            _team = math.floor((math.random(#TRPS.redTeams * 100) / 100) + 1)
                            TRPS.loadTroopsFromZone({ _unitName, true,TRPS.loadableGroups[TRPS.redTeams[_team]],true })
                        else
                            _team = math.floor((math.random(#TRPS.blueTeams * 100) / 100) + 1)
                            TRPS.loadTroopsFromZone({ _unitName, true,TRPS.loadableGroups[TRPS.blueTeams[_team]],true })
                        end
                    else
                        TRPS.loadTroopsFromZone({ _unitName, true,"",true })
                    end

                elseif TRPS.inDropoffZone(_unit) and TRPS.troopsOnboard(_unit, true) then
                    --     env.error("in dropoff zone, unloading.. ".._unit:getName())
                    TRPS.unloadTroops( { _unitName, true })
                end

                if TRPS.unitCanCarryVehicles(_unit) then

                    if _zone.inZone == true and not TRPS.troopsOnboard(_unit, false) then

                        TRPS.loadTroopsFromZone({ _unitName, false,"",true })

                    elseif TRPS.inDropoffZone(_unit) and TRPS.troopsOnboard(_unit, false) then

                        TRPS.unloadTroops( { _unitName, false })
                    end
                end
            end
        end)

        if (not status) then
            env.error(string.format("Error with ai status: %s", error), false)
        end
    end


end

function TRPS.getTransportLimit(_unitType)

    if TRPS.unitLoadLimits[_unitType] then

        return TRPS.unitLoadLimits[_unitType]
    end

    return TRPS.numberOfTroops

end

function TRPS.getUnitActions(_unitType)

    if TRPS.unitActions[_unitType] then
        return TRPS.unitActions[_unitType]
    end

    return {crates=true,troops=true}

end

-- Adds menuitem to all heli units that are active

function TRPS.addF10MenuOptions()
    -- Loop through all Heli units

    timer.scheduleFunction(TRPS.addF10MenuOptions, nil, timer.getTime() + 10)

    for _, _unitName in pairs(TRPS.transportPilotNames) do

        local status, error = pcall(function()

            local _unit = TRPS.getTransportUnit(_unitName)

            if _unit ~= nil then

                local _groupId = TRPS.getGroupId(_unit)

                if _groupId then

                    if TRPS.addedTo[tostring(_groupId)] == nil then

                        --DSMC_R_basePath = missionCommands.addSubMenuForGroup(_groupId, {"DSMC"})

                        local _rootPath = missionCommands.addSubMenuForGroup(_groupId, "CTLD", {"DSMC"})

                        local _unitActions = TRPS.getUnitActions(_unit:getTypeName())


                        if _unitActions.troops then

                            local _troopCommandsPath = missionCommands.addSubMenuForGroup(_groupId, "Troop Transport", _rootPath)

                            missionCommands.addCommandForGroup(_groupId, "Unload / Extract Troops", _troopCommandsPath, TRPS.unloadExtractTroops, { _unitName })

                            missionCommands.addCommandForGroup(_groupId, "Check Cargo", _troopCommandsPath, TRPS.checkTroopStatus, { _unitName })

                            -- local _loadPath = missionCommands.addSubMenuForGroup(_groupId, "Load From Zone", _troopCommandsPath)
                            for _,_loadGroup in pairs(TRPS.loadableGroups) do
                                if not _loadGroup.side or _loadGroup.side == _unit:getCoalition() then

                                    -- check size & unit
                                    if TRPS.getTransportLimit(_unit:getTypeName()) >= _loadGroup.total then
                                        missionCommands.addCommandForGroup(_groupId, "Load ".._loadGroup.name, _troopCommandsPath, TRPS.loadTroopsFromZone, { _unitName, true,_loadGroup,false })
                                    end
                                end
                            end

                            if TRPS.unitCanCarryVehicles(_unit) then

                                local _vehicleCommandsPath = missionCommands.addSubMenuForGroup(_groupId, "Vehicle / FOB Transport", _rootPath)

                                missionCommands.addCommandForGroup(_groupId, "Unload Vehicles", _vehicleCommandsPath, TRPS.unloadTroops, { _unitName, false })
                                missionCommands.addCommandForGroup(_groupId, "Load / Extract Vehicles", _vehicleCommandsPath, TRPS.loadTroopsFromZone, { _unitName, false,"",true })

                                if TRPS.enabledFOBBuilding and TRPS.staticBugWorkaround == false then

                                    missionCommands.addCommandForGroup(_groupId, "Load / Unload FOB Crate", _vehicleCommandsPath, TRPS.loadUnloadFOBCrate, { _unitName, false })
                                end
                                missionCommands.addCommandForGroup(_groupId, "Check Cargo", _vehicleCommandsPath, TRPS.checkTroopStatus, { _unitName })
                            end

                        end


                        if TRPS.enableCrates and _unitActions.crates then

                            if TRPS.unitCanCarryVehicles(_unit) == false then

                                -- local _cratePath = missionCommands.addSubMenuForGroup(_groupId, "Spawn Crate", _rootPath)
                                -- add menu for spawning crates
                                for _subMenuName, _crates in pairs(TRPS.spawnableCrates) do

                                    local _cratePath = missionCommands.addSubMenuForGroup(_groupId, _subMenuName, _rootPath)
                                    for _, _crate in pairs(_crates) do

                                        if TRPS.isJTACUnitType(_crate.unit) == false
                                                or (TRPS.isJTACUnitType(_crate.unit) == true and TRPS.JTAC_dropEnabled) then
                                            if _crate.side == nil or (_crate.side == _unit:getCoalition()) then

                                                local _crateRadioMsg = _crate.desc

                                                --add in the number of crates required to build something
                                                if _crate.cratesRequired ~= nil and _crate.cratesRequired > 1 then
                                                    _crateRadioMsg = _crateRadioMsg.." (".._crate.cratesRequired..")"
                                                end

                                                missionCommands.addCommandForGroup(_groupId,_crateRadioMsg, _cratePath, TRPS.spawnCrate, { _unitName, _crate.weight })
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if (TRPS.enabledFOBBuilding or TRPS.enableCrates) and _unitActions.crates then

                            local _crateCommands = missionCommands.addSubMenuForGroup(_groupId, "DSMC-CTLD Commands", _rootPath)
                            --if TRPS.hoverPickup == false then
                                if  TRPS.slingLoad == false then
                                    missionCommands.addCommandForGroup(_groupId, "Load Nearby Crate", _crateCommands, TRPS.loadNearbyCrate,  _unitName )
                                end
                            --end

                            missionCommands.addCommandForGroup(_groupId, "Unpack Any Crate", _crateCommands, TRPS.unpackCrates, { _unitName })

                            if TRPS.slingLoad == false then
                                missionCommands.addCommandForGroup(_groupId, "Drop Crate", _crateCommands, TRPS.dropSlingCrate, { _unitName })
                                missionCommands.addCommandForGroup(_groupId, "Current Cargo Status", _crateCommands, TRPS.slingCargoStatus, { _unitName })
                            end

                            missionCommands.addCommandForGroup(_groupId, "List Nearby Crates", _crateCommands, TRPS.listNearbyCrates, { _unitName })

                            if TRPS.enabledFOBBuilding then
                                missionCommands.addCommandForGroup(_groupId, "List FOBs", _crateCommands, TRPS.listFOBS, { _unitName })
                            end
                        end


                        if TRPS.enableSmokeDrop then
                            local _smokeMenu = missionCommands.addSubMenuForGroup(_groupId, "Smoke Markers", _rootPath)
                            missionCommands.addCommandForGroup(_groupId, "Drop Red Smoke", _smokeMenu, TRPS.dropSmoke, { _unitName, trigger.smokeColor.Red })
                            missionCommands.addCommandForGroup(_groupId, "Drop Blue Smoke", _smokeMenu, TRPS.dropSmoke, { _unitName, trigger.smokeColor.Blue })
                            missionCommands.addCommandForGroup(_groupId, "Drop Orange Smoke", _smokeMenu, TRPS.dropSmoke, { _unitName, trigger.smokeColor.Orange })
                            missionCommands.addCommandForGroup(_groupId, "Drop Green Smoke", _smokeMenu, TRPS.dropSmoke, { _unitName, trigger.smokeColor.Green })
                        end

                        if TRPS.enabledRadioBeaconDrop then
                            local _radioCommands = missionCommands.addSubMenuForGroup(_groupId, "Radio Beacons", _rootPath)
                            missionCommands.addCommandForGroup(_groupId, "List Beacons", _radioCommands, TRPS.listRadioBeacons, { _unitName })
                            missionCommands.addCommandForGroup(_groupId, "Drop Beacon", _radioCommands, TRPS.dropRadioBeacon, { _unitName })
                            missionCommands.addCommandForGroup(_groupId, "Remove Closet Beacon", _radioCommands, TRPS.removeRadioBeacon, { _unitName })
                        elseif TRPS.deployedRadioBeacons ~= {} then
                            local _radioCommands = missionCommands.addSubMenuForGroup(_groupId, "Radio Beacons", _rootPath)
                            missionCommands.addCommandForGroup(_groupId, "List Beacons", _radioCommands, TRPS.listRadioBeacons, { _unitName })
                        end

                        TRPS.addedTo[tostring(_groupId)] = true
                    end
                end
            else
                -- env.info(string.format("unit nil %s",_unitName))
            end
        end)

        if (not status) then
            env.error(string.format("Error adding f10 to transport: %s", error), false)
        end
    end

    local status, error = pcall(function()

        -- now do any player controlled aircraft that ARENT transport units
        if TRPS.enabledRadioBeaconDrop then
            -- get all BLUE players
            TRPS.addRadioListCommand(2)

            -- get all RED players
            TRPS.addRadioListCommand(1)
        end


        if TRPS.JTAC_jtacStatusF10 then
            -- get all BLUE players
            TRPS.addJTACRadioCommand(2)

            -- get all RED players
            TRPS.addJTACRadioCommand(1)
        end

    end)

    if (not status) then
        env.error(string.format("Error adding f10 to other players: %s", error), false)
    end


end

--add to all players that arent transport
function TRPS.addRadioListCommand(_side)

    local _players = coalition.getPlayers(_side)

    if _players ~= nil then

        for _, _playerUnit in pairs(_players) do

            local _groupId = TRPS.getGroupId(_playerUnit)

            if _groupId then

                if TRPS.addedTo[tostring(_groupId)] == nil then
                    missionCommands.addCommandForGroup(_groupId, "List Radio Beacons", nil, TRPS.listRadioBeacons, { _playerUnit:getName() })
                    TRPS.addedTo[tostring(_groupId)] = true
                end
            end
        end
    end
end

function TRPS.addJTACRadioCommand(_side)

    local _players = coalition.getPlayers(_side)

    if _players ~= nil then

        for _, _playerUnit in pairs(_players) do

            local _groupId = TRPS.getGroupId(_playerUnit)

            if _groupId then
                --   env.info("adding command for "..index)
                if TRPS.jtacRadioAdded[tostring(_groupId)] == nil then
                    -- env.info("about command for "..index)
                    missionCommands.addCommandForGroup(_groupId, "JTAC Status", nil, TRPS.getJTACStatus, { _playerUnit:getName() })
                    TRPS.jtacRadioAdded[tostring(_groupId)] = true
                    -- env.info("Added command for " .. index)
                end
            end


        end
    end
end

function TRPS.getGroupId(_unit)
	if _unit then
		
		local _group = _unit:getGroup()
		local _groupId = _group:getID()
		return _groupId
	
	end
	
	return nil
    
end

--get distance in meters assuming a Flat world
function TRPS.getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end


------------ JTAC -----------


TRPS.jtacLaserPoints = {}
TRPS.jtacIRPoints = {}
TRPS.jtacSmokeMarks = {}
TRPS.jtacUnits = {} -- list of JTAC units for f10 command
TRPS.jtacStop = {} -- jtacs to tell to stop lasing
TRPS.jtacCurrentTargets = {}
TRPS.jtacRadioAdded = {} --keeps track of who's had the radio command added
TRPS.jtacGeneratedLaserCodes = {} -- keeps track of generated codes, cycles when they run out
TRPS.jtacLaserPointCodes = {}
TRPS.jtacColor = {}

function TRPS.CreateJTAC(group, code)
	local _side = TRPS.getGroup(group)[1]:getCoalition()
	
	TRPS.jtacLaserPointCodes[group] = code
	
	if _side == 1 then
		TRPS.jtacColor[group] = TRPS.JTAC_smokeColour_RED
	else
		TRPS.jtacColor[group] = TRPS.JTAC_smokeColour_BLUE
	end
	
	TRPS.JTACAutoLase(group, code)
						
	if TRPS.deployedJTACs[_side] == nil then
		TRPS.deployedJTACs[_side] = {}
	end
	table.insert(TRPS.deployedJTACs[_side], group)
	
	TRPS.refreshJTACMenu(_side)	
end

function TRPS.changeLaserCode(_args)
	local _SelectedLazingCode = tonumber(_args[2])
	if tonumber(TRPS.jtacLaserPointCodes[_args[1]]) ~= _SelectedLazingCode then
		--TODO: check unit's life
		TRPS.JTACAutoLaseStop(_args[1])
		local _smoke
		if _args[3] == 1 then
			_smoke = TRPS.JTAC_smokeOn_RED
		else
			_smoke = TRPS.JTAC_smokeOn_BLUE
		end
		
		timer.scheduleFunction(TRPS.timerJTACAutoLase, { _args[1], _SelectedLazingCode, _smoke, TRPS.JTAC_lock, TRPS.jtacColor[_args[1]]}, timer.getTime() + 5) --TODO: check interval
		
		TRPS.notifyCoalition(_args[1]..": Changing laser code to ".. _SelectedLazingCode, 10, _args[3])
		
		TRPS.jtacLaserPointCodes[_args[1]] = _SelectedLazingCode
	else
		TRPS.notifyCoalition(_args[1]..": I'm already lazing with code ".. _SelectedLazingCode, 10, _args[3])
	end
end

function TRPS.changeJTACColor(_args)
	if TRPS.GetColorName(TRPS.jtacColor[_args[1]]) ~= _args[2] then
		TRPS.JTACAutoLaseStop(_args[1])
		
		local _smoke
		if _args[3] == 1 then
			_smoke = TRPS.JTAC_smokeOn_RED
		else
			_smoke = TRPS.JTAC_smokeOn_BLUE
		end
		
		local _Color = -1  -- no smoke?
		if _args[2] == "Green" then
			_Color = 0
		elseif _args[2] == "Red" then
			_Color = 1
		elseif _args[2] == "White" then
			_Color = 2
		elseif _args[2] == "Orange" then
			_Color = 3
		elseif _args[2] == "Blue" then
			_Color = 4
		end
		
		timer.scheduleFunction(TRPS.timerJTACAutoLase, { _args[1], TRPS.jtacLaserPointCodes[_args[1]], _smoke, TRPS.JTAC_lock, _Color }, timer.getTime() + 5) --TODO: check interval
			
		TRPS.notifyCoalition(_args[1]..": Changing color to ".._args[2], 10, _args[3])
		
		TRPS.jtacColor[_args[1]] = _Color
	else
		TRPS.notifyCoalition(_args[1]..": Smoke color is already ".._args[2]..".", 10, _args[3])
	end
end

function TRPS.refreshJTACMenu(_side)
	if TRPS.JTACCommandMenuPath[tostring(_side)] ~= nil then
	  missionCommands.removeItemForCoalition(_side, TRPS.JTACCommandMenuPath[tostring(_side)])
	end
	local _JTACMenu
	if next(TRPS.deployedJTACs[_side]) ~= nil then
		_JTACMenu = missionCommands.addSubMenuForCoalition(_side, "JTAC Command", nil)
	else 
		return
	end
	
	TRPS.JTACCommandMenuPath[tostring(_side)] = _JTACMenu
	local itemNo = 0
	--Add one menu item foreach deployed JTAC unit?
	local _JTACMenuItem = {}
	local _JTACMenuItemLaser = {}
	local _JTACMenuItemColor = {}
	for _, _JTACGroup in pairs(TRPS.deployedJTACs[_side]) do
		--local _CurrentLazingCode = TRPS.jtacLaserPointCodes[_JTACGroup]
		--local _CurrentSmokeColor = TRPS.GetColorName(TRPS.jtacColor[_JTACGroup])
		
		_JTACMenuItem[itemNo] = missionCommands.addSubMenuForCoalition(_side, _JTACGroup, _JTACMenu)
			
		--Add laser code submenus
		_JTACMenuItemLaser[itemNo] = missionCommands.addSubMenuForCoalition(_side, "Change laser code", _JTACMenuItem[itemNo])
		for _, _laseCode in pairs(TRPS.laser_codes) do
			missionCommands.addCommandForCoalition(_side, "to ".._laseCode, _JTACMenuItemLaser[itemNo], TRPS.changeLaserCode, { _JTACGroup, _laseCode, _side})
		end
		
		--Add color change submenus
		_JTACMenuItemColor[itemNo] = missionCommands.addSubMenuForCoalition(_side, "Change smoke color", _JTACMenuItem[itemNo])
		for _, _smokeColor in pairs(TRPS.JTAC_smokeColous) do
			missionCommands.addCommandForCoalition(_side, "to ".._smokeColor, _JTACMenuItemColor[itemNo], TRPS.changeJTACColor, { _JTACGroup, _smokeColor, _side})
		end
		itemNo = itemNo + 1
	end
end


function TRPS.JTACAutoLase(_jtacGroupName, _laserCode, _smoke, _lock, _colour)

    if TRPS.jtacStop[_jtacGroupName] == true then
        TRPS.jtacStop[_jtacGroupName] = nil -- allow it to be started again
        TRPS.cleanupJTAC(_jtacGroupName)
        return
    end

    if _lock == nil then

        _lock = TRPS.JTAC_lock
    end


    TRPS.jtacLaserPointCodes[_jtacGroupName] = _laserCode

    local _jtacGroup = TRPS.getGroup(_jtacGroupName)
    local _jtacUnit

    if _jtacGroup == nil or #_jtacGroup == 0 then

        --check not in a heli
        for _, _onboard in pairs(TRPS.inTransitTroops) do
            if _onboard ~= nil then
                if _onboard.troops ~= nil and _onboard.troops.groupName ~= nil and _onboard.troops.groupName == _jtacGroupName then

                    --jtac soldier being transported by heli
                    TRPS.cleanupJTAC(_jtacGroupName)

                    --env.info(_jtacGroupName .. ' in Transport - Waiting 10 seconds')
                    timer.scheduleFunction(TRPS.timerJTACAutoLase, { _jtacGroupName, _laserCode, _smoke, _lock, _colour }, timer.getTime() + 10)
                    return
                end

                if _onboard.vehicles ~= nil and _onboard.vehicles.groupName ~= nil and _onboard.vehicles.groupName == _jtacGroupName then
                    --jtac vehicle being transported by heli
                    TRPS.cleanupJTAC(_jtacGroupName)

                    --env.info(_jtacGroupName .. ' in Transport - Waiting 10 seconds')
                    timer.scheduleFunction(TRPS.timerJTACAutoLase, { _jtacGroupName, _laserCode, _smoke, _lock, _colour }, timer.getTime() + 10)
                    return
                end
            end
        end


        if TRPS.jtacUnits[_jtacGroupName] ~= nil then
			local _side = TRPS.jtacUnits[_jtacGroupName].side
            TRPS.notifyCoalition("JTAC Group " .. _jtacGroupName .. " KIA!", 10, _side)
			
			TRPS.deployedJTACs[_side] = {}
			for _jtacGroupName, _jtacDetails in pairs(TRPS.jtacUnits) do
				_jtacUnit = Unit.getByName(_jtacDetails.name)
				if _jtacUnit ~= nil and _jtacUnit:getLife() > 0 and _jtacUnit:getCoalition() == _side then
					table.insert(TRPS.deployedJTACs[_side], _jtacGroupName)
				end
			end
			TRPS.refreshJTACMenu(TRPS.jtacUnits[_jtacGroupName].side)
		end
		
        --remove from list
        TRPS.jtacUnits[_jtacGroupName] = nil

        TRPS.cleanupJTAC(_jtacGroupName)

        return
    else

        _jtacUnit = _jtacGroup[1]
        --add to list
        TRPS.jtacUnits[_jtacGroupName] = { name = _jtacUnit:getName(), side = _jtacUnit:getCoalition() }

        -- work out smoke colour
        if _colour == nil then

            if _jtacUnit:getCoalition() == 1 then
                _colour = TRPS.JTAC_smokeColour_RED
            else
                _colour = TRPS.JTAC_smokeColour_BLUE
            end
        end


        if _smoke == nil then

            if _jtacUnit:getCoalition() == 1 then
                _smoke = TRPS.JTAC_smokeOn_RED
            else
                _smoke = TRPS.JTAC_smokeOn_BLUE
            end
        end
    end


    -- search for current unit

    if _jtacUnit:isActive() == false then

        TRPS.cleanupJTAC(_jtacGroupName)

        --env.info(_jtacGroupName .. ' Not Active - Waiting 30 seconds')
        timer.scheduleFunction(TRPS.timerJTACAutoLase, { _jtacGroupName, _laserCode, _smoke, _lock, _colour }, timer.getTime() + 30)

        return
    end

    local _enemyUnit = TRPS.getCurrentUnit(_jtacUnit, _jtacGroupName)

    if _enemyUnit == nil and TRPS.jtacCurrentTargets[_jtacGroupName] ~= nil then

        local _tempUnitInfo = TRPS.jtacCurrentTargets[_jtacGroupName]

        --      env.info("TEMP UNIT INFO: " .. tempUnitInfo.name .. " " .. tempUnitInfo.unitType)

        local _tempUnit = Unit.getByName(_tempUnitInfo.name)

        if _tempUnit ~= nil and _tempUnit:getLife() > 0 and _tempUnit:isActive() == true then
            TRPS.notifyCoalition(_jtacGroupName .. " target " .. _tempUnitInfo.unitType .. " lost. Scanning for Targets. ", 10, _jtacUnit:getCoalition())
        else
            TRPS.notifyCoalition(_jtacGroupName .. " target " .. _tempUnitInfo.unitType .. " KIA. Good Job! Scanning for Targets. ", 10, _jtacUnit:getCoalition())
        end

        --remove from smoke list
        TRPS.jtacSmokeMarks[_tempUnitInfo.name] = nil

        -- remove from target list
        TRPS.jtacCurrentTargets[_jtacGroupName] = nil

        --stop lasing
        TRPS.cancelLase(_jtacGroupName)
    end


    if _enemyUnit == nil then
        _enemyUnit = TRPS.findNearestVisibleEnemy(_jtacUnit, _lock)

        if _enemyUnit ~= nil then

            -- store current target for easy lookup
            TRPS.jtacCurrentTargets[_jtacGroupName] = { name = _enemyUnit:getName(), unitType = _enemyUnit:getTypeName(), unitId = _enemyUnit:getID() }

            TRPS.notifyCoalition(_jtacGroupName .. " lasing new target " .. _enemyUnit:getTypeName() .. '. CODE: ' .. _laserCode .. TRPS.getPositionString(_enemyUnit), 10, _jtacUnit:getCoalition())

            -- create smoke
            if _smoke == true then

                --create first smoke
                TRPS.createSmokeMarker(_enemyUnit, _colour)
            end
        end
    end

    if _enemyUnit ~= nil then

        TRPS.laseUnit(_enemyUnit, _jtacUnit, _jtacGroupName, _laserCode)

        --   env.info('Timer timerSparkleLase '..jtacGroupName.." "..laserCode.." "..enemyUnit:getName())
        timer.scheduleFunction(TRPS.timerJTACAutoLase, { _jtacGroupName, _laserCode, _smoke, _lock, _colour }, timer.getTime() + 1)


        if _smoke == true then
            local _nextSmokeTime = TRPS.jtacSmokeMarks[_enemyUnit:getName()]

            --recreate smoke marker after 5 mins
            if _nextSmokeTime ~= nil and _nextSmokeTime < timer.getTime() then

                TRPS.createSmokeMarker(_enemyUnit, _colour)
            end
        end

    else
        -- env.info('LASE: No Enemies Nearby')

        -- stop lazing the old spot
        TRPS.cancelLase(_jtacGroupName)
        --  env.info('Timer Slow timerSparkleLase '..jtacGroupName.." "..laserCode.." "..enemyUnit:getName())

        timer.scheduleFunction(TRPS.timerJTACAutoLase, { _jtacGroupName, _laserCode, _smoke, _lock, _colour }, timer.getTime() + 5)
    end
end

function TRPS.JTACAutoLaseStop(_jtacGroupName)
    TRPS.jtacStop[_jtacGroupName] = true
end

-- used by the timer function
function TRPS.timerJTACAutoLase(_args)

    TRPS.JTACAutoLase(_args[1], _args[2], _args[3], _args[4], _args[5])
end

function TRPS.cleanupJTAC(_jtacGroupName)
    -- clear laser - just in case
    TRPS.cancelLase(_jtacGroupName)

    -- Cleanup
    TRPS.jtacUnits[_jtacGroupName] = nil

    TRPS.jtacCurrentTargets[_jtacGroupName] = nil
end


function TRPS.notifyCoalition(_message, _displayFor, _side)


    trigger.action.outTextForCoalition(_side, _message, _displayFor)
    trigger.action.outSoundForCoalition(_side, "radiobeep.ogg")
end

function TRPS.createSmokeMarker(_enemyUnit, _colour)

    --recreate in 5 mins
    TRPS.jtacSmokeMarks[_enemyUnit:getName()] = timer.getTime() + 300.0

    -- move smoke 2 meters above target for ease
    local _enemyPoint = _enemyUnit:getPoint()
    trigger.action.smoke({ x = _enemyPoint.x, y = _enemyPoint.y + 2.0, z = _enemyPoint.z }, _colour)
end

function TRPS.cancelLase(_jtacGroupName)

    --local index = "JTAC_"..jtacUnit:getID()

    local _tempLase = TRPS.jtacLaserPoints[_jtacGroupName]

    if _tempLase ~= nil then
        Spot.destroy(_tempLase)
        TRPS.jtacLaserPoints[_jtacGroupName] = nil

        --      env.info('Destroy laze  '..index)

        _tempLase = nil
    end

    local _tempIR = TRPS.jtacIRPoints[_jtacGroupName]

    if _tempIR ~= nil then
        Spot.destroy(_tempIR)
        TRPS.jtacIRPoints[_jtacGroupName] = nil

        --  env.info('Destroy laze  '..index)

        _tempIR = nil
    end
end

function TRPS.laseUnit(_enemyUnit, _jtacUnit, _jtacGroupName, _laserCode)

    --cancelLase(jtacGroupName)

    local _spots = {}

    local _enemyVector = _enemyUnit:getPoint()
    local _enemyVectorUpdated = { x = _enemyVector.x, y = _enemyVector.y + 2.0, z = _enemyVector.z }

    local _oldLase = TRPS.jtacLaserPoints[_jtacGroupName]
    local _oldIR = TRPS.jtacIRPoints[_jtacGroupName]

    if _oldLase == nil or _oldIR == nil then

        -- create lase

        local _status, _result = pcall(function()
            _spots['irPoint'] = Spot.createInfraRed(_jtacUnit, { x = 0, y = 2.0, z = 0 }, _enemyVectorUpdated)
            _spots['laserPoint'] = Spot.createLaser(_jtacUnit, { x = 0, y = 2.0, z = 0 }, _enemyVectorUpdated, _laserCode)
            return _spots
        end)

        if not _status then
            env.error('ERROR: ' .. _result, false)
        else
            if _result.irPoint then

                --    env.info(jtacUnit:getName() .. ' placed IR Pointer on '..enemyUnit:getName())

                TRPS.jtacIRPoints[_jtacGroupName] = _result.irPoint --store so we can remove after
            end
            if _result.laserPoint then

                --  env.info(jtacUnit:getName() .. ' is Lasing '..enemyUnit:getName()..'. CODE:'..laserCode)

                TRPS.jtacLaserPoints[_jtacGroupName] = _result.laserPoint
            end
        end

    else

        -- update lase

        if _oldLase ~= nil then
            _oldLase:setPoint(_enemyVectorUpdated)
        end

        if _oldIR ~= nil then
            _oldIR:setPoint(_enemyVectorUpdated)
        end
    end
end

-- get currently selected unit and check they're still in range
function TRPS.getCurrentUnit(_jtacUnit, _jtacGroupName)


    local _unit = nil

    if TRPS.jtacCurrentTargets[_jtacGroupName] ~= nil then
        _unit = Unit.getByName(TRPS.jtacCurrentTargets[_jtacGroupName].name)
    end

    local _tempPoint = nil
    local _tempDist = nil
    local _tempPosition = nil

    local _jtacPosition = _jtacUnit:getPosition()
    local _jtacPoint = _jtacUnit:getPoint()

    if _unit ~= nil and _unit:getLife() > 0 and _unit:isActive() == true then

        -- calc distance
        _tempPoint = _unit:getPoint()
        --   tempPosition = unit:getPosition()

        _tempDist = TRPS.getDistance(_unit:getPoint(), _jtacUnit:getPoint())
        if _tempDist < TRPS.JTAC_maxDistance then
            -- calc visible

            -- check slightly above the target as rounding errors can cause issues, plus the unit has some height anyways
            local _offsetEnemyPos = { x = _tempPoint.x, y = _tempPoint.y + 2.0, z = _tempPoint.z }
            local _offsetJTACPos = { x = _jtacPoint.x, y = _jtacPoint.y + 2.0, z = _jtacPoint.z }

            if land.isVisible(_offsetEnemyPos, _offsetJTACPos) then
                return _unit
            end
        end
    end
    return nil
end


-- Find nearest enemy to JTAC that isn't blocked by terrain
function TRPS.findNearestVisibleEnemy(_jtacUnit, _targetType,_distance)

    --local startTime = os.clock()

    local _maxDistance = _distance or TRPS.JTAC_maxDistance

    local _nearestDistance = _maxDistance

    local _jtacPoint = _jtacUnit:getPoint()
    local _coa =    _jtacUnit:getCoalition()

    local _offsetJTACPos = { x = _jtacPoint.x, y = _jtacPoint.y + 2.0, z = _jtacPoint.z }

    local _volume = {
        id = world.VolumeType.SPHERE,
        params = {
            point = _offsetJTACPos,
            radius = _maxDistance
        }
    }

    local _unitList = {}


    local _search = function(_unit, _coa)
        pcall(function()

            if _unit ~= nil
                    and _unit:getLife() > 0
                    and _unit:isActive()
                    and _unit:getCoalition() ~= _coa
                    and not _unit:inAir()
                    and not TRPS.alreadyTarget(_jtacUnit,_unit) then

                local _tempPoint = _unit:getPoint()
                local _offsetEnemyPos = { x = _tempPoint.x, y = _tempPoint.y + 2.0, z = _tempPoint.z }

                if land.isVisible(_offsetJTACPos,_offsetEnemyPos ) then

                    local _dist = TRPS.getDistance(_offsetJTACPos, _offsetEnemyPos)

                    if _dist < _maxDistance then
                        table.insert(_unitList,{unit=_unit, dist=_dist})

                    end
                end
            end
        end)

        return true
    end

    world.searchObjects(Object.Category.UNIT, _volume, _search, _coa)

    --log.info(string.format("JTAC Search elapsed time: %.4f\n", os.clock() - startTime))

    -- generate list order by distance & visible

    -- first check
    -- hpriority
    -- priority
    -- vehicle
    -- unit

    local _sort = function( a,b ) return a.dist < b.dist end
    table.sort(_unitList,_sort)
    -- sort list

    -- check for hpriority
    for _, _enemyUnit in ipairs(_unitList) do
        local _enemyName = _enemyUnit.unit:getName()

        if string.match(_enemyName, "hpriority") then
            return _enemyUnit.unit
        end
    end

    for _, _enemyUnit in ipairs(_unitList) do
        local _enemyName = _enemyUnit.unit:getName()

        if string.match(_enemyName, "priority") then
            return _enemyUnit.unit
        end
    end

    for _, _enemyUnit in ipairs(_unitList) do
        local _enemyName = _enemyUnit.unit:getName()

        if (_targetType == "vehicle" and TRPS.isVehicle(_enemyUnit.unit)) or _targetType == "all" then
            return _enemyUnit.unit

        elseif (_targetType == "troop" and TRPS.isInfantry(_enemyUnit.unit)) or _targetType == "all" then
            return _enemyUnit.unit
        end
    end

    return nil

end


function TRPS.listNearbyEnemies(_jtacUnit)

    local _maxDistance =  TRPS.JTAC_maxDistance

    local _jtacPoint = _jtacUnit:getPoint()
    local _coa =    _jtacUnit:getCoalition()

    local _offsetJTACPos = { x = _jtacPoint.x, y = _jtacPoint.y + 2.0, z = _jtacPoint.z }

    local _volume = {
        id = world.VolumeType.SPHERE,
        params = {
            point = _offsetJTACPos,
            radius = _maxDistance
        }
    }
    local _enemies = nil

    local _search = function(_unit, _coa)
        pcall(function()

            if _unit ~= nil
                    and _unit:getLife() > 0
                    and _unit:isActive()
                    and _unit:getCoalition() ~= _coa
                    and not _unit:inAir() then

                local _tempPoint = _unit:getPoint()
                local _offsetEnemyPos = { x = _tempPoint.x, y = _tempPoint.y + 2.0, z = _tempPoint.z }

                if land.isVisible(_offsetJTACPos,_offsetEnemyPos ) then

                    if not _enemies then
                        _enemies = {}
                    end

                    _enemies[_unit:getTypeName()] = _unit:getTypeName()

                end
            end
        end)

        return true
    end

    world.searchObjects(Object.Category.UNIT, _volume, _search, _coa)

    return _enemies
end

-- tests whether the unit is targeted by another JTAC
function TRPS.alreadyTarget(_jtacUnit, _enemyUnit)

    for _, _jtacTarget in pairs(TRPS.jtacCurrentTargets) do

        if _jtacTarget.unitId == _enemyUnit:getID() then
            -- env.info("ALREADY TARGET")
            return true
        end
    end

    return false
end


-- Returns only alive units from group but the group / unit may not be active

function TRPS.getGroup(groupName)

    local _groupUnits = Group.getByName(groupName)

    local _filteredUnits = {} --contains alive units
    local _x = 1

    if _groupUnits ~= nil and _groupUnits:isExist() then

        _groupUnits = _groupUnits:getUnits()

        if _groupUnits ~= nil and #_groupUnits > 0 then
            for _x = 1, #_groupUnits do
                if _groupUnits[_x]:getLife() > 0  then -- removed and _groupUnits[_x]:isExist() as isExist doesnt work on single units!
                table.insert(_filteredUnits, _groupUnits[_x])
                end
            end
        end
    end

    return _filteredUnits
end

function TRPS.getAliveGroup(_groupName)

    local _group = Group.getByName(_groupName)

    if _group and _group:isExist() == true and #_group:getUnits() > 0 then
        return _group
    end

    return nil
end

-- gets the JTAC status and displays to coalition units
function TRPS.getJTACStatus(_args)

    --returns the status of all JTAC units

    local _playerUnit = TRPS.getTransportUnit(_args[1])

    if _playerUnit == nil then
        return
    end

    local _side = _playerUnit:getCoalition()

    local _jtacGroupName = nil
    local _jtacUnit = nil

    local _message = "JTAC STATUS: \n\n"

    for _jtacGroupName, _jtacDetails in pairs(TRPS.jtacUnits) do

        --look up units
        _jtacUnit = Unit.getByName(_jtacDetails.name)

        if _jtacUnit ~= nil and _jtacUnit:getLife() > 0 and _jtacUnit:isActive() == true and _jtacUnit:getCoalition() == _side then

            local _enemyUnit = TRPS.getCurrentUnit(_jtacUnit, _jtacGroupName)

            local _laserCode = TRPS.jtacLaserPointCodes[_jtacGroupName]

            if _laserCode == nil then
                _laserCode = "UNKNOWN"
            end

            if _enemyUnit ~= nil and _enemyUnit:getLife() > 0 and _enemyUnit:isActive() == true then
                _message = _message .. "" .. _jtacGroupName .. " targeting " .. _enemyUnit:getTypeName() .. " CODE: " .. _laserCode .. TRPS.getPositionString(_enemyUnit) .. "\n"

                local _list = TRPS.listNearbyEnemies(_jtacUnit)

                if _list then
                    _message = _message.."Visual On: "

                    for _,_type in pairs(_list) do
                        _message = _message.._type.." "
                    end
                    _message = _message.."\n"
                end

            else
                _message = _message .. "" .. _jtacGroupName .. " searching for targets" .. TRPS.getPositionString(_jtacUnit) .. "\n"
            end
        end
    end

    if _message == "JTAC STATUS: \n\n" then
        _message = "No Active JTACs"
    end


    TRPS.notifyCoalition(_message, 10, _side)
end

function TRPS.GetColorName(_Color)
	local _ColorName = "No"
	if _Color == 0 then
		_ColorName = "Green"
	elseif _Color == 1 then
		_ColorName = "Red"
	elseif _Color == 2 then
		_ColorName = "White"
	elseif _Color == 3 then
		_ColorName = "Orange"
	elseif _Color == 4 then
		_ColorName = "Blue"
	end
	return _ColorName
end

function TRPS.isInfantry(_unit)

    local _typeName = _unit:getTypeName()

    --type coerce tostring
    _typeName = string.lower(_typeName .. "")

    local _soldierType = { "infantry", "paratrooper", "stinger", "manpad", "mortar" }

    for _key, _value in pairs(_soldierType) do
        if string.match(_typeName, _value) then
            return true
        end
    end

    return false
end

-- assume anything that isnt soldier is vehicle
function TRPS.isVehicle(_unit)

    if TRPS.isInfantry(_unit) then
        return false
    end

    return true
end

-- The entered value can range from 1111 - 1788,
-- -- but the first digit of the series must be a 1 or 2
-- -- and the last three digits must be between 1 and 8.
--  The range used to be bugged so its not 1 - 8 but 0 - 7.
-- function below will use the range 1-7 just incase
function TRPS.generateLaserCode()

    TRPS.jtacGeneratedLaserCodes = {}

    -- generate list of laser codes
    local _code = 1111

    local _count = 1

    while _code < 1777 and _count < 30 do

        while true do

            _code = _code + 1

            if not TRPS.containsDigit(_code, 8)
                    and not TRPS.containsDigit(_code, 9)
                    and not TRPS.containsDigit(_code, 0) then

                table.insert(TRPS.jtacGeneratedLaserCodes, _code)

                --env.info(_code.." Code")
                break
            end
        end
        _count = _count + 1
    end
end

function TRPS.jtacGetLaserCodeBySide(_side)
	return TRPS.laser_codes[_side]
end


function TRPS.containsDigit(_number, _numberToFind)

    local _thisNumber = _number
    local _thisDigit = 0

    while _thisNumber ~= 0 do

        _thisDigit = _thisNumber % 10
        _thisNumber = math.floor(_thisNumber / 10)

        if _thisDigit == _numberToFind then
            return true
        end
    end

    return false
end

-- 200 - 400 in 10KHz
-- 400 - 850 in 10 KHz
-- 850 - 1250 in 50 KHz
function TRPS.generateVHFrequencies()

    --ignore list
    --list of all frequencies in KHZ that could conflict with
    -- 191 - 1290 KHz, beacon range
    local _skipFrequencies = {
        214,
        274,
        291.5,
        297.50,
        300.50,
		307,
        309.50,
		311,
		312,
        312.50,
		320,
		324,
		326,
		329,
		330,
		337,
        342,
		348,
		352,
        353,
		380,
        381,
        384,
		389,
		395,
		396,
		420,
		430,
        435,
        440,
		455,
		462,
		470,
        485,
		507,
		515,
        520,
        525,
		528,
		577,
        580,
        602,
        625,
		641,
		662,
		670,
		680,
		682,
        690,
		705,
		720,
		722,
		730,
        735,
		740,
		745,
        750,
		770,
        795,
		822,
		830,
		862,
		866,
		905,
		907,
        920,
		935,
		942,
        950,
		995,
		1000,
		1116,
		1025,
		1030,
		1050,
        1065,
        1175,
		1182,
		1210,
    }

    TRPS.freeVHFFrequencies = {}
    local _start = 200000

    -- first range
    while _start < 400000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end


        if _found == false then
            table.insert(TRPS.freeVHFFrequencies, _start)
        end

        _start = _start + 10000
    end

    _start = 400000
    -- second range
    while _start < 850000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end

        if _found == false then
            table.insert(TRPS.freeVHFFrequencies, _start)
        end


        _start = _start + 10000
    end

    _start = 850000
    -- third range
    while _start <= 1250000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end

        if _found == false then
            table.insert(TRPS.freeVHFFrequencies, _start)
        end

        _start = _start + 50000
    end
end

-- 220 - 399 MHZ, increments of 0.5MHZ
function TRPS.generateUHFrequencies()

    TRPS.freeUHFFrequencies = {}
    local _start = 220000000

    while _start < 399000000 do
        table.insert(TRPS.freeUHFFrequencies, _start)
        _start = _start + 500000
    end
end


-- 220 - 399 MHZ, increments of 0.5MHZ
--    -- first digit 3-7MHz
--    -- second digit 0-5KHz
--    -- third digit 0-9
--    -- fourth digit 0 or 5
--    -- times by 10000
--
function TRPS.generateFMFrequencies()

    TRPS.freeFMFrequencies = {}
    local _start = 220000000

    while _start < 399000000 do

        _start = _start + 500000
    end

    for _first = 3, 7 do
        for _second = 0, 5 do
            for _third = 0, 9 do
                local _frequency = ((100 * _first) + (10 * _second) + _third) * 100000 --extra 0 because we didnt bother with 4th digit
                table.insert(TRPS.freeFMFrequencies, _frequency)
            end
        end
    end
end

function TRPS.getPositionString(_unit)

    if TRPS.JTAC_location == false then
        return ""
    end

    local _lat, _lon = coord.LOtoLL(_unit:getPosition().p)

    local _latLngStr = TRPS.tostringLL(_lat, _lon, 3, false)

    local _mgrsString = TRPS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(_unit:getPosition().p)), 5)

    return " @ " .. _latLngStr .. " - MGRS " .. _mgrsString
end


-- ***************** SETUP SCRIPT ****************

TRPS.addedTo = {}
TRPS.spawnedCratesRED = {} -- use to store crates that have been spawned
TRPS.spawnedCratesBLUE = {} -- use to store crates that have been spawned
TRPS.spawnedCratesNEUTRAL = {}

TRPS.droppedTroopsRED = {} -- stores dropped troop groups
TRPS.droppedTroopsBLUE = {} -- stores dropped troop groups
TRPS.droppedTroopsNEUTRAL = {} -- stores dropped troop groups

TRPS.droppedVehiclesRED = {} -- stores vehicle groups for c-130 / hercules
TRPS.droppedVehiclesBLUE = {} -- stores vehicle groups for c-130 / hercules
TRPS.droppedVehiclesNEUTRAL = {} -- stores vehicle groups for c-130 / hercules

TRPS.inTransitTroops = {}

TRPS.inTransitFOBCrates = {}

TRPS.inTransitSlingLoadCrates = {} -- stores crates that are being transported by helicopters for alternative to real slingload

TRPS.droppedFOBCratesRED = {}
TRPS.droppedFOBCratesBLUE = {}
TRPS.droppedFOBCratesNEUTRAL = {}

TRPS.builtFOBS = {} -- stores fully built fobs

TRPS.completeAASystems = {} -- stores complete spawned groups from multiple crates

TRPS.fobBeacons = {} -- stores FOB radio beacon details, refreshed every 60 seconds

TRPS.deployedRadioBeacons = {} -- stores details of deployed radio beacons

TRPS.beaconCount = 1

TRPS.usedUHFFrequencies = {}
TRPS.usedVHFFrequencies = {}
TRPS.usedFMFrequencies = {}

TRPS.freeUHFFrequencies = {}
TRPS.freeVHFFrequencies = {}
TRPS.freeFMFrequencies = {}

--used to lookup what the crate will contain
TRPS.crateLookupTable = {}

TRPS.extractZones = {} -- stored extract zones

TRPS.missionEditorCargoCrates = {} --crates added by mission editor for triggering cratesinzone
--TRPS.hoverStatus = {} -- tracks status of a helis hover above a crate

TRPS.callbacks = {} -- function callback


-- Remove intransit troops when heli / cargo plane dies
--TRPS.eventHandler = {}
--function TRPS.eventHandler:onEvent(_event)
--
--    if _event == nil or _event.initiator == nil then
--        env.info("TRPS null event")
--    elseif _event.id == 9 then
--        -- Pilot dead
--        TRPS.inTransitTroops[_event.initiator:getName()] = nil
--
--    elseif world.event.S_EVENT_EJECTION == _event.id or _event.id == 8 then
--        -- env.info("Event unit - Pilot Ejected or Unit Dead")
--        TRPS.inTransitTroops[_event.initiator:getName()] = nil
--
--        -- env.info(_event.initiator:getName())
--    end
--
--end

-- create crate lookup table
for _subMenuName, _crates in pairs(TRPS.spawnableCrates) do

    for _, _crate in pairs(_crates) do
        -- convert number to string otherwise we'll have a pointless giant
        -- table. String means 'hashmap' so it will only contain the right number of elements
        TRPS.crateLookupTable[tostring(_crate.weight)] = _crate
    end
end


--sort out pickup zones
for _, _zone in pairs(TRPS.pickupZones) do

    local _zoneName = _zone[1]
    local _zoneColor = _zone[2]
    local _zoneActive = _zone[4]

    if _zoneColor == "green" then
        _zone[2] = trigger.smokeColor.Green
    elseif _zoneColor == "red" then
        _zone[2] = trigger.smokeColor.Red
    elseif _zoneColor == "white" then
        _zone[2] = trigger.smokeColor.White
    elseif _zoneColor == "orange" then
        _zone[2] = trigger.smokeColor.Orange
    elseif _zoneColor == "blue" then
        _zone[2] = trigger.smokeColor.Blue
    else
        _zone[2] = -1 -- no smoke colour
    end

    -- add in counter for troops or units
    if _zone[3] == -1 then
        _zone[3] = 10000;
    end

    -- change active to 1 / 0
    if _zoneActive == "yes" then
        _zone[4] = 1
    else
        _zone[4] = 0
    end
end

--sort out dropoff zones
for _, _zone in pairs(TRPS.dropOffZones) do

    local _zoneColor = _zone[2]

    if _zoneColor == "green" then
        _zone[2] = trigger.smokeColor.Green
    elseif _zoneColor == "red" then
        _zone[2] = trigger.smokeColor.Red
    elseif _zoneColor == "white" then
        _zone[2] = trigger.smokeColor.White
    elseif _zoneColor == "orange" then
        _zone[2] = trigger.smokeColor.Orange
    elseif _zoneColor == "blue" then
        _zone[2] = trigger.smokeColor.Blue
    else
        _zone[2] = -1 -- no smoke colour
    end

    --mark as active for refresh smoke logic to work
    _zone[4] = 1
end

--sort out waypoint zones
for _, _zone in pairs(TRPS.wpZones) do

    local _zoneColor = _zone[2]

    if _zoneColor == "green" then
        _zone[2] = trigger.smokeColor.Green
    elseif _zoneColor == "red" then
        _zone[2] = trigger.smokeColor.Red
    elseif _zoneColor == "white" then
        _zone[2] = trigger.smokeColor.White
    elseif _zoneColor == "orange" then
        _zone[2] = trigger.smokeColor.Orange
    elseif _zoneColor == "blue" then
        _zone[2] = trigger.smokeColor.Blue
    else
        _zone[2] = -1 -- no smoke colour
    end

    --mark as active for refresh smoke logic to work
    -- change active to 1 / 0
    if  _zone[3] == "yes" then
        _zone[3] = 1
    else
        _zone[3] = 0
    end
end

-- Sort out extractable groups
for _, _groupName in pairs(TRPS.extractableGroups) do

    local _group = Group.getByName(_groupName)

    if _group ~= nil then

        if _group:getCoalition() == 1 then
            table.insert(TRPS.droppedTroopsRED, _group:getName())
        elseif _group:getCoalition() == 2 then
            table.insert(TRPS.droppedTroopsBLUE, _group:getName())
        else 
            table.insert(TRPS.droppedTroopsNEUTRAL, _group:getName())
        end
    end
end


-- Seperate troop teams into red and blue for random AI pickups
if TRPS.allowRandomAiTeamPickups == true then
    TRPS.redTeams = {}
    TRPS.blueTeams = {}
    for _,_loadGroup in pairs(TRPS.loadableGroups) do
        if not _loadGroup.side then
            table.insert(TRPS.redTeams, _)
            table.insert(TRPS.blueTeams, _)
        elseif _loadGroup.side == 1 then
            table.insert(TRPS.redTeams, _)
        elseif _loadGroup.side == 2 then
            table.insert(TRPS.blueTeams, _)
        end
    end
end

-- add total count

for _,_loadGroup in pairs(TRPS.loadableGroups) do

    _loadGroup.total = 0
    if _loadGroup.aa then
        _loadGroup.total = _loadGroup.aa + _loadGroup.total
    end

    if _loadGroup.inf then
        _loadGroup.total = _loadGroup.inf + _loadGroup.total
    end


    if _loadGroup.mg then
        _loadGroup.total = _loadGroup.mg + _loadGroup.total
    end

    if _loadGroup.at then
        _loadGroup.total = _loadGroup.at + _loadGroup.total
    end

    if _loadGroup.mortar then
        _loadGroup.total = _loadGroup.mortar + _loadGroup.total
    end

end


-- Scheduled functions (run cyclically) -- but hold execution for a second so we can override parts

timer.scheduleFunction(TRPS.checkAIStatus, nil, timer.getTime() + 1)
timer.scheduleFunction(TRPS.checkTransportStatus, nil, timer.getTime() + 5)

timer.scheduleFunction(function()

    timer.scheduleFunction(TRPS.refreshRadioBeacons, nil, timer.getTime() + 5)
    timer.scheduleFunction(TRPS.refreshSmoke, nil, timer.getTime() + 5)
    timer.scheduleFunction(TRPS.addF10MenuOptions, nil, timer.getTime() + 5)

    -- if TRPS.enableCrates == true and TRPS.slingLoad == false and TRPS.hoverPickup == true then
        -- timer.scheduleFunction(TRPS.checkHoverStatus, nil, timer.getTime() + 1)
    -- end

end,nil, timer.getTime()+1 )

--event handler for deaths
--world.addEventHandler(TRPS.eventHandler)

--env.info("TRPS event handler added")

env.info("TRPS Generating Laser Codes")
TRPS.generateLaserCode()
env.info("TRPS Generated Laser Codes")



env.info("TRPS Generating UHF Frequencies")
TRPS.generateUHFrequencies()
env.info("TRPS Generated  UHF Frequencies")

env.info("TRPS Generating VHF Frequencies")
TRPS.generateVHFrequencies()
env.info("TRPS Generated VHF Frequencies")


env.info("TRPS Generating FM Frequencies")
TRPS.generateFMFrequencies()
env.info("TRPS Generated FM Frequencies")

-- Search for crates
-- Crates are NOT returned by coalition.getStaticObjects() for some reason
-- Search for crates in the mission editor instead
env.info("Searching for Crates")
for _coalitionName, _coalitionData in pairs(env.mission.coalition) do
    if (_coalitionName == 'red' or _coalitionName == 'blue')
            and type(_coalitionData) == 'table' then
        if _coalitionData.country then --there is a country table
        for _, _countryData in pairs(_coalitionData.country) do

            if type(_countryData) == 'table' then
                for _objectTypeName, _objectTypeData in pairs(_countryData) do
                    if _objectTypeName == "static" then

                        if ((type(_objectTypeData) == 'table')
                                and _objectTypeData.group
                                and (type(_objectTypeData.group) == 'table')
                                and (#_objectTypeData.group > 0)) then

                            for _groupId, _group in pairs(_objectTypeData.group) do
                                if _group and _group.units and type(_group.units) == 'table' then
                                    for _unitNum, _unit in pairs(_group.units) do
                                        if _unit.canCargo == true then
                                            local _cargoName = env.getValueDictByKey(_unit.name)
											local _weight = env.getValueDictByKey(_unit.mass)				--get the cargo mass
											local _crateType = TRPS.crateLookupTable[tostring(_weight)]		--compare cargi weight to the crate type table
											
											if _coalitionName == 'red' then
												TRPS.spawnedCratesRED[_cargoName] = _crateType				--add cargo based on type
											elseif _coalitionName == 'blue' then
												TRPS.spawnedCratesBLUE[_cargoName] = _crateType
                                            else
                                                TRPS.spawnedCratesNEUTRAL[_cargoName] = _crateType
                                            end
											
                                            TRPS.missionEditorCargoCrates[_cargoName] = _cargoName
                                            --env.info("Crate Found: " .. _unit.name.." - Unit: ".._cargoName)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        end
    end
end
env.info("END search for crates")




--DEBUG FUNCTION
--        for key, value in pairs(getmetatable(_spawnedCrate)) do
--            env.info(tostring(key))
--            env.info(tostring(value))
--        end



--------------- CUSTOM DSMC Code // AUTOMATION --------------------

local debugProcessDetail = true

-- add any spawned helicopter, APC or IFV as transport
TRPS.AddHeloOnBirth = {}
function TRPS.AddHeloOnBirth:onEvent(event)	
	if event.id == world.event.S_EVENT_BIRTH and event.initiator then
		if Object.getCategory(event.initiator) == 1 then
			if debugProcessDetail then
				env.info(ModuleName .. " AddHeloOnBirth unit identified")
			end
			
			local unit 			= event.initiator
			if unit then
				local unitID = unit:getID()	
				local unitName = unit:getName()				
				if debugProcessDetail then
					env.info(ModuleName .. " AddHeloOnBirth unit ID " .. tostring(unitID) .. " evaluated")
				end						
				if unit:hasAttribute("Helicopters") then
					table.insert(TRPS.transportPilotNames, unitName)
					--tblTransportsUnit[unitID] = {id = unit:getID(), name = unit:getName(), unitType = unit:getTypeName(), air = true, coa = unit:getCoalition()}
					if debugProcessDetail then
						env.info(ModuleName .. " AddHeloOnBirth unit " .. tostring(unitName) .. " is an helo, tblTransportsUnit updated")
					end
				elseif unit:hasAttribute("APC") or unit:hasAttribute("IFV") then
					table.insert(TRPS.transportPilotNames, unitName)
					--tblTransportsUnit[unitID] = {id = unit:getID(), name = unit:getName(), unitType = unit:getTypeName(), air = false, coa = unit:getCoalition()}
					if debugProcessDetail then
						env.info(ModuleName .. " AddHeloOnBirth unit " .. tostring(unitName) .. " is an APC or IFV, tblTransportsUnit updated")
					end
				end	
			end
		end
	end
end
world.addEventHandler(TRPS.AddHeloOnBirth)

TRPS.AddInfantriesOnBirth = {}
function TRPS.AddInfantriesOnBirth:onEvent(event)	
	if event.id == world.event.S_EVENT_BIRTH and event.initiator then
		if Object.getCategory(event.initiator) == 1 then
			if debugProcessDetail then
				env.info(ModuleName .. " AddInfantriesOnBirth unit identified")
			end			
			local unit = event.initiator
			if unit then
				local unitID = unit:getID()
				if debugProcessDetail then
					env.info(ModuleName .. " AddInfantriesOnBirth unit ID " .. tostring(unitID) .. " evaluated")
				end					
				if unit:hasAttribute("Infantry") then
					if debugProcessDetail then
						env.info(ModuleName .. " AddInfantriesOnBirth unit " .. tostring(unit:getName()) .. " is an infantry, evaluating group composition")
					end
					
					local group = unit:getGroup()
					if group then
						local countTot = 0
						local countInf = 0
						for units_id, units_data in pairs(group:getUnits()) do
							countTot = countTot + 1
							if units_data:hasAttribute("Infantry") then -- right?
								countInf = countInf +1
							end
						end
						
						if countInf == countTot then
							if debugProcessDetail then
								env.info(ModuleName .. " AddInfantriesOnBirth all units in the group are infantry")
							end

							local groupID = group:getID()
							local groupName = group:getName()
							local placefree = true
							if not TRPS.extractableGroups[groupName] then
								table.insert(TRPS.extractableGroups, groupName)
								env.info(ModuleName .. " AddInfantriesOnBirth group of units added as extractable")
							end
						end
					end
				end
			else
				if debugProcessDetail then
					env.info(ModuleName .. " AddInfantriesOnBirth unit table not available")
				end				
			end
		end
	end
end
world.addEventHandler(TRPS.AddInfantriesOnBirth)

function TRPS.AddTroopsToVehicles(_unit, _numberOrTemplate)

    local _onboard = TRPS.inTransitTroops[_unit:getName()]

    --number doesnt apply to vehicles
    if _numberOrTemplate == nil  or (type(_numberOrTemplate) ~= "table" and type(_numberOrTemplate) ~= "number")  then
        _numberOrTemplate = TRPS.numberOfTroops
    end

    if _onboard == nil then
        _onboard = { troops = {}, vehicles = {} }
    end

    local _list
    if _unit:getCoalition() == 1 then
        _list = TRPS.vehiclesForTransportRED
    else
        _list = TRPS.vehiclesForTransportBLUE
    end

	_onboard.troops = TRPS.generateTroopTypes(_unit:getCoalition(), _numberOrTemplate, _unit:getCountry())
	
	trigger.action.outTextForCoalition(_unit:getCoalition(), TRPS.getPlayerNameOrType(_unit) .. " loaded troops into " .. _unit:getTypeName(), 10)
	TRPS.processCallback({unit = _unit, onboard = _onboard.troops, action = "load_troops"})		
    TRPS.inTransitTroops[_unit:getName()] = _onboard
end

-- REDO
function TRPS.updateCTLDTables()
	env.info(ModuleName .. " updateTroopsTables looking for ME helo, IFV, APC for add transport table and infantry groups")
	for _coalitionName, _coalitionData in pairs(env.mission.coalition) do		
		if (_coalitionName == 'red' or _coalitionName == 'blue')
				and type(_coalitionData) == 'table' then
			if _coalitionData.country then --there is a country table
				for _, _countryData in pairs(_coalitionData.country) do

					if type(_countryData) == 'table' then
						for _objectTypeName, _objectTypeData in pairs(_countryData) do
							if _objectTypeName == "vehicle" or _objectTypeName == "helicopter" then

								if ((type(_objectTypeData) == 'table')
										and _objectTypeData.group
										and (type(_objectTypeData.group) == 'table')
										and (#_objectTypeData.group > 0)) then

									for _groupId, _group in pairs(_objectTypeData.group) do
										if _group and _group.units and type(_group.units) == 'table' then
											local infantryCount = 0
											local unitCount = 0										
											local groupName = env.getValueDictByKey(_group.name)
											local Table_group = Group.getByName(groupName)
                                            local check_JTAC = false
                                            if Table_group then
												local Table_group_ID = Table_group:getID()
																			
												for _unitNum, _unit in pairs(_group.units) do
													if _unitNum == 1 then
														local unitName = env.getValueDictByKey(_unit.name)
														if unitName then
															local unit = Unit.getByName(unitName)
															if unit then
																if unit:getLife() > 0 then
																	unitCount = unitCount + 1
																	local unitID = unit:getID()
																	if unit:hasAttribute("APC") or unit:hasAttribute("IFV") then -- preload a ground group in everyone
																		table.insert(TRPS.transportPilotNames, unitName)
																		--tblTransportsUnit[unitID] = {id = unitID, name = unitName, unitType = unit:getTypeName(), air = false, coa = unit:getCoalition()}
																		if debugProcessDetail then
																			trigger.action.outText(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is an APC or IFV, TRPS.transportPilotNames updated", 10)
																			env.info(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is an APC or IFV, TRPS.transportPilotNames updated")
																		end
																		
																		if TRPS.useNameCoding then
																			local tableTemplate = nil
																			if string.find(groupName, "_ads") then -- adding Manpads														
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Anti Air" then
																						tableTemplate = TableBase
																					end
																				end
																				env.info(ModuleName .. " Added Anti Air infantry")
																			elseif string.find(groupName, "_rpg") then -- adding RPGs
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Anti Tank" then
																						tableTemplate = TableBase
																					end
																				end
																				env.info(ModuleName .. " Added Anti Tank infantry")
																			elseif string.find(groupName, "_mtr") then -- adding Mortars
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Mortar Squad" then
																						tableTemplate = TableBase
																					end
																				end
																				env.info("Added Mortar Squad infantry")																								
																			elseif string.find(groupName, "_rec") then -- leaving void (recon unit)
																				env.info(ModuleName .. " Added nothing: recon unit")																								
																			else
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Standard Group" then
																						tableTemplate = TableBase
																					end
																				end
																				env.info(ModuleName .. " Added Standard Group infantry")																								
																			end
																			
																			if tableTemplate then
																				TRPS.AddTroopsToVehicles(unit, tableTemplate)
																			end
																		else
																			local _adsThereshold = 6 -- 5% anti air
																			local _rpgThereshold = 16 -- 10% rpg
																			local _mtrThereshold = 26 -- 10% mortar
																			local _recThereshold = 36 -- 10% no infantry
																			-- 65% standard infantry
																			local thereshold = math.random(0,100)

																			if debugProcessDetail then
																				env.info(ModuleName .. " updateTroopsTables: thereshold " .. tostring(thereshold))
																			end																			
																			
																			local tableTemplate = nil
																			if thereshold < _adsThereshold then -- adding Manpads														
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Anti Air" then
																						tableTemplate = TableBase
																					end
																				end
																				--env.info(ModuleName .. " updateTroopsTables: Added Anti Air infantry")
																			elseif thereshold < _rpgThereshold then -- adding RPGs
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Anti Tank" then
																						tableTemplate = TableBase
																					end
																				end
																				--env.info(ModuleName .. " updateTroopsTables: Added Anti Tank infantry")
																			elseif thereshold < _mtrThereshold then -- adding Mortars
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Mortar Squad" then
																						tableTemplate = TableBase
																					end
																				end
																				--env.info(ModuleName .. " updateTroopsTables: Added Mortar Squad infantry")																								
																			elseif thereshold < _recThereshold then -- leaving void (recon unit)
																				--env.info(ModuleName .. " updateTroopsTables: Added nothing: recon unit")																								
																			else
																				for _id, TableBase in pairs(TRPS.loadableGroups) do
																					if TableBase.name == "Standard Group" then
																						tableTemplate = TableBase
																					end
																				end
																				--env.info(ModuleName .. " updateTroopsTables: Added Standard Group infantry")																								
																			end
																			
																			if tableTemplate then
																				TRPS.AddTroopsToVehicles(unit, tableTemplate)
																			end																		
																		end
																		
																	elseif unit:hasAttribute("Helicopters") then
																		table.insert(TRPS.transportPilotNames, unitName)
																		--tblTransportsUnit[unitID] = {id = unit:getID(), name = unitName, unitType = unit:getTypeName(), air = true, coa = unit:getCoalition()}
																		if debugProcessDetail then
																			trigger.action.outText(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is an helo, TRPS.transportPilotNames updated", 10)
																			env.info(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is an helo, TRPS.transportPilotNames updated")
																		end																							
																	
																	elseif unit:hasAttribute("Infantry") then
                                                                        infantryCount = infantryCount +1
                                                                        if unit:hasAttribute("MANPADS") then
                                                                            check_JTAC = true
                                                                        end
																	end
																end
															end
														end
													end
												end
											end
											
											if infantryCount == unitCount then -- make group with only infantry transportable by default
                                                if infantryCount == 1 and check_JTAC == true then
                                                    if debugProcessDetail then
                                                        env.info(ModuleName .. " updateTroopsTables: groupName " .. tostring(groupName) .. " is a single infantry group, MANPAD, infantryCount = " .. tostring(infantryCount))
                                                    end	
                                                    local _group = Table_group
                                                    local _side = _group:getCoalition()
                                                    local _code = TRPS.jtacGetLaserCodeBySide(_side)
                                                    TRPS.CreateJTAC(groupName, _code)
                                                    TRPS.addRETURNFIREOption(_group)

                                                else
                                                    if debugProcessDetail then
                                                        env.info(ModuleName .. " updateTroopsTables: groupName " .. tostring(groupName) .. " is a full infantry group, infantryCount = " .. tostring(infantryCount))
                                                    end												
                                                    local groupTable = Group.getByName(groupName)
                                                    if groupTable then												
                                                        if not TRPS.extractableGroups[groupName] then
                                                            table.insert(TRPS.extractableGroups, groupName)
                                                            env.info(ModuleName .. " updateTroopsTables: group ".. tostring(groupName) .. " of units added as extractable")													
                                                        end
                                                    end
                                                end
											end
										end
									end
								end
							elseif _objectTypeName == "static" then
								if ((type(_objectTypeData) == 'table')
										and _objectTypeData.group
										and (type(_objectTypeData.group) == 'table')
										and (#_objectTypeData.group > 0)) then
									for _groupId, _group in pairs(_objectTypeData.group) do
										if _group and _group.units and type(_group.units) == 'table' then								
											for _unitNum, _unit in pairs(_group.units) do
												if _unitNum == 1 then		
													local unitName = env.getValueDictByKey(_unit.name)
													if unitName then						
                                                        --env.info(ModuleName .. " updateTroopsTables: checking static unit " .. tostring(unitName) .. ", category: " .. tostring(_unit.category))
                                                        if _unit.category == "Warehouses" then
															table.insert(TRPS.logisticUnits, unitName)												
															env.info(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is a warehouse, TRPS.logisticUnits updated")																
                                                        
                                                        elseif _unit.category == "Fortifications" and _unit.type == "outpost" then           
                                                            env.info(ModuleName .. " updateTroopsTables: checking FOB, found outpost object")	
                                                            local stObject = StaticObject.getByName(unitName)
															if stObject then																	
																local centerposUnit = stObject:getPosition().p
																if centerposUnit then
																	env.info(ModuleName .. " updateTroopsTables: checking FOB, outpost has position")
																	 
																	local foundUnits = {}
																	local volS = {
																	  id = world.VolumeType.SPHERE,
																	  params = {
																		point = centerposUnit,
																		radius = 150
																	  }
																	}
																	
																	local ifFound = function(foundItem, val)
																		env.info(ModuleName .. " updateTroopsTables: checking FOB, proximity object found")	                                                            
																		if foundItem:getTypeName() == "TACAN_beacon" then
																			env.info(ModuleName .. " updateTroopsTables: checking FOB, object is a beacon")	 
																			foundUnits[#foundUnits + 1] = foundItem:getName()
																			return true
																		end
																	end                                                           
																	world.searchObjects(Object.Category.UNIT, volS, ifFound)
																	
																	if table.getn(foundUnits) > 0 then -- there's a beacon nearby an outpost: it's a FOB                                                            
																		
																		--adding FOB
																		table.insert(TRPS.logisticUnits, unitName)
																		env.info(ModuleName .. " updateTroopsTables: checking FOB, outpost added as FOB")	 
																		if TRPS.troopPickupAtFOB == true then
																			table.insert(TRPS.builtFOBS, unitName)			
																		end							
																		env.info(ModuleName .. " updateTroopsTables: unit " .. tostring(unitName) .. " is an outpost, TRPS.logisticUnits updated")	                                                            
																		
																		--adding Beacon functionality
																		for fId, fData in pairs(foundUnits) do
																			if fId == 1 then
																				local fObject = Unit.getByName(fData)
																				local fPoint = fObject:getPosition().p

																				if fPoint then
																					--check proximity to FOB here
						
																					local FOBname           = unitName
																					TRPS.beaconCount        = TRPS.beaconCount + 1
																					local _point            = {x = fPoint.x, y = fPoint.z}
																					local _country          = StaticObject.getByName(unitName):getCountry()
																					local _coalition        = StaticObject.getByName(unitName):getCoalition()
																					local _radioBeaconName  = FOBname .. " beacon #" .. TRPS.beaconCount                   
																					
																					local _freq = TRPS.generateADFFrequencies()
						
																					local _battery = -1                                                    
																					local _lat, _lon = coord.LOtoLL(_point)
																					local _latLngStr = TRPS.tostringLL(_lat, _lon, 3, false)
																					local _message = _radioBeaconName
																					_message = _message .. " - " .. _latLngStr
																					_message = string.format("%s - %.2f KHz", _message, _freq.vhf / 1000)
																					_message = string.format("%s - %.2f MHz", _message, _freq.uhf / 1000000)                                                        
																					_message = string.format("%s - %.2f MHz ", _message, _freq.fm / 1000000)                                                            
						
																					local _beaconDetails = {
																						vhf = _freq.vhf,
																						vhfGroup = unitName,
																						uhf = _freq.uhf,
																						uhfGroup = unitName,
																						fm = _freq.fm,
																						fmGroup = unitName,
																						text = _message,
																						battery = _battery,
																						coalition = _coalition,
																					}
																					TRPS.updateRadioBeacon(_beaconDetails)
																					table.insert(TRPS.deployedRadioBeacons, _beaconDetails)                                           
																					TRPS.fobBeacons[unitName] = { vhf = _beaconDetails.vhf, uhf = _beaconDetails.uhf, fm = _beaconDetails.fm }
																					env.info(ModuleName .. " updateTroopsTables: checking FOB, beacon added")	
																				end
																			end
																		end
																	end
																end
															end
                                                        end
													end
												end
											end
										end
									end
								end							
							end
						end
					end
				end
			end
		end
	end
	env.info(ModuleName .. " updateTroopsTables done")
end

function TRPS.updateLogisticTableWithAirport()
	local apt_Table = world.getAirbases()
	if apt_Table then
		for Aid, Adata in pairs(apt_Table) do
			local aptName = Adata:getName()	
			if debugProcessDetail then
				env.info(ModuleName .. " updateLogisticTables: checking " .. tostring(aptName))
			end
			local unitTbl = Unit.getByName(aptName)
			if unitTbl then
				if type(unitTbl) == 'table' then
					table.insert(TRPS.logisticUnits, aptName)
					if debugProcessDetail then
						trigger.action.outText("DSMC-CTLD: " .. tostring(aptName) .. " airbase is a logistic site available for operations", 10)
						env.info(ModuleName .. " updateLogisticTables: " .. tostring(aptName) .. " airbase is a logistic unit")
					end				
				end
			end
		end
	end
end

TRPS.updateCTLDTables()
--TRPS.updateLogisticTableWithAirport()

-- Sort out extractable groups
for _, _groupName in pairs(TRPS.extractableGroups) do

    local _group = Group.getByName(_groupName)

    if _group ~= nil then

        if _group:getCoalition() == 1 then
            table.insert(TRPS.droppedTroopsRED, _group:getName())
        elseif _group:getCoalition() == 2 then
            table.insert(TRPS.droppedTroopsBLUE, _group:getName())
        else 
            table.insert(TRPS.droppedTroopsNEUTRAL, _group:getName())
        end
    end
end

env.info("TRPS READY")