-- DGWS_beta
local MainVersion = "0"
local SubVersion = "7"
local Build = "2051"

-- by AMVI
-- MIST 3.5 included in the packadge

-- THANKS TO (cronological order):
	-- Rider
	-- Grimes
	-- MBot
	-- xcom
	-- Ian
	-- vicx


DGWS = {}

	-- set io/lfs/os copies
	local DGWStools = {}  -- removed Local due to external files..
	minizip = require('minizip')
	DGWStools.io = io
	DGWStools.lfs = lfs
	--DGWStools.fs = fs
	DGWStools.os = os
	DGWStools.zip = minizip
	DGWStools.loadstring = loadstring

	-- if this variable is "false", it must be set as true in a mission trigger to allow DGWS to work.
	-- Else, any functions will be available but the cicle won't start.
	-- ## VARIABLES ARE IN PRIORITY ORDER: if one of the above is 'true', it will OVERWRITE subsequent settings ##

	DGWSreset = false		-- If this is set as TRUE, it will completely reset the scenery. You need to run this only uning the SCENERY_BASE mission files!
	DGWSallow = false 		-- This enable all the ongoing functions of DGWS
	DGWSlimited = false 	-- If active will not enable all DGWS function, in particoular it won't activate automatic ground war system (not DEIS, that could work!!)
	DGWSoncall = false		-- If this is set as TRUE, it will execute the same of DGWSallow, but only "on call" using the F10 radio men�


--#########################################################################################################################
--###########################################   DEV NOTES   ###############################################################
--#########################################################################################################################
--#########################################################################################################################

	--[[

		ISSUES


		CURRENTLY IN PROCESS
		- TEST if DGWSoncall work as expected
		- working on new ReportFormat
		-- // DGWS.AIATOtasking, send "n" mission for each AG type directly in the tasking list.
		-- Make the ground automatic campaign optional for each coalition!! (remove ground planning process).

		CURRENTLY TO DO LIST
		- maximum active unit filter, AI off or deactivate the others?
		- dead map object persistence
		- understand why maximum force limit in a zone is not working
		- working on road/offroad routing condition based on terrain elevation features
		- Event based messages system (under attack/is firing/arty fire mission)

		NEXT:
		- DEIS enchanced IA modules
		- effectiveness of DGWS.CmdMASS function // ONTEST
		- RE-MOVE tables and updatable files into Saved-Games directory, while code (which do not change from updates to updates) could be placed in DCS main directory. Reassign

		PLANNED:
		- make remaining DGWS functions working as a state change cycle // first pass is completed with decisionmaker & sitrepupdate internally made cycled function, and a global cycle loop has been enstablished.
		- create boundaries polygon using MIST, understand if a dynamic map for report is suitable
		- create risk level management
		- create units status system (needed for bubble & logistic)
		- create logistic system (DLWS)
		- adding infantry orbat counting (vehicles + infantry alone)
		- integrate suppressionscript & dismountscript, by MBot
		- nearest target report (receive a brief report via message about known enemy groups within 20nm range)
		- prioritize ground targets by significance.

	]]



--#########################################################################################################################
--###########################################   VARIABLES   ###############################################################
--#########################################################################################################################
--#########################################################################################################################

--##### FILE EXPORT variables.
	if env.mission["sortie"] then
		campaignName = env.mission["sortie"]
	else
		campaignName = "noName"
	end
	campaigndirectory = "Campaigns/" .. campaignName .. "/"
	commondirectory = "AMVI/Common/"
	subdirectory = "AMVI/DGWS/"
	codedirectory = "AMVI/DGWS/Code/"
	tabledirectory = "Tables/" -- used after subdirectory // changed "AMVI/DGWS/Tables/"
	listdirectory = "Lists/" -- used after subdirectory // changed "AMVI/DGWS/Tables/"
	reportdirectory = "Report/" -- used after subdirectory // changed "AMVI/DGWS/Tables/"
	coaBlueDirectory = "Report/Blue/" -- used after subdirectory // changed "AMVI/DGWS/Tables/"
	coaRedDirectory = "Report/Red/" -- changed "AMVI/DGWS/Tables/"
	documentdirectory = "AMVI/DGWS/Doc/"
	configdirectory = "AMVI/DGWS/Config/"
	debugdirectory = "AMVI/DGWS/Debug/"
	missionfilesdirectory = "Missions/" -- used from lfs.writedir!

	exportfiletype = ".csv"
	reportfiletype = ".doc"
	configfiletype = ".csv"
	tss = ";" -- text separation symbol. May be changed for some purposes.. but I suggest to keep the ";" one.


--##### CAMPAIGN START & DATE CODE

	-- Assert start date
	local stdatefile = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "CampaignStDate" .. exportfiletype, "r")
	for line in DGWStools.io.lines(stdatefile) do
		local StartDate = line:match("(.-)$")
		if (StartDate) then
			OPstartDate = tonumber(StartDate)
		end
	end
	stdatefile:close()

--##### DGWS VARIABLES

	--## SCENERY DATE UPDATES variables.
	local UpdateSceneryDate = true
	--local MissionHourInterval = MissionInterval*3600 -- seconds between missions in a campaign scenery
	local NightMission = false -- if set "false", it will prevent to set up mission in evening and night hours.
	local NightMissionMaxThereshold = 57600 -- not used
	local NightMissionMinThereshold = 25200 -- not used
	local MissionStartTimeSim = timer.getTime0()
	local NEWstartTime = nil
	local NEWweather = nil
	local DebugMode = true

	--## SCENERY BUILDING variables.
	local RebuildScenery = false -- DON'T CHANGE: set this true if you want that when a new campaign is created, it will be created also the objectivelist. ALL THE "objectivelist" GROUP MUST BE THERE. THIS SHOULD BE INTENDED AS A TEST & DEBUG OPTION
	local objectivelistRefreshInterval = 5 --minutes
	local savedFileUpdate = 5 -- minutes: this sets the time interval between update the saved file that has to be used to prepare next mission.
	--local missionMaxTime = 5 --hours
	local KnownEnemyRefreshInterval = 15 -- minutes
	local groupSITREPupdateInterval = 15 -- minutes
	local missionLasting = 6*60*60 -- seconds

	--## LINED DGWS FUNCTION variables
	local AIONdistance = 10000 --mt
	local TimeChecksForLOS = 5 -- sec
	local IsBorderRange = 15 -- km
	local NearBorderRangeMax = 30 --km (minimum is IsBorderRange)
	local RearBorderRangeMax = 60  --km (minimum is NearBorderRangeMax)
	local minRandomRange = 100 -- mt
	local maxRandomRange = 1000 -- mt
	local alliedEnforceRange = 8000 -- mt (range of allied forces from the actual territory center that calculates in sitrep)
	local enemyThreatRange = 8000 --mt(range of KNOWN enemy forces from the nearest uncontrolled territory center that calculates in sitrep)
	local immediateThreatRange = 5000 --mt (range used in instantBreakLOS to start retirement)
	local maxVisualDetection = 6000 -- mt (usato per stabilire se � avvenuto un contatto visivo. deve essere inferiore a enemyThreatRange)
	local StandardSpeedVel = nil -- km/h
	local StartRoadDisable = 0
	local BetMovDelay = 60 -- sec /// NOT USED IF SEPARATED FILES ARE USED
	local RunScriptDelay = 10 -- sec (this has to be set for compliance of the Operation Start Time information printed in the SITREP and OPREP-1)
	if env.mission.weather.clouds.iprecptns == 0 then
		StandardRoadDisable = 1 -- changed to "nil" from "1" due to the stupid behaviour of ground units in open terrain.
		StandardSpeedVel = 40
		LogisticRoadDisable = nil
		LogisticSpeedVel = 60
	elseif env.mission.weather.clouds.iprecptns == 1 then
		StandardRoadDisable = nil
		StandardSpeedVel = 40
		LogisticRoadDisable = nil
		LogisticSpeedVel = 60
	elseif env.mission.weather.clouds.iprecptns > 1 then
		StandardRoadDisable = nil
		StandardSpeedVel = 20
		LogisticRoadDisable = nil
		LogisticSpeedVel = 45
	end
	local meteoCity = "Kutaisi" -- in the weather function, it look for this city name to retrieve yearly meteo model constant data.
	local IsMuntainThereshold = 300 -- mt of height difference in a determinated area to be understood as "muntain" area of operation
	local ControlledThereshold = 3 -- minimum number of ground unit to define a territory controlled
	local GrndHighForAdvg = 2 -- force ratio thereshold to identify an high advantage
	local GrndShyForAdvg = 1.2 -- force ratio thereshold to identify a slightly advantage
	local GrndHighForDisv = 0.5 -- force ratio thereshold to identify a severe disadvantage
	local GrndShyForDisv = 0.7 -- force ratio thereshold to identify a disadvantage
	local GrndRShyForDisv = 0.9 -- force ratio thereshold to identify a small disadvantage
	local MaxForceInTerr = 5  -- total fighting vehicles per coalition in each territory: a group won't move there if current force number is higher than limite
	local messageActive = true

	local InnerStateTimer = 1 -- seconds between executing internal function state change
	local GlobalStateTimer = 5 -- minutes between DGWS cycle. Min value: 2
	local GlobalState = "A" -- set initial global state.
	local PastGlobalState = "A"
	local debugGlobalState = ""
	local ENVINFOdebug = true
	local IntelMovDiscovered = 20 -- % probability that enemy movement has been discovered. May change with other parameter?

	local GlobalDEBUG = true -- should be used to sobstitute any local debugging trigger variable: if true, every debug will run. if false, none will.
	local ForecastText = ""

	local CurrentCPid = 1 -- problema se funziona cos�, non regge da CampaignSetup.lua
	local CurrentCPmixnum = nil
	local CurrentCPdaynum = nil
	local CurrentstatusOngoing = nil
	NextCPid = CurrentCPid
	NextCPmixnum = nil
	NextCPdaynum = nil  -- maybe update in the future...
	NextstatusOngoing = nil

	local ATOstrikeMaxDist = 250000 -- mt of maximum distance for a strike mission
	local blue_radio = nil

	--## LINED MOSS FUNCTION variables
	local AirUnitsUpd = false -- variable: exclude air units from position updates derivative from MOSS  -> maybe in the future you can update only if grounded!
	local SaveProcedureInitDone = false	-- // EX gMOSSInitDone
	local SaveFileTimer = 450 -- seconds between file saves

	--## INITIALIZE void tables (tables witch are reset at every restart)
	KnownEnemyList = {}
	FunctionsTable = {}
	DynGroupsTable = {}
	DeadMapObjects = {}
	TargetMapObjects = {}
	TargetsTable = {}
	StrategicRep = {}
	CampaignStatus = {}
	ATOrequestlist = {}
	PlannedATO = {}
	ORBATlist = {}  -- rimuovere?
	UsedFlightNumber = {}
	AssignedCallsign = {}

	--## PRE_DWGS tags, to be eliminated progressivly if automatic system could be implemented
	local blueRiskLevel = "medium"
	local redRiskLevel = "medium"


	--## Verify campaign name



--#########################################################################################################################
--###########################################   LOAD EXTERNAL CODE   ######################################################
--#########################################################################################################################
--#########################################################################################################################

	-- ORDER DOES MATTER HERE!

	-- load MIST
	dofile(DGWStools.lfs.currentdir() .. commondirectory .. 'Code/mist.lua')

	-- load CAMPAIGN CONFIG
	dofile(DGWStools.lfs.currentdir() .. configdirectory .. 'CampaignSetup.lua')

	-- revise date
	local OPdate = (math.floor(env.mission["start_time"] / 3600/ 24 )) - OPstartDate --math.floor(timer.getTime0() / 3600 / 24) - OPstartDate

	--env.info("OPstartDate: " .. OPstartDate)
	local NextOPdate = OPdate + 1
	local NextMIZdata = (math.floor(env.mission["start_time"] / 3600/ 24 )) + 1



--#########################################################################################################################
--###########################################   UTILITY FUNCTION   ########################################################
--#########################################################################################################################
--#########################################################################################################################



	-- typematch function, work on unitclass dynamic table to assign group category
	function typeMatch(list, value)
		for _,v in pairs(list) do
		  if string.lower(v) == string.lower(value) then
			return true
		  end
		end
		return false
	end
	--]]-- end typeMatch

	-- string concatenation functions
	function DGWS.newStack()
		return {""}
	end
	--]]--

	function DGWS.getStringFromStack(stack)
	-- 	return table.concat(stack, "\n") .. "\n"
		return table.concat(stack) --.. "\n" (modifica del 27/12/13 alle 15:31)
	end
	--]]--

	function DGWS.addStringToStack(stack, s)
		table.insert(stack, s)    -- push 's' into the the stack
	end
	--]]-- END string concatenation functions

	-- string match identifier, useful for callsign match in SQ table
	function DGWS.callsignMatch(list, value)
		for _,v in pairs(list) do
		  if string.lower(v) == string.lower(value) then
			return true
		  end
		end
		return false
	end
	--]]-- END string match identifier, useful for callsign match in SQ table

	-- coordinate conversion, MGRS, copy from MIST
	DGWS.tostringMGRS = function(MGRS, acc)
		if acc == 0 then
			return MGRS.MGRSDigraph
		else
			return MGRS.MGRSDigraph .. string.format('%0' .. acc .. 'd', math.floor(MGRS.Easting/(10^(5-1))))
				   .. string.format('%0' .. acc .. 'd', math.floor(MGRS.Northing/(10^(5-1))))
		end
	end
	--]]-- END coordinate conversion, MGRS, copy from MIST

	--utility copied from internet.
	function table.val_to_str ( v )
	  if "string" == type( v ) then
		v = string.gsub( v, "\n", "\\n" )
		if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
		  return "'" .. v .. "'"
		end
		return string.gsub(v,'"', '\\"' ) -- modded from  '"' .. string.gsub(v,'"', '\\"' ) .. '"'
	  else
		return "table" == type( v ) and table.tostring( v ) or
		  tostring( v )
	  end
	end
	--]]--

	function table.key_to_str ( k )
	  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
		return k
	  else
		return "[" .. table.val_to_str( k ) .. "]"
	  end
	end
	--]]--

	function table.tostring( tbl )
	  local result, done = {}, {}
	  for k, v in ipairs( tbl ) do
		table.insert( result, table.val_to_str( v ) )
		done[ k ] = true
	  end
	  for k, v in pairs( tbl ) do
		if not done[ k ] then
		  table.insert( result,
			table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
		end
	  end
	  return "{" .. table.concat( result, "," ) .. "}"
	end
	--]]--/table to string copied from internet

	-- date conversion
	function date_to_excel_date(dd, mm, yy)
		local days, monthdays, leapyears, nonleapyears, nonnonleapyears

		monthdays= { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

		leapyears=to_int((yy-1900)/4);
		nonleapyears=to_int((yy-1900)/100)
		nonnonleapyears=to_int((yy-1600)/400)

		if ((math.mod(yy,4)==0) and mm<3) then
		  leapyears = leapyears - 1
		end

		days= 365 * (yy-1900) + leapyears - nonleapyears + nonnonleapyears

		c=1
		while (c<mm) do
		  days = days + monthdays[c]
		c=c+1
		end

		days=days+dd+1

		return days
	end
	--]]--

	-- round numbers
	function DGWS.round(num, idp)
	  if idp and idp>0 then
		local mult = 10^idp
		return math.floor(num * mult + 0.5) / mult
	  end
	  return math.floor(num + 0.5)
	end
	--]]--

	DGWS.copyFile =  function(old, new)
		local i = DGWStools.io.open(old, "r")
		local o = DGWStools.io.open(new, "w")
		o:write(i:read("*a"))
		o:close()
		i:close()
	end
	--]]--

	DGWS.moveFile = function(old, new)
	   DGWS.copyFile(old, new)
	   DGWStools.os.remove(old)
	end
	--]]--


	DGWS.tostringLL = function(lat, lon, acc, DMS)  -- conversione coordinate copiato dal MIST ed adattato

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
		local latMin = (lat - latDeg)*60*1000

		local lonDeg = math.floor(lon)
		local lonMin = (lon - lonDeg)*60*1000

		if DMS then  -- degrees, minutes, and seconds.
			local oldLatMin = latMin
			latMin = math.floor(latMin)
			local latSec = mist.utils.round((oldLatMin - latMin)*60, acc)

			local oldLonMin = lonMin
			lonMin = math.floor(lonMin)
			local lonSec = mist.utils.round((oldLonMin - lonMin)*60, acc)

			if latSec == 60 then
				latSec = 0
				latMin = latMin + 1
			end

			if lonSec == 60 then
				lonSec = 0
				lonMin = lonMin + 1
			end

			local secFrmtStr -- create the formatting string for the seconds place
			if acc <= 0 then  -- no decimal place.
				secFrmtStr = '%02d'
			else
				local width = 5  -- 01.310 - that's a width of 6, for example.
				secFrmtStr = '%0' .. width .. 'f'
			end

			return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '   '
				   .. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi

		else  -- degrees, decimal minutes.
			latMin = mist.utils.round(latMin, acc)
			lonMin = mist.utils.round(lonMin, acc)

			if latMin == 60 then
				latMin = 0
				latDeg = latDeg + 1
			end

			if lonMin == 60 then
				lonMin = 0
				lonDeg = lonDeg + 1
			end

			local minFrmtStr -- create the formatting string for the minutes place
			if acc <= 0 then  -- no decimal place.
				minFrmtStr = '%05d'
			else
				minFrmtStr = '%05d'
			end
			--il return va aggiustato nelle cifre di lonDeg e latDeg qualora si cambi scenario
			return string.format('%02d', latDeg) .. string.format(minFrmtStr, latMin) .. latHemi
			.. string.format('%03d', lonDeg) .. string.format(minFrmtStr, lonMin) .. lonHemi

		end
	end
	-- END coordinate conversion, copy from MIST


--#########################################################################################################################
--###########################################   BUILD IN PERSISTENT SCENERY TABLES   ######################################
--#########################################################################################################################
--#########################################################################################################################

	-- UnitsClass information
	--[[

	CURRENTLY ADDED NATIONS' UNITS:
	- USA
	- Russia
	- Ukraine
	-
	]]--

	-- assign units to class
	UnitsClass =  -- max 8 letter per class
	{
		["MBT"] =
		{
			["type"] = {"M-1 Abrams","T-55","T-72B","T-80UD","T-90"},
			["range"] = 5000,
			["attacklvl"] = 8,
			["defencelvl"] = 9,
			["rangeatklvl"] = 3,
		},
		["IFV"] =
		{
			["type"] = {"LAV-25","M-2 Bradley","M1128 Stryker MGS","BMD-1","BMP-1","BMP-2","Boman"},
			["range"] = 3000,
			["attacklvl"] = 7,
			["defencelvl"] = 6,
			["rangeatklvl"] = 3,
		},
		["APC"] =
		{
			["type"] = {"AAV7","M1126 Stryker ICV","M-113","BTR-80","MTLB"},
			["range"] = 3000,
			["attacklvl"] = 2,
			["defencelvl"] = 5,
			["rangeatklvl"] = 1,
		},
		["ATGM"] =
		{
			["type"] = {"AAV7","M1045 HMMWV TOW","M1134 Stryker ATGM","BMP-3","BTR_D"},
			["range"] = 6000,
			["attacklvl"] = 6,
			["defencelvl"] = 6,
			["rangeatklvl"] = 8,
		},
		["LRARTY"] =
		{
			["type"] = {"M-109","MLRS","Smerch","Grad-URAL","SAU Gvozdika","SAU Msta","SAU Akatsia"},
			["range"] = 13000,
			["attacklvl"] = 3,
			["defencelvl"] = 7,
			["rangeatklvl"] = 9,
		},
		["SRARTY"] =
		{
			["type"] = {"2B11 mortar", "SAU 2-C9"},
			["range"] = 6000,
			["attacklvl"] = 3,
			["defencelvl"] = 7,
			["rangeatklvl"] = 9,
		},
		["AAA"] =
		{
			["type"] = {"Vulcan","ZU-23 Emplacement Closed","ZU-23 Emplacement","Ural-375 ZU-23","ZSU-23-4 Shilka"},
			["range"] = 5000,
			["attacklvl"] = 2,
			["defencelvl"] = 2,
			["rangeatklvl"] = 4,
		},
		["LRSAM"] =
		{
			["type"] = {"Hawk ln","Hawk sr","Hawk tr","Patriot AMG","Patriot ECS","Patriot EPP","Patriot cp","Patriot ln","Patriot str","S-300PS 54K6 cp","S-300PS 5P85C ln","S-300PS 5P85D ln","S-300PS 40B6MD sr","S-300PS 64H6E sr","S-300PS 40B6M tr","SA-11 Buk CC 9S470M1","SA-11 Buk LN 9A310M1","SA-11 Buk SR 9S18M1","5p73 s-125 ln","p-19 s-125 sr","snr s-125 tr","Kub 2P25 ln","Kub 1S91 str"},
			["range"] = 10000,
			["attacklvl"] = 2,
			["defencelvl"] = 3,
			["rangeatklvl"] = 2,
		},
		["SRSAM"] =
		{
			["type"] = {"M1097 Avenger","M6 Linebacker","Strela-10M3","Tor 9A331","2S6 Tunguska","Osa 9A33 ln","Strela-1 9P31","M48 Chaparral"},  -- add if suitable: #,"Stinger manpad","Stinger comm"#
			["range"] = 5000,
			["attacklvl"] = 3,
			["defencelvl"] = 7,
			["rangeatklvl"] = 3,
			},
		["EWR"] =
		{
			["type"] = {"1L13 EWR","55G6 EWR","Dog Ear radar"},
			["range"] = 10000,
			["attacklvl"] = 0,
			["defencelvl"] = 1,
			["rangeatklvl"] = 0,
		},
		["HQ"] =
		{
			["type"] = {"Ural-375 PBU","Predator TrojanSpirit","SKP-11"},
			["range"] = 20000,
			["attacklvl"] = 1,
			["defencelvl"] = 3,
			["rangeatklvl"] = 0,
		},
		["RECON"] =
		{
			["type"] = {"Hummer","M1043 HMMWV Armament","UAZ-469","BRDM-2"},
			["range"] = 10000,
			["attacklvl"] = 0,
			["defencelvl"] = 1,
			["rangeatklvl"] = 1,
		},
		["INFANTRY"] =
		{
			["type"] = {"Stinger manpad","Stinger comm","Infantry AK","Infantry M249","Infantry M4"},
			["range"] = 1000,
			["attacklvl"] = 1,
			["defencelvl"] = 0,
			["rangeatklvl"] = 0,
		},
		["LOGISTIC"] =
		{
			["type"] = {"M978 HEMTT Tanker","HEMTT TFFT","M 818","Ural ATsP-6","Ural-4320 APA-5D","ZiL-131 APA-80","ATZ-10","ATMZ-5","Ural-375","GAZ-66"},
			["range"] = 10000,
			["attacklvl"] = 0,
			["defencelvl"] = 1,
			["rangeatklvl"] = 1,
		},
	}
	--]]--

	-- define existent risk level
	AcceptableRiskLevel =
	{
		["negligible"] =
		{
			["atkForceDiff"] = 1.3,
			["defForceDiff"] = 1.3,
			["rngForceDiff"] = 1.3,
			["SizeDiff"] = 5,
		},
		["low"] =
		{
			["atkForceDiff"] = 1.1,
			["defForceDiff"] = 1.1,
			["rngForceDiff"] = 1.1,
			["SizeDiff"] = 3,
		},
		["medium"] =
		{
			["atkForceDiff"] = 1,
			["defForceDiff"] = 1,
			["rngForceDiff"] = 1,
			["SizeDiff"] = 0,
		},
		["high"] =
		{
			["atkForceDiff"] = 0.8,
			["defForceDiff"] = 0.8,
			["rngForceDiff"] = 0.8,
			["SizeDiff"] = -3,
		},
		["extreme"] =
		{
			["atkForceDiff"] = 0.5,
			["defForceDiff"] = 0.5,
			["rngForceDiff"] = 0.5,
			["SizeDiff"] = -5,
		},
	}
	--]]--

	--[[ units name list

	-Vulcan
	-M1097 Avenger
	-M48 Chaparral
	-Hawk ln
	-Hawk sr
	-Hawk tr
	-M6 Linebacker
	-Patriot AMG
	-Patriot ECS
	-Patriot EPP
	-Patriot cp
	-Patriot ln
	-Patriot str

	AAV7
	M1043 HMMWV Armament
	M1126 Stryker ICV
	M-113
	M1045 HMMWV TOW
	LAV-25
	M-2 Bradley
	M-1 Abrams

	2B11 mortar
	MLRS
	M-109
	ZU-23 Emplacement Closed
	ZU-23 Emplacement
	Ural-375 ZU-23
	Dog Ear radar
	1L13 EWR
	55G6 EWR
	S-300PS 54K6 cp
	S-300PS 5P85C ln
	S-300PS 5P85D ln
	S-300PS 40B6MD sr
	S-300PS 64H6E sr
	S-300PS 40B6M tr
	SA-11 Buk CC 9S470M1
	SA-11 Buk LN 9A310M1
	SA-11 Buk SR 9S18M1
	Strela-10M3
	Tor 9A331
	SA-18 Igla-S manpad
	SA-18 Igla-S comm
	2S6 Tunguska
	5p73 s-125 ln
	p-19 s-125 sr
	snr s-125 tr
	Kub 2P25 ln
	Kub 1S91 str
	Osa 9A33 ln
	Strela-1 9P31
	ZSU-23-4 Shilka
	BTR-80
	MTLB
	BRDM-2
	BTR_D
	Boman
	BMD-1
	BMP-1
	BMP-2
	BMP-3
	T-55
	T-72B
	T-80UD
	T-90
	2B11 mortar
	Smerch
	Grad-URAL
	SAU Gvozdika
	SAU Msta
	SAU Akatsia
	SAU 2-C9

	GAZ-3307
	GAZ-3308
	IKARUS Bus
	KAMAZ Truck
	LAZ Bus
	MAZ-6303
	Ural-4320-31
	Ural-4320T
	VAZ Car
	ZIL-131 KUNG
	ZIL-4331
	Trolley bus

	]]--
	--]]--

	-- table of missionType. Editing this will allow to influence the AVIAREQ document and the ground mission planning. It's strictly linked to decisionMaker function.
	GroundMissionType =
	{
		["A"] =
		{
			["Action"] = "Movement to Contact",
			["Description"] = "UNIT IS MOVING TOWARDS THE NEAREST UNCONTROLLED AREA TILL VISUAL CONTACT WITH HOSTILE OR AREA SECURITY IS ARCHIEVED, THREATS IN THE AREA ARE UNKNOWN.",
			["AskSupport"] = 1,
			["Type"] = "neutral",
			["SumCode"] = "CONVOY SECURITY",
			["Function"] = "DGWS.CmdMTC",
			["Movement"] = true,
		},
		["B"] =
		{
			["Action"] = "Attack and occupy",
			["Description"] = "UNIT IS MOVING TOWARDS THE NEAREST OBJECTIVE AREA TO OCCUPY AND SECURE TERRITORY.",
			["AskSupport"] = 2,
			["Type"] = "offensive",
			["SumCode"] = "CAS",
			["Function"] = "DGWS.CmdMTA",
			["Movement"] = true,
		},
		["C"] =
		{
			["Action"] = "Advance 5 km",
			["Description"] = "UNIT IS MOVING TOWARDS THE NEAREST OBJECTIVE AREA FOR 5 CLICKS. AS INTEL REPORTS, OUR FORCES ARE IN SLIGHLY ADVANTAGE. ATTRITION OF HOSTILE ASSETS IN THE TARGET AREA IS ADVISABLE.",
			["AskSupport"] = 4,
			["Type"] = "offensive",
			["SumCode"] = "BAI",
			["Function"] = "DGWS.Cmd5click",
			["Movement"] = true,
		},
		["D"] =
		{
			["Action"] = "Retreat",
			["Description"] = "UNIT IS RETREATING IN THE NEAREST ALLIED CONTROLLED AREA. AS INTEL REPORTS, OUR FORCES ARE IN SEVERE DISADVANTAGE. AIR SUPPORT IS REQUESTED TO ATTRITE AND SLOW DOWN HOSTILE FORCES.",
			["AskSupport"] = 5,
			["Type"] = "defensive",
			["SumCode"] = "CAS",
			["Function"] = "DGWS.CmdRTR",
			["Movement"] = true,
		},
		["E"] =
		{
			["Action"] = "Withdraw till break LOS",
			["Description"] = "UNIT IS WITHDRAWING MOVING BACK TILL HOSTILES BREAK LOS HEADING TO THE NEAREST ALLIED CONTROLLED AREA. AS INTEL REPORTS, OUR FORCES ARE IN A CONCERNING DISADVANTAGE. AIR SUPPORT MAY BE ADVISABLE TO SLOW DOWN OR ATTRITE OPFOR.",
			["AskSupport"] = 1,
			["Type"] = "defensive",
			["SumCode"] = "CAS",
			["Function"] = "DGWS.CmdBrkLOS",
			["Movement"] = true,
		},
		["F"] =
		{
			["Action"] = "Stay there and cover",
			["Description"] = "UNIT IS HOLDING POSITION. HOSTILE ASSETS IN THE PROXIMITY AREAS PREVENT AN ADVANCE DUE TO HIGH RISKS OF SEVERE LOSSES.",
			["AskSupport"] = 2,
			["Type"] = "defensive",
			["SumCode"] = "BAI",
			["Function"] = "No Func",
			["Movement"] = false,
		},
		["G"] =
		{
			["Action"] = "Withdraw till break LOS, enemy has range fire superiority",
			["Description"] = "UNIT IS WITHDRAWING MOVING BACK TILL HOSTILES BREAK LOS HEADING TO THE NEAREST ALLIED CONTROLLED AREA. AS INTEL REPORTS, OUR FORCES ARE IN A SEVERE RANGE FIRE DISADVANTAGE. AIR SUPPORT IS ADVISABLE TO ATTRIT ENEMY ATGM AND ARTILLERY UNITS.",
			["AskSupport"] = 3,
			["Type"] = "defensive",
			["SumCode"] = "CAS",
			["Function"] = "DGWS.CmdBrkLOS",
			["Movement"] = true,
		},
		["H"] =
		{
			["Action"] = "Advance 5 km, range fire advantage",
			["Description"] = "UNIT IS MOVING TOWARDS THE NEAREST OBJECTIVE AREA FOR 5 CLICKS. AS INTEL REPORTS, OUR FORCES ARE IN RANGED FIRE ADVANTAGE. ATTRITION OF HOSTILE ASSETS IN THE TARGET AREA IS WELCOME TO REDUCE RISKS.",
			["AskSupport"] = 2,
			["Type"] = "offensive",
			["SumCode"] = "BAI",
			["Function"] = "DGWS.Cmd5click",
			["Movement"] = true,
		},
		["I"] =
		{
			["Action"] = "Repositioning in same territory",
			["Description"] = "UNIT IS REPOSITIONING IN THE SAME TERRITORY.",
			["AskSupport"] = 2,
			["Type"] = "neutral",
			["SumCode"] = "CAS",
			["Function"] = "DGWS.CmdMTA",
			["Movement"] = true,
		},
		["J"] =
		{
			["Action"] = "Presidiate allied territory",
			["Description"] = "UNIT IS MOVING TOWARDS THE NEAREST ALLIED OBJECTIVE TO KEEP SECURED THE AREA.",
			["AskSupport"] = 2,
			["Type"] = "neutral",
			["SumCode"] = "CONVOY SECURITY",
			["Function"] = "DGWS.CmdMTA",
			["Movement"] = true,
		},
		["K"] =
		{
			["Action"] = "Relocating in another territory",
			["Description"] = "UNIT IS BEING RELOCATED IN ANOTHER TERRITORY.",
			["AskSupport"] = 1,
			["Type"] = "neutral",
			["SumCode"] = "CONVOY SECURITY",
			["Function"] = "DGWS.CmdMTA",
			["Movement"] = true,
		},
	}
	--]]--



--#########################################################################################################################
--############################################### MOVEMENT FUNCTIONS ######################################################
--#########################################################################################################################
--#########################################################################################################################




	--this function check terrain LOS between a any units of a group named "groupXname" and ANY enemy vehicle units: if there is LOS within defined "range", command an hold.
	DGWS.StopMovLOSwEnemy = function(groupXname, range) -- OK

						for _,unitData in pairs(mist.DBs.aliveUnits) do

							if unitData.groupName == groupXname then

								local OwnCoalition = unitData.coalition
								local OwnName = unitData.unitName
								local OwnData = Unit.getByName(OwnName)
								local OwnX = unitData.pos.x
								local OwnZ = unitData.pos.z
								local OwnY = unitData.pos.y+2

								local OwnPos = {
													x = OwnX,
													y = OwnY,
													z = OwnZ
												}

								for _,enemyData in pairs(mist.DBs.aliveUnits) do
									if enemyData.coalition ~= OwnCoalition and enemyData.category == "vehicle" then
										local EnemyName = enemyData.unitName
										local EnemyData = Unit.getByName(EnemyName)
										local EnemyX = enemyData.pos.x
										local EnemyZ = enemyData.pos.z
										local EnemyY = enemyData.pos.y+2

										local EnemyPos = {
															x = EnemyX,
															y = EnemyY,
															z = EnemyZ
														}

										local isLOS = land.isVisible(OwnPos, EnemyPos)

										if isLOS == true then
											if mist.utils.get3DDist(OwnPos,EnemyPos) < range and mist.utils.get3DDist(OwnPos,EnemyPos) < maxVisualDetection then
												trigger.action.groupStopMoving(Group.getByName(groupXname))

												for _,funcData in pairs(FunctionsTable) do
													if groupXname == funcData.GroupName then
														mist.removeFunction(funcData.FuncID)
														table.remove(FunctionsTable,id)
													end
												end

												if messageActive == true then
													mist.message.add({text = "Group " .. groupXname .. " has stopped movement", displayTime = 10, msgFor = {coa = {OwnCoalition}} })
												end
											end
										end
									end
								end

							end
						end
	end
	--]]--

	--this function check terrain LOS between a any units of a group named "groupXname" and ANY enemy vehicle units: if there is not LOS, it will stop movement (used for retire as needed to break LOS with enemy)
	DGWS.StopMovBrkLOSwEnemy = function(groupXname, range)

						for _,unitData in pairs(mist.DBs.aliveUnits) do
							if unitData.groupName == groupXname then

								local OwnCoalition = unitData.coalition
								local OwnName = unitData.unitName
								local OwnData = Unit.getByName(OwnName)
								local OwnX = unitData.pos.x
								local OwnZ = unitData.pos.z
								local OwnY = unitData.pos.y+2

								local OwnPos = {
													x = OwnX,
													y = OwnY,
													z = OwnZ
												}

								for _,enemyData in pairs(mist.DBs.aliveUnits) do
									if enemyData.coalition ~= OwnCoalition and enemyData.category == "vehicle" then
										local EnemyName = enemyData.unitName
										local EnemyData = Unit.getByName(EnemyName)
										local EnemyX = enemyData.pos.x
										local EnemyZ = enemyData.pos.z
										local EnemyY = enemyData.pos.y+2

										local EnemyPos = {
															x = EnemyX,
															y = EnemyY,
															z = EnemyZ
														}

										local isLOS = land.isVisible(OwnPos, EnemyPos)

										if isLOS == false and mist.utils.get3DDist(OwnPos,EnemyPos) > enemyThreatRange then
											--if mist.utils.get3DDist(OwnPos,EnemyPos) > range then
												trigger.action.groupStopMoving(Group.getByName(groupXname))

												for _,funcData in pairs(FunctionsTable) do
													if groupXname == funcData.GroupName then
														mist.removeFunction(funcData.FuncID)
														table.remove(FunctionsTable,id)
													end
												end

												if messageActive == true then
													mist.message.add({text = "Group " .. groupXname .. " has stopped movement", displayTime = 10, msgFor = {coa = {OwnCoalition}} })
												end
											--end
										end
									end
								end

							end
						end
	end
	--]]--

	--this function check terrain LOS between a any units of a group named "groupXname" and ANY friendly vehicle units: if there is LOS within defined "range", command an hold.
	DGWS.StopMovLOSwFriendly = function(groupXname, range)

						for _,unitData in pairs(mist.DBs.aliveUnits) do
							if unitData.groupName == groupXname then

								local OwnCoalition = unitData.coalition
								local OwnName = unitData.unitName
								local OwnData = Unit.getByName(OwnName)
								local OwnX = unitData.pos.x
								local OwnZ = unitData.pos.z
								local OwnY = unitData.pos.y+2

								local OwnPos = {
													x = OwnX,
													y = OwnY,
													z = OwnZ
												}

								for _,enemyData in pairs(mist.DBs.aliveUnits) do
									if enemyData.coalition == OwnCoalition and enemyData.category == "vehicle" then	-- best if it's possible to add units class from class table.
										local EnemyName = enemyData.unitName
										local EnemyData = Unit.getByName(EnemyName)
										local EnemyX = enemyData.pos.x
										local EnemyZ = enemyData.pos.z
										local EnemyY = enemyData.pos.y+2

										local EnemyPos = {
															x = EnemyX,
															y = EnemyY,
															z = EnemyZ
														}

										local isLOS = land.isVisible(OwnPos, EnemyPos)

										if isLOS == true then
											if mist.utils.get3DDist(OwnPos,EnemyPos) < range and mist.utils.get3DDist(OwnPos,EnemyPos) < maxVisualDetection then
												trigger.action.groupStopMoving(Group.getByName(groupXname))

												for _,funcData in pairs(FunctionsTable) do
													if groupXname == funcData.GroupName then
														mist.removeFunction(funcData.FuncID)
														table.remove(FunctionsTable,id)
													end
												end

												if messageActive == true then
													mist.message.add({text = "Group " .. groupXname .. " has stopped movement", displayTime = 10, msgFor = {coa = {OwnCoalition}} })
												end
											end
										end
									end
								end
							end
						end
	end
	--]]--

	--this function calculate linear horizontal distance between a group initial position and the actual group position using the mist aliveunits db at every call. If at the call the distance is more than "range", it stops the group.
	DGWS.StopMovFixDistance = function(groupXname, range) -- OK

						for _,unitData in pairs(mist.DBs.aliveUnits) do
							if unitData.groupName == groupXname then

								local OwnCoalition = unitData.coalition
								local OwnName = unitData.unitName
								local OwnData = Unit.getByName(OwnName)
								local OwnX = unitData.pos.x
								local OwnZ = unitData.pos.z
								local OwnInitX = unitData.point.x
								local OwnInitZ = unitData.point.y

								local OwnPos = {
													x = OwnX,
													y = 0,
													z = OwnZ
												}

								local OwnInitPos = {
													x = OwnInitX,
													y = 0,
													z = OwnInitZ
												}

								if mist.utils.get3DDist(OwnPos,OwnInitPos) > range then
									trigger.action.groupStopMoving(Group.getByName(groupXname))

									for id,funcData in pairs(FunctionsTable) do
										if groupXname == funcData.GroupName then
											mist.removeFunction(funcData.FuncID)
											table.remove(FunctionsTable,id)
										end
									end

									if messageActive == true then
										mist.message.add({text = "Group " .. groupXname .. " has stopped movement", displayTime = 10, msgFor = {coa = {OwnCoalition}} })
									end
								end

							end
						end
	end
	--]]--

	-- ### NEXT DAY MOVEMENT TYPE
	-- UPNAME (check callsign assignment) -> metti direttamete il groupname (conterr� il callsign)
	-- this function command to move a defined vehicle group (by name) to the the nearest enemy territory
	DGWS.CmdMTA = function(group_coalition, groupToMove, DestPos, group_class) -- OK

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass custom table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							local GroupPos = Group.getByName(groupToMove):getUnit(1):getPosition()

							--[[ check mountain conditions part 1/2
							local RoadCondChanged = 0
							local Range = (mist.utils.get2DDist(GroupPos, DestPos))/2
							local StartIsMuntain = mist.terrainHeightDiff(GroupPos,Range)
							local EndIsMuntain = mist.terrainHeightDiff(DestPos,Range)
							if StartIsMuntain > IsMuntainThereshold or EndIsMuntain > IsMuntainThereshold then
								if StandardRoadDisable == 1 then
									StandardRoadDisable = nil
									RoadCondChanged = 1
								elseif StandardRoadDisable == nil then
									StandardRoadDisable = nil
									RoadCondChanged = 0
								end
							end
							]]--

							-- execute terrain profiler
							DGWS.TerrainProfiler(groupToMove, GroupPos, DestPos)


							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end
									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,14400) -- change TimeCheckForLOS, change LOSrange
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange

							--[[ check mountain conditions part 1/2
							if RoadCondChanged == 1 then
								StandardRoadDisable = 1
								RoadCondChanged = 0
							end
							]]--

						end
					end
				end
			end
		end
	end
	--]]--

	-- this function command to move a defined vehicle group (by name) to the the nearest enemy territory till enemy contact is confirmed.
	DGWS.CmdMTC = function(group_coalition, groupToMove, DestPos, group_class) -- OK

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end
							local GroupPos = Group.getByName(groupToMove):getUnit(1):getPosition()  --getPoint

							--execute terrain profiler
							DGWS.TerrainProfiler(groupToMove, GroupPos, DestPos)

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							local MovementID = mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end

							--set ROE as RETURN FIRE
							local groupCon = Group.getByName(groupToMove)
							local groupController = groupCon.getController(groupCon)
							groupController.setOption(groupController, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.RETURN_FIRE )

							local MoveFuncID = mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							FunctionsTable[#FunctionsTable + 1] = { GroupName = groupToMove, FuncID = MoveFuncID}

						end
					end
				end
			end
		end

	end
	--]]--

	-- this function command to move a vehicle group of defined coalition, tag and class to ne the nearest objective area till enemy contact is confirmed.
	DGWS.Cmd5click = function(group_coalition, groupToMove, DestPos, group_class) -- OK

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							local MoveFuncID = mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							FunctionsTable[#FunctionsTable + 1] = { GroupName = groupToMove, FuncID = MoveFuncID}

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end



						end
					end
				end
			end
		end

	end
	--]]--

	-- this function command to move a defined by name vehicle group to the nearest HQ group
	DGWS.CmdMASS = function(group_coalition, groupToMove, DestPos, group_class) -- OK ########## -- NOT USED BY NOW

		local DestPos = nil -- DestPos non dovrebbe esistere!!
		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local LOSrange = 50000
							local closestObjPos = {
												x = 0,
												y = 0,
												z = 0
												}

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							for unitIndex, unitData in pairs(group_data.units) do
								if unitIndex == 1 then

									--local groupToMove = group_data.groupName -- assign groupToMove
									local groupToMoveUNdata = Unit.getByName(unitData.unitName) -- gather data from groupToMove to obtain position
									local groupToMovePos = groupToMoveUNdata:getPosition().p -- get position from groupToMove data. This is used as starting position for distance evaluation
									--local closestObjPos = groupToMovePos -- cancel last "closestObjPos" from previous cycle. this is apparently necessary from previous tests  -- /////////////////////////////////////// THIS IS ADDED TO AVOID closesObjPos inexitence.
									local minimumoffset = 10000000 -- assign a very high minimumoffset value (10.000 km), to be sure that this would be sobstituted by any altoffset gained from the obj list.

									for classID, UnitTypeData in pairs(UnitsClass) do
										if classID == "HQ" then
										local identifier = UnitTypeData.type
											for hqIndex, hqData in pairs(mist.DBs.aliveUnits) do
												if hqData.coalition == group_coalition then
													local CheckType = hqData.type
													if typeMatch(identifier, CheckType) then
														local HQX = hqData.pos.x
														local HQZ = hqData.pos.z
														local HQY = hqData.pos.y
														local HQName = hqData.unitName

														local HQPos = {
																		x = HQX,
																		y = HQY,
																		z = HQZ
																	}

														local actualoffset = mist.utils.get2DDist(HQPos, groupToMovePos)

														if actualoffset < 20000 then
															if minimumoffset > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
																minimumoffset = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
																closestObjPos = HQPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															end
														end
													end
												end
											end
										end
									end

								end
							end

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = closestObjPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs () do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end

						end
					end
				end
			end
		end

	end


	-- this function command to move a defined by name vehicle group to ne the nearest allied objective area, for retirement purposes
	DGWS.CmdRTR = function(group_coalition, groupToMove, DestPos, group_class) -- OK

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local StandardRoadDisable = nil -- road should always be used during retirement ops
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end
						end
					end
				end
			end
		end

	end
	--]]--

	-- this function is equal to the "RTR" one, and simply forcing the group to use road. It could be used also for movement inside the allied territories
	DGWS.CmdByRoad = function(group_coalition, groupToMove, DestPos, group_class) -- NOT USED BY NOW

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local StandardRoadDisable = nil -- road should always be used during retirement ops
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end

						end
					end
				end
			end
		end

	end
	--]]--

	-- this function command to move a vehicle group of defined coalition, tag and class to ne the nearest allied objective area.
	DGWS.CmdBrkLOS = function(group_coalition, groupToMove, DestPos, group_class)

		for ind, group_data in pairs(mist.DBs.groupsById) do -- look for all the groups in mist DBs
			if group_data and group_data.groupName then -- safety check: control that group has name and a table of data
				if group_data.category == "vehicle" then --check only vehicles class: exclude flights and navy
					if group_data.coalition == group_coalition then --apply only on chosen coalition, this may be removed if a correct logic could be applied
						if group_data.groupName == groupToMove then

							-- this is useful if the below values aren't accessible for some reason
							local LOSrange = 50000

							-- check class range
							for class, UnitType in pairs(UnitsClass) do -- now look into UnitsClass table
								if string.find(class,group_class) then -- check for Class type: every class type should create a different behaviour for every move
									local LOSrange = class.range
								end
							end

							--schedule the function
							trigger.action.setGroupAIOn(Group.getByName(groupToMove))
							mist.groupToRandomPoint({group = Group.getByName(groupToMove), point = DestPos, radius = math.random(minRandomRange,maxRandomRange), speed = StandardSpeedVel/3.603, disableRoads = StandardRoadDisable})
							--mist.scheduleFunction(DGWS.StopMovLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							--mist.scheduleFunction(DGWS.StopMovFixDistance,{groupToMove,5000},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							local MoveFuncID = mist.scheduleFunction(DGWS.StopMovBrkLOSwEnemy,{groupToMove,LOSrange},timer.getTime() + 1,TimeChecksForLOS,missionLasting) -- change TimeCheckForLOS, change LOSrange
							FunctionsTable[#FunctionsTable + 1] = {GroupName = groupToMove, FuncID = MoveFuncID}

							if messageActive == true then
								local textSumma = ""
								local MovDescription = ""
								local MovClass = ""
								local MovFrom = ""
								local MovTo = ""
								local MovType = ""
								local MovSerial = ""
								local MovCallsign = ""
								for _, entryData in pairs (plannedMovementList) do
									if entryData.GroupName == groupToMove then
										MovGroupId = entryData.groupId
										MovFrom = entryData.FromTerr
										MovTo = entryData.ToTerr
										MovClass = entryData.Tag
										MovType = entryData.MissType
										MovSerial = entryData.MsgSerial
										for movL, movLdata in pairs (GroundMissionType) do
											if movL == MovType then
											MovDescription = movLdata.Action
											end
										end

									end
								end

								if MovDescription and MovClass and MovFrom and MovTo and MovType and MovSerial then
									textSumma = "MOVEMENT CALL\nCallsign: " .. groupToMove .. "\nMovement serial identification: " .. MovSerial .. "\nAssets class " .. MovClass .. "\nHas started moving from " .. MovFrom .. " to " .. MovTo .. "\nMission description: " .. MovDescription
									mist.message.add({text = textSumma, displayTime = 15, msgFor = {CA = {group_coalition}} })
								end
							end

						end
					end
				end
			end
		end

	end
	--]]--



	-- ### OTHER FUNCTIONS

	-- this function will check every slope of terrain in a profile draw from point "A" to point "B", to check if the area has some steep segments. Returns "false" if terrain is not suitable for offroad, returns "true" if it's suitable.
	DGWS.TerrainProfiler = function(GroupName, InitPos, EndPos)

		local DEBUGmode = false -- make true to enable debug
		local RoadDisable = "Error"

		-- retrieve current StandardRoadDisable value
		if StandardRoadDisable == nil then
			RoadDisable = false
		elseif StandardRoadDisable == 1 then
			RoadDisable = true
		end

		-- build and fill the vector array
		local VectorTable = {}
		VectorTable = land.profile(InitPos, EndPos)

		--## DEBUG: esplicita la tabella vettori
		if DEBUGmode == true then
			local fName = "DGWS-DEBUG-Vectortable_".. GroupName .. ".csv"
			local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
			local debugOBJ = ""

			for VectorId,VectorData in pairs(VectorTable) do
				debugOBJ = debugOBJ .. GroupName .. tss .. VectorData.y .. tss .. VectorData.x .. tss .. VectorData.z .. "\n"

			end
			f:write(debugOBJ)
			f:close()
		end
		--## END DEBUG


	end
	--]]--

--#########################################################################################################################
--############################################### PERSISTENT EXTERNAL TABLES ##############################################
--#########################################################################################################################
--#########################################################################################################################

	-- one-shot launch at campaign start.
	DGWS.CreateBuildingLists = function()

		local TargetList = ""
		local BuildingList = ""
		local IDnum = 0

		local AddObjectsTable = function(TargX, TargY, zoneName,TargetArea,TargetType,TargetName)
			local volS = {
				id = world.VolumeType.SPHERE,
				params = {
					point = {x = TargX, y = land.getHeight({x = TargX, y = TargY}), z = TargY},
					radius = TargetArea
				}
			}
			local function handler(object)
				-- get map objects id
				--print out a line
				local ObjId = object:getName() -- object.id_
				local ObjType = object:getTypeName()
				local ObjPos = object:getPoint()
				local Objx = ObjPos.x
				local Objy = ObjPos.z
				local Status = "alive"
				BuildingList = BuildingList .. ObjId .. tss .. TargetType .. tss .. TargetName .. tss .. ObjType .. tss .. Status .. tss .. Objx .. tss .. Objy .. "\n"
				--Object.destroy(object)
				--object:destroy()
			end
			world.searchObjects(Object.Category.SCENERY, volS, handler );
		end


		-- read any zone data and compose the CSV file
		if env.mission.triggers and env.mission.triggers.zones then
			for zone_ind, zoneData in pairs(env.mission.triggers.zones) do
				local MilPriority = 0
				local LogPriority = 0
				local zoneName = zoneData.name
				local TargetArea = zoneData.radius
				local TargetX = zoneData.x
				local TargetY = zoneData.y
				local TargetName = string.sub(zoneName,5)
				local TargetType = nil
				local Coalition = "none"
				local Callsign = "ToBeDefined"
				local Territory = "Nowhere"
				local Status = 1 -- (to be readed as a percentage, 1 means 100%)

				if string.find(zoneName,"MST") then --enlist Military Structure targets
					if string.find(zoneName,"depot") then
						MilPriority = MilPriority + 1
					end
					TargetType = "Military"
					MilPriority = MilPriority + 1
					IDnum = IDnum + 1
					TargetList = TargetList .. IDnum.. tss .. Coalition .. tss .. TargetName .. tss .. TargetType .. tss .. TargetArea .. tss .. TargetX .. tss .. TargetY .. tss .. Callsign .. tss .. Status .. tss .. 






					.. tss .. MilPriority .. tss .. LogPriority ..  "\n"
					AddObjectsTable(TargetX, TargetY, zoneName,TargetArea,TargetType,TargetName)
				elseif string.find(zoneName,"TGT") then --enlist General Structure targets
					if string.find(zoneName,"depot") then
						LogPriority = LogPriority + 1
					end
					TargetType = "Structure"
					LogPriority = LogPriority + 1
					IDnum = IDnum + 1
					TargetList = TargetList .. IDnum.. tss .. Coalition .. tss .. TargetName .. tss .. TargetType .. tss .. TargetArea .. tss .. TargetX .. tss .. TargetY .. tss .. Callsign .. tss .. Status .. tss .. Territory .. tss .. MilPriority .. tss .. LogPriority ..  "\n"
					AddObjectsTable(TargetX, TargetY, zoneName,TargetArea,TargetType,TargetName)
				elseif string.find(zoneName,"ABS") then --enlist Airbase targets
					TargetType = "Airbase"
					MilPriority = MilPriority + 2
					IDnum = IDnum + 1
					TargetList = TargetList .. IDnum.. tss .. Coalition .. tss .. TargetName .. tss .. TargetType .. tss .. TargetArea .. tss .. TargetX .. tss .. TargetY .. tss .. Callsign .. tss .. Status .. tss .. Territory .. tss .. MilPriority .. tss .. LogPriority ..  "\n"
					AddObjectsTable(TargetX, TargetY, zoneName,TargetArea,TargetType,TargetName)
				end
			end
		end


		local p = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetMapObjects" .. exportfiletype, "w")
		p:write(BuildingList)
		p:close()


		local u = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetsTable" .. exportfiletype, "w")
		u:write(TargetList)
		u:close()

	end
	--]]--

	-- update building list
	DGWS.UpdateBuildingLists = function()
		local CallSignList = {}
		local AvailableCallsign = {}

		local ubDebug = ""

		--### UPDATE Targets Building list first

		-- read Targets assigned object list
		TargetMapObjects = {}
		local r = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetMapObjects" .. exportfiletype, "r")
		--BuildingList = BuildingList .. TargetType .. tss .. TargetName .. tss .. ObjId .. tss .. ObjType .. "\n"
		for line in DGWStools.io.lines(r) do
			local rObjId, rTargetType, rTargetName, rObjType, rObjStatus, rObjX, rObjY = line:match("(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rObjId) then
				TargetMapObjects[#TargetMapObjects + 1] = { ObjId = tonumber(rObjId), TargetType = rTargetType, TargetName = rTargetName, ObjType = rObjType, ObjStatus = rObjStatus, ObjX = tonumber(rObjX), ObjY = tonumber(rObjY) }
				ubDebug = ubDebug .. "letto il TargetMapObjects con Id = " .. rObjId .. "\n"
			end
		end
		r:close()

		--]]--
		-- rewrite the updated table
		local BuildingList = ""
		for _, buildingData in pairs(TargetMapObjects) do
			if buildingData.ObjStatus == "alive" then -- check alive buildings only
				local buildX = buildingData.ObjX
				local buildY = buildingData.ObjY

				for deadId,deadData in pairs(mist.DBs.deadObjects) do
					if deadData.objectData.x == buildX and deadData.objectData.y == buildY then -- filter by position
					--if deadId == buildingData.ObjId then
						buildingData.ObjStatus = "dead"
					end
				end
			end
			BuildingList = BuildingList .. buildingData.ObjId .. tss .. buildingData.TargetType .. tss .. buildingData.TargetName .. tss .. buildingData.ObjType .. tss .. buildingData.ObjStatus .. tss .. buildingData.ObjX .. tss .. buildingData.ObjY .. "\n"

		end

		ubDebug = ubDebug .. "\n\nlinee BuildingList\n\n" .. BuildingList .. "\n"

		local p = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetMapObjects" .. exportfiletype, "w")
		p:write(BuildingList)
		p:close()
		--### UPDATE Targets list

		-- read Targets list
		TargetsTable = {}
		local o = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetsTable" .. exportfiletype, "r")
		--TargetList = TargetList .. IDnum.. tss .. Coalition .. tss .. TargetName .. tss .. TargetType .. tss .. TargetArea .. tss .. TargetX .. tss .. TargetY .. tss .. Callsign .. tss .. Status .. "\n"
		for line in DGWStools.io.lines(o) do
			local rIDnum, rCoalition, rTargetName, rTargetType, rTargetArea, rTargetX, rTargetY, rCallsign, rStatus, rTerritory, rMilPry, rLogPry = line:match("(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rIDnum) then
				TargetsTable[#TargetsTable + 1] = { IDnum = tonumber(rIDnum), Coalition = rCoalition, TargetName = rTargetName, TargetType = rTargetType, TargetArea = rTargetArea, TargetX = tonumber(rTargetX), TargetY = tonumber(rTargetY), Callsign = rCallsign, Status = tonumber(rStatus), Territory = rTerritory, MilPry = rMilPry, LogPry = rLogPry   }
				ubDebug = ubDebug .. "Letto il TargetsTable nome = " .. rTargetName .. "\n\n"
			end
		end
		o:close()
		--]]--

		-- update table data
		local TargetTableText = ""
		for tid, TgtData in pairs(TargetsTable) do

			ubDebug = ubDebug .. "\n\n\nAggiornamento obiettivo " .. TgtData.TargetName .. "\n\n"

			-- assess nearest area & coalition
			local TgtPos = { x = TgtData.TargetX, y = 0, z = TgtData.TargetY}
			local nearestValue = 100000000000
			local nearestTerrCoa = nil
			local ObjPos = nil
			local TerrCoa = nil
			local Distance = nil
			local TerrName = nil
			for ObjID,ObjData in pairs (Objectivelist) do
				ObjPos = { x = tonumber(ObjData.objCoordx), y = 0, z = tonumber(ObjData.objCoordy)}
				TerrCoa = ObjData.objCoalition
				Distance = mist.utils.get2DDist(TgtPos, ObjPos)

				if Distance < nearestValue then
					nearestValue = Distance
					nearestTerrCoa = TerrCoa
					TerrName = ObjData.objName
				end
			end
			if TgtData.Coalition ~= nearestTerrCoa then
				TgtData.Coalition = nearestTerrCoa
			end
			if TgtData.Territory ~= TerrName then
				TgtData.Territory = TerrName
			end



			ubDebug = ubDebug .. "aggiornato Coalition: " .. TgtData.Coalition .. "\n"
			ubDebug = ubDebug .. "aggiornato Territory: " .. TgtData.Territory .. "\n"

			-- assess callsign

			local fName = "TargetCallsign.csv"
			local callsignListCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. listdirectory  .. fName, "r")
			for line in DGWStools.io.lines(callsignListCSV) do
				local rcallsign = line:match("(.-)$")
					if (rcallsign) then
					CallSignList[#CallSignList + 1] = { callsign = rcallsign }
				end
			end
			callsignListCSV:close()

			for _, freeCall in pairs(CallSignList) do
				if freeCall then
					local used = false
					if TgtData.Callsign == freeCall.callsign then
						used = true
					end
					if used == false then
						AvailableCallsign[#AvailableCallsign + 1] = { freeCallsign = freeCall.callsign}
					end
				end
			end
			local AvailableNumber = table.getn(AvailableCallsign)

			local callsignExist = true
			if TgtData.Callsign == "ToBeDefined" then
				callsignExist = false
			end

			if callsignExist == false then
				local randomChoose = math.random(1,AvailableNumber)
				for num, calldata in pairs(AvailableCallsign) do
					if randomChoose == num then
						table.remove(AvailableCallsign, num)
						AvailableNumber = table.getn(AvailableCallsign)
						TgtData.Callsign = calldata.freeCallsign
					end
				end
			end

			ubDebug = ubDebug .. "aggiornato Callsign: " .. TgtData.Callsign .. "\n"

			-- assign status (from mistdeadDB)
			if TgtData.Status > 0 then -- object it's alive
				local TotBnum = 0
				local AliveBnum = 0
				for _, buildingData in pairs(TargetMapObjects) do
					if buildingData.TargetName == TgtData.TargetName then
						TotBnum = TotBnum +1
						if buildingData.ObjStatus == "alive" then
							AliveBnum = AliveBnum + 1
						end
					end
				end
				TgtData.Status = (math.floor((AliveBnum / TotBnum)*100))/100 -- this may create an error if no object is there for an objective. acceptable as building table is built only once?
				ubDebug = ubDebug .. "aggiornato Status: " .. TgtData.Status .. "\n"
			end

			TargetTableText = TargetTableText .. TgtData.IDnum .. tss .. TgtData.Coalition .. tss .. TgtData.TargetName .. tss .. TgtData.TargetType .. tss .. TgtData.TargetArea .. tss .. TgtData.TargetX .. tss .. TgtData.TargetY .. tss .. TgtData.Callsign .. tss .. TgtData.Status .. tss .. TgtData.Territory .. tss .. TgtData.MilPry .. tss .. TgtData.LogPry .. "\n"
		end
		local w = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "TargetsTable" .. exportfiletype, "w")
		w:write(TargetTableText)
		w:close()

		local l = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. "DebugTargetsTable" .. exportfiletype, "w")
		l:write(ubDebug)
		l:close()

		if DGWSoncall == true then
			mist.message.add({text = "Military and strategic objectives structures updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end


	end
	--]]--

	-- read the Codeword list table
	DGWS.readCampaignStatus = function()

		-- reset & read current status
		CampaignStatus = {}
		local y = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "campaignStatus" .. exportfiletype, "r")
		for line in DGWStools.io.lines(y) do
			local rId, rOngoing, rMixnum, rDaynum = line:match("(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rId) then
				CampaignStatus[#CampaignStatus + 1] = { Id = rId, Ongoing = rOngoing, Mixnum = rMixnum, Daynum = rDaynum}
			end
		end
		y:close()

		for _,cpData in pairs(CampaignStatus) do
			if tonumber(cpData.Id) == CurrentCPid then
				CurrentCPmixnum = tonumber(cpData.Mixnum)
				CurrentCPdaynum = tonumber(cpData.Daynum)
				CurrentstatusOngoing = cpData.Ongoing
			end
		end

		--
		if DGWSoncall == true then
			mist.message.add({text = "Campaign Status readed", displayTime = 5, msgFor = {coa = {"all"}} })
		end
		--]]--

	end
	--]]--

	-- read the Codeword list table
	DGWS.updateCampaignStatus = function(campaignId,missionNum,dayNum,statusOngoing)
		local CampaignList = ""
		-- reset & read current status
		for _,cpData in pairs(CampaignStatus) do
			if tonumber(cpData.Id) == CurrentCPid then
				cpData.Ongoing = statusOngoing
				cpData.Mixnum = missionNum
				cpData.Daynum = dayNum
				CampaignList = cpData.Id .. tss .. cpData.Ongoing .. tss .. cpData.Mixnum .. tss .. cpData.Daynum .. "\n"
			else
				CampaignList = cpData.Id .. tss .. cpData.Ongoing .. tss .. cpData.Mixnum .. tss .. cpData.Daynum .. "\n"
			end
		end
		--rewrite csv table
		local y = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "campaignStatus" .. exportfiletype, "w")
		y:write(CampaignList)
		y:close()

		if DGWSoncall == true then
			mist.message.add({text = "Campaign Status updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end

	end
	--]]--

	--[[ read the Codeword list table -- NOT USED ANYMORE?!
	DGWS.CampaignStDateReader = function()
		CampaignStDate = {}
		local g = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "CampaignStDate" .. exportfiletype, "r")

		--define content
		for line in DGWStools.io.lines(g) do
			local rStartDate = line:match("(.-)$")
				if (rStartDate) then
				CampaignStDate[#CampaignStDate + 1] = { StartDate =rStartDate}
			end
		end
		--
		g:close()
	end
	--]]--

	-- read the Codeword list table
	DGWS.readPassCodelist = function()
		PassCodeDB = {}
		local h = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. listdirectory .. "PassCode" .. exportfiletype, "r")

		for line in DGWStools.io.lines(h) do
			local rId, rAlphabet, rCities, rLakes, rCars = line:match("(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rId) then
				PassCodeDB[#PassCodeDB + 1] = { Id =rId, Alphabet = rAlphabet, Cities = rCities, Lakes = rLakes, Cars = rCars }
			end
		end
		h:close()

		--
		if DGWSoncall == true then
			mist.message.add({text = "Passcode list readed", displayTime = 5, msgFor = {coa = {"all"}} })
		end
		--]]--

	end
	--]]--

	--this function read the objectivelist.txt persistent table from \Logs\DGWS directory
	DGWS.readObjList = function() -- MUST "FIX" ONLY TO objectivelist.txt
		Objectivelist = {}
		local o = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "objectivelist" .. exportfiletype, "r")

		for line in DGWStools.io.lines(o) do
			local rIDnum, robjID, robjName, robjRegion, robjCoalition, robjCoordx, robjCoordy, robjControlled, robjblueSize, robjredSize, robjIsBorder, robjBattle = line:match("(%d-)"..tss.."(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (robjID) then
				Objectivelist[#Objectivelist + 1] = { IDnum = rIDnum, objID = robjID, objName = robjName, objRegion = robjRegion, objCoalition = robjCoalition, objCoordx = robjCoordx, objCoordy = robjCoordy, objControlled = robjControlled, objblueSize = robjblueSize, objredSize = robjredSize, objIsBorder = robjIsBorder, objBattle = robjBattle }
			end
		end
		o:close()
	end
	--]]--

	--Primary: this function look every 5 minutes if an objective area is occupied by an enemy: if true, it change the coalition value rewriting objectivelist.txt
	--Secondary NEED APPENDING: write down a log that list every objective coalition changes.
	DGWS.editObjList = function()
		if GlobalState == "A" then
			local fName = "objectivelist" .. exportfiletype
			local g = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. fName, "w")
			local rewriteOBJ = ""
			local ControlledObjDistance = (1000*IsBorderRange)*1/3
			local IDnum = 0

			for _,ObjData in pairs (Objectivelist) do
				local ObjID = ObjData.objID
				local ObjName = ObjData.objName
				local ObjRegion = ObjData.objRegion
				local ObjX = ObjData.objCoordx
				local ObjZ = ObjData.objCoordy
				local ObjCoa = ObjData.objCoalition
				local ObjCtrl = ObjData.objControlled
				local ObjBorder = ObjData.objIsBorder
				local ObjBattle = "no"
				local ObjBlueSize = 0
				local ObjRedSize = 0

				local ObjPos = {
								x = ObjX,
								y = 0,
								z = ObjZ
								}

				local BlueDistanceTable = {}
				local RedDistanceTable = {}

				-- count Blue unit in the area
				for _,unitData in pairs(mist.DBs.aliveUnits) do --populate BlueDistanceTable with all ally units within ControlledObjDistance from obj
					if unitData.coalition == "blue" then
						if unitData.category == "vehicle" then
							local countVec = true
							for class, classData in pairs(UnitsClass) do
								local identifier = classData.type
								if typeMatch(identifier, unitData.type ) then
									if identifier == "RECON" or identifier == "INFANTRY" or identifier == "LOGISTIC" then
										countVec = false
									end
								end
							end

							if countVec == true then
								local BlueX = unitData.pos.x
								local BlueZ = unitData.pos.z
								local BluePos = {
												x = BlueX,
												y = 0,
												z = BlueZ
												}

								local BlueDistance = mist.utils.get2DDist(ObjPos, BluePos)

								if BlueDistance < ControlledObjDistance then
									BlueDistanceTable[#BlueDistanceTable + 1] = {Bluedist = BlueDistance}
									ObjBlueSize = ObjBlueSize +1
								end
							end
						end
					end
				end

				-- count red unit in the area
				for _,enemyData in pairs(mist.DBs.aliveUnits) do
					if enemyData.coalition == "red" then
						if enemyData.category == "vehicle" then
							local countVec = true
							for class, classData in pairs(UnitsClass) do
								local identifier = classData.type
								if typeMatch(identifier, enemyData.type ) then
									if identifier == "RECON" or identifier == "INFANTRY" or identifier == "LOGISTIC" then
										countVec = false
									end
								end
							end

							if countVec == true then
								local RedX =  enemyData.pos.x
								local RedZ =  enemyData.pos.z
								local RedPos = {
												x = RedX,
												y = 0,
												z = RedZ
												}

								local RedDistance = mist.utils.get2DDist(ObjPos, RedPos)

								if RedDistance < ControlledObjDistance then
									RedDistanceTable[#RedDistanceTable + 1] = {Reddist = RedDistance}
									ObjRedSize = ObjRedSize +1
								end
							end
						end
					end
				end

				local ObjNewCoa = ObjCoa -- si presume che il territorio sia della coalizione che lo deteneva prima

				-- reassign territory to the Red
				if table.getn(RedDistanceTable) > 0 and
					table.getn(BlueDistanceTable) == 0 then
					local ObjControllerUnits = table.getn(RedDistanceTable)
					ObjCtrl = math.floor(ObjControllerUnits/ControlledThereshold) -- a territory is controlled by multiple of "n" units. If you have 4, you may take the territory but not control it.
					ObjNewCoa = "red"
					ObjBattle = "no"
				end

				-- reassign territory to the Blue
				if table.getn(BlueDistanceTable) > 0 and
					table.getn(RedDistanceTable) == 0 then
					local ObjControllerUnits = table.getn(BlueDistanceTable)
					ObjCtrl = math.floor(ObjControllerUnits/ControlledThereshold) -- a territory is controlled by multiple of "n" units. If you have 4, you may take the territory but not control it.
					ObjNewCoa = "blue"
					ObjBattle = "no"
				end

				-- il territorio � in battaglia, ci sono forze di entrambe le coalizioni
				if table.getn(RedDistanceTable) > 0 and table.getn(BlueDistanceTable) > 0 then
					ObjBattle = "yes"
					ObjNewCoa = "contended"
				end

				-- nessuna forza � presente nell'area, non ci sono battaglie in corso.
				if table.getn(RedDistanceTable) == 0 and table.getn(BlueDistanceTable) == 0 then
					ObjBattle = "no"
					-- non cambia la coalizione che lo aveva
				end

				local IsBorderPriority = 0

				--definizione di confinante
				for _,OtherObjData in pairs (Objectivelist) do
					local OtherObjID = OtherObjData.objID
					local OtherObjName = OtherObjData.objName
					local OtherObjRegion = OtherObjData.objRegion
					local OtherObjX = OtherObjData.objCoordx
					local OtherObjZ = OtherObjData.objCoordy
					local OtherObjCoa = OtherObjData.objCoalition
					local OtherObjCtrl = OtherObjData.objControlled
					local OtherObjBorder = OtherObjData.objIsBorder

					local OtherObjPos = {
									x = OtherObjX,
									y = 0,
									z = OtherObjZ
									}

					-- Set border status with ranges value
					if ObjCoa ~= OtherObjCoa then
						local ObjDistance = mist.utils.get2DDist(ObjPos, OtherObjPos)

						if ObjDistance < (1000*IsBorderRange) and IsBorderPriority < 4 then
							IsBorderPriority = 4
							ObjBorder = "yes"
						elseif ObjDistance > (1000*IsBorderRange) and ObjDistance <= (1000*NearBorderRangeMax) and IsBorderPriority < 3  then
							ObjBorder = "near"
							IsBorderPriority = 3
						elseif ObjDistance > (1000*NearBorderRangeMax) and ObjDistance <= (1000*RearBorderRangeMax) and IsBorderPriority < 2 then
							ObjBorder = "rear"
							IsBorderPriority = 2
						elseif ObjDistance > (1000*RearBorderRangeMax) and IsBorderPriority < 1 then
							ObjBorder = "no"
							IsBorderPriority = 1
						end
					end




				end
				IDnum = IDnum + 1

				rewriteOBJ = rewriteOBJ .. IDnum .. tss .. ObjID .. tss .. ObjName .. tss .. ObjRegion .. tss .. ObjNewCoa .. tss .. ObjX .. tss .. ObjZ .. tss .. ObjCtrl .. tss .. ObjBlueSize .. tss .. ObjRedSize .. tss .. ObjBorder .. tss .. ObjBattle ..  "\n"

			end
			g:write(rewriteOBJ)
			g:close()
			mist.scheduleFunction(DGWS.readObjList,{},timer.getTime() + 1)
		end
		if DGWSoncall == true then
			mist.message.add({text = "Territories and objective areas updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end
		DGWS.globalStateChanger() -- Change the sim state
	end
	--]]-- END edit Objective List

	-- create objectivelist // CHECK IF WORKS ANYMORE
	DGWS.createObjList = function()
	-- once run this function will look for groups that have "ObjListTag" string in their name, and produce a newfile named "Objectivelist.csv" using unitID as ID, the group name (minus the tag)
	-- as Region name, unit name as single objective name (es. a city or an airport or a factory...), the 2D coordinates and the coalition of the group as coalition classifier.

	-- persistent table structure:
	-- Objective list (table txt: ID,objName,regionName,coordx,coordy,coalition)
		local fName = "objectivelist" .. exportfiletype
		local objectivelistCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. fName, "w")
		local ObjListTag = "objectivelist"
		local objID = ""
		local regionName = ""
		local objName = ""
		local coordx = ""
		local coordy = ""
		local coalition = ""
		local controlled = 0
		local IsBorder = "no"
		local IsBattle = "no"
		local blueSize = 0
		local redSize = 0
		local IDnum = 0

		local OBJLINE = ""

		for groupId,groupData in pairs(mist.DBs.groupsById) do
			if string.find(groupData.groupName,ObjListTag) then
				for UnitInd,UnitObj in pairs(groupData.units) do
					if (UnitObj) then --safety check
						objID = UnitInd
						regionName = string.sub(UnitObj.groupName, 14) -- change "14" in ObjListTag+1
						objName = UnitObj.unitName
						coordx = UnitObj.point.x
						coordy = UnitObj.point.y
						coalition = UnitObj.coalition

						IDnum = IDnum + 1
						OBJLINE = OBJLINE .. IDnum .. tss.. objID .. tss.. objName .. tss.. regionName .. tss.. coalition .. tss.. coordx .. tss.. coordy .. tss.. controlled .. tss.. blueSize .. tss.. redSize .. tss.. IsBorder .. tss.. IsBattle .."\n"
					end
				end
			end

		end
		objectivelistCSV:write(OBJLINE)
		objectivelistCSV:close()

	end
	--]]-- END create objective list

	-- read ORBATlist
	DGWS.readORBATlist = function()
		ORBATlist = {}
		local u = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "ORBATlist" .. exportfiletype, "r")

		for line in DGWStools.io.lines(u) do
			local rIDnum, rgroupID, rgroupCtr, rgroupTag, rgroupCoa, rgroupName, rgroupSize, rgroupAtk, rgroupDef, rgroupRng, rgroupGrid, rgroupTerr, rgroupCallsign, rgroupTypeList = line:match("(%d-)"..tss.."(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rgroupID) then
				ORBATlist[#ORBATlist + 1] = { IDnum = rIDnum, groupID = rgroupID, groupCtr = rgroupCtr, groupTag = rgroupTag, groupCoa = rgroupCoa, groupName = rgroupName, groupSize = rgroupSize, groupAtk = rgroupAtk, groupDef = rgroupDef, groupRng = rgroupRng, groupGrid = rgroupGrid, groupTerr = rgroupTerr, groupCallsign = rgroupCallsign, groupTypeList = rgroupTypeList }
			end
		end
		u:close()
	end
	--]]-- END read ORBATlist

	-- create "ORBATlist.csv" persistent table
	DGWS.updateORBATlist = function()
	-- once run this function will check any "vehicle" group in the scenery and add it to the ORBATlist file. The group type will be assigned using the class internal table, matching the first unit only
	-- (if you create a group composed by 1 ATGM vehicle and 5 ICV vehicle, the group will be stored as ATGM anyway)
		if GlobalState == "D" then
			local fName = "ORBATlist" .. exportfiletype
			local ORBATlistCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. fName, "w")

			local groupID = ""
			local groupCtr = ""
			local groupTag = ""
			local groupCoa = ""
			local groupName = ""
			local groupSize = ""

			local ORBATLINE = ""

			local IDnum = 0

			-- open complete list of callsign
			local CallSignList = {}
			local AvailableCallsign = {}
			local AssignedCallsign = {}

			local fName = "GroundCallsign.csv"
			local callsignListCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. listdirectory  .. fName, "r")
			for line in DGWStools.io.lines(callsignListCSV) do
				local rcallsign = line:match("(.-)$")
					if (rcallsign) then
					CallSignList[#CallSignList + 1] = { callsign = rcallsign }
				end
			end
			callsignListCSV:close()
			-- remove used one!
			local u = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "AssignedCallsign" .. exportfiletype, "r")
			for line in DGWStools.io.lines(u) do
				local rgId, rgCallsign = line:match("(.-)"..tss.."(.-)$")
					if (rgId) then
					AssignedCallsign[#AssignedCallsign + 1] = { gId = rgId, gCallsign = rgCallsign}
				end
			end
			u:close()
			-- build AvailableCallsign table
			for _, freeCall in pairs(CallSignList) do
				if freeCall then
					local used = false
					for _, usedData in pairs(AssignedCallsign) do
						if usedData.gCallsign == freeCall.callsign then
							used = true
						end
					end
					if used == false then
						AvailableCallsign[#AvailableCallsign + 1] = { freeCallsign = freeCall.callsign}
					end
				end
			end

			local AvailableNumber = table.getn(AvailableCallsign)

			for groupId, groupData in pairs(mist.DBs.groupsById) do
				if groupData.category == "vehicle" then
					if groupData.groupName ~= "DGWScontrolunit" then -- EXCLUDE THE DGWS on call control vehicle

						local groupAtk = 0
						local groupDef = 0
						local groupRgn = 0
						local groupTypeList = ""
						groupID = groupData.groupId
						groupCtr = groupData.country
						GroupName = groupData.groupName
						groupTag = "---"
						groupCoa = groupData.coalition
						local OwngroupPos = nil
						local GroupCallsign = ""

						--groupSize = Group.getSize(Group.getByName(GroupName))

						local count = 0
						for _,data in pairs(mist.DBs.aliveUnits) do
							if data.groupId == groupID then
								OwngroupPos = data.pos -- lo so aggiorna l'ultima unit� in pratica... da correggere...
								count = count + 1
							end
						end

						groupSize = count

						if groupSize > 0 then

							for unitID,unitData in pairs(mist.DBs.aliveUnits) do
								if unitData.groupName == GroupName then
									--add unitType to the string
									groupTypeList = unitData.type .. "/".. groupTypeList

									--define total group value
									local unitType = unitData.type
									for class, UnitType in pairs(UnitsClass) do
										local identifier = UnitType.type
										if typeMatch(identifier, unitType ) then
											groupTag = class
											groupAtk = groupAtk + UnitType.attacklvl
											groupDef = groupDef + UnitType.defencelvl
											groupRgn = groupRgn + UnitType.rangeatklvl
										end
									end
								end
							end

							-- reset territories variables
							local minimumoffsetSt = 10000000
							local ActualOBJpos = {}
							local ActualOBJgrid = ""
							local closestObjPos = nil
							local ActualPlaceRef = ""

							-- actual position
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									--if objData.objCoalition == OwngroupCoa then
										local placeName = objData.objName
										local placeClass = objData.objIsBorder
										local placeBattle = objData.objBattle
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

										if minimumoffsetSt > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
											minimumoffsetSt = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
											closestObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
											ActualPlaceRef = placeName
										end
										ActualOBJpos = closestObjPos
										ActualOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = closestObjPos.x, y = 0, z = closestObjPos.z})),1)
									--end
								end
							end

							-- look for available callsign
							local callsignExist = false
							for _, csData in pairs(AssignedCallsign) do
								if csData.gId == groupID then
									callsignExist = true
									GroupCallsign = csData.gCallsign
									GroupName = groupTag .. "-" .. GroupCallsign
								end
							end
							-- if not present, assign one
							if callsignExist == false then
								local randomChoose = math.random(1,AvailableNumber)
								for num, calldata in pairs(AvailableCallsign) do
									if randomChoose == num then
										GroupCallsign = calldata.freeCallsign
										table.remove(AvailableCallsign, num)
										AvailableNumber = table.getn(AvailableCallsign)
										GroupName = groupTag .. "-" .. GroupCallsign
										AssignedCallsign[#AssignedCallsign + 1] = { gId = groupID, gCallsign = GroupCallsign}
									end
								end
							end

							-- write line
							IDnum = IDnum + 1
							ORBATLINE = ORBATLINE .. IDnum .. tss .. groupID .. tss .. groupCtr .. tss .. groupTag .. tss .. groupCoa .. tss .. GroupName .. tss .. groupSize .. tss .. groupAtk .. tss .. groupDef .. tss .. groupRgn .. tss .. ActualOBJgrid .. tss .. ActualPlaceRef .. tss .. GroupCallsign .. tss .. groupTypeList .. "\n"
						end

					end

				end
			end

			ORBATlistCSV:write(ORBATLINE)
			ORBATlistCSV:close()

			--write down AssignedCallsign persistent table
			local NewAssignedCallsign = ""
			for id, aCallsign in pairs(AssignedCallsign) do
				NewAssignedCallsign = NewAssignedCallsign .. aCallsign.gId .. tss .. aCallsign.gCallsign .. "\n"
			end
			k = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "AssignedCallsign.csv", "w")
			k:write(NewAssignedCallsign)
			k:close()

			--mist.scheduleFunction(DGWS.groupCallSignAssignment,{},timer.getTime() + 1)
			mist.scheduleFunction(DGWS.readORBATlist,{},timer.getTime() + 2)

			--debug
			if GlobalDEBUG == true then
				mist.scheduleFunction(DGWS.DEBUGobjetivelist,{},timer.getTime() + 1)
			end

		end

		DGWS.globalStateChanger()
		if DGWSoncall == true then
			mist.message.add({text = "ORBAT updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end
	end
	--]]-- end create "ORBATlist.csv" persistent table

	--this function update the KnownEnemyList table with any enemy unit that is not known. // MAYBE CHANGE TO USE THE "DETECTION" FUNCTION?
	DGWS.integrateKnownEnemyList = function()
		if GlobalState == "C" then
			totKnownEnemyList = {}
			local rIDnum = 0
			for _,enemyData in pairs(mist.DBs.aliveUnits) do
				if enemyData.category == "vehicle" then
					local isLOS = false
					local EarthMaxVisRange = 0

					local rEnemyID = enemyData.unitId
					local rEnemyGroupName = enemyData.groupName
					local rEnemyName = enemyData.unitName
					local rEnemyData = Unit.getByName(rEnemyName)
					local rEnemyX = enemyData.pos.x
					local rEnemyZ = enemyData.pos.z
					local rEnemyY = enemyData.pos.y+2
					local rEnemyType = enemyData.type
					local rEnemyCoalition = enemyData.coalition
					local rEnemyCategory = enemyData.category

					-- additional info
					local rEnemyClass = "Unsorted"
					local rEnemyattacklvl = 0
					local rEnemydefencelvl = 0
					local rEnemyrangeatklvl = 0
					local rOwnPos = ""
					local rOwnAGL = ""
					local rOwnGroup = ""

					-- compose position table
					local rEnemyPos = {
									x = rEnemyX,
									y = rEnemyY,
									z = rEnemyZ
									}

					-- overwrite "unsorted" class with correct one.
					for class, classData in pairs(UnitsClass) do
						local identifier = classData.type
						if typeMatch(identifier, rEnemyType ) then
							rEnemyClass = class
							rEnemyattacklvl = classData.attacklvl
							rEnemydefencelvl = classData.defencelvl
							rEnemyrangeatklvl = classData.rangeatklvl
						end
					end


					for _,unitData in pairs(mist.DBs.aliveUnits) do
						local rOwnCoalition = unitData.coalition
						local rOwnName = unitData.unitName
						rOwnGroup = unitData.groupName
						local rOwnX = unitData.pos.x
						local rOwnZ = unitData.pos.z
						local rOwnY = unitData.pos.y
						local rOwnCategory = unitData.category
						rOwnAGL = (rOwnY - land.getHeight({x = rOwnX, y = rOwnZ}))

						rOwnPos = {
										x = rOwnX,
										y = rOwnY,
										z = rOwnZ
										}

						if rEnemyCoalition ~= rOwnCoalition and rEnemyCategory == "vehicle" then
							if rEnemyClass ~= "INFANTRY" then
								isLOS = land.isVisible(rOwnPos, rEnemyPos)
								EarthMaxVisRange = 6371009*math.acos(6371009/(6371009+2+rOwnAGL))
								if isLOS == true then
									local rDistance = mist.utils.get3DDist(rOwnPos,rEnemyPos)
									if rDistance < EarthMaxVisRange then
										--NEW DA QUI
										--for KnownID,KnownData in pairs (KnownEnemyList) do    --//COMMENTED TO TRY IF IT WORKS THIS WAY
											--if rEnemyID ~= KnownData.EnemyID then				--//COMMENTED TO TRY IF IT WORKS THIS WAY
											-- reset territories variables
											local minimumoffsetSt = 10000000
											local ActualOBJpos = {}
											local ActualOBJgrid = ""
											local closestObjPos = ""
											local ActualPlaceRef = ""

											for _, objData in pairs(Objectivelist) do
												if (objData) then
													if objData.objCoalition == OwngroupCoa then
														local placeName = objData.objName
														local OBJx = objData.objCoordx
														local OBJz = objData.objCoordy
														local OBJPos = {
																		x = OBJx,
																		y = 0,
																		z = OBJz
																		}
														local actualoffset = mist.utils.get2DDist(OBJPos, rEnemyPos)

														if minimumoffsetSt > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetSt = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															closestObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															ActualPlaceRef = placeName
														end
														ActualOBJpos = closestObjPos
														ActualOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = closestObjPos.x, y = 0, z = closestObjPos.z})),1)
													end
												end
											end


											rIDnum = rIDnum + 1
											totKnownEnemyList[#totKnownEnemyList + 1] = { IDnum = rIDnum, EnemyID = rEnemyID, EnemyCoalition = rEnemyCoalition, EnemyGroupName = rEnemyGroupName, EnemyName = rEnemyName, EnemyType = rEnemyType, EnemyClass = rEnemyClass, Enemyattacklvl = rEnemyattacklvl, Enemydefencelvl = rEnemydefencelvl, Enemyrangeatklvl = rEnemyrangeatklvl, EnemyX = rEnemyX, EnemyZ = rEnemyZ, EnemyY = rEnemyY, OwnGroup = rOwnGroup, ReportTime = math.floor(timer.getTime()), Distance = rDistance, Territory = ActualPlaceRef}
											--end
										--end
										--END NEW
									end
								end
							end
						end
					end
				end
			end

			-- update duplicates
			for _,entryData in pairs(totKnownEnemyList) do
				local EnID = entryData.EnemyID
				for existID,existingData in pairs(KnownEnemyList) do
					local ExID = existingData.EnemyID

					if ExID == EnID then
						KnownEnemyList[existID] = nil
					end
				end
				KnownEnemyList[#KnownEnemyList + 1] = entryData
			end
		end

		if GlobalDEBUG == true then
			mist.scheduleFunction(DGWS.DEBUGKnownEnemylist,{},timer.getTime() + 1)
		end
		if DGWSoncall == true then
			mist.message.add({text = "Intelligience data updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end


		DGWS.globalStateChanger() -- Change the sim state

	end
	--]]-- END Knownlist integration

	--[[this function update the KnownEnemyList table with any enemy unit that is not known.
	DGWS.integrateKnownEnemyList = function()

		DGWS.debugIK = function()
			k = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. "ikDEBUGlist.csv", "w")
			k:write(ikDEBUGlist)
			k:close()
		end

		if GlobalState == "C" then
			totKnownEnemyList = {}
			local rIDnum = 0

			local ikDEBUGlist = ""

			for _, alliedData in pairs(mist.DBs.aliveUnits) do
				--if alliedData.category == "vehicle" then
					local _unit = Unit.getByName(alliedData.unitName)
					local _controller = _unit:getController()
					local _detectedTargets = _controller:getDetectedTargets()

					ikDEBUGlist = ikDEBUGlist .. "Processando i bersagli visti dall'unit� " .. alliedData.unitName .. "\n"
					DGWS.debugIK()

					for _,_target in pairs(_detectedTargets) do
						local _target = _target.object
						local _detected, _visible, _distance, _type, _time, _last_position, _last_velocity  = _controller:isTargetDetected(_target,nil)		-- multiple variables assigned using the isTargetDetected function

						if _visible == true then -- "visible" is meant by any detection method and not only LOS?

							ikDEBUGlist = ikDEBUGlist .. "E' stato trovato un bersaglio visibile: "
							DGWS.debugIK()

							if _target then
								local rEnemyObjCat = _target:getCategory()
								if rEnemyObjCat == "UNIT" then -- store enemy vehicles only
									-- allied data needed
									local rOwnGroup = alliedData.unitName
									local rOwnCoa = alliedData.coalition

									-- set enemy data needed
									local rEnemyID = nil
									local rEnemyGroupName = nil
									local rEnemyName = nil
									local rEnemyData = nil
									local rEnemyX = nil
									local rEnemyZ = nil
									local rEnemyY = nil
									local rEnemyPos = nil
									local rEnemyType = nil
									local rEnemyCoalition = nil
									local rEnemyCategory = nil
									local rEnemyClass = "Unsorted"
									local rEnemyattacklvl = 0
									local rEnemydefencelvl = 0
									local rEnemyrangeatklvl = 0
									local rEnemyDistance = nil
									--local rOwnPos = ""
									--local rOwnAGL = ""

									-- retrieve Type, Distance and Name directly by _detectedTargets
									rEnemyType = _type
									rEnemyDistance = _distance
									rEnemyName = _target:getName()	-- is this going to work?
									for _, enemyData in pairs(mist.DBs.aliveUnits) do
										if rEnemyName == enemyData.unitName then
											rEnemyID = enemyData.unitId
											rEnemyGroupName = enemyData.groupName
											--rEnemyName = enemyData.unitName
											rEnemyData = Unit.getByName(rEnemyName)
											rEnemyX = enemyData.pos.x
											rEnemyZ = enemyData.pos.z
											rEnemyY = enemyData.pos.y+2
											rEnemyPos = enemyData.pos
											rEnemyType = enemyData.type
											rEnemyCoalition = enemyData.coalition
											rEnemyCategory = enemyData.category
										end
									end

									ikDEBUGlist = ikDEBUGlist .. rEnemyName .. " a distanza " .. rEnemyDistance
									DGWS.debugIK()
									-- overwrite "unsorted" class with correct one, and assign force levels.
									for class, classData in pairs(UnitsClass) do
										local identifier = classData.type
										if typeMatch(identifier, rEnemyType ) then
											rEnemyClass = class
											rEnemyattacklvl = classData.attacklvl
											rEnemydefencelvl = classData.defencelvl
											rEnemyrangeatklvl = classData.rangeatklvl
										end
									end

									ikDEBUGlist = ikDEBUGlist .. " classe " .. rEnemyClass .."\n"
									DGWS.debugIK()
									-- filter coalition and class
									if rEnemyCoalition ~= rOwnCoa and rEnemyClass ~= "INFANTRY" and rEnemyCategory == "vehicle" then -- need to store only enemy vehicles of different coalition

										ikDEBUGlist = ikDEBUGlist .. " il bersaglio � un veicolo di opposta coalizione\n"

										local minimumoffsetSt = 10000000
										local ActualOBJpos = {}
										local ActualOBJgrid = ""
										local closestObjPos = ""
										local ActualPlaceRef = ""

										for _, objData in pairs(Objectivelist) do
											if (objData) then
												if objData.objCoalition == rOwnCoa then
												local placeName = objData.objName
													local OBJx = objData.objCoordx
													local OBJz = objData.objCoordy
													local OBJPos = {
																	x = OBJx,
																	y = 0,
																	z = OBJz
																	}
													local actualoffset = mist.utils.get2DDist(OBJPos, rEnemyPos)

													if minimumoffsetSt > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
														minimumoffsetSt = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
														closestObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
														ActualPlaceRef = placeName
													end
													ActualOBJpos = closestObjPos
													ActualOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = closestObjPos.x, y = 0, z = closestObjPos.z})),1)
												end
											end
										end

										ikDEBUGlist = ikDEBUGlist .. "il bersaglio si trova: " .. ActualOBJgrid       .. "\n"
										DGWS.debugIK()
										-- add IDnum
										rIDnum = rIDnum + 1
										totKnownEnemyList[#totKnownEnemyList + 1] = { IDnum = rIDnum, EnemyID = rEnemyID, EnemyCoalition = rEnemyCoalition, EnemyGroupName = rEnemyGroupName, EnemyName = rEnemyName, EnemyType = rEnemyType, EnemyClass = rEnemyClass, Enemyattacklvl = rEnemyattacklvl, Enemydefencelvl = rEnemydefencelvl, Enemyrangeatklvl = rEnemyrangeatklvl, EnemyX = rEnemyX, EnemyZ = rEnemyZ, EnemyY = rEnemyY, OwnGroup = rOwnGroup, ReportTime = math.floor(timer.getTime()), Distance = rEnemyDistance, Territory = ActualPlaceRef}

									end -- other filter
								end -- store enemy vehicles only
							end
						end -- end visible filter
					end -- end for target
				--end -- end vehicle filter
			end -- end loop mist alive units

			-- update duplicates
			for _,entryData in pairs(totKnownEnemyList) do
				local EnID = entryData.EnemyID
				for existID,existingData in pairs(KnownEnemyList) do
					local ExID = existingData.EnemyID

					if ExID == EnID then
						KnownEnemyList[existID] = nil
					end
				end
				KnownEnemyList[#KnownEnemyList + 1] = entryData
			end
		end



		if GlobalDEBUG == true then
			mist.scheduleFunction(DGWS.DEBUGKnownEnemylist,{},timer.getTime() + 1)
			DGWS.debugIK()
		end
		DGWS.globalStateChanger() -- Change the sim state
	end
	--]]-- END Knownlist integration


	-- crea ed aggiorna SITREP per ogni gruppo
	local usSITREPline = nil
	local usSITREPlistCSV = nil
	local usIDnum = nil
	local usCycleExecute = nil
	local usStato = nil
	local usTotalGroupNum = nil
	local usStatoChanged = nil

	DGWS.groupSITREPupdate = function()
		if GlobalState == "F" then


			local debugSITREPstate = ""
			-- debug for the globalfunction
			debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", As State F is active, DGWS.groupSITREPupdate has started\n"

			--local fName = "groupSITREPlist" .. exportfiletype
			--local usSITREPlistCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. fName, "w")
			usSITREPline = ""
			usIDnum = 0
			usStato = 1

			-- define current dmMOVPLANtable situation
			usTotalGroupNum = 0
			for _, groupData in pairs(ORBATlist) do
				usTotalGroupNum = usTotalGroupNum +1
			end
			debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", usTotalGroupNum � ".. usTotalGroupNum .. "\n\n"

			usCycleExecute = function()

				-- check if cycle has to be stopped.
				local CycleRunning = true

				if usStato > usTotalGroupNum then
					CycleRunning = false -- Stop Cycling
					usWriteSITREP()
					if GlobalDEBUG == true then
						usWriteDEBUG()
					end
					usReadSITREP()
					DGWS.globalStateChanger() -- Change the sim state
					mist.removeFunction(usCycleRunProcess)
					if DGWSoncall == true then
						mist.message.add({text = "Ground assets SA updated", displayTime = 5, msgFor = {coa = {"all"}} })
					end
					--dmCycleExecute = nil -- reset nil status
				end

				debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", Per il gruppo con usStato = ".. usStato .. " ha CycleRunning  " .. tostring(CycleRunning) .. "\n"

				if CycleRunning == true then
					for _,groupData in pairs(ORBATlist) do

						-- gatherin group information
						local OwngroupId = tonumber(groupData.groupID)
						local OwngroupCoa = groupData.groupCoa
						local OwngroupName = groupData.groupName
						local OwngroupNum = tonumber(groupData.IDnum)
						local OwngroupPos = nil

						if OwngroupNum == usStato then
							usStatoChanged = false
							local actualSITREPline = ""
							debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", Il gruppo scelto con usStato numero ".. usStato .. " � " .. OwngroupName .. "\n"

							--[[ EDBUGENVINFO
							if ENVINFOdebug == true then
							env.info(('DGWS-DEBUG: group ' .. OwngroupName .. ", ORBAT line num " .. OwngroupNum .. ",  us process has started" ))
							end
							--]]--

							--rewrite groupPos based on units
							local FirstUnitName = ""
							local FirstUnitPos = {}
							local FirstUnitId = 10000000000000000

							for _,UnitData in pairs(mist.DBs.aliveUnits) do -- try to define the first unit in the group
								if UnitData.groupId == OwngroupId then -- filter only groups units
									debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", unit� trovata, gruppo: ".. OwngroupName .. ", il nome �:" .. UnitData.unitName .. "\n"
									if UnitData.unitId < FirstUnitId then
										FirstUnitId = UnitData.unitId
										FirstUnitName = UnitData.unitName
										FirstUnitPos = UnitData.pos
									end
								end
							end

							debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", La prima unit� del gruppo  ".. OwngroupName .. " � " .. FirstUnitName .. "\n"

							OwngroupPos = FirstUnitPos

							-- set up preliminary allied/enemy values
							local TotalAlliedAttack = 0  -- dynamic update?
							local TotalAlliedDefence = 0 -- dynamic update?
							local TotalAlliedRange = 0 -- dynamic update?
							local TotalEnemyAttack = 0
							local TotalEnemyDefence = 0
							local TotalEnemyRange = 0

							local TotalAlliedSize = 0
							local TotalEnemySize = 0

							-- ## 1. TERRITORY EVALUATION

							-- reset territories variables
							local minimumoffsetSt = 10000000
							local minimumoffsetAl = 10000000
							local minimumoffsetEn = 10000000

							local UnctrOBJpos = {}
							local ActualOBJpos = {}
							local AllyOBJpos = {}

							local UnctrOBJgrid = ""
							local ActualOBJgrid = ""
							local AllyOBJgrid = ""

							local closestObjPos = ""
							local enemyObjPos = ""
							local allyObjPos = ""

							local EnemyPlaceRef = ""
							local ActualPlaceRef = ""
							local AllyPlaceRef = ""



							--seek the nearest uncontrolled/enemy territory data
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									if objData.objCoalition ~= OwngroupCoa then

										local placeName = objData.objName
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

										if minimumoffsetEn > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
											minimumoffsetEn = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
											enemyObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
											EnemyPlaceRef = placeName
										end
										UnctrOBJpos = enemyObjPos
										UnctrOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = enemyObjPos.x, y = 0, z = enemyObjPos.z})),1)
									end
								end
							end
							usWriteDEBUG()
							-- seek the actual position territory data
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									if objData.objCoalition == OwngroupCoa then
										local placeName = objData.objName
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

										if minimumoffsetSt > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
											minimumoffsetSt = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
											closestObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
											ActualPlaceRef = placeName
										end
										ActualOBJpos = closestObjPos
										ActualOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = closestObjPos.x, y = 0, z = closestObjPos.z})),1)
									end
								end
							end
							usWriteDEBUG()
							-- seek the nearest allied territory away of 8 km data (for retirement and withdrawal movement purposes)
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									if objData.objCoalition == OwngroupCoa then
										local placeName = objData.objName
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

										--debug
										--DEBUGLIST = DEBUGLIST .. groupName .. tss .. placeName .. tss .. actualoffset .. "\n"
										--/debug

										if minimumoffsetAl > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
											if actualoffset > 8000 then
												minimumoffsetAl = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
												allyObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
												AllyPlaceRef = placeName
											end
											AllyOBJpos = allyObjPos
											AllyOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = allyObjPos.x, y = 0, z = allyObjPos.z})),1)
										end
									end
								end

							end
							usWriteDEBUG()
							debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", I territori trovati sono: Attuale ".. ActualPlaceRef .. ", non controllato " .. EnemyPlaceRef .. ", Alleato " .. AllyPlaceRef .. "\n"

							-- ## 2. FORCES ASSESMENT

							-- own forces, dynamic
							for _,OwnUnitData in pairs(mist.DBs.aliveUnits) do
								if OwnUnitData.groupId == OwngroupId then
									local UnitAttack = 0
									local UnitDefence = 0
									local UnitRange = 0

									-- increase Size
									TotalAlliedSize = TotalAlliedSize + 1

									-- overwrite "unsorted" class with correct one.
									for class, classData in pairs(UnitsClass) do
										local identifier = classData.type
										if typeMatch(identifier, OwnUnitData.type ) then
											UnitAttack = classData.attacklvl
											UnitDefence = classData.defencelvl
											UnitRange = classData.rangeatklvl
										end
									end

									TotalAlliedAttack = TotalAlliedAttack + UnitAttack
									TotalAlliedDefence = TotalAlliedDefence + UnitDefence
									TotalAlliedRange = TotalAlliedRange + UnitRange
								end

							end

							-- assess Allied forces, dynamic
							for _,AlliedData in pairs(mist.DBs.aliveUnits) do
								if AlliedData.coalition == OwngroupCoa then
									if AlliedData.category == "vehicle" then
										if AlliedData.groupId ~= OwngroupId then
											local AlliedUnitAttack = 0
											local AlliedUnitDefence = 0
											local AlliedUnitRange = 0
											local AlliedUnitPos = AlliedData.pos
											local AlliedUnitSize = 1

											if mist.utils.get3DDist(ActualOBJpos, AlliedUnitPos) < alliedEnforceRange then

												for class, classData in pairs(UnitsClass) do
													local identifier = classData.type
													if typeMatch(identifier, AlliedData.type ) then
														AlliedUnitAttack = classData.attacklvl
														AlliedUnitDefence = classData.defencelvl
														AlliedUnitRange = classData.rangeatklvl
													end
												end

												TotalAlliedAttack = TotalAlliedAttack + AlliedUnitAttack
												TotalAlliedDefence = TotalAlliedDefence + AlliedUnitDefence
												TotalAlliedRange = TotalAlliedRange + AlliedUnitRange
												TotalAlliedSize = TotalAlliedSize + AlliedUnitSize
											end
										end
									end
								end
							end

							-- assess enemy forces, by Known Enemy List
							for _,VisibleData in pairs(KnownEnemyList) do
								if VisibleData.EnemyCoalition ~= OwngroupCoa then
									--local EnemygroupName = VisibleData.EnemyGroupName
									local EnemygroupAttack = VisibleData.Enemyattacklvl
									local EnemygroupDefence = VisibleData.Enemydefencelvl
									local EnemygroupRange = VisibleData.Enemyrangeatklvl
									local EnemygroupPos = {
														x = VisibleData.EnemyX,
														y = VisibleData.EnemyY,
														z = VisibleData.EnemyZ
														}
									local EnemygroupSize = 1

									if mist.utils.get2DDist(UnctrOBJpos,EnemygroupPos) < enemyThreatRange then
										TotalEnemyAttack = TotalEnemyAttack + EnemygroupAttack
										TotalEnemyDefence = TotalEnemyDefence + EnemygroupDefence
										TotalEnemyRange = TotalEnemyRange + EnemygroupRange
										TotalEnemySize = TotalEnemySize + EnemygroupSize
									end
								end
							end

							-- ## /2 END FORCES ASSESMENT

							-- ## 3. FORCES CALCULATION

							local AtkRapp = 0
							if TotalEnemyAttack == 0 then
								AtkRapp = 100
							elseif TotalEnemyAttack > 0 then
								AtkRapp = (math.floor((TotalAlliedAttack / TotalEnemyAttack)*10))/10
							end

							local DefRapp = 0
							if TotalEnemyDefence == 0 then
								DefRapp = 100
							elseif TotalEnemyDefence > 0 then
								DefRapp = (math.floor((TotalAlliedDefence / TotalEnemyDefence)*10))/10
							end

							local RngRapp = 0
							if TotalEnemyDefence == 0 then
								RngRapp = 100
							elseif TotalEnemyDefence > 0 then
								RngRapp = (math.floor((TotalAlliedRange / TotalEnemyRange)*10))/10
							end

							debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", I rapporti dei valori trovati sono: AtkRapp ".. AtkRapp .. ", DefRapp " .. DefRapp .. ", RngRapp " .. RngRapp .. "\n"

							-- ## /3 END FORCES CALCULATION

							if OwngroupId and OwngroupName and OwngroupCoa then -- can't find main data!
								if TotalAlliedSize and TotalEnemySize then -- filter size data present
									if ActualPlaceRef and ActualOBJgrid then -- actual place must be indentifiable
										usIDnum = usIDnum + 1
										actualSITREPline = usIDnum .. tss .. OwngroupId .. tss .. OwngroupName .. tss .. OwngroupCoa .. tss .. TotalAlliedSize .. tss .. TotalEnemySize .. tss .. AtkRapp .. tss .. DefRapp .. tss .. RngRapp .. "\n"
										usSITREPline = usSITREPline .. actualSITREPline
										--usStato = usStato + 1
										debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", La riga SITREP �: ".. actualSITREPline
										usStatoChanged = true
									end
								end
							--else
								--write else debug code
							end

							--usStato = usStato + 1
							--debugSITREPstate = debugSITREPstate .. usStato .. "\n"
						end -- end chosen cycle
					end -- end for group
				end -- check Cyclerunning

				debugSITREPstate = debugSITREPstate .. "Il valore di usStatoChanged � " .. tostring(usStatoChanged) .. "\n"

				--dmDEBUGlist = dmDEBUGlist .. "La variable dmStatoChanged � ancora " .. tostring(dmStatoChanged) .. "\n\n"
				if usStatoChanged == true then
					debugSITREPstate = debugSITREPstate .. timer.getTime() .. ", DGWS.groupSITREPupdate parameter usStato � cambiato da " .. usStato .. " a "
					usStato = usStato + 1
					debugSITREPstate = debugSITREPstate .. usStato .. "\n\n"
				end

				if GlobalDEBUG == true then
					usWriteDEBUG()
				end

			end -- end usCycleExecute

			-- ## 5. WRITE INFO INTO FILE
			usWriteSITREP = function()
				local fName = "groupSITREPlist" .. exportfiletype
				local usSITREPlistCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. fName, "w")
				usSITREPlistCSV:write(usSITREPline)
				usSITREPlistCSV:close()
			end
			-- ## /5 END WRITE INFO INTO FILE

			-- ## 6. READ AND UPDATE FILE
			usReadSITREP = function()
				groupSITREPList = {}
				local j = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "groupSITREPList" .. exportfiletype, "r")

				for line in DGWStools.io.lines(j) do
					local rIDnum, rOwngroupId, rOwngroupName, rOwngroupCoa, rTotalAlliedSize, rTotalEnemySize, rAtkRapp, rDefRapp, rRngRapp = line:match("(%d-)"..tss.."(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
						if (rOwngroupId) then
						groupSITREPList[#groupSITREPList + 1] = { IDnum = rIDnum, OwngroupId = rOwngroupId, OwngroupName = rOwngroupName, OwngroupCoa = rOwngroupCoa, TotalAlliedSize = rTotalAlliedSize, TotalEnemySize = rTotalEnemySize, AtkRapp = rAtkRapp, DefRapp = rDefRapp, RngRapp = rRngRapp }
					end
				end
				j:close()
			end
			-- ## /6 END READ AND UPDATE FILE

			-- ## 5. WRITE INFO INTO FILE
			usWriteDEBUG = function()
				local fName = "debugSITREPstate" .. exportfiletype
				local usDEBUGlistCSV = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. fName, "w")
				usDEBUGlistCSV:write(debugSITREPstate)
				usDEBUGlistCSV:close()
				local oldname = DGWStools.lfs.currentdir() .. debugdirectory  .. fName
				local newname = DGWStools.lfs.currentdir() .. debugdirectory  .. "RenameProva.csv"
				DGWStools.os.rename(oldname, newname)
			end
			-- ## /5 END WRITE INFO INTO FILE

			usCycleRunProcess = mist.scheduleFunction(usCycleExecute,{}, timer.getTime() + 1, InnerStateTimer, missionLasting)
		end
	end
	--]]-- END SITREP update




--#########################################################################################################################
--############################################### REPORT BUILDING FUNCTIONS ###############################################
--#########################################################################################################################
--#########################################################################################################################






	--[[ ###### E) SITREP ######
	DGWS.SITREPreport = function() -- OK, IMPLEMENT!

		--read and close the planned movement list.
		plannedMovementListAVIAREQ = {}
		local j = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "plannedMovementList" .. exportfiletype, "r")

		-- if DGWStools.io.read("*all")
		if j ~= nil then
			for line in DGWStools.io.lines(j) do
				if line then
					local rCoalition, rID, rGroupName, rTag, rFrom, rTo, rMissionType, rTime, rMsgSerial = line:match("(.-)"..tss.."(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(%d-)$")
					--if type(rID) == "number" then
						plannedMovementListAVIAREQ[#plannedMovementListAVIAREQ + 1] = { ID = rID, Coalition = rCoalition, GroupName = rGroupName, Tag = rTag, From = rFrom, To = rTo, MissionType = rMissionType, Time = rTime, MsgSerial = rMsgSerial }
					--end
				end
			end
			j:close()
		end


		-- other vars
		local BlueOPname = OPname
		local MIXname = env.mission["sortie"]

		-- starting mission time and info (CORRECT)
		local StartDaygg = string.format("%02.f", (NextMIZdata))
		local StartTimehh = string.format("%02.f", math.floor(((timer.getTime0()+groupStrTime))/3600)+6) -- 6h dopo lo start del server della missione attuale
		local StartTimemm = string.format("%02.f", math.floor((((timer.getTime0()+groupStrTime))/60 - (StartTimehh*60))))
		local PlannedDaygg = string.format("%02.f", (NextMIZdata+1))
		local PlannedTimehh = string.format("%02.f", math.floor(((timer.getTime0()+groupStrTime))/3600)) -- 6h dopo lo start del server della missione attuale

		local RepDayTime = StartDaygg .. StartTimehh .. StartTimemm .. TZ
		local PlanningDate = PlannedDaygg .. PlannedTimehh .. StartTimemm .. TZ

		-- create the sitrep file
		local BlueFileName = "SITREP_Blue_".. MIXname
		local RedFileName = "SITREP_Red_".. MIXname
		local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. reportdirectory  .. BlueFileName .. reportfiletype, "w")
		local b = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. reportdirectory  .. RedFileName .. reportfiletype, "w")



		-- ## blue pages & lines variables
		local BlueINT = nil
		local BlueGroundOPREP = nil
		local BlueAirOPREP = nil -- implementa?


		-- Build Page 1 -- presentation
		BlueINT = "\n\n\n\n\n\n\nCOMMANDER SITUATION REPORT\n\n\n"
		local DayOfWar = "DAY OF OPERATION: " .. NextMIZdata .. "\n\n"
		local ReportDate = "INFORMATION AVAILABLE AT " .. RepDayTime  .. "\n"
		local PlannedDate = "SUITABLE FOR PLANNING TILL " .. PlanningDate  .. "\f"
		BlueINT = BlueINT .. DayOfWar .. ReportDate .. PlannedDate

		-- Build Page 2 -- OPREP


	end
	--]]--


	--[[

	-- blue high organization names
	local blueHighJointCommand = "HQ USJFCOM NORFOLK VA"
	local blueHighGroundCommand = "HQ USAREUR WIESBADEN"
	local blueHighAirCommand = "HQ USAFE RAMSTEIN AFB"

	-- local
	local blueRescueCommand = "CDR ARRS KUTAISI AFB"
	local blueTransportCommand = "CDR MAC BATUMI"
	local blueJointCommand = "JFC KUTAISI AFB"
	local blueGroundCommand = "CDR 173IBCT ARFOR"
	local blueAirCommand = "CDR USAFE KUTAISI AFB"


	--]]--



	-- ###### F) AVIAREQ ######

	--[[ OLD AVIAREQ report
	DGWS.AVIAREQreport = function() -- WIP


		if GlobalState == "H" then

			--read and close the planned movement list.
			plannedMovementListAVIAREQ = {}
			local j = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "plannedMovementList" .. exportfiletype, "r")

			-- if DGWStools.io.read("*all")
			if j ~= nil then
				for line in DGWStools.io.lines(j) do
					if line then
						local rIDnum, rCoalition, rID, rGroupName, rTag, rFrom, rTo, rMissionType, rTime, rMsgSerial = line:match("(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
						--if type(rID) == "number" then
							plannedMovementListAVIAREQ[#plannedMovementListAVIAREQ + 1] = { ID = rID, Coalition = rCoalition, GroupName = rGroupName, Tag = rTag, From = rFrom, To = rTo, MissionType = rMissionType, Time = rTime, MsgSerial = rMsgSerial }
						--end
					end
				end
				j:close()
			end

			-- read any group, OPREP will print a page for each
			for id, moveGroup in pairs (plannedMovementListAVIAREQ) do

				-- ## DEFINE AND RETRIEVE VARIABLES

				-- re-identify variables (not needed but I prefer to)
				local groupCoa = moveGroup.Coalition
				local groupName = moveGroup.GroupName
				local groupClass = moveGroup.Tag
				local groupStrTime = tonumber(moveGroup.Time)
				local groupStrTerr = moveGroup.From
				local groupDesTerr = moveGroup.To
				local groupMixType = moveGroup.MissionType
				local groupMsgSerial = tonumber(moveGroup.MsgSerial)

				-- to define variables
				local groupMixPriority = nil
				local groupMixSumCode = nil
				local groupMixDescription = nil

				-- other variables
				local Serial = 0 --serial number of the message. Reset for each mission.
				local UIC = "ToBeId"
				local Subject = "AIR SUPPORT REQUEST - "
				local LinesType = 0
				local Narrative = ""
				local Priority = ""
				local Callsign = ""
				local GroundUnitTarget = "-"
				local ADSonTarget = "-"
				local groupStrGrid = "-"
				local ContactGrid = "-"
				local ActualDayTime = nil
				local OperDayTime = nil
				local Remarks = nil


				-- ## EXECUTE DATA ELABORATION

				-- get callsign
				for id, callData in pairs (AssignedCallsign) do
					if callData.groupName == groupName then
						Callsign = callData.callsign
					end
				end

				-- retrieve mission info
				for MixId, MixData in pairs(GroundMissionType) do
					if MixId == groupMixType then

						groupMixPriority = MixData.AskSupport
						groupMixSumCode = MixData.SumCode
						Narrative = MixData.Description
						Subject = Subject .. groupMixSumCode

						if groupMixPriority == 1 then -- mission priority assignment
							Priority = "VERY LOW"
						elseif groupMixPriority == 1 then
							Priority = "LOW"
						elseif groupMixPriority == 2 then
							Priority = "MEDIUM"
						elseif groupMixPriority == 3 then
							Priority = "HIGH"
						elseif groupMixPriority == 4 then
							Priority = "VERY HIGH"
						elseif groupMixPriority == 5 then
							Priority = "NECESSARY"
						end -- END mission priority assignment
					end
				end


				-- retrieve data
				if groupCoa == "blue"
				and groupMsgSerial
				and groupMixPriority
				and groupMixSumCode
				and Callsign
				and Narrative
				and Subject
				then

					-- general info
					local BlueOPname = OPname
					local MIXname = env.mission["sortie"]

					-- actual time and minutes info
					local ActualDaygg = string.format("%02.f", NextMIZdata)
					local ActualTimehh = string.format("%02.f", math.floor(((timer.getTime()) - ((math.floor(timer.getTime0()/24/3600))*3600*24))/3600))
					local ActualTimemm = string.format("%02.f", math.floor((((timer.getTime()) - ((math.floor(timer.getTime0()/24/3600))*3600*24))/60 - (ActualTimehh*60))))

					-- starting mission time and info (CORRECT)
					local StartDaygg = string.format("%02.f", (NextMIZdata+1))
					local StartTimehh = string.format("%02.f", math.floor(((timer.getTime0()+groupStrTime))/3600)) -- MAYBE ADD THE HOUR INCREMENT?
					local StartTimemm = string.format("%02.f", math.floor((((timer.getTime0()+groupStrTime))/60 - (StartTimehh*60)))) -- MAYBE ADD THE HOUR INCREMENT?

					ActualDayTime = ActualDaygg .. ActualTimehh .. ActualTimemm .. TZ
					OperDayTime = StartDaygg .. StartTimehh .. StartTimemm .. TZ

					-- update narrative
					Narrative = Narrative .. " MOVEMENT IS STARTING AT " .. OperDayTime


					-- assign UIC from group appartainance
					if groupClass == "IFV" or groupClass == "MBT" or groupClass == "ATGM"  then
						UIC = "WTRAAA"
					elseif groupClass == "LRSAM" or groupClass == "EWR"  then
						UIC = "ALLIED"
					elseif groupClass == "SRARTY" or groupClass == "LRARTY" or groupClass == "AAA" or groupClass == "SRSAM"  then
						UIC = "WP4NAA"
					elseif groupClass == "LOGISTIC" then
						UIC = "WX6XAA"
					elseif groupClass == "INFANTRY" or groupClass == "UNARMED" or groupClass == "APC" then
						UIC = "WX5PAA"
					elseif groupClass == "HQ" then
						UIC = "W77AAA"
					end

					-- authentication
					randCode = math.random(1,26)
					PassText = ""
					for id, pass in pairs (PassCodeDB) do
						if id == randCode then
							PassText = pass.Cities -- utilizza i codici della citt�
						end
					end
					Authentication = string.format('%03d', groupMsgSerial) .. PassText

					-- enemy forces in the area assessment
					local TypeList = nil
					local ADSlist = nil
					for id, EnemyData in pairs (KnownEnemyList) do
						if EnemyData.EnemyCoalition ~= groupCoa then
							if EnemyData.Territory == groupDesTerr then
								if EnemyData.EnemyClass ~= "SRSAM" or EnemyData.EnemyClass ~= "AAA" then
									if string.find(EnemyData.EnemyType, TypeList) == false then
										TypeList = TypeList .. EnemyData.EnemyType .. ", "
									end
								elseif EnemyData.EnemyClass == "SRSAM" or EnemyData.EnemyClass == "AAA" then
									if string.find(EnemyData.EnemyType, ADSlist) == false then
										ADSlist = ADSlist .. EnemyData.EnemyType .. ", "
									end
								end
							end
						end
					end

					-- ground unit target
					if groupMixType == "B" then
						GroundUnitTarget = Callsign .. " HAS BEEN TASKED TO OCCUPY " .. string.upper(groupDesTerr) ..". TO ENSURE TASK ARCHIVEMENT A " .. groupMixSumCode .. " MISSION IS REQUESTED TO PREVENT ALLIED LOSSES IN GROUND ENGAGEMENTS.\n"
						if TypeList ~= nil then
							GroundUnitTarget = GroundUnitTarget .. "THOSE UNITS HAVE BEEN REPORTED OPERATING IN PROXIMITY OF THE OBJECTIVE: " .. TypeList .."\n"
						end
					-- add some ELSE?
					end

					-- enemy ADS
					if ADSlist ~= nil then
						ADSonTarget = ADSonTarget .. "THOSE AIR DEFENCE SYSTEMS HAVE BEEN REPORTED OPERATING CLOSE TO THE OBJECTIVE: " .. ADSlist .."\n"
					end

					-- Our grid
					for _,unitData in pairs(mist.DBs.aliveUnits) do
						if unitData.groupName == groupName then
							groupStrGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(unitData.pos)),1)
						end
					end

					if groupStrGrid ~= nil then
						ContactGrid = "CONTACT SHOULD BE MADE WITHIN " .. groupStrGrid .. " GRID"
					end

					-- ## BUILD LINES



					-- CREATE & COMBINE FILE
					local FileName = "AVIAREQ_PRIORITY-" .. groupMixPriority .. "_" .. string.format('%03d', groupMsgSerial) .. "_" .. Callsign
					local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. reportdirectory  .. FileName .. reportfiletype, "w")

					-- init
					local BlueINIT = "CLASSIFIED AVIAREQ/".. UIC .. "/" .. string.format('%03d', groupMsgSerial) .. "\n\n\n"
					-- line1
					local BlueLINE1 = "DATE AND TIME\n"
					local BlueLINE1 = BlueLINE1 .. ActualDayTime .. "\n\n"
					-- line2
					local BlueLINE2 = "UNIT\n"
					local BlueLINE2 = BlueLINE2 .. Callsign .. "\n\n"
					-- line3
					local BlueLINE3 = "ASSETS\n"
					local BlueLINE3 = BlueLINE3 .. "2 x KA-50 or 2 x A-10C" .. "\n\n" -- Change it making dependant by effective request?
					-- line4
					local BlueLINE4 = "PURPOSE\n"
					local BlueLINE4 = BlueLINE4 .. Subject .. "\n\n"
					-- line5
					local BlueLINE5 = "PRIORITY\n"
					local BlueLINE5 = BlueLINE5 .. Priority .. "\n\n"
					-- line6
					local BlueLINE6 = "DTG AND GRID OF PZ\n"
					local BlueLINE6 = BlueLINE6 .. "-" .. "\n\n" -- aggiungere DTG e posizione di una Pickup Zone se presente
					-- line7
					local BlueLINE7 = "DTG AND GRID OF LZ\n"
					local BlueLINE7 = BlueLINE7 .. "-" .. "\n\n" -- aggiungere DTG e posizione di una Landing Zone se presente
					-- line8
					local BlueLINE8 = "AC\n"
					local BlueLINE8 = BlueLINE8 .. "CHECK ACO FOR SUGGESTED ROUTE OR CORRIDORS" .. "\n\n" -- precisare se c'� un corridoio vicino?
					-- line9
					local BlueLINE9 = "ENEMY ADA\n"
					local BlueLINE9 = BlueLINE9 .. ADSonTarget .. "\n\n" -- list enemy Air Defense site by type and grid within 20 km from the target position.
					-- line10
					local BlueLINE10 = "TARGET\n"
					local BlueLINE10 = BlueLINE10 .. GroundUnitTarget .. "\n\n" --// bersaglio da attaccare
					-- line11
					local BlueLINE11 = "LOAD\n"
					local BlueLINE11 = BlueLINE11 .. "-" .. "\n\n" -- armamento // fai in base al bersaglio!
					-- line12
					local BlueLINE12 = "POC\n"
					local BlueLINE12 = BlueLINE12 .. ContactGrid .. "\n\n" -- point of contact. for some reason is the unit grid position
					-- line13
					local BlueLINE13 = "POC AT PZ/LD\n"
					local BlueLINE13 = BlueLINE13 .. "-" .. "\n\n" -- grid zone of the PZ
					-- line14
					local BlueLINE14 = "POC AT LZ\n"
					local BlueLINE14 = BlueLINE14 .. "-" .. "\n\n" -- grid zone of the LZ
					-- line15
					local BlueLINE15 = "FARP\n"
					local BlueLINE15 = BlueLINE15 .. "-" .. "\n\n" -- suggest farp Location within supported area
					-- line16
					local BlueLINE16 = "REMARKS\n"
					local BlueLINE16 = BlueLINE16 .. "-" .. "\n\n" -- remarks (safety risk assesment)
					-- line17
					local BlueLINE17 = "WEATHER\n"
					local BlueLINE17 = BlueLINE17 .. "SEE WEATHER FORECAST INCLUDED IN MISSION OVERVIEW" .. "\n\n" -- simple claim to weather info
					-- line18
					local BlueLINE18 = "NARRATIVE\n"
					local BlueLINE18 = BlueLINE18 .. Narrative .. "\n\n" -- check narrative info
					-- line19
					local BlueLINE19 = "AUTHENTICATION\n"
					local BlueLINE19 = BlueLINE19 .. Authentication .. "\n"


					-- lines aggregation
					a:write(BlueINIT)
					a:write(BlueLINE1)
					a:write(BlueLINE2)
					a:write(BlueLINE3)
					a:write(BlueLINE4)
					a:write(BlueLINE5)
					a:write(BlueLINE6)
					a:write(BlueLINE7)
					a:write(BlueLINE8)
					a:write(BlueLINE9)
					a:write(BlueLINE10)
					a:write(BlueLINE11)
					a:write(BlueLINE12)
					a:write(BlueLINE13)
					a:write(BlueLINE14)
					a:write(BlueLINE15)
					a:write(BlueLINE16)
					a:write(BlueLINE17)
					a:write(BlueLINE18)
					a:write(BlueLINE19)
					a:close()
				end
			end
		end
		DGWS.globalStateChanger()

	end
	--]]--

	local coaInRep = "blue" -- coalition in use for the report printing
	local rpStato = 1

	-- new Single-document report format
	DGWS.Report = function() -- WIP

		--[[-- FROM & TO INFO
		-- blue high organization names
		local blueHighJointCommand = "HQ USJFCOM NORFOLK VA"
		local blueHighGroundCommand = "HQ USAREUR WIESBADEN"
		local blueHighAirCommand = "HQ USAFE RAMSTEIN AFB"

		-- local
		local blueRescueCommand = "CDR ARRS KUTAISI AFB"
		local blueTransportCommand = "CDR MAC BATUMI"
		local blueJointCommand = "JFC KUTAISI AFB"
		local blueGroundCommand = "CDR 173IBCT ARFOR"
		local blueAirCommand = "CDR USAFE KUTAISI AFB"
		--]]--


		--[[-- UIC ADDITIONAL INFO
			1st STBC                            		= WAEL1A, http://www.wainwright.army.mil/1_25_SBCT/

			7TH SPECIAL FORCES GROUP (airborne) 		= WH0Y10, http://en.wikipedia.org/wiki/7th_Special_Forces_Group_(United_States)
			155th Brigade Combat Team (Armor)			= WTRAAA, http://www.globalsecurity.org/military/agency/army/155ar-bde.htm
			129th Field Artillery Regiment (Arty)		= WP4NAA, http://en.wikipedia.org/wiki/129th_Field_Artillery_Regiment#External_links
			184th Sustainment Command (Logistic)		= WX6XAA, http://en.wikipedia.org/wiki/Sustainment_Command_(Expeditionary)
			Joint Force Headquarters					= W8AMAA
			30th Troop Command							= W77AAA, http://www.globalsecurity.org/military/agency/army/30tc.htm
			50th Infantry Brigade Combat Team			= WX5PAA, http://en.wikipedia.org/wiki/50th_Infantry_Brigade_Combat_Team_(United_States)

			185th Aviation Brigade						= WVGZAA, http://en.wikipedia.org/wiki/185th_Aviation_Brigade_(United_States)
		--]]--


		if GlobalState == "I" then 																																					-- ### 1: CHECK GlobalState

			-- SITREP REPORT

			--write report function
			rpCycleExecute = function()



				-- check if cycle has to be stopped.
				local CycleRunning = true
				if rpStato > 2 then
					CycleRunning = false -- Stop Cycling
					--rpWriteReport()
					DGWS.globalStateChanger() -- Change the sim state
					mist.removeFunction(rpCycleRunProcess)
					--dmCycleExecute = nil -- reset nil status
					rpStato = 1
					coaInRep = "blue"
					if DGWSoncall == true then
						mist.message.add({text = "SITREP reports writed", displayTime = 5, msgFor = {coa = {"all"}} })
					end
				end

				if CycleRunning == true and coaInRep ~= "none" then

					local u = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "AssignedCallsign" .. exportfiletype, "r")
					for line in DGWStools.io.lines(u) do
						local rgId, rgCallsign = line:match("(.-)"..tss.."(.-)$")
							if (rgId) then
							AssignedCallsign[#AssignedCallsign + 1] = { gId = rgId, gCallsign = rgCallsign}
						end
					end
					u:close()


					local HighGroundCommand = ""
					local HighJointCommand = ""
					local HighAirCommand = ""
					local AirCommand = ""
					local RescueCommand = ""
					local TransportCommand = ""
					local JointCommand = ""
					local GroundCommand = ""

					if coaInRep == "blue" then
						HighGroundCommand = blueHighGroundCommand
						HighJointCommand = blueHighJointCommand
						HighAirCommand = blueHighAirCommand
						AirCommand = blueAirCommand
						RescueCommand = blueRescueCommand
						TransportCommand = blueTransportCommand
						JointCommand = blueJointCommand
						GroundCommand = blueGroundCommand
					else -- MANCANO
						HighGroundCommand = redHighGroundCommand
						HighJointCommand = redHighJointCommand
						HighAirCommand = redHighAirCommand
						AirCommand = redAirCommand
						RescueCommand = redRescueCommand
						TransportCommand = redTransportCommand
						JointCommand = redJointCommand
						GroundCommand = redGroundCommand
					end
					--]]--

					--read and close the planned movement list.
					plannedMovementListAVIAREQ = {} 																																		-- ### 2: UPDATE Planned movement list file
					local j = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "plannedMovementList" .. exportfiletype, "r")
					-- if DGWStools.io.read("*all")
					if j ~= nil then
						for line in DGWStools.io.lines(j) do
							if line then
								local rIDnum, rCoalition, rID, rGroupName, rTag, rFrom, rTo, rMissionType, rTime, rMsgSerial = line:match("(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
								--if type(rID) == "number" then
									plannedMovementListAVIAREQ[#plannedMovementListAVIAREQ + 1] = { ID = rID, Coalition = rCoalition, GroupName = rGroupName, Tag = rTag, From = rFrom, To = rTo, MissionType = rMissionType, Time = rTime, MsgSerial = rMsgSerial }
								--end
							end
						end
						j:close()
					end
					--]]--

					-- report variables
					local ReportText = ""									-- NOT READY
					-- single pages
					local Coverpage = ""									-- TEST, check Image embedding? / Possible?
					local IndexPage = ""									-- TEST
					local CampaignPage = ""									-- TEST
					local MovementTablepage = ""							-- TEST
					local TerritoriesPage = ""								-- NOT READY
					local ORBATpage = ""									-- TEST
					local SquadronPage = ""									-- NOT READY
					local TargetsPage = ""									-- TEST
					local Meteopage = ForecastText							-- TEST
					local Intelpage = ""									-- TEST
					local AVIAREQpages = ""									-- UPGRADE

					--[[ WORKING ON:
						- Intel Page
						- AVIAREQ Pages

					]]--


					-- #### Coverpage
					--(possible?)
					local missionNumber = CurrentCPmixnum + 1 -- UPDATE MISSION NUMBER ON A DIFFERENT BASIS!
					local dayNumber = CurrentCPdaynum + 1

					local LineCoverpage1 = "\n\n\n\nAeronautica Militare Virtuale Italiana" .. "\n\n"
					local LineImage = "\n\n\n\n\n\n\n\n\n\n\n\n\n"
					local LineCoverpage2 = BlueOPname .. "\n"
					local LineCoverpage3 = "Mission n�" .. missionNumber .. ", Day ".. dayNumber .. "\n\n\n"
					local LineCoverpage4 = "http://www.amvi.it\f"
					Coverpage = LineCoverpage1 .. LineImage .. LineCoverpage2 .. LineCoverpage3 .. LineCoverpage4
					
					if GlobalDEBUG == true then
						local FileName = "CoverPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = Coverpage
						a:write(DebugText)
						a:close()
					end
					
					-- #### IndexPage
					local LineIndex = "\n\n\nINDEX\n"
					LineIndex = LineIndex .. "- Coalition summary report\n"
					LineIndex = LineIndex .. "- Air support request table\n"
					--LineIndex = LineIndex .. "- Territories situation summary\n"
					LineIndex = LineIndex .. "- Order of Battle - ground assets\n"
					--LineIndex = LineIndex .. "- Order of Battle - liftable assets\n"
					LineIndex = LineIndex .. "- Targets\n"
					LineIndex = LineIndex .. "- Weather Forecast\n"
					LineIndex = LineIndex .. "- Intelligence\n"
					LineIndex = LineIndex .. "\n\n\nATTACHMENTS\n"
					LineIndex = LineIndex .. "- AVIAREQ reports\f"
					IndexPage = LineIndex

					if GlobalDEBUG == true then
						local FileName = "IndexPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = IndexPage
						a:write(DebugText)
						a:close()
					end
					--]]--

					-- #### TableMovementPage
					local MIXname = env.mission["sortie"] -- not used
					local TableMovement = ""
					local EnemyTableMovement = ""

					TableMovement = "\n\n\n" .. string.upper("Air support request table, Day " .. LineCoverpage3) .. "\n\n"
					TableMovement = TableMovement .. "FROM: " .. HighGroundCommand .. "\n"
					TableMovement = TableMovement .. "CC: " .. AirCommand .. "\n"
					TableMovement = TableMovement .. "CC: " .. HighJointCommand .. "\n"
					TableMovement = TableMovement .. "TO: " .. HighAirCommand .. "\n\n\n"
					--table composition
					TableMovement = TableMovement .. "\n\nPRIORITY SCALE\n\n0-VERY LOW\n1-LOW\n2-MEDIUM\n3-HIGH\n4-VERY HIGH\n5-NECESSARY\n\n"

					-- read Table of air tasking missions table
					TableMovement = TableMovement  .. "|" .. string.format("%-8s","PRIORITY") .. "|" .. string.format("%-6s","SERIAL") .. "|" .. string.format("%-20s","MISSION") .. "|" .. string.format("%-6s","FROM") .. "|" .. string.format("%-6s","TO") .. "|" .. string.format("%-11s","START TIME") .. "|\n"

					-- #### -> GO AFTER AVIAREQ


					-- #### read any group
					for id, moveGroup in pairs (plannedMovementListAVIAREQ) do	-- per ogni gruppo																										-- ### 3: FOR any planned movement build up an AVIAREQ-format document

						-- ## DEFINE AND RETRIEVE VARIABLES

						-- re-identify variables (not needed but I prefer to)
						local groupCoa = moveGroup.Coalition
						local groupName = moveGroup.GroupName
						local groupClass = moveGroup.Tag
						local groupStrTime = tonumber(moveGroup.Time)
						local groupStrTerr = moveGroup.From
						local groupDesTerr = moveGroup.To
						local groupMixType = moveGroup.MissionType
						local groupMsgSerial = tonumber(moveGroup.MsgSerial)

						-- to define variables
						local groupMixPriority = nil
						local groupMixSumCode = nil
						local groupMixDescription = nil

						-- other variables
						local Serial = 0 --serial number of the message. Reset for each mission.
						local UIC = "ToBeId"
						local Subject = "AIR SUPPORT REQUEST - "
						local LinesType = 0
						local Narrative = ""
						local Priority = ""
						local Callsign = ""
						local GroundUnitTarget = "-"
						local ADSonTarget = "-"
						local groupStrGrid = "-"
						local ContactGrid = "-"
						local ActualDayTime = nil
						local OperDayTime = nil
						local Remarks = nil


						-- ## EXECUTE DATA ELABORATION

						-- get callsign
						for id, callData in pairs (AssignedCallsign) do
							if callData.groupName == groupName then
								Callsign = callData.callsign
							end
						end

						-- retrieve mission info
						for MixId, MixData in pairs(GroundMissionType) do
							if MixId == groupMixType then


								groupMixPriority = MixData.AskSupport
								groupMixSumCode = MixData.SumCode
								Narrative = MixData.Description
								Subject = Subject .. groupMixSumCode

								if groupMixPriority == 1 then -- mission priority assignment
									Priority = "VERY LOW"
								elseif groupMixPriority == 1 then
									Priority = "LOW"
								elseif groupMixPriority == 2 then
									Priority = "MEDIUM"
								elseif groupMixPriority == 3 then
									Priority = "HIGH"
								elseif groupMixPriority == 4 then
									Priority = "VERY HIGH"
								elseif groupMixPriority == 5 then
									Priority = "NECESSARY"
								end -- END mission priority assignment
							end
						end

						local fromGrid = "noGrid"
						local toGrid = "noGrid"						

						-- Filtra coalizione e verifica disponibilit� dati per AVIAREQ
						if groupCoa == coaInRep
						and groupMsgSerial
						and groupMixPriority
						and groupMixSumCode
						and Callsign
						and Narrative
						and Subject
						then

							-- general info
							local BlueOPname = OPname
							local MIXname = env.mission["sortie"]

							-- actual time and minutes info
							local ActualDaygg = string.format("%02.f", CurrentCPdaynum)
							local ActualTimehh = string.format("%02.f", math.floor(((timer.getTime()) - ((math.floor(timer.getTime0()/24/3600))*3600*24))/3600))
							local ActualTimemm = string.format("%02.f", math.floor((((timer.getTime()) - ((math.floor(timer.getTime0()/24/3600))*3600*24))/60 - (ActualTimehh*60))))

							-- starting mission time and info (CORRECT)
							local StartDaygg = string.format("%02.f", (dayNumber))
							local StartTimehh = string.format("%02.f", math.floor(((timer.getTime0()+groupStrTime))/3600)) -- MAYBE ADD THE HOUR INCREMENT?
							local StartTimemm = string.format("%02.f", math.floor((((timer.getTime0()+groupStrTime))/60 - (StartTimehh*60)))) -- MAYBE ADD THE HOUR INCREMENT?

							ActualDayTime = ActualDaygg .. ActualTimehh .. ActualTimemm .. TZ
							OperDayTime = StartDaygg .. StartTimehh .. StartTimemm .. TZ

							-- update narrative
							Narrative = Narrative .. " MOVEMENT IS STARTING AT " .. OperDayTime

							-- assign UIC from group appartainance
							if groupClass == "IFV" or groupClass == "MBT" or groupClass == "ATGM"  then
								UIC = "WTRAAA"
							elseif groupClass == "LRSAM" or groupClass == "EWR"  then
								UIC = "ALLIED"
							elseif groupClass == "SRARTY" or groupClass == "LRARTY" or groupClass == "AAA" or groupClass == "SRSAM"  then
								UIC = "WP4NAA"
							elseif groupClass == "LOGISTIC" then
								UIC = "WX6XAA"
							elseif groupClass == "INFANTRY" or groupClass == "UNARMED" or groupClass == "APC" then
								UIC = "WX5PAA"
							elseif groupClass == "HQ" then
								UIC = "W77AAA"
							end

							-- authentication
							randCode = math.random(1,26)
							PassText = ""
							for id, pass in pairs (PassCodeDB) do
								if id == randCode then
									PassText = pass.Cities -- utilizza i codici della citt�
								end
							end
							Authentication = string.format('%03d', groupMsgSerial) .. PassText

							-- enemy forces in the area assessment
							local TypeList = nil
							local ADSlist = nil
							for id, EnemyData in pairs (KnownEnemyList) do
								if EnemyData.EnemyCoalition ~= groupCoa then
									if EnemyData.Territory == groupDesTerr then
										if EnemyData.EnemyClass ~= "SRSAM" or EnemyData.EnemyClass ~= "AAA" then
											if string.find(EnemyData.EnemyType, TypeList) == false then
												TypeList = TypeList .. EnemyData.EnemyType .. ", "
											end
										elseif EnemyData.EnemyClass == "SRSAM" or EnemyData.EnemyClass == "AAA" then
											if string.find(EnemyData.EnemyType, ADSlist) == false then
												ADSlist = ADSlist .. EnemyData.EnemyType .. ", "
											end
										end
									end
								end
							end

							-- ground unit target
							if groupMixType == "B" then
								GroundUnitTarget = Callsign .. " HAS BEEN TASKED TO OCCUPY " .. string.upper(groupDesTerr) ..". TO ENSURE TASK ARCHIVEMENT A " .. groupMixSumCode .. " MISSION IS REQUESTED TO PREVENT ALLIED LOSSES IN GROUND ENGAGEMENTS.\n"
								if TypeList ~= nil then
									GroundUnitTarget = GroundUnitTarget .. "THOSE UNITS HAVE BEEN REPORTED OPERATING IN PROXIMITY OF THE OBJECTIVE: " .. TypeList .."\n"
								end
							-- add some ELSE?
							end

							-- enemy ADS
							if ADSlist ~= nil then
								ADSonTarget = ADSonTarget .. "THOSE AIR DEFENCE SYSTEMS HAVE BEEN REPORTED OPERATING CLOSE TO THE OBJECTIVE: " .. ADSlist .."\n"
							end

							-- Our grid
							for _,unitData in pairs(mist.DBs.aliveUnits) do
								if unitData.groupName == groupName then
									groupStrGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(unitData.pos)),1)
								end
							end

							if groupStrGrid ~= nil then
								ContactGrid = "CONTACT SHOULD BE MADE WITHIN " .. groupStrGrid .. " GRID"
							end

							-- from/to grid
							-- actual position
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									if objData.objName == groupStrTerr then
										local placeName = objData.objName
										local placeClass = objData.objIsBorder
										local placeBattle = objData.objBattle
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										fromGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(OBJPos)),1)
									elseif objData.objName == groupDesTerr then
										local placeName = objData.objName
										local placeClass = objData.objIsBorder
										local placeBattle = objData.objBattle
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										toGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(OBJPos)),1)
									end
								end
							end
							--]]--

							-- ## BUILD LINES

							-- init
							local BlueINIT = "CLASSIFIED AVIAREQ/".. UIC .. "/" .. string.format('%03d', groupMsgSerial) .. "\nPRIORITY " .. groupMixPriority .. "\n\n\n" 					-- ### 4: BUILD up every lines as a string
							-- line1
							local BlueLINE1 = "DATE AND TIME\n"
							local BlueLINE1 = BlueLINE1 .. ActualDayTime .. "\n"
							-- line2
							local BlueLINE2 = "UNIT\n"
							local BlueLINE2 = BlueLINE2 .. Callsign .. "\n"
							-- line3
							local BlueLINE3 = "ASSETS\n"
							local BlueLINE3 = BlueLINE3 .. "2 x KA-50 or 2 x A-10C" .. "\n" -- Change it making dependant by effective request?
							-- line4
							local BlueLINE4 = "PURPOSE\n"
							local BlueLINE4 = BlueLINE4 .. Subject .. "\n"
							-- line5
							local BlueLINE5 = "PRIORITY\n"
							local BlueLINE5 = BlueLINE5 .. Priority .. "\n"
							-- line6
							local BlueLINE6 = "DTG AND GRID OF PZ\n"
							local BlueLINE6 = BlueLINE6 .. "-" .. "\n" -- aggiungere DTG e posizione di una Pickup Zone se presente
							-- line7
							local BlueLINE7 = "DTG AND GRID OF LZ\n"
							local BlueLINE7 = BlueLINE7 .. "-" .. "\n" -- aggiungere DTG e posizione di una Landing Zone se presente
							-- line8
							local BlueLINE8 = "AC\n"
							local BlueLINE8 = BlueLINE8 .. "CHECK ACO FOR SUGGESTED ROUTE OR CORRIDORS" .. "\n" -- precisare se c'� un corridoio vicino?
							-- line9
							local BlueLINE9 = "ENEMY ADA\n"
							local BlueLINE9 = BlueLINE9 .. ADSonTarget .. "\n" -- list enemy Air Defense site by type and grid within 20 km from the target position.
							-- line10
							local BlueLINE10 = "TARGET\n"
							local BlueLINE10 = BlueLINE10 .. GroundUnitTarget .. "\n" --// bersaglio da attaccare
							-- line11
							local BlueLINE11 = "LOAD\n"
							local BlueLINE11 = BlueLINE11 .. "-" .. "\n" -- armamento // fai in base al bersaglio!
							-- line12
							local BlueLINE12 = "POC\n"
							local BlueLINE12 = BlueLINE12 .. ContactGrid .. "\n" -- point of contact. for some reason is the unit grid position
							-- line13
							local BlueLINE13 = "POC AT PZ/LD\n"
							local BlueLINE13 = BlueLINE13 .. "-" .. "\n" -- grid zone of the PZ
							-- line14
							local BlueLINE14 = "POC AT LZ\n"
							local BlueLINE14 = BlueLINE14 .. "-" .. "\n" -- grid zone of the LZ
							-- line15
							local BlueLINE15 = "FARP\n"
							local BlueLINE15 = BlueLINE15 .. "-" .. "\n" -- suggest farp Location within supported area
							-- line16
							local BlueLINE16 = "REMARKS\n"
							local BlueLINE16 = BlueLINE16 .. "-" .. "\n" -- remarks (safety risk assesment)
							-- line17
							local BlueLINE17 = "WEATHER\n"
							local BlueLINE17 = BlueLINE17 .. "SEE WEATHER FORECAST INCLUDED IN MISSION OVERVIEW" .. "\n" -- simple claim to weather info
							-- line18
							local BlueLINE18 = "NARRATIVE\n"
							local BlueLINE18 = BlueLINE18 .. Narrative .. "\n" -- check narrative info
							-- line19
							local BlueLINE19 = "AUTHENTICATION\n"
							local BlueLINE19 = BlueLINE19 .. Authentication																											-- ### 4: CLOSE the page

							AVIAREQpages = 	AVIAREQpages .. BlueINIT .. BlueLINE1 .. BlueLINE2 .. BlueLINE3 .. BlueLINE4 .. BlueLINE5 .. BlueLINE6 .. BlueLINE7 .. BlueLINE8 .. BlueLINE9 .. BlueLINE10 .. BlueLINE11 .. BlueLINE12 .. BlueLINE13 .. BlueLINE14 .. BlueLINE15 .. BlueLINE16 .. BlueLINE17 .. BlueLINE18 .. BlueLINE19 .. "\f"

							-- Tablemovement data
							TableMovement = TableMovement  .. "|" .. string.format("%-8s",groupMixPriority) .. "|" .. string.format("%-6s",string.format('%03d',groupMsgSerial)) .. "|" .. string.format("%-20s",groupMixSumCode) .. "|" .. string.format("%-6s",fromGrid) .. "|" .. string.format("%-6s",toGrid) .. "|" .. string.format("%-11s",OperDayTime) .. "|\n"


							-- ADD DATA TO THE AIR PLANNING MIX TABLE
						elseif groupCoa ~= coaInRep then

							local fromGrid = "noGrid"
							local toGrid = "noGrid"
							local StartDaygg = string.format("%02.f", (dayNumber))
							local StartTimehh = string.format("%02.f", math.floor(((env.mission["start_time"]+groupStrTime))/3600)) -- MAYBE ADD THE HOUR INCREMENT?
							local StartTimemm = string.format("%02.f", math.floor((((env.mission["start_time"]+groupStrTime))/60 - (StartTimehh*60)))) -- MAYBE ADD THE HOUR INCREMENT?							
							local OperDayTime = StartDaygg .. StartTimehh .. StartTimemm .. TZ
							
							-- actual position
							for _, objData in pairs(Objectivelist) do
								if (objData) then
									if objData.objName == groupStrTerr then
										local placeName = objData.objName
										local placeClass = objData.objIsBorder
										local placeBattle = objData.objBattle
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										fromGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(OBJPos)),1)
									elseif objData.objName == groupDesTerr then
										local placeName = objData.objName
										local placeClass = objData.objIsBorder
										local placeBattle = objData.objBattle
										local OBJx = objData.objCoordx
										local OBJz = objData.objCoordy
										local OBJPos = {
														x = OBJx,
														y = 0,
														z = OBJz
														}
										toGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(OBJPos)),1)
									end
								end
							end
							--]]--							
							
							local prob = math.random(0,100)
							if prob < IntelMovDiscovered then
								local Composition = ""
								for Oid,Odata in pairs (ORBATlist) do
									if groupName == Odata.groupName then
										Composition = Odata.groupTypeList
									end
								end
								EnemyTableMovement = EnemyTableMovement .. "|" 
								.. string.format("%-7s",groupClass) .. "|" 
								.. string.format("%-6s",fromGrid) .. "|" 
								.. string.format("%-6s",toGrid) .. "|" 
								.. string.format("%-11s",OperDayTime) .. "|" 
								.. string.format("%-30s",Composition) .. "|\n"
							end
						end -- End filtro gruppi
					end  -- End Loop Gruppi
					--]]--

					--> RESUME TableMovement page

					TableMovement = TableMovement .. "\f"

					if GlobalDEBUG == true then
						local FileName = "TableMovmentDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = TableMovement
						a:write(DebugText)
						a:close()
					end
					--]]--

					MovementTablepage = TableMovement

					-- #### END TableMovement page

					-- #### CampaignPage
					local Status = ""
					local Situation = ""
					local TotalForces = ""
					local AtkPercentage = ""
					local DefPercentage = ""
					local LogPercentage = ""
					local PrefTarget = ""
					local ValuableAssets = ""
					local StratN = table.getn(StrategicRep)
					if StratN > 0 then 
						for coa, coaData in pairs(StrategicRep) do
							if coa == coaInRep then
								Status = coaData.Status -- offensive/defensive/neutral
								Situation = coaData.Description -- describe the current situation
								TotalForces = coaData.TotFOR -- (number)
								AtkPercentage = math.floor((tonumber(coaData.AtkFOR)/tonumber(coaData.TotFOR))*100) -- forces that play a role in attack
								DefPercentage = math.floor((tonumber(coaData.DefFOR)/tonumber(coaData.TotFOR))*100) -- forces that play a role in defence
								LogPercentage = math.floor((tonumber(coaData.LogFOR)/tonumber(coaData.TotFOR))*100) -- forces that play a role in defence
								PrefTarget = coaData.PrefTGT
							else
								ValuableAssets = coaData.PrefTGT
							end -- end Coa filter
						end -- End StrategiRep loop
					end
					--]]--

					-- text lines
					local LineCampaign = ""

					LineCampaign = "\n\n\n" .. string.upper("Coalition summary report") .. "\n\n"
					LineCampaign = LineCampaign .. "Current Status: " .. string.upper(Status) .."\n"
					LineCampaign = LineCampaign .. "FROM: " .. HighGroundCommand .. "\n"
					LineCampaign = LineCampaign .. "CC: " .. HighJointCommand .. "\n"
					LineCampaign = LineCampaign .. "CC: " .. HighAirCommand .. "\n"
					LineCampaign = LineCampaign .. "TO: " .. AirCommand .. "\n\n\n"
					LineCampaign = LineCampaign .. "Current Status: " .. string.upper(Status) .."\n"
					LineCampaign = LineCampaign .. "Situation description: " .. Situation .."\n\n"
					LineCampaign = LineCampaign .. "Our forces can rely upon a total number of " .. TotalForces .." military vehicles, which are about " .. AtkPercentage .. "% best fitted for attacking action, " .. DefPercentage .. "% fitted for defensive operations and " .. LogPercentage .. "% are supply and logistic enforcements\n\n"
					LineCampaign = LineCampaign .. "In addition to incoming air support requests from Joint Force Command (see next page), Given our knowledge about OPFOR strengths and weaknesses, ground command will be happy to prioritize any " .. PrefTarget .."vehicles class as target of opportunity during your missions. Equally important, is believed that successful defences of our " .. ValuableAssets .. " class vehicle could make our position stronger.\n"
					CampaignPage = LineCampaign

					if GlobalDEBUG == true then
						local FileName = "CampaignPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = CampaignPage
						a:write(DebugText)
						a:close()
					end
					--]]--

					-- END CampaignPage

					-- #### Targets Page /// SELEZIONA
					local CoaString = "TARGETS TABLE" .. "\n\n\n" .. string.upper(string.format("%-20s","CALLSIGN").. "|" .. string.format("%-7s","GRID").. "|" .. string.format("%-7s","STATUS").. "|" .. string.format("%-4s","PRI.")) .. "\n"
					local CoaDesc = ""

					-- blue targets loop
					for tid, TgtData in pairs(TargetsTable) do

							local TgtClass = TgtData.TargetType
							local TgtCoa = TgtData.Coalition
							local point = { x = TgtData.TargetX, y = 0, z = TgtData.TargetY }
							local lat, lon = coord.LOtoLL(mist.utils.makeVec3(point));
							local TgtCoord = DGWS.tostringLL(lat, lon, 3)
							--local TgtCoord = coordinates
							local TgtName = TgtData.TargetName
							--TgtLenght = string.len(TgtName)
							local TgtCallsign = TgtData.Callsign
							local TgtStatus = (tostring((tonumber(TgtData.Status)*100)) .. "%")
							local TgtGrid = DGWS.tostringMGRS(coord.LLtoMGRS(lat, lon),1)
							local TgtPriority = nil
							if TgtClass == "Military" then
								TgtPriority = TgtData.MilPry
							elseif TgtClass == "Structure" then
								TgtPriority = TgtData.LogPry
							end

							local theString = string.upper(string.format("%-20s",TgtCallsign).. "|" .. string.format("%-7s",TgtGrid).. "|" .. string.format("%-7s",TgtStatus).. "|" .. string.format("%-4s",TgtPriority)) .. "\n"

							if TgtCoa == coaInRep then
								CoaString = CoaString .. theString
								CoaDesc = CoaDesc 		.. "CALLSIGN:     " .. string.upper(string.format("%-50s",TgtCallsign) .. "\n")
														.. "NAME:         " .. string.format("%-50s",TgtName) .. "\n"
														.. "TYPE:         " .. string.format("%-50s",TgtClass) .. "\n"
														.. "GRID:         " .. string.format("%-50s",TgtGrid) .. "\n"
														.. "COORDINATES:  " .. string.format("%-50s",TgtCoord) .. "\n"
														.. "STATUS:       " .. string.format("%-50s",TgtStatus) .. "\n"
														.. "PRIORITY:     " .. string.format("%-50s",TgtPriority) .. "\n"
														.. "\n\n"
							end
					end
					--]]--

					TargetsPage = TargetsPage .. CoaString .. "\f" .. CoaDesc .. "\f"

					if GlobalDEBUG == true then
						local FileName = "TargetsPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = TargetsPage
						a:write(DebugText)
						a:close()
					end
					--]]--

					--[[
					local h = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. reportdirectory .. "TargetsSummary.doc", "w")
					h:write(CoaString)
					h:write("\f")
					h:write(CoaDesc)
					h:write("\f")
					h:close()
					]]--


					-- #### ORBAT Page
					ORBATpage = ""

					-- build the Region tables
					local RegionTable = {}
					local EnemyRegionTable = {}
					local TempTerrain = Objectivelist
					local RegionNum = 0
					for _, TerrData in pairs (TempTerrain) do
						local RegionName = TerrData.objRegion
						local TerrainName = TerrData.objName
						local addAllow = true
						local EaddAllow = true
						--allied
						for Rid, Rdata in pairs (RegionTable) do
							if Rdata.Name == RegionName then
								addAllow = false
								local addTerr = true
								if string.find(Rdata.Terr,TerrainName) then
									addTerr = false
								end
								if addTerr == true then
									Rdata.Terr = Rdata.Terr .. "/" .. TerrainName
								end
							end
						end
						if addAllow == true then
							RegionNum = RegionNum + 1
							RegionTable[#RegionTable + 1] = {IDnum = RegionNum, Name = RegionName, Terr = TerrainName, OBatgm = 0, OBmbt = 0, OBifv = 0, OBapc = 0, OBarty = 0, OBlrads = 0, OBsrads = 0, OBsup = 0, OBrec = 0}
						end
						-- enemy
						for ERid, ERdata in pairs (EnemyRegionTable) do
							if ERdata.Name == RegionName then
								EaddAllow = false
								local addTerr = true
								if string.find(ERdata.Terr,TerrainName) then
									addTerr = false
								end
								if addTerr == true then
									ERdata.Terr = ERdata.Terr .. "/" .. TerrainName
								end
							end
						end
						if EaddAllow == true then
							RegionNum = RegionNum + 1
							EnemyRegionTable[#EnemyRegionTable + 1] = {IDnum = RegionNum, Name = RegionName, Terr = TerrainName, OBatgm = 0, OBmbt = 0, OBifv = 0, OBapc = 0, OBarty = 0, OBlrads = 0, OBsrads = 0, OBsup = 0, OBrec = 0}
						end
					end
					--]]--

					-- ORBATlist =  IDnum, groupID, groupCtr, groupTag, groupCoa, groupName, groupSize, groupAtk, groupDef, groupRng, groupGrid, groupTerr, groupCallsign, groupTypeList
					local DetailedORBATtext = "ORBAT - DETAILS\n\nStatus: -: Combat Ready; d: damaged; la: low ammo; lf: low petrol;\n\n"
					DetailedORBATtext = DetailedORBATtext .. "|" .. string.format("%-20s","CALLSIGN") .. "|" .. string.format("%-8s","CLASS") .. "|" .. string.format("%-6s","GRID") .. "|" .. string.format("%-20s","REGION") .. "|" .. string.format("%-6s","STATUS") .. "|\n\n"

					local RegionORBATtext = "ORBAT - SUMMARY\n\n"
					local ERegionORBATtext  = ""
					local ADStext = ""
					RegionORBATtext = RegionORBATtext .. "|" .. string.format("%-20s","REGION") .. "|" .. string.format("%-6s","MBT") .. "|" .. string.format("%-6s","ARMOR") .. "|" .. string.format("%-6s","ARTY") .. "|" .. string.format("%-6s","ADS") .. "|" .. string.format("%-6s","RECON") .. "|" .. string.format("%-6s","SUPPLY") .. "|\n\n"


					for id, OBdata in pairs (ORBATlist) do
						if OBdata.groupCoa == coaInRep then
							local EffCallsign = ""
							local Callsign = OBdata.groupName
							local Location = OBdata.groupTerr
							local Grid = OBdata.groupGrid
							local Class = OBdata.groupTag
							local Country = OBdata.groupCtr
							local Id = OBdata.groupID
							local Region = ""

							--Find Assigned Region
							for _, RegData in pairs (RegionTable) do
								if string.find(RegData.Terr,Location) then
									for Cid, Cdata in pairs (UnitsClass) do
										if Class == Cid then -- check that the listed class exist
											Region = RegData.Name
											if Class == "MBT" then
												RegData.OBmbt = RegData.OBmbt + 1
											elseif Class == "IFV" then
												RegData.OBifv = RegData.OBifv + 1
											elseif Class == "APC" then
												RegData.OBapc = RegData.OBapc + 1
											elseif Class == "ATGM" then
												RegData.OBatgm = RegData.OBatgm + 1
											elseif Class == "LRARTY" or Class == "SRARTY" then
												RegData.OBarty = RegData.OBarty + 1
											elseif Class == "AAA" or Class == "SRSAM" then
												RegData.OBsrads = RegData.OBsrads + 1
											elseif Class == "LRSAM" or Class == "EWR" then
												RegData.OBlrads = RegData.OBlrads + 1
											elseif Class == "LOGISTIC" then
												RegData.OBsup = RegData.OBsup + 1
											elseif Class == "RECON" then
												RegData.OBrec = RegData.OBrec + 1
											end
											
								-- ORA E' QUI		
								RegionORBATtext = RegionORBATtext .. "|" 
								.. string.format("%-20s",RegData.Name) .. "|" 
								.. string.format("%-6s",RegData.OBmbt) .. "|" 
								.. string.format("%-6s",(RegData.OBifv+RegData.OBapc+RegData.OBatgm)) .. "|" 
								.. string.format("%-6s",RegData.OBarty) .. "|" 
								.. string.format("%-6s",(RegData.OBsrads+RegData.OBlrads)) .. "|" 
								.. string.format("%-6s",RegData.OBrec) .. "|" 
								.. string.format("%-6s",RegData.OBsup) .. "|\n"											
											
										end
									end
									
								end

								-- ERA QUI


							end

							for Gid, GCall in pairs (AssignedCallsign) do
								if OBdata.groupID == Gid then
									EffCallsign = GCall.gCallsign
								else
									EffCallsign = Callsign
								end
							end


							-- detailed text
							DetailedORBATtext = DetailedORBATtext .. "|" .. string.format("%-20s",EffCallsign) .. "|" .. string.format("%-8s",Class) .. "|" .. string.format("%-6s",Grid) .. "|" .. string.format("%-20s",Region) .. "|" .. string.format("%-6s","-") .. "|\n"

						else
							-- check if group has been identified
							local isKnown = false
							for Kid, Kdata in pairs(KnownEnemyList) do
								if OBdata.groupName == Kdata.groupName then
									isKnown = true
								end
							end

							if isKnown == true then
								local Callsign = OBdata.groupName
								local Location = OBdata.groupTerr
								local Grid = OBdata.groupGrid
								local Class = OBdata.groupTag
								local Type = OBdata.groupTag -- cahnge
								local Country = OBdata.groupCtr
								local Id = OBdata.groupID
								local Region = ""

								--Find Assigned Region
								for _, ERegData in pairs (EnemyRegionTable) do
									if string.find(ERegData.Terr,Location) then
										for Cid, Cdata in pairs (UnitsClass) do
											if Class == Cid then -- check that the listed class exist
												if Class == "MBT" then
													ERegData.OBmbt = ERegData.OBmbt + 1
												elseif Class == "IFV" then
													ERegData.OBifv = ERegData.OBifv + 1
												elseif Class == "APC" then
													ERegData.OBapc = ERegData.OBapc + 1
												elseif Class == "ATGM" then
													ERegData.OBatgm = ERegData.OBatgm + 1
												elseif Class == "LRARTY" or Class == "SRARTY" then
													ERegData.OBarty = ERegData.OBarty + 1
												elseif Class == "AAA" or Class == "SRSAM" then
													ERegData.OBsrads = ERegData.OBsrads + 1
													local isSAM = false
													local adsType = ""

													for uId ,uData in pairs(mist.DBs.aliveUnits) do
														if uData.groupId == OBdata.groupID then
															local unitType = uData.type
															for class, UnitType in pairs(UnitsClass) do
																if class == Class then
																	local identifier = UnitType.type
																	if typeMatch(identifier, unitType ) then
																		isSAM = true
																		adsType = unitType
																	end
																end
															end
														end
													end

													ADStext = ADStext .. "|" .. string.format("%-7s",Grid) .. "|" .. string.format("%-15s",adsType) .. "|" .. string.format("%-10s","-") .. "|" .. string.format("%-12s","-") .. "|" .. string.format("%-6s","-") .. "|\n"
												elseif Class == "LRSAM" or Class == "EWR" then
													ERegData.OBlrads = ERegData.OBlrads + 1
												elseif Class == "LOGISTIC" then
													ERegData.OBlsup = ERegData.OBlsup + 1
												elseif Class == "RECON" then
													ERegData.OBlrec = ERegData.OBlrec + 1
												end
											end
										end
										Region = ERegData.Name
									end

									ERegionORBATtext = ERegionORBATtext .. "|" .. string.format("%-15s",ERegData.Name) .. "|" .. string.format("%-6s",ERegData.OBmbt) .. "|" .. string.format("%-6s",(ERegData.OBifv+ERegData.OBapc+ERegData.OBatgm)) .. "|" .. string.format("%-6s",ERegData.OBarty) .. "|" .. string.format("%-6s",(ERegData.OBsrads+RegData.OBlrads)) .. "|" .. string.format("%-6s",ERegData.OBlrec) .. "|" .. string.format("%-6s",ERegData.OBlsup) .. "|\n"

								end

							end
						end
					end
					--]]--
					DetailedORBATtext = DetailedORBATtext .. "\n\n\n"
					RegionORBATtext = RegionORBATtext .. "\n\n\nCheck next page for detailed group informations\n"



					ORBATpage = RegionORBATtext .."\f" .. DetailedORBATtext

					if GlobalDEBUG == true then
						local FileName = "ORBATPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = ORBATpage
						a:write(DebugText)
						a:close()
					end
					--]]--

					-- #### END - ORBAT Page

					-- #### Intel Page
					Intelpage = ""
					Intelpage = Intelpage .. "INTEL REPORT - DAY " .. dayNumber .. "\n\n\n"
					Intelpage = Intelpage .. "Index:\n-Summary OPFOR asset information\n-OPFOR known air defence assets\n-Known OPFOR movement plan\n\n\n"
					Intelpage = Intelpage .. string.upper("Summary OPFOR asset information\n\n")

					Intelpage = Intelpage .. "|" .. string.format("%-15s","REGION") .. "|" .. string.format("%-6s","MBT") .. "|" .. string.format("%-6s","ARMOR") .. "|" .. string.format("%-6s","ARTY") .. "|" .. string.format("%-6s","ADS") .. "|" .. string.format("%-6s","RECON") .. "|" .. string.format("%-6s","SUPPLY") .. "|\n"
					if ERegionORBATtext == "" then
						ERegionORBATtext = "no available informations"
					end
					Intelpage = Intelpage .. ERegionORBATtext .. "\n\n\n"

					Intelpage = Intelpage .. string.upper("OPFOR known air defence assets\n\n")
					Intelpage = Intelpage .. "|" .. string.format("%-7s","GRID") .. "|" .. string.format("%-15s","TYPE") .. "|" .. string.format("%-10s","WEZ-RANGE") .. "|" .. string.format("%-12s","WEZ-ALTITUDE") .. "|" .. string.format("%-6s","STATUS") .. "|\n"
					if ADStext == "" then
						ADStext = "no available informations"
					end					
					Intelpage = Intelpage .. ADStext .. "\n\n\n"

					Intelpage = Intelpage .. string.upper("Known OPFOR ground assets movement\n\n")
					Intelpage = Intelpage .. "|" .. string.format("%-7s","TYPE") .. "|" .. string.format("%-6s","FROM") .. "|" .. string.format("%-6s","TO") .. "|" .. string.format("%-11s","TIME") .. "|" .. string.format("%-30s","COMPOSITION") .. "|\n"
					if EnemyTableMovement == "" then
						EnemyTableMovement = "no available informations"
					end

					Intelpage = Intelpage .. EnemyTableMovement .. "\f"

					if GlobalDEBUG == true then
						local FileName = "IntelPageDebug"
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. FileName .. reportfiletype, "w")
						local DebugText = Intelpage
						a:write(DebugText)
						a:close()
					end
					--]]--

					-- #### END - Intel Page
					
					
					-- #### Write report file
					rpWriteReport = function() -- NECESSARY TO CREATE A GLOBAL ONE!?
						local FileName = "DGWS-SITREP-Day" .. dayNumber
						local directory = ""
						if coaInRep == "blue" then
							directory = subdirectory .. campaigndirectory.. coaBlueDirectory
							--[[
							if directory == nil then
								DGWStools.lfs.mkdir(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory.. coaBlueDirectory)
								directory = subdirectory .. campaigndirectory.. coaBlueDirectory
							end
							--]]--
						elseif coaInRep == "red" then
							directory = subdirectory .. campaigndirectory.. coaRedDirectory
							--[[
							if directory == nil then
								DGWStools.lfs.mkdir(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory.. coaRedDirectory)
								directory = subdirectory .. campaigndirectory.. coaRedDirectory
							end
							--]]--
						end
						local a = DGWStools.io.open(DGWStools.lfs.currentdir() .. directory .. FileName .. reportfiletype, "w")
						ReportText = Coverpage .. IndexPage .. CampaignPage .. MovementTablepage .. TerritoriesPage .. ORBATpage .. SquadronPage .. Meteopage .. Intelpage .. AVIAREQpages
						a:write(ReportText)
						a:close()
					end
					--]]--
					rpWriteReport()

					-- #####################################################
					-- #####################################################
					-- #####################################################

					
				end -- #### End filtro Cyclerunning


				rpStato = rpStato +1

				if rpStato == 1 then
					coaInRep = "blue"
				elseif rpStato == 2 then
					coaInRep = "red"
				else
					coaInRep = "none"
				end


			end -- End funzione di loop
			--]]--

			-- schedule the cycle
			rpCycleRunProcess = mist.scheduleFunction(rpCycleExecute,{}, timer.getTime() + 1, InnerStateTimer, missionLasting)


		end	-- End Filtro GlobalState

	end
	--]]--



--#########################################################################################################################
--############################################### DEBUG FUNCTIONS #########################################################
--#########################################################################################################################
--#########################################################################################################################


-- ###### Z) DEBUG ######


	-- ??
	DGWS.DEBUGobjetivelist = function()
		local fName = "DGWS-DEBUG-objectivelist.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		local debugOBJ = ""

		for _, objData in pairs(Objectivelist) do
			debugOBJ = objData.objID .. tss .. objData.objName .. tss .. objData.objRegion .. tss .. objData.objCoalition .. "\n"  -- tss .. objData.objCoordx .. tss .. objData.objCoordy ..
			f:write(debugOBJ)
		end
		f:close()
	end
	--]]-- END debug objectivelist

	-- ??
	DGWS.DEBUGorbatlist = function()
		local fName = "DGWS-DEBUG-ORBATlist.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		local debugORBAT = ""

		for _, ORBATData in pairs(ORBATlist) do
			debugORBAT = ORBATData.groupID .. tss .. ORBATData.groupCtr .. tss .. ORBATData.groupTag .. tss .. ORBATData.groupCoa .. tss .. ORBATData.groupName .. tss .. ORBATData.groupSize .. tss .. ORBATData.groupAtk .. tss .. ORBATData.groupDef .. tss .. ORBATData.groupRng .. tss .. ORBATData.groupGrid .. tss .. ORBATData.groupTerr .. tss .. ORBATData.groupTypeList .. "\n"
			f:write(debugORBAT)
			--groupAtk = rgroupAtk, groupDef = rgroupDef, groupRng = rgroupRng, groupGrid = rgroupGrid, groupTerr = rgroupTerr, groupTypeList = rgroupTypeList
		end
		f:close()
	end
	--]]-- END debug ORBATlist

	-- OK WORKS
	DGWS.DEBUGKnownEnemylist = function()
		local fName = "DGWS-DEBUG-KnownEnemylist.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		local debugKEL = ""

		for _, KELData in pairs(KnownEnemyList) do
			debugKEL = KELData.EnemyID .. tss .. KELData.EnemyCoalition .. tss .. KELData.EnemyGroupName .. tss .. KELData.EnemyName .. tss .. KELData.EnemyType .. tss .. KELData.EnemyClass .. tss .. KELData.Enemyattacklvl .. tss .. KELData.Enemydefencelvl .. tss .. KELData.Enemyrangeatklvl .. tss .. KELData.EnemyX .. tss .. KELData.EnemyZ .. tss .. KELData.EnemyY .. tss .. KELData.OwnGroup .. tss .. KELData.ReportTime .. tss .. math.floor(KELData.Distance) .. tss .. KELData.Territory .. "\n"
			f:write(debugKEL)
		end
		f:close()
	end
	--]]-- END debug KEL

	-- OK, WORKS
	DGWS.DEBUGgroupSITREPlist = function()
		local fName = "DGWS-DEBUG-groupSITREPlist.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		local debugSITREP = ""
		f:write("OwngroupId,OwngroupName,OwngroupCoa,TotalAlliedAttack,TotalAlliedDefence,TotalAlliedRange,TotalEnemyAttack,TotalEnemyDefence,TotalEnemyRange,AtkDiff,DefDiff,RgnDiff,TotalAlliedSize,TotalEnemySize,AtkRapp,DefRapp,RngRapp" .. "\n")

		for _, SITREPData in pairs(groupSITREPList) do
			debugSITREP = SITREPData.OwngroupId .. tss .. SITREPData.OwngroupName .. tss .. SITREPData.OwngroupCoa .. tss .. SITREPData.TotalAlliedAttack .. tss .. SITREPData.TotalAlliedDefence .. tss .. SITREPData.TotalAlliedRange .. tss .. SITREPData.TotalEnemyAttack .. tss .. SITREPData.TotalEnemyDefence .. tss .. SITREPData.TotalEnemyRange .. tss .. SITREPData.AtkDiff .. tss .. SITREPData.DefDiff .. tss .. SITREPData.RgnDiff .. tss .. SITREPData.TotalAlliedSize .. tss .. SITREPData.TotalEnemySize .. "\n"
			f:write(debugSITREP)
		end
		f:close()
	end
	--]]-- END debug SITREP

	-- OK, WORKS
	DGWS.DEBUGFunctionsTable = function()
		local fName = "DGWS-DEBUG-functionstable.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		local debugFT = ""
		f:write("GroupName".. tss .."FuncID\n")

		for _, FTData in pairs(FunctionsTable) do
			debugFT = FTData.GroupName .. tss .. FTData.FuncID .. "\n"
			f:write(debugFT)
		end
		f:close()
	end
	--]]--

	-- DEGUG FOR GLOBAL STATE
	DGWS.DEBUGglobalstate = function()
		local fName = "DGWS-DEBUG-globalstatechanger.txt"
		local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
		f:write(debugGlobalState)
		f:close()
	end
	mist.scheduleFunction(DGWS.DEBUGglobalstate,{},timer.getTime() + StartMovDelay*60, 1, (missionLasting))
	--]]--



--#########################################################################################################################
--###########################################   INT MOSS FUNCTIONS   ######################################################
--#########################################################################################################################
--#########################################################################################################################


	--###########################################   CONFIG FILE   ######################################################


	--dofile(DGWStools.lfs.currentdir() .. 'Scripts/DGWS/DGWS_beta.lua');

	-- --[[ DEBUG PART. remove the double "--" here to comment everything.  // ADDED BY LTO
	local debugProcess = true --// SET THIS FALSE TO PREVENT DEBUGGING  -- WORKS FOR MOSS INTEGRATION ASPECTS ONLY

	if debugProcess == true then
		local debugFile = ""
		local debugFileName = "MOSSdebugFile.lua"
		debugFileTXT = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. debugFileName, "w")
		debugFileTXT:write("init log\n")
	end
	--]]--   // ADDED BY LTO

	--[[

	-- save mode. May be:
	-- MANUAL: save is triggerd manually from menu
	-- ONEND: save is triggered on mission end
	-- ONLCDISC: save is triggered by Last Client Disconnect
	gMOSSSaveMode = "MANUAL";

	-- enable update period (times ten frames), to be used in ONEND save mode
	gMOSSUpdatePeriod = 900;

	-- enable group/kind removal if all units where killed (WARNING should be kept off)
	gMOSSGKRemoval = false;

	-- enable mission resume on first client connect
	gMOSSResumeOnConn = true;

	-- enable mission pause on last client diconnect
	gMOSSPauseOnDisc = true;

	-- following string is added to the initial welcome message
	gMOSSServerMOTD = "";

	]]--

	--###########################################   MAIN FILE   ######################################################


	-- imported basicSerialize
	function IntegratedbasicSerialize(s)
		if s == nil then
			return "\"\""
		else
			if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
				return tostring(s)
			elseif type(s) == 'string' then
				return string.format('%q', s)
			end
		end
	end
	--]]--

	-- imported slmod.serialize
	function Integratedserialize(name, value, level)
		-----Based on ED's serialize_simple2
		local basicSerialize = function (o)
		  if type(o) == "number" then
			return tostring(o)
		  elseif type(o) == "boolean" then
			return tostring(o)
		  else -- assume it is a string
			return IntegratedbasicSerialize(o)
		  end
		end

		local serialize_to_t = function (name, value, level)
		----Based on ED's serialize_simple2


		  local var_str_tbl = {}
		  if level == nil then level = "" end
		  if level ~= "" then level = level.."  " end

		  table.insert(var_str_tbl, level .. name .. " = ")

		  if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
			table.insert(var_str_tbl, basicSerialize(value) ..  ",\n")
		  elseif type(value) == "table" then
			  table.insert(var_str_tbl, "\n"..level.."{\n")

			  for k,v in pairs(value) do -- serialize its fields
				local key
				if type(k) == "number" then
				  key = string.format("[%s]", k)
				else
				  key = string.format("[%q]", k)
				end

				table.insert(var_str_tbl, Integratedserialize(key, v, level.."  "))

			  end
			  if level == "" then
				table.insert(var_str_tbl, level.."} -- end of "..name.."\n")

			  else
				table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")

			  end
		  else
			print("Cannot serialize a "..type(value))
		  end
		  return var_str_tbl
		end

		local t_str = serialize_to_t(name, value, level)

		return table.concat(t_str)
	end
	--]]--

	-- imported slmod.serializeWithCycles
	function IntegratedserializeWithCycles(name, value, saved)
		local basicSerialize = function (o)
			if type(o) == "number" then
				return tostring(o)
			elseif type(o) == "boolean" then
				return tostring(o)
			else -- assume it is a string
				return IntegratedbasicSerialize(o)
			end
		end

		local t_str = {}
		saved = saved or {}       -- initial value
		if ((type(value) == 'string') or (type(value) == 'number') or (type(value) == 'table') or (type(value) == 'boolean')) then
			table.insert(t_str, name .. " = ")
			if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
				table.insert(t_str, basicSerialize(value) ..  "\n")
			else

				if saved[value] then    -- value already saved?
					table.insert(t_str, saved[value] .. "\n")
				else
					saved[value] = name   -- save name for next time
					table.insert(t_str, "{}\n")
					for k,v in pairs(value) do      -- save its fields
						local fieldname = string.format("%s[%s]", name, basicSerialize(k))
						table.insert(t_str, IntegratedserializeWithCycles(fieldname, v, saved))
					end
				end
			end
			return table.concat(t_str)
		else
			return ""
		end
	end
	--]]--


	-- USED IN MOSSUpdate()
	-- Retrieve units from export // chiede all'export di fornire un elenco delle unit� attuali.
	-- non va il NET.DOSTRING_IN

	function MOSSGetWorldObjects()
	  local res = nil;
	  local res_str, success = net.dostring_in('export', "return Integratedserialize('wobjs', LoGetWorldObjects(), '')");
	  if not success then

		if debugProcess == true then
			debugFileTXT:write("--> MOSSGetWorldObjects() non � riuscito a prendere i contenuti, res_str � nil." .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

		return nil
	  end
	  return res_str;
	end
	--]]--

	-- update units and write the new mission file
	function MOSSSave()
	  -- TODO locking may be needed here!!!!
	  if not gMOSSMix then

		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() non ha trovato contenuti in gMOSSMix" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

		return false
	  end

	  --[[
	  if not gMOSSMixObjs then
		gMOSSMixObjs = gMOSSMix 			-- ATTENZIONE : AGGIUNTO DA ME PER CHECK, DA RIMUOVERE.

		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() non ha trovato contenuti in gMOSSMixObjs, li ha sostituiti con gMOSSMix" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

		--return false // TOGLI il commento DOPO IL DEBUG, deve tornare "return False"
	  end
	  ]]--
		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() sta per caricare gMOSSMix" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end	 	  

	  local mixFun, mErrStr = loadstring(gMOSSMix); -- crea una funzione con il contenuto della stringa
	  
		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() ha caricato gMOSSMix" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end	  
	  --local objsFun, oErrStr = loadstring(gMOSSMixObjs);
	  if mixFun then   -- and objsFun
		local env = { };
		setfenv(mixFun, env); -- assegna la funzione all' ENV
		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() setfenv eseguito" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end	  		
		--setfenv(objsFun, env);
		mixFun();
		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() mixFun eseguito" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end			
		--objsFun();

		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() � riuscito a settare gli env separati" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

		for id, MEunitData in pairs(mist.DBs.MEunitsById) do
			local MaybeDead = MEunitData.unitName
			local VerifiedDead = true

			for id,ALunitData in pairs(mist.DBs.aliveUnits) do
				local SureAlive = ALunitData.unitName

				if SureAlive == MaybeDead then
					VerifiedDead = false

					if debugProcess == true then
						debugFileTXT:write("--> MOSSSave() ha trovato l'unit� da uccidere: " .. MaybeDead .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
					end

				end
			end

			if VerifiedDead == true then
				MOSSKillUnit(env.mission, MaybeDead);
			end
		end
		-- remove dead units  // POSSIBILE RIMPIAZZO USANDO mist.DB.alive units // DA REINTEGRARE!!!
		--for i = 1,#slmod.deadUnits do
		  --MOSSKillUnit(env.mission, slmod.deadUnits[i].killed_unit);
		--end

		-- update units positions
		for ID,Object in pairs(mist.DBs.aliveUnits) do -- wobjs viene creato da objsFun
		  if Object.unitName then
			MOSSUpdateUnit(env.mission, Object, not AirUnitsUpd);
		  end
		end


		-- update startime
		DGWS.UpdateMissionStartTime()
		env.mission.start_time = NEWstartTime

		-- update weather
		DGWS.UpdateWeather()
		env.mission.weather = NEWweather

		if DAWS then
			for IgId, IgData in pairs (tabledGroups) do
				local groupName = IgData.Name
				local groupTable = IgData.Table
				local coalition_ID = IgData.Coa -- QUIQUIQUI
				local country_ID = IgData.Country
				IgDebugText = IgDebugText .. "Inserimento gruppo con dati: Group: " .. groupName .. ", Coalition: " .. coalition_ID .. ", Country: " .. country_ID .. "\n"
				IgWritedebug()
				DAWS.InsertGroup(env.mission, coalition_ID, country_ID, groupTable)
			end
		end


		-- generate output script
		local fName = "mission"
		--local lfs = require('lfs')
		local missName = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. fName
		local outFile = DGWStools.io.open(missName, "w");
		local newMissionStr = IntegratedserializeWithCycles('mission', env.mission);
		outFile:write(newMissionStr);
		DGWStools.io.close(outFile);

		--local deskMissName = "C:\Users\lorenzo\Desktop\prova.lua"
		--DGWStools.fs.copy(missName, deskMissName);

		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() � riuscito a scrivere il file missione" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end
	-- TODO generate complete miz file
	  else

		if debugProcess == true then
			debugFileTXT:write("--> MOSSSave() non � riuscito a scrivere il file missione!" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

		return false
	  end

	  return true
	end
	--]]--

	-- find a unit by name in the mission table
	function MOSSUnitLookup(mission, unitName)
	  for coalitionID,coalition in pairs(mission["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
		  for attrID,attr in pairs(country) do
			if (type(attr)=="table") then
			  for groupID,group in pairs(attr["group"]) do
				if (group) then
				  for unitID,unit in pairs(group["units"]) do
					if (unit.name) then
					  if (unit.name == unitName) then
						return coalitionID,coalition,
							countryID,country,
							attrID,attr,
							groupID,group,
							unitID,unit;
					  end
					end
				  end
				end
			  end
			end
		  end
		end
	  end
	  return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil;
	end
	--]]--

	-- kill a unit (or mark dead if static)
	function MOSSKillUnit(mission, unitName)
	  local coalitionID,coalition,
		  countryID,country,
		  kindID,kind,
		  groupID,group,
		  unitID,unit = MOSSUnitLookup(mission, unitName);

	  if not unit then
		if debugProcess == true then
			debugFileTXT:write("--> MOSSKillUnit() non ha trovato l'unit� da uccidere: " .. MaybeDead .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end
	  end

	  --gMOSSLog:write("[DEBUG  ] Unit ".. unitName .." killed\n");

	  -- if the unit is static, mark as dead and leave
	  if (kindID == "static") then
		group["dead"] = true;
	  else

		table.remove(group.units, unitID);
		-- remove subtree up to country if empty
		local next = next;
		if next(group.units) == nil then
			--[[
		  if kind.group[groupID]["name"] then
			gMOSSLog:write("[DEBUG  ] Group ".. kind.group[groupID]["name"] .. " is empty\n");
		  else
			gMOSSLog:write("[DEBUG  ] Group unnamed [".. groupID .."] is empty\n");
		  end -]]

		  if gMOSSGKRemoval then
			kind.group[groupID] = nil;
			--gMOSSLog:write("[DEBUG  ] Group ".. groupID .."] killed\n");
		  end
		  if gMOSSGKRemoval and next(kind.group) == nil then
			country[kindID] = nil;
		  end
		end
	  end
	end
	--]]--

	-- update unit position in respect to world object provided
	function MOSSUpdateUnit(mission, object, keepAUPos)
	  if not object.unitName then
		return
	  end

	  local coalitionID,coalition,
		  countryID,country,
		  kindID,kind,
		  groupID,group,
		  unitID,unit = MOSSUnitLookup(mission, object.unitName)

	  --if not unit then
		--gMOSSLog:write("[WARNING] Unit ".. object.UnitName .." not found for update\n")
		--return
	  --end

	  if keepAUPos and (kindID == "plane" or kindID =="helicopter") then
		return
	  end

	  --if gMOSSLogVerbose then
		--gMOSSLog:write("[INFO   ] Unit "..object.UnitName .." pos updated\n")
	  --end

	  --group.route.points = nil  --// Crea chunk per eliminare i punti di rotta > 1

	  unit["x"] = object.pos["x"];
	  unit["y"] = object.pos["z"];
	  --unit["heading"] = object.Heading;

	  if unitID == 1 then  -- try to fix ME stuff
		group["x"] = unit["x"];
		group["y"] = unit["y"];
		group.route.points[1]["x"] = unit["x"];
		group.route.points[1]["y"] = unit["y"];
	  end


		local NEWgroupName = ""
		for _,ORBATdata in pairs(ORBATlist) do
			if group["groupId"] == tonumber(ORBATdata.groupID) then
				NEWgroupName = ORBATdata.groupName
			end
		end
		group["name"] = NEWgroupName

		for id, pointData in pairs (group.route.points) do
			if id > 1 then
				table.remove(group.route.points, id);
			end
		end

	-- TODO process altitude for air units

	end
	--]]--

	--[[ update unit position in respect to world object provided
	function MOSSUpdateGroup(mission, object, keepAUPos)
	  if not object.unitName then
		return
	  end

	  local coalitionID,coalition,
		  countryID,country,
		  kindID,kind,
		  groupID,group,
		  unitID,unit = MOSSUnitLookup(mission, object.unitName)

	  --if not unit then
		--gMOSSLog:write("[WARNING] Unit ".. object.UnitName .." not found for update\n")
		--return
	  --end

	  if keepAUPos and (kindID == "plane" or kindID =="helicopter") then
		return
	  end

	  --if gMOSSLogVerbose then
		--gMOSSLog:write("[INFO   ] Unit "..object.UnitName .." pos updated\n")
	  --end

	  --group.route.points = nil  --// Crea chunk per eliminare i punti di rotta > 1

	  unit["x"] = object.pos["x"];
	  unit["y"] = object.pos["z"];
	  --unit["heading"] = object.Heading;
	  if unitID == 1 then  -- try to fix ME stuff
		group["x"] = unit["x"];
		group["y"] = unit["y"];
		group.route.points[1]["x"] = unit["x"];
		group.route.points[1]["y"] = unit["y"];
		local NEWgroupName = group["name"] .. "a"
		for _,ORBATdata in pairs(ORBATlist) do
			if groupID == ORBATdata.groupID then
				NEWgroupName = ORBATdata.groupName
			end
		end

	  end
	  group["name"] = NEWgroupName

		for id, pointData in pairs (group.route.points) do
			if id > 1 then
				table.remove(group.route.points, id);
			end
		end

	-- TODO process altitude for air units

	end
	--]]--

	-- reset state variables to initial state
	function MOSSReset() -- OK
	  SaveProcedureInitDone = false;
	  gMOSSNextEventIdx = nil;
	  gMOSSEvents = {};
	  gMOSSFC = 5;          -- phase shift to avoid running in the same slmod frame

		if debugProcess == true then
			debugFileTXT:write("--> MOSSReset() ha resettato le variabili e completato il processo" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

	end
	--]]--

	function IntegratedGetUnzippedMission(t_window) -- OK

		t_window = t_window or 3600 -- default: if t_window not specified, look at all files newer than 1 hour
		local run_t = DGWStools.os.time()
		local mis_path, mis_t
		local path =  DGWStools.lfs.tempdir()

		for file in DGWStools.lfs.dir(path) do
			if file and file:sub(1,1) == '~' then
				local fpath = path .. '/' .. file
				local mod_t = DGWStools.lfs.attributes(fpath, 'modification')
				if mod_t and math.abs(run_t - mod_t) <= t_window then
					local f = DGWStools.io.open(fpath, 'r')
					if f then
						local fline = f:read()
						if fline and fline:sub(1,7) == 'mission' and (not mis_t or mod_t > mis_t) then -- found an unzipped mission file, and either none was found before or this is the most recent
							mis_t = mod_t
							mis_path = fpath
						end
						f:close()
					end
				end
			end
		end

		if mis_path then -- a mission file was found
			local f = DGWStools.io.open(mis_path, 'r')
			if f then
				local mission = f:read('*all')
				f:close()

				if debugProcess == true then
					--debugFileTXT:write("--> SCRITTURA FILE MISSION IN TEMPDIR\n" .. mission .. "\n<-- FINE SCRITTURA FILE MISSION IN TEMPDIR\n")   -- PRINTA TUTTO!
					debugFileTXT:write("--> mission file in tempdir opened" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
				end

				return mission
			end
		end
	end
	--]]--

	--funzioni di start, run & stop
	function MOSSStartMission()  -- OK

		MOSSReset();

		--gMOSSLog:write("[DEBUG  ] Mission start\n");

		gMOSSMix = IntegratedGetUnzippedMission();

		if debugProcess == true and gMOSSMix ~= nil then
			debugFileTXT:write("--> MOSSStartMission() ha creato gMOSSMix, che non � nil" .. "\n")	  -- Printa solo conferma che ha letto la variabile mission.
		end

	--[[--
	  if gMOSSMenu then   --// NON MI SERVE
		gMOSSMenu:destroy();
		gMOSSMenu = nil;
	  end
	  --MOSSCreateMenu();  // NON SERVE??
	--]]--

	  SaveProcedureInitDone = true;

	end
	--]]--



	--execute the savefile update.
	DGWS.startStateSaveup = function()
		MOSSStartMission()
	end
	--]]--

	-- execute the "mission" file export!
	DGWS.doSaveFile = function()

		MOSSSave()
		DebugPrint()

		DGWS.globalStateChanger()
	end
	--]]--

	-- debug function limited to MOSS integration (and not working that good, all issue has been solved before it was necessary)
	function DebugPrint()
		if debugProcess == true then
			debugFileTXT:close()
		else
			return
		end
	end
	--]]--

	--update the mission start time
	function DGWS.UpdateMissionStartTime()
		if UpdateSceneryDate == true then

			NextCPid = CurrentCPid
			NextCPmixnum = CurrentCPmixnum + 1
			NextCPdaynum = CurrentCPdaynum + 1  -- maybe update in the future...
			NextstatusOngoing = CurrentstatusOngoing

			if NightMission == true then
				NEWstartTime = (NextMIZdata*24*60*60) + math.random(8,21)*60*60
			else
				NEWstartTime = (NextMIZdata*24*60*60) + math.random(8,15)*60*60
			end

			--DGWS.updateCampaignStatus(NextCPid,NextCPmixnum,NextCPdaynum,NextstatusOngoing)

		else -- mission time isn't going to change!
			NEWstartTime = MEstartTime
		end
	end
	--]]--

	-- update the weather
	function DGWS.UpdateWeather()

		--[[		start	end		season
		STANDARD SEASONS
		Primavera	293		19		3
		Estate		20		113		1
		Autunno		114		203		4
		Inverno		204		292		2
		--]]--

		--[[
			rain limit = 5
			thunder limit = 9

		--]]--


		--[[
			TEMPERATURE MODEL DATA PLOTTED FROM https://weatherspark.com database of KUTAISI
			TMAX - y = -9E-13x6 + 7E-10x5 - 2E-07x4 + 1E-05x3 - 0.0004x2 + 0.0342x + 31.013
			TMIN - y = -6E-13x6 + 6E-10x5 - 2E-07x4 + 3E-05x3 - 0.0039x2 + 0.2203x + 15.92

		]]--

		--## VARIABLES
		local Temperature = nil
		local TempMin = nil
		local TempMax = nil
		--local MEweather = mission.["weather"]
		NEWweather = nil
		local seasonId = nil
		local maxDayTemp = 14*60*60 -- seconds
		local minDayTemp = 2*60*60 -- seconds
		local pressure = nil
		local precipitation = nil
		local cloudcoverage = nil
		local cloudlevel = nil
		local cloudthickness = nil
		local visibility = nil
		local winddir0 = nil
		local winddir2 = nil
		local winddir8 = nil
		local windspeed0 = nil
		local windspeed2 = nil
		local windspeed8 = nil
		local turbolence0 = nil
		local turbolence2 = nil
		local turbolence8 = nil
		local weatherName = nil

		--local StartTime = NEWstartTime

		--## TABLES

		-- Cities Climates constant (see meteoCity variable)
		local cityClimate =
			{

				["Kutaisi"] =
				{
					["TempMax"] = -- temperature model factor. Temperature model is a polinomial 6 order curve build over a yearly graphic. Gives Tmax at that day
					{
						["a"] = -0.0000000000009,
						["b"] = 0.0000000007,
						["c"] = -0.0000002,
						["d"] = 0.00001,
						["e"] = 0.0004,
						["f"] = 0.0342,
						["g"] = 31.013,
					},
					["TempMin"] = -- temperature model factor. Temperature model is a polinomial 6 order curve build over a yearly graphic. Gives Tmin at that day
					{
						["a"] = -0.0000000000006,
						["b"] = 0.0000000006,
						["c"] = -0.0000002,
						["d"] = 0.00003,
						["e"] = 0.0039,
						["f"] = 0.2203,
						["g"] = 15.92,
					},
					["Seasons"] =
					{
						["Summer"] =
						{
							["Start"] = 1,
							["Id"] = 1,
							["Pmax"] = 766,
							["Pmin"] = 751,
							["RainProb"] = 20,
							["StorProb"] = 11,
							["WindDir"] = 90, -- prevalent wind direction, degrees. 65% of the times the wind will run this way. 30% will run opposite. 5% other.
							["WindSpeed"] = 5,
							["WindSpeedVar"] = 90, -- percent of wind speed	that could vary.
							["WindCalmProb"] = 21, -- percent of probability for haveing a wind of max 2 m/s.
							["CloudMin"] = 700, -- minimum average level when low clouds condition is true
							["CloudLowProb"] = 2, -- probability in % to get a low cloud condition
							["CloudAvg"] = 3000, -- average cloud level
							["CloudTkn"] = 500, -- average cloud thickness
							["VisibilityAvg"] = 50000, -- average visibility value
						},
						["Winter"] =
						{
							["Start"] = 198,
							["Id"] = 2,
							["Pmax"] = 755,
							["Pmin"] = 777,
							["RainProb"] = 40,
							["StorProb"] = 4,
							["WindDir"] = 270, -- prevalent wind direction, degrees. 65% of the times the wind will run this way. 30% will run opposite. 5% other.
							["WindSpeed"] = 6,
							["WindSpeedVar"] = 60, -- percent of wind speed	that could vary.
							["WindCalmProb"] = 19, -- percent of probability for haveing a wind of max 2 m/s.
							["CloudMin"] = 799, -- minimum average level when low clouds condition is true
							["CloudLowProb"] = 8, -- probability in % to get a low cloud condition
							["CloudAvg"] = 3000, -- average cloud level
							["CloudTkn"] = 500, -- average cloud thickness
							["VisibilityAvg"] = 50000, -- average visibility value
						},
						["Spring"] =
						{
							["Start"] = 285,
							["Id"] = 3,
							["Pmax"] = 776,
							["Pmin"] = 760,
							["RainProb"] = 30,
							["StorProb"] = 3,
							["WindDir"] = 270, -- prevalent wind direction, degrees. 65% of the times the wind will run this way. 30% will run opposite. 5% other.
							["WindSpeed"] = 7,
							["WindSpeedVar"] = 30, -- percent of wind speed	that could vary.
							["WindCalmProb"] = 18, -- percent of probability for haveing a wind of max 2 m/s.
							["CloudMin"] = 700, -- minimum average level when low clouds condition is true
							["CloudLowProb"] = 6, -- probability in % to get a low cloud condition
							["CloudAvg"] = 3000, -- average cloud level
							["CloudTkn"] = 500, -- average cloud thickness
							["VisibilityAvg"] = 50000, -- average visibility value
						},
						["Fall"] =
						{
							["Start"] = 107,
							["Id"] = 4,
							["Pmax"] = 755,
							["Pmin"] = 769,
							["RainProb"] = 15,
							["StorProb"] = 1,
							["WindDir"] = 270, -- prevalent wind direction, degrees. 65% of the times the wind will run this way. 30% will run opposite. 5% other.
							["WindSpeed"] = 6,
							["WindSpeedVar"] = 70, -- percent of wind speed	that could vary.
							["WindCalmProb"] = 20, -- percent of probability for haveing a wind of max 2 m/s.
							["CloudMin"] = 700, -- minimum average level when low clouds condition is true
							["CloudLowProb"] = 20, -- probability in % to get a low cloud condition
							["CloudAvg"] = 3000, -- average cloud level
							["CloudTkn"] = 500, -- average cloud thickness
							["VisibilityAvg"] = 50000, -- average visibility value
						},
					},
				},
			}

		-- calculate TempMin & TempMax
		for city, cityData in pairs(cityClimate) do
			if city == meteoCity then
				-- define temperature min & max from model
				local BaseTempMin = (cityData.TempMin.a*(NextMIZdata^6) + cityData.TempMin.b*(NextMIZdata^5) + cityData.TempMin.c*(NextMIZdata^4) + cityData.TempMin.d*(NextMIZdata^3) + cityData.TempMin.e*(NextMIZdata^2) + cityData.TempMin.f*(NextMIZdata) + cityData.TempMin.g)
				local BaseTempMax = (cityData.TempMax.a*(NextMIZdata^6) + cityData.TempMax.b*(NextMIZdata^5) + cityData.TempMax.c*(NextMIZdata^4) + cityData.TempMax.d*(NextMIZdata^3) + cityData.TempMax.e*(NextMIZdata^2) + cityData.TempMax.f*(NextMIZdata) + cityData.TempMax.g)

				-- define current temperature in the day using sinusoid function that define temperature using Tmax as 14:00 and Tmin as 2:00. CHECK IF BETTER SOLUTION TO DEFINE HOURS COULD BE APPLIED
				local A = BaseTempMax - BaseTempMin
				local K = BaseTempMin + (A/2)
				local T = math.floor(((A/2)*math.sin(NEWstartTime*0.0000728+(-4*(math.pi/6)))+K)*(math.random(75,125)/100))
				Temperature = DGWS.round(T, 0)

				-- define season
				if NextMIZdata >= cityData.Seasons.Summer.Start and NextMIZdata < cityData.Seasons.Fall.Start then
					seasonId = cityData.Seasons.Summer.Id
				elseif NextMIZdata >= cityData.Seasons.Fall.Start and NextMIZdata < cityData.Seasons.Winter.Start then
					seasonId = cityData.Seasons.Fall.Id
				elseif NextMIZdata >= cityData.Seasons.Winter.Start and NextMIZdata < cityData.Seasons.Spring.Start then
					seasonId = cityData.Seasons.Winter.Id
				elseif NextMIZdata >= cityData.Seasons.Spring.Start and NextMIZdata < 366 then
					seasonId = cityData.Seasons.Spring.Id
				else
					seasonId = 3 --spring, in case of errors
				end

				-- define rain, thunderstorm, pressure, wind
				for season, seasonData in pairs(cityData.Seasons) do
					if seasonData.Id == seasonId then

						-- winds
						local calmProb = math.random(1,100)
						if calmProb < seasonData.WindCalmProb then
							winddir0 = math.random(1,359)
							winddir2 = math.random(1,359)
							winddir8 = math.random(1,359)
							windspeed0 = math.random(0,2)
							windspeed2 = math.random(0,2)
							windspeed8 = math.random(0,2)
							turbolence0 = math.random(0,2)
							turbolence2 = math.random(5,10)  -- muntain condition
							turbolence8 = math.random(0,2)
						else
							local prevWindProb = math.random(1,100)
							if prevWindProb < 66 then
								winddir0 = math.random(seasonData.WindDir-5,seasonData.WindDir+5)
								if winddir0 > 359 then winddir0 = winddir0 - 360 end
								winddir2 = math.random(seasonData.WindDir-5,seasonData.WindDir+5)
								if winddir2 > 359 then winddir2 = winddir2 - 360 end
								winddir8 = math.random(seasonData.WindDir-5,seasonData.WindDir+5)
								if winddir8 > 359 then winddir8 = winddir8 - 360 end
							elseif prevWindProb > 65 and prevWindProb < 96 then
								winddir0 = math.random(seasonData.WindDir+175,seasonData.WindDir+185)
								if winddir0 > 359 then winddir0 = winddir0 - 360 end
								winddir2 = math.random(seasonData.WindDir+175,seasonData.WindDir+185)
								if winddir2 > 359 then winddir2 = winddir2 - 360 end
								winddir8 = math.random(seasonData.WindDir+175,seasonData.WindDir+185)
								if winddir8 > 359 then winddir8 = winddir8 - 360 end
							else
								winddir0 = math.random(0,359)
								winddir2 = math.random(0,359)
								winddir8 = math.random(0,359)
							end
							windspeed0 = math.random(seasonData.WindSpeed-(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)),seasonData.WindSpeed+(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)))
							windspeed2 = math.random(seasonData.WindSpeed+5-(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)),seasonData.WindSpeed+5+(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)))
							windspeed8 = math.random(seasonData.WindSpeed-(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)),seasonData.WindSpeed+(seasonData.WindSpeed*((seasonData.WindSpeedVar)/100)))
							turbolence0 = windspeed0
							turbolence2 = windspeed2
							turbolence8 = windspeed8
						end

						-- visibility
						visibility = math.random(seasonData.VisibilityAvg*0.8,seasonData.VisibilityAvg*1.2)

						-- cloudlevel
						local lowCloudsProb = math.random(1,100)
						if lowCloudsProb < seasonData.CloudLowProb then
							cloudlevel = math.random(seasonData.CloudMin*0.8,seasonData.CloudMin*1.2)
							cloudthickness = math.random(seasonData.CloudTkn*0.8,seasonData.CloudTkn*1.2)
						else
							cloudlevel = math.random(seasonData.CloudAvg*0.8,seasonData.CloudAvg*1.2)
							cloudthickness = math.random(seasonData.CloudTkn*0.8,seasonData.CloudTkn*1.2)
						end

						-- Precipitation & cloudcover
						local stormTrue = false
						local rainTrue = false
						local stormProb = math.random(1,100)
						local rainProb = math.random(1,100)
						if stormProb <= seasonData.StorProb then
							stormTrue = true
						elseif rainProb <= seasonData.RainProb then
							rainTrue = true
						end

						if stormTrue == true and Temperature <= 4 then
							precipitation = 4
							cloudcoverage = math.random(9,10)
						elseif stormTrue == true and Temperature > 4 then
							precipitation = 2
							cloudcoverage = math.random(9,10)
						elseif rainTrue == true and Temperature <= 4 then
							precipitation = 3
							cloudcoverage = math.random(5,10)
						elseif rainTrue == true and Temperature > 4 then
							precipitation = 1
							cloudcoverage = math.random(5,10)
						else
							precipitation = 0
							cloudcoverage = math.random(0,7)
						end

						-- variables
						pressure = math.random(seasonData.Pmin, seasonData.Pmax)

						-- name
						weatherName = season .. ", Operation date: " .. NextOPdate

					end
				end
			end
		end

		--[[
		iprecptns = 0 - nulla
		iprecptns = 1 - pioggia
		iprecptns = 2 - temporale
		iprecptns = 3 - neve
		iprecptns = 4 - tempesta neve
		--]]--

		-- check inclement weather filter
		if InclementWeather == false then
			--no wind > 15 kn is allowed
			--no low-level cloud is allowed
			--no storm or snowstorm is allowed
			--no temperature

			--check T & reset
			if Temperature > 40 then
				Temperature = math.random(35,40)
			elseif Temperature < -10 then
				Temperature = math.random(1,3)
			end

			--check & reset wind
			if windspeed0 > 8 then
				windspeed0 = math.random(4,8)
			end
			if windspeed2 > 12 then
				windspeed2 = math.random(6,10)
			end
			if windspeed8 > 8 then
				windspeed8 = math.random(4,8)
			end

			-- check & reset precipitation
			if precipitation == 2 then
				precipitation = 1
			elseif precipitation == 4 then
				precipitation = 3
			end
		end


		NEWweather = {
			["atmosphere_type"] = 0,
			["wind"] =
			{
				["at8000"] =
				{
					["speed"] = windspeed8,
					["dir"] = winddir8,
				}, -- end of ["at8000"]
				["atGround"] =
				{
					["speed"] = windspeed0,
					["dir"] = winddir0,
				}, -- end of ["atGround"]
				["at2000"] =
				{
					["speed"] = windspeed2,
					["dir"] = winddir2,
				}, -- end of ["at2000"]
			}, -- end of ["wind"]
			["enable_fog"] = false,
			["turbulence"] =
			{
				["at8000"] = turbolence8,
				["atGround"] = turbolence0,
				["at2000"] = turbolence2,
			}, -- end of ["turbulence"]
			["season"] =
			{
				["iseason"] = seasonId,
				["temperature"] = Temperature,
			}, -- end of ["season"]
			["type_weather"] = 0,
			["qnh"] = pressure,
			["cyclones"] =
			{
			}, -- end of ["cyclones"]
			["name"] = weatherName,
			["fog"] =
			{
				["thickness"] = 0,
				["visibility"] = 25,
				["density"] = 7,
			}, -- end of ["fog"]
			["visibility"] =
			{
				["distance"] = visibility,
			}, -- end of ["visibility"]
			["clouds"] =
			{
				["thickness"] = cloudthickness,
				["density"] = cloudcoverage,
				["base"] = cloudlevel,
				["iprecptns"] = precipitation,
			}, -- end of ["clouds"]
		} -- end of ["weather"]
		--]]--

		local Windfrom0 = winddir0 + 180
		if Windfrom0 > 359 then Windfrom0 = Windfrom0 - 360 end
		local Windfrom2 = winddir2 + 180
		if Windfrom2 > 359 then Windfrom2 = Windfrom2 - 360 end
		local Windfrom8 = winddir8 + 180
		if Windfrom8 > 359 then Windfrom8 = Windfrom8 - 360 end

		local WindSpd0 = math.ceil(windspeed0*1.9426026)
		local WindSpd2 = math.ceil(windspeed2*1.9426026)
		local WindSpd8 = math.ceil(windspeed8*1.9426026)

		local PrecType = ""
		if precipitation == 0 then
			PrecType = "absent"
		elseif precipitation == 1 then
			PrecType = "rain"
		elseif precipitation == 2 then
			PrecType = "storm"
		elseif precipitation == 3 then
			PrecType = "snow"
		elseif precipitation == 4 then
			PrecType = "snowstorm"
		end

		-- FORECAST LINES COMPOSITION
		--[[
		OKTAS: 6/10
		Cloud base: 4200 mt
		Wind: 270 deg @ 2 m/s
		Precipitation: rain
		Temperature: 28 �C
		Pressure: 739 mmHg
		--]]--
		local Line1 = "WEATHER FORECAST\n\n"
		local Line2 = "Day: " .. NextOPdate .. "\n"
		local Line3 = "Cloud coverage (OKTAS): " .. cloudcoverage .. "/10\n"
		local Line4 = "Cloud base: " .. cloudlevel .. " m, thickness: " .. cloudthickness .." m\n"
		local Line5 = "Wind (ground): " .. Windfrom0 .. " deg, at " .. WindSpd0 ..  " kn\n"
		local Line6 = "Wind (6500 ft): " .. Windfrom2 .. " deg, at " .. WindSpd2 ..  " kn\n"
		local Line7 = "Wind (25000 ft): " .. Windfrom8 .. " deg, at " .. WindSpd8 ..  " kn\n"
		local Line8 = "Precipitation: " .. PrecType .. "\n"
		local Line9 = "Pressure: " .. pressure .. " mmHg, " .. math.ceil(pressure*1000*0.0013332) .. " mbar, " .. math.ceil((pressure*0.039370079197408404)*100)/100 .. " mmHg/ft�\n\n"

		ForecastText = Line1 .. Line2 .. Line3 .. Line4 .. Line5 .. Line6 .. Line7 .. Line8 .. Line9.. "\f"
		-- END FORECAST TEXT

	end
	--]]--

	--[[
	local UpdateSceneryDate = true
	local MissionHourInterval = 21600 -- seconds between missions in a campaign scenery
	local NightMission = false -- if set "false", it will prevent to set up mission in evening and night hours.
	local NightMissionMaxThereshold = 57600
	local NightMissionMinThereshold = 25200
	local MissionStartTimeSim = timer.getTime0()
	]]--

	-- save a new mission file
	DGWS.buildNewMizFile = function()

		-- setting variable (should became much more campaign-related the naming of the Miz-files

		local OldMizPath = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. "DGWS-" .. campaignName .. "-Day" .. CurrentCPdaynum .. "-Mission" .. CurrentCPmixnum .. ".miz" -- change to writedir
		local NewMizPath = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. "DGWS-" .. campaignName .. "-Day" .. NextCPdaynum .. "-Mission" .. NextCPmixnum .. ".miz" -- change to writedir
		local NewMizTempDir = "DGWS_TempMix/"
		local OldMissionPath = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. "mission"
		local NewMissionPath = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. NewMizTempDir .. "mission"

		local zipFile, err = minizip.unzOpen(OldMizPath, 'rb')

		--## METHOD 3 unpack, overwrite, repack
		-- occhio al check della cartella.


		DGWStools.lfs.mkdir(DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. NewMizTempDir) -- directory creata
		zipFile:unzGoToFirstFile() --vai al primo file dello zip
		local NewSaveresourceFiles = {}
		local function Unpack()
			while true do --scompattalo e passa al prossimo
				local filename = zipFile:unzGetCurrentFileName()
				local fullPath = DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. NewMizTempDir .. filename
				zipFile:unzUnpackCurrentFile(fullPath) -- base.assert(zipFile:unzUnpackCurrentFile(fullPath))
				NewSaveresourceFiles[filename] = fullPath
				if not zipFile:unzGoToNextFile() then -- se i file son finiti, chiudi.
					break
				end
			end
			return NewSaveresourceFiles
		end
		Unpack() -- execute the unpacking

		DGWS.moveFile(OldMissionPath, NewMissionPath) -- overwrite existing "mission" table

		local miz = minizip.zipCreate(NewMizPath)
		if miz then
			DGWS.updateCampaignStatus(NextCPid,NextCPmixnum,NextCPdaynum,NextstatusOngoing)
		end
		local function packMissionResources(miz)
			for file, fullPath in pairs(NewSaveresourceFiles) do
				miz:zipAddFile(file, fullPath)
				DGWStools.os.remove(fullPath)
			end
		end
		packMissionResources(miz)
		miz:zipClose()
		DGWStools.lfs.rmdir(DGWStools.lfs.writedir() .. missionfilesdirectory .. "Campaigns/" .. campaignName .. "/" .. NewMizTempDir)

		if DGWSoncall == true then
			mist.message.add({text = "New .MIZ file has been saved! host can disconnect.", displayTime = 30, msgFor = {coa = {"all"}} })
		end

	end
	--]]--





--#########################################################################################################################
--############################################### DECISION PROCESS FUNCTIONS ##############################################
--#########################################################################################################################
--#########################################################################################################################


	-- UNDERSTAND ORBAT STATUS
	DGWS.updateStrategicREP = function()

		-- resetTable
		StrategicRep = {}

		-- eval parameters (local ATM)
		local OffensiveThereshold = 1.2
		local DefensiveThereshold = 0.7
		local OccupationThereshold = 0.3 -- not used, meant to monitor occupied territory vs allied not occupied
		local LogEffThereshold = 0 -- to be raised once logistic system will be online)

		local BlueStatus = "neutral"
		local RedStatus = "neutral"
		local BlueDescription = "We are in a balanced situation against our enemies. We will continue to push the front to keep pressure and try to take an advantage"
		local RedDescription = "We are in a balanced situation against our enemies. We will continue to push the front to keep pressure and try to take an advantage"

		-- assess combat forces (IFV, MBT, APC, ATGM)
		local BlueForceSum = 0
		local RedForceSum = 0
		local BlueAtkSum = 0
		local RedAtkSum = 0
		local BlueArtSum = 0
		local RedArtSum = 0
		local BlueDefSum = 0
		local RedDefSum = 0
		local BlueRngSum = 0
		local RedRngSum = 0
		local BlueForNum = 0
		local RedForNum = 0

		-- assess preferred targets // NOT USED ATM
		local BluePrefTgt = ""
		local RedPrefTgt = ""

		-- assess logistic forces (UNARMED, etc)
		local BlueLogSum = 0
		local RedLogSum = 0

		-- forces update
		for id, ORBATdata in pairs (ORBATlist) do
			local gpClass = ORBATdata.groupTag
			local gpAtk = ORBATdata.groupAtk
			local gpDef = ORBATdata.groupDef
			local gpRng = ORBATdata.groupRng
			local gpSize = ORBATdata.groupSize
			local gpCoa = ORBATdata.groupCoa

			if gpCoa == "blue" then
				if gpClass == "IFV" or gpClass == "MBT" or gpClass == "APC" or gpClass == "ATGM" then
					BlueForceSum = BlueForceSum + gpAtk + gpDef + gpRng + gpSize
					BlueAtkSum = BlueAtkSum + gpAtk
					BlueDefSum = BlueDefSum + gpDef
					BlueRngSum = BlueRngSum + gpRng
					BlueForNum = BlueForNum + gpSize
				elseif gpClass == "LRARTY" or gpClass == "SRARTY" then
					BlueArtSum = BlueArtSum + gpRng
				elseif gpClass == "LOGISTIC" then
					BlueLogSum = BlueLogSum + gpSize
				end
			elseif gpCoa == "red" then
				if gpClass == "IFV" or gpClass == "MBT" or gpClass == "APC" or gpClass == "ATGM" then
					RedForceSum = RedForceSum + gpAtk + gpDef + gpRng + gpSize
					RedAtkSum = RedAtkSum + gpAtk
					RedDefSum = RedDefSum + gpDef
					RedRngSum = RedRngSum + gpRng
					RedForNum = RedForNum + gpSize
				elseif gpClass == "LRARTY" or gpClass == "SRARTY" then
					RedArtSum = RedArtSum + gpRng
				elseif gpClass == "LOGISTIC" then
					RedLogSum = RedLogSum + gpSize
				end

			end
		end

		--evaluate SITREP

		--set global parameters
		local ForceDiff = BlueForceSum/RedForceSum
		local AtkDiff = BlueAtkSum/RedAtkSum
		local DefDiff = BlueDefSum/RedDefSum
		local RngDiff = BlueRngSum/RedRngSum
		local LogDiff = BlueLogSum/RedLogSum
		local ArtDiff = BlueArtSum/RedArtSum

		--set specific parameters
		local BlueLogEff = BlueLogSum/BlueForNum
		local RedLogEff = RedLogSum/RedForNum
		local BlueArtEff = BlueArtSum/RedForNum
		local RedArtEff = RedArtSum/BlueForNum

		--assess blue status (SIMPLIFIED)
		if ForceDiff > OffensiveThereshold and  AtkDiff > OffensiveThereshold and RngDiff > OffensiveThereshold and BlueLogEff > LogEffThereshold then -- Offensive!
			BlueStatus = "offensive"
			BlueDescription = "We are in a good situation: our forces are stronger than enemies and our logistic net is able to support us"
		elseif ForceDiff < DefensiveThereshold and  AtkDiff < DefensiveThereshold and RngDiff < DefensiveThereshold then -- Defensive!
			BlueStatus = "defensive"
			BlueDescription = "We are in a dangerous situation: our forces are weaker than enemies and they could start an offensive against us."
		end

		--assess red status (SIMPLIFIED)
		if ForceDiff < DefensiveThereshold and  AtkDiff < DefensiveThereshold and RngDiff < DefensiveThereshold and RedLogEff > LogEffThereshold then -- Offensive!
			RedStatus = "offensive"
			RedDescription = "We are in a good situation: our forces are stronger than enemies and our logistic net is able to support us"
		elseif ForceDiff > OffensiveThereshold and  AtkDiff > OffensiveThereshold and RngDiff > OffensiveThereshold then -- Defensive!
			RedStatus = "defensive"
			RedDescription = "We are in a dangerous situation: our forces are weaker than enemies and they could start an offensive against us."
		end

		--evaluate preferred targets

		--blue values
		if RedArtEff > 0.5 then
			BluePrefTgt = BluePrefTgt .. "LRARTY, SRARTY"
		end
		if AtkDiff < 0.8 then
			BluePrefTgt = BluePrefTgt .. "MBT, IFV"
		end
		if RngDiff < 0.8 then
			BluePrefTgt = BluePrefTgt .. "MBT, ATGM"
		end
		if RedLogEff > 0.7 then
			BluePrefTgt = BluePrefTgt .. "LOGISTIC"
		end

		--red values
		if BlueArtEff > 0.5 then
			RedPrefTgt = RedPrefTgt .. "LRARTY, SRARTY"
		end
		if AtkDiff > 1.2 then
			RedPrefTgt = RedPrefTgt .. "MBT, IFV"
		end
		if RngDiff > 1.2 then
			RedPrefTgt = RedPrefTgt .. "MBT, ATGM"
		end
		if BlueLogEff > 0.7 then
			RedPrefTgt = RedPrefTgt .. "LOGISTIC"
		end

		-- update table
		StrategicRep["blue"] = { coalition = "blue", TotFOR = BlueForceSum, AtkFOR = BlueAtkSum, DefFOR = BlueDefSum, RngFOR = BlueRngSum, LogFOR = BlueLogSum, Status = BlueStatus, PrefTGT = BluePrefTgt, Description = BlueDescription}
		StrategicRep["Red"] = { coalition = "Red", TotFOR = RedForceSum, AtkFOR = RedAtkSum, DefFOR = RedDefSum, RngFOR = RedRngSum, LogFOR = RedLogSum, Status = RedStatus, PrefTGT = RedPrefTgt, Description = RedDescription}

		if DGWSoncall == true then
			mist.message.add({text = "Coalition strategic situation updated", displayTime = 5, msgFor = {coa = {"all"}} })
		end

	end
	--]]--

	-- THIS IS THE KEY FUNCTION THAT PLAN EVERY MOVEMENT AND INSERT IT IN THE EXECUTOR SCRIPT
	local dmDEBUGmode = true -- set debug mode ON/OFF
	local dmFILENAME = "plannedMovementList" .. exportfiletype
	local dmNEXTMOVlist = ""
	local dmDEBUGlist = ""
	local dmWLU = ""
	local dmMOVPLANTABLElist = ""
	local dmDEBUGLISTcsv = ""
	local dmFUTURETERRAINSTATUStable = {}
	local dmMOVPLANtable = {}
	local dmIDNUMvalue = nil
	local dmSERIALnum = nil
	local dmCycleExecute = nil	-- function starting as nil.
	local dmCycleRunProcess = nil
	local dmWritePlanList = nil
	local dmWriteDEBUG = nil
	local INITMOVETIME = nil
	local dmStato = nil
	local dmTotalGroupNum = nil
	local dmStatoChanged = nil


	-- Read the


	-- THIS WILL EVEALUATE EACH GROUP SA AND PLAN THE MOVEMENT
	DGWS.decisionMaker = function()
		if GlobalState == "G" then

			dmDEBUGlist = dmDEBUGlist .. "Globastate is G"
			-- ## reset datas
			dmMOVPLANtable = {}
			dmFUTURETERRAINSTATUStable = {}

			dmNEXTMOVlist = ""
			dmDEBUGlist = ""
			dmMOVPLANTABLElist = ""
			dmDEBUGLISTcsv = ""

			-- ## reset state loop variables
			dmStato = 1
			INITMOVETIME = 0
			dmSERIALnum = 0
			dmIDNUMvalue = 0

			-- define current dmMOVPLANtable situation
			dmTotalGroupNum = 0
			for _, groupData in pairs(ORBATlist) do
				dmTotalGroupNum = dmTotalGroupNum +1
				dmMOVPLANtable[#dmMOVPLANtable + 1] = {Coa = groupData.groupCoa, Name = groupData.groupName, Class = groupData.groupTag, Size = groupData.groupSize, From = groupData.groupTerr, To = groupData.groupTerr}
			end

			dmDEBUGlist = dmDEBUGlist .. "ANALISI PLANNED MOVEMENT LIST, NUMBER OF GROUPS: " .. dmTotalGroupNum .. "\n\n\n\n\n"

			dmWritePlanList = function() -- NECESSARY TO CREATE A GLOBAL ONE!?
				dmPLANLISTcsv = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. dmFILENAME, "w")
				dmPLANLISTcsv:write(dmNEXTMOVlist)
				dmPLANLISTcsv:close()
				dmDEBUGlist = dmDEBUGlist .. "debug function: dmWritePlanList has been written;" .. timer.getTime() .. "\n\n"
			end

			dmWriteDEBUG = function() -- NECESSARY TO CREATE A GLOBAL ONE!?
				if dmDEBUGmode == true then
					dmDEBUGLISTcsv = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. "dmDEBUGlist" .. exportfiletype, "w")
					dmDEBUGLISTcsv:write(dmDEBUGlist)
					dmDEBUGLISTcsv:close()
					--dmDEBUGlist = dmDEBUGlist .. "debug function: dmWriteDEBUG has been written;" .. timer.getTime() .. "\n\n"
				end
			end

			dmCycleExecute = function()
				-- check if cycle has to be stopped.
				local CycleRunning = true
				if dmStato > dmTotalGroupNum then
					CycleRunning = false -- Stop Cycling
					dmWritePlanList()
					DGWS.globalStateChanger() -- Change the sim state
					mist.removeFunction(dmCycleRunProcess)
					if DGWSoncall == true then
						mist.message.add({text = "Ground war decision making process completed", displayTime = 5, msgFor = {coa = {"all"}} })
					end
					--dmCycleExecute = nil -- reset nil status
				end

				if CycleRunning == true then
					dmDEBUGlist = dmDEBUGlist .. timer.getTime() .. ",CycleRunning � true, valore dmStato: " .. dmStato ..  "\n"
					for _, groupData in pairs(ORBATlist) do

						local groupCoa = groupData.groupCoa
						local groupId = tonumber(groupData.groupID)
						local groupTag = groupData.groupTag
						local groupName = groupData.groupName
						local ownSize = tonumber(groupData.groupSize)
						local groupNum = tonumber(groupData.IDnum)

						if groupNum == dmStato then

							--[[ DEBUGENVINFO
							if ENVINFOdebug == true then
							env.info(('DGWS-DEBUG: group ' .. groupName .. ", ORBAT line num " .. groupNum .. ",  dm process has started" ))
							end
							--]]--

							dmStatoChanged = false
							dmDEBUGlist = dmDEBUGlist .. "Coalizione: " .. groupCoa .. ", Gruppo in analisi: " .. groupNum .. ", nome: " .. groupName .. "\n"
							dmSERIALnum = dmSERIALnum + 1

							-- retrieve movTable data for allowing movement
							--local aterDEBUG = ""
							local AllowTerrain = function(place, Coa, ownClass, ownSize) -- DAVERIFICARE
								local FIGHTINGsumma = 0
								local OCCUsumma = 0
								local RECthere = false
								local ARTthere = false
								local ADSthere = false
								for id, movData in pairs (dmMOVPLANtable) do -- qui
									if movData.Coa == Coa then
										if movData.To == place then --focus on destination territory
											if movData.Class == "MBT" or movData.Class == "IFV" or movData.Class == "ATGM" then
												FIGHTINGsumma = FIGHTINGsumma + movData.Size
												OCCUsumma = OCCUsumma + movData.Size
											elseif movData.Class == "APC" then
												OCCUsumma = OCCUsumma + movData.Size
											elseif movData.Class == "RECON" then
												RECthere = true
											elseif movData.Class == "LRARTY" or movData.Class == "SRARTY" then
												ARTthere = true
											elseif movData.Class == "SRSAM" or movData.Class == "AAA" then
												ADSthere = true
											end
										end
									end
								end

								if ownClass == "MBT" or ownClass == "IFV" or ownClass == "ATGM" then
									if FIGHTINGsumma > MaxForceInTerr then
										AllowMovement = false
										--return false
										--dmDEBUGlist = dmDEBUGlist .. "Non conforme per FIGHTINGsumma\n"
									end
								elseif ownClass == "APC" then
									if math.floor((OCCUsumma + ownSize)/ControlledThereshold) > 1 or FIGHTINGsumma > MaxForceInTerr then
										AllowMovement = false
										--return false
										--dmDEBUGlist = dmDEBUGlist .. "Non conforme per OCCUsumma\n"
									end
								elseif ownClass == "RECON" then
									if RECthere == true then
										AllowMovement = false
										--return false
										--dmDEBUGlist = dmDEBUGlist .. "Non conforme per RECthere\n"
									end
								elseif ownClass == "LRARTY" or ownClass == "SRARTY" then
									if ARTthere == true then
										AllowMovement = false
										--return false
										--dmDEBUGlist = dmDEBUGlist .. "Non conforme per ARTthere\n"
									end
								elseif ownClass == "SRSAM" or ownClass == "AAA" then
									if ADSthere == true then
										AllowMovement = false
										--return false
										--dmDEBUGlist = dmDEBUGlist .. "Non conforme per ADSthere\n"
									end
								else
									AllowMovement = true
									--return true
									--dmDEBUGlist = dmDEBUGlist .. "CONFORME!\n"
								end
							end

							-- mission parameters
							local fromTerr = nil
							local toTerr = nil
							local missType = nil
							local CoaStatus = "neutral"

							--read variables function line
							local CoaRiskLvl =  ""
							local OwngroupPos = nil


							--rewrite groupPos based on units
							local OwnunitsCount = 0
							local FirstUnitName = ""
							local FirstUnitPos = nil
							local FirstUnitId = 10000000000000000
							for _,UnitData in pairs(mist.DBs.aliveUnits) do -- try to define the first unit in the group
								if UnitData.groupId == groupId then -- filter only groups units
									OwnunitsCount = OwnunitsCount + 1
									if UnitData.unitId < FirstUnitId then
										FirstUnitId = UnitData.unitId
										FirstUnitName = UnitData.unitName
										FirstUnitPos = UnitData.pos
									end
								end
							end
							OwngroupPos = FirstUnitPos

							dmDEBUGlist = dmDEBUGlist .. "Numero unit�: " .. OwnunitsCount .. "\n"

							-- remove after
							dmWriteDEBUG()

							if OwngroupPos ~= nil and OwnunitsCount > 0 then -- check if a position is found and units > 0

								--read risklevel starting ID. PROVISIONAL: NEEDS TO BECOME DYNAMIC
								if groupCoa == "blue" then
									CoaRiskLvl = blueRiskLevel
								elseif groupCoa == "red" then
									CoaRiskLvl = redRiskLevel
								end

								-- set SITREP values to base values
								local groupAtkRapp = 1
								local groupDefRapp = 1
								local groupRngRapp = 1

								-- size reset
								local enemySize = 0
								local allySize = 0
								local otherAllySize = 0
								--local nowControlled = 0
								--local thenControlled = 0
								--local keepOccupy = false

								-- read about territories
								local groupActGrid = nil
								local groupActTerr = nil
								local groupAllGrid = nil
								local groupAllTerr = nil
								local groupUcrGrid = nil
								local groupUcrTerr = nil
								local groupNeaGrid = nil
								local groupNeaTerr = nil
								local groupReaGrid = nil
								local groupReaTerr = nil
								local groupAlBorGrid = nil
								local groupAlBorTerr = nil
								local groupIsBtlGrid = nil
								local groupIsBtlTerr = nil
								local groupNoBorGrid = nil
								local groupNoBorTerr = nil

								local groupActTerrClass = nil
								local groupActTerrBattle = nil
								local groupActTerrOccup = nil

								-- reset ammo and fuel status
								local AmmoOK = true
								local FuelOK = true

								-- strategic coalition status
								for coa, data in pairs (StrategicRep) do
									if coa == groupCoa then
										CoaStatus = data.Status
									end
								end

								dmDEBUGlist = dmDEBUGlist .. "dmStato coalizione: " .. CoaStatus .. "\n"

								-- allocate Atk, Def, Rgn and size values difference between own forces and enemy ones
								for sitrepID, sitrepData in pairs(groupSITREPList) do
									if groupId == tonumber(sitrepData.OwngroupId) then
										allySize = tonumber(sitrepData.TotalAlliedSize)
										enemySize = tonumber(sitrepData.TotalEnemySize)
										groupAtkRapp = tonumber(sitrepData.AtkRapp)
										groupDefRapp = tonumber(sitrepData.DefRapp)
										groupRngRapp = tonumber(sitrepData.RngRapp)
									end
								end

								dmDEBUGlist = dmDEBUGlist .. "Da SITREP; Alleati vicini: " .. allySize .. ", Ostili vicini: " .. enemySize .. "\n"

								-- ## TERRAIN ASSESSMENT

									-- reset territories variables
									local minimumoffsetSt = 10000000
									local minimumoffsetAl = 10000000
									local minimumoffsetEn = 10000000
									local minimumoffsetNe = 10000000
									local minimumoffsetRe = 10000000
									local minimumoffsetNoBor = 10000000
									local minimumoffsetIsBtl = 10000000
									local minimumoffsetAlBor = 10000000
									local UnctrOBJpos = {}
									local ActualOBJpos = {}
									local AllyOBJpos = {}
									local NearOBJpos = {}
									local RearOBJpos = {}
									local NotBorOBJPos = {}
									local IsBtlOBJPos = {}
									local AlBorOBJPos = {}
									--[[
									local UnctrOBJgrid = ""
									local ActualOBJgrid = ""
									local AllyOBJgrid = ""
									local NearOBJgrid = ""
									local RearOBJgrid = ""
									local NotOccOBJgrid = ""
									local IsBtlOBJgrid = ""
									local AlBorOBJgrid = ""
									]]--
									local closestObjPos = nil
									local enemyObjPos = nil
									local allyObjPos = nil
									local nearObjPos = nil
									local rearObjPos = nil
									local noBorObjpos = nil
									local isbtlObjpos = nil
									local alborObjpos = nil
									--[[
									local UnctrPlaceRef = ""
									local ActualPlaceRef = ""
									local AllyPlaceRef = ""
									local NearPlaceRef = ""
									local RearPlaceRef = ""
									local NotOccPlaceRef = ""
									local IsBtlPlaceRef = ""
									local AlBorPlaceRef = ""
									]]--



									-- ACTUAL - define Actual territory and its characteristics
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											--if objData.objCoalition == OwngroupCoa then
												local placeName = objData.objName
												local placeClass = objData.objIsBorder
												local placeBattle = objData.objBattle
												local OBJx = objData.objCoordx
												local OBJz = objData.objCoordy
												local OBJPos = {
																x = OBJx,
																y = 0,
																z = OBJz
																}
												local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

												if minimumoffsetSt > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
													minimumoffsetSt = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
													closestObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
													groupActTerr = placeName
													groupActTerrClass = placeClass
													groupActTerrBattle = placeBattle
												end
												ActualOBJpos = closestObjPos
												groupActGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = closestObjPos.x, y = 0, z = closestObjPos.z})),1)
											--end
										end
									end

									-- ALLIED, NEAREST - nearest allied territory which is not the actual one.
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition == groupCoa then
												local OBJbor = objData.objIsBorder
												local placeName = objData.objName
												local OBJx = objData.objCoordx
												local OBJz = objData.objCoordy
												local OBJPos = {
																x = OBJx,
																y = 0,
																z = OBJz
																}
												local AllowMovement = true

												-- applyStandardFilter
												AllowTerrain(placeName, groupCoa,  groupTag, ownSize)

												-- apply other filters
												if placeName == groupActTerr then
													AllowMovement = false
												end

												-- now look for the closest with required situation
												if AllowMovement == true then
													local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)
													--debug
													--dmDEBUGlist = dmDEBUGlist .. groupName .. tss .. placeName .. tss .. actualoffset .. "\n"
													--/debug

													if minimumoffsetAl > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
														minimumoffsetAl = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
														allyObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
														groupAllTerr = placeName
														AllyOBJpos = allyObjPos
														groupAllGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = allyObjPos.x, y = 0, z = allyObjPos.z})),1)
													end
												end

											end
										end
									end

									-- UNCONTROLLED
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition ~= groupCoa then

												local placeName = objData.objName
												local OBJx = objData.objCoordx
												local OBJz = objData.objCoordy
												local OBJPos = {
																x = OBJx,
																y = 0,
																z = OBJz
																}

												local AllowMovement = true

												-- applyStandardFilter
												if AllowTerrain(placeName,  groupCoa,  groupTag, ownSize) == false then
													AllowMovement = false
												end

												if AllowMovement == true then

													local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

													if minimumoffsetEn > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
														minimumoffsetEn = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
														enemyObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
														groupUcrTerr = placeName
													end
													UnctrOBJpos = enemyObjPos
													groupUcrGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = enemyObjPos.x, y = 0, z = enemyObjPos.z})),1)
												end
											end
										end
									end

									-- ALLIED, NEAR BORDER
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition == groupCoa then --check same coalition
												if objData.objIsBorder == "near" then -- check is not border, but near a border territory

													local placeName = objData.objName
													local OBJx = objData.objCoordx
													local OBJz = objData.objCoordy
													local OBJPos = {
																	x = OBJx,
																	y = 0,
																	z = OBJz
																	}

													local AllowMovement = true

													-- applyStandardFilter
													if AllowTerrain(placeName, groupCoa,  groupTag, ownSize) == false then
														AllowMovement = false
													end

													if AllowMovement == true then

														local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

														if minimumoffsetNe > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetNe = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															nearObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															groupNeaTerr = placeName
														end

														groupNeaGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = nearObjPos.x, y = 0, z = nearObjPos.z})),1)

														--[[
														if nearObjPos == nil then
															NearOBJpos = "No Pos"
															NearOBJgrid = "No grid"
														else
															NearOBJpos = nearObjPos
															NearOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = nearObjPos.x, y = 0, z = nearObjPos.z})),1)
														end
														]]--
													end
												end
											end
										end
									end

									-- ALLIED, REAR BORDER
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition == groupCoa then --check same coalition
												if objData.objIsBorder == "rear" then -- check is not border, but near a border territory

													local placeName = objData.objName
													local OBJx = objData.objCoordx
													local OBJz = objData.objCoordy
													local OBJPos = {
																	x = OBJx,
																	y = 0,
																	z = OBJz
																	}

													local AllowMovement = true

													-- applyStandardFilter
													if AllowTerrain(placeName, groupCoa,  groupTag, ownSize) == false then
														AllowMovement = false
													end

													if AllowMovement == true then

														local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

														if minimumoffsetRe > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetRe = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															rearObjPos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															groupReaTerr = placeName
														end

														groupReaGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = rearObjPos.x, y = 0, z = rearObjPos.z})),1)

														--[[
														if nearObjPos == nil then
															NearOBJpos = "No Pos"
															NearOBJgrid = "No grid"
														else
															NearOBJpos = nearObjPos
															NearOBJgrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = nearObjPos.x, y = 0, z = nearObjPos.z})),1)
														end
														]]--
													end
												end
											end
										end
									end

									-- ALLIED, IS BORDER
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition == groupCoa then
												local OBJbor = objData.objIsBorder
												local placeName = objData.objName
												local OBJx = objData.objCoordx
												local OBJz = objData.objCoordy
												local OBJPos = {
																x = OBJx,
																y = 0,
																z = OBJz
																}

												if OBJbor == "yes" then

													local AllowMovement = true

													-- applyStandardFilter
													if AllowTerrain(placeName,  groupCoa,  groupTag, ownSize) == false then
														AllowMovement = false
													end

													if AllowMovement == true then


														local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

														if minimumoffsetAlBor > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetAlBor = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															alborObjpos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															groupAlBorTerr = placeName
															AlBorOBJpos = alborObjpos
															groupAlBorGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = alborObjpos.x, y = 0, z = alborObjpos.z})),1)
														end
													end

												end
											end
										end
									end

									-- ALLIED, AWAY FROM BORDER
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											if objData.objCoalition == groupCoa then
												local OBJbor = objData.objIsBorder
												local placeName = objData.objName
												local OBJx = objData.objCoordx
												local OBJz = objData.objCoordy
												local OBJPos = {
																x = OBJx,
																y = 0,
																z = OBJz
																}

												if OBJbor == "no" then

													local AllowMovement = true

													-- applyStandardFilter
													if AllowTerrain(placeName,  groupCoa,  groupTag, ownSize) == false then
														AllowMovement = false
													end

													if AllowMovement == true then


														local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

														if minimumoffsetNoBor > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetNoBor = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															noBorObjpos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															groupNoBorTerr = placeName
															AlBorOBJpos = noBorObjpos
															groupNoBorGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = noBorObjpos.x, y = 0, z = noBorObjpos.z})),1)
														end
													end

												end
											end
										end
									end

									-- IS BATTLE, NOT ACTUAL
									for _, objData in pairs(Objectivelist) do
										if (objData) then
											local OBJocc = objData.objControlled
											local OBJbor = objData.objIsBorder
											local OBJbtl = objData.objBattle
											local placeName = objData.objName
											local OBJx = objData.objCoordx
											local OBJz = objData.objCoordy
											local OBJPos = {
															x = OBJx,
															y = 0,
															z = OBJz
															}

											if OBJbtl == "yes" then -- there is a battle
												if placeName ~= ActualPlaceRef then -- not actual

													local AllowMovement = true

													-- applyStandardFilter
													if AllowTerrain(placeName, groupCoa,  groupTag, ownSize) == false then
														AllowMovement = false
													end

													if AllowMovement == true then

														local actualoffset = mist.utils.get2DDist(OBJPos, OwngroupPos)

														if minimumoffsetIsBtl > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
															minimumoffsetIsBtl = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
															isbtlObjpos = OBJPos -- ad obviously update the coordinates of the closest obj by using the new unitPos unit.
															groupIsBtlTerr = placeName
															groupIsBtlGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = isbtlObjpos.x, y = 0, z = isbtlObjpos.z})),1)
														end
													end


												end
											end
										end
									end

									-- temporary removing nils for debug
									if groupActTerr == nil then groupActTerr = "NoTerr" end
									if groupAllTerr == nil then groupAllTerr = "NoTerr" end
									if groupUcrTerr == nil then groupUcrTerr = "NoTerr" end
									if groupNeaTerr == nil then groupNeaTerr = "NoTerr" end
									if groupReaTerr == nil then groupReaTerr = "NoTerr" end
									if groupAlBorTerr == nil then groupAlBorTerr = "NoTerr" end
									if groupIsBtlTerr == nil then groupIsBtlTerr = "NoTerr" end
									if groupNoBorTerr == nil then groupNoBorTerr = "NoTerr" end


									dmDEBUGlist = dmDEBUGlist .. "Dall'analisi territori, " .. groupName  .." ".. "si trova in " .. groupActTerr .. ", e pu� muovere nei seguenti territori:" .. "\nAlleato: " .. groupAllTerr .. "\nNon controllato: " .. groupUcrTerr .. "\nDi Confine: " .. groupAlBorTerr .. "\nNear: " .. groupNeaTerr .. "\nRear: " .. groupReaTerr .. "\nNon di confine: " .. groupNoBorTerr .. "\nIn Battaglia: " .. groupIsBtlTerr .. "\n"

									-- Changing Nils
									if CoaStatus == "offensive" then

										dmDEBUGlist = dmDEBUGlist .. "la coalizione � in offensiva\n"

										if groupNoBorTerr == "NoTerr" or groupNoBorGrid == "NoTerr" then -- change No Border to Rear
											groupNoBorTerr = groupReaTerr
											groupNoBorGrid = groupReaGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni lontani dal confine disponibili, cambiati in Rear\n"
										end
										if groupReaTerr == "NoTerr" or groupReaGrid == "NoTerr" then -- change Rear in Near
											groupReaTerr = groupNeaTerr
											groupReaGrid = groupNeaGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Rear disponibili, cambiati in Near\n"
										end
										if groupNeaTerr == "NoTerr" or groupNeaGrid == "NoTerr" then -- change Near in Allied
											groupNeaTerr = groupAllTerr
											groupNeaGrid = groupAllGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Near disponibili, cambiati in Allied\n"
										end
										if groupIsBtlTerr == "NoTerr" or groupIsBtlGrid == "NoTerr" then -- change Is Battle to Uncontrolled (advance)
											groupIsBtlTerr = groupUcrTerr
											groupIsBtlGrid = groupUcrGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni IsBtl disponibili, cambiati in Uncontrolled\n"
										end
										if groupAllTerr == "NoTerr" or groupAllGrid == "NoTerr" then -- change Allied to Actual
											groupAllTerr = groupActTerr
											groupAllGrid = groupActGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni alleati disponibili, cambiati in Actual\n"
										end

									elseif CoaStatus == "defensive" then

										dmDEBUGlist = dmDEBUGlist .. "la coalizione � in difensiva\n"

										if groupIsBtlTerr == "NoTerr" or groupIsBtlGrid == "NoTerr" then -- change Is Battle to Actual (stay There)
											groupIsBtlTerr = groupActTerr
											groupIsBtlGrid = groupActGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni IsBtl disponibili, cambiati in Actual\n"
										end
										if groupNoBorTerr == "NoTerr" or groupNoBorGrid == "NoTerr" then -- change No Border to Rear
											groupNoBorTerr = groupReaTerr
											groupNoBorGrid = groupReaGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni lontani dal confine disponibili, cambiati in Rear\n"
										end
										if groupReaTerr == "NoTerr" or groupReaGrid == "NoTerr" then -- change Rear in Near
											groupReaTerr = groupNeaTerr
											groupReaGrid = groupNeaTerr
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Rear disponibili, cambiati in Near\n"
										end
										if groupNeaTerr == "NoTerr" or groupNeaGrid == "NoTerr" then -- change Near in Allied
											groupNeaTerr = groupAllTerr
											groupNeaGrid = groupAllGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Near disponibili, cambiati in Allied\n"
										end
										if groupAllTerr == "NoTerr" or groupAllGrid == "NoTerr" then -- change Allied to Actual
											groupAllTerr = groupActTerr
											groupAllGrid = groupActGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni alleati disponibili, cambiati in Actual\n"
										end

									elseif CoaStatus == "neutral" then

										dmDEBUGlist = dmDEBUGlist .. "la coalizione � in situazione neutra\n"

										if groupIsBtlTerr == "NoTerr" or groupIsBtlGrid == "NoTerr" then -- change Is Battle to Border (move to another border pos)
											groupIsBtlTerr = groupAlBorTerr
											groupIsBtlGrid = groupIsBorGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni IsBtl disponibili, cambiati in IsBorder\n"
										end
										if groupNoBorTerr == "NoTerr" or groupNoBorGrid == "NoTerr" then -- change No Border to Rear
											groupNoBorTerr = groupReaTerr
											groupNoBorGrid = groupReaGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni lontani dal confine disponibili, cambiati in Rear\n"
										end
										if groupReaTerr == "NoTerr" or groupReaGrid == "NoTerr" then -- change Rear in Near
											groupReaTerr = groupNeaTerr
											groupReaGrid = groupNeaTerr
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Rear disponibili, cambiati in Near\n"
										end
										if groupNeaTerr == "NoTerr" or groupNeaGrid == "NoTerr" then -- change Near in Allied
											groupNeaTerr = groupAllTerr
											groupNeaGrid = groupAllGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni Near disponibili, cambiati in Allied\n"
										end
										if groupAllTerr == "NoTerr" or groupAllGrid == "NoTerr" then -- change Allied to Actual
											groupAllTerr = groupActTerr
											groupAllGrid = groupActGrid
											dmDEBUGlist = dmDEBUGlist .. "Non ci sono terreni alleati disponibili, cambiati in Actual\n"
										end

									else
										dmDEBUGlist = dmDEBUGlist .. "!!!!\nERRORE GRAVE: IMPOSSIBILE IDENTIFICARE LO STATO DI COALIZIONE\n!!!!\n\n"
									end


									-- rehash terrain movement // MODIFICA PER AGGIUNGERE CHECK DI DEBUG?
									if groupAllTerr == "NoTerr" then groupAllTerr = groupActTerr end
									if groupUcrTerr == "NoTerr" then groupUcrTerr = groupActTerr end
									if groupNeaTerr == "NoTerr" then groupNeaTerr = groupActTerr end
									if groupReaTerr == "NoTerr" then groupReaTerr = groupActTerr end
									if groupAlBorTerr == "NoTerr" then groupAlBorTerr = groupActTerr end
									if groupIsBtlTerr == "NoTerr" then groupIsBtlTerr = groupActTerr end
									if groupNoBorTerr == "NoTerr" then groupNoBorTerr = groupActTerr end

									-- keepOccupy
									local keepOccupy = false
									local ACTsumma = 0
									for id, movData in pairs (dmMOVPLANtable) do
										if movData.Coa == Coa then
											if movData.From == groupActTerr then
												if movData.Class == "MBT" or movData.Class == "IFV" or movData.Class == "ATGM" or movData.Class == "APC" then
													ACTsumma = ACTsumma + movData.Size
												end
											end
										end
									end
									if math.floor((ACTsumma - ownSize)/ControlledThereshold) > 1 then
										keepOccupy = true
									end

									dmDEBUGlist = dmDEBUGlist .. "Il valore keepOccupy � " .. tostring(keepOccupy) .. "\n"

								-- ## FORCES CALCULATION

								--set coaRiskLevel references
								if groupCoa == "blue" then
									CoaRiskLvl = blueRiskLevel
								elseif groupCoa == "red" then
									CoaRiskLvl = redRiskLevel
								end

								dmDEBUGlist = dmDEBUGlist .. "Il valore CoaRiskLvl � " .. CoaRiskLvl .. "\n"

								-- correct deltas with AcceptableRiskLevel
								for riskID,riskLevels in pairs(AcceptableRiskLevel) do
									if CoaRiskLvl == riskID then
										groupAtkRapp = groupAtkRapp * riskLevels.atkForceDiff
										groupDefRapp = groupDefRapp * riskLevels.defForceDiff
										groupRngRapp = groupRngRapp * riskLevels.rngForceDiff
									end
								end

								-- logistic allow (not working ATM)
								--[[
								for logId, logData in pairs(LogisticRep) do
									if groupName == logData.groupName then
										if logData.Ammo < LowAmmoThereshold then
											AmmoOK = false
										end

										if logData.Fuel < LowFuelThereshold then
											FuelOK = false
										end
									end
								end

								dmDEBUGlist = dmDEBUGlist .. "I valori di FuelOK � " .. FuelOK..  ", mentre AmmoOK � " .. AmmoOK .. "\n"

								]]--


								-- ## MOVEMENT DECISION TABLE ##
								local DecisionRun = 1


								--filter FARP support unit and "special" tags
								if string.find(groupName,"FARP") or string.find(groupName,"Exl_") then
									DecisionRun = 0
									fromTerr = groupActTerr
									toTerr = groupActTerr
									dmDEBUGlist = dmDEBUGlist .. "Essendo un gruppo FARP, DecisionRun �  " .. DecisionRun .. "\n"
								end

								-- add other decisionrun filters to check if the group is in any "special" group not subject of Decisiontable
								if groupTag == "LOGISTIC" or groupTag == "LRSAM" then
									DecisionRun = 0
									fromTerr = groupActTerr
									toTerr = groupActTerr
									dmDEBUGlist = dmDEBUGlist .. "Essendo un gruppo LOGISTIC o LRSAM, DecisionRun �  " .. DecisionRun .. "\n"
								end

								if DecisionRun == 1 then
									dmDEBUGlist = dmDEBUGlist .. "Per il gruppo il valore iniziale di DecisionRun �  " .. DecisionRun .. "\n"

									--------------------------------------------------------->>>
									if -- >> MBT & IFV & ATGM
										groupTag == "MBT" or
										groupTag == "ATGM" or
										groupTag == "IFV" then
										--groupTag == "APC" then

										dmDEBUGlist = dmDEBUGlist .. groupName .. " � un gruppo MBT, ATGM o IFV\n"

										if -- territory is in battle, no move, only relocation.
											AmmoOK == true and
											FuelOK == true and
											groupActTerrBattle == "yes" and
											groupAtkRapp >= GrndShyForAdvg and
											groupDefRapp >= GrndShyForAdvg and
											groupRngRapp >= GrndShyForAdvg then

											missType = "I"
											fromTerr = groupActTerr
											toTerr = groupActTerr
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio di battaglia e l'unit� � in vantaggio sugli ostili (I) \n"

										elseif -- group is far from battle (border = no, rear, near), move to border
											groupActTerrClass == "no" or
											groupActTerrClass == "near" or
											groupActTerrClass == "rear" then
											if
												AmmoOK == true and
												FuelOK == true then

												dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. "� nelle retrovie e muover� verso un territorio di confine\n"
												missType = "K"
												fromTerr = groupActTerr
												toTerr = groupAlBorTerr

											elseif -- caso particolare
												AmmoOK == false or
												FuelOK == false then

												dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. "� nelle retrovie ma senza armi o carburante, rester� fermo (F) \n"
												missType = "F"
												fromTerr = groupActTerr
												toTerr = groupActTerr
											end

										elseif -- no enemy contact, start movement to contact // Only if offensive
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp == 100 and
											groupDefRapp == 100 and
											groupRngRapp == 100 and
											CoaStatus == "offensive" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. "non � in contatto con ostili,muover� verso il territorio non controllato pi� vicino, cercando il contatto con ostili (A)\n"
											missType = "A"
											fromTerr = groupActTerr
											toTerr = groupUcrTerr

										elseif -- forces are in high advantage, move to occupy target area
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp >= GrndHighForAdvg and
											groupDefRapp >= GrndHighForAdvg and
											groupRngRapp >= GrndHighForAdvg then
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in netto vantaggio di forze, muover� per occupare il territorio ostile (B)\n"

											missType = "B"
											fromTerr = groupActTerr
											toTerr = groupUcrTerr

										elseif -- forces are in slight advantage, starting advance for 5 km if not defensive.
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp >= GrndShyForAdvg and
											groupDefRapp >= GrndShyForAdvg and
											groupRngRapp >= GrndShyForAdvg then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in lieve vantaggio sugli ostili"

											if CoaStatus == "defensive" then
												missType = "I"
												fromTerr = groupActTerr
												toTerr = groupActTerr
												dmDEBUGlist = dmDEBUGlist .. "e rester� nel territorio attuale, coalizione sulla difensiva (I)\n"
											else
												missType = "C"
												fromTerr = groupActTerr
												toTerr = groupUcrTerr
												dmDEBUGlist = dmDEBUGlist .. " e avanzer� 5 km in direzione del territorio ostile\n"
											end

										elseif -- retire to the nearest "near" or "allied" territory
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp <= GrndHighForDisv and
											groupDefRapp <= GrndHighForDisv and
											groupRngRapp <= GrndHighForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in netto svantaggio sugli ostili, arretrer� verso il territorio arretrato pi� vicino (D) \n"

											missType = "D"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

										elseif -- withdraw breaking los with enemy to ne nearest territory if neutral or defensive, stay there if offensive
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp <= GrndShyForDisv and
											groupDefRapp <= GrndShyForDisv and
											groupRngRapp <= GrndShyForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � lievemente in svantaggio rispetto agli ostili"

											if CoaStatus == "offensive" then
												missType = "F"
												fromTerr = groupActTerr
												toTerr = groupActTerr
												dmDEBUGlist = dmDEBUGlist .. " e rester� in posizione, coalizione in offensiva (F) \n"
											else
												missType = "E"
												fromTerr = groupActTerr
												toTerr = groupAllTerr
												dmDEBUGlist = dmDEBUGlist .. " e se in contatto con ostili, arretrer� 5 km verso il territorio alleato pi� vicino (E) \n"
											end

										elseif -- withdrawing due to range fire disadvantage
											AmmoOK == true and
											FuelOK == true and
											groupRngRapp <= GrndShyForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in svantaggio per via di un range fire disadvantage, arretrer� verso il territorio alleato pi� vicino quanto basta per rompere la LOS sugli ostili (G) \n"

											missType = "G"
											fromTerr = groupActTerr
											toTerr = groupAllTerr

										elseif -- range fire advantage, advancing to nearest uncontrolled territory
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp >= GrndShyForAdvg and
											groupRngRapp >= GrndShyForAdvg then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in vantaggio sulla gittata dell'armamento avanzer� 5 km verso il territorio ostile (H) \n"

											missType = "H"
											fromTerr = groupActTerr
											toTerr = groupUcrTerr

										elseif -- situazione di equilibrio con gli ostili
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp < GrndShyForAdvg and
											groupAtkRapp > GrndRShyForDisv and
											groupDefRapp < GrndShyForAdvg and
											groupDefRapp > GrndRShyForDisv and
											groupRngRapp < GrndShyForAdvg and
											groupRngRapp > GrndRShyForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in equilibrio con gli ostili, rester� dov'� (F) \n"

											missType = "F"
											fromTerr = groupActTerr
											toTerr = groupActTerr

										elseif -- lack of ammo
											AmmoOK == false and
											FuelOK == true then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " non ha sufficienti munizioni, arretrer� nel territorio near pi� vicino (D) \n"

											missType = "D"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

										elseif -- lack of fuel
											FuelOK == false then
											--dmNEXTMOVlist = dmNEXTMOVlist .. groupCoa ..tss.. groupId ..tss.. groupName ..tss.. groupTag ..tss.. groupActGrid ..tss.. "no move " .. groupActGrid ..tss.. "No Fuel" ..tss.. "F" ..tss .. "No Move" ..tss .. INITMOVETIME .. tss .. groupActGrid .. tss .. dmSERIALnum --[[ .. ActualPlaceRef ..tss .. AllyPlaceRef ..tss .. EnemyPlaceRef]] .. "\n"
											missType = "F"
											fromTerr = groupActTerr
											toTerr = groupActTerr
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " non ha carburante, rester� fermo (F) \n"

										else
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupId ..tss.. groupName ..tss.. "nessuna condizione verificata\n"
											fromTerr = groupActTerr
											toTerr = groupActTerr
											end

									end -- // MBT & IFV


									--------------------------------------------------------->>>
									if -- >> APC
										groupTag == "APC" then

										dmDEBUGlist = dmDEBUGlist .. groupName .. " � un gruppo APC\n"

										if -- territory is in battle, no move, only relocation.
											AmmoOK == true and
											FuelOK == true and
											groupActTerrBattle == "yes" then
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio in battaglia, il gruppo APC deve arretrare, muover� verso il pi� vicino territorio arretrato non occupato \n"

											missType = "K"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

										elseif -- group is in a dangerous situation, will retreat to nearest allied territory.
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp <= GrndHighForDisv and
											groupDefRapp <= GrndHighForDisv and
											groupRngRapp <= GrndHighForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in una situazione svantaggiosa rispetto alle forze ostili note, muover� verso il pi� vicino territorio alleato\n"

											missType = "D"
											fromTerr = groupActTerr
											toTerr = groupAllTerr

										elseif -- group is in an already occupied allied territory, moving elsewhere
											AmmoOK == true and
											FuelOK == true and
											keepOccupy == true then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio gi� occupato (keepOccupy true)\n"

											missType = "J"
											fromTerr = groupActTerr
											toTerr = groupAllTerr
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " muover� verso il pi� vicino territorio alleato non occupato \n"
											-- CONTROLLA IL DISCORSO KEEPOCCUPY!!!
										else
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " nessuna delle precedenti opzioni � stata verificata \n"
											fromTerr = groupActTerr
											toTerr = groupActTerr
										end
									end
									--[[]]--

									--------------------------------------------------------->>>
									if -- >> RECON (TO BE REVISED)
										groupTag == "RECON" then

										dmDEBUGlist = dmDEBUGlist .. groupName .. " � un gruppo RECON\n"

										if -- territory is in battle, relocation.
											AmmoOK == true and
											FuelOK == true and
											groupActTerrBattle == "yes" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio in battaglia, il gruppo Recon deve fuggire: muover� verso il pi� vicino territorio alleato \n"

											missType = "D"
											fromTerr = groupActTerr
											toTerr = groupAllTerr

										elseif -- group is in a dangerous situation, will retreat to nearest allied territory.
											AmmoOK == true and
											FuelOK == true and
											groupAtkRapp <= GrndHighForDisv and
											groupDefRapp <= GrndHighForDisv and
											groupRngRapp <= GrndHighForDisv then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in una situazione svantaggiosa rispetto alle forze ostili note, muover� verso il pi� vicino territorio alleato di confine\n"

											missType = "D"
											fromTerr = groupActTerr
											toTerr = groupAlBorTerr

										elseif -- group is in an already controlled territory, move into another uncontrolled one.
											AmmoOK == true and
											FuelOK == true and
											keepOccupy == true then
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio gi� occupato (keepOccupy true), muover� verso il pi� vicino territorio non controllato \n"

											missType = "J"
											fromTerr = groupActTerr
											toTerr = groupUcrTerr

										else
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " nessuna delle precedenti opzioni � stata verificata \n"
											fromTerr = groupActTerr
											toTerr = groupActTerr
										end

									end
									--[[]]--

									--------------------------------------------------------->>>
									if -- >> ARTY (TO BE REVISED)
										groupTag == "LRARTY" or groupTag == "SRARTY" then

										dmDEBUGlist = dmDEBUGlist .. groupName .. " � un gruppo ARTY\n"

										if -- territory is in battle, relocation to near.
											AmmoOK == true and
											FuelOK == true and
											groupActTerrBattle == "yes" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio in battaglia, il gruppo Recon deve fuggire: muover� verso il pi� vicino territorio near \n"

											missType = "K"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

										elseif -- group is in a non-near territory, relocate in near
											AmmoOK == true and
											FuelOK == true and
											groupActTerrClass ~= "near" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un terreno non near, riposizioner� di conseguenza\n"

											missType = "K"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

											-- AGGIUNGI LOGICHE ?

										else
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " nessuna delle precedenti opzioni � stata verificata \n"
											fromTerr = groupActTerr
											toTerr = groupActTerr
											end

									end
									--[[]]--

									--------------------------------------------------------->>>
									if -- >> ADS (TO BE REVISED)
										groupTag == "SRSAM" or groupTag == "AAA" then

										dmDEBUGlist = dmDEBUGlist .. groupName .. " � un gruppo ADS\n"

										if -- territory is in battle, relocation to near.
											AmmoOK == true and
											FuelOK == true and
											groupActTerrBattle == "yes" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un territorio in battaglia, il gruppo Recon deve fuggire: muover� verso il pi� vicino territorio near \n"

											missType = "K"
											fromTerr = groupActTerr
											toTerr = groupNearTerr

										elseif -- group is in a non-near territory, relocate in near
											AmmoOK == true and
											FuelOK == true and
											groupActTerrClass ~= "near" then

											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " � in un terreno non near, riposizioner� di conseguenza\n"

											missType = "K"
											fromTerr = groupActTerr
											toTerr = groupNeaTerr

											-- AGGIUNGI LOGICHE DI DIFESA DEGLI OBIETTIVI

										else
											dmDEBUGlist = dmDEBUGlist .. groupCoa ..tss .. groupName ..tss.. " nessuna delle precedenti opzioni � stata verificata \n"
											fromTerr = groupActTerr
											toTerr = groupActTerr
										end

									end
									--[[]]--

									--filter no Movement Plan
									if fromTerr == toTerr then
										DecisionRun = 0
									end

									dmDEBUGlist = dmDEBUGlist .. "Ma essendo il territorio di arrivo uguale a quello di destinazione, DecisionRun � modificato a  " .. DecisionRun .. "\n"

									-- write movement list
									if groupTag and fromTerr and toTerr and missType and DecisionRun ~= 0 then
										INITMOVETIME = INITMOVETIME + BetMovDelay
										dmIDNUMvalue = dmIDNUMvalue + 1

										dmDEBUGlist = dmDEBUGlist .. "Il valore di INITMOVETIME �  " .. INITMOVETIME .. "\n"
										dmDEBUGlist = dmDEBUGlist .. "Il valore di dmIDNUMvalue �  " .. dmIDNUMvalue .. "\n"

										dmNEXTMOVlist = dmNEXTMOVlist .. dmIDNUMvalue ..tss.. groupCoa ..tss.. groupId ..tss.. groupName ..tss.. groupTag ..tss.. fromTerr ..tss.. toTerr ..tss.. missType ..tss.. INITMOVETIME .. tss .. dmSERIALnum .. "\n"

										for id, planData in pairs (dmMOVPLANtable) do
											if planData.Name == groupName then
												planData.To = toTerr

												dmDEBUGlist = dmDEBUGlist .. "Cambiato il valore -To- nella tabella dmMOVPLANtable da " .. fromTerr .. " a " .. toTerr .. "\n"
											end
										end
									end
									-- add to movTable



								end -- end decision run
								-- assess change cycle
								dmStatoChanged = true
								dmDEBUGlist = dmDEBUGlist .. "La variable dmStatoChanged � " .. tostring(dmStatoChanged) .. "\n\n"

							else
								dmDEBUGlist = dmDEBUGlist .. "Il gruppo � morto\n\n" --sistemato
								dmStatoChanged = true
							end
						end -- cycle
						dmWriteDEBUG()
					end
				end -- end cycling every group in ORBAT movement

				--dmDEBUGlist = dmDEBUGlist .. "La variable dmStatoChanged � ancora " .. tostring(dmStatoChanged) .. "\n\n"
				if dmStatoChanged == true then
					dmStato = dmStato + 1
					dmDEBUGlist = dmDEBUGlist .. "Aggiornato il valore -dmStato- a " .. dmStato .. "\n\n"
				end
			end



			dmCycleRunProcess = mist.scheduleFunction(dmCycleExecute,{}, timer.getTime() + 1, InnerStateTimer, missionLasting) -- schedule the cycle // MAYBE CAN'T BE LOCAL?!
			--mist.scheduleFunction(dmCycleExecute,{}, timer.getTime() + 1, InnerStateTimer, (1+InnerStateTimer)*dmTotalGroupNum) -- schedule the cycle
			--mist.scheduleFunction(dmWritePlanList,{},(1+InnerStateTimer)*dmTotalGroupNum+5) --write the results
			--mist.scheduleFunction(dmWriteDEBUG,{},(1+InnerStateTimer)*dmTotalGroupNum+7) --write the results
			--GlobalState == "B"  -- /// ACTIVATE WHEN GLOBAL STATE CYCLE IS ACTIVE!
		end
	end
	--]]--

	-- read the PlannedMovementList file
	DGWS.readPlannedMovementList = function()
		plannedMovementList = {}
		local j = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "plannedMovementList" .. exportfiletype, "r")
		local dbg = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. "plannedMovementdebug" .. ".txt", "w")
		if DGWStools.io.lines(j) then
			for line in DGWStools.io.lines(j) do
				local rIDnum, rCoalition, rID, rGroupName, rTag, rFromTerr, rToTerr, rMissType, rTime, rMsgSerial = line:match("(.-)"..tss.."(.-)"..tss.."(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(%d-)"..tss.."(%d-)$")
				--if type(rID) == "number" then
					plannedMovementList[#plannedMovementList + 1] = {IDnum = rIDnum, ID = rID, Coalition = rCoalition, GroupName = rGroupName, Tag = rTag, FromTerr = rFromTerr, ToTerr = rToTerr, MissType = rMissType, Time = rTime, MsgSerial = rMsgSerial }
				--end
			end
		end
		j:close()
	end
	--]]--


	-- THIS WILL READ THE PLANNED MOVEMENT AND LOAD IT IN A SCHEDULED FUNCTION LIST
	DGWS.schedulePlannedMov = function()

		--read the file. As this function is launched once in the start-up process, the content will be the one from the previous mission.
		DGWS.readPlannedMovementList()

		--[[
		-- debug TABLE
		local x = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "DEBUG-plannedMovementList.txt", "w")
		local LISTmov = ""
		for _, LISTData in pairs(plannedMovementList) do
			LISTmov = LISTData.ID .. tss .. LISTData.Coalition .. tss .. LISTData.GroupName .. tss .. LISTData.Tag .. tss .. LISTData.StartingGrid .. tss .. LISTData.MovRef .. tss .. LISTData.DestinationGrid .. tss .. LISTData.BriefSITREP .. tss .. LISTData.MovDescription .. tss .. LISTData.Function .. tss .. LISTData.DestinationName .. tss .. LISTData.DestinationPosTable .. "\n"
			x:write(LISTmov)
		end
		x:close()
		--/debug
		--]]

		-- read the table and create the functions
		for _,movData in pairs(plannedMovementList) do
			if movData then
				-- read the 4 variables
				local Coa = movData.Coalition
				local Name = movData.GroupName
				local PosName = movData.ToTerr
				local Pos = {}
				local Class = movData.Tag

				-- enstablish scheduling parameters
				local StartDelay = (StartMovDelay*60 - RunScriptDelay)
				local PlannedDelay = movData.Time
				local FuncText = ""	--movData.Function --string.sub(movData.Function,6)

				--identify function
				for Mid, Mdata in pairs (GroundMissionType) do
					if Mid == movData.MissType then
						FuncText = Mdata.Function
					end
				end

				for _, DestData in pairs (Objectivelist) do
					if PosName == DestData.objName then
						Pos = {
							x = DestData.objCoordx,
							y = 0,
							z = DestData.objCoordy,
							}
					--else
						--mist.message.add({text = "Group " .. Name .. " can't find destination name", displayTime = 10, msgFor = {coa = {'all'}} })
					end
				end

				--local PosLoad = assert(loadstring("return " .. PosText))
				--local Pos = PosLoad()
				if FuncText  then
					if FuncText ~= "No Func" then
						local FuncLoad = assert(loadstring("return " .. FuncText))
						local FuncInit = FuncLoad()

						-- execute the planning
						mist.scheduleFunction(FuncInit,{Coa, Name, Pos, Class}, StartDelay + PlannedDelay) -- don't give error but also doesn't work.
					end
				--else
					--dbg:write(Coa .. ", " .. Name .. " non � stato possibile pianificare la manovra")
				end
			end
		end

		if DGWSoncall == true then
			mist.message.add({text = "Planned movement has been scheduled as fragged", displayTime = 5, msgFor = {coa = {"all"}} })
		end

		--dbg:close()
	end
	--]]--

	-- UTILS: read ATO requests list (from planned movement
	DGWS.ATOGroundSupportReqList = function()

		-- variables
		local tempATOrequestlist = {}
		ATOrequestlist = {}
		-- read the planned movement list table. As this function is launched only after DecisionMaker, than it will read the planned movement list of the next mission.
		DGWS.readPlannedMovementList()

		-- create a table that enlist the request by AirRequest priority
		for _, plannedData in pairs (plannedMovementList) do
			local PriorityVal = nil
			local ReqMixType = nil
			local NewIndexVal = nil
			local IDval = tonumber(plannedData.ID)
			local TaskedMix = plannedData.MissType
			local TaskedCoa = plannedData.Coalition
			local CoaStatus = nil
			local MovMood = nil

			-- strategic coalition status
			for coa, data in pairs (StrategicRep) do
				if coa == TaskedCoa then
					CoaStatus = data.Status
				end
			end

			-- identify additional information
			for letter, GmixData in pairs (GroundMissionType) do
				if TaskedMix == letter then
					PriorityVal = tonumber(GmixData.AskSupport)
					ReqMixType = GmixData.SumCode
					MovMood = GmixData.Type

				end
			end -- end GroundMissionType cycle

			if CoaStatus == "offensive" then
				if MovMood == CoaStatus then
					PriorityVal = PriorityVal + 1
					if PriorityVal > 5 then PriorityVal = 5 end
				end
			elseif CoaStatus == "defensive" then
				if MovMood == CoaStatus then
					PriorityVal = PriorityVal -1
					if PriorityVal < 1 then PriorityVal = 1 end
				end
			end

			if PriorityVal == 5 then
				NewIndexVal = 10000
			elseif PriorityVal == 4 then
				NewIndexVal = 20000
			elseif PriorityVal == 3 then
				NewIndexVal = 30000
			elseif PriorityVal == 2 then
				NewIndexVal = 40000
			elseif PriorityVal == 1 then
				NewIndexVal = 50000
			else
				NewIndexVal = 60000
			end

			NewIndexVal = NewIndexVal + IDval -- #tempATOrequestlist + 1
			tempATOrequestlist[#tempATOrequestlist + 1] = {IndexVal = NewIndexVal, Priority = PriorityVal, ID = plannedData.ID, Coalition = plannedData.Coalition, GroupName = plannedData.GroupName, Tag = plannedData.Tag, FromTerr = plannedData.FromTerr, ToTerr = plannedData.ToTerr, TaskType = ReqMixType, Time = plannedData.Time, MsgSerial = plannedData.MsgSerial }
		end -- end plannedMovementList cycle
		local numElements = table.getn(tempATOrequestlist)

		local valueInsert = function()
			local minvalue = 1000000000
			local currentID = nil
			local currentTableData = nil
			for id ,tabledata in pairs(tempATOrequestlist) do
				if tabledata.IndexVal < minvalue then
					currentID = id
					currentTableData = tabledata
					minvalue = tabledata.IndexVal

				end
			end
			ATOrequestlist[#ATOrequestlist + 1] = currentTableData
			table.remove(tempATOrequestlist, currentID)
		end

		for i= 1, numElements do
			valueInsert()
		end

		if DebugMode == true then
			local fName = "DGWS-DEBUG-ATOrequestlist.txt"
			local f = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory .. fName, "w")
			local debugATOreq = ""

			for index, ATOdata in pairs(ATOrequestlist) do
				if ATOdata then
					debugATOreq = index .. tss .. ATOdata.Priority .. tss .. ATOdata.ID .. tss ..  ATOdata.Coalition .. tss ..  ATOdata.GroupName .. tss ..  ATOdata.Tag  .. tss ..  ATOdata.FromTerr  .. tss ..  ATOdata.ToTerr  .. tss ..  ATOdata.TaskType  .. tss ..  ATOdata.Time  .. tss ..  ATOdata.MsgSerial .. "\n"
					f:write(debugATOreq)
					--groupAtk = rgroupAtk, groupDef = rgroupDef, groupRng = rgroupRng, groupGrid = rgroupGrid, groupTerr = rgroupTerr, groupTypeList = rgroupTypeList
				end
			end
			f:close()
		end
	end
	--]]--

	-- UTILS: read flight number list
	DGWS.ATOreadFlightNumber = function()
		UsedFlightNumber = {}
		local h = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "UsedFlightNumber" .. exportfiletype, "r")

		for line in DGWStools.io.lines(h) do
			local rNumber, rDay, rTask = line:match("(%d-)"..tss.."(.-)"..tss.."(.-)$")
				if (rNumber) then
				UsedFlightNumber[#UsedFlightNumber + 1] = { Number =rNumber, Day = rDay, Task = rTask}
			end
		end
		h:close()
	end
	--]]--


	local aiCurrentATOstate = "A"
	local PkgList = {}
	local AIATOZoneId = 0
	local aiCycleRunProcess = nil
	local STRIKEmisPerMission = 2
	local CASmisPerMission = 3
	local DCAmisPerMission = 2 -- can be dependant by the number of Border territories.
	local SEADmisPerMission = 1

	-- THIS WILL CREATE AI ATO TASKING FOR EACH COALITION
	DGWS.AIATOtasking = function()

		if GlobalState == "H" then
			-- delete previous ATO
			PlannedATO = {}

			local InsertPackadgeNumber = function(numeromin, numeromax, day, task)
				local newnumber = true
				local numero = math.random(numeromin,numeromax)
				for _, numData in pairs(UsedFlightNumber) do
					if numData.Number == numero then
						newnumber = false
					end
				end

				if newnumber == false then
					return false
				elseif newnumber == true then
					-- aggiungi inserimento in tabella
					UsedFlightNumber[#UsedFlightNumber + 1] = { Number = numero, Day = day, Task = task}
					return numero
				end
			end

			if DAWStrue == true then

				--This function change the internal state
				aiATOchangestate = function()
					if aiCurrentATOstate == "A" then
						aiCurrentATOstate = "B"
					elseif aiCurrentATOstate == "B" then
						aiCurrentATOstate = "C"
					elseif aiCurrentATOstate == "C" then
						aiCurrentATOstate = "D"
					elseif aiCurrentATOstate == "D" then
						aiCurrentATOstate = "E"
					elseif aiCurrentATOstate == "E" then
						mist.removeFunction(aiCycleRunProcess)
						DGWS.writeATO()
						DGWS.globalStateChanger()
						if DGWSoncall == true then
							mist.message.add({text = "Air support planning completed", displayTime = 5, msgFor = {coa = {"all"}} })
						end
						aiCurrentATOstate = "A"
					end
				end

				--[[	workflok
					-- build a task request table in DAWS ATO FORMAT adding each possible mission
					-- randomly sort those missions

						pkg number assignment
					-- 0-9999 riservati ai client.
					-- 90000-99999 riservati alla IA di DAWS.
					-- 10000-39990 riservati ai voli CAS/BAI/CONVOY SECURITY/AREA SECURITY
					-- 40000-49990 riservati ai voli STRIKE
					-- 50000-59990 riservati ai voli SEAD
					-- 60000-79990 riservati ai voli CAP/SWEEP/ESCORT
					-- 80000-89990 riservati ai voli AWACS/TANKER/RECON

					-- crea una tabella assigned packadge!!!
					-- ZoneId , ZoneCoa , ZoneName , ZonePosX , ZonePosY , ZonePosZ , ZoneRange , ZoneAItext , ZoneETAtext , ZoneTGTtext , ZoneMixNum }
				]]--

				local CAPrequest = {}
				local CAPid = 0
				PkgList = {} -- reset packadgelist state

				--local MaxCoaPkg = AIPkgPerCoa

				--[[ initial generic values
				local StdCAStaskRatio = 0.2
				local StdSTRIKEtaskRatio = 0.2
				local StdDCAtaskRatio = 0.2
				local StdSEADtaskRatio = 0.2
				local StdCAPtaskRatio = 0.2
				local StdOCAtaskRatio = 0 -- to be activated when ADS less than "n" value and coalition in offensive
				local StdSWEEPtaskRatio = 0 -- to be activated when ADS less than "n" value and coalition in offensive
				--]]--

				-- read historically used flight numbers
				DGWS.ATOreadFlightNumber()

				-- Create ATO request from Ground units // CAS-INTERDICTION
				DGWS.ATOGroundSupportReqList()

				-- create cycle
				aiATOcycleFunction = function()

					--## plan SEAD flights
					if aiCurrentATOstate == "A" then
						--local tempBLUEseadTargets = {}
						--local tempREDseadTargets = {}
						local blueSEADcount = 0
						local redSEADcount = 0
						local blueSEADID = nil
						local redSEADID = nil
						local blueSEADloop = function()
							for intelId, intelData in pairs(KnownEnemyList) do
								-- totKnownEnemyList = { IDnum, EnemyID, EnemyCoalition, EnemyGroupName, EnemyName, EnemyType, EnemyClass, Territory}
								if intelData.EnemyCoalition == "red" then
									local ADSpriority = 0
									local CurrentChosen = 0
									if intelData.EnemyClass == "LRSAM" or intelData.EnemyClass == "SRSAM" or intelData.EnemyClass == "AAA" then
										--[[ priority table
											LRSAM border = 20
											LRSAM near = 18
											LRSAM rear = 12
											LRSAM (none) = 10

											SRSAM border = 13
											SRSAM near = 11
											SRSAM rear = 5
											SRSAM (none) = 3

											AAA border = 11
											AAA near = 9
											AAA rear = 3
											AAA (none) = 1
										--]]--

										-- assign priority by type
										if intelData.EnemyClass == "LRSAM" then
											ADSpriority = ADSpriority + 10
										elseif intelData.EnemyClass == "SRSAM" then
											ADSpriority = ADSpriority + 3
										elseif intelData.EnemyClass == "AAA" then
											ADSpriority = ADSpriority + 1
										end
										-- assign priority by territory
										local ADSpriority = 0
										for terId, terrData in pairs (Objectivelist) do
											if intelData.Territory == terData.objName then
												if terrData.objIsBorder == "yes" then
													ADSpriority = ADSpriority + 10
												elseif terrData.objIsBorder == "near" then
													ADSpriority = ADSpriority + 8
												elseif terrData.objIsBorder == "rear" then
													ADSpriority = ADSpriority + 2
												end
											end
										end

										if ADSpriority > CurrentChosen then
											CurrentChosen = ADSpriority
											blueSEADID = intelData.IDnum
										end
									end
								end
							end
							return blueSEADID
						end
						local redSEADloop = function()
							for intelId, intelData in pairs(KnownEnemyList) do
								if intelData.EnemyCoalition == "blue" then

									local ADSpriority = 0
									local CurrentChosen = 0
									if intelData.EnemyClass == "LRSAM" or intelData.EnemyClass == "SRSAM" or intelData.EnemyClass == "AAA" then
										--[[ priority table
											LRSAM border = 20
											LRSAM near = 18
											LRSAM rear = 12
											LRSAM (none) = 10

											SRSAM border = 13
											SRSAM near = 11
											SRSAM rear = 5
											SRSAM (none) = 3

											AAA border = 11
											AAA near = 9
											AAA rear = 3
											AAA (none) = 1
										--]]--

										-- assign priority by type
										if intelData.EnemyClass == "LRSAM" then
											ADSpriority = ADSpriority + 10
										elseif intelData.EnemyClass == "SRSAM" then
											ADSpriority = ADSpriority + 3
										elseif intelData.EnemyClass == "AAA" then
											ADSpriority = ADSpriority + 1
										end
										-- assign priority by territory
										local ADSpriority = 0
										for terId, terrData in pairs (Objectivelist) do
											if intelData.Territory == terData.objName then
												if terrData.objIsBorder == "yes" then
													ADSpriority = ADSpriority + 10
												elseif terrData.objIsBorder == "near" then
													ADSpriority = ADSpriority + 8
												elseif terrData.objIsBorder == "rear" then
													ADSpriority = ADSpriority + 2
												end
											end
										end

										if ADSpriority > CurrentChosen then
											CurrentChosen = ADSpriority
											redSEADID = intelData.IDnum
										end
									end
								end
							end
							return redSEADID
						end

						for intelId, intelData in pairs(KnownEnemyList) do
						-- totKnownEnemyList = { IDnum, EnemyID, EnemyCoalition, EnemyGroupName, EnemyName, EnemyType, EnemyClass, Territory}
							if blueSEADcount <= SEADmisPerMission then
								local CurID = blueSEADloop()
								if CurID == intelData.IDnum then
									local alreadythere = false
									for _, pkgData in pairs (PkgList) do
										if intelData.EnemyGroupName == pkgData.Name then
											alreadythere = true
										end
									end

									if alreadythere == false then
										AIATOZoneId = AIATOZoneId + 1
										local ZoneCoa = nil -- ok
										local ZoneName = intelData.EnemyGroupName
										local ZonePosX = intelData.EnemyX
										local ZonePosY = intelData.EnemyY
										local ZonePosZ = intelData.EnemyZ
										local ZoneRange = 10000*1.85
										local ZoneAItext = "SEAD"
										local ZoneETAtext = (StartMovDelay*60)+(math.random(1,30)*60)
										local ZoneACtext = nil -- keep nil!
										local ZoneSTtext = nil
										local ZoneFLtext = nil
										local ZoneTGTtext = nil
										local ZoneMixNum = nil
										local ZoneGrid = nil

										-- reset coa
										if intelData.EnemyCoalition == "blue" then
											ZoneCoa = "red"
										elseif intelData.EnemyCoalition == "red" then
											ZoneCoa = "blue"
										end

										Pkg = InsertPackadgeNumber(5000,5999,NextOPdate,ZoneAItext)
										ZoneMixNum = tonumber(Pkg)*10 + AIATOZoneId
										ZoneGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = ZonePosX, y = 0, z = ZonePosZ})),1)

										PkgList[#PkgList + 1] = {Id = AIATOZoneId, Coalition = ZoneCoa, Name = ZoneName, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Range = ZoneRange, AItext = ZoneAItext, ETAtext = ZoneETAtext, ACtext = "none", STtext = "none", FLtext = "none", TGTtext = "none", MNUMtext = ZoneMixNum, AreaOps = intelData.Territory, Grid = ZoneGrid}

										CAPid = CAPid + 1
										CAPrequest[#CAPrequest + 1] = {Id = CAPid, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Pkg = ZoneMixNum}

										blueSEADcount = blueSEADcount + 1
									end
								end
							end
						end

						-- repeat for red


						--tempREDstrikeTargets[#tempREDstrikeTargets + 1] =

					end
					--]]--

					--## plan CAS/INT flight
					if aiCurrentATOstate == "B" then
						local maxCASnum = 0
						for _,CASdata in pairs(ATOrequestlist) do
							if maxCASnum <= CASmisPerMission then
								local CASallow = true
								--IndexVal, Priority, ID, Coalition, GroupName, Tag, FromTerr, ToTerr, TaskType, Time, MsgSerial
								-- ensure univoque packadge to be created.

								-- assess ADSpermitted
								for intelId, intelData in pairs(KnownEnemyList) do
									if intelData.Territory == CASdata.ToTerr or intelData.Territory == CASdata.FromTerr then -- filter territory
										if intelData.EnemyClass == "LRSAM" or intelData.EnemyClass == "SRSAM" then -- filter SAM
											CASallow = false
										end -- filter SAM
									end -- end filter territory
								end
								--]]--

									--local Pkg = math.random(1000,3999) -- ultima cifra per volo. 0-10000 riservati ai client. 90000-99999 riservati alla IA di DAWS.
								if CASallow == true then
									--## Reset variables
									AIATOZoneId = AIATOZoneId + 1
									local ZoneCoa = nil -- ok
									local ZoneName = nil -- ok
									local ZonePosX = nil -- ok
									local ZonePosY = nil -- ok
									local ZonePosZ = nil -- ok
									local ZoneRange = nil
									local ZoneAItext = nil
									local ZoneETAtext = nil
									local ZoneACtext = nil -- keep nil!
									local ZoneSTtext = nil
									local ZoneFLtext = nil
									local ZoneTGTtext = nil
									local ZoneMixNum = nil
									local Territory = nil
									local ZoneGrid = nil

									--## Retrieve General value
									ZoneCoa = CASdata.Coalition
									ZoneName = CASdata.GroupName
									ZoneAItext = CASdata.TaskType
									ZoneETAtext = math.floor((CASdata.Time - 30)/60)
									ZoneRange = 20000*1.85


									--## Retrieve Coordinates
									if ZoneAItext == "CAS" then -- CAS will provide support right over the requesting unit.
										for ind, group_data in pairs(mist.DBs.groupsById) do
											if group_data.groupName == ZoneName then
												ZonePosX = units.point.x
												ZonePosZ = units.point.y
												ZonePosY = land.getHeight({x = ZonePosX, y = ZonePosZ})
												Territory = CASdata.FromTerr
											end
										end
									elseif ZoneAItext == "BAI" then -- BAI will provide support on the destination territory
										for _,ObjData in pairs (Objectivelist) do
											if ObjData.objName == CASdata.ToTerr then
												ZonePosX = ObjData.objCoordx
												ZonePosZ = ObjData.objCoordy
												ZonePosY = land.getHeight({x = ZonePosX, y = ZonePosZ})
												Territory = CASdata.ToTerr
											end
										end
									end

									Pkg = InsertPackadgeNumber(1000,3999,NextOPdate,ZoneAItext)
									ZoneMixNum = tonumber(Pkg)*10 + AIATOZoneId
									ZoneGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = ZonePosX, y = 0, z = ZonePosZ})),1)

									PkgList[#PkgList + 1] = {Id = AIATOZoneId, Coalition = ZoneCoa, Name = ZoneName, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Range = ZoneRange, AItext = ZoneAItext, ETAtext = ZoneETAtext, ACtext = "none", STtext = "none", FLtext = "none", TGTtext = "none", MNUMtext = ZoneMixNum, AreaOps = Territory, Grid = ZoneGrid}

									CAPid = CAPid + 1
									CAPrequest[#CAPrequest + 1] = {Id = CAPid, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Pkg = ZoneMixNum}
									maxCASnum = maxCASnum + 1
								end
							end
						end
					end
					--]]--

					--## plan STRIKE flight // REVIEW THIS LOGIC IN THE FUTURE
					if aiCurrentATOstate == "C" then
						local tempBLUEstrikeTargets = {}
						local tempREDstrikeTargets = {}
						for Tid, Tdata in pairs (TargetsTable) do
							--TargetsTable: IDnum, Coalition, TargetName, TargetType, TargetArea, TargetX, TargetY, Callsign, Status, Territory
							if Tdata.Status > 0 then -- the target is still operational at some level
								local SuitableDistance = false -- true if terrain is border, near, rear
								local ADSpermitted = true -- false if LRSAM is not in the territory

								-- assess SuitableDistance
								for terrId, terrData in pairs(Objectivelist) do -- cycle objectivelist to verify SuitableDistance
									if Tdata.Territory == terrData.objName then
										if terrData.objIsBorder == "yes" or terrData.objIsBorder == "near" or terrData.objIsBorder == "rear" then
											SuitableDistance = true
										end
									end
								end -- end Objectivelist cycle
								--]]--

								-- totKnownEnemyList = { IDnum, EnemyID, EnemyCoalition, EnemyGroupName, EnemyName, EnemyType, EnemyClass, Territory}
								-- assess ADSpermitted
								for intelId, intelData in pairs(KnownEnemyList) do
									if intelData.Territory == Tdata.Territory then -- filter territory
										if intelData.EnemyClass == "LRSAM" then -- filter SAM
											ADSpermitted = false
										end -- filter SAM
									end -- end filter territory
								end
								--]]--

								-- check targets
								if SuitableDistance == true and ADSpermitted == true then -- permitting filters
									if Tdata.Coalition == "blue" or Tdata.Coalition == "red" then

										if Tdata.Coalition == "red" then
											tempBLUEstrikeTargets[#tempBLUEstrikeTargets + 1] = Tdata
										elseif Tdata.Coalition == "blue" then
											tempREDstrikeTargets[#tempREDstrikeTargets + 1] = Tdata
										end

										BlueTargets = table.getn(tempBLUEstrikeTargets)
										RedTargets = table.getn(tempREDstrikeTargets)

										local Bassigned = 0
										local Rassigned = 0

										-- INIT BLUE MISSIONS
										for Bid, BTdata in pairs (tempBLUEstrikeTargets) do
											local chosen = math.random(1,BlueTargets)
											if 	chosen == Bid and Bassigned <= STRIKEmisPerMission then

												-- ADD THE FILTER!!!!

												--## Reset variables
												AIATOZoneId = AIATOZoneId + 1
												local ZoneCoa = nil -- ok
												local ZoneName = nil -- ok
												local ZonePosX = nil -- ok
												local ZonePosY = nil -- ok
												local ZonePosZ = nil -- ok
												local ZoneRange = nil
												local ZoneAItext = nil
												local ZoneETAtext = nil
												local ZoneACtext = nil -- keep nil!
												local ZoneSTtext = nil
												local ZoneFLtext = nil
												local ZoneTGTtext = nil
												local ZoneMixNum = nil

												--## Retrieve General value
												if BTdata.Coalition == "blue" then
													ZoneCoa = "red"
												elseif BTdata.Coalition == "red" then
													ZoneCoa = "red"
												end

												ZoneName = BTdata.TargetName
												ZoneAItext = "STRIKE"
												ZoneETAtext = (StartMovDelay*60)+(math.random(1,30)*60)--math.floor((CASdata.Time - 30)/60)
												ZoneRange = 5000*1.85
												ZoneTGTtext = BTdata.Callsign
												ZonePosX = BTdata.TargetX
												ZonePosZ = BTdata.TargetY
												ZonePosY = land.getHeight({x = ZonePosX, y = ZonePosZ})

												Pkg = InsertPackadgeNumber(4000,4999,NextOPdate,ZoneAItext)
												ZoneMixNum = tonumber(Pkg)*10 + 1

												PkgList[#PkgList + 1] = {Id = AIATOZoneId, Coalition = ZoneCoa, Name = ZoneName, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Range = ZoneRange, AItext = ZoneAItext, ETAtext = ZoneETAtext, ACtext = "none", STtext = "none", FLtext = "none", TGTtext = ZoneTGTtext, MNUMtext = ZoneMixNum}

												CAPid = CAPid + 1
												CAPrequest[#CAPrequest + 1] = {Id = CAPid, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Pkg = ZoneMixNum }
												Bassigned = Bassigned + 1
											end
										end
										--]]-- end blue missions

										-- INIT RED MISSIONS
										for Rid, RTdata in pairs (tempREDstrikeTargets) do
											local chosen = math.random(1,RedTargets)
											if 	chosen == Rid and Rassigned <= STRIKEmisPerMission then

												-- ADD THE FILTER!!!!

												--## Reset variables
												AIATOZoneId = AIATOZoneId + 1
												local ZoneCoa = nil -- ok
												local ZoneName = nil -- ok
												local ZonePosX = nil -- ok
												local ZonePosY = nil -- ok
												local ZonePosZ = nil -- ok
												local ZoneRange = nil
												local ZoneAItext = nil
												local ZoneETAtext = nil
												local ZoneACtext = nil -- keep nil!
												local ZoneSTtext = nil
												local ZoneFLtext = nil
												local ZoneTGTtext = nil
												local ZoneMixNum = nil
												local ZoneGrid = nil

												--## Retrieve General value
												if RTdata.Coalition == "blue" then
													ZoneCoa = "red"
												elseif RTdata.Coalition == "red" then
													ZoneCoa = "red"
												end

												ZoneName = RTdata.TargetName
												ZoneAItext = "STRIKE"
												ZoneETAtext = (StartMovDelay*60)+(math.random(1,30)*60)--math.floor((CASdata.Time - 30)/60)
												ZoneRange = 5000*1.85
												ZoneTGTtext = RTdata.Callsign
												ZonePosX = RTdata.TargetX
												ZonePosZ = RTdata.TargetY
												ZonePosY = land.getHeight({x = ZonePosX, y = ZonePosZ})

												Pkg = InsertPackadgeNumber(4000,4999,NextOPdate,ZoneAItext)
												ZoneMixNum = tonumber(Pkg)*10 + AIATOZoneId
												ZoneGrid = DGWS.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL({x = ZonePosX, y = 0, z = ZonePosZ})),1)

												PkgList[#PkgList + 1] = {Id = AIATOZoneId, Coalition = ZoneCoa, Name = ZoneName, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Range = ZoneRange, AItext = ZoneAItext, ETAtext = ZoneETAtext, ACtext = "none", STtext = "none", FLtext = "none", TGTtext = ZoneTGTtext, MNUMtext = ZoneMixNum, AreaOps = Tdata.Territory, Grid = ZoneGrid}

												CAPid = CAPid + 1
												CAPrequest[#CAPrequest + 1] = {Id = CAPid, X = ZonePosX, Y = ZonePosY, Z = ZonePosZ, Pkg = ZoneMixNum }
												Rassigned = Rassigned + 1
											end
										end
										--]]-- end red missions
									end -- end check coa
								end -- end permitting filters
							end -- end Status > 0 filter
						end -- end TargetsTable cycle
					end
					--]]--

					--## plan CAP flights
					if aiCurrentATOstate == "D" then

						local DCAaddPoint = function(coalition, localizationClass)
							local pointsTable =  {}
							local numPoints = 0
							local maxPoints = DCAmisPerMission
							for terrId, terrData in pairs(Objectivelist) do -- cycle objectivelist to verify SuitableDistance
								if numPoints <= maxPoints then
									if terrData.objIsBorder == localizationClass and terrData.objCoalition == coalition then




									end
								end
							end
						end


						-- Create DCA flights
						local DCAinteraxis = 60*1.85 --(mt)
						local BlueBorTerrTable = {}
						local RedBorTerrTable = {}
						-- assess SuitableDistance
						for terrId, terrData in pairs(Objectivelist) do -- cycle objectivelist to verify SuitableDistance
							-- Objectivelist: IDnum, objID, objName, objRegion, objCoalition, objCoordx, objCoordy, objControlled, objblueSize, objredSize, objIsBorder, objBattle
							if terrData.objIsBorder == "near" then
								if terrData.objCoalition == "blue" then

								elseif terrData.objCoalition == "red" then

								end
							end
						end -- end objectivelist cycle
								--]]--









						--[[ blue missions enum
						local totBlueCAS = 0
						local totBlueSTRIKE = 0
						local totBlueSEAD = 0
						local totBlueCAP = 0
						-- red missions enum
						local totRedCAS = 0
						local totRedSTRIKE = 0
						local totRedSEAD = 0
						local totRedCAP = 0

						local TotTasking = table.getn(PkgList)


						-- this function write down the ATO
						DGWS.writeATO()
						CAPid = 0
						--]]--
					end


					--]]--
					if aiCurrentATOstate == "F" then
						DGWS.writeATO()
						CAPid = 0
					end

					--## Create the mission list for every coalition & print down the request to DAWS


					--]]--

					--[[ evaluate total possibile requests
					local reqNum = 0
					for _, pkgData in pairs(PkgList) do
						if pkgData then
							reqNum = reqNum +1
						end
					end
					--]]--


					aiATOchangestate()
				end

				-- Mist repetition
				aiCycleRunProcess = mist.scheduleFunction(aiATOcycleFunction,{}, timer.getTime() + 1, InnerStateTimer, missionLasting)
				-- exec the internal stato change

			else
				DGWS.globalStateChanger()
			end -- close DAWS verification
		end -- end GLOBALSTATE CYCLE
	end
	--]]--


--##### BUBBLE CODE, NOT WORKING

	-- this function can be used to set ALL ground AI off at scenery start // TO BE USED IF BUBBLE WORK
	DGWS.AllGroundAIOff = function()
		for ind, group_data in pairs(mist.DBs.groupsById) do
			trigger.action.setGroupAIOn(Group.getByName(group_data.groupName))
		end
	end
	--]]--

	-- this function should optimize performances by setting all groups "AI OFF" // NOT WORKING
	DGWS.Bubble = function() -- DO NOT WORK MAYBE CAUSE OF A DCS BUG in getGroup function.
		local debugbubble = true --// SET THIS FALSE TO PREVENT DEBUGGING
		local limitDistance = AIONdistance

		if debugbubble == true then
			local bubbleline = ""
			local debugFile = ""
			local bubblelineName = "bubbleline".. timer.getTime() .. ".lua"
			bubblelineTXT = DGWStools.io.open(DGWStools.lfs.currentdir() .. debugdirectory  .. bubblelineName, "w")
			bubblelineTXT:write("init log\n")

		end

		-- to SET AI OFF for All at mission start.
		for _, groupData in pairs(ORBATlist) do -- to SET AI OFF for All at mission start.
			local grp = Group.getByName(groupData.groupName)
			--if timer.getTime() < timer.getTime0()+100 then
				trigger.action.setGroupAIOff(grp)

				if debugbubble == true then
					bubbleline = bubbleline .. "\n\n-> group " .. groupData.groupName .. " has been set to AI OFF due to mission start reason " .. timer.getTime() .. "\n"
				end

			--end
		end

		-- to SET AI ON or OFF at given conditions.
		for _, groupData in pairs(ORBATlist) do -- to SET AI ON at given conditions.
			local grp = Group.getByName(groupData.groupName)
			local grpName = groupData.groupName
			local grpCoa = groupData.groupCoa
			local grpEnemyDist = 1000000

			for _, grpUnits in pairs(mist.DBs.aliveUnits) do
				local DBgrpName = grpUnits.groupName
				if DBgrpName == grpName then
					local minimumoffset = 1000000
					grpPos = grpUnits.pos

					for _, enemyUnits in pairs(mist.DBs.aliveUnits) do
						if grpCoa ~= enemyUnits.coalition then
							enemyPos = enemyUnits.pos

							local actualoffset = mist.utils.get2DDist(grpPos, enemyPos)

							if minimumoffset > actualoffset then -- this loop will ensure to return the lowest actualoffset possibile...
								minimumoffset = actualoffset -- ...by sobstitute every time "minimumoffset" is > than the new calculated position.
								grpEnemyDist = minimumoffset
							end
						end
					end
				end
			end



			if debugbubble == true then
				bubbleline = bubbleline .. "\n\n-> group " .. groupData.groupName .. " is under evaluation at time " .. timer.getTime() .. "\n"
			end

			--if timer.getTime() > timer.getTime0()+100 then
				if	grpEnemyDist < limitDistance
					-- add other conditions
					then

					trigger.action.setGroupAIOn(grp)

					if debugbubble == true then
						bubbleline = bubbleline .. "-- group " .. groupData.groupName .. " has been put AI ON at time " .. timer.getTime() .. "\n"
					end
				else
					trigger.action.setGroupAIOff(grp)
					if debugbubble == true then
						bubbleline = bubbleline .. "-- group " .. groupData.groupName .. " has been put AI OFF at time " .. timer.getTime() .. "\n"
					end
				end

			--end

		end

		if debugbubble == true then
			bubblelineTXT:write(bubbleline)
			bubblelineTXT:close()
		end

	end
	--]]--


--##### DEAD MAP OBJECT DISTRUCTION

	-- this function store in a file the destroyed map objects table. the file is constantly rewrited every "n" seconds, and rely on mist.DBs.deadObjects only
	DGWS.deadMapObjCollect = function()

		local deadOBJ = ""

		-- add to the previous data stored in "deadOBJ" string the new data
		for deadId,deadData in pairs(mist.DBs.deadObjects) do
			if deadData.objectType == "building" then -- filter map Objects
				local Id = deadId
				local Pos = deadData.objectPos

				deadOBJ = deadOBJ .. Id .. tss .. Pos.x .. tss  .. Pos.y .. tss  .. Pos.z .. tss .. OPdate .. "\n"
			end
		end

		-- now overwrite the old file (erase previous data)
		local o = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "deadobjects" .. exportfiletype, "w")
		o:write(deadOBJ)
		o:close()

		if DGWSoncall == true then
			mist.message.add({text = "Destroyed building has been collected", displayTime = 5, msgFor = {coa = {"all"}} })
		end

	end
	--]]--

	--[[ this function store in a file the destroyed map objects table
	DGWS.deadMapObjCollect = function(event)

		if event.id == world.event.S_EVENT_DEAD then
			if event.initiator and event.initiator.id_ and event.initiator.id_ > 0 then
				local id = event.initiator.id
				local val = {object = event.initiator}
				local pos = Object.getPosition(val.object)


				--object = event.initiator




				deadOBJ = deadOBJ .. id .. tss .. Pos.x

			end
		end


	end
	]]--


	-- this function will destroy previously destroyed objects at mission start
	DGWS.deadMapObjDestroy = function()

		-- retrieve dead objects data
		local destroyMethod = 1 -- 0 means by destroy, 1 by explosion. 0 does not work due to a bug.
		local u = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory  .. "deadobjects" .. exportfiletype, "r")

		for line in DGWStools.io.lines(u) do
			local rdeadID, rdeadPosX, rdeadPosY, rdeadPosZ, rdeadDate = line:match("(%d-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)"..tss.."(.-)$")
				if (rdeadID) then
				DeadMapObjects[#DeadMapObjects + 1] = { deadID = rdeadID, deadPosX = rdeadPosX, deadPosY = rdeadPosY, deadPosZ = rdeadPosZ, deadDate = rdeadDate}
			end
		end
		u:close()


		-- exec the deletion
		for id, DeadData in pairs(DeadMapObjects) do
			local deadX = tonumber(DeadData.deadPosX)
			local deadY = tonumber(DeadData.deadPosY)
			local deadZ = tonumber(DeadData.deadPosZ)
			local val = "nodata"

			local ExpPos = {
							x = deadX,
							y = deadY,
							z = deadZ
							}

			local volume = 	{
							id = world.VolumeType.SPHERE,
							params = {
										point = ExpPos,
										radius = 0.2
									}
							}

			local function handler(object, data)
				val = SceneryObject.getLife(object)
				Object.destroy(object)
				--object:destroy()
			end

			if destroyMethod == 0 then
				if ExpPos then
					world.searchObjects(Object.Category.SCENERY, volume, handler, nil)
				end
			elseif destroyMethod == 1 then
				if id then
					trigger.action.explosion(ExpPos, 3000)
				end
			end
		end
		if DGWSoncall == true then
			mist.message.add({text = "Previously destroyed building has been removed", displayTime = 5, msgFor = {coa = {"all"}} })
		end

	end
	--]]--


--#########################################################################################################################
--############################################### DGWS LOOP FUNCTIONS #####################################################
--#########################################################################################################################
--#########################################################################################################################


	-- GSC
	DGWS.globalStateChanger = function()

		if GlobalState == "A" then -- start looping state filter...
			GlobalState = "B" -- Changed from B, reserved.
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from A to B\n"
		elseif GlobalState == "B" then
			GlobalState = "C"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from B to C\n"
		elseif GlobalState == "C" then
			GlobalState = "D"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from C to D\n"
		elseif GlobalState == "D" then
			GlobalState = "E" -- Changed from E, reserved.
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from D to E\n"
		elseif GlobalState == "E" then
			GlobalState = "F"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from E to F\n"
		elseif GlobalState == "F" then
			GlobalState = "G"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from F to G\n"
		elseif GlobalState == "G" then
			GlobalState = "H"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from G to H\n"
		elseif GlobalState == "H" then
			GlobalState = "I"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from H to I\n"
		elseif GlobalState == "I" then
			GlobalState = "J"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from I to J\n"
		elseif GlobalState == "J" then
			GlobalState = "K"
			debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from J to K\n"
		elseif GlobalState == "K" then -- this one close the loop and restart
			if DGWSoncall == true then
				debugGlobalState = debugGlobalState .. timer.getTime() .. ", On-Call process complete\n\n"
				mist.removeFunction(OnCallPeriodicCycle)
			else
				debugGlobalState = debugGlobalState .. timer.getTime() .. ", State is changed from J to A\n\n"
				GlobalState = "A"
			end
		--elseif PastGlobalState == "X" then -- this one force the loop start at first load.
			--GlobalState = "A"
			--PastGlobalState = "A"
		end

	end
	--]]--

	-- EPC
	DGWS.ExecutePeriodicCycle = function() --

		if GlobalState ~= PastGlobalState then

			if GlobalState == "A" then -- start looping state filter...
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state A, editObjList has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Updating territories and objective areas    .... (STANDBY) ....  ", displayTime = 5, msgFor = {coa = {"all"}} })
				end
				DGWS.editObjList()
				PastGlobalState = "A"
			elseif GlobalState == "B" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state B, (placeholder) has started '))
				end
				DGWS.globalStateChanger()
				PastGlobalState = "B"
			elseif GlobalState == "C" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state C, integrateKnownEnemyList has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Updating intelligience data    .... (STANDBY) ....  ", displayTime = 5, msgFor = {coa = {"all"}} })
				end
				DGWS.integrateKnownEnemyList()
				PastGlobalState = "C"
			elseif GlobalState == "D" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state D, updateORBATlist has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Updating ORBAT    .... (STANDBY) ....  ", displayTime = 5, msgFor = {coa = {"all"}} })
				end
				DGWS.updateORBATlist()
				local ORBATn = table.getn(ORBATlist)
				if ORBATn > 0 then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state J, DGWS.updateStrategicREP() has started '))
					end
					DGWS.updateStrategicREP()
				end
				PastGlobalState = "D"
			elseif GlobalState == "E" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state E, (placeholder) has started '))
				end
				DGWS.globalStateChanger()
				PastGlobalState = "E"
			elseif GlobalState == "F" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state F, groupSITREPupdate has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Updating Ground units SA .... (STANDBY. WARNING: THIS PROCESS MAY TAKE FEW MINUTES!) ....  ", displayTime = 30, msgFor = {coa = {"all"}} })
				end
				DGWS.groupSITREPupdate()
				PastGlobalState = "F"
			elseif GlobalState == "G" then
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state G, decisionMaker has started '))
				end

				if LimitedFlow == false or LimitedFlow == nil then
					if DGWSoncall == true then
						mist.message.add({text = "Performing Ground War decision making process .... (STANDBY. WARNING: THIS PROCESS MAY TAKE FEW MINUTES!) ....  ", displayTime = 30, msgFor = {coa = {"all"}} })
					end
					DGWS.decisionMaker()
				end
				PastGlobalState = "G"
			elseif GlobalState == "H" then   --> QUI esegue la pianificazione dei voli partendo dai dati di campagna, ancora non funzionante. In stand-by da quando devo completare il creatore dei voli dell'ATO
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state H, AIATOtasking has started '))
				end
				if LimitedFlow == false or LimitedFlow == nil then
					if DGWSoncall == true then
						mist.message.add({text = "Issuing air support requests .... (STANDBY. WARNING: THIS PROCESS MAY TAKE FEW MINUTES!) ....  ", displayTime = 10, msgFor = {coa = {"all"}} })
					end
					--DGWS.AIATOtasking()   -- BYPASS
				end
				DGWS.globalStateChanger()
				PastGlobalState = "H"
			elseif GlobalState == "I" then   
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state I, SITREP has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Writing SITREP reports .... (STANDBY. WARNING: THIS PROCESS MAY TAKE FEW SECONDS!) ....  ", displayTime = 5, msgFor = {coa = {"all"}} })
				end
				DGWS.Report()   -- BYPASS
				DGWS.globalStateChanger()
				PastGlobalState = "I"
			elseif GlobalState == "J" then -- this one close the loop and restart
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state J, integrating DAWS flights '))
				end

				if DAWS then
					if DGWSoncall == true then
						mist.message.add({text = "Integrating Flights using DAWS ... (STANDBY. WARNING: THIS PROCESS MAY TAKE A MINUTE!)", displayTime = 10, msgFor = {coa = {"all"}} })
					end
					DAWS.onCallProcess()
					mist.scheduleFunction(DGWS.globalStateChanger,{},timer.getTime() + 35)
				else
					mist.message.add({text = "DAWS not active", displayTime = 5, msgFor = {coa = {"all"}} })
					DGWS.globalStateChanger()
				end

				PastGlobalState = "J"
			elseif GlobalState == "K" then -- this one close the loop and restart
				if ENVINFOdebug == true then
					env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state K, doSaveFile has started '))
				end
				if DGWSoncall == true then
					mist.message.add({text = "Saving new mission file ... ", displayTime = 5, msgFor = {coa = {"all"}} })
				end
				DGWS.doSaveFile()
				DGWS.buildNewMizFile()
				PastGlobalState = "K"
			end
		end

	end
	--]]--

	--[[ LPC
	DGWS.ExecuteLimitedPeriodicCycle = function() -- NON PIU' USATO?

		if GlobalState ~= PastGlobalState then

			if GlobalState == "A" then -- start looping state filter...
				--DEBUGENVINFO
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state A, editObjList has started '))
				end
				DGWS.editObjList()
				PastGlobalState = "A"
			--elseif GlobalState == "B" then
				--break
			elseif GlobalState == "C" then
				--DEBUGENVINFO
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state C, integrateKnownEnemyList has started '))
				end
				DGWS.integrateKnownEnemyList()
				PastGlobalState = "C"
			elseif GlobalState == "D" then
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state D, updateORBATlist has started '))
				end
				DGWS.updateORBATlist()
				PastGlobalState = "D"
			--elseif GlobalState == "E" then
				--break
			elseif GlobalState == "F" then
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state F, groupSITREPupdate has started '))
				end
				DGWS.groupSITREPupdate() -- CAN BE SKIPPED?
				PastGlobalState = "F"
			elseif GlobalState == "G" then
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state G, decisionMaker has started '))
				end
				DGWS.globalStateChanger() -- SKIP DECISIONMAKER
				--DGWS.decisionMaker()
				PastGlobalState = "G"
			elseif GlobalState == "H" then
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state H, AIATOtasking has started '))
				end
				DGWS.globalStateChanger() -- SKIP ATOTASKING
				--DGWS.AIATOtasking()
				PastGlobalState = "H"
			elseif GlobalState == "I" then
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state I, SITREP has started '))
				end
				--DGWS.Report()
				DGWS.globalStateChanger() -- SKIP REPORT (for the moment)
				PastGlobalState = "I"
			elseif GlobalState == "J" then -- this one close the loop and restart
				if ENVINFOdebug == true then
				env.info(('DGWS-DEBUG: Previous state ' .. PastGlobalState .. ', current state J, doSaveFile has started '))
				end
				DGWS.doSaveFile()
				DGWS.buildNewMizFile()
				PastGlobalState = "J"
			end



		end

	end
	--]]--


--#########################################################################################################################
--###########################################   RUN DGWS FUNCTIONS   ######################################################
--#########################################################################################################################
--#########################################################################################################################

	-- pre-looped function (to be run in this very moment
	DGWSinitialize = function()
		InitState = "A"
		PastInitState = "X"
		mist.message.add({text = "DGWS initialization...", displayTime = 3, msgFor = {coa = {"all"}} })

		DGWS.InitStateChanger = function()
			if InitState == "A" then -- start looping state filter...
				InitState = "C" -- Changed from B, reserved.
			elseif InitState == "B" then
				InitState = "C"
			elseif InitState == "C" then
				InitState = "D"
			elseif InitState == "D" then
				InitState = "F" -- Changed from E, reserved.
			elseif InitState == "E" then
				InitState = "F"
			elseif InitState == "F" then
				InitState = "G"
			elseif InitState == "G" then
				InitState = "H"
			elseif InitState == "H" then
				InitState = "I"
			elseif InitState == "I" then
				InitState = "J"
			elseif InitState == "J" then -- this one close the loop and restart
				InitState = "K"
			elseif InitState == "K" then
				InitState = "L"
			elseif InitState == "L" then -- this one close the loop and restart
				mist.removeFunction(initProcess)
				DGWS.StartProcess()
				mist.message.add({text = "DGWS on-call mode is initialized", displayTime = 3, msgFor = {coa = {"all"}} })
			end
		end
		--]]--

		-- EPC
		DGWS.ExecuteInitCycle = function() -- POSSIBILI DIFFICOLTA' NELL'ESEGUIRE I CICLI...

			if InitState ~= PastInitState then

				if InitState == "A" then -- start looping state filter...
					--DEBUGENVINFO
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state A, DGWS.deadMapObjDestroy() has started '))
					end
					DGWS.deadMapObjDestroy()
					DGWS.InitStateChanger()
					PastInitState = "A"
				--elseif InitState == "B" then
					--break
				elseif InitState == "C" then
					--DEBUGENVINFO
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state C, DGWS.readCampaignStatus() has started '))
					end
					DGWS.readCampaignStatus()
					DGWS.InitStateChanger()
					PastInitState = "C"
				elseif InitState == "D" then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state D, DGWS.readObjList() has started '))
					end
					DGWS.readObjList()
					DGWS.InitStateChanger()
					PastInitState = "D"
				--elseif InitState == "E" then
					--break
				elseif InitState == "F" then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state F, DGWS.readPassCodelist() has started '))
					end
					DGWS.readPassCodelist()
					DGWS.InitStateChanger()
					PastInitState = "F"
				elseif InitState == "G" then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state G, DGWS.startStateSaveup() has started '))
					end
					DGWS.startStateSaveup()
					DGWS.InitStateChanger()
					PastInitState = "G"
				elseif InitState == "H" then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state H, DGWS.updateORBATlist() has started '))
					end
					DGWS.updateORBATlist()
					DGWS.InitStateChanger()
					PastInitState = "H"
				elseif InitState == "I" then
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state I, DGWS.readObjList() has started '))
					end
					DGWS.readObjList()
					DGWS.InitStateChanger()
					PastInitState = "I"
				elseif InitState == "J" then -- this one close the loop and restart
					local ORBATn = table.getn(ORBATlist)
					if ORBATn > 0 then
						if ENVINFOdebug == true then
							env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state J, DGWS.updateStrategicREP() has started '))
						end
						DGWS.updateStrategicREP()
					end
					DGWS.InitStateChanger()
					PastInitState = "J"
					
				elseif InitState == "K" then -- this one close the loop and restart
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state K, DGWS.UpdateMissionStartTime() has started '))
					end
					DGWS.UpdateMissionStartTime()
					DGWS.InitStateChanger()
					PastInitState = "K"
				elseif InitState == "L" then -- this one close the loop and restart
					if ENVINFOdebug == true then
						env.info(('DGWS-INIT: Previous state ' .. PastInitState .. ', current state L, DGWS.UpdateWeather() has started '))
					end
					DGWS.UpdateWeather()
					DGWS.InitStateChanger()
					PastInitState = "L"
				end

			end

		end
		--]]--

		local initProcess = mist.scheduleFunction(DGWS.ExecuteInitCycle,{},timer.getTime() + 1, 1, (missionLasting))

		env.info(('DGWS initialization complete'))
	end
	--]]--

	DGWSresetworkflow = function() -- REVIEW THIS!!!!

			--overwrite startdate
			local STdate = math.floor(timer.getTime0() / 3600 / 24)-1
			local stdatefile = DGWStools.io.open(DGWStools.lfs.currentdir() .. subdirectory .. campaigndirectory .. tabledirectory .. "CampaignStDate" .. exportfiletype, "w")
			stdatefile:write(STdate)
			stdatefile:close()

			if RebuildScenery == true then
				-- mist.scheduleFunction(DGWS.createObjList,{},timer.getTime() + 5) commented for safety purposes. Maybe to be removed in the future and better explained in a dedicated functions.
				-- mist.scheduleFunction(DGWS.CreateBuildingLists,{},timer.getTime() + 6) commented for safety purposes. Maybe to be removed in the future and better explained in a dedicated functions.
			end

			--## PHASE 1: read external tables
			mist.scheduleFunction(DGWS.readCampaignStatus,{},timer.getTime() + 2)
			--mist.scheduleFunction(DGWS.CampaignStDateReader,{},timer.getTime() + 4)
			mist.scheduleFunction(DGWS.readObjList,{},timer.getTime() + 5)
			mist.scheduleFunction(DGWS.readPassCodelist,{},timer.getTime() + 6)

			--## PHASE 2: one timer sequence to setup campaign
			-- ADD STARTING DATE READER!!
			mist.scheduleFunction(DGWS.updateORBATlist,{},timer.getTime() + 10)

			mist.scheduleFunction(DGWS.readObjList,{},timer.getTime() + 15)
			mist.scheduleFunction(DGWS.editObjList,{},timer.getTime() + 20)
			mist.scheduleFunction(DGWS.readObjList,{},timer.getTime() + 25)

			mist.scheduleFunction(DGWS.integrateKnownEnemyList,{},timer.getTime() + 30)
			mist.scheduleFunction(DGWS.updateORBATlist,{},timer.getTime() + 35)
			mist.scheduleFunction(DGWS.readORBATlist,{},timer.getTime() + 40)
			mist.scheduleFunction(DGWS.updateStrategicREP,{},timer.getTime() + 43)

			mist.scheduleFunction(DGWS.groupSITREPupdate,{},timer.getTime() + 45)
			--mist.scheduleFunction(DGWS.readgroupSITREPList,{},timer.getTime() + 50) //MAYBE NOT USEFUL ANYMORE

			mist.scheduleFunction(DGWS.decisionMaker,{},timer.getTime() + 55)

			RunScenery = false

			-- confirm message. // ADD CHECKS?
			mist.message.add({text = "Scenery rebuild is complete", displayTime = 10, msgFor = {coa = {"[all]"} }})

	end
	--]]--

	DGWSworkflow = function() -- AGGIORNA!!
			local LimitedFlow = false
			--[[--
			--]]--
			--schedule planned movement
			mist.scheduleFunction(DGWS.schedulePlannedMov,{},timer.getTime() + StartMovDelay*60 + 10)

			-- Cycle!
			mist.scheduleFunction(DGWS.ExecutePeriodicCycle,{},timer.getTime() + StartMovDelay*60 + 60, 10, (missionLasting))

			-- ## PHASE 5: launch frequent "instant" class function
			mist.scheduleFunction(DGWS.deadMapObjCollect,{},timer.getTime() + StartMovDelay*60 + 310, 60, (missionLasting))
			mist.scheduleFunction(DGWS.UpdateBuildingLists,{},timer.getTime() + StartMovDelay*60 + 62, 60, (missionLasting))

			-- ## EX: debug functions
			mist.scheduleFunction(DGWS.DEBUGFunctionsTable,{},timer.getTime() + StartMovDelay*60 + 205, 30, (missionLasting))

			-- bubble function /DISABLED
			--mist.scheduleFunction(DGWS.Bubble,{},timer.getTime() + StartMovDelay*60 + 15, 30,(missionLasting))

	end
	--]]--

	-- limited workflow
	DGWSlimitedworkflow = function()
			local LimitedFlow = true
			mist.scheduleFunction(DGWS.ExecutePeriodicCycle,{},timer.getTime() + StartMovDelay*60 + 60, 10, (missionLasting))

			-- ## PHASE 5: launch frequent "instant" class function
			mist.scheduleFunction(DGWS.deadMapObjCollect,{},timer.getTime() + StartMovDelay*60 + 310, 60, (missionLasting))
			mist.scheduleFunction(DGWS.UpdateBuildingLists,{},timer.getTime() + StartMovDelay*60 + 62, 60, (missionLasting))

			-- ## EX: debug functions
			mist.scheduleFunction(DGWS.DEBUGFunctionsTable,{},timer.getTime() + StartMovDelay*60 + 205, 30, (missionLasting))

	end
	--]]--

	-- on call: call in a radio item that execute once the update & saving procedures.
	DGWSoncallworkflow = function() -- check if this could limit DEIS functionality
		local LimitedFlow = false
		GlobalState = "A"
		PastGlobalState = "X"
		mist.scheduleFunction(DGWS.deadMapObjCollect,{},timer.getTime() + 1)
		mist.scheduleFunction(DGWS.UpdateBuildingLists,{},timer.getTime() + 2)
		OnCallPeriodicCycle = mist.scheduleFunction(DGWS.ExecutePeriodicCycle,{},timer.getTime() + 3, 10, (missionLasting))
	end
	--]]--

	DGWS.StartProcess = function()
		if DGWSreset == true then
			--mist.scheduleFunction(DGWSinitialize,{},timer.getTime() + 5)
			mist.scheduleFunction(DGWSresetworkflow,{},timer.getTime() + 60)
		elseif DGWSallow == true then
			--mist.scheduleFunction(DGWSinitialize,{},timer.getTime() + 5)
			mist.scheduleFunction(DGWSworkflow,{},timer.getTime() + 60)
		elseif DGWSlimited == true then
			--mist.scheduleFunction(DGWSinitialize,{},timer.getTime() + 5)
			mist.scheduleFunction(DGWSlimitedworkflow(),{},timer.getTime() + 60)
		elseif DGWSoncall == true then

			-- FROM RADIO COMMAND SCRIPT CHUNK... sadly I don't know the author to add him to the thanks' list
			blue_radio = {"DGWScontrolunit"}
			radiotable_blue = {}

			function addradio_blue(arg)
			------------------------------------------------------------------------------------------------------------------------------------------------------------------
					AddRadioMenu_blue("DGWScontrolunit")
			end

			function AddRadioMenu_blue(unitName)
				if radiotable_blue[unitName] == nil then
				local unit = Unit.getByName(unitName)

					if unit == nil then
						return
					end

					local group = unit:getGroup()

					if group == nil then
						return
					end
					radiogid = group:getID()
					missionCommands.addCommandForGroup(radiogid, "DGWS - Elaborate & save data", nil, DGWSoncallworkflow, unitName)
				end
			end

			function recheck_blue()
				for i=1,#blue_radio do

					local unitName = blue_radio[i]
					local unit = Unit.getByName(unitName)

					if unit == nil then
						local playerName = unit:getPlayerName()
							end
				end
				timer.scheduleFunction(recheck_blue, nil, timer.getTime() + 2)
				return
			end

			mist.scheduleFunction(recheck_blue,{},timer.getTime() + 10)
			mist.scheduleFunction(addradio_blue,{},timer.getTime() + 15)
			--DGWSoncallworkflow()
			mist.scheduleFunction(DGWS.schedulePlannedMov,{},timer.getTime() + StartMovDelay*60 + 10)
			env.info(("DGWS on call mode is initialized"))
			--mist.scheduleFunction(mist.message.add,{text = "DGWSoncall mode is active", displayTime = 5, msgFor = {coa = {"all"}} },timer.getTime()+6)
		end
		--]]--
	end
	--]]--


	env.info(('DGWS ' .. MainVersion .. "." .. SubVersion .. "." .. Build))

	--if DGWSreset or DGWSallow or DGWSoncall or DGWSlimited then
	DGWSinitialize()
	--end
	-- ADD MESSAGE



--#########################################################################################################################
--################################################# OTHER MODULES / CODE ##################################################
--#########################################################################################################################
--#########################################################################################################################


	-- load DAWS
	if DAWStrue == true then
		dofile(DGWStools.lfs.currentdir() .. 'AMVI/DAWS/DAWS_main.lua')
	end

	-- load EnhancedIA
	if DEIStrue == true then
		dofile(DGWStools.lfs.currentdir() .. codedirectory .. 'DEIS.lua')
	end


	---------TESTING----------

	--DGWS.createATOreqList()
	--mist.scheduleFunction(DGWS.readCampaignStatus,{},timer.getTime() + 2)


--#########################################################################################################################
--################################################# TRASH BOX // DELETE IT ################################################
--#########################################################################################################################
--#########################################################################################################################
