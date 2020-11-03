-- Dynamic Sequential Mission Campaign -- Loader

local ModuleName  	= "Loader"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0001"
local Date			= "09/03/2020"

-- ## USER PREFERENCE VARIABLES - CHANGING THOSE WILL IMPACT THE DSMC WAY TO WORK ######

debugProcess				= true -- this should be left on for testers normal ops and test missions

--## DEBUG
function writeDebugBase(debuglog, othervar)
	if debuglog and debugProcess then
		f = io.open(lfs.writedir() .. "Logs/" .. "DSMC_log.txt", "r")		
		oldDebug = f:read("*all")
		f:close()
		newDebug = oldDebug .. "\n" .. os.date("%H:%M") .. " - " .. debuglog
		n = io.open(lfs.writedir() .. "Logs/" .. "DSMC_log.txt", "w")		
		n:write(newDebug)
		if othervar then n:write("othervar exist\n") end
		n:close()
	end
end
function writeDebugDetail(debuglog, othervar)
	if debuglog and debugProcessDetail then
		f = io.open(lfs.writedir() .. "Logs/" .. "DSMC_log.txt", "r")		
		oldDebug = f:read("*all")
		f:close()
		newDebug = oldDebug .. "\n" .. os.date("%H:%M") .. " - " .. debuglog
		n = io.open(lfs.writedir() .. "Logs/" .. "DSMC_log.txt", "w")		
		n:write(newDebug)
		if othervar then n:write("othervar exist\n") end
		n:close()
	end
end
writeDebugBase(ModuleName .. ": user pref loaded")

writeDebugBase(ModuleName .. ": DEBUG_var = " ..tostring(DEBUG_var))
if DEBUG_var == true then
	debugProcessDetail = true
	writeDebugBase(ModuleName .. ": debugProcessDetail inner check true")
else
	writeDebugBase(ModuleName .. ": debugProcessDetail inner check false")
end


-- ## LOCAL VARIABLES
DSMCloader 					= false
StartFilterCode				= "DSMC"
mapObj_deathcounter 		= 0
baseGcounter 				= 100000
saveCounter					= 0 
StaticStartNumber 			= 0
NEWstartTime 				= nil
NEWstartDateYear			= nil
NEWstartDateMonth			= nil
NEWstartDateDay				= nil
NEWstartTime				= nil			
NEWstartDateDay				= nil
NEWstartDateYear			= nil
NEWstartDateMonth			= nil
NEWweather 					= nil 
strDeadUnits				= nil
strScenObj					= nil
strUnitsUpdate				= nil
strAirbases					= nil
strWeather					= nil
strSpawned					= nil
hits_max_count				= 10000  -- more that this number and the aircraft is considerered grounded!. Set 10000 to "disable" that function
tempWeatherTable			= nil
randomizeDynWeather			= false
writeDebugBase(ModuleName .. ": variables loaded")

-- ## PATHS
DSMCdirectory				= lfs.writedir() .. "DSMC/"
DSMCfiles					= lfs.writedir() .. "DSMC/Files/"
missionfilesdirectory 		= lfs.writedir() .. "Missions/"
tempmissionfilesdirectory	= lfs.tempdir() .. "DSMCunpack/"
NewMizTempDir 				= "SAVE_TempMix/"	
OldMissionPath 				= missionfilesdirectory .. "Temp/" .. "mission"
NewMissionPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .. "mission"
OldDictPath 				= missionfilesdirectory .. "Temp/" .. "dictionary"
NewDictPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "dictionary"	
OldMResPath 				= missionfilesdirectory .. "Temp/" .. "mapResource"
NewMResPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "mapResource"	
OldWrhsPath 				= missionfilesdirectory .. "Temp/" .. "warehouses"
NewWrhsPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."warehouses"
logpath 					= lfs.writedir() .. "Logs/mixpath.txt"
tempPath 					= missionfilesdirectory .. "DSMC_tempFile.miz"
writeDebugBase(ModuleName .. ": paths loaded")


TMUP_cont_DP 				= nil
-- adjust options multiple values
if TMUP_cont_var == 1 then -- timer_options == "default" or 
	TMUP_cont_DP = true
else
	TMUP_cont_DP = false
end
--]]--

writeDebugDetail(ModuleName .. ": MOBJ_var = " ..tostring(MOBJ_var))
writeDebugDetail(ModuleName .. ": CRST_var = " ..tostring(CRST_var))
writeDebugDetail(ModuleName .. ": WTHR_var = " ..tostring(WTHR_var))
writeDebugDetail(ModuleName .. ": TMUP_var = " ..tostring(TMUP_var))
writeDebugDetail(ModuleName .. ": TMUP_cont_var = " ..tostring(TMUP_cont_var))
writeDebugDetail(ModuleName .. ": WRHS_var = " ..tostring(WRHS_var))
writeDebugDetail(ModuleName .. ": SPWN_var = " ..tostring(SPWN_var))
writeDebugDetail(ModuleName .. ": TRPS_var = " ..tostring(TRPS_var))
writeDebugDetail(ModuleName .. ": TRPS_setup_var = " ..tostring(TRPS_setup_var))
writeDebugDetail(ModuleName .. ": DEBUG_var = " ..tostring(DEBUG_var))
writeDebugDetail(ModuleName .. ": ATRL_var = " ..tostring(ATRL_var))
writeDebugDetail(ModuleName .. ": ATRL_time_var = " ..tostring(ATRL_time_var))

UpdateSceneryStartTime		= TMUP_var 			-- if true the next mission start time will change in the next sortie
KeepContinousMission 		= TMUP_cont_DP		-- if true (and UpdateSceneryStartTime = true) the nex mission start time will be exactly the mission end time
CreateSceneryWreckage 		= CRST_var 			-- if true vehicle units wreckage will be tracked from a mission to another 
TrackMapDestruction 		= MOBJ_var 			-- if true map object will kept destroyed from a mission to another
UpdateSceneryWeather		= WTHR_var 			-- if true weather will change in the next mission
TrackWarehousesItems		= WRHS_var 			-- if true warehouses items in the inbuilt resource manager system will be tracked
UpdateMissionPapers			= false 			-- NOT USED NOW if true mission briefings will be updated from a mission to another
TrackSpawnedGroundUnits		= SPWN_var  		-- if true spawned ground units like vehicles will be tracked from a mission to the next one
AutoRestartModule			= ATRL_var

-- #####################################################################################

-- ## DSMC CORE MODULES
UTIL						= require("UTIL")
writeDebugBase(ModuleName .. ": loader called in UTIL module")
SAVE 						= require("SAVE")
writeDebugBase(ModuleName .. ": loader called in SAVE module")

-- ## DSMC ADDITIONAL MODULES
if UTIL.fileExist(DSMCdirectory .. "MOBJ" .. ".lua") == true and TrackMapDestruction == true then
	MOBJ 						= require("MOBJ")
	writeDebugBase(ModuleName .. ": loader called in MOBJ module")
end
if UTIL.fileExist(DSMCdirectory .. "CRST" .. ".lua") == true and CreateSceneryWreckage == true then
	CRST 						= require("CRST")
	writeDebugBase(ModuleName .. ": loader called in CRST module")
end
if UTIL.fileExist(DSMCdirectory .. "WTHR" .. ".lua") == true and UpdateSceneryWeather == true then
	WTHR 						= require("WTHR")
	writeDebugBase(ModuleName .. ": loader called in WTHR module")
end
if UTIL.fileExist(DSMCdirectory .. "WRHS" .. ".lua") == true and TrackWarehousesItems == true then
	WRHS 						= require("WRHS")
	writeDebugBase(ModuleName .. ": loader called in WRHS module")
end
if UTIL.fileExist(DSMCdirectory .. "TMUP" .. ".lua") == true and UpdateSceneryStartTime == true then
	TMUP 						= require("TMUP")
	writeDebugBase(ModuleName .. ": loader called in TMUP module")
end
if UTIL.fileExist(DSMCdirectory .. "SPWN" .. ".lua") == true and TrackSpawnedGroundUnits == true then
	SPWN 						= require("SPWN")
	writeDebugBase(ModuleName .. ": loader called in SPWN module")
end
if UTIL.fileExist(DSMCdirectory .. "ATRL" .. ".lua") == true and AutoRestartModule == true then
	ATRL 						= require("ATRL")
	writeDebugBase(ModuleName .. ": loader called in ATRL module")
end
--

writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build  .. ", released in " .. Date)
DSMCloader = true
--~=