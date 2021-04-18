-- Dynamic Sequential Mission Campaign -- TRACK SPAWNED module

local ModuleName  	= "SLOT"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('SLOT', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')
local ME_DB   		= require('me_db_api')
local ME_U			= require('me_utilities')
local Terrain		= require('terrain')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
SLOTloaded						= false
local addedGroups				= 0
local addedunits				= 0
local tblSlots					= {}
local MaxSlotsPerHeliport		= 4 -- maximum number of created slots per heliport that could be generated. Not related to airport/airbase
local MaxFlightPerAirport		= 2
local slotOnAirbasePerType		= 2

-- ## MANUAL TABLES
local standardUnitTypes = {
    ["Ka-50"] = {	
		["alt"] = 0,
		["alt_type"] = "BARO",		
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["type"] = "Ka-50",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[7] = 40,
					[1] = 21.5,
					[2] = 25.7,
					[4] = 28,
					[8] = 50,
					[9] = 55.5,
					[5] = 30,
					[10] = 59.9,
					[3] = 27,
					[6] = 32,
				}, -- end of ["channels"]
			}, -- end of [1]
			[2] = 
			{
				["modulations"] = 
				{
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[11] = 0.718,
					[13] = 0.583,
					[7] = 0.443,
					[1] = 0.625,
					[2] = 0.303,
					[15] = 0.995,
					[8] = 0.215,
					[16] = 1.21,
					[9] = 0.525,
					[5] = 0.408,
					[10] = 1.065,
					[14] = 0.283,
					[3] = 0.289,
					[6] = 0.803,
					[12] = 0.35,
					[4] = 0.591,
				}, -- end of ["channels"]
			}, -- end of [2]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = "0", -- "0"
			["flare"] = 128,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [Ka-50]
	["Mi-8MT"] = 
	{
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["AddPropAircraft"] = 
		{
			["LeftEngineResource"] = 90,
			["RightEngineResource"] = 90,
			["NetCrewControlPriority"] = 1,
			["ExhaustScreen"] = true,
			["CargoHalfdoor"] = true,
			["GunnersAISkill"] = 90,
			["AdditionalArmor"] = true,
			["NS430allow"] = true,
		}, -- end of ["AddPropAircraft"]
		["type"] = "Mi-8MT",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[1] = 127.5,
					[2] = 135,
					[4] = 127,
					[8] = 128,
					[16] = 132,
					[17] = 138,
					[9] = 126,
					[18] = 122,
					[5] = 125,
					[10] = 133,
					[20] = 137,
					[11] = 130,
					[3] = 136,
					[6] = 121,
					[12] = 129,
					[13] = 123,
					[7] = 141,
					[14] = 131,
					[15] = 134,
					[19] = 124,
				}, -- end of ["channels"]
			}, -- end of [1]
			[2] = 
			{
				["modulations"] = 
				{
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[7] = 40,
					[1] = 21.5,
					[2] = 25.7,
					[4] = 28,
					[8] = 50,
					[9] = 55.5,
					[5] = 30,
					[10] = 59.9,
					[3] = 27,
					[6] = 32,
				}, -- end of ["channels"]
			}, -- end of [2]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = "0",
			["flare"] = 128,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
	["UH-1H"] = 
	{
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["AddPropAircraft"] = 
		{
			["EngineResource"] = 90,
			["NetCrewControlPriority"] = 1,
			["GunnersAISkill"] = 90,
			["ExhaustScreen"] = true,
		}, -- end of ["AddPropAircraft"]
		["type"] = "UH-1H",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[1] = 251,
					[2] = 264,
					[4] = 256,
					[8] = 257,
					[16] = 261,
					[17] = 267,
					[9] = 255,
					[18] = 251,
					[5] = 254,
					[10] = 262,
					[20] = 266,
					[11] = 259,
					[3] = 265,
					[6] = 250,
					[12] = 268,
					[13] = 269,
					[7] = 270,
					[14] = 260,
					[15] = 263,
					[19] = 253,
				}, -- end of ["channels"]
			}, -- end of [1]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = "0",
			["flare"] = 60,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
	["SA342L"] = 
	{	
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["type"] = "SA342L",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
					[6] = 0,
					[2] = 0,
					[8] = 0,
					[3] = 0,
					[1] = 0,
					[4] = 0,
					[5] = 0,
					[7] = 0,
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[6] = 41,
					[2] = 31,
					[8] = 50,
					[3] = 32,
					[1] = 30,
					[4] = 33,
					[5] = 40,
					[7] = 42,
				}, -- end of ["channels"]
			}, -- end of [1]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = 0,
			["flare"] = 32,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
	["SA342M"] = 
	{	
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["type"] = "SA342M",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
					[6] = 0,
					[2] = 0,
					[8] = 0,
					[3] = 0,
					[1] = 0,
					[4] = 0,
					[5] = 0,
					[7] = 0,
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[6] = 41,
					[2] = 31,
					[8] = 50,
					[3] = 32,
					[1] = 30,
					[4] = 33,
					[5] = 40,
					[7] = 42,
				}, -- end of ["channels"]
			}, -- end of [1]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = 0,
			["flare"] = 32,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
	["SA342Minigun"] = 
	{
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["type"] = "SA342Minigun",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
					[6] = 0,
					[2] = 0,
					[8] = 0,
					[3] = 0,
					[1] = 0,
					[4] = 0,
					[5] = 0,
					[7] = 0,
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[6] = 41,
					[2] = 31,
					[8] = 50,
					[3] = 32,
					[1] = 30,
					[4] = 33,
					[5] = 40,
					[7] = 42,
				}, -- end of ["channels"]
			}, -- end of [1]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = 0,
			["flare"] = 32,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
	["SA342Mistral"] = 
	{
		["hardpoint_racks"] = true,
		["alt_type"] = "BARO",
		["ropeLength"] = 15,
		["speed"] = 41.666666666667,
		["type"] = "SA342Mistral",
		["Radio"] = 
		{
			[1] = 
			{
				["modulations"] = 
				{
					[6] = 0,
					[2] = 0,
					[8] = 0,
					[3] = 0,
					[1] = 0,
					[4] = 0,
					[5] = 0,
					[7] = 0,
				}, -- end of ["modulations"]
				["channels"] = 
				{
					[6] = 41,
					[2] = 31,
					[8] = 50,
					[3] = 32,
					[1] = 30,
					[4] = 33,
					[5] = 40,
					[7] = 42,
				}, -- end of ["channels"]
			}, -- end of [1]
		}, -- end of ["Radio"]
		["psi"] = 0,
		["payload"] = 
		{
			["pylons"] = 
			{
			}, -- end of ["pylons"]
			["fuel"] = 0,
			["flare"] = 32,
			["chaff"] = 0,
			["gun"] = 100,
		}, -- end of ["payload"]
		["callsign"] = 
		{
			[1] = 1,
			[2] = 1,
			[3] = 1,
			["name"] = "Enfield11",
		}, -- end of ["callsign"]
		["onboard_num"] = "050",
	}, -- end of [1]
}

local permitAll = false
if HOOK.SLOT_coa_var == "all" then
	permitAll = true
	HOOK.writeDebugDetail(ModuleName .. ": all coalition will create slots")
end

function getRightParkingAirport(a_listP, uType, uCat)
	local keepList = {}
	--HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a1")
	HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a_listP pre:" .. tostring(#a_listP))
    local unitDesc = ME_DB.unit_by_type[uType]
    --HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a2")
    local HEIGHT = unitDesc.height
    local WIDTH  = unitDesc.wing_span or unitDesc.rotor_diameter
    local LENGTH = unitDesc.length
    --HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a3")
    for k, v in pairs(a_listP) do
        --print("------name---",v.name)
        --print("---type=",group.units[1].type,"--WIDTH=",WIDTH,"--LENGTH=",LENGTH,"--HEIGHT",HEIGHT)
        --print("---in terrain-----WIDTH=",v.params.WIDTH,"--LENGTH=",v.params.LENGTH,"--HEIGHT",v.params.HEIGHT,"---FOR_HELICOPTERS---",v.params.FOR_HELICOPTERS)
		if (not((WIDTH < v.params.WIDTH) 
                and (LENGTH < v.params.LENGTH)
                and (HEIGHT < (v.params.HEIGHT or 1000)))) 
			or ((uCat == 'helicopter') and (v.params.FOR_HELICOPTERS == 0))
            or ((uCat == 'plane') and (v.params.FOR_AIRPLANES == 0))    then
			table.insert(keepList, k)
			--HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a4")
		end
	end
	
	for k,v in pairs(keepList) do
		a_listP[tonumber(v)] = nil
	end
	--HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a5")
	HOOK.writeDebugDetail(ModuleName .. ": getRightParkingAirport, a_listP post:" .. tostring(#a_listP))
	return a_listP
end

function getFirstFreeParkingSpot(availParkList, airportID, parkListComplete)
	--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot started")	
	HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot, parkListComplete pre:" .. tostring(#parkListComplete))

	if #parkListComplete > 0 then
		-- get latest park position
		local usedPname = nil
		local usedPx = nil
		local usedPy = nil
		local max_pId = 0
		for pId, pData in pairs(availParkList) do
			--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot c5")
			if pId > max_pId then
				--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot c6")
				max_pId		= pId
				usedPname 	= pData.name
				usedPx	 	= pData.x
				usedPy	  	= pData.y
			end
		end
		
		--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot, usedPname: " .. tostring(usedPname) .. ", usedPx: " .. tostring(usedPx) .. ", usedPy: " .. tostring(usedPy))
		if usedPname and usedPx and usedPy then
			for pkId, pkData in pairs(parkListComplete) do		
				if pkData.name == usedPname then
					parkListComplete[pkId] = nil
				end
			end
			--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot added used parking spot to " ..tostring(airportID) .. ", park num = " ..tostring(usedPname))
			HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot, parkListComplete post:" .. tostring(#parkListComplete))
			return usedPname, usedPx, usedPy, parkListComplete
		else
			--HOOK.writeDebugDetail(ModuleName .. ": getFirstFreeParkingSpot no parking available")	
			return false
		end
	else
		return false
	end
end

function getMaxHeliParkingAvailable(airportID)
	for id, data in pairs(tblAirbases) do 
		if data.index == airportID then
			local parkAvail = 0 
			if data.parkings then
				for pId, pData in pairs(data.parkings) do
					if pData.params.FOR_HELICOPTERS == 1 then
						parkAvail = parkAvail + 1
					end
				end

				return parkAvail
			else
				HOOK.writeDebugBase(ModuleName .. ": getMaxHeliParkingAvailable, no parkings")
				return 0
			end
		end
	end
end

function createGroups(mission, dictionary)
	local maxG, maxU = setMaxId(mission)
	local MaxDict = mission.maxDictId

	if #tblSlots > 0 then
		HOOK.writeDebugDetail(ModuleName .. ": createGroups, tblSlots entries: " .. tostring(#tblSlots))
		for sId, sData in pairs(tblSlots) do
			HOOK.writeDebugDetail(ModuleName .. ": createGroups, checking slot: " .. tostring(sId))
			-- looking for right address to insert the group
			for coalitionID,coalition in pairs(mission["coalition"]) do
				if string.lower(sData.coaID) == string.lower(coalitionID) then
					HOOK.writeDebugDetail(ModuleName .. ": createGroups, coalition found: " .. tostring(coalitionID))
					for countryID,country in pairs(coalition["country"]) do
						if sData.cntyID == country.id then			
							HOOK.writeDebugDetail(ModuleName .. ": createGroups, country found: " .. tostring(country.name))

							local there_are_helos = false
							for attrID,attr in pairs(country) do
								if (type(attr)=="table") then
									if attrID == "helicopter" then
										HOOK.writeDebugDetail(ModuleName .. ": createGroups, helicopter table found")
										there_are_helos = true
									end
								end
							end
						
							if there_are_helos == false then
								HOOK.writeDebugDetail(ModuleName .. ": createGroups, helicopter table not found, creating...")
								country["helicopter"] = {}
								country["helicopter"]["group"] = {}
								HOOK.writeDebugDetail(ModuleName .. ": createGroups, helicopter table created")
							end

							for attrID,attr in pairs(country) do
								if (type(attr)=="table") then
									if attrID == "helicopter" then
										if attr.group then
											
											-- ## ADDING GROUP!

											-- set first parking SLOTloaded
											local park = 0
											addedGroups = addedGroups + 1

											--[[ set name
											MaxDict = MaxDict+1
											local gDictEntry = "DictKey_GroupName_" .. MaxDict
											addedGroups = addedGroups + 1
											local gNameEntry = sData.acfType .. "_DSMC_" .. tostring(addedGroups)	
											dictionary[gDictEntry] = gNameEntry
											HOOK.writeDebugDetail(ModuleName .. ": createGroups, adding gNameEntry: " .. tostring(gNameEntry))
											--]]--

											-- set id
											maxG = maxG + 1

											-- set route first point
											local wptData = {}

											HOOK.writeDebugDetail(ModuleName .. ": createGroups, linkType: " .. tostring(sData.linkType))
											wptData.alt = 0
											wptData.x = sData.x
											wptData.y = sData.y
							
											-- set wptname to ""
											--DICTPROBLEM
											--MaxDict = MaxDict+1
											--local WptDictEntry = "DictKey_WptName_" .. MaxDict
											--dictionary[WptDictEntry] = ""
											wptData.name = "" -- WptDictEntry
											HOOK.writeDebugDetail(ModuleName .. ": createGroups, wptData updated")

											-- wp action
											wptData.action = "From Parking Area"
											wptData.alt_type = "BARO"
											wptData.speed = 41.666666666667
											wptData.ETA = 0
											wptData.ETA_locked = true
											wptData.type = "TakeOffParking"
											wptData.formation_template = ""
											wptData.speed_locked = true
											wptData.properties = 	{
												["addopt"] = 
												{
												}, -- end of ["addopt"]
											} -- end of ["properties"]
											wptData.task = {
												["id"] = "ComboTask",
												["params"] = 
												{
													["tasks"] = 
													{
													}, -- end of ["tasks"]
												}, -- end of ["params"]
											} -- end of ["task"]

											if sData.linkType == "Heliport" then
												wptData.linkUnit = sData.link
												wptData.helipadId = sData.link
												HOOK.writeDebugDetail(ModuleName .. ": createGroups, heliport type found")
											elseif sData.linkType == "Airport" then
												wptData.airdromeId = sData.airdrome
												HOOK.writeDebugDetail(ModuleName .. ": createGroups, airport type found")
											else
												HOOK.writeDebugBase(ModuleName .. ": createGroups, linkType not found! error")
												return false
											end
											
											local groupTable = {

												["y"] = sData.y,
												["x"] = sData.x,
												--	["name"] = gDictEntry,
												["groupId"] = maxG,
												["route"] = 
												{
													["points"] = 
													{
														[1] = wptData, -- end of [1]
													}, -- end of ["points"]
												}, -- end of ["route"]

												--NON MODIFIED PART
												["modulation"] = 0,
												["tasks"] = 
												{
												}, -- end of ["tasks"]
												["radioSet"] = false,
												["task"] = "Nothing",
												["uncontrolled"] = false,
												["taskSelected"] = true,
												["hidden"] = false,
												["communication"] = true,
												["start_time"] = 0,
												["uncontrollable"] = false,
												["frequency"] = 124,
											}

											-- now check standard unit
											local unitData = {}
											local cls_group = ""
											for i=1, sData.numUnits do
												for acfId, acfData in pairs(standardUnitTypes) do
													if acfId == sData.acfType then
														local uTbl = {}

														maxU = maxU + 1
														HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, maxId: " .. tostring(maxU))
														uTbl.unitId = maxU
												
														--[[ set unit name
														MaxDict = MaxDict+1									
														local UnitDictEntry = "DictKey_UnitName_" .. MaxDict
														addedunits = addedunits + 1
														dictionary[UnitDictEntry] = gNameEntry .. "_unit_" .. addedunits
														HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, uname: " .. tostring(sData.acfType .. "_unit_" .. addedunits))
														uTbl.name = UnitDictEntry
														--]]--
														

														--set coordinates
														local ParkFARP = true
														
														if sData.linkType == "Airport" then
															for id, data in pairs(sData.parkings) do
																if id == i then
																	uTbl.x = data.px
																	uTbl.y = data.py
																	uTbl.parking = tostring(data.pname)
																	uTbl.parking_id = tostring(data.pname) --tostring(tonumber(data.pname) + 1)
																	ParkFARP = false
																	HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, park: " .. tostring(uTbl.parking))
																end
															end		
														else
															uTbl.x = sData.x
															uTbl.y = sData.y
														end
														
														uTbl.heading = sData.h
												
														--set parking
														if ParkFARP then
															park = park + 1
															HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, park: " .. tostring(park))
															uTbl.parking = tostring(park)
															uTbl.parking_id = nil -- DSMC_ possibile error?
														end

														--set livery
														uTbl.livery_id = nil  -- DSMC_ possibile error?
														
														--set skill
														uTbl.skill = "Client"

														--set callsign
														local mtext = "Chevy"
														local mnum  = 1
														local groupNum = addedGroups
												
														if addedGroups < 10 then
															mtext = "Chevy"
															mnum  = 1
															groupNum = addedGroups
														elseif addedGroups < 19 then
															mtext = "Ford"
															mnum  = 2
															groupNum = addedGroups - 9
														elseif addedGroups < 28 then
															mtext = "Pontiac"
															mnum  = 3
															groupNum = addedGroups - 18		
														elseif addedGroups < 37 then
															mtext = "Springfield"
															mnum  = 4
															groupNum = addedGroups - 27	
														elseif addedGroups < 46 then
															mtext = "Enfield"
															mnum  = 5
															groupNum = addedGroups - 36	
														else
															mtext = "Chevy"
															mnum  = 1
															groupNum = addedGroups
														end

														HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, callsign.name: " .. tostring(mtext .. tostring(groupNum) .. tostring(i)))
														
														local revCls = {}
														
														if ME_U then
															HOOK.writeDebugDetail(ModuleName .. ": createGroups ME_U available")
															revCls = {
																[1] =  mnum,
																[2] =  tonumber(groupNum),
																[3] =  tonumber(i),
																["name"] = tonumber(tostring(mnum .. tostring(groupNum) .. tostring(i)))
															}

															HOOK.writeDebugDetail(ModuleName .. ": createGroups country.name: " .. tostring(country.name))

															local ctryControl = _(country.name)

															if ME_U.isWesternCountry(ctryControl) then

																HOOK.writeDebugDetail(ModuleName .. ": createGroups is a western country")

																revCls["name"] = mtext .. tostring(groupNum) .. tostring(i)
																cls_group = mtext .. tostring(groupNum)
															else
																cls_group = tostring(mnum .. tostring(groupNum) .. "0")
															end
														else
															revCls = {
																[1] =  mnum,
																[2] =  tonumber(groupNum),
																[3] =  tonumber(i),
																["name"] = tostring(mtext .. tostring(groupNum) .. tostring(i)),
															}															
															HOOK.writeDebugDetail(ModuleName .. ": createGroups ME_U module not available, possible problem with china & eastern countries!")
															cls_group = tostring(mtext .. tostring(groupNum) .. tostring(i))
														end
														uTbl.callsign = revCls

														
														-- set unit name
														--DICTPROBLEM
														--MaxDict = MaxDict+1									
														--local UnitDictEntry = "DictKey_UnitName_" .. MaxDict
														--addedunits = addedunits + 1
														--dictionary[UnitDictEntry] = tostring(revCls["name"])

														HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, uname: " .. tostring(sData.acfType .. "_unit_" .. addedunits))
														uTbl.name = tostring(revCls["name"]) -- UnitDictEntry

														-- retrieve from standard
														uTbl.alt = acfData.alt
														uTbl.alt_type = acfData.alt_type
														uTbl.ropeLength = acfData.ropeLength
														uTbl.speed = acfData.speed
														uTbl.type = acfData.type
														uTbl.Radio = acfData.Radio
														uTbl.psi = acfData.psi	
														uTbl.payload = acfData.payload
														uTbl.onboard_num = acfData.onboard_num
														uTbl.hardpoint_racks = acfData.hardpoint_racks
														uTbl.AddPropAircraft = acfData.AddPropAircraft

														unitData[#unitData+1] = uTbl
													end
												end
											end

											-- set name
											--DICTPROBLEM
											--MaxDict = MaxDict+1
											--local gDictEntry = "DictKey_GroupName_" .. MaxDict
											local gNameEntry = tostring(tostring(cls_group) .. "_" .. sData.acfType .. "_DSMC_" .. tostring(addedGroups))
											--dictionary[gDictEntry] = gNameEntry
											HOOK.writeDebugDetail(ModuleName .. ": createGroups, adding gNameEntry: " .. tostring(gNameEntry))

											groupTable.name = gNameEntry -- gDictEntry
											groupTable.units = unitData

											attr.group[#attr.group+1] = groupTable
											HOOK.writeDebugDetail(ModuleName .. ": createGroups adding unit, group added")
											--UTIL.dumpTable("groupTable_" .. tostring(addedGroups) .. ".lua", groupTable)

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
		HOOK.writeDebugBase(ModuleName .. ": createGroups error, no slots in tblSlots")
	end

	-- reset maxDictId
	mission.maxDictId = MaxDict

	HOOK.writeDebugDetail(ModuleName .. ": createGroups function done")
	return mission, dictionary

end

-- set maxId number
function setMaxId(mixfile)
	local curvalG = 0
	local curvalU = 0
	for coalitionID,coalition in pairs(mixfile["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then		
					for groupID,group in pairs(attr["group"]) do
						if (group) then
							if group.groupId then
								if curvalG < group.groupId then
									curvalG = group.groupId
								end
							end

							for unitID,unit in pairs(group["units"]) do
								if unit.unitId then
									if curvalU < unit.unitId then
										curvalU = unit.unitId
									end
								end
							end
						end
					end
				end
			end
		end
	end

	if curvalG > 0 and curvalU > 0 then
		return curvalG, curvalU
	else
		HOOK.writeDebugBase(ModuleName .. ": setMaxId failed to get id results")
		return nil
	end
end

-- MAIN FUNCTION TO LAUNCH
function addSlot(missionEnv, warehouseEnv, dictEnv)
	addedGroups = 0
	addedunits = 0
	tblSlots = {}

	-- clean all helos slot!
	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			HOOK.writeDebugDetail(ModuleName .. ": addSlot, removing heli slots for: " .. tostring(country.name))
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then		
					if attrID == "helicopter" then
						if attr["group"] and type(attr["group"]) == "table" then
							local toFix = UTIL.deepCopy(attr["group"])

							for groupID,group in pairs(toFix) do
								if (group) then						
									for unitID, unit in pairs(group["units"]) do
										if unit.skill == "Client" or unit.skill == "Player" then
											--table.remove(group, groupID)
											toFix[groupID] = nil
											--table.remove(attr["group"], groupID);
											HOOK.writeDebugDetail(ModuleName .. ": addSlot killed group: " .. tostring(groupID))	
										end
									end
								end
							end

							if table.getn(toFix) < 1 then -- next(attr.group) == nil
								--table.remove(country, attrID)											
								country[attrID] = nil;
								toFix = nil
								HOOK.writeDebugDetail(ModuleName .. ": addSlot killed country (no more groups)")
							else
								attr["group"] = {}
								for _, gData in pairs(toFix) do
									attr["group"][#attr["group"]+1] = gData
								end
							end							

						end
						--table.remove(country, attrID) -- won't work on "non arrays" things
					end
				end
			end
		end
	end

	--rebuilt them
	for afbType, afbIds in pairs(warehouseEnv) do
		if afbType == "warehouses" then
			for afbId, afbData in pairs(afbIds) do
				HOOK.writeDebugDetail(ModuleName .. ": addSlot, checking heliport: " .. tostring(afbId))

				--local alt_val = 0
				local heading_val = nil
				local x_val = nil
				local y_val = nil
				local link_val = nil
				local link_type_val = nil
				local coa = afbData.coalition
				--HOOK.writeDebugDetail(ModuleName .. ": addSlot, heliport: " .. tostring(afbId) .. ", coa:" ..tostring(coa))

				for coalitionID,coalition in pairs(missionEnv["coalition"]) do
					if coalitionID == HOOK.SLOT_coa_var or permitAll == true then
						--if string.lower(coa) == string.lower(coalitionID) then
							--HOOK.writeDebugDetail(ModuleName .. ": addSlot, heliport: " .. tostring(afbId) .. ", c1")
							for countryID,country in pairs(coalition["country"]) do
								for attrID,attr in pairs(country) do
									if (type(attr)=="table") then		
										if attrID == "static" then
											for groupID,group in pairs(attr["group"]) do
												if (group) then
													for unitID,unit in pairs(group["units"]) do
														--HOOK.writeDebugDetail(ModuleName .. ": addSlot, heliport: " .. tostring(afbId) .. ", c2 unit id: " .. tostring(unit.unitId))
														if tonumber(unit.unitId) == tonumber(afbId) then
															-- correct coalition
															if string.lower(coa) ~= string.lower(coalitionID) then
																afbData.coalition = string.lower(coalitionID)
																coa = string.lower(coalitionID)
																HOOK.writeDebugDetail(ModuleName .. ": addSlot, coalition has been fixed: " .. tostring(unit.unitId))
															end

															if coa ~= "NEUTRAL" and coa ~= "neutrals" then
																-- proceed
																HOOK.writeDebugDetail(ModuleName .. ": addSlot, found unit.unitId-heliport: " .. tostring(unit.unitId))
																heading_val = unit.heading
																x_val = unit.x
																y_val = unit.y
																link_val = unit.unitId
																if unit.category == "Heliports" then
																	link_type_val = "Heliport"
																end

																if heading_val and x_val and y_val and link_val and coa and link_type_val then
																	if afbData.unlimitedAircrafts then
																		HOOK.writeDebugDetail(ModuleName .. ": addSlot, heliport is unlimited, adding all helo types")
																		
																		tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = "Ka-50", numUnits = 2}
																		tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = "Mi-8MT", numUnits = 2}
																		tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = "UH-1H", numUnits = 2}
																		tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = "SA342L", numUnits = 2}

																	else
																		HOOK.writeDebugDetail(ModuleName .. ": addSlot, heliport limited, checking availability")
																		for catId, catData in pairs(afbData.aircrafts) do
																			if catId == "helicopters" then
																				for acfId, acfData in pairs(catData) do
																					for aId, aData in pairs(standardUnitTypes) do
																						--HOOK.writeDebugDetail(ModuleName .. ": addSlot, acfId: " .. tostring(acfId) .. ", aId:" .. tostring(aId))
																						if acfId == aId then
																							local numberFlights = acfData.initialAmount/2

																							HOOK.writeDebugDetail(ModuleName .. ": addSlot, acfId" .. tostring(acfId) .. ", numberFlights: " .. tostring(numberFlights))
																							if numberFlights > 0 and numberFlights < 1 then  -- single ship
																								tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = acfId, numUnits = 1}
																								HOOK.writeDebugDetail(ModuleName .. ": addSlot, creating 1 group, single ship")
																							elseif numberFlights == 1 then -- two ship
																								tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = acfId, numUnits = 2}
																								HOOK.writeDebugDetail(ModuleName .. ": addSlot, creating 1 group, 2ship")																							
																							elseif numberFlights < 2 and numberFlights > 1 then -- three ship
																								tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = acfId, numUnits = 3}
																								HOOK.writeDebugDetail(ModuleName .. ": addSlot, creating 1 group, 3ship")
																							elseif numberFlights >= 2 then -- 2x two ship
																								local flights = math.floor(numberFlights)
																								if flights > MaxSlotsPerHeliport/2 then
																									flights = MaxSlotsPerHeliport/2
																								end
																								HOOK.writeDebugDetail(ModuleName .. ": addSlot, creating " .. tostring(flights) .. " groups , 2 ships each")

																								for i=1, flights do
																									HOOK.writeDebugDetail(ModuleName .. ": addSlot, creating group i: " .. tostring(i) .. ", 2 ships")
																									tblSlots[#tblSlots+1] = {h= heading_val, x=x_val, y = y_val, link = link_val, linkType = link_type_val, cntyID = country.id, coaID = coa, acfType = acfId, numUnits = 2}
																								end
																							else
																								HOOK.writeDebugDetail(ModuleName .. ": addSlot, no availability for " .. tostring(acfId))
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
						--end
					end
				end
			end
		--[[
		elseif afbType == "airports" then

			---- CHECK FOR ALREADY TAKEN PARKINGS!


			for afbId, afbData in pairs(afbIds) do
				HOOK.writeDebugDetail(ModuleName .. ": addSlot, checking airports: " .. tostring(afbId))

				local airdrome_val = afbId
				local coa = string.lower(afbData.coalition)

				if coa == HOOK.SLOT_coa_var or permitAll == true then
					local heading_val = nil
					local x_val = nil
					local y_val = nil
					local parking_tbl = nil

					for aId, aData in pairs(tblAirbases) do 
						if aData.index == afbId then
							parking_tbl = aData.parkings
						end
					end

					-- check number of effective helicopter type available
					local helo_type_number = 0
					local min_park_avail = parking_tbl
					if afbData.unlimitedAircrafts == false then
						for catId, catData in pairs(afbData.aircrafts) do
							if catId == "helicopters" then
								for acfId, acfData in pairs(catData) do
									for aId, aData in pairs(standardUnitTypes) do
										if acfId == aId then
											if acfData.initialAmount > 0 then
												local x_parking = parking_tbl
												min_park_avail_new = getRightParkingAirport(x_parking, acfId, "helicopter")
												HOOK.writeDebugDetail(ModuleName .. ": addSlot, min_park_avail_new " .. tostring(#min_park_avail_new) .. ", for : " .. tostring(acfId))
												if #min_park_avail > #min_park_avail_new then
													min_park_avail = min_park_avail_new
												end
												helo_type_number = helo_type_number + 1
											end
										end
									end
								end
							end
						end

						-- estimate number of flight that can be added per type
						local maxUsableSlots_helo = #min_park_avail - 2 -- 4 are kept as reserve for any reason
						local allowedFlights_helo = math.floor(maxUsableSlots_helo/2)
						HOOK.writeDebugDetail(ModuleName .. ": addSlot, maxUsableSlots_helo " .. tostring(maxUsableSlots_helo))
						HOOK.writeDebugDetail(ModuleName .. ": addSlot, allowedFlights_helo " .. tostring(allowedFlights_helo))
						HOOK.writeDebugDetail(ModuleName .. ": addSlot, helo_type_number " .. tostring(helo_type_number))

						local flightsPerType_helo = math.floor(allowedFlights_helo/helo_type_number)
						
						HOOK.writeDebugDetail(ModuleName .. ": addSlot, flightsPerType_helo " .. tostring(flightsPerType_helo))

						if flightsPerType_helo > 0 and parking_tbl then
							for catId, catData in pairs(afbData.aircrafts) do
								if catId == "helicopters" then
									local catParking = "helicopter"
									for acfId, acfData in pairs(catData) do
										for aId, aData in pairs(standardUnitTypes) do
											if acfId == aId then
												HOOK.writeDebugDetail(ModuleName .. ": addSlot, acfId: " .. tostring(acfId) )
												local numberFlights = math.floor(acfData.initialAmount/2)
												HOOK.writeDebugDetail(ModuleName .. ": addSlot, numberFlights: " .. tostring(numberFlights) )
												if numberFlights > 0 and #parking_tbl > 0 then
													local entries = 0
													if numberFlights >= flightsPerType_helo then
														if numberFlights >= MaxFlightPerAirport then
															entries = MaxFlightPerAirport
														else
															entries = flightsPerType_helo
														end
													else
														if numberFlights > MaxFlightPerAirport then
															entries = MaxFlightPerAirport
														else
															entries = numberFlights
														end
													end
													HOOK.writeDebugDetail(ModuleName .. ": addSlot, entries: " .. tostring(entries) )

													for i=1, entries do
														local x_parking = parking_tbl
														local parkAvail = getRightParkingAirport(x_parking, acfId, catParking)
														HOOK.writeDebugDetail(ModuleName .. ": addSlot, parkAvail: " .. tostring(#parkAvail) )
														if parkAvail then
															if #parkAvail >= slotOnAirbasePerType then
																local assignedParkings = {}
																for i=1, slotOnAirbasePerType do
																	local numpark = table.getn(parking_tbl)
																	if numpark > 0 then
																		local usedPname, usedPx, usedPy, revPark_tbl = getFirstFreeParkingSpot(parkAvail, afbId, parking_tbl)
																		if usedPname and usedPx and usedPy and revPark_tbl then
																			parking_tbl = revPark_tbl
																			HOOK.writeDebugDetail(ModuleName .. ": addSlot, assignedParkings iter, i: " .. tostring(i) )
																			
																			assignedParkings[#assignedParkings+1] = {pname = usedPname, px = usedPx, py = usedPy}
																			if i == 1 then
																				x_val = usedPx
																				y_val = usedPy
																			end
																		end
																	end
																end

																if #assignedParkings == slotOnAirbasePerType then
																	HOOK.writeDebugDetail(ModuleName .. ": addSlot, #assignedParkings: " .. tostring(#assignedParkings) )
																	local choose_coa = nil
																	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
																		if string.lower(coa) == string.lower(coalitionID) then
																			choose_coa = coalitionID
																		end
																	end

																	HOOK.writeDebugDetail(ModuleName .. ": addSlot, assigned on airbase " .. tostring(afbId) .. ", type: " .. tostring(acfId))
																	tblSlots[#tblSlots+1] = {h= 0, x=x_val, y = y_val, airdrome = airdrome_val, linkType = "Airport", parkings = assignedParkings, cntyID = 1, coaID = choose_coa, acfType = acfId, numUnits = slotOnAirbasePerType}
																else
																	HOOK.writeDebugDetail(ModuleName .. ": addSlot, no more parking available")
																end
															else
																HOOK.writeDebugBase(ModuleName .. ": addSlot, no sufficient parking spot available")
															end
														else
															HOOK.writeDebugBase(ModuleName .. ": addSlot, no parking availabe by getRightParkingAirport")
														end
													end
												end
											end
										end
									end
								end
							end

						else
							HOOK.writeDebugDetail(ModuleName .. ": addSlot, currently not possibile to add slot to unlimited airport")
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": addSlot, currently not possibile to add slot to unlimited airport")			
					end
				end
			end
		--]]--
		else
			HOOK.writeDebugDetail(ModuleName .. ": airbase currently skipped")
		end
	end

	if tblSlots then
		if table.getn(tblSlots) > 0 then
			UTIL.dumpTable("tblSlots.lua", tblSlots)
			local newmiz, newdict = createGroups(missionEnv, dictEnv)

			if newmiz and newdict then
				missionEnv = newmiz
				dictEnv = newdict
				HOOK.writeDebugDetail(ModuleName .. ": everything ok")
			else
				HOOK.writeDebugBase(ModuleName .. ": addSlot, error in createGroups")
			end
		end
	end
end


HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
SLOTloaded = true
